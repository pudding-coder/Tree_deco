-- 특성 효과: Traits.luau의 effect 이름으로 트리에 걸린 장식의 겉모습을 바꾼다
-- 재질·색·빛·파티클은 서버가 붙이고, 색이 계속 바뀌는 효과(무지개, 오로라)는
-- 태그만 붙여 두고 클라이언트(src/client/TraitAnimator.luau)가 움직인다
local CollectionService = game:GetService("CollectionService")

local TraitEffects = {}

-- 클라이언트 TraitAnimator와 같은 이름을 쓴다
TraitEffects.RAINBOW_TAG = "TraitRainbow"
TraitEffects.AURORA_TAG = "TraitAurora"

-- Roblox 기본 파티클 그림 (따로 올린 에셋이 아니라 항상 있다)
local SPARKLE_TEXTURE = "rbxasset://textures/particles/sparkles_main.dds"
local SMOKE_TEXTURE = "rbxasset://textures/particles/smoke_main.dds"

local GOLD = Color3.fromRGB(255, 200, 40)
local AURORA_GREEN = Color3.fromRGB(120, 255, 200)
local AURORA_BLUE = Color3.fromRGB(90, 170, 255)
local AURORA_PURPLE = Color3.fromRGB(190, 120, 255)

local function numbers(a: number, b: number): NumberSequence
	return NumberSequence.new(a, b)
end

local function emitter(parent: BasePart, props)
	local e = Instance.new("ParticleEmitter")
	e.Name = "TraitParticles"
	e.Texture = SPARKLE_TEXTURE
	e.LightEmission = 1
	e.SpreadAngle = Vector2.new(180, 180)
	e.Rotation = NumberRange.new(0, 360)
	local target: any = e
	for key, value in props do
		target[key] = value
	end
	e.Parent = parent
	return e
end

local function light(parent: BasePart, color: Color3, range: number, brightness: number)
	local l = Instance.new("PointLight")
	l.Name = "TraitLight"
	l.Color = color
	l.Range = range
	l.Brightness = brightness
	l.Parent = parent
	return l
end

-- 재질·색: 장식의 모든 파츠에
local looks = {
	Sparkle = function(part: BasePart)
		part.Reflectance = math.max(part.Reflectance, 0.15)
	end,
	Frost = function(part: BasePart)
		part.Material = Enum.Material.Ice
		part.Color = part.Color:Lerp(Color3.fromRGB(225, 240, 255), 0.55)
	end,
	Gold = function(part: BasePart)
		part.Material = Enum.Material.Foil
		part.Color = GOLD
		part.Reflectance = 0.2
	end,
	Rainbow = function(part: BasePart)
		part.Material = Enum.Material.Neon
		CollectionService:AddTag(part, TraitEffects.RAINBOW_TAG)
	end,
	Aurora = function(part: BasePart)
		part.Material = Enum.Material.Neon
		part.Color = AURORA_GREEN
		CollectionService:AddTag(part, TraitEffects.AURORA_TAG)
	end,
	Smoge = function(part: BasePart)
		part.Material = Enum.Material.Slate
		part.Color = part.Color:Lerp(Color3.fromRGB(90, 90, 95), 0.65)
	end,
}

