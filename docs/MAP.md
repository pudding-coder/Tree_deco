# 맵 꾸미기 (크리스마스 마켓)

맵은 Studio에서 직접 만든다. 코드(Rojo)는 `Workspace`를 건드리지 않으므로, 맵은 **플레이스 파일에 저장**된다(`Cmd + S` / Publish).

---

## 1. 트리 자리 정하기 (PlotSpots)

트리가 설 자리를 맵에 직접 표시한다. 표시가 없으면 코드가 광장 둘레에 원 모양으로 자동 배치한다.

### 만드는 법

1. Explorer에서 `Workspace`에 **Folder**를 만들고 이름을 정확히 `PlotSpots`로 바꾼다.
2. 그 안에 **Part**를 넣는다. 파트 하나 = 트리 하나.
   - 이름: `1`, `2`, `3` ... (숫자 순서대로 먼저 채워진다. **사람이 많이 지나가는 좋은 자리를 작은 번호로**)
   - 크기: **30 × 0.4 × 30** (트리 + 바닥 아이템이 들어가는 내 자리 넓이). 파트 **바닥 가운데**에 트리가 선다 → 파트를 땅 위에 올려 둔다. 이미 만든 자리는 아래 "자리 크기 한 번에 맞추기"로 바꾼다.
   - `Anchored` 켜기
3. 파트의 **앞면(Front)** 이 트리 정면이다. 사람은 앞면 쪽 14스터드에 나타나 트리를 바라본다. 파트에는 앞면을 보여주는 속성이 없으므로 글자를 붙여 표시한다 (**1번에만 하고 복제**):
   1. 파트 `1`의 `+` → **SurfaceGui** (`Face`가 기본으로 Front)
   2. SurfaceGui의 `+` → **TextLabel** → `Size` `{1,0},{1,0}`, `Text` `앞`, `TextScaled` 체크
   3. "앞" 글자가 통로를 향하게 회전 (`Cmd + 4`)
   4. 파트를 `Cmd + D`로 복제하면 글자도 같이 복사된다. 파트 크기를 6 × 4 × 6 정도로 키우면 잘 보인다.
   - 게임이 시작되면 표시 파트와 글자는 자동으로 사라진다.
4. **서버 인원(`SERVER_MAX_PLAYERS`, 지금 20)만큼** 만든다. 모자라면 Output에 경고가 나오고 늦게 온 사람은 트리를 못 받는다.

게임이 시작되면 표시 파트는 자동으로 투명해지고(안의 글자도 지워짐) 부딪히지 않는다. 트리 자리 매트는 아래 **"트리 자리 매트 만들기: 고정"**으로 플레이스에 만들어 두면 그대로 쓰인다. 만들어 두지 않으면 게임이 시작될 때 판을 **그 자리의 바닥 표면에 맞추고** 매트를 만든다(판 안 25곳을 재서 가장 높은 곳에 흙바닥을 맞추고, 가장 낮은 곳까지 흙을 두껍게 채운다)(바닥으로 보는 것: 지형, 그리고 Workspace의 `MapGround`·`MapPaths`·`MapFloor`·`Baseplate` 안의 파트. 무료 바닥 에셋을 쓰면 이 이름 중 하나의 폴더·모델에 넣는다)(눈에 묻혀 있어도 트리는 눈 위에 선다). 대신 판 크기에 맞춘 **둥근 흙바닥 + 돌 테두리**가 깔린다(`TreeService.luau`의 `SPOT_DIRT_COLOR`·`SPOT_STONE_COLOR`·`SPOT_RIM_WIDTH`·`SPOT_RIM_HEIGHT`). 편집할 때는 판 전체가 보이니 그대로 두면 된다.

### 원 따라 둥글게 놓기 (Command Bar)

트리 자리 판을 **원 둘레에 같은 간격으로** 세운다. 판 앞(노란 띠)은 모두 **원 가운데(광장)**를 본다. 그래서 사람은 광장 쪽에 나타나 자기 트리를 바라본다. **Play를 멈춘 상태**에서 실행하고, 끝나면 투명벽 스크립트를 다시 실행해 벽을 맞춘다.

- `COUNT`: 자리 수(서버 인원 `SERVER_MAX_PLAYERS`와 같게). 이미 있는 `PlotSpots` 파트는 번호 순서대로 다시 쓰고, 모자라면 만들고, 남으면 지운다.
- `GAP`: 이웃 판 사이 빈 통로 폭. 반지름은 판이 겹치지 않게 자동으로 정한다(직접 정하려면 `RADIUS`).
- `CENTER`: 광장 가운데. `nil`이면 지금 자리들의 가운데(없으면 원점).
- `START_ANGLE`: 1번 자리 방향(도). 0이면 가운데에서 -Z 쪽. 입구·스폰 앞에 1번이 오게 돌린다.

