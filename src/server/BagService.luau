-- 가방: 판매 · 잠금 · 자동 판매 설정 (GAME_RULES.md '가방')
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Rarity = require(Shared:WaitForChild("Rarity"))
local Gacha = require(Shared:WaitForChild("Gacha"))
local Remotes = ReplicatedStorage:WaitForChild("Remotes")

local PlayerData = require(script.Parent.PlayerData)
local GachaService = require(script.Parent.GachaService)

local BagService = {}

local function fail(reason: string)
	return { ok = false, reason = reason }
end

local function isWholeNumber(value: any, min: number, max: number): boolean
	return type(value) == "number" and value % 1 == 0 and value >= min and value <= max
end

local function getReadyProfile(player: Player)
	local profile = PlayerData.Get(player)
	if not profile then
		return nil, "데이터를 불러오는 중이에요"
	end
	-- 슬롯이 돌아가는 중에 가방을 바꾸면 결과가 미리 보이므로 막는다
	if workspace:GetServerTimeNow() < profile.busyUntil then
		return nil, "룰렛이 멈춘 뒤에 할 수 있어요"
	end
	return profile, nil
end

-- 잠기지 않은 장식을 모두 판다
local function onSell(player: Player)
	local profile, reason = getReadyProfile(player)
	if not profile then
		return fail(reason)
	end

	local sold = 0
	local gained = 0
	for i = 1, Rarity.Count do
		local count = profile.bag[i]
		if count > 0 and not profile.locked[i] then
			sold += count
			gained += Gacha.GetSellPrice(i) * count
			profile.bag[i] = 0
		end
	end
	if sold == 0 then
		return fail("팔 장식이 없어요")
	end
	PlayerData.AddCoins(player, gained)

	return {
		ok = true,
		sold = sold,
		gained = gained,
		state = GachaService.BuildState(player),
	}
end

local function onSetLock(player: Player, rarityIndex: any, locked: any)
	if not isWholeNumber(rarityIndex, 1, Rarity.Count) or type(locked) ~= "boolean" then
		return fail("잘못된 요청이에요")
	end
	local profile = PlayerData.Get(player)
	if not profile then
		return fail("데이터를 불러오는 중이에요")
	end
	profile.locked[rarityIndex] = locked
	return { ok = true, state = GachaService.BuildState(player) }
end

-- level: 0(끔) ~ AUTO_SELL_MAX_OPTION. 이 등급 이하를 자동 판매한다.
local function onSetAutoSell(player: Player, level: any)
	if not isWholeNumber(level, 0, Config.AUTO_SELL_MAX_OPTION) then
		return fail("잘못된 요청이에요")
	end
	local profile = PlayerData.Get(player)
	if not profile then
		return fail("데이터를 불러오는 중이에요")
	end
	profile.autoSellMax = level
	return { ok = true, state = GachaService.BuildState(player) }
end

function BagService.Init()
	Remotes.Sell.OnServerInvoke = onSell
	Remotes.SetLock.OnServerInvoke = onSetLock
	Remotes.SetAutoSell.OnServerInvoke = onSetAutoSell
end

return BagService
