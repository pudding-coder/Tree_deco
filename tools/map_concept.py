# 맵 분위기 초안 그리기: python3 tools/map_concept.py out.html -> 브라우저로 열기 (약도: docs/MAP_CONCEPT.md)
import math
import random
import sys

random.seed(7)
W, H = 1600, 1000
CX, CY = 800, 560
RX, RY = 600, 345  # 광장 타원
K = RY / RX  # 깊이 압축 비율

out = []  # 배경
items = []  # (정렬용 y, svg)


def P(x, z, h=0):
    """광장 좌표(x 오른쪽, z 앞쪽) -> 화면"""
    return CX + x, CY + z * K - h


def poly(pts, fill, extra=""):
    return f'<polygon points="{" ".join(f"{x:.1f},{y:.1f}" for x, y in pts)}" fill="{fill}" {extra}/>'


def shade(c, k):
    r, g, b = int(c[1:3], 16), int(c[3:5], 16), int(c[5:7], 16)
    f = (lambda v: max(0, min(255, int(v * k)))) if k <= 1 else (lambda v: max(0, min(255, int(v + (255 - v) * (k - 1)))))
    return "#%02x%02x%02x" % (f(r), f(g), f(b))


def tree(sx, sy, s, green="#2f8f57", deco=None, star=False, snow=True):
    """로우폴리 트리: 층마다 밝은 면/어두운 면"""
    g = poly([(sx - 5 * s, sy), (sx + 5 * s, sy), (sx + 4 * s, sy - 12 * s), (sx - 4 * s, sy - 12 * s)], "#6b4428")
    tiers = [(34, 12, 46), (27, 38, 40), (20, 62, 34), (13, 84, 30)]
    for w, y0, hh in tiers:
        top = (sx, sy - (y0 + hh) * s)
        l, r, m = (sx - w * s, sy - y0 * s), (sx + w * s, sy - y0 * s), (sx - w * 0.15 * s, sy - (y0 - 5) * s)
        g += poly([top, l, m], shade(green, 1.18)) + poly([top, m, r], shade(green, 0.78))
        if snow:
            g += poly([top, (sx - w * 0.45 * s, sy - (y0 + hh * 0.42) * s), (sx - w * 0.1 * s, sy - (y0 + hh * 0.5) * s),
                       (sx + w * 0.3 * s, sy - (y0 + hh * 0.5) * s)], "#f4f8ff", 'opacity=".9"')
    if deco:
        rnd = random.Random(int(sx * 13 + sy))
        for w, y0, hh in tiers:
            for i in range(3):
                t = (i + 0.5) / 3 + rnd.uniform(-0.1, 0.1)
                ox = sx + (t * 2 - 1) * w * 0.7 * s
                oy = sy - (y0 + 2 + rnd.uniform(0, 5)) * s
                g += f'<circle cx="{ox:.1f}" cy="{oy:.1f}" r="{3.2*s:.1f}" fill="{rnd.choice(deco)}"/>'
        # 띠
        for w, y0, hh in tiers[:3]:
            g += f'<path d="M{sx-w*0.8*s:.1f},{sy-(y0+10)*s:.1f} Q{sx:.1f},{sy-(y0-2)*s:.1f} {sx+w*0.8*s:.1f},{sy-(y0+12)*s:.1f}" stroke="#ffe9a8" stroke-width="{1.6*s:.1f}" fill="none" stroke-dasharray="1 {5*s:.1f}" stroke-linecap="round"/>'
    if star:
        tx, ty = sx, sy - 118 * s
        pts = []
        for i in range(10):
            a = -math.pi / 2 + i * math.pi / 5
            rr = (11 if i % 2 == 0 else 4.6) * s
            pts.append((tx + rr * math.cos(a), ty + rr * math.sin(a)))
        g += f'<circle cx="{tx}" cy="{ty}" r="{22*s}" fill="url(#glowY)"/>' + poly(pts, "#ffd84a")
    return g


