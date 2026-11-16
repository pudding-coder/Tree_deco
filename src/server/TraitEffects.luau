-- 특성 효과: Traits.luau의 effect 이름으로 장식 주변에 파티클(반짝임·연기·눈송이)을 피운다
-- 장식 색·재질은 바꾸지 않는다. 장식 색은 뽑을 때 정해진 칠하기 색(Paints.luau)으로만 바뀐다 (TraitEffects.Paint)
-- 빛 색이 계속 바뀌는 효과(무지개, 오로라)는 태그만 붙여 두고 클라이언트(src/client/TraitAnimator.luau)가 움직인다
local CollectionService = game:GetService("CollectionService")

local TraitEffects = {}

-- Roblox 기본 파티클 그림 (따로 올린 에셋이 아니라 항상 있다)
local SMOKE_TEXTURE = "rbxasset://textures/particles/smoke_main.dds" -- 연기
local SPARKLE_TEXTURE = "rbxasset://textures/particles/sparkles_main.dds" -- 반짝임·눈송이

--[[
	특성별 효과. 하나의 특성에 파티클 종류(kind)를 하나 고른다
	kind     "sparkle" 반짝이는 별가루 / "snow" 떨어지는 눈송이 / "smoke" 피어오르는 연기
	colors   파티클 색 (여러 개면 피어올라 사라지는 동안 이 순서로 바뀐다)
	glow     연기가 스스로 빛날지 (false면 탁한 연기)
	rate     초당 나오는 개수
	light    주변을 밝히는 빛 { 색, 거리, 밝기 } (없으면 빛 없음)
	tag      빛 색을 클라이언트가 계속 바꿀 때 태그 (TraitAnimator와 같은 이름)
]]
local RAINBOW = {
	Color3.fromRGB(255, 90, 90),
	Color3.fromRGB(255, 170, 60),
	Color3.fromRGB(255, 230, 80),
	Color3.fromRGB(90, 255, 140),
	Color3.fromRGB(90, 170, 255),
	Color3.fromRGB(200, 100, 255),
}
local AURORA = {
	Color3.fromRGB(120, 255, 200),
	Color3.fromRGB(90, 200, 255),
	Color3.fromRGB(120, 130, 255),
	Color3.fromRGB(200, 120, 255),
}

local EFFECTS = {
	-- 반짝이: 반짝이는 별가루
	Sparkle = {
		kind = "sparkle",
		colors = { Color3.fromRGB(255, 255, 255), Color3.fromRGB(255, 240, 160) },
		rate = 8,
		light = { Color3.fromRGB(255, 245, 210), 5, 0.4 },
	},
	-- 눈꽃: 떨어지는 눈송이
	Frost = {
		kind = "snow",
		colors = { Color3.fromRGB(255, 255, 255), Color3.fromRGB(180, 225, 255) },
		rate = 6,
		light = { Color3.fromRGB(170, 220, 255), 5, 0.5 },
	},
	-- 황금: 금빛 별가루
	Gold = {
		kind = "sparkle",
		colors = { Color3.fromRGB(255, 240, 160), Color3.fromRGB(255, 185, 40) },
		rate = 10,
		light = { Color3.fromRGB(255, 210, 120), 6, 0.7 },
	},
	-- 무지개: 무지개색 연기
	Rainbow = {
		kind = "smoke",
		colors = RAINBOW,
		glow = true,
		rate = 5,
		light = { Color3.fromRGB(255, 120, 200), 8, 0.8 },
		tag = "TraitRainbow",
	},
	-- 오로라: 초록·파랑·보라 오로라색 연기
	Aurora = {
		kind = "smoke",
		colors = AURORA,
		glow = true,
		rate = 5,
		light = { Color3.fromRGB(120, 255, 200), 10, 1 },
		tag = "TraitAurora",
	},
	-- 스모그: 회색 연기
	Smoge = {
		kind = "smoke",
		colors = { Color3.fromRGB(165, 165, 170), Color3.fromRGB(85, 85, 90) },
		glow = false,
		rate = 4,
	},
}

