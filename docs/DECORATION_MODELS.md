# 장식 모델 방향·모양 한꺼번에 맞추기 (Studio)

장식 3D 모델은 GitHub가 아니라 **플레이스 파일**의 `ReplicatedStorage.DecorationModels`에 있다.
방향은 Studio에서 모델을 직접 돌려서 맞추고, 크기와 위치는 게임이 자동으로 맞춘다.

---

## 규칙 (이것만 기억)

`DecorationModels`에 놓인 **그대로의 방향**이 기준이다.

| 모델에서 | 맞출 방향 |
| --- | --- |
| 앞(얼굴, 글자) | Studio의 **Front**(-Z) 쪽. 아래 꺼내기 스크립트의 **빨간 판 쪽** |
| 위(머리, 키링 고리) | 위(+Y) |

이렇게 맞춰 두면 트리 어느 자리에 걸어도 앞이 트리 바깥(보는 사람 쪽)을 본다.

게임이 알아서 하는 것(손대지 않아도 된다):

- **크기**: 가장 긴 변을 오너먼트 2.7, 토퍼 4.7스터드에 맞춘다. 원래 크기는 상관없다.
- **위치**: 모델 상자 가운데를 자리에 놓는다. 피벗 위치·방향은 상관없다.
- **기울기**: 오너먼트는 윗부분이 트리 쪽으로 20도 기운다(`lean`).
- **머리카락 토퍼**: `id`가 `Hair`로 끝나면 꼭대기에 절반 씌운다(`sink`).

---

## 작업 순서

> Play 중에 바꾼 것은 멈추면 사라진다. **꼭 Play를 멈춘 상태**에서 한다.

### 1. 모델 전부 꺼내기

**View → Command Bar**에 아래를 붙여 넣고 Enter.
`DecorationModels`의 모델이 공중(높이 200)에 한 줄로 늘어서고, 모델마다 앞쪽에 **이름이 적힌 빨간 판**이 깔린다.

```lua
local RS = game:GetService("ReplicatedStorage")
local source = RS:FindFirstChild("DecorationModels")
if not source then
	warn("ReplicatedStorage에 DecorationModels가 없습니다.")
elseif workspace:FindFirstChild("DecorationPreview") then
	warn("이미 꺼내 둔 DecorationPreview가 있습니다. 먼저 넣기 스크립트를 실행해 주세요.")
else
	local preview = Instance.new("Folder")
	preview.Name = "DecorationPreview"
	preview.Parent = workspace
	local GAP, SIZE, ORIGIN = 8, 4, Vector3.new(0, 200, 0)
	local models = source:GetChildren()
	table.sort(models, function(a, b) return a.Name < b.Name end)
	for i, m in models do
		local spot = ORIGIN + Vector3.new((i - 1) * GAP, 0, 0)
		local mark = Instance.new("Part")
		mark:SetAttribute("PreviewMark", true)
		mark.Name = "FrontMark"
		mark.Anchored, mark.CanCollide = true, false
		mark.Size = Vector3.new(SIZE, 0.2, 2)
		mark.Color = Color3.fromRGB(220, 60, 60)
		mark.CFrame = CFrame.new(spot + Vector3.new(0, -SIZE / 2 - 0.3, -SIZE / 2 - 1.2))
		local gui = Instance.new("SurfaceGui")
		gui.Face = Enum.NormalId.Top
		gui.Parent = mark
		local label = Instance.new("TextLabel")
		label.Size = UDim2.fromScale(1, 1)
		label.BackgroundTransparency = 1
		label.TextScaled = true
		label.TextColor3 = Color3.new(1, 1, 1)
		label.Text = m.Name .. " 앞"
		label.Parent = gui
		mark.Parent = preview

		m.Parent = preview
		if m:IsA("Model") then
			local _, size = m:GetBoundingBox()
			local longest = math.max(size.X, size.Y, size.Z)
			if longest > 0 then
				m:ScaleTo(m:GetScale() * SIZE / longest)
			end
			local box = m:GetBoundingBox()
			m:PivotTo(m:GetPivot() + (spot - box.Position))
		elseif m:IsA("BasePart") then
			m:PivotTo(m:GetPivot() + (spot - m.Position))
		end
	end
	print("꺼냄: " .. #models .. "개. Explorer에서 DecorationPreview를 선택하고 F를 누르면 보입니다.")
end
```

Explorer에서 `Workspace → DecorationPreview`를 클릭하고 화면에서 **F**를 누르면 카메라가 그쪽으로 간다.
빨간 판이 있는 쪽에서 모델들을 바라보게 카메라를 돌린다. 이 시점이 트리 앞에서 장식을 보는 시점이다.

