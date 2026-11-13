-- 장식·특성 카탈로그: Decorations.luau와 Traits.luau를 읽고 검사한다.
-- 잘못 적은 곳이 있으면 게임이 시작될 때 Output에 빨간 글씨로 어디가 틀렸는지 알려준다.
local Rarity = require(script.Parent.Rarity)

local rawDecorations = require(script.Decorations)
local rawTraits = require(script.Traits)

local Catalog = {}

Catalog.AREAS = {
	Topper = "토퍼",
	Ornament = "오너먼트",
	Garland = "띠",
}

local rarityIndexById = {}
for i, r in Rarity.List do
	rarityIndexById[r.id] = i
end

local problems = {}
local function problem(where: string, message: string)
	table.insert(problems, where .. ": " .. message)
end

local function isValidId(id): boolean
	return type(id) == "string" and string.match(id, "^%a[%w_]*$") ~= nil
end

local function isNonEmptyString(value): boolean
	return type(value) == "string" and value ~= ""
end

----------------------------------------------------------------
-- 장식
----------------------------------------------------------------

Catalog.Decorations = {} -- 파일에 적힌 순서
Catalog.DecorationById = {}
Catalog.DecorationsByRarity = {} -- [등급 번호] = { 뽑힐 수 있는 장식 } (retired 제외)
for i = 1, Rarity.Count do
	Catalog.DecorationsByRarity[i] = {}
end

for index, deco in rawDecorations do
	local where = string.format("Decorations.luau %d번째 줄(id=%s)", index, tostring(type(deco) == "table" and deco.id))
	if type(deco) ~= "table" then
		problem(where, "{ id = ..., name = ..., ... } 형태가 아니에요")
		continue
	end

	local before = #problems
	if not isValidId(deco.id) then
		problem(where, "id는 영문으로 시작하고 영문·숫자·_만 쓸 수 있어요")
	elseif Catalog.DecorationById[deco.id] then
		problem(where, "id가 다른 장식과 겹쳐요")
	end
	if not isNonEmptyString(deco.name) then
		problem(where, "name(화면에 보이는 이름)이 비어 있어요")
	end
	local rarityIndex = rarityIndexById[deco.rarity]
	if not rarityIndex then
		problem(where, "rarity는 Common, Uncommon, Rare, Epic, Legendary, Mystic, Secret 중 하나여야 해요")
	end
	if not Catalog.AREAS[deco.area] then
		problem(where, "area는 Topper, Ornament, Garland 중 하나여야 해요")
	end
	if deco.weight ~= nil and (type(deco.weight) ~= "number" or deco.weight <= 0) then
		problem(where, "weight는 0보다 큰 숫자여야 해요")
	end
	if deco.model ~= nil and not isNonEmptyString(deco.model) then
		problem(where, "model은 모델 이름(글자)이어야 해요")
	end

	if #problems == before then
		local entry = {
			id = deco.id,
			name = deco.name,
			rarity = rarityIndex,
			area = deco.area,
			weight = deco.weight or 1,
			model = deco.model,
			retired = deco.retired == true,
		}
		table.insert(Catalog.Decorations, entry)
		Catalog.DecorationById[entry.id] = entry
		if not entry.retired then
			table.insert(Catalog.DecorationsByRarity[rarityIndex], entry)
		end
	end
end

for i, r in Rarity.List do
	local pool = Catalog.DecorationsByRarity[i]
	if #pool == 0 then
		problem("Decorations.luau", string.format("%s(%s) 등급에 뽑힐 수 있는 장식이 하나도 없어요", r.name, r.id))
	end
end

----------------------------------------------------------------
-- 특성
----------------------------------------------------------------

Catalog.Traits = {} -- 파일에 적힌 순서
Catalog.TraitById = {}
Catalog.BaseTrait = nil -- n이 없는 기본 특성

local baseCount = 0
local probabilitySum = 0
for index, trait in rawTraits do
	local where = string.format("Traits.luau %d번째 줄(id=%s)", index, tostring(type(trait) == "table" and trait.id))
	if type(trait) ~= "table" then
		problem(where, "{ id = ..., name = ..., ... } 형태가 아니에요")
		continue
	end

	local before = #problems
	if not isValidId(trait.id) then
		problem(where, "id는 영문으로 시작하고 영문·숫자·_만 쓸 수 있어요")
	elseif Catalog.TraitById[trait.id] then
		problem(where, "id가 다른 특성과 겹쳐요")
	end
	if not isNonEmptyString(trait.name) then
		problem(where, "name(화면에 보이는 이름)이 비어 있어요")
	end
	if type(trait.mult) ~= "number" or trait.mult <= 0 then
		problem(where, "mult(가치 배수)는 0보다 큰 숫자여야 해요")
	end
	if trait.n ~= nil and (type(trait.n) ~= "number" or trait.n <= 1) then
		problem(where, "n은 1보다 큰 숫자여야 해요 (10이면 1/10 확률)")
	end

	if #problems == before then
		local entry = {
			id = trait.id,
			name = trait.name,
			emoji = trait.emoji or "",
			n = trait.n,
			mult = trait.mult,
			effect = trait.effect,
			retired = trait.retired == true,
		}
		table.insert(Catalog.Traits, entry)
		Catalog.TraitById[entry.id] = entry
		if entry.n == nil then
			baseCount += 1
			Catalog.BaseTrait = entry
		elseif not entry.retired then
			probabilitySum += 1 / entry.n
		end
	end
end

if baseCount ~= 1 then
	problem("Traits.luau", string.format("n을 비워 둔 기본 특성이 정확히 1개여야 해요 (지금 %d개)", baseCount))
end
if probabilitySum >= 1 then
	problem("Traits.luau", "특성 확률(1/n)을 모두 더하면 100%를 넘어요. n을 키워 주세요")
end

if #problems > 0 then
	error("\n[카탈로그 오류] 아래를 고쳐 주세요\n- " .. table.concat(problems, "\n- "), 0)
end

----------------------------------------------------------------
-- 뽑기 (서버에서만 호출)
----------------------------------------------------------------

-- 해당 등급의 장식 중 하나를 weight 비율로 뽑는다
function Catalog.RollDecoration(rarityIndex: number, rng: Random)
	local pool = Catalog.DecorationsByRarity[rarityIndex]
	local total = 0
	for _, deco in pool do
		total += deco.weight
	end
	local r = rng:NextNumber() * total
	for _, deco in pool do
		r -= deco.weight
		if r < 0 then
			return deco
		end
	end
	return pool[#pool]
end

-- 특성 하나를 뽑는다
function Catalog.RollTrait(rng: Random)
	local r = rng:NextNumber()
	local acc = 0
	for _, trait in Catalog.Traits do
		if trait.n and not trait.retired then
			acc += 1 / trait.n
			if r < acc then
				return trait
			end
		end
	end
	return Catalog.BaseTrait
end

return Catalog
