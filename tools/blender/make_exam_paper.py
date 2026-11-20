"""시험지 줄(ExamPaperGarland) 띠 장식에 다는 모델: 나무 집게에 집힌 시험지 한 장. .blend / .fbx 로 저장한다.

띠 장식은 이 모델을 줄을 따라 여러 개 매단다 (줄에 집게 윗부분이 닿게). src/server/TreeService.luau의 renderGarland.
시험지 앞면 그림(제목·문제 줄·빨간 동그라미·100점)과 색을 그림 한 장에 구워 FBX에 함께 넣는다.
Studio에서 Import 3D로 불러오기만 하면 색이 보인다.
앞(시험지 앞면)은 Blender의 -Y 쪽(Front 보기, 숫자패드 1)이고, 내보내면 Roblox의 Front(-Z)가 된다.

실행 (둘 중 하나):
  1) Blender 화면: 위쪽 Scripting 탭 -> Open -> 이 파일 -> Run Script (재생 버튼)
  2) 명령: blender -b -P tools/blender/make_exam_paper.py -- <저장할 폴더>
출력: <폴더>/ExamPaperGarland.fbx, ExamPaperGarland.blend, ExamPaperGarland_texture.png
     (폴더를 안 주면 내 사용자 폴더의 Tree_deco/assets/models/decorations)
주의: 실행하면 지금 장면의 물체를 모두 지우고 새로 만든다.
"""
import math
import os
import sys

import bpy
import bmesh
from mathutils import Matrix

# ---------------------------------------------------------------- 모양 숫자 (바꿔 보면서 다듬기)
PAPER_W = 1.0         # 종이 너비
PAPER_H = 1.36        # 종이 높이
PAPER_T = 0.012       # 종이 두께
CURL = 0.07           # 종이 양옆이 뒤로 휘는 정도
BOTTOM_CURL = 0.06    # 종이 아래쪽이 앞으로 말리는 정도
PIN_W = 0.13          # 집게 다리 너비
PIN_D = 0.06          # 집게 다리 두께
PIN_H = 0.62          # 집게 길이
PIN_DOWN = 0.26       # 집게가 종이 위 가장자리에서 아래로 내려온 길이 (나머지는 위로 나온다)

# ---------------------------------------------------------------- 색 (R, G, B) 0~255
PAPER = (250, 250, 245)
INK = (70, 70, 78)
INK_LIGHT = (165, 165, 172)
RED = (215, 40, 45)
WOOD = (205, 160, 110)
WOOD_DARK = (150, 108, 68)
METAL = (150, 152, 160)

argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
OUT_DIR = os.path.abspath(argv[0]) if argv else os.path.join(
    os.path.expanduser("~"), "Tree_deco", "assets", "models", "decorations")
os.makedirs(OUT_DIR, exist_ok=True)
NAME = "ExamPaperGarland"

# ---------------------------------------------------------------- 장면 비우기
for obj in list(bpy.data.objects):
    bpy.data.objects.remove(obj, do_unlink=True)
for coll in (bpy.data.meshes, bpy.data.materials, bpy.data.images):
    for item in list(coll):
        if item.users == 0:
            coll.remove(item)
scene = bpy.context.scene

# ---------------------------------------------------------------- 그림 (256x256)
# 왼쪽 192x256: 시험지 앞면 인쇄. 오른쪽 64칸 세로 4칸: 단색 (종이 뒷면 · 나무 · 진한 나무 · 금속)
TEX = 256
PRINT_W = 192
pix = [0.0] * (TEX * TEX * 4)


def put(x, y, rgb):
    if 0 <= x < TEX and 0 <= y < TEX:
        j = (y * TEX + x) * 4
        pix[j:j + 4] = [rgb[0] / 255, rgb[1] / 255, rgb[2] / 255, 1.0]


def rect(x0, y0, x1, y1, rgb):
    for y in range(y0, y1):
        for x in range(x0, x1):
            put(x, y, rgb)


def ring(cx, cy, r, width, rgb):
    for y in range(cy - r - 1, cy + r + 2):
        for x in range(cx - r - 1, cx + r + 2):
            d = math.hypot(x - cx, y - cy)
            if r - width <= d <= r:
                put(x, y, rgb)


DIGITS = {  # 5x7 글꼴 (위에서 아래로)
    "1": ["00100", "01100", "00100", "00100", "00100", "00100", "01110"],
    "0": ["01110", "10001", "10011", "10101", "11001", "10001", "01110"],
}


