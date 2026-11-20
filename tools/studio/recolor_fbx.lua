local COLORS = {
	Coal = { 24, 24, 28 }, Cream = { 246, 241, 231 }, Glass = { 192, 231, 255 },
	GlowBlue = { 90, 161, 240 }, GlowGold = { 255, 217, 73 }, GlowGreen = { 121, 231, 191 },
	GlowRed = { 233, 63, 57 }, GlowWarm = { 255, 227, 151 }, Gold = { 255, 217, 73 },
	Green = { 43, 155, 92 }, GreenDark = { 32, 107, 74 }, Iron = { 39, 43, 55 },
	Orange = { 255, 155, 57 }, Potion = { 181, 92, 255 }, Purple = { 139, 92, 240 },
	Red = { 217, 46, 55 }, Snow = { 244, 248, 255 }, Stone = { 142, 128, 135 },
	Wood = { 139, 85, 46 }, WoodDark = { 95, 55, 26 }, WoodLight = { 177, 123, 75 },
}
local roots = game:GetService("Selection"):Get()
if #roots == 0 then
	roots = { workspace }
end
local painted = 0
for _, root in roots do
	local list = root:GetDescendants()
	table.insert(list, root)
	for _, p in list do
		if not p:IsA("BasePart") then
			continue
		end
		local key = string.match(p.Name, "_([%a]+)$") or p.Name
		local rgb = COLORS[key]
		if not rgb then
			continue
		end
		p.Color = Color3.fromRGB(rgb[1], rgb[2], rgb[3])
		if p.Name == "StarPole_GlowGold" then
			-- 별 기둥의 별: Neon이면 면 음영이 사라져 모양이 안 보인다. 금속 느낌 + 불빛으로
			p.Material = Enum.Material.Metal
			if not p:FindFirstChildOfClass("PointLight") then
				local light = Instance.new("PointLight")
				light.Color = p.Color
				light.Range = 20
				light.Brightness = 2
				light.Parent = p
			end
		elseif string.sub(key, 1, 4) == "Glow" then
			p.Material = Enum.Material.Neon
		elseif key == "Glass" then
			p.Material = Enum.Material.Glass
			p.Transparency = 0.4
		else
			p.Material = Enum.Material.SmoothPlastic
		end
		if key == "GlowWarm" and not p:FindFirstChildOfClass("PointLight") then
			local light = Instance.new("PointLight")
			light.Color = p.Color
			light.Range = 14
			light.Brightness = 1.5
			light.Parent = p
		end
		painted += 1
	end
end
print("색을 입힌 파트:", painted)
