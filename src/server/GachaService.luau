-- 룰렛(뽑기) 서버 처리. 결과는 항상 서버에서 정한다.
-- 한 번 돌리면 레어도 → 장식 → 특성 순서로 정해진다.
local MessagingService = game:GetService("MessagingService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Rarity = require(Shared:WaitForChild("Rarity"))
local Gacha = require(Shared:WaitForChild("Gacha"))
local Catalog = require(Shared:WaitForChild("Catalog"))
local Remotes = ReplicatedStorage:WaitForChild("Remotes")

local PlayerData = require(script.Parent.PlayerData)

local GachaService = {}

local GLOBAL_TOPIC = "TreeDeco_GlobalAnnounce"
local rng = Random.new()

local function now(): number
	return workspace:GetServerTimeNow()
end

-- 물약·게임패스가 들어오면 여기서 부스트 배수를 돌려준다.
local function getLuckBoost(_player: Player): number
	return 1
end

local function getSpeedBoost(_player: Player): number
	return 1
end

-- 전시 수익이 들어오면 여기서 초당 수입을 돌려준다.
local function getIncomePerSec(_player: Player): number
	return 0
end

local function getLuck(player: Player, profile): number
	return Gacha.GetLuckMultiplier(profile.luckLevel, getLuckBoost(player))
end

-- 클라이언트 화면에 필요한 값
function GachaService.BuildState(player: Player)
	local profile = PlayerData.Get(player)
	if not profile then
		return nil
	end
	local luck = getLuck(player, profile)
	local speedBoost = getSpeedBoost(player)

	-- 카탈로그에 있는 칸만 보낸다
	local stacks = {}
	for _, stack in profile.stacks do
		if stack.c > 0 and PlayerData.IsKnownStack(stack) then
			table.insert(stacks, { d = stack.d, t = stack.t, c = stack.c, l = stack.l })
		end
	end

	return {
		coins = profile.coins,
		luck = luck,
		reelTime = Gacha.GetReelTime(profile.speedLevel, speedBoost),
		freeCooldown = Gacha.GetFreeCooldown(profile.speedLevel, speedBoost),
		nextFreeSpinAt = profile.nextFreeSpinAt,
		coinSpinCost = Gacha.GetCoinSpinCost(luck, getIncomePerSec(player)),
		stacks = stacks,
		bagUsed = #stacks,
		bagCapacity = profile.bagCapacity,
		autoSellMax = profile.autoSellMax,
	}
end

----------------------------------------------------------------
-- 공지
----------------------------------------------------------------

local function announceToServer(playerName: string, decoId: string, traitId: string, isGlobal: boolean)
	Remotes.Announce:FireAllClients({
		playerName = playerName,
		decoId = decoId,
		traitId = traitId,
		global = isGlobal,
	})
end

local function publishGlobal(playerName: string, decoId: string, traitId: string)
	task.spawn(function()
		local ok, err = pcall(function()
			MessagingService:PublishAsync(GLOBAL_TOPIC, {
				jobId = game.JobId,
				playerName = playerName,
				decoId = decoId,
				traitId = traitId,
			})
		end)
		if not ok then
			warn("[Gacha] 전체 서버 공지 실패:", err)
		end
	end)
end

local function onGlobalMessage(message)
	local data = message.Data
	if type(data) ~= "table" then
		return
	end
	if data.jobId == game.JobId then
		return -- 우리 서버 공지는 이미 보냈다
	end
	-- 다른 버전의 서버가 보낸, 이 서버가 모르는 장식이면 무시한다
	if not Catalog.DecorationById[data.decoId] or not Catalog.TraitById[data.traitId] then
		return
	end
	announceToServer(tostring(data.playerName), data.decoId, data.traitId, true)
end

----------------------------------------------------------------
-- 돌리기
----------------------------------------------------------------

local function fail(reason: string)
	return { ok = false, reason = reason }
end

local function onSpin(player: Player, kind: any)
	if kind ~= "free" and kind ~= "coin" then
		return fail("잘못된 요청입니다")
	end

	local profile = PlayerData.Get(player)
	if not profile then
		return fail("데이터를 불러오는 중입니다")
	end

	local t = now()
	if t < profile.busyUntil then
		return fail("룰렛이 돌아가는 중입니다")
	end
	if PlayerData.GetBagSlotsUsed(profile) >= profile.bagCapacity then
		return fail("가방이 가득 찼습니다. 판매하거나 확장해 주십시오")
	end

	local luck = getLuck(player, profile)
	local speedBoost = getSpeedBoost(player)

	if kind == "free" then
		if t < profile.nextFreeSpinAt then
			return fail("무료 룰렛을 기다리는 중입니다")
		end
		profile.nextFreeSpinAt = t + Gacha.GetFreeCooldown(profile.speedLevel, speedBoost)
	else
		local cost = Gacha.GetCoinSpinCost(luck, getIncomePerSec(player))
		if profile.coins < cost then
			return fail("코인이 부족합니다")
		end
		PlayerData.AddCoins(player, -cost)
	end

	local reelTime = Gacha.GetReelTime(profile.speedLevel, speedBoost)
	profile.busyUntil = t + reelTime - 0.05

	local rarityIndex = Gacha.Roll(luck, rng)
	local deco = Catalog.RollDecoration(rarityIndex, rng)
	local trait = Catalog.RollTrait(rng)
	local coinsAfterCost = profile.coins

	-- 자동 판매: 지정한 등급 이하이고, 그 칸이 잠기지 않았고, (설정에 따라) 특성이 없을 때
	local key = PlayerData.StackKey(deco.id, trait.id)
	local existing = PlayerData.FindStack(profile, key)
	local isLocked = if existing
		then existing.l
		else rarityIndex >= Config.DEFAULT_LOCK_MIN_RARITY
	local traitAllowed = trait == Catalog.BaseTrait or not Config.AUTO_SELL_ONLY_BASE_TRAIT

	local saleCoins = 0
	if rarityIndex <= profile.autoSellMax and not isLocked and traitAllowed then
		saleCoins = Gacha.GetSellPrice(rarityIndex, trait.mult)
		PlayerData.AddCoins(player, saleCoins)
	else
		PlayerData.AddItem(profile, deco, trait, 1)
	end

	-- 공지는 슬롯이 멈춘 뒤에 띄운다 (결과를 미리 알리지 않도록)
	if rarityIndex >= Config.SERVER_ANNOUNCE_MIN_RARITY then
		local playerName = player.DisplayName
		local isGlobal = rarityIndex >= Config.GLOBAL_ANNOUNCE_MIN_RARITY
		task.delay(reelTime, function()
			announceToServer(playerName, deco.id, trait.id, isGlobal)
			if isGlobal then
				publishGlobal(playerName, deco.id, trait.id)
			end
		end)
	end

	return {
		ok = true,
		rarity = rarityIndex,
		decoId = deco.id,
		traitId = trait.id,
		reelTime = reelTime,
		autoSold = saleCoins > 0,
		saleCoins = saleCoins,
		coinsAfterCost = coinsAfterCost, -- 결과가 드러나기 전에 보여줄 코인
		state = GachaService.BuildState(player),
	}
end

function GachaService.Init()
	Remotes.Spin.OnServerInvoke = onSpin
	Remotes.GetState.OnServerInvoke = function(player)
		return GachaService.BuildState(player)
	end

	task.spawn(function()
		local ok, err = pcall(function()
			MessagingService:SubscribeAsync(GLOBAL_TOPIC, onGlobalMessage)
		end)
		if not ok then
			warn("[Gacha] 전체 서버 공지 구독 실패 (Studio에서는 정상일 수 있음):", err)
		end
	end)
end

return GachaService
