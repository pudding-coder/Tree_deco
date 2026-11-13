-- 플레이어 데이터 (지금은 메모리에만 있음. 나가면 사라진다 → DataStore 저장은 다음 단계)
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Rarity = require(Shared:WaitForChild("Rarity"))

local PlayerData = {}

local profiles = {}

local function newProfile()
	return {
		coins = if RunService:IsStudio() then Config.STUDIO_START_COINS else Config.START_COINS,
		luckLevel = 0,
		speedLevel = 0,
		bag = table.create(Rarity.Count, 0), -- 등급 번호 -> 개수 (같은 등급끼리 1칸에 쌓임)
		bagCapacity = Config.BAG_BASE_SLOTS,
		nextFreeSpinAt = 0, -- 서버 시각(workspace:GetServerTimeNow())
		busyUntil = 0, -- 룰렛 연출이 끝나는 서버 시각
	}
end

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

local function onPlayerAdded(player: Player)
	local profile = newProfile()
	profiles[player] = profile

	local leaderstats = Instance.new("Folder")
	leaderstats.Name = "leaderstats"

	local coinsValue = Instance.new("IntValue")
	coinsValue.Name = "Coins"
	coinsValue.Value = profile.coins
	coinsValue.Parent = leaderstats

	leaderstats.Parent = player
end

local function onPlayerRemoving(player: Player)
	profiles[player] = nil
end

function PlayerData.Init()
	Players.PlayerAdded:Connect(onPlayerAdded)
	Players.PlayerRemoving:Connect(onPlayerRemoving)
	for _, player in Players:GetPlayers() do
		if not profiles[player] then
			onPlayerAdded(player)
		end
	end
end

return PlayerData