```lua
local COUNT = 20 -- 자리 수 (SERVER_MAX_PLAYERS)
local PAD = 30 -- 판 가로·세로
local PAD_H = 0.4 -- 판 두께
local GAP = 8 -- 이웃 판 사이 통로 폭
local RADIUS = nil -- 원 반지름을 직접 정하려면 숫자로. nil이면 판이 안 겹치게 자동
local CENTER = nil -- 광장 가운데 Vector3.new(x, 0, z). nil이면 지금 자리들의 가운데
local START_ANGLE = 0 -- 1번 자리 방향(도)

local folder = workspace:FindFirstChild("PlotSpots")
if not folder then
	folder = Instance.new("Folder")
	folder.Name = "PlotSpots"
	folder.Parent = workspace
end
local parts = {}
for _, p in folder:GetChildren() do
	if p:IsA("BasePart") then
		table.insert(parts, p)
	end
end
table.sort(parts, function(a, b)
	return (tonumber(a.Name) or math.huge) < (tonumber(b.Name) or math.huge)
end)

-- 가운데와 바닥 높이: 지금 자리들 기준
local center, groundY = CENTER, 0
if #parts > 0 then
	local sum, low = Vector3.zero, math.huge
	for _, p in parts do
		sum += p.Position
		low = math.min(low, p.Position.Y - p.Size.Y / 2)
	end
	center = center or sum / #parts
	groundY = low
end
center = center or Vector3.zero

-- 반지름: 이웃 판 중심 사이가 (판 대각선 + 통로)가 되게
local step = math.pi * 2 / COUNT
local need = PAD * math.sqrt(2) + GAP
local radius = RADIUS or need / (2 * math.sin(step / 2))

for i = 1, COUNT do
	local p = parts[i]
	if not p then
		p = Instance.new("Part")
		p.Parent = folder
	end
	p.Name = tostring(i)
	p.Anchored = true
	p.CanCollide = false
	p.Color = Color3.fromRGB(120, 200, 255)
	p.Transparency = 0.3
	p.Size = Vector3.new(PAD, PAD_H, PAD)
	local angle = math.rad(START_ANGLE) + (i - 1) * step
	local pos = Vector3.new(center.X + math.sin(angle) * radius, groundY + PAD_H / 2, center.Z - math.cos(angle) * radius)
	-- 앞(-Z)이 원 가운데를 보게
	p.CFrame = CFrame.lookAt(pos, Vector3.new(center.X, pos.Y, center.Z))
	local old = p:FindFirstChild("FrontEdge")
	if old then old:Destroy() end
	local edge = Instance.new("Part")
	edge.Name = "FrontEdge"
	edge.Anchored = true
	edge.CanCollide = false
	edge.Color = Color3.fromRGB(255, 210, 60)
	edge.Size = Vector3.new(PAD, PAD_H + 0.1, 1.5)
	edge.CFrame = p.CFrame * CFrame.new(0, 0.05, -PAD / 2 + 0.75)
	edge.Parent = p
end
for i = COUNT + 1, #parts do
	parts[i]:Destroy() -- 남는 자리 표시는 지운다
end
print(string.format("트리 자리 %d개를 반지름 %.0f 원 위에 놓았습니다 (가운데 %.0f, %.0f)", COUNT, radius, center.X, center.Z))
```

### 자리 크기 한 번에 맞추기 (Command Bar)

`PlotSpots` 안의 파트를 모두 **넓고 납작한 판(30 × 0.4 × 30)**으로 바꾼다. 트리가 서는 바닥 가운데 위치와 앞 방향은 그대로 두고 크기만 바꾼다. 판 앞쪽 가장자리에 **노란 띠**를 붙여 정면을 보여 준다(게임이 시작되면 판과 띠는 사라진다). **Play를 멈춘 상태**에서 실행한다.

판 하나에 들어가는 것: 트리(폭 13), 넓게 까는 바닥 아이템(잔디·마법진, 지름 약 20), 트리 둘레 바닥 자리 아이템(지름 약 23). 사람은 판 앞 가장자리 근처(트리 앞 14)에 나타난다.

```lua
local PAD = 30 -- 판 가로·세로(스터드)
local PAD_H = 0.4 -- 판 두께
local folder = workspace:FindFirstChild("PlotSpots")
local spots = {}
for _, p in (folder and folder:GetChildren() or {}) do
	if p:IsA("BasePart") then
		local bottom = p.CFrame * CFrame.new(0, -p.Size.Y / 2, 0) -- 트리가 서는 곳 (그대로 둔다)
		p.Size = Vector3.new(PAD, PAD_H, PAD)
		p.CFrame = bottom * CFrame.new(0, PAD_H / 2, 0)
		p.Anchored = true
		p.CanCollide = false
		local old = p:FindFirstChild("FrontEdge")
		if old then old:Destroy() end
		local edge = Instance.new("Part")
		edge.Name = "FrontEdge" -- 앞쪽 표시 (편집용)
		edge.Anchored = true
		edge.CanCollide = false
		edge.Color = Color3.fromRGB(255, 210, 60)
		edge.Size = Vector3.new(PAD, PAD_H + 0.1, 1.5)
		edge.CFrame = p.CFrame * CFrame.new(0, 0.05, -PAD / 2 + 0.75)
		edge.Parent = p
		table.insert(spots, p)
	end
end
-- 판끼리 겹치는 자리를 알려 준다
for i = 1, #spots do
	for j = i + 1, #spots do
		local a, b = spots[i].Position, spots[j].Position
		local dist = (Vector3.new(a.X, 0, a.Z) - Vector3.new(b.X, 0, b.Z)).Magnitude
		if dist < PAD then
			warn(string.format("자리 %s와 %s가 겹칩니다 (중심 간격 %.0f, %d 이상 필요)", spots[i].Name, spots[j].Name, dist, PAD))
		end
	end
end
print(string.format("트리 자리 %d개를 %d × %.1f × %d 판으로 바꿨습니다", #spots, PAD, PAD_H, PAD))
```

- 겹친다는 경고가 나오면 그 자리를 옮겨 **중심 간격 30 이상**(사이로 지나가려면 36 이상) 띄운다.
- 판을 돌려 앞(노란 띠)을 통로 쪽으로 맞춘다. 돌릴 때는 판을 선택하고 `Cmd + R`(90도)이나 Rotate 도구.

### 트리 자리 매트 만들기: 고정 (Command Bar)