local function gradient(colors: { Color3 }): ColorSequence
	if #colors == 1 then
		return ColorSequence.new(colors[1])
	end
	local keypoints = {}
	for i, color in colors do
		table.insert(keypoints, ColorSequenceKeypoint.new((i - 1) / (#colors - 1), color))
	end
	return ColorSequence.new(keypoints)
end

-- radius: 장식 크기의 절반 (파티클 크기를 장식에 맞춘다)
local function makeEmitter(spec, radius: number): ParticleEmitter
	local e = Instance.new("ParticleEmitter")
	e.Name = "TraitParticles"
	e.Color = gradient(spec.colors)
	e.Rate = spec.rate
	e.Rotation = NumberRange.new(0, 360)
	e.SpreadAngle = Vector2.new(180, 180)

	if spec.kind == "sparkle" then
		e.Texture = SPARKLE_TEXTURE
		e.LightEmission = 1
		e.Size = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0),
			NumberSequenceKeypoint.new(0.3, radius * 0.45),
			NumberSequenceKeypoint.new(1, 0),
		})
		e.Lifetime = NumberRange.new(0.5, 1)
		e.Speed = NumberRange.new(radius * 0.6, radius * 1.4)
		e.Drag = 3
		e.RotSpeed = NumberRange.new(-90, 90)
	elseif spec.kind == "snow" then
		e.Texture = SPARKLE_TEXTURE
		e.LightEmission = 0.5
		e.Size = NumberSequence.new(radius * 0.25, radius * 0.15)
		e.Transparency = NumberSequence.new(0, 1)
		e.Lifetime = NumberRange.new(1.5, 2.5)
		e.Speed = NumberRange.new(radius * 0.3, radius * 0.6)
		e.Acceleration = Vector3.new(0, -radius * 1.2, 0)
		e.Drag = 1
		e.RotSpeed = NumberRange.new(-40, 40)
	else -- smoke
		e.Texture = SMOKE_TEXTURE
		e.LightEmission = if spec.glow then 0.8 else 0
		e.Size = NumberSequence.new(radius * 0.7, radius * 1.8)
		e.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1),
			NumberSequenceKeypoint.new(0.2, if spec.glow then 0.45 else 0.4),
			NumberSequenceKeypoint.new(1, 1),
		})
		e.Lifetime = NumberRange.new(1.8, 2.6)
		e.Speed = NumberRange.new(radius * 0.3, radius * 0.6)
		e.Acceleration = Vector3.new(0, radius * 0.8, 0)
		e.RotSpeed = NumberRange.new(-25, 25)
		e.ZOffset = -0.5 -- 장식을 너무 가리지 않게 뒤쪽에
	end
	return e
end

local function partsOf(target: Instance): { BasePart }
	local parts = {}
	if target:IsA("BasePart") then
		table.insert(parts, target)
	end
	for _, descendant in target:GetDescendants() do
		if descendant:IsA("BasePart") then
			table.insert(parts, descendant)
		end
	end
	return parts
end

-- 분위기를 붙일 파츠: 모델이면 PrimaryPart, 없으면 가장 큰 파츠
local function mainPart(target: Instance, parts: { BasePart }): BasePart?
	if target:IsA("BasePart") then
		return target
	end
	if target:IsA("Model") and target.PrimaryPart then
		return target.PrimaryPart
	end
	local best, bestVolume = nil, -1
	for _, part in parts do
		local volume = part.Size.X * part.Size.Y * part.Size.Z
		if volume > bestVolume then
			best, bestVolume = part, volume
		end
	end
	return best
end

-- target: 장식 파츠나 모델. 효과는 장식마다 한 파츠에만 붙는다
-- withAura가 false면 아무것도 붙이지 않는다 (띠 전구처럼 파츠가 많을 때 몇 개만 붙이려고)
function TraitEffects.Apply(target: Instance, trait, withAura: boolean?)
	local effect = trait and trait.effect
	if not effect or withAura == false then
		return
	end
	local spec = EFFECTS[effect]
	if not spec then
		warn("[TraitEffects] 모르는 특성 효과입니다:", effect)
		return
	end
	local part = mainPart(target, partsOf(target))
	if not part then
		return
	end

	-- 장식 크기: 모델이면 모델 전체 크기에 맞춘다
	local size = part.Size
	if target:IsA("Model") then
		local _, boxSize = target:GetBoundingBox()
		size = boxSize
	end
	local radius = math.max(size.X, size.Y, size.Z) / 2

	makeEmitter(spec, radius).Parent = part

	if spec.light then
		local light = Instance.new("PointLight")
		light.Name = "TraitLight"
		light.Color = spec.light[1]
		light.Range = spec.light[2]
		light.Brightness = spec.light[3]
		light.Parent = part
		if spec.tag then
			CollectionService:AddTag(light, spec.tag)
		end
	end
end

-- 뽑을 때 정해진 칠하기 색을 입힌다
-- 모델이면 이름이 Paint로 시작하는 파츠만 칠한다 (없으면 그대로). 파츠 하나(임시 공)면 그 파츠를 칠한다
function TraitEffects.Paint(target: Instance, color: Color3)
	if target:IsA("BasePart") then
		target.Color = color
		return
	end
	for _, part in partsOf(target) do
		if string.sub(part.Name, 1, 5) == "Paint" then
			part.Color = color
		end
	end
end

return TraitEffects
