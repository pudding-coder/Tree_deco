# 장식 에셋 스타일 시안 그리기: python3 tools/asset_style_sheet.py out.html -> 브라우저로 열기 (규칙: docs/ASSET_RULES.md)
import sys

PALETTE = [
    ("Red", "빨강", (200, 42, 48)),
    ("DeepGreen", "진초록", (30, 112, 62)),
    ("LightGreen", "연초록", (122, 190, 92)),
    ("Navy", "남색", (38, 58, 124)),
    ("SkyBlue", "하늘색", (118, 184, 230)),
    ("Purple", "보라", (132, 82, 172)),
    ("Pink", "분홍", (240, 140, 172)),
    ("Brown", "갈색", (150, 96, 56)),
]
TRIM = "#f6f4ef"
ACCENT_GOLD = "#c49a48"
LEAF = "#2f7d3b"
BERRY = "#c8262c"


def rgb(c):
    return "rgb(%d,%d,%d)" % c


def lerp(c, t, k):
    return tuple(round(a + (b - a) * k) for a, b in zip(c, t))


DEFS = """
<defs>
 <linearGradient id="shade" x1="0" y1="0" x2="0.3" y2="1">
  <stop offset="0" stop-color="#fff" stop-opacity=".45"/>
  <stop offset=".45" stop-color="#fff" stop-opacity="0"/>
  <stop offset="1" stop-color="#000" stop-opacity=".28"/>
 </linearGradient>
 <linearGradient id="goldshade" x1="0" y1="0" x2="0.4" y2="1">
  <stop offset="0" stop-color="#fff" stop-opacity=".75"/>
  <stop offset=".35" stop-color="#fff" stop-opacity="0"/>
  <stop offset=".6" stop-color="#7a4a00" stop-opacity=".1"/>
  <stop offset="1" stop-color="#5a3000" stop-opacity=".45"/>
 </linearGradient>
 <linearGradient id="rainbow" x1="0" y1="0" x2="1" y2="1">
  <stop offset="0" stop-color="#ff4d4d"/><stop offset=".2" stop-color="#ffb23d"/>
  <stop offset=".4" stop-color="#f5f04a"/><stop offset=".6" stop-color="#4ee06a"/>
  <stop offset=".8" stop-color="#4aa8ff"/><stop offset="1" stop-color="#b45cff"/>
 </linearGradient>
 <linearGradient id="frost" x1="0" y1="0" x2="1" y2="1">
  <stop offset="0" stop-color="#fff" stop-opacity=".7"/>
  <stop offset=".5" stop-color="#cfeaff" stop-opacity=".15"/>
  <stop offset="1" stop-color="#9fd0ff" stop-opacity=".35"/>
 </linearGradient>
 <filter id="glow" x="-40%" y="-40%" width="180%" height="180%">
  <feGaussianBlur stdDeviation="7" result="b"/>
  <feMerge><feMergeNode in="b"/><feMergeNode in="SourceGraphic"/></feMerge>
 </filter>
 <filter id="soft" x="-20%" y="-20%" width="140%" height="140%">
  <feDropShadow dx="0" dy="3" stdDeviation="3" flood-opacity=".25"/>
 </filter>
</defs>
"""


def main_fill(main, trait):
    """returns (fill, overlay) for Main parts under a trait"""
    if trait == "Gold":
        return rgb((255, 200, 40)), "url(#goldshade)"
    if trait == "Rainbow":
        return "url(#rainbow)", "url(#shade)"
    if trait == "Aurora":
        return rgb((120, 255, 200)), "url(#shade)"
    if trait == "Frost":
        return rgb(lerp(main, (255, 255, 255), 0.45)), "url(#frost)"
    if trait == "Smoge":
        return rgb(main), "url(#shade)"
    return rgb(main), "url(#shade)"


def shape(d, fill, overlay, extra=""):
    return f'<path d="{d}" fill="{fill}" {extra}/><path d="{d}" fill="{overlay}"/>'


