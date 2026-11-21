"""원숭이(Monkey) 장식 모델을 만들어 .blend / .fbx 로 저장한다.

큰 머리 + 둥근 귀 + 작은 몸 + 앞으로 모은 두 팔 + 짧은 다리 + 길게 휜 꼬리.
몸은 메타볼(서로 녹아 붙는 공)로 만들어 이음매 없이 매끈하다.
색은 작은 그림(팔레트)으로 구워 FBX에 함께 넣는다. Studio에서 Import 3D로 불러오기만 하면 색이 보인다.
  털(회갈색) · 얼굴과 귀 안쪽(밝은색) · 눈과 입(검정)
앞(얼굴)은 Blender의 -Y 쪽(Front 보기, 숫자패드 1)이고, 내보내면 Roblox의 Front(-Z)가 된다.

실행 (둘 중 하나):
  1) Blender 화면: 위쪽 Scripting 탭 -> Open -> 이 파일 -> Run Script (재생 버튼)
  2) 명령: blender -b -P tools/blender/make_monkey.py -- <저장할 폴더>
출력: <폴더>/Monkey.fbx, Monkey.blend, Monkey_palette.png
     (폴더를 안 주면 내 사용자 폴더의 Tree_deco/assets/models/decorations)
주의: 실행하면 지금 장면의 물체를 모두 지우고 새로 만든다.
"""
import math
import os
import sys

import bpy
from mathutils import Vector

# ---------------------------------------------------------------- 색 (R, G, B) 0~255
PALETTE = {
    "Fur": (176, 166, 152),     # 털
    "Light": (232, 228, 220),   # 얼굴·귀 안쪽
    "Black": (22, 22, 24),      # 눈·입
}

# ---------------------------------------------------------------- 모양 숫자 (바꿔 보면서 다듬기)
HEAD_Z = 2.0          # 머리 가운데 높이
HEAD_W = 1.0          # 머리 가로 반지름
HEAD_D = 0.85         # 머리 앞뒤 반지름
HEAD_H = 0.88         # 머리 세로 반지름
EAR_R = 0.3           # 귀 반지름
EYE_GAP = 0.32        # 두 눈 사이 거리의 절반
EYE_Z = 2.02          # 눈 높이
EYE_R = 0.085         # 눈 크기
MOUTH_Z = 1.8         # 입 높이
MOUTH_W = 0.2         # 입 너비의 절반
TAIL_LEN = 1.0        # 꼬리 길이 배수
DETAIL = 0.06         # 표면 촘촘함 (작을수록 매끈, 대신 무거움)
MAX_TRIS = 14000      # 삼각형 수 상한 (Roblox 메시 한 개 한도 20000보다 작게)

argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
OUT_DIR = os.path.abspath(argv[0]) if argv else os.path.join(
    os.path.expanduser("~"), "Tree_deco", "assets", "models", "decorations")
os.makedirs(OUT_DIR, exist_ok=True)

# ---------------------------------------------------------------- 장면 비우기
for obj in list(bpy.data.objects):
    bpy.data.objects.remove(obj, do_unlink=True)
for coll in (bpy.data.meshes, bpy.data.metaballs, bpy.data.curves, bpy.data.materials, bpy.data.images):
    for item in list(coll):
        if item.users == 0:
            coll.remove(item)
scene = bpy.context.scene

# ---------------------------------------------------------------- 몸: 메타볼
mb = bpy.data.metaballs.new("MonkeyShape")
mb.resolution = DETAIL
mb.render_resolution = DETAIL
mb.threshold = 0.6
shape = bpy.data.objects.new("MonkeyShape", mb)
scene.collection.objects.link(shape)
K = 1.55  # 메타볼 반지름 -> 보이는 반지름 보정


def ball(x, y, z, r, sx=1.0, sy=1.0, sz=1.0):
    el = mb.elements.new(type="ELLIPSOID")
    el.co = (x, y, z)
    el.radius = r * K
    el.size_x, el.size_y, el.size_z = sx, sy, sz
    el.stiffness = 2.0


def chain(points, r0, r1, steps=10):
    """점들을 잇는 굵기가 변하는 관 (팔·다리·꼬리)"""
    total = len(points) - 1
    for seg in range(total):
        a, b = Vector(points[seg]), Vector(points[seg + 1])
        for i in range(steps):
            t = (seg + i / steps) / total
            p = a.lerp(b, i / steps)
            ball(p.x, p.y, p.z, r0 + (r1 - r0) * t)
    p = Vector(points[-1])
    ball(p.x, p.y, p.z, r1)