def stall(x, z, w=110, d=46, h=58, face=0, stripe="#d8323a", name="", icon=""):
    """마켓 부스: 나무 몸통 + 줄무늬 차양 + 따뜻한 불빛"""
    sx, sy = P(x, z)
    hw = w / 2
    g = f'<ellipse cx="{sx}" cy="{sy+4}" rx="{hw+18}" ry="{18}" fill="#000" opacity=".22"/>'
    g += poly([(sx - hw, sy), (sx + hw, sy), (sx + hw, sy - h), (sx - hw, sy - h)], "#8a5632")
    g += poly([(sx + hw, sy), (sx + hw + 18, sy - 14), (sx + hw + 18, sy - h - 14), (sx + hw, sy - h)], "#5f3a20")
    # 불 켜진 창
    g += poly([(sx - hw + 10, sy - 22), (sx + hw - 10, sy - 22), (sx + hw - 10, sy - h + 6), (sx - hw + 10, sy - h + 6)], "#ffd27a")
    g += f'<rect x="{sx-hw+10}" y="{sy-h+6}" width="{w-20}" height="{h-28}" fill="url(#glowWin)"/>'
    rnd = random.Random(int(x * 7 + z * 3))
    for i in range(7):  # 진열된 장식
        ox = sx - hw + 18 + i * (w - 36) / 6
        g += f'<circle cx="{ox:.1f}" cy="{sy-h+16+rnd.uniform(0,8):.1f}" r="4" fill="{rnd.choice(["#e8413c","#3aa860","#ffd84a","#5aa0f0","#f08cc0"])}"/>'
    g += poly([(sx - hw - 4, sy - 22), (sx + hw + 4, sy - 22), (sx + hw + 4, sy - 16), (sx - hw - 4, sy - 16)], "#a56a3e")
    # 차양
    n = 8
    for i in range(n):
        x0 = sx - hw - 10 + i * (w + 20) / n
        x1 = x0 + (w + 20) / n
        g += poly([(x0, sy - h + 10), (x1, sy - h + 10), (x1 + 8, sy - h - 16), (x0 + 8, sy - h - 16)], stripe if i % 2 == 0 else "#f6f1e6")
    g += poly([(sx - hw - 2, sy - h - 16), (sx + hw + 18, sy - h - 16), (sx + hw + 30, sy - h - 30), (sx - hw + 14, sy - h - 30)], "#f4f8ff")
    # 전구 줄
    for i in range(9):
        bx = sx - hw - 8 + i * (w + 18) / 8
        g += f'<circle cx="{bx:.1f}" cy="{sy-h+13+3*math.sin(i*1.6):.1f}" r="2.6" fill="#fff1b0"/>'
    # 간판
    if name:
        bw = len(name) * 20 + 22
        g += f'<rect x="{sx-bw/2+6}" y="{sy-h-62}" width="{bw}" height="30" rx="6" fill="#3a2a22"/><text x="{sx+6}" y="{sy-h-40}" text-anchor="middle" font-size="19" font-weight="800" fill="#ffe7a0">{name}</text>'
    ix, iy = sx + 6, sy - h - 86
    if icon == "wheel":
        cols = ["#e8413c", "#ffd84a", "#3aa860", "#5aa0f0", "#f08cc0", "#f6f1e6"]
        for q in range(6):
            a0, a1 = q * math.pi / 3, (q + 1) * math.pi / 3
            g += poly([(ix, iy), (ix + 20 * math.cos(a0), iy + 20 * math.sin(a0)), (ix + 20 * math.cos(a1), iy + 20 * math.sin(a1))], cols[q])
        g += f'<circle cx="{ix}" cy="{iy}" r="4" fill="#3a2a22"/>' + poly([(ix - 5, iy - 26), (ix + 5, iy - 26), (ix, iy - 16)], "#f6f1e6")
    elif icon == "up":
        g += poly([(ix, iy - 24), (ix + 18, iy - 4), (ix + 7, iy - 4), (ix + 7, iy + 16), (ix - 7, iy + 16), (ix - 7, iy - 4), (ix - 18, iy - 4)], "#ffd84a")
    elif icon == "potion":
        g += poly([(ix - 5, iy - 24), (ix + 5, iy - 24), (ix + 5, iy - 12), (ix + 15, iy + 6), (ix + 10, iy + 16), (ix - 10, iy + 16), (ix - 15, iy + 6), (ix - 5, iy - 12)], "#bfe6ff")
        g += poly([(ix + 11, iy), (ix + 15, iy + 6), (ix + 10, iy + 16), (ix - 10, iy + 16), (ix - 15, iy + 6), (ix - 11, iy)], "#b45cff") + f'<rect x="{ix-6}" y="{iy-29}" width="12" height="6" rx="2" fill="#8a5632"/>'
    return (sy, g)