def sparkles(trait):
    if trait in ("Glitter", "Gold", "Aurora"):
        col = "#ffe08a" if trait == "Gold" else "#fffbe0"
        pts = [(40, 50), (165, 70), (150, 175), (55, 160), (110, 30), (175, 125)]
        out = ""
        for x, y in pts:
            out += f'<path d="M{x},{y-9} L{x+2.5},{y-2.5} L{x+9},{y} L{x+2.5},{y+2.5} L{x},{y+9} L{x-2.5},{y+2.5} L{x-9},{y} L{x-2.5},{y-2.5} Z" fill="{col}" stroke="#d9b54a" stroke-width=".6"/>'
        return out
    if trait == "Smoge":
        return ''.join(f'<circle cx="{x}" cy="{y}" r="{r}" fill="#8a8a8a" opacity=".35"/>' for x, y, r in [(50, 60, 16), (68, 48, 12), (160, 150, 18), (145, 168, 12), (170, 60, 10)])
    return ""


def wrap(inner, trait):
    filt = ' filter="url(#glow)"' if trait == "Aurora" else ' filter="url(#soft)"'
    return f'<g{filt}>{inner}</g>{sparkles(trait)}'


def stocking(main, trait="None", mark=None):
    f, o = main_fill(main, trait)
    body = "M72,52 L134,52 L134,118 Q134,146 160,148 Q186,151 186,172 Q186,192 160,192 L98,192 Q72,192 72,166 Z"
    toe = "M152,148 Q186,151 186,172 Q186,192 160,192 L146,192 Q136,170 152,148 Z"
    heel = "M72,158 Q72,192 98,192 L104,192 Q90,176 94,156 Q82,154 72,158 Z"
    cuff = "M62,30 Q62,22 72,22 L134,22 Q144,22 144,30 L144,56 Q138,66 132,56 Q126,68 118,56 Q110,70 102,56 Q94,66 86,56 Q78,68 70,56 Q64,62 62,54 Z"
    s = shape(body, f, o)
    # knit lines on Main (form detail, follows main colour)
    for x in (88, 104, 120):
        s += f'<path d="M{x},62 L{x},{180 if x < 110 else 150}" stroke="#000" stroke-opacity=".12" stroke-width="3" fill="none"/>'
    s += shape(toe, TRIM, "url(#shade)") + shape(heel, TRIM, "url(#shade)") + shape(cuff, TRIM, "url(#shade)")
    # stitches
    for x, y in [(150, 156), (146, 168), (146, 180), (98, 162), (96, 174)]:
        s += f'<rect x="{x-4}" y="{y-1.5}" width="8" height="3" rx="1.5" fill="{TRIM}"/>'
    # holly accent
    s += f'<ellipse cx="94" cy="28" rx="15" ry="7" transform="rotate(-25 94 28)" fill="{LEAF}"/><ellipse cx="118" cy="28" rx="15" ry="7" transform="rotate(25 118 28)" fill="{LEAF}"/>'
    s += f'<path d="M94,28 L118,28" stroke="#1f5a28" stroke-width="1"/>'
    for cx, cy in [(100, 36), (112, 36), (106, 30)]:
        s += f'<circle cx="{cx}" cy="{cy}" r="5.5" fill="{BERRY}"/><circle cx="{cx-1.8}" cy="{cy-2}" r="1.6" fill="#fff" opacity=".7"/>'
    return wrap(s, trait)


def ball(main, trait="None"):
    f, o = main_fill(main, trait)
    s = f'<circle cx="100" cy="118" r="62" fill="{f}"/><circle cx="100" cy="118" r="62" fill="{o}"/>'
    for x, y in [(70, 100), (100, 88), (130, 100), (82, 130), (118, 130), (100, 155), (60, 135), (140, 135)]:
        s += f'<circle cx="{x}" cy="{y}" r="5" fill="{TRIM}"/>'
    s += f'<path d="M58,112 Q100,128 142,112" stroke="{TRIM}" stroke-width="7" fill="none" stroke-linecap="round"/>'
    s += f'<rect x="86" y="46" width="28" height="16" rx="3" fill="{ACCENT_GOLD}"/><rect x="86" y="46" width="28" height="16" rx="3" fill="url(#goldshade)"/>'
    s += f'<circle cx="100" cy="38" r="8" fill="none" stroke="{ACCENT_GOLD}" stroke-width="3.5"/>'
    return wrap(s, trait)


