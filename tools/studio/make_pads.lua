-- 트리 자리 매트 만들기 (고정): 판마다 바닥 높이를 재서 판을 맞추고, 둥근 흙바닥 + 돌 테두리 매트를 플레이스에 만든다
-- 다시 실행하면 예전 매트를 지우고 새로 만든다. 판을 옮기거나 바닥을 바꿨으면 다시 실행한다
-- 아래 값은 src/server/TreeService.luau의 SPOT_ 값과 같게
local DIRT_COLOR = Color3.fromRGB(110, 78, 52)
local STONE_COLOR = Color3.fromRGB(150, 148, 145)
local RIM_WIDTH = 1.6
local RIM_HEIGHT = 0.7
local SEGMENTS = 28

local spots = workspace:FindFirstChild("PlotSpots")
assert(spots, "PlotSpots가 없습니다")
for _, name in { "PlotSpotPads", "PlotSpotPadsPreview" } do
	local old = workspace:FindFirstChild(name)
	if old then old:Destroy() end
end
local folder = Instance.new("Folder")
folder.Name = "PlotSpotPads"
folder.Parent = workspace

-- 바닥으로 보는 것: 지형 + 이 이름의 폴더·모델 안 파트
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

local made, missed = 0, 0
for _, spot in spots:GetChildren() do
	if not spot:IsA("BasePart") then
		continue
	end
	-- 판 안 25곳(가운데 + 원 두 겹)의 바닥 높이: 가장 높은 곳에 흙바닥을 맞추고, 가장 낮은 곳까지 흙을 채운다
	local bottomY = spot.Position.Y - spot.Size.Y / 2
	local radius = math.min(spot.Size.X, spot.Size.Z) / 2
	local samples = { Vector3.zero }
	for ring, scale in { 0.45, 0.9 } do
		local count = ring * 8
		for k = 1, count do
			local a = (k - 1) / count * math.pi * 2
			table.insert(samples, Vector3.new(math.sin(a), 0, math.cos(a)) * radius * scale)
		end
	end
	local high, low = -math.huge, math.huge
	for _, offset in samples do
		local p = spot.Position + offset
		local hit = workspace:Raycast(Vector3.new(p.X, bottomY + 300, p.Z), Vector3.new(0, -800, 0), params)
		if hit then
			high = math.max(high, hit.Position.Y)
			low = math.min(low, hit.Position.Y)
		end
	end
	local depth = 0
	if high > -math.huge then
		spot.CFrame += Vector3.new(0, high - bottomY, 0)
		depth = high - low
	else
		missed += 1
		warn("밑에 바닥이 없어 판 높이 그대로 둡니다:", spot.Name)
	end

	-- 판은 안 보이게 (위치 표시 역할은 그대로). 예전 둥근 그림은 지운다
	spot.Transparency = 1
	local look = spot:FindFirstChild("RoundLook")
	if look then look:Destroy() end

	local base = spot.CFrame * CFrame.new(0, -spot.Size.Y / 2, 0) -- 트리가 서는 곳
	local diameter = math.min(spot.Size.X, spot.Size.Z)
	local model = Instance.new("Model")
	model.Name = "Spot" .. spot.Name
	local function part(props)
		local p = Instance.new("Part")
		p.Anchored = true
		p.CanCollide = true
		p.CanQuery = false
		p.CanTouch = false
		p.CastShadow = false
		p.TopSurface = Enum.SurfaceType.Smooth
		p.BottomSurface = Enum.SurfaceType.Smooth
		for k, v in props do
			p[k] = v
		end
		p.Parent = model
	end
	local thick = 2 + depth
	part({
		Name = "Dirt",
		Shape = Enum.PartType.Cylinder,
		Material = Enum.Material.Ground,
		Color = DIRT_COLOR,
		Size = Vector3.new(thick, diameter - RIM_WIDTH, diameter - RIM_WIDTH),
		CFrame = base * CFrame.new(0, 0.15 - thick / 2, 0) * CFrame.Angles(0, 0, math.pi / 2),
	})
	local r = diameter / 2 - RIM_WIDTH / 2
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
	made += 1
end
print(string.format("트리 자리 매트 %d개를 만들었습니다 (바닥 못 찾음 %d개). 저장하면 게임도 이대로 나옵니다", made, missed))
