-- 서버와 클라이언트가 함께 쓰는 밸런스 값 (GAME_RULES.md 부록과 같은 값)
local Config = {}

Config.GameName = "Tree_deco"

-- 시작 코인. Studio 테스트에서는 코인 룰렛을 바로 해볼 수 있게 더 준다.
Config.START_COINS = 200 -- 처음 접속할 때 주는 코인 (코인 룰렛 3회)
Config.STUDIO_START_COINS = 1000

-- 룰렛
Config.FREE_SPIN_COOLDOWN = 15 -- 무료 룰렛 쿨타임(초)
Config.REEL_STOP_TIME = 2 -- 슬롯 한 칸이 멈추는 기본 시간(초)
Config.COIN_SPIN_MIN_COST = 60 -- 코인 룰렛 최소 비용 (행운 배수를 곱함)
Config.COIN_SPIN_INCOME_SEC = 90 -- 코인 룰렛 비용 = 몇 초 치 수입인지

-- 행운
Config.LUCK_MIN_RARITY = 3 -- 행운 배수가 적용되는 최소 등급 (레어)
Config.BOOST_LUCK_CAP = 2 -- 물약·게임패스 등 부스트 행운 합계 상한
Config.LUCK_TOTAL_CAP = 8 -- 최종 행운 배수 상한

-- 연출·공지 (등급 번호: 1 커먼 ~ 7 시크릿)
Config.EFFECT_MIN_RARITY = 3 -- 레어 이상: 본인 화면 연출
Config.SERVER_ANNOUNCE_MIN_RARITY = 4 -- 에픽 이상: 서버 전체 공지
Config.GLOBAL_ANNOUNCE_MIN_RARITY = 6 -- 미스틱 이상: 모든 서버 공지

-- 가방
Config.BAG_BASE_SLOTS = 50
Config.BAG_MAX_SLOTS = 500
Config.SELL_RATE = 0.25 -- 판매 가격 = 장식 가치 × SELL_RATE (소수점 버림, 최소 1)
Config.AUTO_SELL_MAX_OPTION = 5 -- 자동 판매로 고를 수 있는 최고 등급 (레전더리)

-- 업그레이드 (0 = 업그레이드 전)
Config.LUCK_MULT = { [0] = 1.0, 1.2, 1.4, 1.6, 1.9, 2.2, 2.6, 3.0, 3.5, 4.2, 5.0 }
Config.SPEED_TIME_MULT = { [0] = 1.0, 0.9, 0.8, 0.7, 0.6, 0.5 }
Config.SPEED_COOLDOWN_MULT = { [0] = 1.0, 0.9, 0.8, 0.7, 0.6, 0.5 }

return Config
