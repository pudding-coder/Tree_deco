-- 트리 효과 상점: 코인으로 트리 효과·바닥 아이템을 사고, 산 것을 켜고 끈다
-- 꾸미기 전용 (수입·트리 가치에 영향 없음). GAME_RULES.md '트리 효과 상점'
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Catalog = require(Shared:WaitForChild("Catalog"))
local Remotes = ReplicatedStorage:WaitForChild("Remotes")

local PlayerData = require(script.Parent.PlayerData)
local GachaService = require(script.Parent.GachaService)
local TreeService = require(script.Parent.TreeService)

local TreeEffectService = {}

local function fail(reason: string)
	return { ok = false, reason = reason }
end

local function ok(player: Player, extra)
	TreeService.RefreshEffects(player)
	local result = extra or {}
	result.ok = true
	result.state = GachaService.BuildState(player)
	return result
end

-- 켠다. 효과는 하나만이라 바꿔 끼우고, 바닥은 자리가 남아 있을 때만 켠다
local function turnOn(profile, fx): string?
	if fx.area == "Effect" then
		profile.effect = fx.id
		return nil
	end
	if table.find(profile.floor, fx.id) then
		return nil
	end
	if #profile.floor >= Config.MAX_FLOOR_ITEMS then
		return string.format("바닥 아이템은 %d개까지 켤 수 있습니다. 하나를 끄고 다시 눌러 주세요", Config.MAX_FLOOR_ITEMS)
	end
	table.insert(profile.floor, fx.id)
	return nil
end

local function onBuy(player: Player, id: any)
	local fx = type(id) == "string" and Catalog.TreeEffectById[id]
	if not fx then
		return fail("잘못된 요청입니다")
	end
	local profile = PlayerData.Get(player)
	if not profile then
		return fail("데이터를 불러오는 중입니다")
	end
	if profile.ownedEffects[fx.id] then
		return fail("이미 가지고 있습니다")
	end
	if fx.retired then
		return fail("지금은 팔지 않습니다")
	end
	if not fx.cost then
		return fail("로벅스 구매는 준비 중입니다")
	end
	if profile.coins < fx.cost then
		return fail("코인이 부족합니다")
	end

	PlayerData.AddCoins(player, -fx.cost)
	profile.ownedEffects[fx.id] = true
	-- 사면 바로 켠다 (바닥 자리가 꽉 찼으면 산 것만 하고 켜지는 않는다)
	local reason = turnOn(profile, fx)
	return ok(player, { equipped = reason == nil, coinsSpent = fx.cost, note = reason })
end

local function onSet(player: Player, id: any, on: any)
	local fx = type(id) == "string" and Catalog.TreeEffectById[id]
	if not fx or type(on) ~= "boolean" then
		return fail("잘못된 요청입니다")
	end
	local profile = PlayerData.Get(player)
	if not profile then
		return fail("데이터를 불러오는 중입니다")
	end
	if not profile.ownedEffects[fx.id] then
		return fail("먼저 사 주세요")
	end

	if on then
		local reason = turnOn(profile, fx)
		if reason then
			return fail(reason)
		end
	elseif fx.area == "Effect" then
		if profile.effect == fx.id then
			profile.effect = nil
		end
	else
		local index = table.find(profile.floor, fx.id)
		if index then
			table.remove(profile.floor, index)
		end
	end
	return ok(player)
end

function TreeEffectService.Init()
	Remotes.BuyTreeEffect.OnServerInvoke = onBuy
	Remotes.SetTreeEffect.OnServerInvoke = onSet
end

return TreeEffectService
