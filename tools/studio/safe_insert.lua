-- 에셋 ID로 안전하게 넣기: 스크립트를 지우고, 모든 파트를 고정해서, 카메라 앞에 놓는다
-- Toolbox에서 에셋 오른쪽 클릭 → Copy Asset ID → 아래 ID에 붙여 넣고 실행
local ID = 0 -- 여기에 에셋 ID
local FOLDER = "MapDecor" -- 넣을 폴더 (없으면 만든다)

local objects = game:GetObjects("rbxassetid://" .. ID)
local model = Instance.new("Model")
model.Name = (objects[1] and objects[1].Name or "Asset") .. "_" .. ID
for _, obj in objects do
	obj.Parent = model
end
local removed = 0
for _, d in model:GetDescendants() do
	if d:IsA("LuaSourceContainer") then
		d:Destroy()
		removed += 1
	elseif d:IsA("BasePart") then
		d.Anchored = true
	end
end
local folder = workspace:FindFirstChild(FOLDER) or Instance.new("Folder")
folder.Name = FOLDER
folder.Parent = workspace
model.Parent = folder
local cam = workspace.CurrentCamera
if model:FindFirstChildWhichIsA("BasePart", true) then
	local target = cam.CFrame.Position + cam.CFrame.LookVector * 30
	local box = model:GetBoundingBox()
	model:PivotTo(model:GetPivot() + (target - box.Position))
end
game:GetService("Selection"):Set({ model })
print(string.format("넣었습니다: %s (스크립트 %d개 지움) → %s", model.Name, removed, FOLDER))
