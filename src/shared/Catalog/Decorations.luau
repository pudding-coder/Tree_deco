--[[
	장식 목록 ― 새 장식은 맨 아래(또는 같은 등급 근처)에 한 줄 추가하면 된다.
	자세한 방법: docs/ADDING_ITEMS.md

	id      저장용 이름. 영문으로 시작, 영문·숫자·_만. (중요) 한 번 정하면 절대 바꾸지 말 것 (바꾸면 가진 사람 장식이 사라짐)
	name    화면에 보이는 이름. 언제든 바꿔도 된다.
	rarity  "Common" "Uncommon" "Rare" "Epic" "Legendary" "Mystic" "Secret"
	area    "Topper"(꼭대기) "Ornament"(가지에 거는 것) "Garland"(띠)
	weight  (선택) 같은 등급 안에서 나오는 비율. 안 쓰면 1. 2면 다른 장식보다 2배 잘 나온다.
	model   (선택) ReplicatedStorage.DecorationModels 안의 3D 모델 이름. 안 쓰면 id와 같은 이름의 모델을 쓴다.
	        모델 이름을 id와 다르게 지었을 때만 적는다.
	size    (선택) 모델 크기 배수. 안 쓰면 1 (오너먼트 2.3 · 토퍼 4스터드에 맞춰진다). 1.3이면 1.3배 크게
	turn    (선택) 모델을 옆으로 돌리는 각도(도). 트리에 걸었을 때 뒤나 옆을 보고 있으면 180, 90, -90 등으로 고친다
	lean    (선택, 오너먼트만) 모델 윗부분을 트리 쪽으로 기울이는 각도(도). 안 쓰면 10. 0이면 똑바로 선다
	out     (선택, 오너먼트만) 트리에 너무 묻히면 바깥으로 띄우는 거리(스터드). 안 쓰면 0. 0.4면 0.4스터드 바깥으로
	sink    (선택, 토퍼만) 모델 높이 중 꼭대기 아래로 내려가는 비율(0~1). 모자·머리처럼 트리에 씌우는 장식에 쓴다.
	        안 쓰면 0 (꼭대기 위에 올라앉음). 단 id가 Hair로 끝나는 토퍼는 안 써도 0.5
	paintable (선택) true면 뽑을 때 Paints.luau의 색이 랜덤으로 정해져 모델의 Paint 파트에 칠해진다.
	        색이 다르면 가방 칸이 따로 생기므로, Paint 파트가 있는 모델에만 켠다.
	retired (선택) true면 더 이상 뽑히지 않는다. 이미 가진 사람은 그대로 갖는다. (삭제 대신 이걸 쓸 것)

	※ 초안: GAME_RULES.md에 확정되기 전 목록이다.
]]

