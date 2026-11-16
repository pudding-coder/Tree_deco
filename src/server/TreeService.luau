-- 트리 꾸미기·전시 (GAME_RULES.md '트리 꾸미기', '전시·수익')
-- 서버는 빈 광장에서 시작한다. 플레이어가 들어오면 플롯(트리)이 생기고, 나가면 PLOT_KEEP_SECONDS 뒤에 사라진다.
-- 플롯에는 트리가 서 있고, 정해진 자리에 장식을 건다.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Gacha = require(Shared:WaitForChild("Gacha"))
local Catalog = require(Shared:WaitForChild("Catalog"))
local Remotes = ReplicatedStorage:WaitForChild("Remotes")

local PlayerData = require(script.Parent.PlayerData)
local GachaService = require(script.Parent.GachaService)
local Income = require(script.Parent.Income)

local TreeService = {}

local AREA_CAPACITY = PlayerData.AREA_CAPACITY

----------------------------------------------------------------
-- 모양 (스터드 단위)
----------------------------------------------------------------

-- 플롯 자리: 광장을 둘러싼 원 여러 겹. 안쪽 원부터 채운다
local PLOT_RINGS = {
	{ radius = 70, count = 8 },
	{ radius = 120, count = 12 },
	{ radius = 170, count = 16 },
}
local PLOT_SIZE = 36
local TRUNK_HEIGHT = 2.7
-- 트리 몸통(원기둥 트리): 아래층부터 { 반지름, 높이 }. 트리 높이(토퍼 제외) = TRUNK_HEIGHT + 층 높이 합 = 16
-- TreeTemplate도 이 높이에 맞춰 크기가 조절된다
local LAYERS = {
	{ radius = 6, height = 3.3 },
	{ radius = 5, height = 3 },
	{ radius = 4, height = 2.7 },
	{ radius = 3, height = 2.3 },
	{ radius = 2, height = 2 },
}
-- TreeTemplate에서 층마다 밖으로 보이는 경사면 높이 { 아래, 위 } (트리 높이 대비 비율, 아래층부터)
-- assets/models/ChristmasTree.fbx를 재서 정했다. 층이 서로 겹쳐서 아래층일수록 보이는 부분이 좁다
-- 트리 모델을 바꾸면 다시 재야 한다
local TEMPLATE_TIER_BANDS = {
	{ 0.16, 0.24 },
	{ 0.27, 0.38 },
	{ 0.42, 0.52 },
	{ 0.54, 0.66 },
	{ 0.70, 0.86 },
}
-- 오너먼트 자리: 어느 띠를 따라 걸지(띠 번호)와 각도(0 = 광장 쪽 정면, 도 단위)
-- 띠가 비스듬하므로 같은 띠의 오너먼트는 사선으로 이어진다. 띠를 안 걸어도 그 자리를 따른다
-- 트리 둘레 360도에 고르게 퍼져 있고, 1번 자리부터 채워지므로 몇 개만 걸어도 퍼지게 순서를 섞어 둔다
local ORNAMENT_SPOTS = {
	{ garland = 1, angle = 0 },
	{ garland = 2, angle = -45 },
	{ garland = 3, angle = 60 },
	{ garland = 2, angle = 45 },
	{ garland = 1, angle = -90 },
	{ garland = 1, angle = 90 },
	{ garland = 2, angle = 135 },
	{ garland = 2, angle = -135 },
	{ garland = 1, angle = 180 },
	{ garland = 3, angle = -120 },
}
local ORNAMENT_DROP = 0.4 -- 오너먼트가 띠 전선보다 이만큼 아래에 매달린다
-- 띠가 걸리는 층 (띠 1번부터). 하나만 걸어도 트리 가운데에 오게 한다. 1층은 보이는 부분이 좁아서 쓰지 않는다
local GARLAND_TIERS = { 4, 2, 5, 3 }
local GARLAND_BALLS = 28 -- 임시 띠 모양: 트리를 한 바퀴 도는 전구 개수
local GARLAND_TILT = 0.35 -- 띠 기울기: 층에서 보이는 경사면 높이에 대한 비율. 한쪽은 높고 반대쪽은 낮게 비스듬히 두른다
local GARLAND_WIRE_COLOR = Color3.fromRGB(30, 45, 30)

local TREE_GREEN = Color3.fromRGB(34, 110, 60)
local TRUNK_BROWN = Color3.fromRGB(110, 72, 40)

----------------------------------------------------------------
-- 플롯
----------------------------------------------------------------

local plotsFolder = nil
local plotPositions = {} -- [자리 번호] = 플롯 중심 CFrame (광장을 바라봄)
local plots = {} -- [자리 번호] = { cframe, spawn, model, decorations, signLabel, owner, keptFor, keptName, keptUntil }
local plotOf = {} -- [Player] = 자리 번호