판 위치를 정했으면 이걸 실행해 **둥근 흙바닥 + 돌 테두리 매트를 플레이스에 만든다**. 판마다 안쪽 25곳의 바닥 높이를 재서, 가장 높은 곳에 흙바닥을 맞추고 가장 낮은 곳까지 흙을 채운다(볼록한 눈이 흙을 뚫고 나오지 않는다). **편집 화면에 보이는 그대로 게임에 나온다.**

- 게임은 `Workspace.PlotSpotPads`가 있으면 판 높이와 매트를 **건드리지 않고 그대로** 쓴다. 없으면 게임이 시작될 때 스스로 높이를 재서 매트를 만든다(예전 방식).
- 판을 옮기거나 바닥을 바꿨으면 **다시 실행**한다(예전 매트를 지우고 새로 만든다).
- 한 자리만 높이를 손보려면 그 판(`PlotSpots`의 숫자)과 매트(`PlotSpotPads`의 `Spot숫자`)를 **같이 선택해서** 옮긴다. 트리는 판 바닥 높이에 선다.

```lua
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
```

### 트리 크기 (자리 사이 간격 잡을 때)

| 항목 | 크기 (스터드) |
| --- | --- |
| 트리 폭 (맨 아래층 지름) | 약 13 |
| 트리 높이 (토퍼 포함) | 약 18 |
| 이름표 높이 | 바닥에서 약 22 |
| 띠 장식 | 트리 폭 안 |
| 사람이 나타나는 곳 | 트리 앞 14 |

- 트리끼리는 **중심 간격 18 이상**이면 겹치지 않지만, 바닥 아이템까지 넣는 내 자리(판 30)를 쓰려면 **30 이상**, 사이로 사람이 지나가려면 36 이상 띄운다.
- 트리 앞 14스터드 안에 부스·벽이 있으면 사람이 그 안에 끼일 수 있다. 앞쪽은 비워 둔다.
- 트리 모양·크기를 바꾸고 싶으면 Claude에게 말한다 (`src/server/TreeService.luau`의 `LAYERS`).

### 트리 모델 (TreeTemplate)

`ServerStorage`에 `TreeTemplate`이라는 **Model**이 있으면 원기둥 트리 대신 그 모델을 세운다. 없으면 원기둥 트리가 나온다.

- 원본: `assets/models/ChristmasTree.fbx` (Blender 스크립트 `tools/blender/make_tree.py`로 만듦)
- Studio에서 **Home → Import**로 불러온 뒤, 생긴 Model을 `ServerStorage`로 옮기고 이름을 `TreeTemplate`으로 바꾼다.
- 트리는 **똑바로 선 모습**으로 두고, 피벗을 돌리지 않는다. 크기·위치는 아무래도 된다. 게임이 시작될 때 높이를 위 표의 트리 높이(토퍼 제외 16)에 맞추고 밑동을 자리 바닥 가운데에 세운다.
- 장식은 모델 겉면에 맞춰 자동으로 붙는다. 위치를 직접 정하려면 아래 "장식 자리 직접 정하기"를 따른다.
  - 토퍼: 꼭대기 끝에 앉는다.
  - 띠: 층마다 겉면을 **비스듬히** 한 바퀴 두르는 전구 줄이다 (`GARLAND_TIERS` 순서: 4층, 2층, 5층). 기울기는 `TreeService.luau`의 `GARLAND_TILT`.
  - 오너먼트: 띠 3줄을 따라 트리 둘레 360도에 고르게 매달려 사선으로 이어진다 (`ORNAMENT_SPOTS`에서 띠 번호와 각도). 띠를 안 걸어도 그 자리를 따른다. 걸면 트리에서 낮은 자리부터 채워진다(내 트리 창 번호 1, 2, 3 ... 순서).
- 층마다 밖으로 보이는 경사면 높이는 `TreeService.luau`의 `TEMPLATE_TIER_BANDS`에 적혀 있다 (`assets/models/ChristmasTree.fbx`를 재서 정함). **트리 모델 모양을 바꾸면 Claude에게 다시 재 달라고 한다.**
- **장식·띠가 트리에서 떠 보이면** 트리 MeshPart의 `CollisionFidelity`를 `PreciseConvexDecomposition`으로 바꾼다. 장식 위치는 광선으로 트리 겉면을 재서 정하는데, 광선은 보이는 모양이 아니라 충돌 모양에 맞는다. 기본값(덩어리 모양)이면 층 사이 오목한 곳을 못 재서 떠 보인다. Play를 멈춘 상태에서 Command Bar에 아래를 실행하고 저장(`Cmd + S`)한다. 안 돼 있으면 Play할 때 Output에 경고가 나온다.
  ```lua
  local t = game.ServerStorage:FindFirstChild("TreeTemplate") or workspace:FindFirstChild("TreeTemplate")
  for _, p in t:GetDescendants() do
  	if p:IsA("MeshPart") then p.CollisionFidelity = Enum.CollisionFidelity.PreciseConvexDecomposition end
  end
  print("바꿈")
  ```
- `ServerStorage`는 Rojo가 건드리지 않으므로 모델은 플레이스 파일에 저장된다 (`Cmd + S`).
- 편집할 때는 `TreeTemplate`을 `Workspace`에 꺼내 둬도 된다. 게임이 시작되면 Workspace에 있는 원본은 자동으로 치워지고 트리 자리마다 복제된다.

### 장식 자리 직접 정하기 (Slots)

`TreeTemplate` 안에 자리 표시 파트를 넣으면 코드가 정한 자리 대신 그 위치에 장식이 걸린다.

