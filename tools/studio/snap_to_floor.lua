-- 선택한 물건을 바닥 표면 높이에 맞춰 내려놓는다 (울퉁불퉁한 눈 바닥에서 떠 있거나 묻힌 것)
-- 폴더를 선택하면 그 안의 모델·파트를 하나씩 맞춘다. 바닥: 지형 + Baseplate·MapFloor·MapGround 폴더 안 파트
local LIFT = 0 -- 바닥 위로 더 띄울 높이 (살짝 묻히면 0.2)

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

local selection = game:GetService("Selection"):Get()
print("선택된 것:", #selection)
local targets = {}
local function collect(inst)
	if inst:IsA("Model") or inst:IsA("BasePart") then
		table.insert(targets, inst)
	elseif inst:IsA("Folder") then
		for _, child in inst:GetChildren() do
			collect(child)
		end
	end
end
for _, sel in selection do
	collect(sel)
end

local moved = 0
for _, obj in targets do
	local box, size
	if obj:IsA("Model") then
		box, size = obj:GetBoundingBox()
	else
		box, size = obj.CFrame, obj.Size
	end
	local bottom = box.Position.Y - size.Y / 2
	local hit = workspace:Raycast(Vector3.new(box.Position.X, box.Position.Y + 500, box.Position.Z), Vector3.new(0, -2000, 0), params)
	if hit then
		obj:PivotTo(obj:GetPivot() + Vector3.new(0, hit.Position.Y + LIFT - bottom, 0))
		moved += 1
	else
		warn("밑에 바닥이 없습니다:", obj:GetFullName())
	end
end
print("바닥에 맞춘 것:", moved)
