-- 트리 꾸미기·전시 (GAME_RULES.md '트리 꾸미기', '전시·수익')
-- 서버는 빈 광장에서 시작한다. 플레이어가 들어오면 플롯(트리)이 생기고, 나가면 PLOT_KEEP_SECONDS 뒤에 사라진다.
-- 플롯에는 트리가 서 있고, 정해진 자리에 장식을 건다.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Rarity = require(Shared:WaitForChild("Rarity"))
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
local TRUNK_HEIGHT = 4
-- 트리 몸통: 아래층부터 { 반지름, 높이 }
local LAYERS = {
	{ radius = 9, height = 5 },
	{ radius = 7.5, height = 4.5 },
	{ radius = 6, height = 4 },
	{ radius = 4.5, height = 3.5 },
	{ radius = 3, height = 3 },
}
-- 오너먼트 자리: 층 번호와 각도(0 = 광장 쪽 정면, 도 단위)
local ORNAMENT_SPOTS = {
	{ layer = 1, angle = -70 },
	{ layer = 1, angle = 0 },
	{ layer = 1, angle = 70 },
	{ layer = 2, angle = -40 },
	{ layer = 2, angle = 40 },
	{ layer = 2, angle = 140 },
	{ layer = 3, angle = -90 },
	{ layer = 3, angle = 20 },
	{ layer = 4, angle = -20 },
	{ layer = 4, angle = 60 },
}
local GARLAND_BALLS = 16 -- 임시 띠 모양: 작은 공을 원으로 늘어놓는다

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
	if area == "Topper" then
		return CFrame.new(0, treeTop() + 1.6, 0)
	elseif area == "Ornament" then
		local spot = ORNAMENT_SPOTS[index]
		local layer = LAYERS[spot.layer]
		local pos = localPoint(spot.angle, layer.radius + 0.4, layerBottom(spot.layer) + 0.8)
		return CFrame.lookAt(pos, Vector3.new(0, pos.Y, 0)) -- 트리 쪽을 바라보게
	else -- Garland: 층과 층 사이에 두르는 원의 중심
		return CFrame.new(0, layerBottom(index + 1) + 0.2, 0)
	end
end

local function garlandRadius(index: number): number
	return LAYERS[index].radius * 0.85
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

local function buildPlot(index: number)
	local cframe = plotPositions[index]

	local model = Instance.new("Model")
	model.Name = "Plot" .. index

	newPart({
		Name = "Ground",
		Size = Vector3.new(PLOT_SIZE, 1, PLOT_SIZE),
		CFrame = cframe * CFrame.new(0, 0.5, 0),
		Color = Color3.fromRGB(235, 240, 245),
		Material = Enum.Material.Snow,
		Parent = model,
	})

	local base = cframe * CFrame.new(0, 1, 0)
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
		spawn = cframe * CFrame.new(0, 4, -(PLOT_SIZE / 2 - 4)) * CFrame.Angles(0, math.pi, 0), -- 트리 앞, 트리를 바라봄
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
local function applyTrait(part: BasePart, trait)
	local effect = trait.effect
	if effect == "Sparkle" then
		Instance.new("Sparkles").Parent = part
	elseif effect == "Frost" then
		part.Material = Enum.Material.Ice
		part.Color = part.Color:Lerp(Color3.new(1, 1, 1), 0.45)
	elseif effect == "Gold" then
		part.Color = Color3.fromRGB(255, 200, 40)
		part.Material = Enum.Material.Metal
		local sparkles = Instance.new("Sparkles")
		sparkles.SparkleColor = Color3.fromRGB(255, 220, 120)
		sparkles.Parent = part
	elseif effect == "Rainbow" then
		part.Material = Enum.Material.Neon
		table.insert(rainbowParts, part)
	elseif effect == "Aurora" then
		part.Material = Enum.Material.Neon
		part.Color = Color3.fromRGB(120, 255, 200)
		local light = Instance.new("PointLight")
		light.Color = Color3.fromRGB(120, 255, 200)
		light.Range = 10
		light.Parent = part
		Instance.new("Sparkles").Parent = part
	end
end

local function decorateLook(part: BasePart, deco, trait)
	local r = Rarity.List[deco.rarity]
	part.Color = r.color
	part.Material = if deco.rarity >= 4 then Enum.Material.Neon else Enum.Material.SmoothPlastic
	if deco.rarity >= 5 then
		local light = Instance.new("PointLight")
		light.Color = r.color
		light.Range = 8
		light.Parent = part
	end
	applyTrait(part, trait)
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

	local model = cloneModel(deco)
	if model then
		model:PivotTo(cf)
		model.Parent = plot.decorations
		return
	end

	-- 임시 모양
	if entry.a == "Garland" then
		local holder = Instance.new("Model")
		holder.Name = deco.id
		local radius = garlandRadius(entry.i)
		for k = 1, GARLAND_BALLS do
			local angle = (k - 1) / GARLAND_BALLS * 360
			local ball = newPart({
				Shape = Enum.PartType.Ball,
				Size = Vector3.new(0.7, 0.7, 0.7),
				CFrame = cf * CFrame.new(localPoint(angle, radius, 0)),
				CanCollide = false,
				CastShadow = false,
				Parent = holder,
			})
			decorateLook(ball, deco, trait)
		end
		holder.Parent = plot.decorations
	else
		local size = if entry.a == "Topper" then 3 else 1.8
		local part = newPart({
			Name = deco.id,
			Shape = Enum.PartType.Ball,
			Size = Vector3.new(size, size, size),
			CFrame = cf,
			CanCollide = false,
			Parent = plot.decorations,
		})
		decorateLook(part, deco, trait)
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
	table.insert(profile.tree, { a = deco.area, i = freeIndex, d = stack.d, t = stack.t })
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
	local key = PlayerData.StackKey(entry.d, entry.t)
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
		PlayerData.AddItem(profile, deco, trait, 1)
	else
		table.insert(profile.stacks, { d = entry.d, t = entry.t, c = 1, l = false })
	end
	render(player)

	return { ok = true, state = GachaService.BuildState(player) }
end

----------------------------------------------------------------
-- 시작
----------------------------------------------------------------

function TreeService.Init()
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
