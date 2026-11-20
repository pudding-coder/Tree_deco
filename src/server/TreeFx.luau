-- 트리 효과(상점)를 실제로 만든다. 목록: src/shared/Catalog/TreeEffects.luau
-- ReplicatedStorage.TreeEffectModels에 id(또는 model)와 같은 이름의 모델이 있으면 그 모델을 쓰고,
-- 없으면 아래 BUILT_IN에서 코드로 만든 기본 효과를 쓴다.
-- 꾸미기 전용이라 수입·트리 가치와는 상관없다.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Debris = game:GetService("Debris")

local TreeFx = {}

-- ctx: 트리 정보
--   base   트리 밑동 가운데 바닥 (CFrame, -Z가 트리 정면 = 사람이 서는 쪽)
--   height 트리 높이 (토퍼 제외, 스터드)
--   radius 트리 밑동 반지름 (스터드, 가장 넓은 층)
--   floorDiameter 트리 자리 매트의 돌 테두리 안쪽 지름 (맵이 없으면 nil)
--   spot   (바닥 아이템만) 바닥 자리 번호 1~MAX_FLOOR_ITEMS

-- 바닥 자리(spread가 아닌 바닥 아이템): 트리 둘레, 정면 양옆부터
local FLOOR_SPOT_ANGLES = { -40, 40, -140, 140 } -- 0도 = 정면(-Z)
local FLAT_FLOOR_LIFT = 0.2 -- 넓게 까는 바닥 모델(마법진 등)의 밑면 높이 (밑동 기준)
local FLOOR_ITEM_SIZE = 3 -- 바닥 자리 아이템의 가장 긴 변(스터드)

local function newPart(props)
	local part = Instance.new("Part")
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	for key, value in props do
		part[key] = value
	end
	return part
end

local function spotCFrame(ctx, index: number): CFrame
	local angle = math.rad(FLOOR_SPOT_ANGLES[index] or (index * 90))
	local r = ctx.radius + 2
	local pos = ctx.base:PointToWorldSpace(Vector3.new(math.sin(angle) * r, 0, -math.cos(angle) * r))
	local center = ctx.base.Position
	-- 정면(-Z)이 트리 바깥을 보게
	return CFrame.lookAt(pos, Vector3.new(center.X, pos.Y, center.Z)) * CFrame.Angles(0, math.pi, 0)
end

----------------------------------------------------------------
-- 코드로 만든 기본 효과
----------------------------------------------------------------

local BUILT_IN = {}

-- 잔디밭: 트리 밑에 둥근 잔디를 깐다
function BUILT_IN.Grass(ctx)
	local diameter = ctx.floorDiameter or (ctx.radius * 2 + 8)
	return newPart({
		Name = "Grass",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.3, diameter, diameter),
		CFrame = ctx.base * CFrame.new(0, 0.03, 0) * CFrame.Angles(0, 0, math.pi / 2), -- 윗면이 흙(+0.15) 바로 위 +0.18
		Material = Enum.Material.Grass,
		Color = Color3.fromRGB(88, 160, 72),
	})
end

-- 불타는 트리: 층마다 둘레에 불을 붙인다
function BUILT_IN.Fire(ctx)
	local model = Instance.new("Model")
	model.Name = "Fire"
	local rings = { { y = 0.15, r = 0.9, n = 6 }, { y = 0.4, r = 0.65, n = 5 }, { y = 0.65, r = 0.4, n = 4 } }
	for ringIndex, ring in rings do
		for k = 1, ring.n do
			local angle = (k - 1) / ring.n * math.pi * 2 + ringIndex * 0.6
			local r = ctx.radius * ring.r
			local holder = newPart({
				Name = "Flame",
				Size = Vector3.new(0.2, 0.2, 0.2),
				Transparency = 1,
				CFrame = ctx.base * CFrame.new(math.sin(angle) * r, ctx.height * ring.y, -math.cos(angle) * r),
				Parent = model,
			})
			local fire = Instance.new("Fire")
			fire.Size = 6 - ringIndex
			fire.Heat = 12
			fire.Color = Color3.fromRGB(255, 120, 30)
			fire.SecondaryColor = Color3.fromRGB(255, 220, 80)
			fire.Parent = holder
		end
	end
	local glow = newPart({
		Name = "Glow",
		Size = Vector3.new(0.2, 0.2, 0.2),
		Transparency = 1,
		CFrame = ctx.base * CFrame.new(0, ctx.height * 0.4, 0),
		Parent = model,
	})
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(255, 140, 50)
	light.Range = ctx.radius * 3
	light.Brightness = 2
	light.Parent = glow
	return model
end

