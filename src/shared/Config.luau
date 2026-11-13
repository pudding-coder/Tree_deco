-- 밸런스 값은 모두 이 파일 한 곳에만 둔다. 수치를 바꿀 때는 여기만 고친다.
-- GAME_RULES.md는 규칙과 공식만 설명하고 숫자는 이 파일의 변수 이름으로 가리킨다.
-- tools/balance_sim.py도 이 파일을 읽어서 쓴다 (값을 바꾼 뒤 시뮬레이션으로 확인).
--
-- 작성 규칙 (시뮬레이터가 읽을 수 있게):
--   Config.이름 = 값 -- 설명      (한 줄에 하나, 값은 숫자 또는 { 숫자, ... } 표)
--   [미구현] 표시는 아직 게임 코드에서 쓰지 않는 값이다. 바꿔도 게임에는 아직 반영되지 않는다.
--
-- 등급 번호: 1 커먼 · 2 언커먼 · 3 레어 · 4 에픽 · 5 레전더리 · 6 미스틱 · 7 시크릿
local Config = {}

Config.GameName = "Tree_deco"

----------------------------------------------------------------
-- 시작
----------------------------------------------------------------
Config.START_COINS = 1_000 -- 처음 접속할 때 주는 코인 (속도 업그레이드 1단계 + 코인 룰렛 약 6회. 시뮬레이션상 밸런스 영향 거의 없음)
Config.STUDIO_START_COINS = 1000 -- Studio 테스트용 시작 코인

----------------------------------------------------------------
-- 룰렛
----------------------------------------------------------------
Config.FREE_SPIN_COOLDOWN = 15 -- 무료 룰렛 쿨타임(초)
Config.REEL_STOP_TIME = 5 -- 한 번 돌릴 때 슬롯 3칸(레어도·장식·특성)이 모두 멈추는 기본 시간(초)
Config.COIN_SPIN_MIN_COST = 60 -- 코인 룰렛 최소 비용 (행운 배수를 곱함)
Config.COIN_SPIN_INCOME_SEC = 90 -- 코인 룰렛 비용 = 몇 초 치 수입인지

-- 등급별 확률 = 1 / N. 커먼은 나머지 확률이라 N이 없다.
Config.N_UNCOMMON = 5
Config.N_RARE = 25
Config.N_EPIC = 100
Config.N_LEGENDARY = 1_500
Config.N_MYSTIC = 12_000
Config.N_SECRET = 150_000

-- 등급별 기본 가치(코인) = 장식 가치
Config.BASE_VALUE_COMMON = 10
Config.BASE_VALUE_UNCOMMON = 25
Config.BASE_VALUE_RARE = 100
Config.BASE_VALUE_EPIC = 500
Config.BASE_VALUE_LEGENDARY = 8_000
Config.BASE_VALUE_MYSTIC = 100_000
Config.BASE_VALUE_SECRET = 1_500_000

-- 행운
Config.LUCK_MIN_RARITY = 3 -- 행운 배수가 적용되는 최소 등급 (레어)
Config.BOOST_LUCK_CAP = 2 -- 물약·게임패스 등 부스트 행운 합계 상한 (게임패스 ×1.5 × 물약 ×1.5 = ×2.25를 ×2로 묶음)
Config.LUCK_TOTAL_CAP = 8 -- 최종 행운 배수 상한 (×8일 때 언커먼 이상 합계 약 60%)

-- 연출·공지
Config.EFFECT_MIN_RARITY = 3 -- 이 등급 이상: 본인 화면 연출 (레어)
Config.SERVER_ANNOUNCE_MIN_RARITY = 4 -- 이 등급 이상: 서버 전체 공지 (에픽)
Config.GLOBAL_ANNOUNCE_MIN_RARITY = 6 -- 이 등급 이상: 모든 서버 공지 (미스틱)

