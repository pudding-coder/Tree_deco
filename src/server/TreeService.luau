-- 트리 꾸미기·전시 (GAME_RULES.md '트리 꾸미기', '전시·수익')
-- 서버는 빈 광장에서 시작한다. 플레이어가 들어오면 플롯(트리)이 생기고, 나가면 PLOT_KEEP_SECONDS 뒤에 사라진다.
-- 플롯에는 트리가 서 있고, 정해진 자리에 장식을 건다.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Rarity = require(Shared:WaitForChild("Rarity"))
local Gacha = require(Shared:WaitForChild("Gacha"))
local Catalog = require(Shared:WaitForChild("Catalog"))
local Remotes = ReplicatedStorage:WaitForChild("Remotes")

local PlayerData = require(script.Parent.PlayerData)
local GachaService = require(script.Parent.GachaService)
local Income = require(script.Parent.Income)
local TraitEffects = require(script.Parent.TraitEffects)
local TreeFx = require(script.Parent.TreeFx)

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
-- 1번 자리부터 채워지므로 아래 띠 → 가운데 띠 → 위 띠 순서로, 같은 띠에서는 앞쪽부터 둔다
-- (띠 2번이 아래, 1번이 가운데, 3번이 위: GARLAND_TIERS)
-- 정확히 옆(±90도)은 트리 가장자리에 떠 보여서 피한다
local ORNAMENT_SPOTS = {
	-- 아래 띠: 앞 둘, 뒤 둘
	{ garland = 2, angle = -45 },
	{ garland = 2, angle = 45 },
	{ garland = 2, angle = 135 },
	{ garland = 2, angle = -135 },
	-- 가운데 띠: 정면, 뒤 양쪽
	{ garland = 1, angle = 0 },
	{ garland = 1, angle = -120 },
	{ garland = 1, angle = 120 },
	-- 위 띠: 앞 둘, 뒤
	{ garland = 3, angle = -50 },
	{ garland = 3, angle = 50 },
	{ garland = 3, angle = 180 },
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
local slotOrder = {} -- [영역] = { 자리 번호, ... } 아래 자리부터. 빈자리를 채우는 순서로도 쓴다 (publishSlotOrder)

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
	local roughMeshes = 0
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.Anchored = true
			table.insert(parts, descendant)
			if descendant:IsA("MeshPart") and descendant.CollisionFidelity ~= Enum.CollisionFidelity.PreciseConvexDecomposition then
				roughMeshes += 1
			end
		end
	end
	if roughMeshes > 0 then
		-- 장식을 붙일 때 광선으로 겉면을 재는데, 광선은 보이는 모양이 아니라 충돌 모양에 맞는다
		-- 충돌 모양이 덩어리(Default·Hull·Box)면 층 사이 오목한 곳을 못 재서 장식·띠가 떠 보인다
		warn(string.format(
			"[Tree] TreeTemplate의 MeshPart %d개가 CollisionFidelity = PreciseConvexDecomposition이 아닙니다. 장식이 트리에서 떠 보입니다. docs/MAP.md를 보고 바꿔 주세요.",
			roughMeshes
		))
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

-- 투명벽: 편집할 때는 보이게(반투명) 두고, 게임이 시작되면 안 보이게 한다 (docs/MAP.md '투명벽')
local function hideMapWalls()
	for _, name in { "MapWalls", "Walls" } do
		local folder = workspace:FindFirstChild(name)
		if folder then
			for _, part in folder:GetDescendants() do
				if part:IsA("BasePart") then
					part.Transparency = 1
					part.CanQuery = false
					part.CastShadow = false
					part:ClearAllChildren() -- 편집용 글자 표시 등
				end
			end
		end
	end
end

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
	local effects = Instance.new("Folder")
	effects.Name = "Effects" -- 상점 트리 효과·바닥 아이템
	effects.Parent = model

	model.Parent = plotsFolder
	plots[index] = {
		cframe = base, -- 트리 밑동 기준
		spawn = base * CFrame.new(0, 3, -14) * CFrame.Angles(0, math.pi, 0), -- 트리 앞 14스터드, 트리를 바라봄
		model = model,
		decorations = decorations,
		effects = effects,
		signLabel = signLabel,
		owner = nil,
	}
end

----------------------------------------------------------------
-- 장식 모양
----------------------------------------------------------------

-- 임시 모양(등급 색 공)의 겉모습. withExtras가 false면 특성 파티클·빛은 붙이지 않는다
local function decorateLook(part: BasePart, deco, trait, withExtras: boolean?)
	local r = Rarity.List[deco.rarity]
	part.Color = r.color
	part.Material = if deco.rarity >= 4 then Enum.Material.Neon else Enum.Material.SmoothPlastic
	if deco.rarity >= 5 then
		local light = Instance.new("PointLight")
		light.Color = r.color
		light.Range = 8
		light.Parent = part
	end
	TraitEffects.Apply(part, trait, withExtras)
end

-- Studio에서 만든 모델이 있으면 그걸 쓴다 (ReplicatedStorage.DecorationModels.장식id 또는 model에 적은 이름)
-- 장식 모델 크기: 모델에서 가장 긴 변을 이 길이(스터드)에 맞춘다. 장식 목록의 size로 장식마다 배수를 줄 수 있다
-- 임시 공(오너먼트 1.4, 토퍼 2.4)보다 크다. 띠는 모델이 줄 모양이라 아직 크기를 맞추지 않는다
local MODEL_SIZE = { Topper = 4, Ornament = 2.3 }
-- 오너먼트 모델이 가지에 매달린 것처럼 보이게 윗부분을 트리 쪽으로 기울인다(도). 장식 목록의 lean으로 장식마다 바꿀 수 있다
local ORNAMENT_LEAN = 10
-- 오너먼트 모델의 가장 안쪽(트리 쪽 끝)이 자리보다 이만큼 바깥에 오게 한다(스터드. 음수면 안쪽)
-- 자리는 트리 겉면 +0.6, 띠 전구 가운데는 겉면 +0.35라서 -0.25면 트리 쪽 끝이 전구 가운데 깊이에 온다
local ORNAMENT_GAP = -0.25
-- 위 계산은 어림이라, 놓은 뒤 실제 트리 겉면까지 광선으로 재서 다시 붙인다
-- 모델의 트리 쪽 끝이 실제 겉면에서 이만큼 바깥에 온다(스터드). 띠 전구 가운데가 겉면 +0.35
-- 음수면 그만큼 트리 안으로 파묻는다. 충돌 모양이 보이는 겉면보다 조금 바깥이라 살짝 파묻어야 붙어 보인다
local ORNAMENT_SURFACE_GAP = -0.3

local function cloneModel(deco)
	-- model을 적지 않았으면 장식 id와 같은 이름의 모델을 쓴다
	local modelName = deco.model or deco.id
	local folder = ReplicatedStorage:FindFirstChild("DecorationModels")
	local template = folder and folder:FindFirstChild(modelName)
	if not template then
		if deco.model then -- 직접 적은 이름만 경고한다 (모델이 아직 없는 장식은 임시 모양으로 보인다)
			warn("[Tree] 장식 모델을 찾지 못했습니다:", deco.model)
		end
		return nil
	end
	local clone = template:Clone()
	if clone:IsA("BasePart") then
		-- 파츠 하나짜리 모델도 Model로 감싸서 똑같이 다룬다
		local holder = Instance.new("Model")
		holder.Name = clone.Name
		clone.Parent = holder
		holder.PrimaryPart = clone
		clone = holder
	elseif not clone:IsA("Model") and clone:FindFirstChildWhichIsA("BasePart", true) then
		-- Tool(손에 드는 도구)·Accessory(모자류)처럼 안에 파츠가 든 것도 Model로 감싸서 쓴다
		local holder = Instance.new("Model")
		holder.Name = clone.Name
		clone.Parent = holder
		clone = holder
	elseif not clone:IsA("Model") then
		warn("[Tree] 장식 모델 안에 파츠가 없습니다:", modelName, clone.ClassName)
		return nil
	end
	-- 장식은 보기만 하는 것: 줍기·들기·앉기·누르기가 되지 않게 한다
	-- Tool·Accessory는 닿으면 플레이어가 주워 들 수 있으므로 Model로 바꾸고, 스크립트와 닿음 판정을 없앤다
	for _, descendant in clone:GetDescendants() do
		if descendant:IsA("Tool") or descendant:IsA("Accessory") or descendant:IsA("HopperBin") then
			local plain = Instance.new("Model")
			plain.Name = descendant.Name
			for _, child in descendant:GetChildren() do
				child.Parent = plain
			end
			plain.Parent = descendant.Parent
			descendant:Destroy()
		end
	end
	for _, descendant in clone:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.Anchored = true
			descendant.CanCollide = false
			descendant.CanTouch = false
		elseif
			descendant:IsA("LuaSourceContainer")
			or descendant:IsA("TouchTransmitter")
			or descendant:IsA("ClickDetector")
			or descendant:IsA("ProximityPrompt")
		then
			descendant:Destroy()
		end
	end
	-- 방향 기준: DecorationModels에 놓인 그대로의 월드 방향을 쓴다 (모델 피벗 방향은 무시)
	-- Studio에서 모델의 앞이 Front(-Z), 위가 위(+Y)를 보게 돌려 두면 트리에서도 그쪽이 앞이 된다 (docs/DECORATION_MODELS.md)
	-- PrimaryPart가 있으면 피벗이 그 파츠 방향을 따라가므로 잠깐 빼고, 놓은 뒤 renderEntry에서 되돌린다
	local primary = clone.PrimaryPart
	clone.PrimaryPart = nil
	clone.WorldPivot = CFrame.new(clone:GetPivot().Position)
	return clone, primary
end

-- 서버 시작 때 장식 모델 연결 상태를 Output에 알린다 (모델이 안 보일 때 원인 찾기용)
local function reportDecorationModels()
	if workspace:FindFirstChild("DecorationPreview") then
		warn("[Tree] Workspace에 DecorationPreview가 남아 있습니다. 꺼내 둔 모델은 게임에 쓰이지 않습니다. Play를 멈추고 docs/DECORATION_MODELS.md의 3번(다시 넣기) 스크립트를 실행해 주세요.")
	end
	local folder = ReplicatedStorage:FindFirstChild("DecorationModels")
	if not folder then
		warn("[Tree] ReplicatedStorage에 DecorationModels 폴더가 없습니다. 모든 장식이 임시 모양으로 보입니다.")
		return
	end
	local linked, missing = {}, {}
	local used = {}
	for _, deco in Catalog.Decorations do
		local modelName = deco.model or deco.id
		if folder:FindFirstChild(modelName) then
			table.insert(linked, deco.id)
			used[modelName] = true
		elseif deco.model then
			table.insert(missing, deco.id .. "(" .. deco.model .. ")")
		end
	end
	local unused = {}
	for _, child in folder:GetChildren() do
		if not used[child.Name] then
			table.insert(unused, child.Name)
		end
	end
	print(string.format("[Tree] 장식 모델 %d개 연결: %s", #linked, table.concat(linked, ", ")))
	if #missing > 0 then
		warn("[Tree] model에 적었지만 폴더에 없는 모델: " .. table.concat(missing, ", "))
	end
	if #unused > 0 then
		warn("[Tree] 이름이 어떤 장식 id와도 맞지 않는 모델: " .. table.concat(unused, ", "))
	end
end

-- 모델을 자리에 맞춰 놓는다: 크기를 맞추고, 정면이 바깥을 보게 돌리고, 모델 가운데가 자리에 오게 한다
-- (FBX로 들여온 모델은 피벗이 가운데가 아닌 경우가 많아서 피벗 대신 모델 상자 가운데를 기준으로 한다)
-- sizeScale: 뽑을 때 정해진 크기 배수 (Config.SIZES의 scale)
local function placeModel(model: Model, area: string, deco, cf: CFrame, sizeScale: number)
	local target = MODEL_SIZE[area]
	if target then
		local _, boxSize = model:GetBoundingBox()
		local longest = math.max(boxSize.X, boxSize.Y, boxSize.Z)
		if longest > 0 then
			model:ScaleTo(model:GetScale() * target * deco.size * sizeScale / longest)
		end
	end

	local facing = cf
	if area == "Ornament" then
		local lean = math.rad(deco.lean or ORNAMENT_LEAN)
		-- 모델 앞뒤 두께(turn으로 돌린 뒤 기준)와 기울였을 때 윗부분이 트리 쪽으로 들어오는 만큼 바깥으로 밀어
		-- 모델이 띠·트리에 묻히지 않게 한다
		local _, boxSize = model:GetBoundingBox()
		local t = math.rad(deco.turn)
		local depth = math.abs(math.cos(t)) * boxSize.Z + math.abs(math.sin(t)) * boxSize.X
		local out = depth / 2 + boxSize.Y / 2 * math.abs(math.sin(lean)) + ORNAMENT_GAP
		-- 오너먼트 자리는 트리 쪽을 바라본다(LookVector가 트리 쪽). 바깥으로 밀고, 모델 정면(-Z)이 바깥을 보게 뒤집는다
		facing = (cf - cf.LookVector * out) * CFrame.Angles(0, math.pi, 0)
		-- 윗부분을 트리 쪽(+Z)으로 기울인다. turn보다 먼저 해서 모델을 돌려도 트리 쪽으로 기운다
		facing *= CFrame.Angles(lean, 0, 0)
	end
	facing *= CFrame.Angles(0, math.rad(deco.turn), 0)

	local box = model:GetBoundingBox()
	local pivotFromBox = box:ToObjectSpace(model:GetPivot())
	model:PivotTo(facing * pivotFromBox)
end

-- 오너먼트 모델 뒷면 윗부분 여러 점에서 트리 쪽으로 광선을 쏴 실제 겉면까지 거리를 재고, 가장 가까운 점이 ORNAMENT_SURFACE_GAP에 오게 옮긴다
-- 윗부분만 재는 이유: 트리는 층마다 아래 가지가 튀어나와서, 아랫부분까지 재면 그 가지에 걸려 윗부분이 떠 보인다.
-- 매달린 장식처럼 윗부분(고리 쪽)을 트리에 붙이고, 아랫부분은 아래 가지에 살짝 걸쳐도 둔다. 광선이 하나도 안 맞으면 그대로 둔다
local snapMissWarned = {} -- 같은 경고를 한 번만 띄운다
local function snapToTree(model: Model, deco, plot, cf: CFrame)
	local treeParts = {}
	for _, child in plot.model:GetChildren() do
		if child ~= plot.decorations and child.Name ~= "Sign" and child.Name ~= "Ground" then
			table.insert(treeParts, child)
		end
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = treeParts

	local inward = Vector3.new(cf.LookVector.X, 0, cf.LookVector.Z)
	if inward.Magnitude < 1e-3 then
		return
	end
	inward = inward.Unit
	local box, size = model:GetBoundingBox() -- 놓은 방향(기울기 포함)을 따른 상자. +Z가 트리 쪽
	local nearest = math.huge
	for _, u in { -0.4, 0, 0.4 } do
		for _, v in { 0.05, 0.25, 0.45 } do
			local point = box:PointToWorldSpace(Vector3.new(u * size.X, v * size.Y, size.Z / 2))
			local origin = point - inward * 5 -- 모델이 트리에 묻혀 있어도 바깥에서 쏜다
			local hit = workspace:Raycast(origin, inward * 20, params)
			if hit then
				nearest = math.min(nearest, (hit.Position - point):Dot(inward))
			end
		end
	end
	if nearest < math.huge then
		model:PivotTo(model:GetPivot() + inward * (nearest - ORNAMENT_SURFACE_GAP - deco.out))
	elseif not snapMissWarned[model.Name] then
		snapMissWarned[model.Name] = true
		warn("[Tree] 오너먼트를 트리에 붙이지 못했습니다(광선이 트리에 안 맞음). 계산한 위치에 둡니다:", model.Name)
	end
end

----------------------------------------------------------------
-- 잡을 수 있는 장식 (holdable): 캐릭터가 장식에 닿으면 손을 뻗어 잡은 채 트리에 그대로 붙는다
-- 보이지 않는 사본 Tool을 장식 자리에 고정해 두고 캐릭터가 그것을 든다(도구 드는 팔 자세).
-- 손잡이가 고정돼 있어서 캐릭터가 트리에 매달린다. 점프하면 놓고 내려온다. 장식은 트리에서 빠지지 않는다
----------------------------------------------------------------

local HOLD_ATTRIBUTE = "HoldDecoId" -- 잡기용 사본 Tool에 붙여 둔다
local HOLD_COOLDOWN = 1.5 -- 놓은 뒤 이 시간(초) 동안은 닿아도 다시 잡지 않는다 (내려올 수 있게)
local holdCooldown = {} -- [Player] = 다시 잡을 수 있는 시각

-- 사본 Tool: DecorationModels 원본(안에 Tool이 있으면 그 Tool) 모양 그대로, 보이지 않게
local function buildHoldTool(deco): Tool?
	local folder = ReplicatedStorage:FindFirstChild("DecorationModels")
	local template = folder and folder:FindFirstChild(deco.model or deco.id)
	if not template then
		return nil
	end
	local source = if template:IsA("Tool") then template else template:FindFirstChildWhichIsA("Tool", true)
	local tool = Instance.new("Tool")
	tool.Name = deco.name
	tool.CanBeDropped = false
	tool.RequiresHandle = true
	tool.ManualActivationOnly = true
	tool:SetAttribute(HOLD_ATTRIBUTE, deco.id)
	if source then
		tool.Grip = source.Grip
	end
	local root = (source or template):Clone()
	if root:IsA("BasePart") then
		root.Parent = tool
	else
		for _, child in root:GetChildren() do
			child.Parent = tool
		end
		root:Destroy()
	end
	local parts = {}
	for _, d in tool:GetDescendants() do
		if
			d:IsA("LuaSourceContainer")
			or d:IsA("ProximityPrompt")
			or d:IsA("ClickDetector")
			or d:IsA("Decal")
			or d:IsA("Texture")
		then
			d:Destroy()
		elseif d:IsA("BasePart") then
			table.insert(parts, d)
		end
	end
	if #parts == 0 then
		tool:Destroy()
		return nil
	end
	local handle = tool:FindFirstChild("Handle")
	if not (handle and handle:IsA("BasePart")) then
		table.sort(parts, function(x, y)
			return x.Size.Magnitude > y.Size.Magnitude
		end)
		handle = parts[1]
		handle.Name = "Handle"
		handle.Parent = tool
	end
	for _, part in parts do
		part.Transparency = 1 -- 트리의 장식이 보이므로 사본은 숨긴다
		part.CanCollide = false
		part.CanTouch = false
		part.CanQuery = false
		part.Massless = true
		part.Anchored = part == handle -- 손잡이만 고정: 이걸 쥔 캐릭터가 그 자리에 매달린다
		if part ~= handle then
			local weld = Instance.new("WeldConstraint")
			weld.Part0 = handle
			weld.Part1 = part
			weld.Parent = handle
		end
	end
	return tool
end

-- 잡은 것을 놓는다 (점프했을 때)
local function releaseHold(player: Player)
	local character = player.Character
	if not character then
		return
	end
	for _, item in character:GetChildren() do
		if item:IsA("Tool") and item:GetAttribute(HOLD_ATTRIBUTE) then
			item:Destroy()
			holdCooldown[player] = os.clock() + HOLD_COOLDOWN
		end
	end
	character:SetAttribute("HoldingTree", nil)
end

-- 캐릭터가 트리의 holdable 장식에 닿았다
local function tryHold(model: Model, deco, hit: BasePart)
	local character = hit:FindFirstAncestorOfClass("Model")
	local player = character and Players:GetPlayerFromCharacter(character)
	if not player or not model.Parent then
		return
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 or character:GetAttribute("HoldingTree") then
		return
	end
	if os.clock() < (holdCooldown[player] or 0) then
		return
	end
	-- 트리 장식의 손잡이 자리 (원본이 Tool이면 Handle, 아니면 가장 큰 파츠)
	local anchor = model:FindFirstChild("Handle", true)
	if not (anchor and anchor:IsA("BasePart")) then
		local biggest = 0
		for _, part in model:GetDescendants() do
			if part:IsA("BasePart") and part.Size.Magnitude > biggest then
				anchor, biggest = part, part.Size.Magnitude
			end
		end
	end
	if not anchor then
		return
	end
	local tool = buildHoldTool(deco)
	if not tool then
		return
	end
	character:SetAttribute("HoldingTree", true)
	humanoid:UnequipTools() -- 다른 도구를 들고 있으면 내려놓는다
	tool.Handle.CFrame = anchor.CFrame
	tool.Parent = character -- 들면 손과 손잡이가 이어지고, 손잡이가 고정돼 있어 트리에 매달린다
	-- 장식이 트리에서 빠지면 같이 놓는다
	model.AncestryChanged:Connect(function(_, parent)
		if parent == nil and tool.Parent then
			releaseHold(player)
		end
	end)
	-- 손에서 떨어지면(아래 도구 칸을 눌러 내려놓기, 죽음 등) 바로 없앤다
	-- 가방(Backpack)에 남겨 두면 다시 들 때 엉뚱한 자리에 매달리고, 또 닿으면 사본이 하나 더 생긴다
	tool.AncestryChanged:Connect(function()
		if tool.Parent == character then
			return
		end
		if tool.Parent then
			tool:Destroy()
		end
		holdCooldown[player] = os.clock() + HOLD_COOLDOWN
		if character.Parent then
			character:SetAttribute("HoldingTree", nil)
		end
	end)
end

-- 트리에 걸린 holdable 장식이 닿으면 잡히게 한다
local function makeHoldable(model: Model, deco)
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") then
			part.CanTouch = true
			part.Touched:Connect(function(hit)
				tryHold(model, deco, hit)
			end)
		end
	end
end

local function renderEntry(plot, entry)
	local deco = Catalog.DecorationById[entry.d]
	local trait = Catalog.TraitById[entry.t]
	if not deco or not trait then
		return -- 카탈로그에 없는 장식은 보이지 않는다
	end
	local cf = plot.cframe * slotOffset(entry.a, entry.i)

	local paint = entry.p and Catalog.PaintById[entry.p] -- 뽑을 때 정해진 색 (paintable 장식만)
	local sizeScale = Catalog.SizeOf(entry.s).scale -- 뽑을 때 정해진 크기 (띠는 항상 보통)
	local model, primary = cloneModel(deco)
	if model then
		placeModel(model, entry.a, deco, cf, sizeScale)
		if entry.a == "Ornament" then
			snapToTree(model, deco, plot, cf)
		end
		if entry.a == "Topper" then
			-- 모델 밑면이 꼭대기 끝에 살짝 걸치게 올린다. sink만큼(모델 높이 비율) 더 내려 꼭대기에 씌운다
			local box, boxSize = model:GetBoundingBox()
			local lift = (cf.Y - 0.3 - boxSize.Y * deco.sink) - (box.Y - boxSize.Y / 2)
			model:PivotTo(model:GetPivot() + Vector3.new(0, lift, 0))
		end
		model.PrimaryPart = primary -- 특성 분위기가 붙을 파츠
		if paint then
			TraitEffects.Paint(model, paint.color) -- Paint 파츠만 칠한다
		end
		TraitEffects.Apply(model, trait)
		if deco.holdable then
			makeHoldable(model, deco)
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
			-- 특성 효과는 전구가 아니라 아래 띠 모양 운반 파츠에 붙인다
			decorateLook(ball, deco, trait, false)

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

		-- 특성 효과: 전구 2칸마다 보이지 않는 길쭉한 파츠를 놓고 거기에 효과를 붙여 줄 전체를 띠처럼 감싼다
		if trait.effect then
			local carrier = 0
			for k = 1, GARLAND_BALLS, 2 do
				local from = points[k]
				local to = points[(k + 1) % GARLAND_BALLS + 1]
				if not from or not to then
					continue
				end
				local a = plot.cframe:PointToWorldSpace(from)
				local b = plot.cframe:PointToWorldSpace(to)
				carrier += 1
				local band = newPart({
					Name = "TraitBand",
					Size = Vector3.new(0.8, 0.8, (b - a).Magnitude),
					CFrame = CFrame.lookAt((a + b) / 2, b),
					Transparency = 1,
					CanCollide = false,
					CanQuery = false,
					CanTouch = false,
					CastShadow = false,
					Parent = holder,
				})
				-- 빛은 몇 곳에만 (많으면 무거워진다)
				TraitEffects.Apply(band, trait, { radius = 0.6, rateScale = 0.35, light = carrier % 4 == 1 })
			end
		end
		holder.Parent = plot.decorations
	else
		local size = (if entry.a == "Topper" then 2.4 else 1.4) * sizeScale
		local part = newPart({
			Name = deco.id,
			Shape = Enum.PartType.Ball,
			Size = Vector3.new(size, size, size),
			-- 토퍼는 공 밑면이 꼭대기 끝에 살짝 걸치게
			CFrame = if entry.a == "Topper" then cf * CFrame.new(0, size / 2 - 0.3, 0) else cf,
			CanCollide = false,
			Parent = plot.decorations,
		})
		decorateLook(part, deco, trait)
		if paint then
			TraitEffects.Paint(part, paint.color)
		end
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

-- 상점 트리 효과와 바닥 아이템을 다시 만든다 (TreeFx.luau)
-- 장식을 걸 때마다 render가 불리므로, 켠 효과가 바뀌었을 때만 다시 만든다 (벼락·컨페티가 끊기지 않게)
local function renderEffects(plot, profile)
	local key = (profile.effect or "") .. "|" .. table.concat(profile.floor, ",")
	if plot.effectsKey == key then
		return
	end
	plot.effectsKey = key
	plot.effects:ClearAllChildren()
	local radius = LAYERS[1].radius
	local tree = plot.model:FindFirstChild("Tree")
	if tree and tree:IsA("Model") then
		local _, size = tree:GetBoundingBox()
		radius = math.max(size.X, size.Z) / 2
	end
	local ctx = { base = plot.cframe, height = treeTop(), radius = radius, spot = 1 }

	local list = {}
	if profile.effect then
		table.insert(list, profile.effect)
	end
	for _, id in profile.floor do
		table.insert(list, id)
	end
	local spot = 0
	for _, id in list do
		local fx = Catalog.TreeEffectById[id]
		if not fx then
			continue -- 카탈로그에서 빠진 효과는 보이지 않는다
		end
		if fx.area == "Floor" and not fx.spread then
			spot += 1
			ctx.spot = spot
		end
		local ok, inst = pcall(TreeFx.Build, fx, ctx)
		if not ok then
			warn("[Tree] 트리 효과를 만들지 못했습니다:", id, inst)
		elseif inst then
			inst.Parent = plot.effects
		end
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
	renderEffects(plot, profile)
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

-- 가방의 장식 1개를 트리에 건다. index가 있으면 그 자리에, 없으면 그 장식 영역의 첫 빈자리에
local function onPlace(player: Player, key: any, index: any)
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
	local capacity = AREA_CAPACITY[deco.area]

	local freeIndex = nil
	if index ~= nil then
		if not isWholeNumber(index, 1, capacity) then
			return fail("잘못된 요청입니다")
		end
		if findEntry(profile, deco.area, index) then
			return fail("이미 장식이 걸린 자리입니다")
		end
		freeIndex = index
	else
		-- 아래 자리부터 채운다 (내 트리 창의 1, 2, 3 ... 순서)
		for _, i in slotOrder[deco.area] or {} do
			if not findEntry(profile, deco.area, i) then
				freeIndex = i
				break
			end
		end
	end
	if not freeIndex then
		return fail(string.format("%s 자리가 모두 찼습니다. 트리에서 하나를 빼 주세요", Catalog.AREAS[deco.area]))
	end

	stack.c -= 1
	PlayerData.RemoveEmptyStacks(profile)
	table.insert(profile.tree, { a = deco.area, i = freeIndex, d = stack.d, t = stack.t, p = stack.p, s = stack.s })
	render(player)

	return { ok = true, area = deco.area, index = freeIndex, state = GachaService.BuildState(player) }
end

----------------------------------------------------------------
-- 빈자리 자동 채우기
----------------------------------------------------------------

-- 가방에서 그 영역에 걸 가장 좋은 장식 칸: 등급이 높은 것, 같으면 가치(특성·크기 포함)가 높은 것
local function bestStackFor(profile, area: string)
	local best, bestRarity, bestValue = nil, 0, 0
	for _, stack in profile.stacks do
		if stack.c <= 0 or not PlayerData.IsKnownStack(stack) then
			continue
		end
		local deco = Catalog.DecorationById[stack.d]
		if deco.area ~= area then
			continue
		end
		local value = Gacha.GetItemValue(deco.rarity, Catalog.ValueMult(Catalog.TraitById[stack.t], stack.s))
		if not best or deco.rarity > bestRarity or (deco.rarity == bestRarity and value > bestValue) then
			best, bestRarity, bestValue = stack, deco.rarity, value
		end
	end
	return best
end

-- 트리의 빈자리를 아래 자리부터 가방의 가장 좋은 장식으로 채운다. 채운 개수를 돌려준다 (트리 모습은 바꾸지 않는다)
local function autoFillProfile(profile): number
	local placed = 0
	for area in AREA_CAPACITY do
		for _, index in slotOrder[area] or {} do
			if findEntry(profile, area, index) then
				continue
			end
			local stack = bestStackFor(profile, area)
			if not stack then
				break -- 이 영역에 걸 장식이 없다
			end
			stack.c -= 1
			table.insert(profile.tree, { a = area, i = index, d = stack.d, t = stack.t, p = stack.p, s = stack.s })
			placed += 1
		end
	end
	if placed > 0 then
		PlayerData.RemoveEmptyStacks(profile)
	end
	return placed
end

-- 뽑은 장식이 가방에 들어간 뒤 (GachaService가 부른다). 트리 모습은 슬롯이 멈춘 뒤에 바꿔서 결과를 미리 보여주지 않는다
local function onItemAdded(player: Player, profile, revealDelay: number)
	if not profile.autoFill or not plotOf[player] then
		return
	end
	if autoFillProfile(profile) > 0 then
		task.delay(revealDelay, function()
			if plotOf[player] then
				render(player)
			end
		end)
	end
end

-- 자동 채우기 켜고 끄기. 켜면 지금 빈자리도 바로 채운다
local function onSetAutoFill(player: Player, enabled: any)
	if type(enabled) ~= "boolean" then
		return fail("잘못된 요청입니다")
	end
	local profile, reason = getReadyProfile(player)
	if not profile then
		return fail(reason)
	end
	profile.autoFill = enabled
	local placed = 0
	if enabled then
		placed = autoFillProfile(profile)
		if placed > 0 then
			render(player)
		end
	end
	return { ok = true, placed = placed, state = GachaService.BuildState(player) }
end

-- 트리에서 장식을 빼서 가방에 넣는다. slots = { { a = 영역, i = 자리 번호 }, ... } (여러 개를 한 번에)
-- 가방 칸이 모자라면 하나도 빼지 않는다
local function onRemove(player: Player, slots: any)
	local totalCapacity = 0
	for _, capacity in AREA_CAPACITY do
		totalCapacity += capacity
	end
	if type(slots) ~= "table" or #slots < 1 or #slots > totalCapacity then
		return fail("잘못된 요청입니다")
	end
	local profile, reason = getReadyProfile(player)
	if not profile then
		return fail(reason)
	end

	local entries = {}
	local seen = {}
	for _, slot in slots do
		if type(slot) ~= "table" then
			return fail("잘못된 요청입니다")
		end
		local area, index = slot.a, slot.i
		if type(area) ~= "string" or not AREA_CAPACITY[area] or not isWholeNumber(index, 1, AREA_CAPACITY[area]) then
			return fail("잘못된 요청입니다")
		end
		local slotKey = area .. ":" .. index
		if seen[slotKey] then
			return fail("잘못된 요청입니다")
		end
		seen[slotKey] = true
		local entry = findEntry(profile, area, index)
		if not entry then
			return fail("빈 자리는 뺄 수 없습니다")
		end
		table.insert(entries, entry)
	end

	-- 가방에 같은 칸이 없으면 새 칸이 필요하다
	local newKeys = {}
	local needed = 0
	for _, entry in entries do
		local key = PlayerData.StackKey(entry.d, entry.t, entry.p, entry.s)
		if not PlayerData.FindStack(profile, key) and not newKeys[key] then
			newKeys[key] = true
			needed += 1
		end
	end
	local free = profile.bagCapacity - PlayerData.GetBagSlotsUsed(profile)
	if needed > free then
		return fail(string.format("가방 칸이 %d칸 모자랍니다. 판매하거나 확장해 주세요", needed - free))
	end

	for _, entry in entries do
		local _, position = findEntry(profile, entry.a, entry.i)
		if position then
			table.remove(profile.tree, position)
		end
		local deco = Catalog.DecorationById[entry.d]
		local trait = Catalog.TraitById[entry.t]
		local existing = PlayerData.FindStack(profile, PlayerData.StackKey(entry.d, entry.t, entry.p, entry.s))
		if existing then
			existing.c += 1
		elseif deco and trait then
			PlayerData.AddItem(profile, deco, trait, 1, entry.p, entry.s)
		else
			table.insert(profile.stacks, { d = entry.d, t = entry.t, p = entry.p, s = entry.s, c = 1, l = false })
		end
	end
	render(player)

	return { ok = true, removed = #entries, state = GachaService.BuildState(player) }
end

----------------------------------------------------------------
-- 시작
----------------------------------------------------------------

-- 내 트리 창이 칸을 아래부터 보여 주도록, 영역별 자리 번호를 높이가 낮은 순서로 알려 준다
-- (자리 번호 자체는 처음 몇 개만 걸어도 퍼지게 섞여 있어서 화면 순서와 다르다)
-- ReplicatedStorage 속성 TreeSlotOrder_<영역> = "2,5,1,..." (아래 자리부터)
local function publishSlotOrder()
	for area, capacity in AREA_CAPACITY do
		local heights = {}
		local indexes = {}
		for i = 1, capacity do
			table.insert(indexes, i)
			if area == "Ornament" and not ORNAMENT_SPOTS[i] and not customSlots.Ornament[i] then
				heights[i] = math.huge -- 자리 정보가 없는 번호는 맨 뒤로
			else
				heights[i] = slotOffset(area, i).Position.Y
			end
		end
		table.sort(indexes, function(a, b)
			if math.abs(heights[a] - heights[b]) > 0.05 then
				return heights[a] < heights[b]
			end
			return a < b
		end)
		slotOrder[area] = indexes
		ReplicatedStorage:SetAttribute("TreeSlotOrder_" .. area, table.concat(indexes, ","))
	end
end

-- 상점에서 트리 효과를 사거나 켜고 끈 뒤 부른다 (TreeEffectService)
function TreeService.RefreshEffects(player: Player)
	local plotIndex = plotOf[player]
	local profile = PlayerData.Get(player)
	if plotIndex and profile and plots[plotIndex] then
		renderEffects(plots[plotIndex], profile)
	end
end

function TreeService.Init()
	hideMapWalls()
	loadMapSpots()
	loadTreeTemplate()
	if not treeTemplate then
		local bands = {}
		for i, layer in LAYERS do
			table.insert(bands, { layerBottom(i), layerBottom(i) + layer.height })
		end
		buildSlotPositions(bands, cylinderSurfaceRadius)
	end
	publishSlotOrder()
	reportDecorationModels()
	TreeFx.Report(Catalog.TreeEffects)
	plotsFolder = Instance.new("Folder")
	plotsFolder.Name = "Plots"
	plotsFolder.Parent = workspace

	Remotes.ReleaseHold.OnServerEvent:Connect(releaseHold)
	Players.PlayerRemoving:Connect(function(player)
		holdCooldown[player] = nil
	end)
	Remotes.PlaceDecoration.OnServerInvoke = onPlace
	Remotes.RemoveDecoration.OnServerInvoke = onRemove
	Remotes.SetAutoFill.OnServerInvoke = onSetAutoFill
	GachaService.AfterItemAdded = onItemAdded

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
end

return TreeService