# 머리 (가로로 살짝 넓은 공)
ball(0, 0, HEAD_Z, 1.0, HEAD_W, HEAD_D, HEAD_H)
# 귀: 머리 양옆, 앞뒤로 납작
for side in (-1, 1):
    ball(side * (HEAD_W + 0.02), 0.05, HEAD_Z + 0.05, EAR_R, 1.0, 0.6, 1.0)
# 몸통
ball(0, 0.05, 1.0, 0.5, 1.0, 0.85, 1.15)
# 팔: 어깨에서 가슴 앞으로 모은다 (오른팔이 조금 더 높다)
chain([(-0.42, 0.0, 1.25), (-0.5, -0.25, 1.15), (-0.32, -0.48, 1.28)], 0.15, 0.17)
chain([(0.42, 0.0, 1.25), (0.52, -0.25, 1.22), (0.33, -0.5, 1.4)], 0.15, 0.17)
# 다리
for side in (-1, 1):
    chain([(side * 0.27, 0.0, 0.6), (side * 0.3, -0.05, 0.25), (side * 0.3, -0.12, 0.13)], 0.19, 0.2, 6)
# 꼬리: 엉덩이에서 뒤·오른쪽으로 나와 위로 휘어 올라간다
L = TAIL_LEN
chain([(0.15, 0.45, 0.75), (0.6, 0.6, 0.65), (1.05 * L, 0.55, 0.85), (1.3 * L, 0.45, 1.3),
       (1.25 * L, 0.35, 1.75 * L)], 0.11, 0.095, 16)

depsgraph = bpy.context.evaluated_depsgraph_get()
body_mesh = bpy.data.meshes.new_from_object(shape.evaluated_get(depsgraph))
bpy.data.objects.remove(shape, do_unlink=True)
bpy.data.metaballs.remove(mb)
body = bpy.data.objects.new("Monkey_Body", body_mesh)
scene.collection.objects.link(body)

tris = sum(len(p.vertices) - 2 for p in body_mesh.polygons)
if tris > MAX_TRIS:
    mod = body.modifiers.new("Decimate", "DECIMATE")
    mod.ratio = MAX_TRIS / tris
    depsgraph = bpy.context.evaluated_depsgraph_get()
    light = bpy.data.meshes.new_from_object(body.evaluated_get(depsgraph))
    body.modifiers.clear()
    old = body.data
    body.data = light
    bpy.data.meshes.remove(old)
    body_mesh = light
body_mesh.name = "Monkey_Body"
body_mesh.polygons.foreach_set("use_smooth", [True] * len(body_mesh.polygons))
body_mesh.update()


def surface_front(x, z):
    """얼굴 앞쪽 겉면의 y (앞에서 뒤로 광선을 쏴서 처음 맞는 곳)"""
    ok, loc, _, _ = body.ray_cast(Vector((x, -5.0, z)), Vector((0, 1, 0)))
    return loc if ok else Vector((x, -HEAD_D, z))


# ---------------------------------------------------------------- 눈: 납작한 검은 공
parts = [body]
for side in (-1, 1):
    hit = surface_front(side * EYE_GAP, EYE_Z)
    bpy.ops.mesh.primitive_uv_sphere_add(segments=16, ring_count=10, radius=EYE_R,
                                         location=(hit.x, hit.y + EYE_R * 0.25, hit.z))
    eye = bpy.context.active_object
    eye.scale = (1.0, 0.5, 1.15)
    eye.name = "Monkey_Eye" + ("L" if side < 0 else "R")
    bpy.ops.object.shade_smooth()
    parts.append(eye)

# ---------------------------------------------------------------- 입: ω 모양 검은 선 (겉면을 따라 휜다)
curve = bpy.data.curves.new("Monkey_Mouth", "CURVE")
curve.dimensions = "3D"
curve.bevel_depth = 0.022
curve.bevel_resolution = 3
spline = curve.splines.new("POLY")
N = 24
spline.points.add(N - 1)
for i in range(N):
    s = i / (N - 1) * 2  # 0~2: 볼록 두 개
    x = -MOUTH_W + s * MOUTH_W
    z = MOUTH_Z - 0.075 * abs(math.sin(math.pi * s)) + 0.02
    hit = surface_front(x, z)
    spline.points[i].co = (hit.x, hit.y + 0.01, hit.z, 1.0)
mouth_curve = bpy.data.objects.new("Monkey_Mouth_curve", curve)
scene.collection.objects.link(mouth_curve)
depsgraph = bpy.context.evaluated_depsgraph_get()
mouth_mesh = bpy.data.meshes.new_from_object(mouth_curve.evaluated_get(depsgraph))
bpy.data.objects.remove(mouth_curve, do_unlink=True)
bpy.data.curves.remove(curve)
mouth = bpy.data.objects.new("Monkey_Mouth", mouth_mesh)
scene.collection.objects.link(mouth)
parts.append(mouth)

