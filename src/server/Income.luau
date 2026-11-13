-- 트리 가치와 전시 수익 계산 (GAME_RULES.md '전시·수익')
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Gacha = require(Shared:WaitForChild("Gacha"))
local Catalog = require(Shared:WaitForChild("Catalog"))

local Income = {}

-- 트리 가치 = 걸린 장식 가치의 합 (카탈로그에 없는 장식은 0)
function Income.GetTreeValue(profile): number
	local total = 0
	for _, entry in profile.tree do
		local deco = Catalog.DecorationById[entry.d]
		local trait = Catalog.TraitById[entry.t]
		if deco and trait then
			total += Gacha.GetItemValue(deco.rarity, trait.mult)
		end
	end
	return total
end

-- 이번 접속에서 전시한 시간(분)
function Income.GetDisplayMinutes(profile): number
	return (workspace:GetServerTimeNow() - profile.displayStartedAt) / 60
end

-- 초당 수입
function Income.GetPerSec(profile): number
	if not profile then
		return 0
	end
	return Gacha.GetIncomePerSec(Income.GetTreeValue(profile), profile.votes, Income.GetDisplayMinutes(profile))
end

return Income
