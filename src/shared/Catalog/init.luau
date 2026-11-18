-- 장식·특성 카탈로그: Decorations.luau와 Traits.luau를 읽고 검사한다.
-- 잘못 적은 곳이 있으면 게임이 시작될 때 Output에 빨간 글씨로 어디가 틀렸는지 알려준다.
local Rarity = require(script.Parent.Rarity)
local Config = require(script.Parent.Config)

local rawDecorations = require(script.Decorations)
local rawTraits = require(script.Traits)
local rawPaints = require(script.Paints)
local rawTreeEffects = require(script.TreeEffects)

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
	if deco.size ~= nil and (type(deco.size) ~= "number" or deco.size <= 0) then
		problem(where, "size는 0보다 큰 숫자여야 해요 (1이면 기본 크기, 1.5면 1.5배)")
	end
	if deco.turn ~= nil and type(deco.turn) ~= "number" then
		problem(where, "turn은 숫자(도)여야 해요. 예: turn = 180")
	end
	if deco.lean ~= nil and type(deco.lean) ~= "number" then
		problem(where, "lean은 숫자(도)여야 해요. 예: lean = 30")
	end
	if deco.lean ~= nil and deco.area ~= "Ornament" then
		problem(where, "lean은 Ornament(가지) 장식에만 쓸 수 있어요")
	end
	if deco.out ~= nil and type(deco.out) ~= "number" then
		problem(where, "out은 숫자(스터드)여야 해요. 예: out = 0.4")
	end
	if deco.out ~= nil and deco.area ~= "Ornament" then
		problem(where, "out은 Ornament(가지) 장식에만 쓸 수 있어요")
	end
	if deco.sink ~= nil and (type(deco.sink) ~= "number" or deco.sink < 0 or deco.sink > 1) then
		problem(where, "sink는 0에서 1 사이 숫자여야 해요 (0.5면 모델 높이의 절반이 꼭대기 아래로 내려가요)")
	end
	if deco.sink ~= nil and deco.area ~= "Topper" then
		problem(where, "sink는 Topper(꼭대기) 장식에만 쓸 수 있어요")
	end
	if deco.paintable ~= nil and type(deco.paintable) ~= "boolean" then
		problem(where, "paintable은 true 또는 false여야 해요")
	end
	if deco.holdable ~= nil and type(deco.holdable) ~= "boolean" then
		problem(where, "holdable은 true 또는 false여야 해요")
	end

	if #problems == before then
		local entry = {
			id = deco.id,
			name = deco.name,
			rarity = rarityIndex,
			area = deco.area,
			weight = deco.weight or 1,
			model = deco.model,
			paintable = deco.paintable == true,
			holdable = deco.holdable == true, -- 트리에 걸린 장식을 누르면 같은 모양의 사본을 손에 든다
			size = deco.size or 1,
			turn = deco.turn or 0,
			out = deco.out or 0, -- 트리에서 바깥으로 더 띄우는 거리(스터드)
			lean = deco.lean, -- 없으면 TreeService의 기본 기울기
			-- 머리카락(id가 Hair로 끝나는 토퍼)은 꼭대기에 씌운 것처럼 기본으로 절반 내려 둔다
			sink = deco.sink or ((deco.area == "Topper" and string.sub(deco.id, -4) == "Hair") and 0.5 or 0),
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

----------------------------------------------------------------
-- 칠하기 색
----------------------------------------------------------------

Catalog.Paints = {} -- 파일에 적힌 순서
Catalog.PaintById = {}
local paintPool = {} -- 뽑힐 수 있는 색 (retired 제외)

for index, paint in rawPaints do
	local where = string.format("Paints.luau %d번째 줄(id=%s)", index, tostring(type(paint) == "table" and paint.id))
	if type(paint) ~= "table" then
		problem(where, "{ id = ..., name = ..., rgb = ... } 형태가 아니에요")
		continue
	end

	local before = #problems
	if not isValidId(paint.id) then
		problem(where, "id는 영문으로 시작하고 영문·숫자·_만 쓸 수 있어요")
	elseif Catalog.PaintById[paint.id] then
		problem(where, "id가 다른 색과 겹쳐요")
	end
	if not isNonEmptyString(paint.name) then
		problem(where, "name(화면에 보이는 이름)이 비어 있어요")
	end
	local rgbOk = type(paint.rgb) == "table" and #paint.rgb == 3
	if rgbOk then
		for _, channel in paint.rgb do
			if type(channel) ~= "number" or channel < 0 or channel > 255 then
				rgbOk = false
			end
		end
	end
	if not rgbOk then
		problem(where, "rgb는 { 빨강, 초록, 파랑 } 숫자 3개(0~255)여야 해요. 예: rgb = { 255, 150, 190 }")
	end
	if paint.weight ~= nil and (type(paint.weight) ~= "number" or paint.weight <= 0) then
		problem(where, "weight는 0보다 큰 숫자여야 해요")
	end

	if #problems == before then
		local entry = {
			id = paint.id,
			name = paint.name,
			color = Color3.fromRGB(paint.rgb[1], paint.rgb[2], paint.rgb[3]),
			weight = paint.weight or 1,
			retired = paint.retired == true,
		}
		table.insert(Catalog.Paints, entry)
		Catalog.PaintById[entry.id] = entry
		if not entry.retired then
			table.insert(paintPool, entry)
		end
	end
end

local needsPaint = false
for _, deco in Catalog.Decorations do
	if deco.paintable and not deco.retired then
		needsPaint = true
	end
end
if needsPaint and #paintPool == 0 then
	problem("Paints.luau", "paintable 장식이 있는데 뽑힐 수 있는 색이 하나도 없어요")
end

----------------------------------------------------------------
-- 크기 (Config.SIZES)
----------------------------------------------------------------

Catalog.Sizes = {} -- Config에 적힌 순서
Catalog.SizeById = {}
Catalog.BaseSize = nil -- n이 없는 기본 크기 (보통)

local sizeBaseCount = 0
local sizeProbabilitySum = 0
for index, size in Config.SIZES do
	local where = string.format("Config.SIZES %d번째 줄(id=%s)", index, tostring(type(size) == "table" and size.id))
	if type(size) ~= "table" or not isValidId(size.id) or Catalog.SizeById[size.id] then
		problem(where, "id가 없거나 겹쳐요")
		continue
	end
	if not isNonEmptyString(size.name) then
		problem(where, "name이 비어 있어요")
	end
	if type(size.scale) ~= "number" or size.scale <= 0 or type(size.mult) ~= "number" or size.mult <= 0 then
		problem(where, "scale과 mult는 0보다 큰 숫자여야 해요")
	end
	if size.n ~= nil and (type(size.n) ~= "number" or size.n <= 1) then
		problem(where, "n은 1보다 큰 숫자여야 해요")
	end
	table.insert(Catalog.Sizes, size)
	Catalog.SizeById[size.id] = size
	if size.n == nil then
		sizeBaseCount += 1
		Catalog.BaseSize = size
	else
		sizeProbabilitySum += 1 / size.n
	end
end
if sizeBaseCount ~= 1 then
	problem("Config.SIZES", string.format("n을 비워 둔 기본 크기가 정확히 1개여야 해요 (지금 %d개)", sizeBaseCount))
end
if sizeProbabilitySum >= 1 then
	problem("Config.SIZES", "크기 확률(1/n)을 모두 더하면 100%를 넘어요")
end

----------------------------------------------------------------
-- 트리 효과 (상점)
----------------------------------------------------------------

Catalog.TREE_EFFECT_AREAS = {
	Effect = "트리 효과",
	Floor = "바닥",
}
Catalog.TreeEffects = {} -- 파일에 적힌 순서
Catalog.TreeEffectById = {}

for index, fx in rawTreeEffects do
	local where = string.format("TreeEffects.luau %d번째 줄(id=%s)", index, tostring(type(fx) == "table" and fx.id))
	if type(fx) ~= "table" then
		problem(where, "{ id = ..., name = ..., ... } 형태가 아니에요")
		continue
	end
	local before = #problems
	if not isValidId(fx.id) then
		problem(where, "id는 영문으로 시작하고 영문·숫자·_만 쓸 수 있어요")
	elseif Catalog.TreeEffectById[fx.id] then
		problem(where, "id가 다른 트리 효과와 겹쳐요")
	end
	if not isNonEmptyString(fx.name) then
		problem(where, "name(화면에 보이는 이름)이 비어 있어요")
	end
	if not Catalog.TREE_EFFECT_AREAS[fx.area] then
		problem(where, "area는 Effect, Floor 중 하나여야 해요")
	end
	if fx.spread ~= nil and (type(fx.spread) ~= "boolean" or fx.area ~= "Floor") then
		problem(where, "spread는 Floor(바닥)에만 true 또는 false로 쓸 수 있어요")
	end
	if fx.model ~= nil and not isNonEmptyString(fx.model) then
		problem(where, "model은 모델 이름(글자)이어야 해요")
	end
	if fx.size ~= nil and (type(fx.size) ~= "number" or fx.size <= 0) then
		problem(where, "size는 0보다 큰 숫자여야 해요")
	end
	local cost = Config.TREE_EFFECT_COST[fx.id]
	local robux = Config.TREE_EFFECT_ROBUX_PRICE[fx.id]
	if cost ~= nil and (type(cost) ~= "number" or cost < 0) then
		problem(where, "Config.TREE_EFFECT_COST의 가격은 0 이상 숫자여야 해요")
	end
	if robux ~= nil and (type(robux) ~= "number" or robux <= 0) then
		problem(where, "Config.TREE_EFFECT_ROBUX_PRICE의 가격은 0보다 큰 숫자여야 해요")
	end
	if cost == nil and robux == nil and fx.retired ~= true then
		problem(where, "Config.TREE_EFFECT_COST나 TREE_EFFECT_ROBUX_PRICE에 가격이 없어요")
	end

	if #problems == before then
		local entry = {
			id = fx.id,
			name = fx.name,
			area = fx.area,
			spread = fx.spread == true,
			model = fx.model,
			size = fx.size or 1,
			cost = cost, -- 코인 가격 (없으면 코인으로 못 삼)
			robux = robux, -- 로벅스 가격 (표시만)
			retired = fx.retired == true,
		}
		table.insert(Catalog.TreeEffects, entry)
		Catalog.TreeEffectById[entry.id] = entry
	end
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

-- 색 하나를 뽑는다 (paintable 장식일 때만 부른다)
function Catalog.RollPaint(rng: Random)
	local total = 0
	for _, paint in paintPool do
		total += paint.weight
	end
	local r = rng:NextNumber() * total
	for _, paint in paintPool do
		r -= paint.weight
		if r < 0 then
			return paint
		end
	end
	return paintPool[#paintPool]
end

-- 크기 하나를 뽑는다 (띠는 부르지 않고 보통)
function Catalog.RollSize(rng: Random)
	local r = rng:NextNumber()
	local acc = 0
	for _, size in Catalog.Sizes do
		if size.n then
			acc += 1 / size.n
			if r < acc then
				return size
			end
		end
	end
	return Catalog.BaseSize
end

-- 저장된 크기 id → 크기 (없거나 모르는 id면 보통)
function Catalog.SizeOf(sizeId: string?)
	return (sizeId and Catalog.SizeById[sizeId]) or Catalog.BaseSize
end

-- 가치 배수 = 특성 배수 × 크기 배수
function Catalog.ValueMult(trait, sizeId: string?): number
	return trait.mult * Catalog.SizeOf(sizeId).mult
end

-- 가방 칸 열쇠: 장식·특성·색·크기가 모두 같으면 한 칸에 쌓인다 (서버·클라이언트 공용)
-- 크기가 보통이면 크기를 빼서, 크기가 생기기 전 열쇠와 같다
function Catalog.StackKey(decoId: string, traitId: string, paintId: string?, sizeId: string?): string
	local key = decoId .. ":" .. traitId
	if paintId then
		key ..= ":" .. paintId
	end
	if sizeId and sizeId ~= Catalog.BaseSize.id then
		key ..= "#" .. sizeId
	end
	return key
end

-- 화면 이름: "반짝이 거대 분홍 공" (기본 특성·보통 크기·색 없음이면 그 말은 빼고)
function Catalog.ItemName(deco, trait, paintId: string?, sizeId: string?): string
	local name = deco.name
	local paint = paintId and Catalog.PaintById[paintId]
	if paint then
		name = paint.name .. " " .. name
	end
	local size = Catalog.SizeOf(sizeId)
	if size ~= Catalog.BaseSize then
		name = size.name .. " " .. name
	end
	if trait ~= Catalog.BaseTrait then
		name = trait.name .. " " .. name
	end
	return name
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
