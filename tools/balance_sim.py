"""Tree_deco 밸런스 진행 시뮬레이터 (GAME_RULES.md 초기값 검증용).

플레이어 모델: 하루 SESSION_MIN분 접속해 자동 돌리기를 켜 둔다. 트리에는 가치가
가장 높은 TREE_SLOTS개를 걸고 나머지는 판다. 살 수 있는 업그레이드 중 가장 싼 것을
바로 사고, 다음 업그레이드 비용을 넘는 코인만 코인 룰렛에 쓴다.
시간은 모두 '플레이 시간'(접속 시간 합계) 기준이다.

사용법:
  python3 tools/balance_sim.py                     # 무과금 (하루 40분)
  python3 tools/balance_sim.py '{"BOOST_LUCK":2.25,"BOOST_SPEED":0.72,"SESSION_MIN":120}'  # 과금 (하루 2시간)
  python3 tools/balance_sim.py '{"BOOST_LUCK":2.25,"BOOST_SPEED":0.72,"SESSION_MIN":120,"ROBUX_SPINS_PER_DAY":300}'  # 과금 + 로벅스 룰렛
  NRUNS=500 python3 tools/balance_sim.py           # 반복 횟수 변경
"""
import random, statistics, sys, json

P = dict(
    N=[None, 5, 25, 100, 1500, 12000, 150000],
    VAL=[10, 25, 100, 500, 8000, 100000, 1500000],
    FREE_CD=15.0, REEL=2.0,
    SPEED_COST=[600, 3000, 12000, 40000, 120000],
    SPEED_MULT=[1.0, 0.9, 0.8, 0.7, 0.6, 0.5],
    LUCK_COST=[1500, 6000, 20000, 60000, 160000, 400000, 900000, 2000000, 4500000, 10000000],
    LUCK_MULT=[1.0, 1.2, 1.4, 1.6, 1.9, 2.2, 2.6, 3.0, 3.5, 4.2, 5.0],
    LUCK_CAP=8.0, BOOST_LUCK_CAP=2.0,
    INCOME_RATE=0.001, SELL_RATE=0.25,
    COIN_MIN=60, COIN_INCOME_SEC=90,
    TREE_SLOTS=14,
    POP_BASE=1.0, POP_PER_VOTE=0.01, POP_MAX=3.0, VOTES_RECV_PER_DAY=3,
    DISP_PER_MIN=0.01, DISP_MAX=1.3,
    SESSION_MIN=40, HOURS=80,
    BOOST_LUCK=1.0, BOOST_SPEED=1.0,  # 물약·게임패스 등 상시 부스트 (과금 유저 가정)
    ROBUX_SPINS_PER_DAY=0,  # 하루에 로벅스로 산 룰렛 횟수
)

def probs(L, N):
    p = [0.0] * 7
    for i in range(1, 7):
        p[i] = (1 / N[i]) * (L if i >= 2 else 1)
    p[0] = 1 - sum(p[1:])
    assert p[0] >= 0, L
    return p

def run(P, seed):
    rnd = random.Random(seed)
    t = 0.0; coins = 0.0; tree = []; spd = 0; lk = 0; votes = 0
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
        if L not in pcache: pcache[L] = probs(L, P['N'])
        p = pcache[L]
        sm = P['SPEED_MULT'][spd] * P['BOOST_SPEED']
        cd = P['FREE_CD'] * sm; reel = P['REEL'] * sm
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

def summarize(P, n=int(__import__('os').environ.get('NRUNS', 200))):
    runs = [run(P, s) for s in range(n)]
    keys = ['rare', 'epic', 'legendary', 'speed_max', 'mystic', 'luck_max', 'tree_all_leg', 'secret']
    out = {}
    for k in keys:
        vals = sorted(r[k] for r in runs if k in r)
        reached = len(vals) / n
        if vals:
            out[k] = dict(med=round(statistics.median(vals), 2),
                          p90=round(vals[int(len(vals) * 0.9) - 1 if len(vals) > 1 else 0], 2),
                          reached=round(reached, 2))
        else:
            out[k] = dict(reached=0)
    for h in (20, 30, 40, 60):
        out[f'secret_by_{h}h'] = round(sum(1 for r in runs if r.get('secret', 1e9) <= h) / n, 2)
    for h in (1, 5, 10, 20, 40):
        k = f'ips@{h}h'
        out[k] = statistics.median(r[k] for r in runs if k in r)
    return out

if __name__ == '__main__':
    if len(sys.argv) > 1: P.update(json.loads(sys.argv[1]))
    for k, v in summarize(P).items(): print(k, v)
