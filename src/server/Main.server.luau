local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- 장식·특성 목록을 먼저 검사한다. 잘못 적은 곳이 있으면 여기서 Output에 오류가 뜬다.
require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Catalog"))

local PlayerData = require(script.Parent.PlayerData)
local GachaService = require(script.Parent.GachaService)
local BagService = require(script.Parent.BagService)
local UpgradeService = require(script.Parent.UpgradeService)

PlayerData.Init()
GachaService.Init()
BagService.Init()
UpgradeService.Init()

print("[Tree_deco] 서버 시작")