def lamp(x, z, h=70):
    sx, sy = P(x, z)
    g = f'<ellipse cx="{sx}" cy="{sy}" rx="60" ry="{60*K:.0f}" fill="url(#glowGround)"/>'
    g += f'<rect x="{sx-2.5}" y="{sy-h}" width="5" height="{h}" fill="#2b2f3a"/>'
    g += f'<circle cx="{sx}" cy="{sy-h-6}" r="26" fill="url(#glowY)"/>' + poly([(sx - 7, sy - h), (sx + 7, sy - h), (sx + 5, sy - h - 13), (sx - 5, sy - h - 13)], "#ffe7a0")
    return (sy, g)


def person(x, z, coat, hat):
    sx, sy = P(x, z)
    g = f'<ellipse cx="{sx}" cy="{sy}" rx="9" ry="3.5" fill="#000" opacity=".25"/>'
    g += f'<rect x="{sx-6}" y="{sy-20}" width="12" height="16" rx="2" fill="{coat}"/><rect x="{sx-5}" y="{sy-5}" width="4" height="5" fill="#2a2f45"/><rect x="{sx+1}" y="{sy-5}" width="4" height="5" fill="#2a2f45"/>'
    g += f'<rect x="{sx-5}" y="{sy-30}" width="10" height="10" rx="2" fill="#f2c9a0"/><rect x="{sx-6}" y="{sy-33}" width="12" height="5" rx="2" fill="{hat}"/>'
    return (sy, g)


# ---------------------------------------------------------------- 배경
out.append(f'<rect width="{W}" height="{H}" fill="url(#sky)"/>')
for _ in range(140):
    out.append(f'<circle cx="{random.uniform(0,W):.0f}" cy="{random.uniform(0,330):.0f}" r="{random.uniform(.6,1.8):.1f}" fill="#fff" opacity="{random.uniform(.4,1):.2f}"/>')
# 먼 산·언덕 (로우폴리)
for base, col, amp in [(300, "#27365f", 90), (345, "#2f4272", 60)]:
    xs = list(range(-50, W + 100, 110))
    pts = [(x, base - random.uniform(0.2, 1) * amp) for x in xs]
    for (x0, y0), (x1, y1) in zip(pts, pts[1:]):
        out.append(poly([(x0, y0), (x1, y1), (x1, 520), (x0, 520)], shade(col, random.uniform(0.9, 1.15))))
out.append(f'<rect y="330" width="{W}" height="{H-330}" fill="#dfe9f7"/>')
out.append(f'<rect y="330" width="{W}" height="{H-330}" fill="url(#snowShade)"/>')
# 왼쪽 아래 언덕
for (hx, hy, hw, hh, c) in [(120, 880, 330, 190, "#eef4fd"), (330, 960, 300, 150, "#e3ecf9"), (-40, 990, 260, 120, "#f6f9ff")]:
    out.append(poly([(hx - hw, hy + 60), (hx - hw * 0.5, hy - hh * 0.7), (hx, hy - hh), (hx + hw * 0.55, hy - hh * 0.6), (hx + hw, hy + 60)], c))
    out.append(poly([(hx, hy - hh), (hx + hw * 0.55, hy - hh * 0.6), (hx + hw, hy + 60), (hx + hw * 0.2, hy + 60)], shade(c, 0.9), 'opacity=".7"'))

# 광장 바닥
out.append(f'<ellipse cx="{CX}" cy="{CY+14}" rx="{RX+34}" ry="{RY+22}" fill="#b9c6dc"/>')
out.append(f'<ellipse cx="{CX}" cy="{CY}" rx="{RX+30}" ry="{RY+18}" fill="#f2f6fd"/>')  # 눈 쌓인 테두리
out.append(f'<ellipse cx="{CX}" cy="{CY}" rx="{RX}" ry="{RY}" fill="#d3dcee"/>')  # 눈밭
PATH = "#8d7f86"
SPOKES = [-90, 30, 150]  # 가운데 광장에서 나가는 세 갈래 길 (도)
R_IN, R_OUT, R_C, HALF = 0.56 * RX, 0.70 * RX, 215, 36  # 둘레길 안·밖, 가운데 광장 반지름, 길 반폭


