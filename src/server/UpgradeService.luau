-- 업그레이드: 행운 · 속도 (코인으로 단계 올리기) · 물약 (코인으로 사는 시간제 버프)
-- GAME_RULES.md '재화·업그레이드'
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Gacha = require(Shared:WaitForChild("Gacha"))
local Remotes = ReplicatedStorage:WaitForChild("Remotes")

local PlayerData = require(script.Parent.PlayerData)
local GachaService = require(script.Parent.GachaService)

local UpgradeService = {}

-- 업그레이드 종류별 레벨 칸과 비용표
local UPGRADES = {
	luck = { field = "luckLevel", costs = Config.LUCK_COST },
	speed = { field = "speedLevel", costs = Config.SPEED_COST },
}

local function fail(reason: string)
	return { ok = false, reason = reason }
end

local function onUpgrade(player: Player, kind: any)
	local upgrade = UPGRADES[kind]
	if type(kind) ~= "string" or not upgrade then
		return fail("잘못된 요청입니다")
	end
	local profile = PlayerData.Get(player)
	if not profile then
		return fail("데이터를 불러오는 중입니다")
	end

	local level = profile[upgrade.field]
	local cost = upgrade.costs[level + 1]
	if not cost then
		return fail("이미 최대 단계입니다")
	end
	if profile.coins < cost then
		return fail("코인이 부족합니다")
	end

	PlayerData.AddCoins(player, -cost)
	profile[upgrade.field] = level + 1

	return {
		ok = true,
		kind = kind,
		level = level + 1,
		state = GachaService.BuildState(player),
	}
end

local function onBuyPotion(player: Player)
	local profile = PlayerData.Get(player)
	if not profile then
		return fail("데이터를 불러오는 중입니다")
	end

	local cost = Gacha.GetPotionCost(GachaService.GetIncomePerSec(player))
	if profile.coins < cost then
		return fail("코인이 부족합니다")
	end

	PlayerData.AddCoins(player, -cost)
	-- 이미 켜져 있으면 남은 시간에 더한다
	local now = workspace:GetServerTimeNow()
	profile.potionEndsAt = math.max(profile.potionEndsAt, now) + Config.POTION_DURATION

	return { ok = true, state = GachaService.BuildState(player) }
end

function UpgradeService.Init()
	Remotes.Upgrade.OnServerInvoke = onUpgrade
	Remotes.BuyPotion.OnServerInvoke = onBuyPotion
end

return UpgradeService
