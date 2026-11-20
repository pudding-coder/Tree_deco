-- 아바타 모델 만들기: 카메라 앞 바닥에 사람 모양 모델(Humanoid 포함)을 하나 세운다
-- NPC, 상점 주인, 포토존 마네킹 등에 쓴다. Play를 멈춘 상태에서 실행
-- 위 설정만 바꾸면 된다. 다시 실행하면 같은 이름의 모델을 지우고 새로 만든다

local MODEL_NAME = "AvatarModel"   -- Explorer에 보일 이름
local DISPLAY_NAME = ""            -- 머리 위 이름표. 비우면 안 보임
local USER_ID = 0                  -- 로블록스 사용자 번호를 넣으면 그 사람 옷차림으로 만든다. 0이면 기본 모습
local RIG_TYPE = Enum.HumanoidRigType.R15 -- R6로 바꾸면 블록 모양 6파트
local ANCHORED = true              -- true면 서 있기만 함(마네킹). 걸어 다니게 하려면 false

-- 기본 모습일 때 색 (USER_ID = 0일 때만 씀)
local SKIN = Color3.fromRGB(255, 204, 153)
local SHIRT = Color3.fromRGB(196, 40, 28)   -- 크리스마스 빨강
local PANTS = Color3.fromRGB(39, 70, 45)    -- 짙은 초록

local Players = game:GetService("Players")
local Selection = game:GetService("Selection")

-- 1. 모습 정하기
local desc
if USER_ID ~= 0 then
	local ok, result = pcall(Players.GetHumanoidDescriptionFromUserId, Players, USER_ID)
	if ok then
		desc = result
	else
		warn("사용자 모습을 못 불러와서 기본 모습으로 만듭니다:", result)
	end
end
if not desc then
	desc = Instance.new("HumanoidDescription")
	desc.HeadColor = SKIN
	desc.LeftArmColor = SKIN
	desc.RightArmColor = SKIN
	desc.TorsoColor = SHIRT
	desc.LeftLegColor = PANTS
	desc.RightLegColor = PANTS
end

-- 2. 모델 만들기
local ok, model = pcall(Players.CreateHumanoidModelFromDescription, Players, desc, RIG_TYPE)
if not ok then
	error("아바타를 못 만들었습니다(Studio가 로그인돼 있고 인터넷이 되는지 확인): " .. tostring(model))
end
model.Name = MODEL_NAME

-- 3. 안에 든 스크립트(Animate 등) 정리. 마네킹이면 필요 없다
if ANCHORED then
	for _, d in model:GetDescendants() do
		if d:IsA("LuaSourceContainer") then
			d:Destroy()
		end
	end
end

local humanoid = model:FindFirstChildOfClass("Humanoid")
local root = model:FindFirstChild("HumanoidRootPart")
model.PrimaryPart = root
if DISPLAY_NAME ~= "" then
	humanoid.DisplayName = DISPLAY_NAME
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.Viewer
else
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
end
root.Anchored = ANCHORED

-- 4. 예전에 만든 같은 이름 모델 지우기
local parent = workspace:FindFirstChild("MapDecor") or workspace
local old = parent:FindFirstChild(MODEL_NAME)
if old then
	old:Destroy()
end

-- 5. 놓을 곳: 카메라 앞 12스터드, 바닥 위에 서게
local cam = workspace.CurrentCamera
local look = cam.CFrame.LookVector * Vector3.new(1, 0, 1)
if look.Magnitude < 0.01 then
	look = Vector3.new(0, 0, -1)
end
look = look.Unit
local spot = cam.CFrame.Position + look * 12

local params = RaycastParams.new()
params.FilterDescendantsInstances = { model }
local hit = workspace:Raycast(spot + Vector3.new(0, 50, 0), Vector3.new(0, -500, 0), params)
local floorY = hit and hit.Position.Y or 0

-- 다리 길이(HipHeight) + 몸통 절반만큼 띄우면 발이 바닥에 닿는다
-- R6는 HipHeight가 0이고 다리 길이가 2라서 따로 계산한다
local legs = RIG_TYPE == Enum.HumanoidRigType.R6 and 2 or humanoid.HipHeight
local rootY = floorY + legs + root.Size.Y / 2
-- 카메라 쪽을 바라보게
local pos = Vector3.new(spot.X, rootY, spot.Z)
model:PivotTo(CFrame.lookAt(pos, pos - look))

-- 6. 넣기: MapDecor가 있으면 그 안에, 없으면 Workspace에
model.Parent = parent
Selection:Set({ model })

print(string.format("아바타 '%s'를 %s 안에 만들었습니다 (%s)", MODEL_NAME, parent:GetFullName(), RIG_TYPE.Name))
