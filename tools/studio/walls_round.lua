local MARGIN = 45 -- 가장 바깥 트리 자리에서 벽까지 거리(스터드). 트리 폭 13 + 사람이 서는 앞 14 + 여유
local RADIUS = nil -- 반지름을 직접 정하려면 숫자로 (예: 220). nil이면 트리 자리 + MARGIN
local CENTER = nil -- 원 가운데를 직접 정하려면 Vector3.new(x, 0, z). nil이면 트리 자리들의 가운데
local SEGMENTS = 64 -- 벽 조각 수 (많을수록 매끈한 원)
local HEIGHT = 80 -- 벽 높이 (뛰어넘기 방지)
local THICK = 4 -- 벽 두께

local points, groundY = {}, 0
local spots = workspace:FindFirstChild("PlotSpots")
if spots then
	for _, p in spots:GetChildren() do
		if p:IsA("BasePart") then
			table.insert(points, p.Position)
		end
	end
end
local center = CENTER
if #points > 0 then
	local sum = Vector3.zero
	groundY = math.huge
	for _, pos in points do
		sum += pos
	end
	for _, p in spots:GetChildren() do
		if p:IsA("BasePart") then
			groundY = math.min(groundY, p.Position.Y - p.Size.Y / 2)
		end
	end
	center = center or sum / #points
end
center = center or Vector3.zero
local radius = RADIUS
if not radius then
	local far = 170 -- 트리 자리 표시가 없으면 코드가 자동 배치하는 바깥 반지름
	if #points > 0 then
		far = 0
		for _, pos in points do
			far = math.max(far, (Vector3.new(pos.X, 0, pos.Z) - Vector3.new(center.X, 0, center.Z)).Magnitude)
		end
	end
	radius = far + MARGIN
end

local old = workspace:FindFirstChild("MapWalls")
if old then old:Destroy() end
local folder = Instance.new("Folder")
folder.Name = "MapWalls"
folder.Parent = workspace

local y = groundY - 5 + HEIGHT / 2 -- 땅속 5스터드부터 세워 바닥 틈을 막는다
local r = radius + THICK / 2 -- 벽 안쪽 면이 radius에 오게
local length = 2 * r * math.tan(math.pi / SEGMENTS) + 0.5 -- 이웃 조각과 살짝 겹치게
for i = 1, SEGMENTS do
	local angle = (i - 1) / SEGMENTS * math.pi * 2
	local pos = Vector3.new(center.X + math.cos(angle) * r, y, center.Z + math.sin(angle) * r)
	local p = Instance.new("Part")
	p.Name = "Wall" .. i
	p.Anchored = true
	p.CanCollide = true
	p.CanQuery = false
	p.CastShadow = false
	p.Material = Enum.Material.SmoothPlastic
	p.Color = Color3.fromRGB(255, 80, 80)
	p.Transparency = 0.7 -- 편집 중에만 보인다. 게임이 시작되면 1이 된다
	p.Size = Vector3.new(length, HEIGHT, THICK)
	p.CFrame = CFrame.lookAt(pos, Vector3.new(center.X, y, center.Z)) -- 넓은 면이 가운데를 본다
	p.Parent = folder
end
print(string.format("원형 투명벽을 세웠습니다: 반지름 %d, 조각 %d개, 높이 %d (MapWalls)", radius, SEGMENTS, HEIGHT))