def text(s, x, y, scale, rgb):
    """y는 글자 맨 아래 줄"""
    for n, ch in enumerate(s):
        rows = DIGITS[ch]
        for r, row in enumerate(rows):
            for c, bit in enumerate(row):
                if bit == "1":
                    rect(x + (n * 6 + c) * scale, y + (6 - r) * scale,
                         x + (n * 6 + c + 1) * scale, y + (7 - r) * scale, rgb)


rect(0, 0, PRINT_W, TEX, PAPER)
# 제목 줄과 그 밑 선
rect(16, 230, 76, 238, INK)
rect(10, 220, PRINT_W - 10, 222, INK)
# 이름 칸
rect(16, 202, 84, 203, INK_LIGHT); rect(16, 213, 84, 214, INK_LIGHT)
rect(16, 202, 17, 214, INK_LIGHT); rect(83, 202, 84, 214, INK_LIGHT)
# 점수: 빨간 100 + 동그라미
text("100", 128, 196, 2, RED)
ring(145, 203, 24, 3, RED)
# 문제 6개: 번호 · 글 줄 두 개 · 빨간 동그라미
lengths = [150, 120, 165, 140, 110, 155]
for q in range(6):
    y = 178 - q * 28
    rect(14, y - 3, 20, y + 3, INK)                # 번호 자리
    rect(28, y - 1, 28 + lengths[q] - 28, y + 2, INK_LIGHT)
    rect(28, y - 10, 28 + int(lengths[q] * 0.6), y - 7, INK_LIGHT)
    ring(17, y, 9, 2, RED)                         # 정답 동그라미

# 오른쪽 단색 칸
SOLIDS = ["Back", "Wood", "WoodDark", "Metal"]
SOLID_RGB = {"Back": PAPER, "Wood": WOOD, "WoodDark": WOOD_DARK, "Metal": METAL}
for i, name in enumerate(SOLIDS):
    rect(PRINT_W, i * 64, TEX, (i + 1) * 64, SOLID_RGB[name])

image = bpy.data.images.new(NAME + "_texture", TEX, TEX)
image.pixels = pix
image.filepath_raw = os.path.join(OUT_DIR, NAME + "_texture.png")
image.file_format = "PNG"
image.save()


def solid_uv(name):
    i = SOLIDS.index(name)
    return ((PRINT_W + 32) / TEX, (i * 64 + 32) / TEX)


material = bpy.data.materials.new(NAME + "_Mat")
material.use_nodes = True
nodes = material.node_tree.nodes
tex = nodes.new("ShaderNodeTexImage")
tex.image = image
bsdf = nodes["Principled BSDF"]
material.node_tree.links.new(tex.outputs["Color"], bsdf.inputs["Base Color"])
bsdf.inputs["Roughness"].default_value = 0.85

# ---------------------------------------------------------------- 시험지: 살짝 휜 얇은 종이 (앞면·뒷면·옆면)
NX, NZ = 10, 12


def paper_point(u, v, back):
    """u, v: 0~1 (왼쪽 아래 0). 앞면은 -Y를 본다"""
    x = (u - 0.5) * PAPER_W
    z = v * PAPER_H
    y = CURL * ((2 * u - 1) ** 2) - BOTTOM_CURL * ((1 - v) ** 3)
    return (x, y + (PAPER_T if back else 0.0), z)


bm = bmesh.new()
uv_layer = bm.loops.layers.uv.new("UVMap")
grid = {}
for side in (0, 1):
    for i in range(NX + 1):
        for k in range(NZ + 1):
            grid[side, i, k] = bm.verts.new(paper_point(i / NX, k / NZ, side == 1))
for i in range(NX):
    for k in range(NZ):
        quad = [(i, k), (i + 1, k), (i + 1, k + 1), (i, k + 1)]
        # 앞면 (앞에서 봤을 때 반시계 = -Y를 본다)
        f = bm.faces.new([grid[0, a, b] for a, b in quad])
        for loop, (a, b) in zip(f.loops, quad):
            loop[uv_layer].uv = (a / NX * PRINT_W / TEX, b / NZ)
        # 뒷면 (순서를 뒤집어 +Y를 본다)
        f = bm.faces.new([grid[1, a, b] for a, b in reversed(quad)])
        for loop in f.loops:
            loop[uv_layer].uv = solid_uv("Back")
