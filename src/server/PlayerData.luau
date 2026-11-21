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

-- 자동 판매: 등급마다 켜고 끈다 (비트: 등급 i면 2^(i-1)). 켤 수 있는 등급은 AUTO_SELL_MAX_OPTION까지
local AUTO_SELL_ALLOWED_MASK = 2 ^ Config.AUTO_SELL_MAX_OPTION - 1
PlayerData.AUTO_SELL_ALLOWED_MASK = AUTO_SELL_ALLOWED_MASK

function PlayerData.IsAutoSold(profile, rarityIndex: number): boolean
	return bit32.btest(profile.autoSellMask, 2 ^ (rarityIndex - 1))
end

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
		-- { d = 장식 id, t = 특성 id, s = 크기 id(보통이면 nil), c = 개수, l = 잠금 여부 }
		-- 카탈로그에 없는 id(지워졌거나 바뀐 장식)는 지우지 않고 보관만 한다. 화면·칸 수·판매에서 빠진다.
		stacks = {},
		bagCapacity = Config.BAG_BASE_SLOTS,
		autoSellMask = 0, -- 뽑자마자 판매할 등급 (비트: 등급 i면 2^(i-1). 0 = 모두 보관)
		autoFill = true, -- 트리 빈자리를 가방에서 가장 좋은 장식으로 자동으로 채울지
		potionEndsAt = 0, -- 물약이 끝나는 서버 시각. 저장할 때는 남은 시간(초)으로 바꾼다 (접속 중에만 줄어듦)
		-- 트리에 걸린 장식. { a = 영역(Topper/Ornament/Garland), i = 자리 번호, d = 장식 id, t = 특성 id, s = 크기 id 또는 nil }
		tree = {},
		votes = 0, -- 누적으로 받은 투표 수 (투표 기능 전까지 0)
		-- 트리 효과 상점: 산 효과 id 모음과 켠 효과. 카탈로그에서 빠진 id도 지우지 않고 보관한다 (산 것이므로)
		ownedEffects = {}, -- [id] = true
		effect = nil, -- 켠 트리 효과 id (하나) 또는 nil
		floor = {}, -- 켠 바닥 아이템 id 목록 (Config.MAX_FLOOR_ITEMS개까지, 순서 = 바닥 자리 순서)

		-- 아래는 저장하지 않는 값
		displayStartedAt = workspace:GetServerTimeNow(), -- 이번 접속에서 전시를 시작한 서버 시각 (전시 시간 보너스)
		coinCarry = 0, -- 초당 수입의 소수점 부분을 모아 두는 곳
		nextFreeSpinAt = 0, -- 서버 시각(workspace:GetServerTimeNow())
		busyUntil = 0, -- 룰렛 연출이 끝나는 서버 시각
		canSave = true,
	}
end