def on_path(x, z):
    rr = math.hypot(x, z)
    if rr < R_C or R_IN < rr < R_OUT:
        return True
    if rr < R_IN:
        for a in SPOKES:
            d = abs((math.degrees(math.atan2(z, x)) - a + 180) % 360 - 180)
            if d < 90 and rr * math.sin(math.radians(d)) < HALF:
                return True
    return False


out.append(f'<ellipse cx="{CX}" cy="{CY}" rx="{R_OUT:.0f}" ry="{R_OUT*K:.0f}" fill="{PATH}"/>')
out.append(f'<ellipse cx="{CX}" cy="{CY}" rx="{R_IN:.0f}" ry="{R_IN*K:.0f}" fill="#d3dcee"/>')
for a in SPOKES:
    ca, sa = math.cos(math.radians(a)), math.sin(math.radians(a))
    quad = [P(-sa * HALF, ca * HALF), P(sa * HALF, -ca * HALF), P(ca * R_IN * 1.02 + sa * HALF, sa * R_IN * 1.02 - ca * HALF), P(ca * R_IN * 1.02 - sa * HALF, sa * R_IN * 1.02 + ca * HALF)]
    out.append(poly(quad, PATH))
out.append(f'<ellipse cx="{CX}" cy="{CY}" rx="{R_C}" ry="{R_C*K:.0f}" fill="{PATH}"/>')
n = 0
while n < 620:  # 돌 타일은 길 위에만
    a, rr = random.uniform(0, 2 * math.pi), math.sqrt(random.uniform(0, 1)) * R_OUT
    x, z = rr * math.cos(a), rr * math.sin(a)
    if not on_path(x, z):
        continue
    n += 1
    sx, sy = P(x, z)
    out.append(f'<ellipse cx="{sx:.0f}" cy="{sy:.0f}" rx="{random.uniform(8,15):.0f}" ry="{random.uniform(4,6.5):.0f}" fill="{random.choice(["#9b8c92","#857780","#a3959a","#7c6f79"])}" opacity=".8"/>')
for _ in range(90):  # 눈밭의 얕은 그늘
    a, rr = random.uniform(0, 2 * math.pi), math.sqrt(random.uniform(0, 1)) * RX * 0.97
    x, z = rr * math.cos(a), rr * math.sin(a)
    if on_path(x, z):
        continue
    sx, sy = P(x, z)
    out.append(f'<ellipse cx="{sx:.0f}" cy="{sy:.0f}" rx="{random.uniform(14,30):.0f}" ry="{random.uniform(4,8):.0f}" fill="#f4f8ff" opacity=".7"/>')
out.append(f'<ellipse cx="{CX}" cy="{CY}" rx="{RX}" ry="{RY}" fill="url(#plazaLight)"/>')
out.append(f'<ellipse cx="{CX}" cy="{CY}" rx="150" ry="{150*K:.0f}" fill="#a8565a" opacity=".5"/>')  # 가운데 붉은 바닥
out.append(f'<ellipse cx="{CX}" cy="{CY}" rx="92" ry="{92*K:.0f}" fill="#f1e2c4"/>')  # 스폰 단

# ---------------------------------------------------------------- 숲 (광장 바깥)
for i in range(150):
    a = random.uniform(0, 2 * math.pi)
    r = random.uniform(1.13, 1.75)
    x, z = RX * r * math.cos(a), RX * r * math.sin(a)
    sx, sy = P(x, z)
    if sy < 345 or sx < -40 or sx > W + 40 or sy > H + 80:
        continue
    if sx < 520 and sy > 800:  # 언덕 자리는 비운다
        continue
    if 430 < sx < 1400 and sy > 780:  # 앞쪽 트리 자리를 가리지 않게
        continue
    if abs(sx - CX) < 260 and sy < CY:  # 포토존 자리
        continue
    s = random.uniform(0.75, 1.25) * (0.55 + (sy - 330) / 900)
    items.append((sy, tree(sx, sy, s, green=random.choice(["#2c7a52", "#256b4b", "#318a5a", "#1f5f48"]))))