# 옆면 (테두리를 막는다)
edge_path = [(i, 0) for i in range(NX)] + [(NX, k) for k in range(NZ)] + \
            [(i, NZ) for i in range(NX, 0, -1)] + [(0, k) for k in range(NZ, 0, -1)]
for n in range(len(edge_path)):
    a, b = edge_path[n], edge_path[(n + 1) % len(edge_path)]
    f = bm.faces.new([grid[(0,) + b], grid[(0,) + a], grid[(1,) + a], grid[(1,) + b]])
    for loop in f.loops:
        loop[uv_layer].uv = solid_uv("Back")
paper_mesh = bpy.data.meshes.new(NAME + "_Paper")
bm.to_mesh(paper_mesh)
bm.free()
paper = bpy.data.objects.new(NAME + "_Paper", paper_mesh)
scene.collection.objects.link(paper)

# ---------------------------------------------------------------- 나무 집게: 다리 두 개 + 가운데 스프링


def box(name, center, size, color, bevel=0.015):
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    for v in bm.verts:
        v.co.x = v.co.x * size[0] + center[0]
        v.co.y = v.co.y * size[1] + center[1]
        v.co.z = v.co.z * size[2] + center[2]
    if bevel > 0:
        bmesh.ops.bevel(bm, geom=list(bm.edges), offset=bevel, segments=2, affect="EDGES")
    uv = bm.loops.layers.uv.new("UVMap")
    for f in bm.faces:
        for loop in f.loops:
            loop[uv].uv = solid_uv(color)
    mesh = bpy.data.meshes.new(name)
    bm.to_mesh(mesh)
    bm.free()
    obj = bpy.data.objects.new(name, mesh)
    scene.collection.objects.link(obj)
    return obj


top = PAPER_H
pin_z = top - PIN_DOWN + PIN_H / 2
front_y = paper_point(0.5, 1.0, False)[1] - PIN_D / 2 - 0.004
back_y = paper_point(0.5, 1.0, True)[1] + PIN_D / 2 + 0.004
pin_front = box(NAME + "_PinFront", (0, front_y, pin_z), (PIN_W, PIN_D, PIN_H), "Wood")
pin_back = box(NAME + "_PinBack", (0, back_y, pin_z), (PIN_W, PIN_D, PIN_H), "Wood")
# 다리 위쪽 홈 (집게 모양이 보이게)
groove = box(NAME + "_Groove", (0, front_y - PIN_D / 2, top + 0.02), (PIN_W * 1.02, 0.012, 0.03), "WoodDark", 0)

# 스프링: 두 다리를 앞뒤로 관통하는 짧은 원통
bm = bmesh.new()
bmesh.ops.create_cone(bm, cap_ends=True, segments=16, radius1=0.05, radius2=0.05,
                      depth=(back_y - front_y) + PIN_D + 0.03)
uv = bm.loops.layers.uv.new("UVMap")
for f in bm.faces:
    for loop in f.loops:
        loop[uv].uv = solid_uv("Metal")
bmesh.ops.rotate(bm, verts=bm.verts, cent=(0, 0, 0),
                 matrix=Matrix.Rotation(math.radians(90), 3, "X"))
bmesh.ops.translate(bm, verts=bm.verts, vec=(0, (front_y + back_y) / 2, top + 0.12))
spring_mesh = bpy.data.meshes.new(NAME + "_Spring")
bm.to_mesh(spring_mesh)
bm.free()
spring = bpy.data.objects.new(NAME + "_Spring", spring_mesh)
scene.collection.objects.link(spring)

parts = [paper, pin_front, pin_back, groove, spring]
for obj in parts:
    obj.data.materials.append(material)

# ---------------------------------------------------------------- 저장
bpy.ops.object.select_all(action="DESELECT")
for obj in parts:
    obj.select_set(True)
bpy.context.view_layer.objects.active = paper
total = sum(sum(len(p.vertices) - 2 for p in o.data.polygons) for o in parts)
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(OUT_DIR, NAME + ".blend"))
fbx_path = os.path.join(OUT_DIR, NAME + ".fbx")
bpy.ops.export_scene.fbx(
    filepath=fbx_path,
    use_selection=True,
    axis_forward="-Z",
    axis_up="Y",
    apply_unit_scale=True,
    apply_scale_options="FBX_SCALE_NONE",
    mesh_smooth_type="FACE",
    path_mode="COPY",
    embed_textures=True,  # 그림을 FBX 안에 넣는다
    object_types={"MESH"},
)
print(f"[시험지] 삼각형 {total}개. 저장: {fbx_path}")