### 2. 돌리기

빨간 판 쪽에서 봤을 때 **얼굴이 보이고 위가 위**인지 하나씩 확인하고, 아니면 돌린다.

| 상황 | 하는 법 |
| --- | --- |
| 등이나 옆이 보인다 | 모델을 클릭하고 **Ctrl + R** (세로축으로 90도). 등이면 두 번 |
| 누워 있거나 거꾸로다 | 모델을 클릭하고 **Ctrl + T** (눕히기 90도). 필요한 만큼 반복 |
| 90도 단위가 아니다 | **Model 탭 → Rotate** 도구로 원을 끌어 돌린다. Model 탭의 Rotate 칸에서 각도 단위(예: 15)를 정하면 편하다 |

- Explorer에서 모델 이름(예: `Santa`)을 클릭하면 모델 전체가 선택된다. 안의 파트가 하나만 선택되면 그 파트만 돌아가니 주의.
- 여러 개를 같은 만큼 돌릴 때는 Ctrl 누른 채 여러 개 클릭 후 Ctrl + R. (같이 선택하면 묶음 가운데를 기준으로 도는데, 위치는 상관없으니 괜찮다)
- 위치·크기는 아무렇게나 둬도 된다. 방향만 본다.

### 3. 다시 넣기

> 이 단계를 빼고 Play하면 모델이 전부 사라진 것처럼 보인다(게임은 `DecorationModels`만 본다). Output에 `DecorationPreview가 남아 있습니다` 경고가 나온다.

Command Bar에 아래를 붙여 넣고 Enter. 빨간 판은 지워지고 모델만 `DecorationModels`로 돌아간다.

```lua
local RS = game:GetService("ReplicatedStorage")
local preview = workspace:FindFirstChild("DecorationPreview")
local dest = RS:FindFirstChild("DecorationModels")
if not dest then
	-- 빈 폴더가 지워졌으면 새로 만든다
	dest = Instance.new("Folder")
	dest.Name = "DecorationModels"
	dest.Parent = RS
	print("ReplicatedStorage에 DecorationModels 폴더를 새로 만들었습니다.")
end
if not preview then
	warn("Workspace에 DecorationPreview가 없습니다. Play 중이라면 멈추고 다시 실행해 주세요.")
else
	local moved = 0
	for _, child in preview:GetChildren() do
		if child:GetAttribute("PreviewMark") then
			child:Destroy()
		else
			child.Parent = dest
			moved += 1
		end
	end
	preview:Destroy()
	print("넣음: " .. moved .. "개")
end
```

### 4. 확인하고 저장

1. **Play** → 장식을 뽑아 트리에 걸어 본다.
2. 멈추고 **Cmd(Ctrl) + S** 또는 **File → Publish to Roblox**. 모델은 플레이스 파일에 저장되므로 저장하지 않으면 사라진다.

---

## 그래도 어색할 때 (장식 줄에 적기, `src/shared/Catalog/Decorations.luau`)

Studio에서 고치기 어려운 것만 코드 쪽 값으로 손본다. Claude에게 "○○ 더 크게" 처럼 말해도 된다.

| 문제 | 적는 것 |
| --- | --- |
| 너무 작다 / 크다 | `size = 1.3` / `size = 0.8` |
| 오너먼트가 너무 눕거나 서 있다 | `lean = 30` (더 기울임) / `lean = 0` (똑바로) |
| 토퍼가 꼭대기 위에 떠 있다 | `sink = 0.5` (높이 절반을 꼭대기 아래로) |
| Studio에서 돌리기 싫다 | `turn = 180` / `90` / `-90` (Studio에서 맞춘 방향에서 더 돌린다) |

---

## 자주 보는 메시지

| Output | 뜻 |
| --- | --- |
| `[Tree] 장식 모델 N개 연결: …` | 서버 시작 때 연결된 모델 목록. 빠진 장식은 임시 공으로 보인다 |
| `이름이 어떤 장식 id와도 맞지 않는 모델: …` | 모델 이름이 `Decorations.luau`의 `id`와 다르다. 대소문자까지 맞춘다 |
| `rbxassetid://… failed due to: Asset type does not match` | 어느 모델 안의 텍스처·소리 칸에 종류가 다른 에셋 ID가 들어 있다. 그 부분만 빠져 보이고 게임에는 문제없다 |
| `Hello world!  -  Server - Script:1` | 어딘가 기본 `Script`가 남아 있다. Explorer 검색에 `Script`를 쳐서 찾아 지운다 |