----------------------------------------------------------------
-- 가방
----------------------------------------------------------------
Config.BAG_BASE_SLOTS = 50 -- 기본 가방 칸 수 (종류·특성 확정 후 재검토)
Config.BAG_MAX_SLOTS = 500 -- 확장 포함 최대 칸 수 (저장 데이터 크기 제한, 미검증)
Config.BAG_EXPAND_SLOTS = 25 -- [미구현] 확장 1회당 늘어나는 칸 수
Config.BAG_EXPAND_COST_BASE = 5_000 -- [미구현] 첫 코인 확장 비용 (미검증)
Config.BAG_EXPAND_COST_GROWTH = 3 -- [미구현] 확장할 때마다 비용에 곱하는 배수 (미검증)
Config.SELL_RATE = 0.25 -- 판매 가격 = 장식 가치 × SELL_RATE (소수점 버림, 최소 1)
Config.AUTO_SELL_MAX_OPTION = 5 -- 자동 판매로 고를 수 있는 최고 등급 (레전더리)
Config.DEFAULT_LOCK_MIN_RARITY = 5 -- 처음부터 잠겨 있는 최소 등급 (레전더리 이상)
Config.SELL_CONFIRM_MIN_RARITY = 4 -- 모두 판매에 이 등급 이상이 섞이면 한 번 더 눌러야 판다 (에픽)
Config.AUTO_SELL_ONLY_BASE_TRAIT = true -- true면 특성이 붙은 장식(반짝이 등)은 자동 판매하지 않는다

----------------------------------------------------------------
-- 트리·서버
----------------------------------------------------------------
Config.SERVER_MAX_PLAYERS = 8 -- [미구현] 서버당 최대 인원(= 플롯 수). 실제 인원 제한은 Roblox 게임 설정에서도 같이 바꿔야 한다
Config.MAX_TOPPER = 1 -- [미구현] 토퍼 최대 개수
Config.MAX_ORNAMENT = 10 -- [미구현] 오너먼트 최대 개수
Config.MAX_GARLAND = 3 -- [미구현] 띠 최대 개수 (가정)

----------------------------------------------------------------
-- 수익·투표
----------------------------------------------------------------
Config.INCOME_RATE = 0.001 -- [미구현] 트리 가치 대비 초당 수입 비율 (장식 1개가 약 17분에 본전)
Config.POP_MULT_BASE = 1.0 -- [미구현] 투표 0표일 때 인기 배수
Config.POP_PER_VOTE = 0.01 -- [미구현] 1표당 인기 배수 증가량
Config.POP_MULT_MAX = 3.0 -- [미구현] 인기 배수 상한 (0.01씩이면 200표에서 도달)
Config.DISPLAY_BONUS_PER_MIN = 0.01 -- [미구현] 연속 전시 1분당 보너스 증가량
Config.DISPLAY_BONUS_MAX = 1.3 -- [미구현] 전시 시간 보너스 상한 (0.01씩이면 30분에서 도달)
Config.VOTES_PER_DAY = 10 -- [미구현] 1인당 하루 투표권 수
Config.VOTES_PER_TREE_PER_DAY = 1 -- [미구현] 같은 트리에 하루에 줄 수 있는 표 수
Config.VOTE_RESET_HOUR_UTC = 0 -- [미구현] 투표권 초기화 시각 (UTC 시. 0이면 한국 09:00, 미국 서부 16:00)
Config.VOTE_REWARD_MIN = 50 -- [미구현] 투표 1회당 최소 보상 코인 (미검증)
Config.VOTE_REWARD_INCOME_SEC = 30 -- [미구현] 투표 보상 = 몇 초 치 수입인지 (미검증)

----------------------------------------------------------------
-- 업그레이드
-- 단계 수는 COST 표의 길이다. MULT 표는 0단계(업그레이드 전)부터라 COST보다 1개 많다.
----------------------------------------------------------------
Config.LUCK_COST = { 1_500, 6_000, 20_000, 60_000, 160_000, 400_000, 900_000, 2_000_000, 4_500_000, 10_000_000 } -- 행운 단계별 비용
Config.LUCK_MULT = { [0] = 1.0, 1.2, 1.4, 1.6, 1.9, 2.2, 2.6, 3.0, 3.5, 4.2, 5.0 } -- 행운 단계별 배수
Config.SPEED_COST = { 600, 3_000, 12_000, 40_000, 120_000 } -- 속도 단계별 비용
Config.SPEED_TIME_MULT = { [0] = 1.0, 0.9, 0.8, 0.7, 0.6, 0.5 } -- 속도 단계별 회전·멈춤 시간 배수
Config.SPEED_COOLDOWN_MULT = { [0] = 1.0, 0.9, 0.8, 0.7, 0.6, 0.5 } -- 속도 단계별 무료 쿨타임 배수

