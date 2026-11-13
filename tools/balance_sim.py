"""Tree_deco 밸런스 진행 시뮬레이터.

밸런스 값은 src/shared/Config.luau에서 읽는다. 수치를 바꿀 때는 Config.luau만 고치고
이 스크립트를 다시 돌려 GAME_RULES.md '밸런스 목표'의 목표치와 비교한다.

플레이어 모델: 하루 SESSION_MIN분 접속해 자동 돌리기를 켜 둔다. 트리에는 가치가
가장 높은 장식을 칸 수(MAX_TOPPER + MAX_ORNAMENT + MAX_GARLAND)만큼 걸고 나머지는 판다.
살 수 있는 업그레이드 중 가장 싼 것을 바로 사고, 다음 업그레이드 비용을 넘는 코인만
코인 룰렛에 쓴다. 시간은 모두 '플레이 시간'(접속 시간 합계) 기준이다.

사용법:
  python3 tools/balance_sim.py                    # 4가지 유저 유형을 모두 돌려 표로 출력
  python3 tools/balance_sim.py paid               # 한 유형만 (free / light / paid / paid_robux)
  python3 tools/balance_sim.py paid '{"SESSION_MIN":60}'   # 값을 임시로 덮어써서 실험
  NRUNS=500 python3 tools/balance_sim.py          # 반복 횟수 변경 (기본 300)
"""
import json, multiprocessing, os, random, re, statistics, sys

CONFIG_PATH = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', 'src', 'shared', 'Config.luau')


def _num(text):
    text = text.strip().replace('_', '')
    return float(text) if any(c in text for c in '.eE') else int(text)


def load_config(path=CONFIG_PATH):
    """Config.luau에서 `Config.이름 = 숫자`, `Config.이름 = true/false`, `Config.이름 = { 숫자, ... }` 줄을 읽는다."""
    cfg = {}
    line_re = re.compile(r'^Config\.(\w+)\s*=\s*(.*?)\s*(--.*)?$')
    with open(path, encoding='utf-8') as f:
        for line in f:
            m = line_re.match(line.strip())
            if not m:
                continue
            name, value = m.group(1), m.group(2)
            if value.startswith('"'):
                continue  # 문자열(게임 이름 등)은 밸런스 값이 아니다
            if value in ('true', 'false'):
                cfg[name] = value == 'true'
                continue
            if value.startswith('{'):
                items = [x for x in value.strip('{} ').split(',') if x.strip()]
                cfg[name] = [_num(re.sub(r'^\s*\[0\]\s*=', '', x)) for x in items]
            else:
                cfg[name] = _num(value)
    return cfg


C = load_config()

# 시뮬레이션 전용 값 (게임 수치가 아니라 플레이어 행동 가정)
SIM = dict(
    SESSION_MIN=40,  # 하루 플레이 시간(분)
    HOURS=80,  # 시뮬레이션할 총 플레이 시간
    VOTES_RECV_PER_DAY=3,  # 하루에 받는 투표 수
    BOOST_LUCK=1.0,  # 물약·게임패스 등 상시 행운 부스트
    BOOST_SPEED=1.0,  # 물약·게임패스 등 상시 속도 부스트
    ROBUX_SPINS_PER_DAY=0,  # 하루에 로벅스로 산 룰렛 횟수
)

# 유저 유형. 과금 효과는 Config 값으로 계산한다.
PRESETS = {
    'free': ('무과금 (하루 40분)', {}),
    'light': ('행운 게임패스만 (하루 40분)', dict(BOOST_LUCK=C['GAMEPASS_LUCK_MULT'])),
    'paid': ('과금 (하루 2시간, 게임패스 3개 + 물약 상시)', dict(
        SESSION_MIN=120,
        BOOST_LUCK=C['GAMEPASS_LUCK_MULT'] * C['POTION_LUCK_MULT'],
        BOOST_SPEED=C['GAMEPASS_SPEED_MULT'] * C['POTION_SPEED_MULT'])),
    'paid_robux': ('과금 + 로벅스 룰렛 상한/일', dict(
        SESSION_MIN=120,
        BOOST_LUCK=C['GAMEPASS_LUCK_MULT'] * C['POTION_LUCK_MULT'],
        BOOST_SPEED=C['GAMEPASS_SPEED_MULT'] * C['POTION_SPEED_MULT'],
        ROBUX_SPINS_PER_DAY=C['ROBUX_SPIN_DAILY_LIMIT'])),
}