1. `ServerStorage`의 `TreeTemplate`을 `Workspace`로 드래그해서 화면에 보이게 한다.
2. `TreeTemplate` 안에 **Folder**를 만들고 이름을 정확히 `Slots`로 바꾼다.
3. `Slots` 안에 작은 **Part**(예: 1 × 1 × 1)를 넣고 장식이 걸릴 곳에 옮긴다. 이름으로 어느 자리인지 정한다.

   | 이름 | 뜻 |
   | --- | --- |
   | `Topper` | 꼭대기 장식이 앉을 자리 (파트 가운데가 토퍼 밑면) |
   | `Ornament1` ~ `Ornament10` | 오너먼트 위치 (파트 가운데. 트리 겉면에 반쯤 걸치게) |
   | `Garland1` ~ `Garland3` | 띠 높이. 파트 높이가 비스듬한 띠의 가운데 높이가 된다 (앞뒤 위치는 상관없음) |

   - 번호 개수는 `Config.luau`의 `MAX_ORNAMENT`, `MAX_GARLAND`를 따른다. 표시가 없는 번호는 자동 위치를 쓴다.
   - 이름이 틀리면 Play할 때 Output에 노란 경고가 나온다.
   - 파트 하나를 만들고 `Cmd + D`로 복제하면 편하다. 색을 눈에 띄게 하고 `Anchored`, `CanCollide` 끄기를 권한다.
4. 다 했으면 Play로 확인한다. Output에 `[Tree] TreeTemplate.Slots에서 장식 자리 N곳을 읽었습니다`가 나온다.
5. 확인이 끝나면 `TreeTemplate`을 `ServerStorage`로 되돌리거나 Workspace에 그대로 두고 `Cmd + S`로 저장한다.

- 모델 크기는 아무래도 된다. 게임이 트리 높이를 맞출 때 표시도 같이 늘거나 줄어든다.
- 트리 정면은 모델의 **피벗 앞(-Z) 방향**이다. 피벗을 돌리지 않았다면 처음 불러온 방향 그대로다.
- 이미 걸려 있는 장식은 번호(`Ornament3` 등)로 저장되어 있어서, 표시를 옮기면 기존 장식도 새 위치로 옮겨진다.

---

## 2. 투명벽 (맵 밖으로 못 나가게)

### 자동으로 만들기 (Command Bar)

트리 자리(`PlotSpots`)를 모두 감싸는 **원형** 투명벽을 한 번에 세운다. 짧은 벽 조각을 원 둘레에 빙 둘러 세우는 방식이다. **Play를 멈춘 상태**에서 **View → Command Bar**에 붙여 넣고 Enter.

- 편집할 때는 **빨간 반투명**으로 보여서 위치를 확인하기 좋다. **게임이 시작되면 자동으로 안 보이게** 된다(코드가 `MapWalls`·`Walls` 폴더의 파트를 투명하게 바꾼다).
- 다시 실행하면 예전 `MapWalls`를 지우고 새로 세운다. 크기는 `MARGIN`(가장 바깥 트리 자리에서 벽까지)이나 `RADIUS`(직접 정하는 반지름)로 바꾼다. 원이 더 매끈해야 하면 `SEGMENTS`를 늘린다.
- 원의 가운데는 트리 자리들의 가운데(없으면 맵 원점)다. 광장 가운데가 따로 있으면 `CENTER`에 적는다.
- 다 됐으면 저장(`Cmd + S`).

```lua
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
```

### 손으로 만들기

1. `Workspace`에 **Folder** `Walls`를 만든다 (정리용, 이름은 자유).
2. **Part**를 넣고 맵 가장자리를 따라 세운다.
   - 크기 예: 두께 2, 높이 60 이상 (점프·뛰어넘기 방지)
   - Properties:
     | 속성 | 값 |
     | --- | --- |
     | `Anchored` | 켜기 |
     | `CanCollide` | 켜기 |
     | `Transparency` | `1` |
     | `CastShadow` | 끄기 |
     | `CanQuery` | 끄기 (클릭·레이 판정에서 빠짐) |
3. 모서리는 벽끼리 살짝 겹치게 해서 틈을 없앤다.
4. 천장도 필요하면(아주 높이 점프하는 게임패스 등) 같은 방법으로 위를 덮는다.

> 편집 중에 투명벽이 안 보여서 헷갈리면, 만들 때는 `Transparency`를 `0.7`로 두고 다 만든 뒤 `1`로 바꾼다.

---

## 2-0. 바닥 깔기: 잔디 + 눈 (Command Bar)

길을 깔기 **전에** 바닥부터 깐다. 투명벽 안쪽(조금 더 넓게)에 **잔디 원판**을 깔고, 그 위에 **눈 무더기**를 흩뿌린다(가장자리일수록 많이). 다시 실행하면 예전 `MapGround`를 지우고 새로 깐다.

- 먼저 **기본 `Baseplate`를 지운다**(잔디와 같은 높이라 겹쳐서 깜빡인다). 맵 밖이 허공이 되므로 투명벽 밖 꾸미기(숲·눈 언덕)는 따로 바닥을 깐다.
- 눈 무더기는 길보다 얇고 낮게 깔려서, 길을 깔면 길이 눈 위로 보인다. 트리 자리 위에 눈이 겹쳐도 트리가 그 위에 선다.
- 눈 양은 `SNOW_PATCHES`, 배치는 `SEED`를 바꿔 다시 실행한다. 다 됐으면 `Locked`로 잠근다.