# ---------------------------------------------------------------- 색: 팔레트 그림 + 면마다 칸 지정
CELLS = 2  # 2x2칸 (4색까지)
SIZE = 32
names = list(PALETTE)
image = bpy.data.images.new("Monkey_palette", SIZE, SIZE)
pixels = [0.0] * (SIZE * SIZE * 4)
cell = SIZE // CELLS
for i, name in enumerate(names):
    cx, cy = i % CELLS, i // CELLS
    rgb = PALETTE[name]
    for y in range(cy * cell, (cy + 1) * cell):
        for x in range(cx * cell, (cx + 1) * cell):
            j = (y * SIZE + x) * 4
            pixels[j:j + 4] = [c / 255 for c in rgb] + [1.0]
image.pixels = pixels
image.filepath_raw = os.path.join(OUT_DIR, "Monkey_palette.png")
image.file_format = "PNG"
image.save()

material = bpy.data.materials.new("Monkey_Palette")
material.use_nodes = True
nodes = material.node_tree.nodes
tex = nodes.new("ShaderNodeTexImage")
tex.image = image
tex.interpolation = "Closest"  # 칸 경계가 섞이지 않게
bsdf = nodes["Principled BSDF"]
material.node_tree.links.new(tex.outputs["Color"], bsdf.inputs["Base Color"])
bsdf.inputs["Roughness"].default_value = 0.8


def cell_uv(name):
    i = names.index(name)
    return ((i % CELLS + 0.5) / CELLS, (i // CELLS + 0.5) / CELLS)


def body_color(c: Vector) -> str:
    """몸 겉면 한 점의 색: 얼굴(하트 모양 두 덩이 + 아래 볼) · 귀 안쪽은 밝게, 나머지는 털"""
    # 얼굴: 머리 앞쪽에서만
    on_head = ((c.x / (HEAD_W + 0.1)) ** 2 + (c.y / (HEAD_D + 0.1)) ** 2 + ((c.z - HEAD_Z) / (HEAD_H + 0.1)) ** 2) < 1.15
    if on_head and c.y < -0.35 and abs(c.x) < 0.8:
        u, v = c.x, c.z
        lobe = min(((u - s * 0.3) / 0.33) ** 2 + ((v - (EYE_Z + 0.08)) / 0.36) ** 2 for s in (-1, 1))
        cheek = (u / 0.6) ** 2 + ((v - (MOUTH_Z - 0.02)) / 0.3) ** 2
        if lobe < 1 or cheek < 1:
            return "Light"
    # 귀 안쪽: 귀 앞면 가운데
    for side in (-1, 1):
        ex, ez = side * (HEAD_W + 0.02 + EAR_R * 0.25), HEAD_Z + 0.05
        if c.y < -0.02 and side * c.x > HEAD_W - 0.05 and ((c.x - ex) ** 2 + (c.z - ez) ** 2) < (EAR_R * 0.7) ** 2:
            return "Light"
    return "Fur"


for obj in parts:
    mesh = obj.data
    mesh.materials.clear()
    mesh.materials.append(material)
    uv = mesh.uv_layers.new(name="UVMap") if not mesh.uv_layers else mesh.uv_layers[0]
    for poly in mesh.polygons:
        if obj is body:
            name = body_color(obj.matrix_world @ poly.center)
        else:
            name = "Black"
        u, v = cell_uv(name)
        for li in poly.loop_indices:
            uv.data[li].uv = (u, v)

# ---------------------------------------------------------------- 저장
bpy.ops.object.select_all(action="DESELECT")
for obj in parts:
    obj.select_set(True)
bpy.context.view_layer.objects.active = body
total = sum(sum(len(p.vertices) - 2 for p in o.data.polygons) for o in parts)
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(OUT_DIR, "Monkey.blend"))
fbx_path = os.path.join(OUT_DIR, "Monkey.fbx")
bpy.ops.export_scene.fbx(
    filepath=fbx_path,
    use_selection=True,
    axis_forward="-Z",
    axis_up="Y",
    apply_unit_scale=True,
    apply_scale_options="FBX_SCALE_NONE",
    mesh_smooth_type="FACE",
    path_mode="COPY",
    embed_textures=True,  # 팔레트 그림을 FBX 안에 넣는다
    object_types={"MESH"},
)
print(f"[원숭이] 삼각형 {total}개. 저장: {fbx_path}")
