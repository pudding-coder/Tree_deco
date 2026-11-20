-- 가운데 별 기둥(StarPole)에서 가로등(이름이 LAMP_NAME인 모델)마다 전구 줄을 늘어뜨려 잇는다
-- 결과는 Workspace.MapDecor.StarLights 폴더. 다시 실행하면 예전 줄을 지우고 새로 만든다
-- 가로등을 옮기거나 더 놓은 뒤에 다시 실행하면 된다. Play를 멈춘 상태에서 실행
local LAMP_NAME = "Street lamp" -- 이을 가로등 모델 이름 (map deco 폴더 안에 있는 것)
local RING = false -- true면 이웃 가로등끼리도 둥글게 잇는다
local SAG = 0.08 -- 줄이 처지는 정도 (줄 길이 대비. 0이면 팽팽)
local SPACING = 2.5 -- 전구 사이 간격(스터드)
local BULB_SIZE = 0.45
local WIRE_WIDTH = 0.12
local STAR_DROP = 0.6 -- 별 가운데에서 이만큼(별 높이 비율) 아래에서 줄이 시작 (별이 전구에 가리지 않게)
local LAMP_DROP = 0.5 -- 가로등 꼭대기에서 이만큼(스터드) 아래에 줄을 건다 (불빛 부분을 못 찾았을 때)
local LIGHT_EVERY = 5 -- 전구 몇 개마다 실제 불빛(PointLight)을 달지. 0이면 안 단다 (많으면 느려짐)
local COLORS = { -- 전구 색 (차례로 돌아가며)
	Color3.fromRGB(255, 227, 151), -- 따뜻한 노랑
	Color3.fromRGB(255, 227, 151),
	Color3.fromRGB(233, 63, 57), -- 빨강
	Color3.fromRGB(255, 227, 151),
	Color3.fromRGB(121, 231, 191), -- 초록
	Color3.fromRGB(255, 227, 151),
	Color3.fromRGB(90, 161, 240), -- 파랑
}
local WIRE_COLOR = Color3.fromRGB(39, 43, 55)

local pole = workspace:FindFirstChild("StarPole", true)
if not pole then
	error("StarPole을 찾지 못했습니다. 별 기둥 모델 이름을 StarPole로 맞춰 주세요.")
end

-- 별 기둥 쪽 시작점: 별 파트(GlowGold) 아래쪽. 없으면 모델 꼭대기
local function starPoint()
	local star
	for _, d in pole:GetDescendants() do
		if d:IsA("BasePart") and string.find(d.Name, "GlowGold") then
			star = d
			break
		end
	end
	if star then
		return star.Position - Vector3.new(0, star.Size.Y * STAR_DROP, 0)
	end
	local box, size = pole:GetBoundingBox()
	return box.Position + Vector3.new(0, size.Y / 2 - 1, 0)
end

-- 가로등 쪽 끝점: 불빛이 든 파트(빛·Neon) 중 가장 높은 것. 없으면 모델 꼭대기 조금 아래
local function lampPoint(lamp)
	local best
	for _, d in lamp:GetDescendants() do
		local part
		if d:IsA("Light") and d.Parent:IsA("BasePart") then
			part = d.Parent
		elseif d:IsA("BasePart") and d.Material == Enum.Material.Neon then
			part = d
		end
		if part and (not best or part.Position.Y > best.Position.Y) then
			best = part
		end
	end
	if best then
		return best.Position
	end
	local box, size
	if lamp:IsA("Model") then
		box, size = lamp:GetBoundingBox()
	else
		box, size = lamp.CFrame, lamp.Size
	end
	return box.Position + Vector3.new(0, size.Y / 2 - LAMP_DROP, 0)
end

local lamps = {}
for _, d in workspace:GetDescendants() do
	if d.Name == LAMP_NAME and (d:IsA("Model") or d:IsA("BasePart")) and not d:IsDescendantOf(pole) then
		table.insert(lamps, d)
	end
end
if #lamps == 0 then
	error("이름이 '" .. LAMP_NAME .. "'인 가로등을 찾지 못했습니다.")
end

local decor = workspace:FindFirstChild("MapDecor")
if not decor then
	decor = Instance.new("Folder")
	decor.Name = "MapDecor"
	decor.Parent = workspace
end
local old = decor:FindFirstChild("StarLights")
if old then
	old:Destroy()
end
local folder = Instance.new("Folder")
folder.Name = "StarLights"

local function newPart(name, parent)
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.CanCollide = false
	p.CanTouch = false
	p.CastShadow = false
	p.Locked = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

local bulbTotal = 0
local function hang(name, a, b)
	local model = Instance.new("Model")
	model.Name = name
	model.Parent = folder
	local length = (b - a).Magnitude
	local sag = length * SAG
	local function at(t)
		return a:Lerp(b, t) - Vector3.new(0, sag * 4 * t * (1 - t), 0)
	end
	-- 줄
	local segments = math.max(4, math.ceil(length / 2))
	for i = 1, segments do
		local p0, p1 = at((i - 1) / segments), at(i / segments)
		local wire = newPart("Wire", model)
		wire.Material = Enum.Material.SmoothPlastic
		wire.Color = WIRE_COLOR
		wire.Size = Vector3.new(WIRE_WIDTH, WIRE_WIDTH, (p1 - p0).Magnitude + 0.05)
		wire.CFrame = CFrame.lookAt((p0 + p1) / 2, p1)
	end
	-- 전구
	local count = math.max(1, math.floor(length / SPACING))
	for i = 1, count do
		local pos = at((i - 0.5) / count) - Vector3.new(0, BULB_SIZE * 0.4, 0)
		bulbTotal += 1
		local bulb = newPart("Bulb", model)
		bulb.Shape = Enum.PartType.Ball
		bulb.Material = Enum.Material.Neon
		bulb.Color = COLORS[(bulbTotal - 1) % #COLORS + 1]
		bulb.Size = Vector3.new(BULB_SIZE, BULB_SIZE, BULB_SIZE)
		bulb.Position = pos
		if LIGHT_EVERY > 0 and bulbTotal % LIGHT_EVERY == 0 then
			local light = Instance.new("PointLight")
			light.Color = bulb.Color
			light.Range = 8
			light.Brightness = 0.8
			light.Parent = bulb
		end
	end
end

local center = starPoint()
-- 별 기둥 둘레 각도 순서로 정렬 (RING일 때 이웃끼리 잇기 위해)
local points = {}
for _, lamp in lamps do
	local p = lampPoint(lamp)
	table.insert(points, { pos = p, angle = math.atan2(p.Z - center.Z, p.X - center.X) })
end
table.sort(points, function(x, y)
	return x.angle < y.angle
end)

for i, pt in points do
	hang("Star_" .. i, center, pt.pos)
end
if RING and #points >= 3 then
	for i, pt in points do
		local nextPt = points[i % #points + 1]
		hang("Ring_" .. i, pt.pos, nextPt.pos)
	end
end

folder.Parent = decor
print("이은 가로등:", #points, "/ 전구:", bulbTotal)