def box(main, trait="None"):
    f, o = main_fill(main, trait)
    front = "M45,85 L135,85 L135,190 L45,190 Z"
    side = "M135,85 L165,65 L165,168 L135,190 Z"
    top = "M45,85 L75,65 L165,65 L135,85 Z"
    s = shape(front, f, o) + shape(side, f, o, 'filter="brightness(.8)"') + f'<path d="{side}" fill="#000" opacity=".18"/>' + shape(top, f, o)
    for x, y in [(60, 105), (82, 125), (60, 150), (82, 172), (118, 105), (118, 150), (100, 182), (148, 100), (152, 140), (100, 76), (130, 72)]:
        s += f'<circle cx="{x}" cy="{y}" r="4.2" fill="{TRIM}"/>'
    # ribbon accent
    s += f'<path d="M84,85 L96,85 L96,190 L84,190 Z" fill="{ACCENT_GOLD}"/><path d="M84,85 L96,85 L96,190 L84,190 Z" fill="url(#goldshade)"/>'
    s += f'<path d="M84,85 L96,85 L126,65 L114,65 Z" fill="{ACCENT_GOLD}"/>'
    s += f'<ellipse cx="88" cy="62" rx="20" ry="11" transform="rotate(-20 88 62)" fill="{ACCENT_GOLD}"/><ellipse cx="122" cy="62" rx="20" ry="11" transform="rotate(20 122 62)" fill="{ACCENT_GOLD}"/>'
    s += f'<ellipse cx="88" cy="62" rx="20" ry="11" transform="rotate(-20 88 62)" fill="url(#goldshade)"/><ellipse cx="122" cy="62" rx="20" ry="11" transform="rotate(20 122 62)" fill="url(#goldshade)"/>'
    s += f'<circle cx="105" cy="70" r="8" fill="{ACCENT_GOLD}"/>'
    return wrap(s, trait)


def star(main, trait="None"):
    import math
    f, o = main_fill(main, trait)
    pts = []
    for i in range(10):
        a = -math.pi / 2 + i * math.pi / 5
        r = 80 if i % 2 == 0 else 36
        pts.append(f"{100 + r*math.cos(a):.1f},{112 + r*math.sin(a):.1f}")
    d = "M" + " L".join(pts) + " Z"
    s = f'<path d="{d}" fill="{f}" stroke="{ACCENT_GOLD}" stroke-width="7" stroke-linejoin="round"/><path d="{d}" fill="{o}"/>'
    for x, y in [(100, 70), (70, 105), (130, 105), (85, 140), (115, 140), (100, 112)]:
        s += f'<circle cx="{x}" cy="{y}" r="5" fill="{TRIM}"/>'
    s += f'<rect x="92" y="186" width="16" height="12" rx="2" fill="{ACCENT_GOLD}"/>'
    return wrap(s, trait)


def cell(svg_inner, label, sub=""):
    return f'''<div class="cell"><svg viewBox="0 0 210 210">{svg_inner}</svg>
<div class="lab">{label}</div><div class="sub">{sub}</div></div>'''


TRAITS = [("None", "기본", "팔레트 색 그대로"), ("Glitter", "반짝이", "색 유지 + 반짝임"),
          ("Frost", "눈꽃", "흰색 45% 섞기, 얼음"), ("Gold", "황금", "금색 고정, 금속"),
          ("Rainbow", "무지개", "네온, 색 순환"), ("Aurora", "오로라", "네온 민트, 빛"),
          ("Smoge", "스모그", "효과 코드 미정")]

red = PALETTE[0][2]
navy = PALETTE[3][2]

