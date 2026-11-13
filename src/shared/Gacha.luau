-- 룰렛 공식 (GAME_RULES.md '룰렛', '행운', '업그레이드')
-- 서버는 뽑기에, 클라이언트는 확률 표시에 같은 공식을 쓴다.
local Config = require(script.Parent.Config)
local Rarity = require(script.Parent.Rarity)

local Gacha = {}

-- 행운 배수 = min(LUCK_MULT[레벨] × min(부스트, BOOST_LUCK_CAP), LUCK_TOTAL_CAP)
function Gacha.GetLuckMultiplier(luckLevel: number, boost: number?): number
	local boostMult = math.min(boost or 1, Config.BOOST_LUCK_CAP)
	local mult = (Config.LUCK_MULT[luckLevel] or 1) * boostMult
	return math.min(mult, Config.LUCK_TOTAL_CAP)
end

-- 실제 멈춤 시간 = REEL_STOP_TIME × SPEED_TIME_MULT[레벨] × 속도 부스트
function Gacha.GetReelTime(speedLevel: number, speedBoost: number?): number
	return Config.REEL_STOP_TIME * (Config.SPEED_TIME_MULT[speedLevel] or 1) * (speedBoost or 1)
end

-- 실제 무료 쿨타임 = FREE_SPIN_COOLDOWN × SPEED_COOLDOWN_MULT[레벨] × 속도 부스트
function Gacha.GetFreeCooldown(speedLevel: number, speedBoost: number?): number
	return Config.FREE_SPIN_COOLDOWN * (Config.SPEED_COOLDOWN_MULT[speedLevel] or 1) * (speedBoost or 1)
end

-- 코인 룰렛 비용 = max(COIN_SPIN_MIN_COST × 행운 배수, 초당 수입 × COIN_SPIN_INCOME_SEC)
function Gacha.GetCoinSpinCost(luckMult: number, incomePerSec: number?): number
	local byLuck = Config.COIN_SPIN_MIN_COST * luckMult
	local byIncome = (incomePerSec or 0) * Config.COIN_SPIN_INCOME_SEC
	return math.ceil(math.max(byLuck, byIncome))
end

-- 코인 물약 가격 = max(POTION_MIN_COST, 초당 수입 × POTION_COST_INCOME_SEC)
function Gacha.GetPotionCost(incomePerSec: number?): number
	return math.ceil(math.max(Config.POTION_MIN_COST, (incomePerSec or 0) * Config.POTION_COST_INCOME_SEC))
end

-- 등급별 확률. 레어 이상은 행운 배수를 곱하고, 늘어난 만큼 커먼에서 뺀다.
function Gacha.GetProbabilities(luckMult: number): { number }
	local probs = table.create(Rarity.Count, 0)
	local others = 0
	for i = 2, Rarity.Count do
		local p = 1 / Rarity.List[i].n
		if i >= Config.LUCK_MIN_RARITY then
			p *= luckMult
		end
		probs[i] = p
		others += p
	end
	probs[1] = math.max(0, 1 - others)
	return probs
end

-- 장식 가치 = 레어도 기본 가치 × 특성 배수 (소수점 버림)
function Gacha.GetItemValue(rarityIndex: number, traitMult: number): number
	return math.floor(Rarity.List[rarityIndex].value * traitMult)
end

-- 판매 가격 = 장식 가치 × SELL_RATE (소수점 버림, 최소 1코인)
function Gacha.GetSellPrice(rarityIndex: number, traitMult: number): number
	return math.max(1, math.floor(Gacha.GetItemValue(rarityIndex, traitMult) * Config.SELL_RATE))
end

-- 등급 번호(1~7)를 하나 뽑는다. 서버에서만 호출한다.
function Gacha.Roll(luckMult: number, rng: Random): number
	local probs = Gacha.GetProbabilities(luckMult)
	local r = rng:NextNumber()
	local acc = 0
	for i = Rarity.Count, 1, -1 do
		acc += probs[i]
		if r < acc then
			return i
		end
	end
	return 1
end

-- 1234567 -> "1,234,567"
function Gacha.FormatNumber(n: number): string
	local s = tostring(math.floor(n))
	local sign = ""
	if string.sub(s, 1, 1) == "-" then
		sign = "-"
		s = string.sub(s, 2)
	end
	local out = string.reverse((string.gsub(string.reverse(s), "(%d%d%d)", "%1,")))
	if string.sub(out, 1, 1) == "," then
		out = string.sub(out, 2)
	end
	return sign .. out
end

-- 확률을 "1/N" 표기로 바꾼다.
function Gacha.FormatOdds(p: number): string
	if p <= 0 then
		return "-"
	end
	local n = 1 / p
	if n < 10 then
		return string.format("1/%.1f", n)
	end
	return "1/" .. Gacha.FormatNumber(n + 0.5)
end

return Gacha