```lua
local GRASS_COLOR = Color3.fromRGB(104, 150, 82) -- 잔디색
local SNOW_COLOR = Color3.fromRGB(240, 245, 252) -- 눈색
local SNOW_PATCHES = 160 -- 눈 무더기 수 (늘리면 눈이 많아진다)
local SNOW_SIZE = { 6, 22 } -- 눈 무더기 지름 범위(스터드)
local EDGE_SNOW = 2 -- 클수록 맵 가장자리에 눈이 몰린다 (1이면 고르게)
local MARGIN = 6 -- 투명벽 밖으로 더 까는 여유
local SEED = 7 -- 바꾸면 눈 무더기 배치가 달라진다

-- 가운데·바닥 높이·반지름: 트리 자리와 투명벽 기준
local center, groundY, radius = Vector3.zero, 0, 210
local spots = workspace:FindFirstChild("PlotSpots")
if spots then
	local sum, low, n = Vector3.zero, math.huge, 0
	for _, p in spots:GetChildren() do
		if p:IsA("BasePart") then
			sum += p.Position
			low = math.min(low, p.Position.Y - p.Size.Y / 2)
			n += 1
		end
	end
	if n > 0 then
		center, groundY = sum / n, low
	end
end
local walls = workspace:FindFirstChild("MapWalls")
if walls then
	local far = 0
	for _, w in walls:GetChildren() do
		if w:IsA("BasePart") then
			far = math.max(far, (Vector3.new(w.Position.X, 0, w.Position.Z) - Vector3.new(center.X, 0, center.Z)).Magnitude)
		end
	end
	if far > 0 then
		radius = far
	end
end
radius += MARGIN

local old = workspace:FindFirstChild("MapGround")
if old then old:Destroy() end
local folder = Instance.new("Folder")
folder.Name = "MapGround"
folder.Parent = workspace

local function disc(name, x, z, diameter, thick, topY, color, material)
	local p = Instance.new("Part")
	p.Name = name
	p.Shape = Enum.PartType.Cylinder
	p.Anchored = true
	p.CanCollide = true
	p.CastShadow = false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Material = material
	p.Color = color
	p.Size = Vector3.new(thick, diameter, diameter)
	p.CFrame = CFrame.new(x, topY - thick / 2, z) * CFrame.Angles(0, 0, math.pi / 2)
	p.Parent = folder
	return p
end

-- 잔디 원판: 윗면이 트리 자리 바닥 높이보다 아주 조금 위 (길은 이 위에 얹힌다)
disc("Grass", center.X, center.Z, radius * 2, 4, groundY + 0.02, GRASS_COLOR, Enum.Material.Grass)

-- 눈 무더기: 원 몇 개를 겹쳐 울퉁불퉁한 모양으로. 가장자리일수록 많이
local rng = Random.new(SEED)
for i = 1, SNOW_PATCHES do
	local r = radius * (rng:NextNumber() ^ (1 / (EDGE_SNOW + 1)))
	local a = rng:NextNumber() * math.pi * 2
	local x, z = center.X + math.sin(a) * r, center.Z - math.cos(a) * r
	local size = rng:NextNumber(SNOW_SIZE[1], SNOW_SIZE[2])
	for k = 1, rng:NextInteger(2, 4) do
		local ox, oz = rng:NextNumber(-0.4, 0.4) * size, rng:NextNumber(-0.4, 0.4) * size
		local d = size * rng:NextNumber(0.5, 1)
		-- 원판 밖으로 나가지 않게
		if (Vector3.new(x + ox, 0, z + oz) - Vector3.new(center.X, 0, center.Z)).Magnitude + d / 2 < radius then
			disc("Snow" .. i .. "_" .. k, x + ox, z + oz, d, 0.3, groundY + 0.06 + k * 0.01, SNOW_COLOR, Enum.Material.Snow)
		end
	end
end
print(string.format("바닥을 깔았습니다: 잔디 반지름 %.0f, 눈 무더기 %d곳 (MapGround)", radius, SNOW_PATCHES))
```

## 2-1. 길 깔기: 지형(눈) 바닥 위에 (Command Bar)

바닥이 **지형(Terrain)**일 때 쓴다. 파트를 까는 대신 **지형 표면의 재질만 길 재질로 바꾼다**. 그래서 울퉁불퉁한 눈 바닥을 그대로 따라 길이 생기고, 떠 보이거나 묻히지 않는다.

- **가운데 광장**: `StarPole`(별 기둥) 둘레. 붉은 벽돌 재질
- **트리 구경 둘레길**: 트리 자리 판 안쪽을 한 바퀴
- **세 갈래 길**: 광장에서 120도 간격. 첫 갈래는 **트리 자리 판이 가장 크게 비어 있는 곳(포토존)**으로 자동으로 향해 판 원 바깥까지 이어진다
- 길 색은 지형 재질 색을 바꾸는 것이라, 같은 재질(Cobblestone·Brick)을 쓰는 다른 지형도 같은 색이 된다
- 마음에 안 들면 `REVERT = true`로 한 번 실행해 눈으로 되돌린 뒤, 숫자를 고쳐 다시 깐다

```lua
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
```

## 2-1-b. 길 깔기: 평평한 파트 바닥 위에 (Command Bar)

바닥이 평평한 파트(위 "2-0. 바닥 깔기")일 때 쓴다. 갈색 돌길 파트를 깐다.



맵 분위기 초안의 길을 한 번에 깐다. **트리 자리를 원 따라 놓은 뒤** 실행한다(트리 자리 원을 기준으로 길 크기를 정한다). 다시 실행하면 예전 `MapPaths`를 지우고 새로 깐다.