do
	for _, ring in PLOT_RINGS do
		for k = 1, ring.count do
			if #plotPositions >= Config.SERVER_MAX_PLAYERS then
				break
			end
			-- 겹마다 시작 각도를 조금 돌려서 안쪽 트리 뒤에 가리지 않게
			local angle = (k - 1) / ring.count * math.pi * 2 + ring.radius * 0.01
			local position = Vector3.new(math.cos(angle) * ring.radius, 0, math.sin(angle) * ring.radius)
			table.insert(plotPositions, CFrame.lookAt(position, Vector3.new(0, 0, 0)))
		end
	end
	-- 원이 모자라면 맨 바깥 원 밖으로 더 늘린다
	local extraRadius = PLOT_RINGS[#PLOT_RINGS].radius
	while #plotPositions < Config.SERVER_MAX_PLAYERS do
		extraRadius += 50
		local count = math.floor(2 * math.pi * extraRadius / 60)
		for k = 1, count do
			if #plotPositions >= Config.SERVER_MAX_PLAYERS then
				break
			end
			local angle = (k - 1) / count * math.pi * 2
			local position = Vector3.new(math.cos(angle) * extraRadius, 0, math.sin(angle) * extraRadius)
			table.insert(plotPositions, CFrame.lookAt(position, Vector3.new(0, 0, 0)))
		end
	end
end

-- ServerStorage.TreeTemplate(Studio에서 넣은 트리 모델)이 있으면 원기둥 대신 그 모델을 쓴다 (docs/MAP.md)
local treeTemplate: Model? = nil
local treeTemplatePivot = CFrame.identity -- 밑동 가운데가 (0, 0, 0)에 오게 하는 피벗
local ornamentPoints = {} -- [오너먼트 자리] = 플롯 기준 점 (트리 겉면)
local garlandPaths = {} -- [띠 자리] = { [k] = 플롯 기준 점 또는 nil } 트리 겉면을 비스듬히 한 바퀴 도는 전구 자리
local garlandCenters = {} -- [띠 자리] = 띠 가운데 높이
local topperY = nil -- 트리 꼭대기 끝 높이 (모델에서 잰 값)
-- TreeTemplate 안 Slots 폴더에 직접 놓은 자리 표시 (docs/MAP.md). 있으면 자동 위치보다 먼저 쓴다
local customSlots = { Topper = {}, Ornament = {}, Garland = {} } -- [영역][번호] = 플롯 기준 위치(Vector3)

local function layerBottom(layerIndex: number): number
	local y = TRUNK_HEIGHT
	for i = 1, layerIndex - 1 do
		y += LAYERS[i].height
	end
	return y
end

local function treeTop(): number
	return layerBottom(#LAYERS + 1)
end

-- 플롯 기준 좌표: 앞(-Z) = 광장 쪽
local function localPoint(angleDeg: number, radius: number, y: number): Vector3
	local a = math.rad(angleDeg)
	return Vector3.new(math.sin(a) * radius, y, -math.cos(a) * radius)
end

-- 자리별 위치 (플롯 기준)
local function slotOffset(area: string, index: number): CFrame
	local custom = customSlots[area] and customSlots[area][index]
	if custom then
		if area == "Ornament" then
			return CFrame.lookAt(custom, Vector3.new(0, custom.Y, 0)) -- 트리 쪽을 바라보게
		elseif area == "Garland" then
			return CFrame.new(0, custom.Y, 0) -- 띠는 표시 높이에서 트리를 한 바퀴 두른다
		end
		return CFrame.new(custom)
	end
	if area == "Topper" then
		-- 토퍼 밑면이 앉을 자리 (꼭대기 끝)
		return CFrame.new(0, topperY or treeTop(), 0)
	elseif area == "Ornament" then
		local spot = ORNAMENT_SPOTS[index]
		local pos = ornamentPoints[index] or localPoint(spot.angle, LAYERS[1].radius + 0.4, layerBottom(1) + 0.8)
		return CFrame.lookAt(pos, Vector3.new(0, pos.Y, 0)) -- 트리 쪽을 바라보게
	else -- Garland: 띠 가운데 높이의 트리 중심
		return CFrame.new(0, garlandCenters[index] or (layerBottom(index + 1) + 0.2), 0)
	end
end

-- 띠 자리마다 트리 겉면을 비스듬히 한 바퀴 도는 점을 만들고, 오너먼트를 띠와 나란히 놓는다
-- bands: 층마다 밖으로 보이는 경사면 높이 { 아래, 위 } (스터드, 아래층부터)
-- surfaceRadius(각도, 높이): 그 높이에서 트리 겉면까지 거리 (없으면 nil)
local function buildSlotPositions(bands: { { number } }, surfaceRadius: (number, number) -> number?)
	local count = AREA_CAPACITY.Garland
	local garlandTilts = {} -- [띠 자리] = 기울기 (스터드)
	for i = 1, count do
		-- 보이는 경사면 가운데를 비스듬히 두른다
		local tier = math.clamp(GARLAND_TIERS[i] or i, 1, #bands)
		local bottom, top = bands[tier][1], bands[tier][2]
		local gap = top - bottom
		local center = (bottom + top) / 2
		local custom = customSlots.Garland[i]
		if custom then
			center = custom.Y
		end
		local tilt = gap * GARLAND_TILT
		garlandTilts[i] = tilt

		local points = {}
		for k = 1, GARLAND_BALLS do
			local angle = (k - 1) / GARLAND_BALLS * 360
			local y = center + tilt * math.sin(math.rad(angle))
			local r = surfaceRadius(angle, y)
			if r then
				points[k] = localPoint(angle, r + 0.35, y)
			end
		end
		garlandPaths[i] = points
		garlandCenters[i] = center
	end

	-- 오너먼트: 띠를 따라 그 각도의 띠 높이에 매단다 (그래서 사선으로 이어진다)
	for i, spot in ORNAMENT_SPOTS do
		local g = math.clamp(spot.garland, 1, count)
		local y = garlandCenters[g] + garlandTilts[g] * math.sin(math.rad(spot.angle)) - ORNAMENT_DROP
		local r = surfaceRadius(spot.angle, y)
		if r then
			ornamentPoints[i] = localPoint(spot.angle, r + 0.6, y)
		end
	end
end

-- 원기둥 트리의 겉면 거리
local function cylinderSurfaceRadius(_angle: number, y: number): number?
	for i, layer in LAYERS do
		if y >= layerBottom(i) and y < layerBottom(i) + layer.height then
			return layer.radius
		end
	end
	return nil
end

-- 트리 모델을 원기둥 트리와 같은 높이로 맞추고, 장식이 겉면에 붙도록 거리를 잰다
local function loadTreeTemplate()
	-- 편집하기 편하게 Workspace에 둬도 된다. 게임이 시작되면 Workspace의 원본은 치운다
	local source = game:GetService("ServerStorage"):FindFirstChild("TreeTemplate") or workspace:FindFirstChild("TreeTemplate")
	if not source then
		warn("[Tree] ServerStorage에 TreeTemplate이 없어 원기둥 트리를 씁니다.")
		return
	end
	if not source:IsA("Model") then
		warn("[Tree] TreeTemplate은 Model이어야 합니다. 지금은 " .. source.ClassName .. "입니다. 원기둥 트리를 씁니다.")
		return
	end
	local model = source:Clone()
	if source.Parent == workspace then
		source.Parent = nil
	end

	-- 자리 표시(Slots 폴더)는 크기 재기 전에 빼 두고, 모델 피벗 기준 위치만 기억한다
	local markers = {} -- { area, index, name, point }
	local slotsFolder = model:FindFirstChild("Slots")
	if slotsFolder then
		local pivot = model:GetPivot()
		for _, marker in slotsFolder:GetChildren() do
			if not marker:IsA("BasePart") then
				continue
			end
			local area, number = string.match(marker.Name, "^(%a+)(%d*)$")
			local index = tonumber(number) or 1
			local capacity = area and AREA_CAPACITY[area]
			if not capacity or index < 1 or index > capacity then
				warn(string.format(
					"[Tree] TreeTemplate.Slots의 '%s'는 쓸 수 없는 이름입니다. Topper, Ornament1~%d, Garland1~%d 중 하나로 지어 주세요.",
					marker.Name,
					AREA_CAPACITY.Ornament,
					AREA_CAPACITY.Garland
				))
				continue
			end
			table.insert(markers, { area = area, index = index, point = pivot:PointToObjectSpace(marker.Position) })
		end
		slotsFolder:Destroy()
	end

	local parts = {}
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.Anchored = true
			table.insert(parts, descendant)
		end
	end
	if #parts == 0 then
		warn("[Tree] ServerStorage.TreeTemplate 안에 파츠가 없습니다. 원기둥 트리를 씁니다.")
		return
	end

	local _, size = model:GetBoundingBox()
	local scale = treeTop() / size.Y
	model:ScaleTo(model:GetScale() * scale) -- 피벗을 중심으로 커지거나 작아진다

	-- 밑동 가운데를 원점에 맞춘다
	model:PivotTo(CFrame.identity)
	local box, boxSize = model:GetBoundingBox()
	treeTemplatePivot = CFrame.new(-box.X, boxSize.Y / 2 - box.Y, -box.Z)
	model:PivotTo(treeTemplatePivot)

	for _, marker in markers do
		customSlots[marker.area][marker.index] = treeTemplatePivot:PointToWorldSpace(marker.point * scale)
	end
	if #markers > 0 then
		print(string.format("[Tree] TreeTemplate.Slots에서 장식 자리 %d곳을 읽었습니다", #markers))
	end

	-- 원점에 잠깐 놓고 이 모델만 맞히는 광선으로 겉면 거리를 잰다 (같은 프레임에 치워서 보이지 않는다)
	model.Parent = workspace
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { model }
	local function surfaceRadius(angleDeg: number, y: number): number?
		local origin = localPoint(angleDeg, 100, y)
		local target = Vector3.new(0, y, 0)
		local hit = workspace:Raycast(origin, target - origin, params)
		if hit then
			return Vector3.new(hit.Position.X, 0, hit.Position.Z).Magnitude
		end
		return nil
	end

	-- 꼭대기 끝: 위에서 아래로 쏜 광선이 처음 맞는 높이
	local topHit = workspace:Raycast(Vector3.new(0, treeTop() + 50, 0), Vector3.new(0, -(treeTop() + 60), 0), params)
	topperY = if topHit then topHit.Position.Y else treeTop()

	local bands = {}
	for _, band in TEMPLATE_TIER_BANDS do
		table.insert(bands, { band[1] * treeTop(), band[2] * treeTop() })
	end
	buildSlotPositions(bands, surfaceRadius)
	model.Parent = nil

	treeTemplate = model
	print(string.format(
		"[Tree] TreeTemplate을 씁니다 (파츠 %d개, 오너먼트 자리 %d곳 맞춤, 꼭대기 높이 %.1f)",
		#parts,
		#ornamentPoints,
		topperY
	))
end

local function newPart(props)
	local part = Instance.new("Part")
	part.Anchored = true
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	for key, value in props do
		if key ~= "Parent" then
			part[key] = value
		end
	end
	part.Parent = props.Parent
	return part
end

-- 맵에 트리 자리 표시(Workspace.PlotSpots 폴더의 파츠)가 있으면 그 자리를 쓴다 (docs/MAP.md)
local usingMapSpots = false

local function loadMapSpots()
	local folder = workspace:FindFirstChild("PlotSpots")
	if not folder then
		return
	end
	local spots = {}
	for _, child in folder:GetChildren() do
		if child:IsA("BasePart") then
			table.insert(spots, child)
		end
	end
	if #spots == 0 then
		return
	end
	-- 이름이 숫자면 숫자 순서(1, 2, 3 ...), 아니면 이름 순서로 채운다
	table.sort(spots, function(a, b)
		local na, nb = tonumber(a.Name), tonumber(b.Name)
		if na and nb then
			return na < nb
		elseif na or nb then
			return na ~= nil
		end
		return a.Name < b.Name
	end)

	plotPositions = {}
	for _, spot in spots do
		-- 파츠 바닥 가운데에 트리를 세운다. 파츠의 앞면(Front) 쪽이 트리 정면(사람이 서는 쪽)
		table.insert(plotPositions, spot.CFrame * CFrame.new(0, -spot.Size.Y / 2, 0))
		spot.Transparency = 1
		spot:ClearAllChildren() -- "앞" 글자(SurfaceGui) 같은 편집용 표시를 지운다
		spot.CanCollide = false
		spot.CanQuery = false
		spot.CanTouch = false
	end
	usingMapSpots = true
	if #plotPositions < Config.SERVER_MAX_PLAYERS then
		warn(string.format(
			"[Tree] PlotSpots에 자리가 %d개뿐입니다. 서버 인원(%d명)보다 적으면 늦게 온 사람은 트리를 받지 못합니다.",
			#plotPositions,
			Config.SERVER_MAX_PLAYERS
		))
	end
end

-- 트리 모델이 없을 때 쓰는 원기둥 트리
local function buildCylinderTree(model: Model, base: CFrame)
	newPart({
		Name = "Trunk",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(TRUNK_HEIGHT, 2.4, 2.4),
		CFrame = base * CFrame.new(0, TRUNK_HEIGHT / 2, 0) * CFrame.Angles(0, 0, math.rad(90)),
		Color = TRUNK_BROWN,
		Material = Enum.Material.Wood,
		Parent = model,
	})
	for i, layer in LAYERS do
		newPart({
			Name = "Layer" .. i,
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(layer.height, layer.radius * 2, layer.radius * 2),
			CFrame = base * CFrame.new(0, layerBottom(i) + layer.height / 2, 0) * CFrame.Angles(0, 0, math.rad(90)),
			Color = TREE_GREEN,
			Material = Enum.Material.Grass,
			CanCollide = i == 1,
			Parent = model,
		})
	end
end

local function buildPlot(index: number)
	local cframe = plotPositions[index]

	local model = Instance.new("Model")
	model.Name = "Plot" .. index

	-- 맵이 없을 때만 눈 바닥을 깐다 (맵이 있으면 맵 바닥을 그대로 쓴다)
	local base = cframe
	if not usingMapSpots then
		newPart({
			Name = "Ground",
			Size = Vector3.new(PLOT_SIZE, 1, PLOT_SIZE),
			CFrame = cframe * CFrame.new(0, 0.5, 0),
			Color = Color3.fromRGB(235, 240, 245),
			Material = Enum.Material.Snow,
			Parent = model,
		})
		base = cframe * CFrame.new(0, 1, 0)
	end
	if treeTemplate then
		local tree = treeTemplate:Clone()
		tree.Name = "Tree"
		tree:PivotTo(base * treeTemplatePivot)
		tree.Parent = model
	else
		buildCylinderTree(model, base)
	end

	-- 이름표
	local signPart = newPart({
		Name = "Sign",
		Size = Vector3.new(1, 1, 1),
		CFrame = base * CFrame.new(0, treeTop() + 6, 0),
		Transparency = 1,
		CanCollide = false,
		CanQuery = false,
		Parent = model,
	})
	local billboard = Instance.new("BillboardGui")
	billboard.Size = UDim2.fromOffset(260, 60)
	billboard.AlwaysOnTop = false
	billboard.MaxDistance = 150
	billboard.Parent = signPart
	local signLabel = Instance.new("TextLabel")
	signLabel.Size = UDim2.fromScale(1, 1)
	signLabel.BackgroundTransparency = 1
	signLabel.Font = Enum.Font.GothamBold
	signLabel.TextScaled = true
	signLabel.TextColor3 = Color3.new(1, 1, 1)
	signLabel.TextStrokeTransparency = 0.4
	signLabel.Text = "빈 자리"
	signLabel.Parent = billboard

	local decorations = Instance.new("Folder")
	decorations.Name = "Decorations"
	decorations.Parent = model

	model.Parent = plotsFolder
	plots[index] = {
		cframe = base, -- 트리 밑동 기준
		spawn = base * CFrame.new(0, 3, -14) * CFrame.Angles(0, math.pi, 0), -- 트리 앞 14스터드, 트리를 바라봄
		model = model,
		decorations = decorations,
		signLabel = signLabel,
		owner = nil,
	}
end

----------------------------------------------------------------
-- 장식 모양
----------------------------------------------------------------

local rainbowParts = {} -- 무지개 특성 파츠 (색을 계속 바꾼다)

-- 특성 효과: Traits.luau의 effect 이름으로 정한다
-- extras가 false면 반짝임·빛은 붙이지 않고 색·재질만 바꾼다 (Main 파츠가 여러 개일 때 첫 파츠에만 붙이려고)
local function applyTrait(part: BasePart, trait, extras: boolean)
	local effect = trait.effect
	if effect == "Sparkle" then
		if extras then
			Instance.new("Sparkles").Parent = part
		end
	elseif effect == "Frost" then
		part.Material = Enum.Material.Ice
		part.Color = part.Color:Lerp(Color3.new(1, 1, 1), 0.45)
	elseif effect == "Gold" then
		part.Color = Color3.fromRGB(255, 200, 40)
		part.Material = Enum.Material.Metal
		if extras then
			local sparkles = Instance.new("Sparkles")
			sparkles.SparkleColor = Color3.fromRGB(255, 220, 120)
			sparkles.Parent = part
		end
	elseif effect == "Rainbow" then
		part.Material = Enum.Material.Neon
		table.insert(rainbowParts, part)
	elseif effect == "Aurora" then
		part.Material = Enum.Material.Neon
		part.Color = Color3.fromRGB(120, 255, 200)
		if extras then
			local light = Instance.new("PointLight")
			light.Color = Color3.fromRGB(120, 255, 200)
			light.Range = 10
			light.Parent = part
			Instance.new("Sparkles").Parent = part
		end
	end
end

-- 장식의 몸통 색 (Colors.luau). 모르는 색이면 첫 번째 색
local function mainColor(entry): Color3
	local color = Catalog.ColorById[entry.col]
	return if color then color.color else Catalog.Colors[1].color
end

-- 임시 공 모양: 몸통 색 + 특성 효과
local function decorateLook(part: BasePart, color: Color3, trait)
	part.Color = color
	part.Material = Enum.Material.SmoothPlastic
	applyTrait(part, trait, true)
end

-- Studio 모델: 이름이 Main으로 시작하는 파츠에만 몸통 색 + 특성 효과를 입힌다.
-- Trim·Accent 파츠는 Studio에서 칠한 그대로 둔다. (docs/ASSET_RULES.md)
local warnedNoMain = {}
local function paintModel(model: Instance, color: Color3, trait)
	local parts = model:GetDescendants()
	table.insert(parts, model)
	local first = true
	for _, part in parts do
		if part:IsA("BasePart") and string.sub(part.Name, 1, 4) == "Main" then
			part.Color = color
			applyTrait(part, trait, first)
			first = false
		end
	end
	if first and not warnedNoMain[model.Name] then
		warnedNoMain[model.Name] = true
		warn("[Tree] 장식 모델에 Main 파츠가 없어 색과 특성을 입히지 못했습니다:", model.Name)
	end
end

-- Studio에서 만든 모델이 있으면 그걸 쓴다 (ReplicatedStorage.DecorationModels.모델이름)
local function cloneModel(deco)
	if not deco.model then
		return nil
	end
	local folder = ReplicatedStorage:FindFirstChild("DecorationModels")
	local template = folder and folder:FindFirstChild(deco.model)
	if not template then
		warn("[Tree] 장식 모델을 찾지 못했습니다:", deco.model)
		return nil
	end
	local clone = template:Clone()
	for _, descendant in clone:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.Anchored = true
			descendant.CanCollide = false
		end
	end
	if clone:IsA("BasePart") then
		clone.Anchored = true
		clone.CanCollide = false
	end
	return clone
end

local function renderEntry(plot, entry)
	local deco = Catalog.DecorationById[entry.d]
	local trait = Catalog.TraitById[entry.t]
	if not deco or not trait then
		return -- 카탈로그에 없는 장식은 보이지 않는다
	end
	local cf = plot.cframe * slotOffset(entry.a, entry.i)

	local color = mainColor(entry)
	local model = cloneModel(deco)
	if model then
		paintModel(model, color, trait)
		model:PivotTo(cf)
		if entry.a == "Topper" then
			-- 모델 밑면이 꼭대기 끝에 살짝 걸치게 올린다
			local box, boxSize = model:GetBoundingBox()
			local lift = (cf.Y - 0.3) - (box.Y - boxSize.Y / 2)
			model:PivotTo(model:GetPivot() + Vector3.new(0, lift, 0))
		end
		model.Parent = plot.decorations
		return
	end

	-- 임시 모양
	if entry.a == "Garland" then
		-- 트리 겉면을 비스듬히 도는 전구 줄: 전구 사이를 가는 전선으로 잇는다
		local holder = Instance.new("Model")
		holder.Name = deco.id
		local points = garlandPaths[entry.i] or {}
		for k = 1, GARLAND_BALLS do
			local point = points[k]
			if not point then
				continue
			end
			local ball = newPart({
				Shape = Enum.PartType.Ball,
				Size = Vector3.new(0.6, 0.6, 0.6),
				CFrame = plot.cframe * CFrame.new(point),
				CanCollide = false,
				CanQuery = false,
				CastShadow = false,
				Parent = holder,
			})
			decorateLook(ball, color, trait)

			local nextPoint = points[k % GARLAND_BALLS + 1]
			if nextPoint then
				local a = plot.cframe:PointToWorldSpace(point)
				local b = plot.cframe:PointToWorldSpace(nextPoint)
				newPart({
					Name = "Wire",
					Size = Vector3.new(0.1, 0.1, (b - a).Magnitude),
					CFrame = CFrame.lookAt((a + b) / 2, b),
					Color = GARLAND_WIRE_COLOR,
					CanCollide = false,
					CanQuery = false,
					CastShadow = false,
					Parent = holder,
				})
			end
		end
		holder.Parent = plot.decorations
	else
		local size = if entry.a == "Topper" then 2.4 else 1.4
		local part = newPart({
			Name = deco.id,
			Shape = Enum.PartType.Ball,
			Size = Vector3.new(size, size, size),
			-- 토퍼는 공 밑면이 꼭대기 끝에 살짝 걸치게
			CFrame = if entry.a == "Topper" then cf * CFrame.new(0, size / 2 - 0.3, 0) else cf,
			CanCollide = false,
			Parent = plot.decorations,
		})
		decorateLook(part, color, trait)
		if entry.a == "Topper" then
			part.Material = Enum.Material.Neon
		end
	end
end

local function updateSign(plotIndex: number)
	local plot = plots[plotIndex]
	if not plot then
		return
	end
	local owner = plot.owner
	if owner then
		local profile = PlayerData.Get(owner)
		local value = if profile then Income.GetTreeValue(profile) else 0
		plot.signLabel.Text = string.format("%s님의 트리\n가치 %s코인", owner.DisplayName, Gacha.FormatNumber(value))
	elseif plot.keptName then
		plot.signLabel.Text = string.format("%s님의 트리\n(자리 비움)", plot.keptName)
	else
		plot.signLabel.Text = "빈 자리"
	end
end

local function updateTreeValueStat(player: Player)
	local profile = PlayerData.Get(player)
	local leaderstats = player:FindFirstChild("leaderstats")
	local stat = leaderstats and leaderstats:FindFirstChild("TreeValue")
	if profile and stat then
		stat.Value = Income.GetTreeValue(profile)
	end
end

local function render(player: Player)
	local plotIndex = plotOf[player]
	local profile = PlayerData.Get(player)
	if not plotIndex or not profile then
		return
	end
	local plot = plots[plotIndex]
	plot.decorations:ClearAllChildren()
	for _, entry in profile.tree do
		renderEntry(plot, entry)
	end
	updateSign(plotIndex)
	updateTreeValueStat(player)
end

-- 플롯을 없앤다 (자리를 비운다)
local function destroyPlot(plotIndex: number)
	local plot = plots[plotIndex]
	if plot then
		plot.model:Destroy()
		plots[plotIndex] = nil
	end
end

----------------------------------------------------------------
-- 배정
----------------------------------------------------------------

local function teleportToPlot(player: Player)
	local plotIndex = plotOf[player]
	local character = player.Character
	if plotIndex and character then
		character:PivotTo(plots[plotIndex].spawn)
	end
end

-- 자리 배정: 5분 안에 돌아온 사람은 원래 자리 → 비어 있는 가장 안쪽 자리 → 남겨 둔 트리 중 가장 오래된 것을 치우고 그 자리
local function assignPlot(player: Player)
	for index, plot in plots do
		if plot.owner == nil and plot.keptFor == player.UserId then
			plot.owner = player
			plot.keptFor, plot.keptName, plot.keptUntil = nil, nil, nil
			plotOf[player] = index
			return index
		end
	end

	for index = 1, #plotPositions do
		if not plots[index] then
			buildPlot(index)
			plots[index].owner = player
			plotOf[player] = index
			return index
		end
	end

	local oldestIndex, oldestUntil = nil, math.huge
	for index, plot in plots do
		if plot.owner == nil and (plot.keptUntil or 0) < oldestUntil then
			oldestIndex, oldestUntil = index, plot.keptUntil or 0
		end
	end
	if oldestIndex then
		destroyPlot(oldestIndex)
		buildPlot(oldestIndex)
		plots[oldestIndex].owner = player
		plotOf[player] = oldestIndex
		return oldestIndex
	end
	return nil
end

local function onPlayerAdded(player: Player)
	-- 데이터를 다 불러올 때까지 기다린다
	local waited = 0
	while not PlayerData.Get(player) and player.Parent and waited < 30 do
		waited += task.wait(0.2)
	end
	if not PlayerData.Get(player) or not player.Parent then
		return
	end

	local leaderstats = player:WaitForChild("leaderstats", 10)
	if leaderstats and not leaderstats:FindFirstChild("TreeValue") then
		local stat = Instance.new("IntValue")
		stat.Name = "TreeValue"
		stat.Parent = leaderstats
	end

	if not assignPlot(player) then
		warn("[Tree] 빈 플롯이 없습니다. 서버 인원 설정을 확인해 주세요:", player.Name)
		return
	end
	render(player)

	player.CharacterAdded:Connect(function(character)
		character:WaitForChild("HumanoidRootPart", 10)
		task.wait()
		teleportToPlot(player)
	end)
	teleportToPlot(player)
end

-- 나가면 트리를 PLOT_KEEP_SECONDS 동안 남겨 둔다 (수입은 없음)
local function onPlayerRemoving(player: Player)
	local plotIndex = plotOf[player]
	plotOf[player] = nil
	local plot = plotIndex and plots[plotIndex]
	if not plot then
		return
	end
	plot.owner = nil
	plot.keptFor = player.UserId
	plot.keptName = player.DisplayName
	plot.keptUntil = workspace:GetServerTimeNow() + Config.PLOT_KEEP_SECONDS
	updateSign(plotIndex)

	local model = plot.model
	task.delay(Config.PLOT_KEEP_SECONDS, function()
		local current = plots[plotIndex]
		-- 그사이 돌아왔거나 다른 사람이 자리를 받았으면 그대로 둔다
		if current and current.model == model and current.owner == nil and current.keptFor == player.UserId then
			destroyPlot(plotIndex)
		end
	end)
end

----------------------------------------------------------------
-- 걸기·빼기
----------------------------------------------------------------

local function fail(reason: string)
	return { ok = false, reason = reason }
end

local function isWholeNumber(value: any, min: number, max: number): boolean
	return type(value) == "number" and value % 1 == 0 and value >= min and value <= max
end

local function getReadyProfile(player: Player)
	local profile = PlayerData.Get(player)
	if not profile then
		return nil, "데이터를 불러오는 중입니다"
	end
	if not plotOf[player] then
		return nil, "트리 자리를 준비하는 중입니다"
	end
	-- 슬롯이 돌아가는 중에 바꾸면 결과가 미리 보이므로 막는다
	if workspace:GetServerTimeNow() < profile.busyUntil then
		return nil, "룰렛이 멈춘 뒤에 할 수 있습니다"
	end
	return profile, nil
end

local function findEntry(profile, area: string, index: number)
	for i, entry in profile.tree do
		if entry.a == area and entry.i == index then
			return entry, i
		end
	end
	return nil, nil
end

-- 가방의 장식 1개를 그 장식 영역의 첫 빈자리에 건다
local function onPlace(player: Player, key: any)
	if type(key) ~= "string" then
		return fail("잘못된 요청입니다")
	end
	local profile, reason = getReadyProfile(player)
	if not profile then
		return fail(reason)
	end
	local stack = PlayerData.FindStack(profile, key)
	if not stack or stack.c <= 0 or not PlayerData.IsKnownStack(stack) then
		return fail("가방에 없는 장식입니다")
	end
	local deco = Catalog.DecorationById[stack.d]

	local freeIndex = nil
	for index = 1, AREA_CAPACITY[deco.area] do
		if not findEntry(profile, deco.area, index) then
			freeIndex = index
			break
		end
	end
	if not freeIndex then
		return fail(string.format("%s 자리가 모두 찼습니다. 트리에서 하나를 빼 주세요", Catalog.AREAS[deco.area]))
	end

	stack.c -= 1
	PlayerData.RemoveEmptyStacks(profile)
	table.insert(profile.tree, { a = deco.area, i = freeIndex, d = stack.d, t = stack.t, col = stack.col })
	render(player)

	return { ok = true, area = deco.area, index = freeIndex, state = GachaService.BuildState(player) }
end

-- 트리에서 장식을 빼서 가방에 넣는다
local function onRemove(player: Player, area: any, index: any)
	if type(area) ~= "string" or not AREA_CAPACITY[area] or not isWholeNumber(index, 1, AREA_CAPACITY[area]) then
		return fail("잘못된 요청입니다")
	end
	local profile, reason = getReadyProfile(player)
	if not profile then
		return fail(reason)
	end
	local entry, position = findEntry(profile, area, index)
	if not entry then
		return fail("빈 자리입니다")
	end

	-- 가방에 같은 칸이 없으면 새 칸이 필요하다
	local key = PlayerData.StackKey(entry.d, entry.t, entry.col)
	local existing = PlayerData.FindStack(profile, key)
	if not existing and PlayerData.GetBagSlotsUsed(profile) >= profile.bagCapacity then
		return fail("가방이 가득 찼습니다. 판매하거나 확장해 주세요")
	end

	table.remove(profile.tree, position)
	local deco = Catalog.DecorationById[entry.d]
	local trait = Catalog.TraitById[entry.t]
	if existing then
		existing.c += 1
	elseif deco and trait then
		PlayerData.AddItem(profile, deco, trait, entry.col, 1)
	else
		table.insert(profile.stacks, { d = entry.d, t = entry.t, col = entry.col, c = 1, l = false })
	end
	render(player)

	return { ok = true, state = GachaService.BuildState(player) }
end

----------------------------------------------------------------
-- 시작
----------------------------------------------------------------

function TreeService.Init()
	loadMapSpots()
	loadTreeTemplate()
	if not treeTemplate then
		local bands = {}
		for i, layer in LAYERS do
			table.insert(bands, { layerBottom(i), layerBottom(i) + layer.height })
		end
		buildSlotPositions(bands, cylinderSurfaceRadius)
	end
	plotsFolder = Instance.new("Folder")
	plotsFolder.Name = "Plots"
	plotsFolder.Parent = workspace

	Remotes.PlaceDecoration.OnServerInvoke = onPlace
	Remotes.RemoveDecoration.OnServerInvoke = onRemove

	Players.PlayerAdded:Connect(onPlayerAdded)
	Players.PlayerRemoving:Connect(onPlayerRemoving)
	for _, player in Players:GetPlayers() do
		task.spawn(onPlayerAdded, player)
	end

	-- 전시 수익: 1초마다 코인을 넣는다 (소수점은 모아 뒀다가 1이 되면 넣는다)
	task.spawn(function()
		while true do
			task.wait(1)
			for player in plotOf do
				local profile = PlayerData.Get(player)
				if profile then
					profile.coinCarry += Income.GetPerSec(profile)
					local whole = math.floor(profile.coinCarry)
					if whole >= 1 then
						profile.coinCarry -= whole
						PlayerData.AddCoins(player, whole)
					end
				end
			end
			-- 이름표의 트리 가치는 그대로지만, 주인이 바뀐 경우를 위해 가끔 갱신
		end
	end)

	-- 무지개 특성: 색을 천천히 바꾼다
	local hue = 0
	local elapsed = 0
	RunService.Heartbeat:Connect(function(dt)
		elapsed += dt
		if elapsed < 0.15 then
			return
		end
		hue = (hue + elapsed * 0.25) % 1
		elapsed = 0
		local alive = {}
		local color = Color3.fromHSV(hue, 0.8, 1)
		for _, part in rainbowParts do
			if part.Parent then
				part.Color = color
				table.insert(alive, part)
			end
		end
		rainbowParts = alive
	end)
end

return TreeService
