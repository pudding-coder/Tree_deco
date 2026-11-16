-- 특성 효과: Traits.luau의 effect 이름으로 장식 주변에 그라데이션 분위기를 피운다
-- 장식 색·재질은 바꾸지 않는다. 장식 색은 뽑을 때 정해진 칠하기 색(Paints.luau)으로만 바뀐다 (TraitEffects.Paint)
-- 빛 색이 계속 바뀌는 효과(무지개, 오로라)는 태그만 붙여 두고 클라이언트(src/client/TraitAnimator.luau)가 움직인다
local CollectionService = game:GetService("CollectionService")

local TraitEffects = {}

-- Roblox 기본 파티클 그림 (따로 올린 에셋이 아니라 항상 있다)
local GLOW_TEXTURE = "rbxasset://textures/particles/smoke_main.dds" -- 부드러운 안개
local SPARKLE_TEXTURE = "rbxasset://textures/particles/sparkles_main.dds"

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

--[[
	특성별 분위기
	colors   안개 색 그라데이션 (피어올라 사라지는 동안 이 순서로 바뀐다)
	glow     true면 빛나는 안개, false면 연기처럼 탁한 안개
	light    주변을 밝히는 빛 { 색, 거리, 밝기 } (없으면 빛 없음)
	sparkle  반짝이 가루도 조금 섞을지
	tag      빛 색을 클라이언트가 계속 바꿀 때 태그 (TraitAnimator와 같은 이름)
]]
local AURAS = {
	Sparkle = {
		colors = { Color3.fromRGB(255, 255, 255), Color3.fromRGB(255, 240, 170) },
		glow = true,
		light = { Color3.fromRGB(255, 245, 200), 5, 0.5 },
		sparkle = true,
	},
	Frost = {
		colors = { Color3.fromRGB(240, 250, 255), Color3.fromRGB(150, 210, 255) },
		glow = true,
		light = { Color3.fromRGB(170, 220, 255), 6, 0.6 },
	},
	Gold = {
		colors = { Color3.fromRGB(255, 235, 150), Color3.fromRGB(255, 180, 40) },
		glow = true,
		light = { Color3.fromRGB(255, 210, 120), 7, 0.8 },
		sparkle = true,
	},
	Rainbow = {
		colors = {
			Color3.fromRGB(255, 90, 90),
			Color3.fromRGB(255, 220, 80),
			Color3.fromRGB(90, 255, 140),
			Color3.fromRGB(90, 170, 255),
			Color3.fromRGB(200, 100, 255),
		},
		glow = true,
		light = { Color3.fromRGB(255, 120, 200), 8, 0.9 },
		tag = "TraitRainbow",
	},
	Aurora = {
		colors = { Color3.fromRGB(120, 255, 200), Color3.fromRGB(90, 170, 255), Color3.fromRGB(190, 120, 255) },
		glow = true,
		light = { Color3.fromRGB(120, 255, 200), 10, 1 },
		tag = "TraitAurora",
	},
	Smoge = {
		colors = { Color3.fromRGB(160, 160, 165), Color3.fromRGB(80, 80, 85) },
		glow = false,
	},
}

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

-- target: 장식 파츠나 모델. 분위기는 장식마다 한 파츠에만 붙는다
-- withAura가 false면 아무것도 붙이지 않는다 (띠 전구처럼 파츠가 많을 때 몇 개만 붙이려고)
function TraitEffects.Apply(target: Instance, trait, withAura: boolean?)
	local effect = trait and trait.effect
	if not effect or withAura == false then
		return
	end
	local aura = AURAS[effect]
	if not aura then
		warn("[TraitEffects] 모르는 특성 효과입니다:", effect)
		return
	end
	local part = mainPart(target, partsOf(target))
	if not part then
		return
	end

	-- 장식을 감싸는 크기: 모델이면 모델 전체 크기에 맞춘다
	local size = part.Size
	if target:IsA("Model") then
		local _, boxSize = target:GetBoundingBox()
		size = boxSize
	end
	local radius = math.max(size.X, size.Y, size.Z) / 2

	local haze = Instance.new("ParticleEmitter")
	haze.Name = "TraitAura"
	haze.Texture = GLOW_TEXTURE
	haze.Color = gradient(aura.colors)
	haze.LightEmission = if aura.glow then 1 else 0
	haze.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, radius * 1.2),
		NumberSequenceKeypoint.new(1, radius * 2.2),
	})
	haze.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.3, if aura.glow then 0.7 else 0.55),
		NumberSequenceKeypoint.new(1, 1),
	})
	haze.Lifetime = NumberRange.new(1.8, 2.6)
	haze.Rate = 3
	haze.Speed = NumberRange.new(0.2, 0.5)
	haze.SpreadAngle = Vector2.new(180, 180)
	haze.Acceleration = Vector3.new(0, 0.6, 0)
	haze.Rotation = NumberRange.new(0, 360)
	haze.RotSpeed = NumberRange.new(-20, 20)
	haze.ZOffset = -1 -- 장식 뒤쪽에 깔리게
	haze.Parent = part

	if aura.sparkle then
		local sparkle = Instance.new("ParticleEmitter")
		sparkle.Name = "TraitSparkle"
		sparkle.Texture = SPARKLE_TEXTURE
		sparkle.Color = gradient(aura.colors)
		sparkle.LightEmission = 1
		sparkle.Size = NumberSequence.new(radius * 0.25, 0)
		sparkle.Lifetime = NumberRange.new(0.5, 0.9)
		sparkle.Rate = 3
		sparkle.Speed = NumberRange.new(0.4, 0.8)
		sparkle.SpreadAngle = Vector2.new(180, 180)
		sparkle.Parent = part
	end

	if aura.light then
		local light = Instance.new("PointLight")
		light.Name = "TraitLight"
		light.Color = aura.light[1]
		light.Range = aura.light[2]
		light.Brightness = aura.light[3]
		light.Parent = part
		if aura.tag then
			CollectionService:AddTag(light, aura.tag)
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
