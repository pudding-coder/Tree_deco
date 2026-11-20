-- 트리 자리를 포토존 자리만 비우고 원 둘레에 같은 간격으로 놓은 뒤, 매트까지 다시 만든다
local COUNT = 12 -- 자리 수 (Config.SERVER_MAX_PLAYERS와 같게)
local PAD = 50 -- 매트 지름 (판 가로·세로)
local SPACING = 4 -- 이웃 매트 사이 빈 틈
local PHOTO_GAP = 50 -- 포토존 자리로 비워 둘 폭(스터드, 판 원 둘레 기준)
local PHOTO_ANGLE = nil -- 포토존 방향(도, 0 = 가운데에서 -Z 쪽, 시계방향). nil이면 지금 판들 사이가 가장 크게 빈 곳
-- 매트 모양 (src/server/TreeService.luau의 SPOT_ 값과 같게)
local DIRT_COLOR = Color3.fromRGB(110, 78, 52)
local STONE_COLOR = Color3.fromRGB(150, 148, 145)
local RIM_WIDTH = 1.6
local RIM_HEIGHT = 0.7
local SEGMENTS = 28

local spots = workspace:FindFirstChild("PlotSpots")
assert(spots, "PlotSpots가 없습니다")
local pole = workspace:FindFirstChild("StarPole", true)
local parts, sum = {}, Vector3.zero
for _, p in spots:GetChildren() do
	if p:IsA("BasePart") then
		table.insert(parts, p)
		sum += p.Position
	end