return {
	-- 커먼
	{ id = "Star", name = "별", rarity = "Common", area = "Topper" },
	{ id = "NoobHead", name = "뉴비 머리", rarity = "Common", area = "Topper" },
	{ id = "BrownFloofHair", name = "갈색 푹신한 머리", rarity = "Common", area = "Topper" },



	{ id = "Ball", name = "공", rarity = "Common", area = "Ornament" },
	{ id = "PineCone", name = "솔방울", rarity = "Common", area = "Ornament" },
	{ id = "Fish", name = "물고기", rarity = "Common", area = "Ornament", out = 0.4 },
	{ id = "CandyCane", name = "사탕지팡이", rarity = "Common", area = "Ornament" },
	{ id = "ABCKeycap", name = "ABC 키캡", rarity = "Common", area = "Ornament" },
	{ id = "Crab", name = "게", rarity = "Common", area = "Ornament" },
	{ id = "Noob", name = "로블록스 뉴비 스킨 키링", rarity = "Common", area = "Ornament" },
	{ id = "OctopusGuaSha", name = "문어 괄사", rarity = "Common", area = "Ornament" },
	{ id = "DotPresentBox", name = "도트무늬 선물상자", rarity = "Common", area = "Ornament" },
	{ id = "Fortunepouch", name = "복주머니", rarity = "Common", area = "Ornament" },
	{ id = "Santa", name = "산타", rarity = "Common", area = "Ornament" },
	{ id = "TungSahurKeyring", name = "퉁퉁퉁 사후르 키링", rarity = "Common", area = "Ornament", out = 0.4 },
	{ id = "Snowball", name = "눈뭉치", rarity = "Common", area = "Ornament" },
	{ id = "Snowflake", name = "눈꽃", rarity = "Common", area = "Ornament" },
	{ id = "PresentBox", name = "선물상자", rarity = "Common", area = "Ornament" },
	{ id = "Apple", name = "사과", rarity = "Common", area = "Ornament" },

	{ id = "MiniLights", name = "꼬마전구 줄", rarity = "Common", area = "Garland" },
	{ id = "ExamPaperGarland", name = "시험지 줄", rarity = "Common", area = "Garland" },

	-- 언커먼
	{ id = "Bow", name = "리본", rarity = "Uncommon", area = "Topper" },
	{ id = "IceBingsu", name = "빙수", rarity = "Uncommon", area = "Topper" },

	{ id = "Gingerbread", name = "진저브레드맨", rarity = "Uncommon", area = "Ornament" },
	{ id = "Snowman", name = "눈사람", rarity = "Uncommon", area = "Ornament" },
	{ id = "SadNoob", name = "슬픈 로블록스 뉴비 스킨 키링", rarity = "Uncommon", area = "Ornament" },
	{ id = "Stocking", name = "크리스마스 양말", rarity = "Uncommon", area = "Ornament" },
	{ id = "LuckyFish", name = "액막이 명태", rarity = "Uncommon", area = "Ornament" },
	{ id = "NoEntrySign", name = "관계자 외 출입금지 표지판", rarity = "Uncommon", area = "Ornament" },
	{ id = "EggDog", name = "에그독", rarity = "Uncommon", area = "Ornament" },
	{ id = "PinkStrawberry", name = "핑크 딸기", rarity = "Uncommon", area = "Ornament" },
	{ id = "Donut", name = "도넛", rarity = "Uncommon", area = "Ornament" },

	{ id = "Tinsel", name = "반짝이 띠", rarity = "Uncommon", area = "Garland" },
	{ id = "DonutGarland", name = "도넛 띠", rarity = "Uncommon", area = "Garland" },

	-- 레어
	{ id = "SantaHat", name = "산타 모자", rarity = "Rare", area = "Topper" },
	{ id = "SpinningMaxWellTheCat", name = "빙글빙글 맥스웰", rarity = "Rare", area = "Topper" },


	{ id = "TakeLKeycap", name = "L을 가져가 키캡", rarity = "Rare", area = "Ornament" },
	{ id = "BreadSeullangi", name = "빵 슬랑이", rarity = "Rare", area = "Ornament" }, 
	{ id = "DubaiCookieKeyring", name = "두바이 쫀득쿠키 키링", rarity = "Rare", area = "Ornament" },
	{ id = "HanMochi", name = "한정선 찹쌀떡", rarity = "Rare", area = "Ornament" },
	{ id = "MinecraftZombie", name = "마인크래프트 좀비", rarity = "Rare", area = "Ornament" },
	{ id = "CuteSnowman", name = "귀여운 눈사람", rarity = "Rare", area = "Ornament" },

	{ id = "KeycapGarland", name = "키캡 줄", rarity = "Rare", area = "Garland" },

	-- 에픽
	{ id = "Angel", name = "천사", rarity = "Epic", area = "Topper" },

	{ id = "BukangiKeyring", name = "부캉이 키링", rarity = "Epic", area = "Ornament" },
	{ id = "Brainrot67", name = "67 브래인롯 캐릭터", rarity = "Epic", area = "Ornament" },
	{ id = "EnterKey", name = "Enter키", rarity = "Epic", area = "Ornament" },
	{ id = "BusinessHoursSign", name = "영업 중 표지판", rarity = "Epic", area = "Ornament" },
	{ id = "MinecraftHerobine", name = "마인크래프트 히로빈", rarity = "Epic", area = "Ornament" },

	{ id = "CandyCaneChain", name = "사탕지팡이 줄", rarity = "Epic", area = "Garland" },
	{ id = "NeonLights", name = "네온 전구 줄", rarity = "Epic", area = "Garland" },
	{ id = "CCTVCamera", name = "CCTV 카메라", rarity = "Epic", area = "Garland" },

	-- 레전더리
	{ id = "BombardiroTopper", name = "봄바르디로 크로코딜로", rarity = "Legendary", area = "Topper" },
	{ id = "Poop", name = "똥", rarity = "Legendary", area = "Topper" },

	{ id = "TralaleroKeyring", name = "트랄랄레로 트랄랄라 키링", rarity = "Legendary", area = "Ornament" },
	{ id = "BallerinaKeyring", name = "발레리나 카푸치나 키링", rarity = "Legendary", area = "Ornament" },

	{ id = "AuroraRibbon", name = "오로라 리본", rarity = "Legendary", area = "Garland" },

	-- 미스틱
	{ id = "SantaSleigh", name = "산타 썰매", rarity = "Mystic", area = "Topper" },

	{ id = "CrystalSnowflake", name = "크리스탈 눈꽃", rarity = "Mystic", area = "Ornament" },
	{ id = "SantaWithSleigh", name = "썰매를 탄 산타", rarity = "Mystic", area = "Ornament" },
	{ id = "HeartPresentBox", name = "하트무늬 선물상자", rarity = "Mystic", area = "Ornament" },

	{ id = "GoldenKeyboard", name = "황금 키보드 줄", rarity = "Mystic", area = "Garland" },

	-- 시크릿
	{ id = "GiantTungSahur", name = "거대 퉁퉁퉁 사후르", rarity = "Secret", area = "Topper" },
	
	{ id = "GalaxyOrb", name = "은하수 구슬", rarity = "Secret", area = "Ornament" },
}
