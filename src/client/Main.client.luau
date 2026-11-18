local GachaUI = require(script.Parent.GachaUI)
local TraitAnimator = require(script.Parent.TraitAnimator)

TraitAnimator.Start()
GachaUI.Start()

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
