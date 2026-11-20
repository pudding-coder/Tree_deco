-- 길 깔기: 울퉁불퉁한 바닥(메시 눈 바닥·지형) 위에 작은 돌 타일을 바닥 모양대로 깐다
local TILE = 3 -- 타일 한 칸 크기(스터드). 작을수록 바닥을 잘 따라가지만 파트가 많아진다
local RING_WIDTH = 14 -- 트리 구경 둘레길 폭
local RING_GAP = 8 -- 트리 매트 안쪽 끝과 둘레길 사이 여유
local PLAZA_RADIUS = 30 -- 가운데 광장(별 기둥 둘레) 반지름
local SPOKE_WIDTH = 12 -- 세 갈래 길 폭
local PHOTO_REACH = 30 -- 포토존 갈래가 트리 자리 원보다 더 나가는 길이
local PATH_COLOR = Color3.fromRGB(150, 108, 80) -- 길 (갈색 돌)
local PLAZA_COLOR = Color3.fromRGB(170, 92, 82) -- 광장 (붉은 돌)
local LIFT = 0.12 -- 바닥 위로 띄우는 높이 (눈에 묻히면 키운다)

local spots = workspace:FindFirstChild("PlotSpots")
assert(spots, "PlotSpots가 없습니다")
local pole = workspace:FindFirstChild("StarPole", true)
local list, sum = {}, Vector3.zero
for _, p in spots:GetChildren() do
	if p:IsA("BasePart") then
		table.insert(list, p)
		sum += p.Position
	end
end
assert(#list > 0, "PlotSpots 안에 판이 없습니다")
local c = if pole then (if pole:IsA("Model") then pole:GetPivot().Position else pole.Position) else sum / #list
local center = Vector3.new(c.X, 0, c.Z)

-- 트리 자리 원 반지름, 매트 크기, 포토존 방향(판 사이가 가장 크게 빈 곳)
local angles, total, pad = {}, 0, 0
for _, p in list do
	local d = Vector3.new(p.Position.X, 0, p.Position.Z) - center
	total += d.Magnitude
	pad = math.max(pad, math.min(p.Size.X, p.Size.Z))
	table.insert(angles, math.atan2(d.X, -d.Z))
end
local treeRadius = total / #list
table.sort(angles)
local photo, widest = 0, -1
for i, a in angles do
	local nextA = angles[i % #angles + 1] + (if i == #angles then math.pi * 2 else 0)
	if nextA - a > widest then
		widest = nextA - a
		photo = (a + nextA) / 2
	end
end
local ringRadius = treeRadius - pad / 2 - RING_GAP - RING_WIDTH / 2

-- 길이 될 칸 모으기 (TILE 격자)
local cells = {} -- ["x,z"] = "path" | "plaza"
local function mark(x, z, kind)
	local key = math.floor(x / TILE) .. "," .. math.floor(z / TILE)
	if cells[key] ~= "plaza" then
		cells[key] = kind
	end
end
local function stamp(pos, radius, kind)
	for dx = -radius, radius, TILE / 2 do
		for dz = -radius, radius, TILE / 2 do
			if dx * dx + dz * dz <= radius * radius then
				mark(pos.X + dx, pos.Z + dz, kind)
			end
		end
	end
end
local function dirOf(a)
	return Vector3.new(math.sin(a), 0, -math.cos(a))
end
local steps = math.ceil(2 * math.pi * ringRadius / (TILE / 2))
for i = 0, steps - 1 do
	stamp(center + dirOf(i / steps * math.pi * 2) * ringRadius, RING_WIDTH / 2, "path")
end
for k = 0, 2 do
	local dir = dirOf(photo + k * math.pi * 2 / 3)
	local to = if k == 0 then treeRadius + PHOTO_REACH else ringRadius
	for r = PLAZA_RADIUS - 2, to, TILE / 2 do
		stamp(center + dir * r, SPOKE_WIDTH / 2, "path")
	end
end
stamp(center, PLAZA_RADIUS, "plaza")

-- 바닥: 지형 + 이 이름의 폴더·모델 안 파트
local floors = { workspace.Terrain }
for _, name in { "Baseplate", "MapFloor", "MapGround" } do
	local f = workspace:FindFirstChild(name)
	if f then
		table.insert(floors, f)
	end
end
local params = RaycastParams.new()
params.FilterType = Enum.RaycastFilterType.Include
params.FilterDescendantsInstances = floors

local old = workspace:FindFirstChild("MapPaths")
if old then old:Destroy() end
local folder = Instance.new("Folder")
folder.Name = "MapPaths"
folder.Parent = workspace

-- 칸마다 바닥 높이와 기울기를 재서 그 모양대로 타일을 놓는다
local made, missed = 0, 0
for key, kind in cells do
	local gx, gz = string.match(key, "(-?%d+),(-?%d+)")
	local x, z = (tonumber(gx) + 0.5) * TILE, (tonumber(gz) + 0.5) * TILE
	local hit = workspace:Raycast(Vector3.new(x, c.Y + 300, z), Vector3.new(0, -1000, 0), params)
	if not hit then
		missed += 1
		continue
	end
	-- 바닥 기울기(법선)에 맞춰 타일을 눕힌다
	local up = hit.Normal
	local r = up:Cross(Vector3.zAxis)
	local right = if r.Magnitude > 0.01 then r.Unit else Vector3.xAxis
	local back = right:Cross(up).Unit
	local p = Instance.new("Part")
	p.Name = if kind == "plaza" then "Plaza" else "Path"
	p.Anchored = true
	p.CanCollide = true
	p.CastShadow = false
	p.Locked = true -- 꾸밀 때 집히지 않게
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Material = if kind == "plaza" then Enum.Material.Brick else Enum.Material.Cobblestone
	p.Color = if kind == "plaza" then PLAZA_COLOR else PATH_COLOR
	p.Size = Vector3.new(TILE + 0.3, 0.6, TILE + 0.3) -- 이웃 타일과 살짝 겹쳐 틈을 막는다
	p.CFrame = CFrame.fromMatrix(hit.Position + up * (LIFT - 0.3), right, up, back) -- 윗면이 바닥 + LIFT
	p.Parent = folder
	made += 1
end
print(string.format("길을 깔았습니다: 타일 %d개 (바닥 못 찾음 %d), 둘레길 반지름 %.0f, 포토존 방향 %.0f도 (MapPaths)",
	made, missed, ringRadius, math.deg(photo) % 360))
