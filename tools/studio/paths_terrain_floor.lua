local RING_WIDTH = 14 -- 트리 구경 둘레길 폭
local RING_GAP = 8 -- 트리 자리 판 안쪽 끝과 둘레길 사이 여유
local PLAZA_RADIUS = 30 -- 가운데 광장(별 기둥 둘레) 반지름
local SPOKE_WIDTH = 12 -- 세 갈래 길 폭
local PHOTO_REACH = 20 -- 포토존 갈래가 트리 자리 원보다 더 나가는 길이
local PATH_MATERIAL = Enum.Material.Cobblestone -- 길 재질
local PLAZA_MATERIAL = Enum.Material.Brick -- 광장 재질
local PATH_COLOR = Color3.fromRGB(150, 108, 80) -- 길 색 (지형 재질 색이라 이 재질을 쓰는 지형 전체에 적용)
local PLAZA_COLOR = Color3.fromRGB(170, 92, 82)
local FROM = { Enum.Material.Snow, Enum.Material.Glacier, Enum.Material.Grass, Enum.Material.Ground } -- 바꿀 원래 바닥 재질
local REVERT = false -- true로 다시 실행하면 길을 눈으로 되돌린다

local terrain = workspace.Terrain
local pole = workspace:FindFirstChild("StarPole", true)
local spots = workspace:FindFirstChild("PlotSpots")
assert(spots, "PlotSpots가 없습니다")

-- 가운데: 별 기둥 (없으면 트리 자리들의 가운데)
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

-- 트리 자리 원 반지름과 판 크기, 판들의 각도
local angles, total, pad = {}, 0, 0
for _, p in list do
	local d = Vector3.new(p.Position.X, 0, p.Position.Z) - center
	total += d.Magnitude
	pad = math.max(pad, p.Size.X, p.Size.Z)
	table.insert(angles, math.atan2(d.X, -d.Z))
end
local treeRadius = total / #list
table.sort(angles)

-- 포토존 방향: 판 사이가 가장 크게 빈 곳의 가운데
local photoAngle, widest = 0, -1
for i, a in angles do
	local nextA = angles[i % #angles + 1] + (if i == #angles then math.pi * 2 else 0)
	if nextA - a > widest then
		widest = nextA - a
		photoAngle = (a + nextA) / 2
	end
end
local ringRadius = treeRadius - pad / 2 - RING_GAP - RING_WIDTH / 2

-- 길이 될 칸(지형 4스터드 격자의 기둥)을 모은다
local cells = {} -- ["x,z"] = 재질
local function mark(x, z, material)
	local gx, gz = math.floor(x / 4) * 4, math.floor(z / 4) * 4
	local key = gx .. "," .. gz
	if cells[key] ~= PLAZA_MATERIAL then
		cells[key] = material
	end
end
local function stamp(pos, radius, material)
	for dx = -radius, radius, 2 do
		for dz = -radius, radius, 2 do
			if dx * dx + dz * dz <= radius * radius then
				mark(pos.X + dx, pos.Z + dz, material)
			end
		end
	end
end
local function dirOf(a)
	return Vector3.new(math.sin(a), 0, -math.cos(a))
end

-- 1. 둘레길
local steps = math.ceil(2 * math.pi * ringRadius / 2)
for i = 0, steps - 1 do
	stamp(center + dirOf(i / steps * math.pi * 2) * ringRadius, RING_WIDTH / 2, PATH_MATERIAL)
end
-- 2. 세 갈래 길: 포토존 쪽 하나 + 120도씩 둘
for k = 0, 2 do
	local dir = dirOf(photoAngle + k * math.pi * 2 / 3)
	local to = if k == 0 then treeRadius + PHOTO_REACH else ringRadius
	for r = PLAZA_RADIUS - 2, to, 2 do
		stamp(center + dir * r, SPOKE_WIDTH / 2, PATH_MATERIAL)
	end
end
-- 3. 광장
stamp(center, PLAZA_RADIUS, PLAZA_MATERIAL)

-- 칸마다 지형 표면을 찾아 겉 재질만 바꾼다 (모양은 그대로라 울퉁불퉁한 눈 위에 그대로 길이 생긴다)
local params = RaycastParams.new()
params.FilterType = Enum.RaycastFilterType.Include
params.FilterDescendantsInstances = { terrain }
local changed = 0
for key, material in cells do
	local gx, gz = string.match(key, "(-?%d+),(-?%d+)")
	gx, gz = tonumber(gx), tonumber(gz)
	local hit = workspace:Raycast(Vector3.new(gx + 2, c.Y + 300, gz + 2), Vector3.new(0, -1000, 0), params)
	if hit then
		local y = hit.Position.Y
		local region = Region3.new(Vector3.new(gx, y - 8, gz), Vector3.new(gx + 4, y + 4, gz + 4)):ExpandToGrid(4)
		if REVERT then
			terrain:ReplaceMaterial(region, 4, material, Enum.Material.Snow)
		else
			for _, from in FROM do
				terrain:ReplaceMaterial(region, 4, from, material)
			end
		end
		changed += 1
	end
end
if not REVERT then
	terrain:SetMaterialColor(PATH_MATERIAL, PATH_COLOR)
	terrain:SetMaterialColor(PLAZA_MATERIAL, PLAZA_COLOR)
end
print(string.format("%s: 칸 %d개, 둘레길 반지름 %.0f, 포토존 방향 %.0f도, 광장 반지름 %d",
	if REVERT then "길을 눈으로 되돌렸습니다" else "길을 깔았습니다", changed, ringRadius, math.deg(photoAngle) % 360, PLAZA_RADIUS))