- **트리 구경 둘레길**: 트리 자리 판 안쪽을 한 바퀴 도는 갈색 돌길
- **가운데 광장**: 룰렛 가게가 설 붉은 돌 원판
- **세 갈래 길**: 광장에서 둘레길까지 120도 간격 세 갈래. 세 갈래 모두 둘레길에서 멈춘다(`EXTEND`를 늘리면 첫 갈래가 1번·2번 자리 사이로 포토존 쪽까지 이어진다)
- 재질은 Roblox 기본 `Cobblestone`(돌길 무늬). 색·폭은 맨 위 숫자로 바꾼다. 다 됐으면 `Locked`로 잠가 두면 꾸밀 때 안 집힌다

```lua
local PAD = 30 -- 트리 자리 판 크기 (원 따라 놓기 스크립트와 같게)
local RING_WIDTH = 14 -- 트리 구경 둘레길 폭
local RING_GAP = 8 -- 트리 자리 판 안쪽 끝과 둘레길 사이 여유
local PLAZA_RADIUS = 30 -- 가운데 광장(룰렛 자리) 반지름
local SPOKE_WIDTH = 12 -- 세 갈래 길 폭
local START_ANGLE = 0 -- 원 따라 놓기의 START_ANGLE과 같게. 첫 갈래는 1번·2번 자리 사이(포토존 쪽)로 맵 끝까지 이어진다
local EXTEND = 0 -- 첫 갈래를 둘레길 밖으로 더 늘릴 길이 (포토존 쪽으로 이으려면 40 정도)
local SEGMENTS = 72 -- 둘레길 조각 수
local THICK = 0.2 -- 길 두께
local PATH_COLOR = Color3.fromRGB(150, 108, 80) -- 돌길 갈색
local PLAZA_COLOR = Color3.fromRGB(170, 92, 82) -- 가운데 광장 붉은 돌

-- 트리 자리들로 가운데·반지름·바닥 높이를 정한다
local spots = workspace:FindFirstChild("PlotSpots")
local center, groundY, treeRadius, count = Vector3.zero, 0, 160, 0
if spots then
	local sum, low = Vector3.zero, math.huge
	for _, p in spots:GetChildren() do
		if p:IsA("BasePart") then
			sum += p.Position
			low = math.min(low, p.Position.Y - p.Size.Y / 2)
			count += 1
		end
	end
	if count > 0 then
		center = sum / count
		groundY = low
		local total = 0
		for _, p in spots:GetChildren() do
			if p:IsA("BasePart") then
				total += (Vector3.new(p.Position.X, 0, p.Position.Z) - Vector3.new(center.X, 0, center.Z)).Magnitude
			end
		end
		treeRadius = total / count
	end
end
local ringRadius = treeRadius - PAD / 2 - RING_GAP - RING_WIDTH / 2 -- 둘레길 가운데선 반지름

local old = workspace:FindFirstChild("MapPaths")
if old then old:Destroy() end
local folder = Instance.new("Folder")
folder.Name = "MapPaths"
folder.Parent = workspace

local function slab(name, cf, size, color, lift)
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.CanCollide = true
	p.CastShadow = false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Material = Enum.Material.Cobblestone
	p.Color = color
	p.Size = size
	p.CFrame = cf + Vector3.new(0, lift, 0)
	p.Parent = folder
	return p
end
local base = groundY + THICK / 2

-- 1. 트리 구경 둘레길: 조각을 원 둘레에 이어 붙인다
local outer = ringRadius + RING_WIDTH / 2
local length = 2 * outer * math.tan(math.pi / SEGMENTS) + 0.3
for i = 1, SEGMENTS do
	local a = (i - 1) / SEGMENTS * math.pi * 2
	local pos = Vector3.new(center.X + math.sin(a) * ringRadius, base, center.Z - math.cos(a) * ringRadius)
	local cf = CFrame.lookAt(pos, Vector3.new(center.X, base, center.Z))
	slab("Ring" .. i, cf, Vector3.new(length, THICK, RING_WIDTH), PATH_COLOR, 0)
end

-- 2. 가운데 광장: 납작한 원판
local plaza = slab("Plaza", CFrame.new(center.X, base, center.Z) * CFrame.Angles(0, 0, math.pi / 2),
	Vector3.new(THICK, PLAZA_RADIUS * 2, PLAZA_RADIUS * 2), PLAZA_COLOR, 0.04)
plaza.Shape = Enum.PartType.Cylinder

-- 3. 세 갈래 길: 광장에서 둘레길까지 (첫 갈래는 1번·2번 자리 사이로 맵 끝까지)
local step = spots and count > 0 and (360 / count) or 18
for k = 0, 2 do
	local deg = START_ANGLE + step / 2 + k * 120
	local a = math.rad(deg)
	local dir = Vector3.new(math.sin(a), 0, -math.cos(a))
	local from = PLAZA_RADIUS - 2
	local to = ringRadius + RING_WIDTH / 2 + (k == 0 and EXTEND or 0)
	local mid = Vector3.new(center.X, base, center.Z) + dir * ((from + to) / 2)
	local cf = CFrame.lookAt(mid, mid + dir)
	slab("Spoke" .. (k + 1), cf, Vector3.new(SPOKE_WIDTH, THICK, to - from), PATH_COLOR, 0.02)
end
print(string.format("길을 깔았습니다: 둘레길 반지름 %.0f (폭 %d), 광장 반지름 %d, 세 갈래 길 (MapPaths)", ringRadius, RING_WIDTH, PLAZA_RADIUS))
```

## 3. 시작 위치