-- 컨페티: 트리 위에서 알록달록한 종이가 떨어진다
function BUILT_IN.Confetti(ctx)
	local width = ctx.radius * 2 + 4
	local source = newPart({
		Name = "Confetti",
		Size = Vector3.new(width, 0.2, width),
		Transparency = 1,
		CFrame = ctx.base * CFrame.new(0, ctx.height + 8, 0),
	})
	local colors = {
		Color3.fromRGB(255, 80, 80),
		Color3.fromRGB(255, 210, 60),
		Color3.fromRGB(80, 200, 120),
		Color3.fromRGB(80, 160, 255),
		Color3.fromRGB(220, 110, 255),
	}
	for _, color in colors do
		local emitter = Instance.new("ParticleEmitter")
		emitter.Color = ColorSequence.new(color)
		emitter.LightEmission = 0.2
		emitter.Size = NumberSequence.new(0.35)
		emitter.Squash = NumberSequence.new(-0.6) -- 납작한 종이 모양
		emitter.Lifetime = NumberRange.new(5, 7)
		emitter.Rate = 5
		emitter.Speed = NumberRange.new(2, 4)
		emitter.EmissionDirection = Enum.NormalId.Bottom
		emitter.SpreadAngle = Vector2.new(25, 25)
		emitter.Acceleration = Vector3.new(0, -1.5, 0)
		emitter.Drag = 0.6
		emitter.Rotation = NumberRange.new(0, 360)
		emitter.RotSpeed = NumberRange.new(-180, 180)
		emitter.Shape = Enum.ParticleEmitterShape.Box
		emitter.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
		emitter.Parent = source
	end
	return source
end

-- 벼락 한 번: 하늘에서 트리 꼭대기까지 지그재그 빛줄기와 번쩍임
local function strike(model: Model, ctx)
	local top = ctx.base:PointToWorldSpace(Vector3.new(0, ctx.height, 0))
	local from = top + Vector3.new(math.random(-6, 6), 45, math.random(-6, 6))
	local bolt = Instance.new("Model")
	bolt.Name = "Bolt"
	local steps = 9
	local last = from
	for k = 1, steps do
		local t = k / steps
		local nextPoint = from:Lerp(top, t)
		if k < steps then
			nextPoint += Vector3.new(math.random() * 4 - 2, 0, math.random() * 4 - 2)
		end
		local length = (nextPoint - last).Magnitude
		newPart({
			Name = "Segment",
			Size = Vector3.new(0.35, 0.35, length),
			CFrame = CFrame.lookAt((last + nextPoint) / 2, nextPoint),
			Material = Enum.Material.Neon,
			Color = Color3.fromRGB(190, 215, 255),
			Parent = bolt,
		})
		last = nextPoint
	end
	local flash = newPart({
		Name = "Flash",
		Size = Vector3.new(0.2, 0.2, 0.2),
		Transparency = 1,
		CFrame = CFrame.new(top),
		Parent = bolt,
	})
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(180, 210, 255)
	light.Range = 40
	light.Brightness = 6
	light.Parent = flash
	local sparks = Instance.new("ParticleEmitter")
	sparks.Color = ColorSequence.new(Color3.fromRGB(200, 225, 255))
	sparks.LightEmission = 1
	sparks.Size = NumberSequence.new(0.4, 0)
	sparks.Lifetime = NumberRange.new(0.3, 0.6)
	sparks.Speed = NumberRange.new(10, 18)
	sparks.SpreadAngle = Vector2.new(180, 180)
	sparks.Rate = 0
	sparks.Parent = flash
	bolt.Parent = model
	sparks:Emit(30)
	Debris:AddItem(bolt, 0.6)
	-- 한 번 깜빡였다가 사라진다
	task.delay(0.08, function()
		for _, part in bolt:GetChildren() do
			if part:IsA("BasePart") and part.Name == "Segment" then
				part.Transparency = 0.7
			end
		end
	end)
	task.delay(0.16, function()
		for _, part in bolt:GetChildren() do
			if part:IsA("BasePart") and part.Name == "Segment" then
				part.Transparency = 1
			end
		end
		light.Enabled = false
	end)
end