-- 파티클·빛: 장식마다 한 파츠에만 (많이 붙이면 무거워진다)
local extras = {
	Sparkle = function(part: BasePart)
		emitter(part, {
			Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(255, 240, 150)),
			Size = numbers(0.35, 0),
			Transparency = numbers(0, 0.3),
			Lifetime = NumberRange.new(0.5, 0.9),
			Rate = 6,
			Speed = NumberRange.new(0.5, 1),
		})
	end,
	Frost = function(part: BasePart)
		-- 눈송이가 천천히 떨어진다
		emitter(part, {
			Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(170, 220, 255)),
			Size = numbers(0.25, 0.1),
			Transparency = numbers(0, 1),
			Lifetime = NumberRange.new(1.5, 2.5),
			Rate = 4,
			Speed = NumberRange.new(0.2, 0.5),
			Acceleration = Vector3.new(0, -1.5, 0),
			LightEmission = 0.4,
		})
		light(part, Color3.fromRGB(170, 220, 255), 5, 0.6)
	end,
	Gold = function(part: BasePart)
		emitter(part, {
			Color = ColorSequence.new(Color3.fromRGB(255, 230, 140), GOLD),
			Size = numbers(0.4, 0),
			Transparency = numbers(0, 0.2),
			Lifetime = NumberRange.new(0.6, 1),
			Rate = 5,
			Speed = NumberRange.new(0.6, 1.2),
		})
		light(part, Color3.fromRGB(255, 210, 120), 6, 0.8)
	end,
	Rainbow = function(part: BasePart)
		emitter(part, {
			Color = ColorSequence.new({
				ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 80, 80)),
				ColorSequenceKeypoint.new(0.25, Color3.fromRGB(255, 220, 60)),
				ColorSequenceKeypoint.new(0.5, Color3.fromRGB(80, 255, 120)),
				ColorSequenceKeypoint.new(0.75, Color3.fromRGB(80, 160, 255)),
				ColorSequenceKeypoint.new(1, Color3.fromRGB(200, 90, 255)),
			}),
			Size = numbers(0.4, 0),
			Lifetime = NumberRange.new(0.8, 1.2),
			Rate = 6,
			Speed = NumberRange.new(0.8, 1.4),
		})
	end,
	Aurora = function(part: BasePart)
		-- 빛 띠가 위로 피어오른다
		emitter(part, {
			Color = ColorSequence.new({
				ColorSequenceKeypoint.new(0, AURORA_GREEN),
				ColorSequenceKeypoint.new(0.5, AURORA_BLUE),
				ColorSequenceKeypoint.new(1, AURORA_PURPLE),
			}),
			Size = numbers(0.6, 0),
			Transparency = numbers(0.2, 1),
			Lifetime = NumberRange.new(1.5, 2.2),
			Rate = 8,
			Speed = NumberRange.new(0.3, 0.6),
			Acceleration = Vector3.new(0, 1.2, 0),
		})
		local l = light(part, AURORA_GREEN, 10, 1)
		CollectionService:AddTag(l, TraitEffects.AURORA_TAG)
	end,
	Smoge = function(part: BasePart)
		-- 회색 연기가 피어오른다
		emitter(part, {
			Texture = SMOKE_TEXTURE,
			Color = ColorSequence.new(Color3.fromRGB(150, 150, 150), Color3.fromRGB(90, 90, 90)),
			Size = numbers(0.5, 1.6),
			Transparency = numbers(0.35, 1),
			Lifetime = NumberRange.new(1.8, 2.6),
			Rate = 4,
			Speed = NumberRange.new(0.4, 0.8),
			Acceleration = Vector3.new(0, 0.8, 0),
			LightEmission = 0,
			RotSpeed = NumberRange.new(-30, 30),
		})
	end,
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

-- 파티클·빛을 붙일 파츠: 모델이면 PrimaryPart, 없으면 가장 큰 파츠
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

-- target: 장식 파츠나 모델. withExtras가 false면 재질·색만 바꾼다 (띠 전구처럼 파츠가 많을 때)
function TraitEffects.Apply(target: Instance, trait, withExtras: boolean?)
	local effect = trait and trait.effect
	if not effect then
		return
	end
	local look = looks[effect]
	local extra = extras[effect]
	if not look and not extra then
		warn("[TraitEffects] 모르는 특성 효과입니다:", effect)
		return
	end
	local parts = partsOf(target)
	if look then
		for _, part in parts do
			look(part)
		end
	end
	if extra and withExtras ~= false then
		local part = mainPart(target, parts)
		if part then
			extra(part)
		end
	end
end

return TraitEffects
