-- 플레이어 데이터: 접속하면 DataStore에서 불러오고, 1분마다·나갈 때·서버가 꺼질 때 저장한다.
local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Rarity = require(Shared:WaitForChild("Rarity"))
local Catalog = require(Shared:WaitForChild("Catalog"))
local Gacha = require(Shared:WaitForChild("Gacha"))

local PlayerData = {}

local STORE_NAME = "PlayerData_v1"
local DATA_VERSION = 2 -- 2: 가방이 등급별 개수에서 장식·특성 칸 목록으로 바뀜
local AUTOSAVE_INTERVAL = 60 -- 초
local MAX_RETRIES = 3
local SHUTDOWN_SAVE_TIMEOUT = 25 -- 서버가 꺼질 때 저장을 기다리는 최대 시간(초)

local IS_STUDIO = RunService:IsStudio()

local store = nil
local storeError = nil
do
	local ok, result = pcall(function()
		return DataStoreService:GetDataStore(STORE_NAME)
	end)
	if ok then
		store = result
	else
		storeError = result
	end
end

local profiles = {} -- [Player] = profile (불러오기가 끝난 플레이어만 들어 있다)
local pendingSaves = 0

----------------------------------------------------------------
-- 데이터 모양
----------------------------------------------------------------

local function newProfile()
	return {
		coins = if IS_STUDIO then Config.STUDIO_START_COINS else Config.START_COINS,
		luckLevel = 0,
		speedLevel = 0,
		-- 가방 칸 목록. 장식과 특성이 같으면 한 칸에 쌓인다.
		-- { d = 장식 id, t = 특성 id, c = 개수, l = 잠금 여부 }
		-- 카탈로그에 없는 id(지워졌거나 바뀐 장식)는 지우지 않고 보관만 한다. 화면·칸 수·판매에서 빠진다.
		stacks = {},
		bagCapacity = Config.BAG_BASE_SLOTS,
		autoSellMax = 0, -- 이 등급 이하는 뽑자마자 판매 (0 = 끔)

		-- 아래는 저장하지 않는 값
		nextFreeSpinAt = 0, -- 서버 시각(workspace:GetServerTimeNow())
		busyUntil = 0, -- 룰렛 연출이 끝나는 서버 시각
		canSave = true,
	}
end