-- 벼락 맞는 트리: 몇 초마다 꼭대기에 벼락이 떨어지고, 트리 둘레에 전기가 튄다
function BUILT_IN.Lightning(ctx)
	local model = Instance.new("Model")
	model.Name = "Lightning"
	local aura = newPart({
		Name = "Aura",
		Size = Vector3.new(ctx.radius * 1.6, ctx.height * 0.9, ctx.radius * 1.6),
		Transparency = 1,
		CFrame = ctx.base * CFrame.new(0, ctx.height * 0.45, 0),
		Parent = model,
	})
	local zap = Instance.new("ParticleEmitter")
	zap.Color = ColorSequence.new(Color3.fromRGB(170, 200, 255))
	zap.LightEmission = 1
	zap.Size = NumberSequence.new(0.25, 0)
	zap.Lifetime = NumberRange.new(0.15, 0.3)
	zap.Speed = NumberRange.new(4, 8)
	zap.SpreadAngle = Vector2.new(180, 180)
	zap.Rate = 12
	zap.Shape = Enum.ParticleEmitterShape.Box
	zap.ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface
	zap.Parent = aura

	task.spawn(function()
		task.wait(1)
		while model.Parent do
			strike(model, ctx)
			task.wait(math.random(30, 60) / 10) -- 3~6초마다
		end
	end)
	return model
end

----------------------------------------------------------------
-- Studio에서 넣은 모델
----------------------------------------------------------------

local function fromModel(fx, ctx)
	local folder = ReplicatedStorage:FindFirstChild("TreeEffectModels")
	local template = folder and folder:FindFirstChild(fx.model or fx.id)
	if not template then
		if fx.model then
			warn("[TreeFx] 트리 효과 모델을 찾지 못했습니다:", fx.model)
		end
		return nil
	end
	local model = template:Clone()
	if model:IsA("BasePart") then
		local holder = Instance.new("Model")
		holder.Name = model.Name
		model.Parent = holder
		model = holder
	elseif not model:IsA("Model") then
		warn("[TreeFx] 트리 효과 모델은 Model이나 Part여야 합니다:", fx.id, model.ClassName)
		return nil
	end
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			d.Anchored = true
			d.CanCollide = false
			d.CanQuery = false
			d.CanTouch = false
		elseif d:IsA("LuaSourceContainer") then
			d:Destroy() -- 무료 모델 스크립트는 돌리지 않는다
		end
	end
	-- 방향은 TreeEffectModels에 놓인 그대로 (장식 모델과 같은 규칙: 앞이 Front(-Z), 위가 위)
	model.PrimaryPart = nil
	model.WorldPivot = CFrame.new(model:GetPivot().Position)

	local _, size = model:GetBoundingBox()
	local scale
	local target
	if fx.area == "Floor" and fx.spread then
		-- 트리 밑에 넓게: 가로 긴 변을 매트 테두리 안쪽 지름에 (맵이 없으면 트리 지름보다 조금 크게)
		scale = (ctx.floorDiameter or (ctx.radius * 2 + 6)) / math.max(size.X, size.Z, 0.01)
		target = ctx.base
	elseif fx.area == "Floor" then
		scale = FLOOR_ITEM_SIZE / math.max(size.X, size.Y, size.Z, 0.01)
		target = spotCFrame(ctx, ctx.spot or 1)
	else
		-- 트리 효과: 높이를 트리보다 조금 크게, 트리 밑동 가운데에
		scale = ctx.height * 1.3 / math.max(size.Y, 0.01)
		target = ctx.base
	end
	model:ScaleTo(model:GetScale() * scale * fx.size)

	-- 모델 밑면 가운데를 target에 맞춘다
	-- 매트 흙 윗면이 밑동 +0.15, 잔디밭 윗면이 +0.18이라 그 바로 위에 깐다 (묻히지도 뜨지도 않게)
	local lift = if fx.area == "Floor" and fx.spread then FLAT_FLOOR_LIFT else 0.15
	local box, boxSize = model:GetBoundingBox()
	local bottom = box * CFrame.new(0, -boxSize.Y / 2, 0)
	local pivotFromBottom = bottom:ToObjectSpace(model:GetPivot())
	model:PivotTo(target * CFrame.new(0, lift, 0) * pivotFromBottom)
	return model
end

-- 효과 하나를 만든다. 만들 수 없으면 nil
function TreeFx.Build(fx, ctx)
	local inst = fromModel(fx, ctx)
	if inst then
		return inst
	end
	local builder = BUILT_IN[fx.id]
	if builder then
		return builder(ctx)
	end
	return nil
end

-- 서버 시작 때 효과마다 모양이 있는지 알린다 (모델도 기본 효과도 없으면 사도 안 보인다)
function TreeFx.Report(effects)
	local folder = ReplicatedStorage:FindFirstChild("TreeEffectModels")
	local missing = {}
	for _, fx in effects do
		local hasModel = folder and folder:FindFirstChild(fx.model or fx.id)
		if not hasModel and not BUILT_IN[fx.id] then
			table.insert(missing, fx.id)
		end
	end
	if #missing > 0 then
		warn("[TreeFx] 모양이 없는 트리 효과(ReplicatedStorage.TreeEffectModels에 모델을 넣어 주세요): " .. table.concat(missing, ", "))
	end
end

return TreeFx
