-- 룰렛(뽑기) 서버 처리. 결과는 항상 서버에서 정한다.
local MessagingService = game:GetService("MessagingService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Rarity = require(Shared:WaitForChild("Rarity"))
local Gacha = require(Shared:WaitForChild("Gacha"))
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
	return {
		coins = profile.coins,
		luck = luck,
		reelTime = Gacha.GetReelTime(profile.speedLevel, speedBoost),
		freeCooldown = Gacha.GetFreeCooldown(profile.speedLevel, speedBoost),
		nextFreeSpinAt = profile.nextFreeSpinAt,
		coinSpinCost = Gacha.GetCoinSpinCost(luck, getIncomePerSec(player)),
		bag = table.clone(profile.bag),
		bagUsed = PlayerData.GetBagSlotsUsed(profile),
		bagCapacity = profile.bagCapacity,
	}
end

local function announceToServer(playerName: string, rarityIndex: number, isGlobal: boolean)
	Remotes.Announce:FireAllClients({
		playerName = playerName,
		rarity = rarityIndex,
		global = isGlobal,
	})
end

local function publishGlobal(playerName: string, rarityIndex: number)
	task.spawn(function()
		local ok, err = pcall(function()
			MessagingService:PublishAsync(GLOBAL_TOPIC, {
				jobId = game.JobId,
				playerName = playerName,
				rarity = rarityIndex,
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
	if type(data.rarity) ~= "number" or not Rarity.List[data.rarity] then
		return
	end
	announceToServer(tostring(data.playerName), data.rarity, true)
end

local function fail(reason: string)
	return { ok = false, reason = reason }
end

local function onSpin(player: Player, kind: any)
	if kind ~= "free" and kind ~= "coin" then
		return fail("잘못된 요청이에요")
	end

	local profile = PlayerData.Get(player)
	if not profile then
		return fail("데이터를 불러오는 중이에요")
	end

	local t = now()
	if t < profile.busyUntil then
		return fail("룰렛이 돌아가는 중이에요")
	end
	if PlayerData.GetBagSlotsUsed(profile) >= profile.bagCapacity then
		return fail("가방이 가득 찼어요. 판매하거나 확장해 주세요")
	end

	local luck = getLuck(player, profile)
	local speedBoost = getSpeedBoost(player)

	if kind == "free" then
		if t < profile.nextFreeSpinAt then
			return fail("무료 룰렛을 기다리는 중이에요")
		end
		profile.nextFreeSpinAt = t + Gacha.GetFreeCooldown(profile.speedLevel, speedBoost)
	else
		local cost = Gacha.GetCoinSpinCost(luck, getIncomePerSec(player))
		if profile.coins < cost then
			return fail("코인이 부족해요")
		end
		PlayerData.AddCoins(player, -cost)
	end

	local reelTime = Gacha.GetReelTime(profile.speedLevel, speedBoost)
	profile.busyUntil = t + reelTime - 0.05

	local rarityIndex = Gacha.Roll(luck, rng)
	profile.bag[rarityIndex] += 1

	-- 공지는 슬롯이 멈춘 뒤에 띄운다 (결과를 미리 알리지 않도록)
	if rarityIndex >= Config.SERVER_ANNOUNCE_MIN_RARITY then
		local playerName = player.DisplayName
		local isGlobal = rarityIndex >= Config.GLOBAL_ANNOUNCE_MIN_RARITY
		task.delay(reelTime, function()
			announceToServer(playerName, rarityIndex, isGlobal)
			if isGlobal then
				publishGlobal(playerName, rarityIndex)
			end
		end)
	end

	return {
		ok = true,
		rarity = rarityIndex,
		reelTime = reelTime,
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
