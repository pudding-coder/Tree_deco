-- 레어도 7등급. 번호가 클수록 희귀하다.
-- n: 확률 분모 (확률 = 1/n). 커먼은 나머지 확률이라 n이 없다.
-- value: 기본 가치(코인)
local Rarity = {}

Rarity.List = {
	{ id = "Common", name = "커먼", n = nil, value = 10, color = Color3.fromRGB(190, 196, 205) },
	{ id = "Uncommon", name = "언커먼", n = 5, value = 25, color = Color3.fromRGB(96, 214, 110) },
	{ id = "Rare", name = "레어", n = 25, value = 100, color = Color3.fromRGB(72, 150, 255) },
	{ id = "Epic", name = "에픽", n = 100, value = 500, color = Color3.fromRGB(178, 96, 255) },
	{ id = "Legendary", name = "레전더리", n = 1500, value = 8000, color = Color3.fromRGB(255, 176, 40) },
	{ id = "Mystic", name = "미스틱", n = 12000, value = 100000, color = Color3.fromRGB(255, 92, 186) },
	{ id = "Secret", name = "시크릿", n = 150000, value = 1500000, color = Color3.fromRGB(255, 60, 60) },
}

Rarity.Count = #Rarity.List

return Rarity