def build_params(overrides=None):
    P = dict(
        N=[None, C['N_UNCOMMON'], C['N_RARE'], C['N_EPIC'], C['N_LEGENDARY'], C['N_MYSTIC'], C['N_SECRET']],
        VAL=[C['BASE_VALUE_COMMON'], C['BASE_VALUE_UNCOMMON'], C['BASE_VALUE_RARE'], C['BASE_VALUE_EPIC'],
             C['BASE_VALUE_LEGENDARY'], C['BASE_VALUE_MYSTIC'], C['BASE_VALUE_SECRET']],
        FREE_CD=C['FREE_SPIN_COOLDOWN'], REEL=C['REEL_STOP_TIME'],
        SPEED_COST=C['SPEED_COST'], SPEED_TIME_MULT=C['SPEED_TIME_MULT'], SPEED_CD_MULT=C['SPEED_COOLDOWN_MULT'],
        LUCK_COST=C['LUCK_COST'], LUCK_MULT=C['LUCK_MULT'],
        LUCK_MIN_RARITY=C['LUCK_MIN_RARITY'],
        LUCK_CAP=C['LUCK_TOTAL_CAP'], BOOST_LUCK_CAP=C['BOOST_LUCK_CAP'],
        INCOME_RATE=C['INCOME_RATE'], SELL_RATE=C['SELL_RATE'],
        COIN_MIN=C['COIN_SPIN_MIN_COST'], COIN_INCOME_SEC=C['COIN_SPIN_INCOME_SEC'],
        TREE_SLOTS=C['MAX_TOPPER'] + C['MAX_ORNAMENT'] + C['MAX_GARLAND'],
        POP_BASE=C['POP_MULT_BASE'], POP_PER_VOTE=C['POP_PER_VOTE'], POP_MAX=C['POP_MULT_MAX'],
        DISP_PER_MIN=C['DISPLAY_BONUS_PER_MIN'], DISP_MAX=C['DISPLAY_BONUS_MAX'],
        START_COINS=C['START_COINS'],
    )
    P.update(SIM)
    if overrides:
        P.update(overrides)
    assert len(P['LUCK_MULT']) == len(P['LUCK_COST']) + 1, 'LUCK_MULT는 LUCK_COST보다 1개 많아야 한다'
    assert len(P['SPEED_TIME_MULT']) == len(P['SPEED_COST']) + 1, 'SPEED_TIME_MULT는 SPEED_COST보다 1개 많아야 한다'
    return P


def probs(L, N, luck_min):
    p = [0.0] * 7
    for i in range(1, 7):
        p[i] = (1 / N[i]) * (L if i + 1 >= luck_min else 1)
    p[0] = 1 - sum(p[1:])
    assert p[0] >= 0, L
    return p

def run(P, seed):
    rnd = random.Random(seed)
    t = 0.0; coins = float(P["START_COINS"]); tree = []; spd = 0; lk = 0; votes = 0
    session_start = 0.0; next_free = 0.0; bonus = P['ROBUX_SPINS_PER_DAY']
    ev = {}
    pcache = {}
    sess = P['SESSION_MIN'] * 60
    end = P['HOURS'] * 3600
    def mark(k):
        if k not in ev: ev[k] = t / 3600
    while t < end:
        # day boundary
        if t - session_start >= sess:
            session_start = t; votes += P['VOTES_RECV_PER_DAY']; bonus = P['ROBUX_SPINS_PER_DAY']
        L = min(P['LUCK_MULT'][lk] * min(P['BOOST_LUCK'], P['BOOST_LUCK_CAP']), P['LUCK_CAP'])
        if L not in pcache: pcache[L] = probs(L, P['N'], P['LUCK_MIN_RARITY'])
        p = pcache[L]
        cd = P['FREE_CD'] * P['SPEED_CD_MULT'][spd] * P['BOOST_SPEED']
        reel = P['REEL'] * P['SPEED_TIME_MULT'][spd] * P['BOOST_SPEED']
        tv = sum(tree)
        pop = min(P['POP_BASE'] + votes * P['POP_PER_VOTE'], P['POP_MAX'])
        disp = min(1 + (t - session_start) / 60 * P['DISP_PER_MIN'], P['DISP_MAX'])
        ips = tv * pop * disp * P['INCOME_RATE']
        coin_cost = max(P['COIN_MIN'] * L, ips * P['COIN_INCOME_SEC'])
        # upgrades
        nxt = []
        if spd < len(P['SPEED_COST']): nxt.append((P['SPEED_COST'][spd], 's'))
        if lk < len(P['LUCK_COST']): nxt.append((P['LUCK_COST'][lk], 'l'))
        nxt.sort()
        if nxt and coins >= nxt[0][0]:
            coins -= nxt[0][0]
            if nxt[0][1] == 's':
                spd += 1
                if spd == len(P['SPEED_COST']): mark('speed_max')
            else:
                lk += 1
                if lk == len(P['LUCK_COST']): mark('luck_max')
            continue
        reserve = nxt[0][0] if nxt else 0
        if bonus > 0:
            bonus -= 1; dt = reel
        elif t >= next_free:
            next_free = t + cd; dt = reel
        elif coins - reserve >= coin_cost:
            coins -= coin_cost; dt = reel
        else:
            dt = next_free - t
            coins += ips * dt; t += dt
            continue
        # spin
        r = rnd.random(); acc = 0; ra = 0
        for i in range(6, -1, -1):
            acc += p[i]
            if r < acc: ra = i; break
        if ra >= 2: mark('rare')
        if ra >= 3: mark('epic')
        if ra >= 4: mark('legendary')
        if ra >= 5: mark('mystic')
        if ra >= 6: mark('secret')
        v = P['VAL'][ra]
        if len(tree) < P['TREE_SLOTS']:
            tree.append(v); tree.sort()
        elif v > tree[0]:
            coins += tree[0] * P['SELL_RATE']; tree[0] = v; tree.sort()
        else:
            coins += v * P['SELL_RATE']
        if len(tree) == P['TREE_SLOTS'] and tree[0] >= P['VAL'][4]: mark('tree_all_leg')
        coins += ips * dt; t += dt
        for h in (1, 5, 10, 20, 40):
            k = f'ips@{h}h'
            if k not in ev and t >= h * 3600: ev[k] = round(ips, 1)
    return ev