# ---------------------------------------------------------------- 플롯 (각자의 트리)
DECO = ["#e8413c", "#ffd84a", "#5aa0f0", "#f08cc0", "#f6f1e6", "#ff9a3c", "#78e6be"]
N = 10
for i in range(N):
    a = math.radians(-90 + 360 / N * (i + 0.5))
    x, z = RX * 0.84 * math.cos(a), RX * 0.84 * math.sin(a)
    sx, sy = P(x, z)
    s = 0.62 + (sy - 330) / 1500
    g = f'<ellipse cx="{sx}" cy="{sy}" rx="{78*s}" ry="{78*s*K:.0f}" fill="#000" opacity=".18"/>'
    g += f'<ellipse cx="{sx}" cy="{sy-4}" rx="{72*s}" ry="{72*s*K:.0f}" fill="#7a4a2a"/>'  # 나무 단
    g += f'<ellipse cx="{sx}" cy="{sy-9}" rx="{72*s}" ry="{72*s*K:.0f}" fill="#f4f8ff"/>'  # 눈
    g += f'<ellipse cx="{sx}" cy="{sy-9}" rx="{110*s}" ry="{110*s*K:.0f}" fill="url(#glowGround)"/>'
    # 울타리 전구
    for k in range(14):
        b = k / 14 * 2 * math.pi
        g += f'<circle cx="{sx+72*s*math.cos(b):.1f}" cy="{sy-13+72*s*K*math.sin(b):.1f}" r="{2.6*s:.1f}" fill="{DECO[k%len(DECO)]}"/>'
    g += tree(sx, sy - 10, s * 1.05, green="#2f9a5c", deco=DECO, star=True)
    # 이름표
    g += f'<rect x="{sx-26*s}" y="{sy-150*s}" width="{52*s}" height="{13*s}" rx="{3*s}" fill="#3a2a22" opacity=".85"/><rect x="{sx-20*s}" y="{sy-146*s}" width="{40*s}" height="{4*s}" rx="2" fill="#ffe7a0"/>'
    items.append((sy, g))

# ---------------------------------------------------------------- 가운데: 스폰 + 가게 3곳
items.append(stall(-150, -95, stripe="#2f9a5c", name="업그레이드", icon="up"))
items.append(stall(150, -95, stripe="#8a5cf0", name="물약", icon="potion"))
items.append(stall(0, 150, w=140, stripe="#d8323a", name="룰렛", icon="wheel"))
sx, sy = P(0, 0)
g = f'<ellipse cx="{sx}" cy="{sy}" rx="150" ry="{150*K:.0f}" fill="url(#glowGround)"/>'
g += f'<rect x="{sx-4}" y="{sy-150}" width="8" height="150" fill="#3a2a22"/>'
g += f'<circle cx="{sx}" cy="{sy-165}" r="60" fill="url(#glowY)"/>'
pts = []
for i in range(12):
    a = -math.pi / 2 + i * math.pi / 6
    rr = 30 if i % 2 == 0 else 12
    pts.append((sx + rr * math.cos(a), sy - 165 + rr * math.sin(a)))
g += poly(pts, "#ffd84a") + poly(pts[0:1] + pts[5:8], "#fff3b8", 'opacity=".6"')
items.append((sy, g))
# 가운데 기둥에서 광장 가장자리로 뻗는 전구 줄
lights = ""
for i in range(N):
    a = math.radians(-90 + 360 / N * i)
    ex, ey = P(RX * 0.63 * math.cos(a), RX * 0.63 * math.sin(a), 70)
    mx, my = (sx + ex) / 2, (sy - 150 + ey) / 2 + 55
    lights += f'<path d="M{sx},{sy-150} Q{mx:.0f},{my:.0f} {ex:.0f},{ey:.0f}" stroke="#2b2f3a" stroke-width="1.5" fill="none"/>'
    for t in [j / 10 for j in range(1, 10)]:
        bx = (1 - t) ** 2 * sx + 2 * (1 - t) * t * mx + t * t * ex
        by = (1 - t) ** 2 * (sy - 150) + 2 * (1 - t) * t * my + t * t * ey
        lights += f'<circle cx="{bx:.1f}" cy="{by:.1f}" r="7" fill="url(#glowY)" opacity=".7"/><circle cx="{bx:.1f}" cy="{by:.1f}" r="2.8" fill="#fff1b0"/>'
    items.append(lamp(RX * 0.63 * math.cos(a), RX * 0.63 * math.sin(a)))

