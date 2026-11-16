# 장식 에셋 스타일 시안 그리기: python3 tools/asset_style_sheet.py out.html -> 브라우저로 열기 (규칙: docs/ASSET_RULES.md)
import sys

PALETTE = [  # src/shared/Catalog/Paints.luau (retired 제외)
    ("Pink", "분홍", (255, 150, 190)),
    ("HotPink", "진분홍", (255, 90, 160)),
    ("Red", "빨강", (230, 60, 60)),
    ("Orange", "주황", (255, 150, 60)),
    ("Yellow", "노랑", (255, 220, 80)),
    ("Mint", "민트", (120, 230, 190)),
    ("Sky", "하늘", (130, 200, 255)),
    ("Blue", "파랑", (70, 120, 230)),
    ("Lavender", "보라", (180, 140, 255)),
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
    """특성은 색을 바꾸지 않는다: Paint 파츠는 항상 칠하기 색"""
    return rgb(main), "url(#shade)"


def shape(d, fill, overlay, extra=""):
    return f'<path d="{d}" fill="{fill}" {extra}/><path d="{d}" fill="{overlay}"/>'


def star4(x, y, r, col):
    return f'<path d="M{x},{y-r} L{x+r*.28},{y-r*.28} L{x+r},{y} L{x+r*.28},{y+r*.28} L{x},{y+r} L{x-r*.28},{y+r*.28} L{x-r},{y} L{x-r*.28},{y-r*.28} Z" fill="{col}"/>'


HALO = {"Frost": ["#ffffff"], "Rainbow": ["#ff5a5a", "#ffdc50", "#5aff8c", "#5aaaff", "#c864ff"],
        "Aurora": ["#78ffc8", "#5aaaff", "#be78ff"]}


def halo(trait):
    """특성 효과 중 장식 뒤에 깔리는 빛 안개"""
    cols = HALO.get(trait)
    if not cols:
        return ""
    stops = "".join(f'<stop offset="{i/(max(len(cols)-1,1)):.2f}" stop-color="{c}"/>' for i, c in enumerate(cols))
    gid = "h" + trait
    return (f'<defs><linearGradient id="{gid}" x1="0" y1="0" x2="1" y2="1">{stops}</linearGradient></defs>'
            f'<ellipse cx="105" cy="110" rx="92" ry="92" fill="url(#{gid})" opacity=".35" filter="url(#glow)"/>')


def sparkles(trait):
    pts = [(40, 50), (165, 70), (150, 175), (55, 160), (110, 30), (175, 125), (30, 110)]
    if trait == "Glitter":
        return "".join(star4(x, y, 8, "#fff6c0") for x, y in pts)
    if trait == "Gold":
        return "".join(star4(x, y, 10, "#ffc81e") for x, y in pts)
    if trait == "Frost":
        out = ""
        for x, y in pts:
            out += f'<g stroke="#bfe4ff" stroke-width="2" stroke-linecap="round"><path d="M{x-7},{y} L{x+7},{y} M{x-3.5},{y-6} L{x+3.5},{y+6} M{x-3.5},{y+6} L{x+3.5},{y-6}"/></g>'
        return out
    if trait == "Smoge":
        return ''.join(f'<circle cx="{x}" cy="{y}" r="{r}" fill="#7a7a80" opacity=".35"/>' for x, y, r in [(50, 60, 18), (68, 44, 13), (160, 150, 20), (145, 170, 13), (172, 58, 12), (40, 140, 14)])
    return ""


def wrap(inner, trait):
    return f'{halo(trait)}<g filter="url(#soft)">{inner}</g>{sparkles(trait)}'


def stocking(main, trait="None", mark=None):
    f, o = main_fill(main, trait)
    body = "M72,52 L134,52 L134,118 Q134,146 160,148 Q186,151 186,172 Q186,192 160,192 L98,192 Q72,192 72,166 Z"
    toe = "M152,148 Q186,151 186,172 Q186,192 160,192 L146,192 Q136,170 152,148 Z"
    heel = "M72,158 Q72,192 98,192 L104,192 Q90,176 94,156 Q82,154 72,158 Z"
    cuff = "M62,30 Q62,22 72,22 L134,22 Q144,22 144,30 L144,56 Q138,66 132,56 Q126,68 118,56 Q110,70 102,56 Q94,66 86,56 Q78,68 70,56 Q64,62 62,54 Z"
    s = shape(body, f, o)
    # knit lines on Paint (form detail, follows main colour)
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


TRAITS = [("None", "기본", "효과 없음"), ("Glitter", "반짝이", "흰·연노랑 반짝임"),
          ("Frost", "눈꽃", "눈송이 + 흰 안개"), ("Gold", "황금", "금색 반짝임"),
          ("Rainbow", "무지개", "무지개 빛 안개"), ("Aurora", "오로라", "초록·파랑·보라 안개"),
          ("Smoge", "스모그", "회색 연기")]

red = PALETTE[2][2]
blue = PALETTE[7][2]

rows = []
rows.append(("1. 대표 장식 네 가지 (칠하기 색 = 빨강, 기본 특성)",
             [cell(ball(red), "공 Ball"), cell(stocking(red), "양말 Stocking"),
              cell(box(red), "선물상자 PresentBox"), cell(star(red), "별 Star")]))

diagram = stocking((210, 70, 200))
diagram += '''
<g font-size="11" font-family="sans-serif" font-weight="700">
<line x1="110" y1="110" x2="200" y2="112" stroke="#222"/><text x="150" y="106" fill="#222">Paint</text>
<line x1="70" y1="40" x2="20" y2="20" stroke="#222"/><text x="4" y="16" fill="#222">흰 장식</text>
<line x1="170" y1="182" x2="200" y2="200" stroke="#222"/><text x="150" y="208" fill="#222">흰 장식</text>
<line x1="118" y1="28" x2="190" y2="10" stroke="#222"/><text x="150" y="8" fill="#222">포인트</text>
</g>'''
legend = f'''<div class="legend">
<div><b class="sw" style="background:rgb(210,70,200)"></b><b>Paint 파츠</b> 이름이 Paint로 시작. 넓은 몸통. 뽑을 때 정한 랜덤 색이 여기에만 칠해집니다 (paintable 장식만).</div>
<div><b class="sw" style="background:{TRIM};border:1px solid #bbb"></b><b>흰 장식</b> 흰색 고정. 눈, 아이싱, 땡땡이, 바느질.</div>
<div><b class="sw" style="background:{ACCENT_GOLD}"></b><b class="sw" style="background:{LEAF}"></b><b class="sw" style="background:{BERRY}"></b><b>포인트</b> 장식마다 고정. 무광 금, 잎, 열매. 면적 20% 이하.</div>
</div>'''
rows.append(("2. 파츠 나누기 (그림의 자주색 = Paint 자리 표시용)", [cell(diagram, "양말 파츠 구분"), legend]))

rows.append(("3. 랜덤 칠하기 색 9색 (Paints.luau, 하양은 뺌)",
             [cell(stocking(c), k, f"{rgb(c)[4:-1]}") for _, k, c in PALETTE]))
rows.append(("4. 특성 효과 (색은 그대로, 주변에 파티클·빛)",
             [cell(stocking(blue, t), k, s) for t, k, s in TRAITS]))

# 5. 띠: 한 칸 조각을 줄을 따라 반복
import math
pts = [(30 + i * 62, 95 + 40 * math.sin(i * 0.9)) for i in range(15)]
wire = "M" + " L".join(f"{x:.0f},{y:.0f}" for x, y in pts)
bulbs = "".join(f'<g transform="translate({x:.0f},{y:.0f})"><rect x="-6" y="-14" width="12" height="8" rx="2" fill="{ACCENT_GOLD}"/><ellipse cx="0" cy="4" rx="11" ry="14" fill="{rgb(red)}"/><ellipse cx="-4" cy="-1" rx="3" ry="5" fill="#fff" opacity=".5"/></g>' for k, (x, y) in enumerate(pts))
garland = f'<div class="wide"><svg viewBox="0 0 920 190"><path d="{wire}" stroke="#1e2d1e" stroke-width="3" fill="none"/>{bulbs}</svg><div class="sub">조각 하나(전구 1개)만 모델로 만들면 게임이 줄을 따라 28곳에 놓고 전선으로 잇습니다.</div></div>'
rows.append(("5. 띠는 한 칸 조각만 만든다", [garland]))

html = f'''<!doctype html><html><head><meta charset="utf-8"><style>
body{{margin:0;background:#fbf7f0;font-family:'Noto Sans KR','Apple SD Gothic Neo',sans-serif;color:#2a2a2a;width:1540px}}
.wrap{{padding:32px 40px}}
h1{{font-size:30px;margin:0 0 4px}} .lead{{color:#666;margin:0 0 24px;font-size:15px}}
h2{{font-size:18px;margin:26px 0 10px;border-left:5px solid #c8262c;padding-left:10px}}
.row{{display:flex;flex-wrap:wrap;gap:10px;align-items:center}}
.cell{{background:#fff;border-radius:14px;padding:8px 4px 10px;width:138px;text-align:center;box-shadow:0 1px 3px rgba(0,0,0,.08)}}
.cell svg{{width:138px;height:138px}}
.lab{{font-weight:700;font-size:14px}} .sub{{font-size:11px;color:#888;min-height:14px}}
.wide{{background:#fff;border-radius:14px;padding:10px;width:940px}} .wide svg{{width:920px}}
.legend{{font-size:15px;line-height:2.1;max-width:900px}}
.sw{{display:inline-block;width:16px;height:16px;border-radius:4px;vertical-align:-3px;margin-right:4px}}
</style></head><body><svg width="0" height="0" style="position:absolute">{DEFS}</svg><div class="wrap">
<h1>장식 에셋 스타일 시안</h1>
<p class="lead">통통한 실물 소품 느낌, 큰 몸통 + 흰 장식 + 작은 포인트. paintable 장식은 뽑을 때 몸통(Paint 파츠) 색이 9색 중 하나로 정해집니다. 특성은 색을 바꾸지 않고 주변에 효과를 냅니다.</p>
{''.join(f'<h2>{t}</h2><div class="row">{"".join(c)}</div>' for t, c in rows)}
</div></body></html>'''

open(sys.argv[1], "w").write(html)
