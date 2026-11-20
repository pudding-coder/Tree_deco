-- 폴더 안 파트 잠그기/풀기 (잠기면 3D 화면에서 클릭해도 안 집힌다. Explorer에서는 선택 가능)
-- 다시 실행하면 반대로 바뀐다
local FOLDER = "MapWalls" -- MapWalls, MapPaths, PlotSpotPads, Baseplate 등

local folder = workspace:FindFirstChild(FOLDER)
assert(folder, FOLDER .. "가 없습니다")
local first = folder:FindFirstChildWhichIsA("BasePart", true)
local lock = first and not first.Locked
local n = 0
for _, p in folder:GetDescendants() do
	if p:IsA("BasePart") then
		p.Locked = lock
		n += 1
	end
end
print(string.format("%s 파트 %d개를 %s", FOLDER, n, if lock then "잠갔습니다" else "풀었습니다"))