- `SpawnLocation`은 **처음 들어와서 데이터를 불러오는 1~2초 동안** 서 있는 곳이다. 데이터가 오면 자기 트리 앞으로 순간이동한다.
- 마켓 입구나 광장 가운데에 하나 두면 된다.

---

## 4. 저장하고 확인

1. 맵을 고친 뒤 `Cmd + S` (Save to Roblox).
2. Play → Output에 `PlotSpots에 자리가 N개뿐입니다` 경고가 없는지 확인.
3. **Test** 탭에서 플레이어를 2~3명으로 두고 Start → 트리가 1번, 2번, 3번 자리에 차례로 생기는지 확인.

## 5. 꾸미기 에셋

맵 분위기 초안(원형 광장 · 가운데 별 기둥 스폰 · 룰렛/업그레이드/물약 가게 · 세 갈래 길 · 트리 구경 둘레길 · 포토존 아치 · 리더보드 · 숲 · 눈 언덕)에 맞춘 에셋.

### 우리가 만든 에셋 (먼저 쓰기)

`assets/models/map/`의 FBX 14종은 이 초안에 맞춰 만든 것이다. **Home → Import 3D**로 하나씩 불러온다(1단위 = 1스터드).

| 초안 | 파일 |
| --- | --- |
| 가운데 별 기둥(스폰) | `StarPole.fbx` (색 그림 포함: 불러오기만 하면 색이 보인다. 색 입히기 스크립트를 쓰지 않는다. 미리보기 `StarPole_preview.png`, 만드는 스크립트 `tools/blender/make_starpole.py`) |
| 룰렛·업그레이드·물약 가게 | `StallRoulette.fbx` · `StallUpgrade.fbx` · `StallPotion.fbx` |
| 포토존 아치 · 벤치 · 눈사람 · 선물상자 | `PhotoArch.fbx` · `Bench.fbx` · `Snowman.fbx` · `GiftBox.fbx` |
| 길가 가로등 · 전구 줄 | `LampPost.fbx` · `StringLight.fbx`(이어 붙이는 조각) |
| 각자의 트리 자리 받침 | `PlotBase.fbx` |
| 리더보드 판 | `Leaderboard.fbx` |
| 숲 · 눈 언덕 | `PineTree.fbx` · `SnowHill.fbx` |

### 우리 FBX 색 입히기 (Command Bar)

Import 3D로 불러오면 색이 빠져서 **회색**으로 나올 수 있다(텍스처 없이 재질 색만 쓴 모델이라). 파트 이름 끝(`StarPole_Stone`의 `Stone`)을 보고 Blender에서 정한 색을 다시 입힌다. `Glow…`는 빛나는 Neon, `GlowWarm`(가로등·가게 전구)에는 불빛도 단다. **선택한 모델에만** 입히고, 아무것도 선택하지 않으면 Workspace 전체에 입힌다.

```lua
local COLORS = {
	Coal = { 24, 24, 28 }, Cream = { 246, 241, 231 }, Glass = { 192, 231, 255 },
	GlowBlue = { 90, 161, 240 }, GlowGold = { 255, 217, 73 }, GlowGreen = { 121, 231, 191 },
	GlowRed = { 233, 63, 57 }, GlowWarm = { 255, 227, 151 }, Gold = { 255, 217, 73 },
	Green = { 43, 155, 92 }, GreenDark = { 32, 107, 74 }, Iron = { 39, 43, 55 },
	Orange = { 255, 155, 57 }, Potion = { 181, 92, 255 }, Purple = { 139, 92, 240 },
	Red = { 217, 46, 55 }, Snow = { 244, 248, 255 }, Stone = { 142, 128, 135 },
	Wood = { 139, 85, 46 }, WoodDark = { 95, 55, 26 }, WoodLight = { 177, 123, 75 },
}
local roots = game:GetService("Selection"):Get()
if #roots == 0 then
	roots = { workspace }
end
local painted = 0
for _, root in roots do
	local list = root:GetDescendants()
	table.insert(list, root)
	for _, p in list do
		if not p:IsA("BasePart") then
			continue
		end
		local key = string.match(p.Name, "_([%a]+)$") or p.Name
		local rgb = COLORS[key]
		if not rgb then
			continue
		end
		p.Color = Color3.fromRGB(rgb[1], rgb[2], rgb[3])
		if p.Name == "StarPole_GlowGold" then
			-- 별 기둥의 별: Neon이면 면 음영이 사라져 모양이 안 보인다. 금속 느낌 + 불빛으로
			p.Material = Enum.Material.Metal
			if not p:FindFirstChildOfClass("PointLight") then
				local light = Instance.new("PointLight")
				light.Color = p.Color
				light.Range = 20
				light.Brightness = 2
				light.Parent = p
			end
		elseif string.sub(key, 1, 4) == "Glow" then
			p.Material = Enum.Material.Neon
		elseif key == "Glass" then
			p.Material = Enum.Material.Glass
			p.Transparency = 0.4
		else
			p.Material = Enum.Material.SmoothPlastic
		end
		if key == "GlowWarm" and not p:FindFirstChildOfClass("PointLight") then
			local light = Instance.new("PointLight")
			light.Color = p.Color
			light.Range = 14
			light.Brightness = 1.5
			light.Parent = p
		end
		painted += 1
	end
end
print("색을 입힌 파트:", painted)
```

### 무료 에셋 후보 (Creator Store)

웹 검색으로 찾은 후보다. 품질·라이선스·스크립트 여부는 **직접 확인하지 못했다**. 아래 스크립트로 한꺼번에 꺼내 보고 마음에 드는 것만 남긴다.

