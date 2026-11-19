"""파티클용 눈꽃 그림(흰색, 투명 배경)을 만든다.

실행: python3 tools/make_snowflake.py assets/textures/snowflake.png
Roblox에 올린 뒤 ParticleEmitter.Texture에 rbxassetid://숫자 로 넣는다.
"""
import math
import sys

from PIL import Image, ImageDraw, ImageFilter

SIZE = 256
SCALE = 4  # 크게 그려서 줄이면 선이 매끈하다
out = sys.argv[1] if len(sys.argv) > 1 else "snowflake.png"

big = SIZE * SCALE
c = big / 2
img = Image.new("RGBA", (big, big), (0, 0, 0, 0))
d = ImageDraw.Draw(img)
white = (255, 255, 255, 255)
arm = big * 0.44
w = int(big * 0.035)


def line(a, r0, r1, width, angle_off=0.0, start=None):
    sx, sy = start if start else (c + math.cos(a) * r0, c + math.sin(a) * r0)
    ex, ey = sx + math.cos(a + angle_off) * (r1 - r0), sy + math.sin(a + angle_off) * (r1 - r0)
    d.line([(sx, sy), (ex, ey)], fill=white, width=width)
    d.ellipse([ex - width / 2, ey - width / 2, ex + width / 2, ey + width / 2], fill=white)


for k in range(6):
    a = k * math.pi / 3 - math.pi / 2
    line(a, 0, arm, w)  # 큰 가지
    for t, length in ((0.38, 0.30), (0.66, 0.22)):  # 곁가지 두 쌍
        base = (c + math.cos(a) * arm * t, c + math.sin(a) * arm * t)
        for side in (-1, 1):
            line(a, 0, arm * length, int(w * 0.8), side * math.radians(55), start=base)
    # 끝의 작은 마름모
    tx, ty = c + math.cos(a) * arm, c + math.sin(a) * arm
    s = w * 1.3
    d.polygon([(tx + math.cos(a) * s, ty + math.sin(a) * s), (tx + math.cos(a + 1.57) * s * 0.7, ty + math.sin(a + 1.57) * s * 0.7),
               (tx - math.cos(a) * s, ty - math.sin(a) * s), (tx + math.cos(a - 1.57) * s * 0.7, ty + math.sin(a - 1.57) * s * 0.7)], fill=white)
# 가운데 육각형
r = w * 2.2
d.polygon([(c + math.cos(k * math.pi / 3) * r, c + math.sin(k * math.pi / 3) * r) for k in range(6)], fill=white)

# 은은한 빛번짐을 뒤에 깐다
glow = img.filter(ImageFilter.GaussianBlur(big * 0.02))
alpha = glow.getchannel("A").point(lambda v: int(v * 0.55))
glow.putalpha(alpha)
final = Image.alpha_composite(glow, img).resize((SIZE, SIZE), Image.LANCZOS)
final.save(out)
print("saved", out)