# 위쪽 포토존: 전구 아치 + 큰 선물상자 + 눈사람 + 벤치
sx, sy = P(0, -RX * 1.04)
g = f'<ellipse cx="{sx}" cy="{sy+6}" rx="190" ry="34" fill="#f4f8ff"/><ellipse cx="{sx}" cy="{sy+6}" rx="230" ry="46" fill="url(#glowGround)"/>'
g += f'<path d="M{sx-120},{sy} L{sx-120},{sy-50} A120,105 0 0 1 {sx+120},{sy-50} L{sx+120},{sy}" stroke="#256b4b" stroke-width="26" fill="none"/>'
g += f'<path d="M{sx-120},{sy} L{sx-120},{sy-50} A120,105 0 0 1 {sx+120},{sy-50} L{sx+120},{sy}" stroke="#318a5a" stroke-width="12" fill="none"/>'
for i in range(25):
    t = i / 24
    if t < 0.2:
        bx, by = sx - 120, sy - t / 0.2 * 50
    elif t > 0.8:
        bx, by = sx + 120, sy - (1 - t) / 0.2 * 50
    else:
        a = math.pi * (1 - (t - 0.2) / 0.6)
        bx, by = sx + 120 * math.cos(a), sy - 50 - 105 * math.sin(a)
    g += f'<circle cx="{bx:.0f}" cy="{by:.0f}" r="11" fill="url(#glowY)" opacity=".8"/><circle cx="{bx:.0f}" cy="{by:.0f}" r="4.5" fill="{DECO[i%len(DECO)]}"/>'
g += f'<rect x="{sx-62}" y="{sy-192}" width="124" height="38" rx="8" fill="#3a2a22"/><text x="{sx}" y="{sy-165}" text-anchor="middle" font-size="25" font-weight="800" fill="#ffe7a0">포토존</text>'
# 큰 선물상자
for (gx, gw, gh, c) in [(-185, 62, 62, "#d8323a"), (176, 50, 50, "#3a6fd8")]:
    x0 = sx + gx
    g += poly([(x0 - gw / 2, sy + 8), (x0 + gw / 2, sy + 8), (x0 + gw / 2, sy + 8 - gh), (x0 - gw / 2, sy + 8 - gh)], c)
    g += poly([(x0 + gw / 2, sy + 8), (x0 + gw / 2 + 14, sy - 2), (x0 + gw / 2 + 14, sy - 2 - gh), (x0 + gw / 2, sy + 8 - gh)], shade(c, 0.7))
    g += poly([(x0 - gw / 2, sy + 8 - gh), (x0 + gw / 2, sy + 8 - gh), (x0 + gw / 2 + 14, sy - 2 - gh), (x0 - gw / 2 + 14, sy - 2 - gh)], "#f4f8ff")
    g += f'<rect x="{x0-5}" y="{sy+8-gh}" width="10" height="{gh}" fill="#ffd84a"/>'
# 눈사람
mx = sx + 62
g += f'<circle cx="{mx}" cy="{sy-12}" r="24" fill="#fbfdff"/><circle cx="{mx}" cy="{sy-46}" r="17" fill="#fbfdff"/><circle cx="{mx}" cy="{sy-68}" r="12" fill="#fbfdff"/>'
g += f'<rect x="{mx-11}" y="{sy-90}" width="22" height="14" fill="#2b2f3a"/><rect x="{mx-16}" y="{sy-78}" width="32" height="4" fill="#2b2f3a"/><rect x="{mx-14}" y="{sy-60}" width="28" height="6" rx="3" fill="#d8323a"/>'
g += poly([(mx, sy - 68), (mx + 14, sy - 65), (mx, sy - 63)], "#ff9a3c")
# 벤치
g += f'<rect x="{sx-70}" y="{sy-22}" width="90" height="8" rx="2" fill="#a56a3e"/><rect x="{sx-70}" y="{sy-42}" width="90" height="14" rx="2" fill="#8a5632"/><rect x="{sx-64}" y="{sy-14}" width="6" height="16" fill="#5f3a20"/><rect x="{sx+8}" y="{sy-14}" width="6" height="16" fill="#5f3a20"/>'
items.append((sy, g))