local function copyStacks(stacks)
	local copy = table.create(#stacks)
	for i, stack in stacks do
		copy[i] = { d = stack.d, t = stack.t, s = stack.s, c = stack.c, l = stack.l }
	end
	return copy
end

local function copyTree(tree)
	local copy = table.create(#tree)
	for i, entry in tree do
		copy[i] = { a = entry.a, i = entry.i, d = entry.d, t = entry.t, s = entry.s }
	end
	return copy
end

-- 영역별 자리 수
local AREA_CAPACITY = {
	Topper = Config.MAX_TOPPER,
	Ornament = Config.MAX_ORNAMENT,
	Garland = Config.MAX_GARLAND,
}
PlayerData.AREA_CAPACITY = AREA_CAPACITY

-- { [id] = true } → { id, ... } (저장용)
local function ownedList(owned)
	local list = {}
	for id in owned do
		table.insert(list, id)
	end
	table.sort(list)
	return list
end
PlayerData.OwnedEffectList = ownedList

-- 저장할 값만 골라낸다
local function serialize(profile)
	return {
		version = DATA_VERSION,
		coins = profile.coins,
		luckLevel = profile.luckLevel,
		speedLevel = profile.speedLevel,
		stacks = copyStacks(profile.stacks),
		bagCapacity = profile.bagCapacity,
		autoSellMask = profile.autoSellMask,
		autoFill = profile.autoFill,
		potionRemaining = math.max(0, math.floor(profile.potionEndsAt - workspace:GetServerTimeNow())),
		tree = copyTree(profile.tree),
		votes = profile.votes,
		ownedEffects = ownedList(profile.ownedEffects),
		effect = profile.effect,
		floor = table.clone(profile.floor),
	}
end

local function readInt(value, min: number, max: number, default: number): number
	if type(value) ~= "number" or value ~= value then -- NaN 방지
		return default
	end
	return math.clamp(math.floor(value), min, max)
end

local stackKey = Catalog.StackKey

-- 저장된 크기 id: 글자가 아니거나 보통이면 nil (보통은 저장하지 않는다)
local function readSize(value): string?
	if type(value) ~= "string" or value == "" or value == Catalog.BaseSize.id then
		return nil
	end
	return value
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
	profile.autoFill = saved.autoFill ~= false
	if type(saved.autoSellMask) == "number" then
		profile.autoSellMask = bit32.band(readInt(saved.autoSellMask, 0, 2 ^ Rarity.Count - 1, 0), AUTO_SELL_ALLOWED_MASK)
	else
		-- 옛 데이터: "이 등급 이하 자동 판매"(autoSellMax)를 등급별 켜기로 바꾼다
		local level = readInt(saved.autoSellMax, 0, Config.AUTO_SELL_MAX_OPTION, 0)
		profile.autoSellMask = 2 ^ level - 1
	end
	profile.votes = readInt(saved.votes, 0, math.huge, 0)

	-- 트리: 영역·자리 번호가 맞고 겹치지 않는 것만 (자리 수를 줄였으면 넘치는 장식은 가방으로)
	local overflow = {}
	if type(saved.tree) == "table" then
		local used = {}
		for _, entry in saved.tree do
			if type(entry) ~= "table" or type(entry.d) ~= "string" or type(entry.t) ~= "string" then
				continue
			end
			local capacity = AREA_CAPACITY[entry.a]
			local index = readInt(entry.i, 0, 1000, 0)
			local slotKey = tostring(entry.a) .. ":" .. index
			if capacity and index >= 1 and index <= capacity and not used[slotKey] then
				used[slotKey] = true
				table.insert(profile.tree, { a = entry.a, i = index, d = entry.d, t = entry.t, s = readSize(entry.s) })
			else
				table.insert(overflow, entry)
			end
		end
	end

	-- 트리 효과: 산 것만 켤 수 있다
	if type(saved.ownedEffects) == "table" then
		for _, id in saved.ownedEffects do
			if type(id) == "string" and id ~= "" then
				profile.ownedEffects[id] = true
			end
		end
	end
	if type(saved.effect) == "string" and profile.ownedEffects[saved.effect] then
		profile.effect = saved.effect
	end
	if type(saved.floor) == "table" then
		for _, id in saved.floor do
			if #profile.floor >= Config.MAX_FLOOR_ITEMS then
				break
			end
			if type(id) == "string" and profile.ownedEffects[id] and not table.find(profile.floor, id) then
				table.insert(profile.floor, id)
			end
		end
	end

	local potionRemaining = readInt(saved.potionRemaining, 0, 7 * 24 * 3600, 0)
	if potionRemaining > 0 then
		profile.potionEndsAt = workspace:GetServerTimeNow() + potionRemaining
	end

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
			local size = readSize(stack.s)
			local key = stackKey(stack.d, stack.t, size)
			local existing = byKey[key]
			if existing then
				existing.c += count -- 같은 칸이 두 번 저장돼 있으면 합친다
			else
				local entry = { d = stack.d, t = stack.t, s = size, c = count, l = stack.l == true }
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

	-- 트리 자리에서 넘친 장식을 가방에 넣는다 (가방 칸 수를 넘어도 넣어서 잃어버리지 않게)
	for _, entry in overflow do
		local size = readSize(entry.s)
		local key = stackKey(entry.d, entry.t, size)
		local merged = false
		for _, stack in profile.stacks do
			if stackKey(stack.d, stack.t, stack.s) == key then
				stack.c += 1
				merged = true
				break
			end
		end
		if not merged then
			table.insert(profile.stacks, { d = entry.d, t = entry.t, s = size, c = 1, l = false })
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
		if stackKey(stack.d, stack.t, stack.s) == key then
			return stack
		end
	end
	return nil
end

-- 장식을 가방에 넣는다. 새 칸이면 레전더리 이상은 처음부터 잠근다
function PlayerData.AddItem(profile, deco, trait, count: number, sizeId: string?)
	local key = stackKey(deco.id, trait.id, sizeId)
	local stack = PlayerData.FindStack(profile, key)
	if stack then
		stack.c += count
	else
		stack = { d = deco.id, t = trait.id, s = sizeId, c = count, l = deco.rarity >= Config.DEFAULT_LOCK_MIN_RARITY }
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

-- Studio 테스트용: 특성마다 오너먼트·띠·토퍼 견본을 하나씩 넣는다 (이미 있는 칸은 건너뛴다)
local TRAIT_SAMPLE_DECORATIONS = { "OrnamentBall", "MiniLights", "Star" }

local function giveTraitSamples(profile)
	local given = 0
	for _, decoId in TRAIT_SAMPLE_DECORATIONS do
		local deco = Catalog.DecorationById[decoId]
		if not deco then
			continue
		end
		for _, trait in Catalog.Traits do
			if trait.retired then
				continue
			end
			-- 같은 장식·특성이 이미 있으면(색은 상관없이) 건너뛴다
			local owned = false
			for _, stack in profile.stacks do
				if stack.d == deco.id and stack.t == trait.id and stack.c > 0 then
					owned = true
				end
			end
			if owned then
				continue
			end
			PlayerData.AddItem(profile, deco, trait, 1)
			given += 1
		end
	end
	if given > 0 then
		print(string.format("[PlayerData] Studio 테스트: 특성 견본 장식 %d개를 가방에 넣었습니다", given))
	end
end

-- Studio 테스트: DecorationModels에 모델이 있는 장식을 하나씩 가방에 넣는다 (모델 확인용)
local function giveModelSamples(profile)
	local folder = ReplicatedStorage:FindFirstChild("DecorationModels")
	if not folder or not Catalog.BaseTrait then
		return
	end
	local owned = {}
	for _, stack in profile.stacks do
		if stack.c > 0 then
			owned[stack.d] = true
		end
	end
	for _, entry in profile.tree do
		owned[entry.d] = true
	end
	local given = {}
	for _, deco in Catalog.Decorations do
		if not owned[deco.id] and folder:FindFirstChild(deco.model or deco.id) then
			PlayerData.AddItem(profile, deco, Catalog.BaseTrait, 1)
			table.insert(given, deco.id)
		end
	end
	if #given > 0 then
		print(string.format("[PlayerData] Studio 테스트: 모델이 있는 장식 %d개를 가방에 넣었습니다: %s", #given, table.concat(given, ", ")))
	end
end

-- 시연 계정 목록(쉼표로 구분한 글자)에 이 플레이어가 있는지: 계정 이름(대소문자 무시) 또는 UserId(숫자)로 찾는다
-- 표시 이름(닉네임)은 누구나 같게 바꿀 수 있어서 쓰지 않는다
function PlayerData.IsListed(list: string?, player: Player): boolean
	for entry in string.gmatch(list or "", "[^,%s]+") do
		if string.lower(entry) == string.lower(player.Name) or entry == tostring(player.UserId) then
			return true
		end
	end
	return false
end

-- 시연용: Config.DEMO_GIVE_ALL_NAMES에 적힌 계정이면 뽑을 수 있는 모든 장식을 하나씩 넣는다 (실제 서버에서도 동작)
local function isDemoPlayer(player: Player): boolean
	return PlayerData.IsListed(Config.DEMO_GIVE_ALL_NAMES, player)
end

local function giveAllDecorations(profile)
	if not Catalog.BaseTrait then
		return
	end
	local owned = {}
	for _, stack in profile.stacks do
		if stack.c > 0 then
			owned[stack.d] = true
		end
	end
	for _, entry in profile.tree do
		owned[entry.d] = true
	end
	local given = 0
	for _, deco in Catalog.Decorations do
		if not deco.retired and not owned[deco.id] then
			PlayerData.AddItem(profile, deco, Catalog.BaseTrait, 1)
			given += 1
		end
	end
	-- 넣은 뒤에도 룰렛을 돌릴 수 있게 빈 칸을 기본 칸 수만큼 남긴다
	local want = PlayerData.GetBagSlotsUsed(profile) + Config.BAG_BASE_SLOTS
	profile.bagCapacity = math.clamp(math.max(profile.bagCapacity, want), Config.BAG_BASE_SLOTS, Config.BAG_MAX_SLOTS)
	print(string.format("[PlayerData] 시연 계정: 장식 %d개를 가방에 넣었습니다 (가방 %d칸)", given, profile.bagCapacity))
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
			player:Kick("데이터를 불러오지 못했습니다. 잠시 후 다시 접속해 주세요.")
			return
		end
	end

	local profile = reconcile(saved)
	profile.canSave = canSave
	if IS_STUDIO and Config.STUDIO_GIVE_TRAIT_SAMPLES then
		giveTraitSamples(profile)
	end
	if IS_STUDIO and Config.STUDIO_GIVE_MODEL_SAMPLES then
		giveModelSamples(profile)
	end
	if IS_STUDIO then
		-- 시연 계정이 인식되는지 확인용: 서버가 보는 계정 이름·UserId (Config의 DEMO_* 목록에는 이 둘 중 하나를 적는다)
		print(string.format(
			"[PlayerData] 접속: 계정 이름 %s · 표시 이름 %s · UserId %d · 시연 행운 %s · 시연 장식 지급 %s",
			player.Name,
			player.DisplayName,
			player.UserId,
			if PlayerData.IsListed(Config.DEMO_LUCK_NAMES, player) then "켜짐" else "꺼짐",
			if isDemoPlayer(player) then "켜짐" else "꺼짐"
		))
	end
	if isDemoPlayer(player) then
		giveAllDecorations(profile)
	end
	if IS_STUDIO and Config.STUDIO_GIVE_ALL_TREE_EFFECTS then
		local given = {}
		for _, fx in Catalog.TreeEffects do
			if not fx.retired and not profile.ownedEffects[fx.id] then
				profile.ownedEffects[fx.id] = true
				table.insert(given, fx.id)
			end
		end
		if #given > 0 then
			print("[PlayerData] Studio 테스트: 상점 트리 효과를 전부 넣었습니다: " .. table.concat(given, ", "))
		end
	end
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
