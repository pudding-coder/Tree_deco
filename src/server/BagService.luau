-- 가방: 판매 · 잠금 · 자동 판매 설정 (GAME_RULES.md '가방')
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Gacha = require(Shared:WaitForChild("Gacha"))
local Catalog = require(Shared:WaitForChild("Catalog"))
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
		return nil, "데이터를 불러오는 중입니다"
	end
	-- 슬롯이 돌아가는 중에 가방을 바꾸면 결과가 미리 보이므로 막는다
	if workspace:GetServerTimeNow() < profile.busyUntil then
		return nil, "룰렛이 멈춘 뒤에 할 수 있습니다"
	end
	return profile, nil
end

local function sellPrice(stack): number
	local deco = Catalog.DecorationById[stack.d]
	local trait = Catalog.TraitById[stack.t]
	return Gacha.GetSellPrice(deco.rarity, trait.mult)
end

-- key가 없으면 잠기지 않은 칸을 모두 팔고, 있으면 그 칸만 전부 판다
local function onSell(player: Player, key: any)
	if key ~= nil and type(key) ~= "string" then
		return fail("잘못된 요청이에요")
	end
	local profile, reason = getReadyProfile(player)
	if not profile then
		return fail(reason)
	end

	local sold = 0
	local gained = 0
	for _, stack in profile.stacks do
		if stack.c <= 0 or stack.l or not PlayerData.IsKnownStack(stack) then
			continue
		end
		if key ~= nil and PlayerData.StackKey(stack.d, stack.t) ~= key then
			continue
		end
		sold += stack.c
		gained += sellPrice(stack) * stack.c
		stack.c = 0
	end

	if sold == 0 then
<<<<<<< HEAD
		if key ~= nil then
			local stack = PlayerData.FindStack(profile, key)
			if stack and stack.l then
				return fail("잠긴 장식은 팔 수 없어요")
			end
		end
		return fail("팔 장식이 없어요")
=======
		return fail("팔 장식이 없습니다")
>>>>>>> 7f122a4 (말투 수정해떠욤)
	end

	PlayerData.RemoveEmptyStacks(profile)
	PlayerData.AddCoins(player, gained)

	return {
		ok = true,
		sold = sold,
		gained = gained,
		state = GachaService.BuildState(player),
	}
end

<<<<<<< HEAD
local function onSetLock(player: Player, key: any, locked: any)
	if type(key) ~= "string" or type(locked) ~= "boolean" then
		return fail("잘못된 요청이에요")
=======
local function onSetLock(player: Player, rarityIndex: any, locked: any)
	if not isWholeNumber(rarityIndex, 1, Rarity.Count) or type(locked) ~= "boolean" then
		return fail("잘못된 요청입니다")
>>>>>>> 7f122a4 (말투 수정해떠욤)
	end
	local profile = PlayerData.Get(player)
	if not profile then
		return fail("데이터를 불러오는 중입니다")
	end
	local stack = PlayerData.FindStack(profile, key)
	if not stack or not PlayerData.IsKnownStack(stack) then
		return fail("가방에 없는 장식이에요")
	end
	stack.l = locked
	return { ok = true, state = GachaService.BuildState(player) }
end

-- level: 0(끔) ~ AUTO_SELL_MAX_OPTION. 이 등급 이하를 자동 판매한다.
local function onSetAutoSell(player: Player, level: any)
	if not isWholeNumber(level, 0, Config.AUTO_SELL_MAX_OPTION) then
		return fail("잘못된 요청입니다")
	end
	local profile = PlayerData.Get(player)
	if not profile then
		return fail("데이터를 불러오는 중입니다")
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
