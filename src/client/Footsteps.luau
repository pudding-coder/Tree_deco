-- 발소리: 눈 위를 걸으면 사각사각 눈 발소리로 바꾼다
-- Roblox 기본 걷기 소리(캐릭터 HumanoidRootPart 안의 "Running")의 소리만 바꿔 끼운다. 걷는 속도에 맞춰 빨라지는 건 기본 그대로
-- 눈으로 보는 바닥: 발밑 파트의 재질이 Snow·Glacier이거나, 파트(또는 그 모델)에 속성 Footstep = "Snow"가 붙어 있으면
-- 소리 id는 Config.SNOW_FOOTSTEP_SOUND_ID (비워 두면 기본 소리 그대로)
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

local Footsteps = {}

local SNOW_MATERIALS = {
	[Enum.Material.Snow] = true,
	[Enum.Material.Glacier] = true,
}
local CHECK_INTERVAL = 0.2 -- 발밑을 확인하는 간격(초)

local function isSnow(hit: RaycastResult?): boolean
	if not hit then
		return false
	end
	if SNOW_MATERIALS[hit.Material] then
		return true -- 지형(Terrain)의 눈이나 재질이 Snow인 파트
	end
	local inst = hit.Instance
	while inst and inst ~= workspace do
		if inst:GetAttribute("Footstep") == "Snow" then
			return true
		end
		inst = inst.Parent
	end
	return false
end

local function watch(character: Model)
	local root = character:WaitForChild("HumanoidRootPart", 10)
	if not root then
		return
	end
	local running = root:WaitForChild("Running", 10) -- 기본 캐릭터 소리 스크립트가 만든다
	if not (running and running:IsA("Sound")) then
		return
	end
	local defaultId = running.SoundId
	local defaultVolume = running.Volume
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { character }

	local elapsed = 0
	local onSnow = false
	local connection
	connection = RunService.Heartbeat:Connect(function(dt)
		if not character.Parent or not running.Parent then
			connection:Disconnect()
			return
		end
		elapsed += dt
		if elapsed < CHECK_INTERVAL then
			return
		end
		elapsed = 0
		local hit = workspace:Raycast(root.Position, Vector3.new(0, -6, 0), params)
		local snow = isSnow(hit)
		if snow == onSnow then
			return
		end
		onSnow = snow
		if snow then
			running.SoundId = Config.SNOW_FOOTSTEP_SOUND_ID
			running.Volume = Config.SNOW_FOOTSTEP_VOLUME
		else
			running.SoundId = defaultId
			running.Volume = defaultVolume
		end
	end)
end

function Footsteps.Start()
	if Config.SNOW_FOOTSTEP_SOUND_ID == "" then
		return -- 소리를 정하지 않았으면 기본 발소리 그대로
	end
	local player = Players.LocalPlayer
	player.CharacterAdded:Connect(watch)
	if player.Character then
		task.spawn(watch, player.Character)
	end
end

return Footsteps
