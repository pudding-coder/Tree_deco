-- 이름이 TARGET인 모델 안의 파티클을 모두 눈꽃 설정으로 바꾼다 (양·속도·모양)
local TEXTURE = "rbxassetid://92676423649432" -- 눈꽃 그림 (assets/textures/snowflake.png를 올린 것)
local TARGET = "Snow flakes" -- 파티클이 든 모델 이름
local RATE = 3 -- 1초에 나오는 개수
local SPEED = NumberRange.new(1.5, 3) -- 나오는 속도
local LIFETIME = NumberRange.new(6, 9) -- 떠 있는 시간(초)
local SIZE = 0.5

local roots = {}
for _, inst in workspace:GetDescendants() do
	if inst.Name == TARGET then
		table.insert(roots, inst)
	end
end
print("찾은", TARGET, ":", #roots)
local n = 0
for _, root in roots do
	for _, e in root:GetDescendants() do
		if e:IsA("ParticleEmitter") then
			e.Texture = TEXTURE
			e.Rate = RATE
			e.Speed = SPEED
			e.Lifetime = LIFETIME
			e.Size = NumberSequence.new({
				NumberSequenceKeypoint.new(0, SIZE * 0.6),
				NumberSequenceKeypoint.new(0.2, SIZE),
				NumberSequenceKeypoint.new(1, SIZE * 0.8),
			})
			e.Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 1),
				NumberSequenceKeypoint.new(0.1, 0),
				NumberSequenceKeypoint.new(0.8, 0),
				NumberSequenceKeypoint.new(1, 1),
			})
			e.Color = ColorSequence.new(Color3.new(1, 1, 1))
			e.LightEmission = 0.3
			e.Rotation = NumberRange.new(0, 360)
			e.RotSpeed = NumberRange.new(-30, 30)
			e.Acceleration = Vector3.new(0, -1, 0)
			e.Drag = 0.5
			n += 1
		end
	end
end
print("바꾼 파티클:", n)
