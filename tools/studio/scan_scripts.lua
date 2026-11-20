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
