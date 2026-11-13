-- 레어도 7등급. 번호가 클수록 희귀하다.
-- n: 확률 분모 (확률 = 1/n). 커먼은 나머지 확률이라 n이 없다.
-- value: 기본 가치(코인)
-- n과 value는 Config.luau에서 바꾼다. 여기에는 이름과 색만 둔다.
local Config = require(script.Parent.Config)

local Rarity = {}

Rarity.List = {
	{ id = "Common", name = "커먼", n = nil, value = Config.BASE_VALUE_COMMON, color = Color3.fromRGB(190, 196, 205) },
	{ id = "Uncommon", name = "언커먼", n = Config.N_UNCOMMON, value = Config.BASE_VALUE_UNCOMMON, color = Color3.fromRGB(96, 214, 110) },
	{ id = "Rare", name = "레어", n = Config.N_RARE, value = Config.BASE_VALUE_RARE, color = Color3.fromRGB(72, 150, 255) },
	{ id = "Epic", name = "에픽", n = Config.N_EPIC, value = Config.BASE_VALUE_EPIC, color = Color3.fromRGB(178, 96, 255) },
	{ id = "Legendary", name = "레전더리", n = Config.N_LEGENDARY, value = Config.BASE_VALUE_LEGENDARY, color = Color3.fromRGB(255, 176, 40) },
	{ id = "Mystic", name = "미스틱", n = Config.N_MYSTIC, value = Config.BASE_VALUE_MYSTIC, color = Color3.fromRGB(255, 92, 186) },
	{ id = "Secret", name = "시크릿", n = Config.N_SECRET, value = Config.BASE_VALUE_SECRET, color = Color3.fromRGB(255, 60, 60) },
}

Rarity.Count = #Rarity.List

return Rarity
