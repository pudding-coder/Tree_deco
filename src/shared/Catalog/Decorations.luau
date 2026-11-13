--[[
	장식 목록 ― 새 장식은 맨 아래(또는 같은 등급 근처)에 한 줄 추가하면 된다.
	자세한 방법: docs/ADDING_ITEMS.md

	id      저장용 이름. 영문으로 시작, 영문·숫자·_만. ★ 한 번 정하면 절대 바꾸지 말 것 (바꾸면 가진 사람 장식이 사라짐)
	name    화면에 보이는 이름. 언제든 바꿔도 된다.
	rarity  "Common" "Uncommon" "Rare" "Epic" "Legendary" "Mystic" "Secret"
	area    "Topper"(꼭대기) "Ornament"(가지에 거는 것) "Garland"(띠)
	weight  (선택) 같은 등급 안에서 나오는 비율. 안 쓰면 1. 2면 다른 장식보다 2배 잘 나온다.
	model   (선택) ReplicatedStorage.DecorationModels 안의 3D 모델 이름. 트리 꾸미기 작업 때 연결.
	retired (선택) true면 더 이상 뽑히지 않는다. 이미 가진 사람은 그대로 갖는다. (삭제 대신 이걸 쓸 것)

	※ 초안: GAME_RULES.md에 확정되기 전 목록이다.
]]

return {
	-- 커먼
	{ id = "PaperStar", name = "종이 별", rarity = "Common", area = "Topper" },
	{ id = "RedBall", name = "빨간 공", rarity = "Common", area = "Ornament" },
	{ id = "GoldBall", name = "금색 공", rarity = "Common", area = "Ornament" },
	{ id = "PineCone", name = "솔방울", rarity = "Common", area = "Ornament" },
	{ id = "CandyCane", name = "사탕지팡이", rarity = "Common", area = "Ornament" },
	{ id = "MiniLights", name = "꼬마전구 줄", rarity = "Common", area = "Garland" },

	-- 언커먼
	{ id = "BigBow", name = "큰 리본", rarity = "Uncommon", area = "Topper" },
	{ id = "Gingerbread", name = "진저브레드맨", rarity = "Uncommon", area = "Ornament" },
	{ id = "Snowman", name = "눈사람", rarity = "Uncommon", area = "Ornament" },
	{ id = "Stocking", name = "크리스마스 양말", rarity = "Uncommon", area = "Ornament" },
	{ id = "Tinsel", name = "반짝이 띠", rarity = "Uncommon", area = "Garland" },

	-- 레어
	{ id = "SantaHat", name = "산타 모자", rarity = "Rare", area = "Topper" },
	{ id = "KeycapKeyring", name = "키캡 키링", rarity = "Rare", area = "Ornament" },
	{ id = "Seullangi", name = "슬랑이", rarity = "Rare", area = "Ornament" }, -- 모양 미정
	{ id = "DubaiCookieKeyring", name = "두바이 쫀득쿠키 키링", rarity = "Rare", area = "Ornament" },
	{ id = "KeycapGarland", name = "키캡 줄", rarity = "Rare", area = "Garland" },

	-- 에픽
	{ id = "Angel", name = "천사", rarity = "Epic", area = "Topper" },
	{ id = "BukangiKeyring", name = "부캉이 키링", rarity = "Epic", area = "Ornament" }, -- 모양 미정
	{ id = "MagpieTigerKeyring", name = "까치호랑이 민화 키링", rarity = "Epic", area = "Ornament" },
	{ id = "BlindBoxMonster", name = "블라인드박스 몬스터 인형", rarity = "Epic", area = "Ornament" },
	{ id = "NeonLights", name = "네온 전구 줄", rarity = "Epic", area = "Garland" },

	-- 레전더리 (브레인롯 캐릭터 이름 사용 여부 미정)
	{ id = "BombardiroTopper", name = "봄바르디로 크로코딜로", rarity = "Legendary", area = "Topper" },
	{ id = "TungSahurKeyring", name = "퉁퉁퉁 사후르 키링", rarity = "Legendary", area = "Ornament" },
	{ id = "TralaleroKeyring", name = "트랄랄레로 트랄랄라 키링", rarity = "Legendary", area = "Ornament" },
	{ id = "BallerinaKeyring", name = "발레리나 카푸치나 키링", rarity = "Legendary", area = "Ornament" },
	{ id = "AuroraRibbon", name = "오로라 리본", rarity = "Legendary", area = "Garland" },

	-- 미스틱
	{ id = "SantaSleigh", name = "산타 썰매", rarity = "Mystic", area = "Topper" },
	{ id = "CrystalSnowflake", name = "크리스탈 눈꽃", rarity = "Mystic", area = "Ornament" },
	{ id = "GoldenKeyboard", name = "황금 키보드 줄", rarity = "Mystic", area = "Garland" },

	-- 시크릿
	{ id = "GiantTungSahur", name = "거대 퉁퉁퉁 사후르", rarity = "Secret", area = "Topper" },
	{ id = "GalaxyOrb", name = "은하수 구슬", rarity = "Secret", area = "Ornament" },
}
