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

-- amount: 1 이상 정수, 또는 "all"(그 등급 전부)
local function onSell(player: Player, rarityIndex: any, amount: any)
	if not isWholeNumber(rarityIndex, 1, Rarity.Count) then
		return fail("잘못된 요청이에요")
	end
	local profile, reason = getReadyProfile(player)
	if not profile then
		return fail(reason)
	end
	if profile.locked[rarityIndex] then
		return fail("잠긴 장식은 팔 수 없어요")
	end

	local have = profile.bag[rarityIndex]
	if have <= 0 then
		return fail("팔 장식이 없어요")
	end

	local count
	if amount == "all" then
		count = have
	elseif isWholeNumber(amount, 1, math.huge) then
		count = math.min(amount, have)
	else
		return fail("잘못된 요청이에요")
	end

	local gained = Gacha.GetSellPrice(rarityIndex) * count
	profile.bag[rarityIndex] = have - count
	PlayerData.AddCoins(player, gained)

	return {
		ok = true,
		rarity = rarityIndex,
		sold = count,
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
