-- 색이 계속 바뀌는 특성 효과(무지개·오로라 빛)를 움직인다 (서버 src/server/TraitEffects.luau가 태그를 붙인다)
-- 화면에서만 바뀌는 색이라 서버와 주고받지 않는다
local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")

local TraitAnimator = {}

local RAINBOW_TAG = "TraitRainbow"
local AURORA_TAG = "TraitAurora"
local UPDATE_INTERVAL = 1 / 20 -- 초당 20번이면 충분히 부드럽다

-- 오로라: 초록 → 파랑 → 보라 → 초록
local AURORA_COLORS = {
	Color3.fromRGB(120, 255, 200),
	Color3.fromRGB(90, 170, 255),
	Color3.fromRGB(190, 120, 255),
}

local function auroraColor(t: number): Color3
	local count = #AURORA_COLORS
	local x = (t % 1) * count
	local i = math.floor(x) + 1
	local nextIndex = i % count + 1
	return AURORA_COLORS[i]:Lerp(AURORA_COLORS[nextIndex], x - math.floor(x))
end

-- 장식마다 시작 위치를 조금씩 달리해서 모두 똑같이 깜빡이지 않게 한다
local function offsetOf(inst: Instance): number
	local p = if inst:IsA("BasePart") then inst.Position elseif inst.Parent and inst.Parent:IsA("BasePart") then (inst.Parent :: BasePart).Position else Vector3.zero
	return (p.X * 0.13 + p.Y * 0.07 + p.Z * 0.11) % 1
end

function TraitAnimator.Start()
	local elapsed = 0
	local clock = 0
	RunService.RenderStepped:Connect(function(dt)
		clock += dt
		elapsed += dt
		if elapsed < UPDATE_INTERVAL then
			return
		end
		elapsed = 0

		for _, inst in CollectionService:GetTagged(RAINBOW_TAG) do
			local color = Color3.fromHSV((clock * 0.25 + offsetOf(inst)) % 1, 0.8, 1)
			if inst:IsA("BasePart") then
				inst.Color = color
			elseif inst:IsA("Light") then
				inst.Color = color
			elseif inst:IsA("Sparkles") then
				inst.SparkleColor = color
			end
		end
		for _, inst in CollectionService:GetTagged(AURORA_TAG) do
			local color = auroraColor(clock * 0.12 + offsetOf(inst))
			if inst:IsA("BasePart") then
				inst.Color = color
			elseif inst:IsA("Light") then
				inst.Color = color
			elseif inst:IsA("Sparkles") then
				inst.SparkleColor = color
			end
		end
	end)
end

return TraitAnimator
