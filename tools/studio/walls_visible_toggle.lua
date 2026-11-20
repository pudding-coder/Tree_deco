-- 투명벽을 편집 화면에서 숨기기/보이기 (게임에서는 항상 안 보인다). 다시 실행하면 반대로
local walls = workspace:FindFirstChild("MapWalls")
assert(walls, "MapWalls가 없습니다")
local first = walls:FindFirstChildWhichIsA("BasePart")
local hide = first and first.Transparency < 1
for _, p in walls:GetDescendants() do
	if p:IsA("BasePart") then
		p.Transparency = if hide then 1 else 0.7
	end
end
print(if hide then "투명벽을 숨겼습니다" else "투명벽을 다시 보이게 했습니다")