| 용도 | 에셋 ID | 이름 |
| --- | --- | --- |
| 가게 | 2994923203 | Shop Model (FREE!) |
| 전구 줄 | 8236432063 | Christmas Lights - Decoration |
| 전구 줄 | 208231531 | Simple Christmas Lights |
| 가로등 | 18184120049 | Old Roblox Lamp Post |
| 눈사람 | 2115285171 | Snowman |
| 눈사람 | 5722668698 | Snowman Couple |
| 선물상자 | 12606769394 | Gift Box (MrCat) |
| 선물상자 | 15480976264 | Gift box |
| 벤치 | 86392811 | Park Bench |
| 벤치 | 1127298073 | Modern Park Bench |
| 사탕지팡이(아치 꾸미기) | 11766336375 | Christmas Candy Cane |
| 숲 | 13986682846 | Low Poly Pine Tree |
| 숲 | 261980178 | Pine Tree (Snowy) |
| 숲 | 12016295226 | Low poly snow tree |
| 눈 언덕 | 17139851600 | Low Poly Hills |
| 눈 언덕 | 11821992228 | Low Poly Mountain |
| 맵 둘레 산 | 13883219499 | Mountain border for Terrain maps (Low-Poly) |
| 바위 | 14566490393 | Low Poly Rock |
| 모음 팩 | 6286468514 | Low poly Village and Nature Asset Pack |
| 모음 팩 | 8379202496 | FREE LOW POLY ASSET PACK 2.0 |

### 무료 모델 넣은 뒤 꼭: 숨은 스크립트 검사 (Command Bar)

Toolbox 무료 모델에는 `qTexture`·`TextureConfiguration`·`CoreViewSystem`·`cTextureManager`처럼 **이름을 위장한 백도어 스크립트**가 자주 숨어 있다(다른 사람 코드를 에셋 ID로 몰래 불러오려 한다. Creator Hub 오류에 `cannot require using asset ID (lacking capability LoadUnownedAsset)`로 보인다). 맵에 모델을 넣었으면 아래로 검사한다. 우리 코드(Rojo의 `Server`·`Client`·`Shared`) 밖 스크립트를 모두 찾는다. 처음엔 목록만 보고, 확인 뒤 `DELETE = true`로 다시 실행해 지운 다음 저장·퍼블리시한다.

```lua
local DELETE = false -- 목록을 확인한 뒤 true로 바꿔 다시 실행하면 지운다
local keep = {
	game.ServerScriptService:FindFirstChild("Server"),
	game.StarterPlayer.StarterPlayerScripts:FindFirstChild("Client"),
	game.ReplicatedStorage:FindFirstChild("Shared"),
}
local function isOurs(inst)
	for _, root in keep do
		if root and (inst == root or inst:IsDescendantOf(root)) then
			return true
		end
	end
	return false
end
local found = 0
for _, service in { workspace, game.ReplicatedStorage, game.ServerStorage, game.ServerScriptService, game.StarterGui, game.StarterPack, game.StarterPlayer, game.Lighting } do
	for _, d in service:GetDescendants() do
		if d:IsA("LuaSourceContainer") and not isOurs(d) then
			found += 1
			warn("우리 코드 밖 스크립트:", d:GetFullName(), d.ClassName)
			if DELETE then
				d:Destroy()
			end
		end
	end
end
print(DELETE and "지움:" or "찾음:", found)
```

### 후보 한꺼번에 꺼내 보기 (Command Bar)

`Workspace`의 `AssetInbox` 폴더에 후보를 한 줄로 늘어놓는다(높이 300 공중, 스크립트는 지움). 고른 것은 `MapDecor` 등으로 옮기고, 끝나면 `AssetInbox`를 통째로 지운다. Explorer에서 `AssetInbox`를 고르고 `F`를 누르면 카메라가 간다.

```lua
local IDS = {
	2994923203, 8236432063, 208231531, 18184120049, 2115285171, 5722668698,
	12606769394, 15480976264, 86392811, 1127298073, 11766336375, 13986682846,
	261980178, 12016295226, 17139851600, 11821992228, 13883219499, 14566490393,
	6286468514, 8379202496,
}
local GAP = 40
local inbox = workspace:FindFirstChild("AssetInbox") or Instance.new("Folder")
inbox.Name = "AssetInbox"
inbox.Parent = workspace
for i, id in IDS do
	local ok, objects = pcall(function()
		return game:GetObjects("rbxassetid://" .. id)
	end)
	if not ok or #objects == 0 then
		warn("못 불러옴:", id, objects)
		continue
	end
	local holder = Instance.new("Model")
	holder.Name = string.format("%02d_%d_%s", i, id, objects[1].Name)
	for _, obj in objects do
		obj.Parent = holder
	end
	local removed = 0
	for _, d in holder:GetDescendants() do
		if d:IsA("LuaSourceContainer") then
			d:Destroy()
			removed += 1
		elseif d:IsA("BasePart") then
			d.Anchored = true
		end
	end
	holder.Parent = inbox
	if holder:FindFirstChildWhichIsA("BasePart", true) then
		local box = holder:GetBoundingBox()
		holder:PivotTo(holder:GetPivot() + (Vector3.new((i - 1) * GAP, 300, 0) - box.Position))
	end
	print(string.format("꺼냄 %s (스크립트 %d개 지움)", holder.Name, removed))
end
```

---

## 팀 작업 주의

- 맵은 GitHub가 아니라 **플레이스 파일**에 있다. 팀원이 각자 만든 테스트 플레이스에는 맵이 없으므로 트리가 원 모양으로 배치된다(정상).
- 원래 게임 플레이스의 맵은 공동 편집(Collaborate)으로 같이 고친다.
