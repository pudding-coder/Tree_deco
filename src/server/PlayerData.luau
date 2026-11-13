-- 플레이어 데이터: 접속하면 DataStore에서 불러오고, 1분마다·나갈 때·서버가 꺼질 때 저장한다.
local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Rarity = require(Shared:WaitForChild("Rarity"))

local PlayerData = {}

local STORE_NAME = "PlayerData_v1"
local DATA_VERSION = 1
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
		bag = table.create(Rarity.Count, 0), -- 등급 번호 -> 개수 (같은 등급끼리 1칸에 쌓임)
		bagCapacity = Config.BAG_BASE_SLOTS,

		-- 아래는 저장하지 않는 값
		nextFreeSpinAt = 0, -- 서버 시각(workspace:GetServerTimeNow())
		busyUntil = 0, -- 룰렛 연출이 끝나는 서버 시각
		canSave = true,
	}
end

-- 저장할 값만 골라낸다
local function serialize(profile)
	return {
		version = DATA_VERSION,
		coins = profile.coins,
		luckLevel = profile.luckLevel,
		speedLevel = profile.speedLevel,
		bag = table.clone(profile.bag),
		bagCapacity = profile.bagCapacity,
	}
end

local function readInt(value, min: number, max: number, default: number): number
	if type(value) ~= "number" or value ~= value then -- NaN 방지
		return default
	end
	return math.clamp(math.floor(value), min, max)
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
	if type(saved.bag) == "table" then
		for i = 1, Rarity.Count do
			profile.bag[i] = readInt(saved.bag[i], 0, math.huge, 0)
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

-- 가방에서 쓰고 있는 칸 수
function PlayerData.GetBagSlotsUsed(profile): number
	local used = 0
	for _, count in profile.bag do
		if count > 0 then
			used += 1
		end
	end
	return used
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
				"[PlayerData] DataStore를 쓸 수 없어 이번 테스트는 저장하지 않아요.",
				"(게임을 게시하고 Game Settings → Security → Enable Studio Access to API Services를 켜면 저장돼요)",
				saved
			)
			canSave = false
		else
			-- 빈 데이터로 시작했다가 기존 데이터를 덮어쓰지 않도록 내보낸다
			player:Kick("데이터를 불러오지 못했어요. 잠시 후 다시 접속해 주세요.")
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