-- 물약 (코인으로 사든 로벅스로 사든 효과는 같다)
Config.POTION_MIN_COST = 2_000 -- 코인 물약 최소 가격 (미검증)
Config.POTION_COST_INCOME_SEC = 300 -- 코인 물약 가격 = 몇 초 치 수입인지 (미검증)
Config.POTION_DURATION = 600 -- 물약 지속 시간(초). 이미 켜져 있을 때 사면 남은 시간에 더한다
Config.POTION_LUCK_MULT = 1.5 -- 물약 행운 배수 (BOOST_LUCK_CAP 적용)
Config.POTION_SPEED_MULT = 0.85 -- 물약 속도 배수 (시간에 곱함)

----------------------------------------------------------------
-- 로벅스
-- 가격(_PRICE)은 화면 표시·문서용이다. 실제 결제 가격은 Roblox 크리에이터 대시보드에서
-- 게임패스·개발자 상품마다 정하므로, 가격을 바꿀 때는 대시보드와 이 파일을 같이 고친다.
-- 원화는 400 R$ ≈ $4.99, $1 ≈ ₩1,350 기준 (1 R$ ≈ ₩17)
----------------------------------------------------------------
Config.ROBUX_SPIN_DAILY_LIMIT = 300 -- [미구현] 로벅스 룰렛 하루 구매 상한(회). 상한까지 사면 첫 시크릿까지 약 11일
Config.GAMEPASS_LUCK_MULT = 1.5 -- [미구현] 행운 게임패스 행운 배수 (BOOST_LUCK_CAP 적용)
Config.GAMEPASS_SPEED_MULT = 0.85 -- [미구현] 속도 게임패스 속도 배수 (물약과 같이 쓰면 ×0.72)

Config.GAMEPASS_LUCK_PRICE = 199 -- [미구현] 행운 게임패스 (약 ₩3,350)
Config.GAMEPASS_SPEED_PRICE = 99 -- [미구현] 속도 게임패스 (약 ₩1,670)
Config.GAMEPASS_AUTO_PRICE = 149 -- [미구현] 자동 돌리기 게임패스 (약 ₩2,510)
Config.ROBUX_SPIN_50_PRICE = 49 -- [미구현] 룰렛 50회 (약 ₩830)
Config.ROBUX_SPIN_300_PRICE = 249 -- [미구현] 룰렛 300회, 50회 6번보다 약 15% 저렴 (약 ₩4,190)
Config.ROBUX_POTION_1_PRICE = 39 -- [미구현] 물약 1개 (약 ₩660)
Config.ROBUX_POTION_5_PRICE = 149 -- [미구현] 물약 5개, 1개씩보다 약 25% 저렴 (약 ₩2,510)
Config.ROBUX_BAG_EXPAND_PRICE = 49 -- [미구현] 가방 확장 1회 (약 ₩830)

----------------------------------------------------------------
-- 값 확인 (표 길이가 안 맞으면 게임 시작 때 바로 알려준다)
----------------------------------------------------------------
assert(#Config.LUCK_MULT == #Config.LUCK_COST, "LUCK_MULT는 LUCK_COST보다 1개 많아야 한다 (0단계 포함)")
assert(#Config.SPEED_TIME_MULT == #Config.SPEED_COST, "SPEED_TIME_MULT는 SPEED_COST보다 1개 많아야 한다 (0단계 포함)")
assert(#Config.SPEED_COOLDOWN_MULT == #Config.SPEED_COST, "SPEED_COOLDOWN_MULT는 SPEED_COST보다 1개 많아야 한다 (0단계 포함)")

return Config