def _run_one(args):
    return run(*args)


def summarize(P, n=None):
    n = n or int(os.environ.get('NRUNS', 300))
    with multiprocessing.Pool() as pool:
        runs = pool.map(_run_one, [(P, s) for s in range(n)])
    keys = ['rare', 'epic', 'legendary', 'speed_max', 'mystic', 'luck_max', 'tree_all_leg', 'secret']
    out = {}
    for k in keys:
        # 도달 못 한 사람은 무한대로 두고 전체 중앙값을 구한다 (절반이 도달하는 시점)
        vals = sorted(r.get(k, float('inf')) for r in runs)
        med = statistics.median_low(vals)
        out[k] = dict(reached=sum(1 for v in vals if v != float('inf')) / n)
        if med != float('inf'):
            out[k]['med'] = med
    for h in (20, 30, 40, 60):
        out[f'secret_by_{h}h'] = sum(1 for r in runs if r.get('secret', 1e9) <= h) / n
    return out


GOALS = [  # (키, 이름, 목표치) — 목표치는 GAME_RULES.md '밸런스 목표'와 같게 유지
    ('rare', '첫 레어', '3~5분'),
    ('epic', '첫 에픽', '15~20분'),
    ('legendary', '첫 레전더리', '2~3시간'),
    ('speed_max', '속도 업그레이드 만렙', '4~5시간'),
    ('mystic', '첫 미스틱', '10~14시간'),
    ('tree_all_leg', '트리 전체 레전더리 이상', '18~20시간'),
    ('luck_max', '행운 업그레이드 만렙', '18~20시간'),
    ('secret', '첫 시크릿 (절반이 뽑는 시점)', '상위 유저 3~4주'),
]


def fmt(res, session_min):
    if 'med' not in res:
        return f'절반 못 도달 ({res["reached"]:.0%} 도달)'
    h = res['med']
    t = f'{h * 60:.0f}분' if h < 1 else f'{h:.1f}시간'
    days = h * 60 / session_min
    if days >= 1:
        t += f' / 약 {days:.0f}일'
    return t


def main(argv):
    names = [a for a in argv if not a.startswith('{')]
    extra = next((json.loads(a) for a in argv if a.startswith('{')), {})
    keys = names or list(PRESETS)
    cols = []
    for k in keys:
        label, ov = PRESETS[k]
        P = build_params({**ov, **extra})
        cols.append((label, P['SESSION_MIN'], summarize(P)))
    n = int(os.environ.get('NRUNS', 300))
    print(f'Config: {os.path.relpath(CONFIG_PATH)} · {n}명 시뮬레이션 중앙값 (플레이 시간 / 달력 기준)\n')
    print('| 목표 | 목표치 | ' + ' | '.join(c[0] for c in cols) + ' |')
    print('| --- | --- | ' + ' | '.join('---' for _ in cols) + ' |')
    for key, label, goal in GOALS:
        print(f'| {label} | {goal} | ' + ' | '.join(fmt(c[2][key], c[1]) for c in cols) + ' |')
    print('| 시크릿 뽑은 비율 (40시간까지) | | ' + ' | '.join(f"{c[2]['secret_by_40h']:.0%}" for c in cols) + ' |')


if __name__ == '__main__':
    main(sys.argv[1:])