# 오른쪽 리더보드
sx, sy = P(RX * 1.12, 40)
g = f'<rect x="{sx-50}" y="{sy-150}" width="8" height="150" fill="#6b4428"/><rect x="{sx+42}" y="{sy-150}" width="8" height="150" fill="#6b4428"/>'
g += f'<rect x="{sx-62}" y="{sy-170}" width="124" height="130" rx="6" fill="#3a2a22"/><rect x="{sx-62}" y="{sy-178}" width="124" height="12" rx="4" fill="#f4f8ff"/>'
for i in range(5):
    g += f'<rect x="{sx-50}" y="{sy-152+i*22}" width="{100-i*12}" height="12" rx="3" fill="{"#ffd84a" if i==0 else "#d9c9a8"}"/>'
items.append((sy, g))

# 사람들
for (x, z, c, h) in [(-60, 60, "#d8323a", "#f6f1e6"), (40, 90, "#3a6fd8", "#d8323a"), (-250, 40, "#2f9a5c", "#ffd84a"), (230, 160, "#f08cc0", "#f6f1e6"),
                     (300, -120, "#ff9a3c", "#3a2a22"), (-330, -150, "#8a6cf0", "#f6f1e6"), (90, -30, "#f6f1e6", "#d8323a"), (-140, 230, "#3aa860", "#d8323a")]:
    items.append(person(x, z, c, h))

items.sort(key=lambda t: t[0])
body = "".join(out) + "".join(g for _, g in items) + lights
snow = "".join(f'<circle cx="{random.uniform(0,W):.0f}" cy="{random.uniform(0,H):.0f}" r="{random.uniform(1.2,3.4):.1f}" fill="#fff" opacity="{random.uniform(.35,.9):.2f}"/>' for _ in range(260))


def label(x, y, t, tx, ty):
    return (f'<line x1="{x}" y1="{y}" x2="{tx}" y2="{ty}" stroke="#fff" stroke-width="1.5" opacity=".8"/><circle cx="{x}" cy="{y}" r="4" fill="#fff"/>'
            f'<rect x="{tx-6}" y="{ty-20}" width="{len(t)*17+14}" height="28" rx="8" fill="#141a33" opacity=".85"/><text x="{tx+1}" y="{ty}" font-size="17" font-weight="700" fill="#fff">{t}</text>')


labels = (label(800, 545, "스폰 (가운데 별 기둥)", 870, 318) + label(640, 440, "가게: 룰렛·업그레이드·물약", 300, 262) + label(1290, 610, "각자의 트리 자리", 1345, 420)
          + label(1470, 480, "리더보드", 1440, 300) + label(180, 800, "눈 언덕", 60, 660) + label(925, 150, "포토존", 1040, 110) + label(250, 470, "숲", 60, 400)
          + label(1000, 660, "세 갈래 길", 1130, 880) + label(480, 690, "트리 구경 둘레길", 330, 905))

svg = f'''<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {W} {H}" width="{W}" height="{H}" font-family="'Noto Sans KR','Apple SD Gothic Neo',sans-serif">
<defs>
<linearGradient id="sky" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#0d1330"/><stop offset=".35" stop-color="#1c2a5c"/><stop offset=".36" stop-color="#1c2a5c"/></linearGradient>
<linearGradient id="snowShade" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#3a4f8a" stop-opacity=".75"/><stop offset="1" stop-color="#6f86bd" stop-opacity=".35"/></linearGradient>
<radialGradient id="plazaLight"><stop offset="0" stop-color="#ffcf7a" stop-opacity=".5"/><stop offset=".6" stop-color="#ffb060" stop-opacity=".18"/><stop offset="1" stop-color="#1c2a5c" stop-opacity=".45"/></radialGradient>
<radialGradient id="glowY"><stop offset="0" stop-color="#fff3b8" stop-opacity=".95"/><stop offset=".4" stop-color="#ffd060" stop-opacity=".45"/><stop offset="1" stop-color="#ffd060" stop-opacity="0"/></radialGradient>
<radialGradient id="glowGround"><stop offset="0" stop-color="#ffd27a" stop-opacity=".5"/><stop offset="1" stop-color="#ffd27a" stop-opacity="0"/></radialGradient>
<linearGradient id="glowWin" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#fff3c0" stop-opacity=".9"/><stop offset="1" stop-color="#ffb347" stop-opacity=".3"/></linearGradient>
</defs>{body}{snow}{labels}
<text x="40" y="60" font-size="34" font-weight="800" fill="#fff">맵 분위기 초안</text>
</svg>'''

open(sys.argv[1], "w").write('<!doctype html><meta charset="utf-8"><body style="margin:0;background:#0d1330">' + svg)