end
assert(#parts > 0, "PlotSpots 안에 판이 하나는 있어야 합니다")
local c = if pole then (if pole:IsA("Model") then pole:GetPivot().Position else pole.Position) else sum / #parts
local center = Vector3.new(c.X, 0, c.Z)
local thickness = parts[1].Size.Y

-- 포토존 방향: 지금 판들 사이가 가장 크게 빈 곳 (또는 PHOTO_ANGLE)
local photo
if PHOTO_ANGLE then
	photo = math.rad(PHOTO_ANGLE)
else
	local angles = {}
	for _, p in parts do
		local d = Vector3.new(p.Position.X, 0, p.Position.Z) - center
		table.insert(angles, math.atan2(d.X, -d.Z))
	end
	table.sort(angles)
	local widest = -1
	for i, a in angles do
		local nextA = angles[i % #angles + 1] + (if i == #angles then math.pi * 2 else 0)
		if nextA - a > widest then
			widest = nextA - a
			photo = (a + nextA) / 2
		end
	end
end

-- 반지름: 이웃 매트가 SPACING만큼 떨어지고, 포토존 쪽에 PHOTO_GAP이 남게
-- 매트 사이 (COUNT-1)칸 + 포토존 한 칸이 원 둘레를 나눠 갖는다 (중심 사이 거리 기준)
local circumference = (COUNT - 1) * (PAD + SPACING) + PHOTO_GAP + PAD
local radius = circumference / (2 * math.pi)
local step = (PAD + SPACING) / radius -- 이웃 매트 사이 각도
local first = photo + (PHOTO_GAP + PAD) / 2 / radius -- 포토존 오른쪽 첫 자리

-- 판: 번호순으로 다시 쓰고, 모자라면 만들고, 남으면 지운다
table.sort(parts, function(a, b)
	return (tonumber(a.Name) or math.huge) < (tonumber(b.Name) or math.huge)
end)
local groundY = math.huge
for _, p in parts do
	groundY = math.min(groundY, p.Position.Y - p.Size.Y / 2)
end
for i = 1, COUNT do
	local p = parts[i]
	if not p then
		p = parts[1]:Clone()
		p.Parent = spots
	end
	p.Name = tostring(i)
	p.Size = Vector3.new(PAD, thickness, PAD)
	local a = first + (i - 1) * step
	local pos = Vector3.new(center.X + math.sin(a) * radius, groundY + thickness / 2, center.Z - math.cos(a) * radius)
	p.CFrame = CFrame.lookAt(pos, Vector3.new(center.X, pos.Y, center.Z)) -- 앞이 광장 가운데를 보게
	local edge = p:FindFirstChild("FrontEdge")
	if edge then
		edge.Size = Vector3.new(4, edge.Size.Y, 1.5)
		edge.CFrame = p.CFrame * CFrame.new(0, thickness / 2 + 0.03, -PAD / 2 + 2.5)
	end
end
for i = COUNT + 1, #parts do
	parts[i]:Destroy()
end

-- 매트 다시 만들기 (판 높이도 바닥에 맞춘다)
for _, name in { "PlotSpotPads", "PlotSpotPadsPreview" } do
	local old = workspace:FindFirstChild(name)
	if old then old:Destroy() end
end
local folder = Instance.new("Folder")
folder.Name = "PlotSpotPads"
folder.Parent = workspace
local floors = { workspace.Terrain }
for _, name in { "MapGround", "MapPaths", "MapFloor", "Baseplate" } do
	local f = workspace:FindFirstChild(name)
	if f then
		table.insert(floors, f)
	end
end
local params = RaycastParams.new()
params.FilterType = Enum.RaycastFilterType.Include
params.FilterDescendantsInstances = floors
for _, spot in spots:GetChildren() do
	if not spot:IsA("BasePart") then
		continue
	end
	local bottomY = spot.Position.Y - spot.Size.Y / 2
	local r0 = PAD / 2
	local samples = { Vector3.zero }
	for ring, scale in { 0.45, 0.9 } do
		local n = ring * 8
		for k = 1, n do
			local a = (k - 1) / n * math.pi * 2
			table.insert(samples, Vector3.new(math.sin(a), 0, math.cos(a)) * r0 * scale)
		end
	end
	local high, low = -math.huge, math.huge
	for _, offset in samples do
		local q = spot.Position + offset
		local hit = workspace:Raycast(Vector3.new(q.X, bottomY + 300, q.Z), Vector3.new(0, -800, 0), params)
		if hit then
			high = math.max(high, hit.Position.Y)
			low = math.min(low, hit.Position.Y)
		end
	end
	local depth = 0
	if high > -math.huge then
		spot.CFrame += Vector3.new(0, high - bottomY, 0)
		depth = high - low
	end
	spot.Transparency = 1
	local look = spot:FindFirstChild("RoundLook")
	if look then look:Destroy() end

	local base = spot.CFrame * CFrame.new(0, -spot.Size.Y / 2, 0)
	local model = Instance.new("Model")
	model.Name = "Spot" .. spot.Name
	local function part(props)
		local q = Instance.new("Part")
		q.Anchored = true
		q.CanCollide = true
		q.CanQuery = false
		q.CanTouch = false
		q.CastShadow = false
		q.TopSurface = Enum.SurfaceType.Smooth
		q.BottomSurface = Enum.SurfaceType.Smooth
		for k, v in props do
			q[k] = v
		end
		q.Parent = model
	end
	local thick = 2 + depth
	part({
		Name = "Dirt",
		Shape = Enum.PartType.Cylinder,
		Material = Enum.Material.Ground,
		Color = DIRT_COLOR,
		Size = Vector3.new(thick, PAD - RIM_WIDTH, PAD - RIM_WIDTH),
		CFrame = base * CFrame.new(0, 0.15 - thick / 2, 0) * CFrame.Angles(0, 0, math.pi / 2),
	})
	local r = PAD / 2 - RIM_WIDTH / 2
	local length = 2 * (r + RIM_WIDTH / 2) * math.tan(math.pi / SEGMENTS) + 0.1
	local rimHeight = thick + RIM_HEIGHT
	for i = 1, SEGMENTS do
		local a = (i - 1) / SEGMENTS * math.pi * 2
		local pos = base * CFrame.new(math.sin(a) * r, 0.15 + RIM_HEIGHT - rimHeight / 2, -math.cos(a) * r)
		part({
			Name = "Rim" .. i,
			Material = Enum.Material.Slate,
			Color = STONE_COLOR,
			Size = Vector3.new(length, rimHeight, RIM_WIDTH),
			CFrame = CFrame.lookAt(pos.Position, base.Position + Vector3.new(0, pos.Y - base.Y, 0)),
		})
	end
	model.Parent = folder
end
print(string.format("트리 자리 %d개를 놓고 매트를 만들었습니다: 반지름 %.0f, 포토존 방향 %.0f도. 투명벽·길 스크립트도 다시 실행해 주세요",
	COUNT, radius, math.deg(photo) % 360))
