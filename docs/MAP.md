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

게임이 시작되면 표시 파트는 자동으로 투명해지고(안의 글자도 지워짐) 부딪히지 않는다. 편집할 때는 보이니 그대로 두면 된다.

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
