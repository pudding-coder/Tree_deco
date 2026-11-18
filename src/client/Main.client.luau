local GachaUI = require(script.Parent.GachaUI)
local TraitAnimator = require(script.Parent.TraitAnimator)

TraitAnimator.Start()
GachaUI.Start()

-- 아래 도구 칸(Backpack)을 숨긴다. 이 게임의 도구는 트리 장식을 잡을 때 생기는 보이지 않는 사본뿐이라
-- 칸이 보이면 눌러서 내려놓거나 다시 들 수 있어 헷갈린다. 나중에 들고 다니는 도구를 넣으면 이 줄을 지운다
game:GetService("StarterGui"):SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false)

-- 트리에 걸린 장식을 잡고 붙어 있을 때 점프하면 놓는다 (서버 TreeService의 holdable)
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local releaseHold = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("ReleaseHold")
UserInputService.JumpRequest:Connect(function()
	local character = Players.LocalPlayer.Character
	if character and character:GetAttribute("HoldingTree") then
		releaseHold:FireServer()
	end
end)

print("[Tree_deco] 클라이언트 시작")