local function copyStacks(stacks)
	local copy = table.create(#stacks)
	for i, stack in stacks do
		copy[i] = { d = stack.d, t = stack.t, c = stack.c, l = stack.l }
	end
	return copy
end

-- 저장할 값만 골라낸다
local function serialize(profile)
	return {
		version = DATA_VERSION,
		coins = profile.coins,
		luckLevel = profile.luckLevel,
		speedLevel = profile.speedLevel,
		stacks = copyStacks(profile.stacks),
		bagCapacity = profile.bagCapacity,
		autoSellMax = profile.autoSellMax,
	}
end

local function readInt(value, min: number, max: number, default: number): number
	if type(value) ~= "number" or value ~= value then -- NaN 방지
		return default
	end
	return math.clamp(math.floor(value), min, max)
end

local function stackKey(decoId: string, traitId: string): string
	return decoId .. ":" .. traitId
end

-- 저장된 값을 검사해서 프로필로 만든다. 없는 값은 기본값으로 채운다.
local function reconcile(saved)
	local profile = newProfile()
	if type(saved) ~= "table" then
		return profile -- 처음 온 플레이어
	end

	profile.coins = readInt(saved.coins, 0, math.huge, 0)
	profile.luckLevel = readInt(saved.luckLevel, 0, #Config.LUCK_MULT, 0)
	profile.speedLevel = readInt(saved.speedLevel, 0, #Config.SPEED_TIME_MULT, 0)
	profile.bagCapacity = readInt(saved.bagCapacity, Config.BAG_BASE_SLOTS, Config.BAG_MAX_SLOTS, Config.BAG_BASE_SLOTS)
	profile.autoSellMax = readInt(saved.autoSellMax, 0, Config.AUTO_SELL_MAX_OPTION, 0)

	if type(saved.stacks) == "table" then
		local byKey = {}
		for _, stack in saved.stacks do
			if type(stack) ~= "table" or type(stack.d) ~= "string" or type(stack.t) ~= "string" then
				continue
			end
			local count = readInt(stack.c, 0, math.huge, 0)
			if count <= 0 then
				continue
			end
			local key = stackKey(stack.d, stack.t)
			local existing = byKey[key]
			if existing then
				existing.c += count -- 같은 칸이 두 번 저장돼 있으면 합친다
			else
				local entry = { d = stack.d, t = stack.t, c = count, l = stack.l == true }
				byKey[key] = entry
				table.insert(profile.stacks, entry)
			end
		end
	elseif type(saved.bag) == "table" then
		-- 버전 1(등급별 개수) 데이터: 장식 정보가 없으므로 판매 가격만큼 코인으로 돌려준다
		for i = 1, Rarity.Count do
			local count = readInt(saved.bag[i], 0, math.huge, 0)
			profile.coins += Gacha.GetSellPrice(i, 1) * count
		end
	end
	return profile
end

----------------------------------------------------------------
-- DataStore
----------------------------------------------------------------

local function keyFor(userId: number): string
	return "u_" .. userId
end

local function withRetries(fn, retries: number?)
	local tries = retries or MAX_RETRIES
	local lastError
	for attempt = 1, tries do
		local ok, result = pcall(fn)
		if ok then
			return true, result
		end
		lastError = result
		if attempt < tries then
			task.wait(attempt * 2)
		end
	end
	return false, lastError
end

local function loadData(userId: number)
	if not store then
		return false, storeError
	end
	-- Studio에서는 DataStore가 꺼져 있는 경우가 많아서 기다리지 않고 한 번만 시도한다
	return withRetries(function()
		return store:GetAsync(keyFor(userId))
	end, if IS_STUDIO then 1 else MAX_RETRIES)
end

local function saveData(userId: number, profile): boolean
	if not profile.canSave or not store then
		return true
	end
	local data = serialize(profile)
	local ok, err = withRetries(function()
		store:UpdateAsync(keyFor(userId), function()
			return data
		end)
	end)
	if not ok then
		warn(string.format("[PlayerData] %d 저장 실패: %s", userId, tostring(err)))
	end
	return ok
end

local function saveTracked(userId: number, profile)
	pendingSaves += 1
	saveData(userId, profile)
	pendingSaves -= 1
end

----------------------------------------------------------------
-- 공개 함수
----------------------------------------------------------------

-- 불러오기가 끝나기 전에는 nil
function PlayerData.Get(player: Player)
	return profiles[player]
end

PlayerData.StackKey = stackKey

-- 카탈로그에 있는 장식·특성인지 (없으면 보관만 하고 화면·칸 수·판매에서 뺀다)
function PlayerData.IsKnownStack(stack): boolean
	return Catalog.DecorationById[stack.d] ~= nil and Catalog.TraitById[stack.t] ~= nil
end

-- 가방에서 쓰고 있는 칸 수
function PlayerData.GetBagSlotsUsed(profile): number
	local used = 0
	for _, stack in profile.stacks do
		if stack.c > 0 and PlayerData.IsKnownStack(stack) then
			used += 1
		end
	end
	return used
end

function PlayerData.FindStack(profile, key: string)
	for _, stack in profile.stacks do
		if stackKey(stack.d, stack.t) == key then
			return stack
		end
	end
	return nil
end

-- 장식을 가방에 넣는다. 새 칸이면 레전더리 이상은 처음부터 잠근다.
function PlayerData.AddItem(profile, deco, trait, count: number)
	local key = stackKey(deco.id, trait.id)
	local stack = PlayerData.FindStack(profile, key)
	if stack then
		stack.c += count
	else
		stack = { d = deco.id, t = trait.id, c = count, l = deco.rarity >= Config.DEFAULT_LOCK_MIN_RARITY }
		table.insert(profile.stacks, stack)
	end
	return stack
end

-- 개수가 0인 칸을 지운다
function PlayerData.RemoveEmptyStacks(profile)
	local kept = {}
	for _, stack in profile.stacks do
		if stack.c > 0 then
			table.insert(kept, stack)
		end
	end
	profile.stacks = kept
end

function PlayerData.AddCoins(player: Player, amount: number)
	local profile = profiles[player]
	if not profile then
		return
	end
	profile.coins = math.max(0, profile.coins + amount)

	local leaderstats = player:FindFirstChild("leaderstats")
	local coinsValue = leaderstats and leaderstats:FindFirstChild("Coins")
	if coinsValue then
		coinsValue.Value = profile.coins
	end
end

----------------------------------------------------------------
-- 접속·퇴장
----------------------------------------------------------------

local function createLeaderstats(player: Player, profile)
	local leaderstats = Instance.new("Folder")
	leaderstats.Name = "leaderstats"

	local coinsValue = Instance.new("IntValue")
	coinsValue.Name = "Coins"
	coinsValue.Value = profile.coins
	coinsValue.Parent = leaderstats

	leaderstats.Parent = player
end

local function onPlayerAdded(player: Player)
	local ok, saved = loadData(player.UserId)
	if player.Parent == nil then
		return -- 불러오는 동안 나갔다
	end

	local canSave = true
	if not ok then
		if IS_STUDIO then
			-- 게시 안 된 플레이스이거나 Studio API 접근이 꺼져 있으면 여기로 온다
			warn(
				"[PlayerData] DataStore를 쓸 수 없어 이번 테스트는 저장하지 않습니다.",
				"(게임을 게시하고 Game Settings → Security → Enable Studio Access to API Services를 켜면 저장돼요)",
				saved
			)
			canSave = false
		else
			-- 빈 데이터로 시작했다가 기존 데이터를 덮어쓰지 않도록 내보낸다
			player:Kick("데이터를 불러오지 못했습니다. 잠시 후 다시 접속해 주십시오.")
			return
		end
	end

	local profile = reconcile(saved)
	profile.canSave = canSave
	profiles[player] = profile
	createLeaderstats(player, profile)
end

local function onPlayerRemoving(player: Player)
	local profile = profiles[player]
	if not profile then
		return
	end
	profiles[player] = nil
	saveTracked(player.UserId, profile)
end

local function onShutdown()
	for player, profile in profiles do
		profiles[player] = nil
		task.spawn(saveTracked, player.UserId, profile)
	end
	local deadline = os.clock() + SHUTDOWN_SAVE_TIMEOUT
	while pendingSaves > 0 and os.clock() < deadline do
		task.wait(0.1)
	end
end

function PlayerData.Init()
	Players.PlayerAdded:Connect(onPlayerAdded)
	Players.PlayerRemoving:Connect(onPlayerRemoving)
	for _, player in Players:GetPlayers() do
		task.spawn(onPlayerAdded, player)
	end

	game:BindToClose(onShutdown)

	task.spawn(function()
		while true do
			task.wait(AUTOSAVE_INTERVAL)
			for player, profile in profiles do
				task.spawn(saveData, player.UserId, profile)
			end
		end
	end)
end

return PlayerData
