-- 선택한 것 정리: 안의 스크립트를 지우고 모든 파트를 고정한다
-- Toolbox로 끌어다 넣은 모델, Play하면 떨어지는 나무·장식에 쓴다. 넣은 것을 Explorer에서 선택하고 실행
local scripts, anchored = 0, 0
for _, root in game:GetService("Selection"):Get() do
	local list = root:GetDescendants()
	table.insert(list, root)
	for _, d in list do
		if d:IsA("LuaSourceContainer") then
			print("지움:", d:GetFullName())
			d:Destroy()
			scripts += 1
		elseif d:IsA("BasePart") then
			d.Anchored = true
			anchored += 1
		end
	end
end
print(string.format("스크립트 %d개 지움, 파트 %d개 고정", scripts, anchored))