rows = []
rows.append(("1. 대표 장식 네 가지 (메인 색 = 빨강, 기본 특성)",
             [cell(ball(red), "공 Ball"), cell(stocking(red), "양말 Stocking"),
              cell(box(red), "선물상자 PresentBox"), cell(star(red), "별 Star")]))

diagram = stocking((210, 70, 200))
diagram += '''
<g font-size="11" font-family="sans-serif" font-weight="700">
<line x1="110" y1="110" x2="200" y2="112" stroke="#222"/><text x="150" y="106" fill="#222">Main</text>
<line x1="70" y1="40" x2="20" y2="20" stroke="#222"/><text x="4" y="16" fill="#222">Trim</text>
<line x1="170" y1="182" x2="200" y2="200" stroke="#222"/><text x="165" y="208" fill="#222">Trim</text>
<line x1="118" y1="28" x2="190" y2="10" stroke="#222"/><text x="150" y="8" fill="#222">Accent</text>
</g>'''
legend = f'''<div class="legend">
<div><b class="sw" style="background:rgb(210,70,200)"></b><b>Main</b> 넓은 몸통. 뽑을 때 정한 랜덤 색 + 특성 효과가 여기에만 들어갑니다.</div>
<div><b class="sw" style="background:{TRIM};border:1px solid #bbb"></b><b>Trim</b> 흰색 고정. 눈, 아이싱, 땡땡이, 바느질.</div>
<div><b class="sw" style="background:{ACCENT_GOLD}"></b><b class="sw" style="background:{LEAF}"></b><b class="sw" style="background:{BERRY}"></b><b>Accent</b> 장식마다 고정. 무광 금, 잎, 열매. 면적 20% 이하.</div>
</div>'''
rows.append(("2. 파츠 나누기 (그림의 분홍 = Main 자리 표시용)", [cell(diagram, "양말 파츠 구분"), legend]))

rows.append(("3. 랜덤 메인 색 팔레트 8색 (양말)",
             [cell(stocking(c), k, f"{rgb(c)[4:-1]}") for _, k, c in PALETTE]))
rows.append(("4. 특성 효과 (메인 색 = 남색 양말, Trim·Accent는 그대로)",
             [cell(stocking(navy, t), k, s) for t, k, s in TRAITS]))
rows.append(("4-1. 같은 특성, 다른 장식 (남색)",
             [cell(fn(navy, t), k) for t, k, _ in TRAITS[2:5] for fn in (ball, box)]))

html = f'''<!doctype html><html><head><meta charset="utf-8"><style>
body{{margin:0;background:#fbf7f0;font-family:'Noto Sans KR','Apple SD Gothic Neo',sans-serif;color:#2a2a2a;width:1400px}}
.wrap{{padding:32px 40px}}
h1{{font-size:30px;margin:0 0 4px}} .lead{{color:#666;margin:0 0 24px;font-size:15px}}
h2{{font-size:18px;margin:26px 0 10px;border-left:5px solid #c8262c;padding-left:10px}}
.row{{display:flex;flex-wrap:wrap;gap:10px;align-items:center}}
.cell{{background:#fff;border-radius:14px;padding:8px 4px 10px;width:138px;text-align:center;box-shadow:0 1px 3px rgba(0,0,0,.08)}}
.cell svg{{width:138px;height:138px}}
.lab{{font-weight:700;font-size:14px}} .sub{{font-size:11px;color:#888;min-height:14px}}
.legend{{font-size:15px;line-height:2.1;max-width:900px}}
.sw{{display:inline-block;width:16px;height:16px;border-radius:4px;vertical-align:-3px;margin-right:4px}}
</style></head><body><svg width="0" height="0" style="position:absolute">{DEFS}</svg><div class="wrap">
<h1>장식 에셋 스타일 시안</h1>
<p class="lead">통통한 실물 소품 느낌, 큰 몸통 + 흰 장식 + 작은 포인트. 몸통 색은 뽑을 때 팔레트 8색 중 하나로 정해집니다.</p>
{''.join(f'<h2>{t}</h2><div class="row">{"".join(c)}</div>' for t, c in rows)}
</div></body></html>'''

open(sys.argv[1], "w").write(html)
