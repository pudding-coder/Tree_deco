"""크리스마스 링 도넛(ChristmasRingDonut) 장식 모델을 만들어 .blend / .fbx 로 저장한다.

노릇한 도넛 + 앞면을 덮은 초록 아이싱(진한 초록 점, 가장자리 물결) + 흰 아이싱 지그재그 + 빨간 크랜베리 조각.
트리에 세워서 거는 장식이라 도넛 구멍이 앞(-Y)을 보게 세워 만든다.
색은 작은 그림(팔레트)으로 구워 FBX에 함께 넣는다. Studio에서 Import 3D로 불러오기만 하면 색이 보인다.
앞(아이싱 면)은 Blender의 -Y 쪽(Front 보기, 숫자패드 1)이고, 내보내면 Roblox의 Front(-Z)가 된다.

실행 (둘 중 하나):
  1) Blender 화면: 위쪽 Scripting 탭 -> Open -> 이 파일 -> Run Script (재생 버튼)
  2) 명령: blender -b -P tools/blender/make_christmas_donut.py -- <저장할 폴더>
출력: <폴더>/ChristmasRingDonut.fbx, ChristmasRingDonut.blend, ChristmasRingDonut_palette.png
     (폴더를 안 주면 내 사용자 폴더의 Tree_deco/assets/models/decorations)
주의: 실행하면 지금 장면의 물체를 모두 지우고 새로 만든다.
"""
import math
import os
import random
import sys

import bpy
import bmesh
from mathutils import Euler, Vector

# ---------------------------------------------------------------- 색 (R, G, B) 0~255
PALETTE = {
    "Dough": (214, 160, 98),      # 도넛 빵
    "Green": (78, 140, 70),       # 초록 아이싱
    "GreenDark": (38, 88, 44),    # 아이싱 속 진한 초록 점
    "White": (246, 244, 236),     # 흰 아이싱
    "Red": (176, 30, 48),         # 크랜베리
}

# ---------------------------------------------------------------- 모양 숫자 (바꿔 보면서 다듬기)
RING_R = 1.0          # 도넛 가운데 원의 반지름 (구멍 가운데에서 빵 가운데까지)
TUBE_R = 0.45         # 빵 굵기 (반지름)
TUBE_FLAT = 0.78      # 앞뒤로 납작한 정도 (1 = 동그란 관)
ICING_COVER = 62      # 초록 아이싱이 앞면 가운데에서 덮는 각도(도). 클수록 옆까지 덮는다
ICING_WAVE = 14       # 아이싱 가장자리 물결 깊이(도)
ICING_LIFT = 0.04     # 아이싱 두께
SPECKLE = 0.2         # 아이싱 중 진한 초록 점 비율
DRIZZLE_ZIGS = 16     # 흰 아이싱 지그재그 수
BERRIES = 22          # 크랜베리 조각 수
SEED = 7              # 난수 (바꾸면 점·크랜베리 자리가 달라진다)
NU, NV = 84, 28       # 도넛을 이루는 칸 수 (둘레, 관)

argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
OUT_DIR = os.path.abspath(argv[0]) if argv else os.path.join(
    os.path.expanduser("~"), "Tree_deco", "assets", "models", "decorations")
os.makedirs(OUT_DIR, exist_ok=True)
NAME = "ChristmasRingDonut"
rng = random.Random(SEED)

# ---------------------------------------------------------------- 장면 비우기
for obj in list(bpy.data.objects):
    bpy.data.objects.remove(obj, do_unlink=True)
for coll in (bpy.data.meshes, bpy.data.curves, bpy.data.materials, bpy.data.images):
    for item in list(coll):
        if item.users == 0:
            coll.remove(item)
scene = bpy.context.scene

# ---------------------------------------------------------------- 색 그림 (3x3칸)
CELLS = 3
SIZE = 48
names = list(PALETTE)
image = bpy.data.images.new(NAME + "_palette", SIZE, SIZE)
pixels = [0.0] * (SIZE * SIZE * 4)
cell = SIZE // CELLS
for i, name in enumerate(names):
    cx, cy = i % CELLS, i // CELLS
    for y in range(cy * cell, (cy + 1) * cell):
        for x in range(cx * cell, (cx + 1) * cell):
            j = (y * SIZE + x) * 4
            pixels[j:j + 4] = [c / 255 for c in PALETTE[name]] + [1.0]
image.pixels = pixels
image.filepath_raw = os.path.join(OUT_DIR, NAME + "_palette.png")
image.file_format = "PNG"
image.save()

material = bpy.data.materials.new(NAME + "_Palette")
material.use_nodes = True
nodes = material.node_tree.nodes
tex = nodes.new("ShaderNodeTexImage")
tex.image = image
tex.interpolation = "Closest"
bsdf = nodes["Principled BSDF"]
material.node_tree.links.new(tex.outputs["Color"], bsdf.inputs["Base Color"])
bsdf.inputs["Roughness"].default_value = 0.6


def cell_uv(name):
    i = names.index(name)
    return ((i % CELLS + 0.5) / CELLS, (i // CELLS + 0.5) / CELLS)


def paint_all(mesh, name):
    uv = mesh.uv_layers.new(name="UVMap") if not mesh.uv_layers else mesh.uv_layers[0]
    u, v = cell_uv(name)
    for loop in mesh.loops:
        uv.data[loop.index].uv = (u, v)


# ---------------------------------------------------------------- 도넛 겉면 위의 점
# a: 둘레 각도(라디안), b: 관 각도(라디안). b = -90도가 앞(-Y) 가운데, 0도가 바깥 가장자리
def surface(a, b, lift=0.0):
    radial = Vector((math.cos(a), 0.0, math.sin(a)))
    center = radial * RING_R
    r = TUBE_R + lift
    return center + radial * (r * math.cos(b)) + Vector((0, 1, 0)) * (r * TUBE_FLAT * math.sin(b))


def icing_edge(a):
    """그 둘레 각도에서 아이싱이 앞 가운데로부터 덮는 각도(도): 물결 모양으로 흘러내린다"""
    wave = math.sin(a * 7) * 0.6 + math.sin(a * 11 + 1.3) * 0.4
    return ICING_COVER + ICING_WAVE * wave


def iced(a, b):
    return abs(math.degrees(b) + 90) < icing_edge(a)


# ---------------------------------------------------------------- 도넛 몸통 (아이싱 부분은 살짝 부풀린다)
bm = bmesh.new()
uv_layer = bm.loops.layers.uv.new("UVMap")
verts = {}
flags = {}
for i in range(NU):
    a = 2 * math.pi * i / NU
    for k in range(NV):
        b = 2 * math.pi * k / NV - math.pi
        on = iced(a, b)
        flags[i, k] = on
        verts[i, k] = bm.verts.new(surface(a, b, ICING_LIFT if on else 0.0))
for i in range(NU):
    for k in range(NV):
        quad = [(i, k), ((i + 1) % NU, k), ((i + 1) % NU, (k + 1) % NV), (i, (k + 1) % NV)]
        f = bm.faces.new([verts[q] for q in quad])
        n_iced = sum(1 for q in quad if flags[q])
        if n_iced >= 3:
            name = "GreenDark" if rng.random() < SPECKLE else "Green"
        else:
            name = "Dough"
        u, v = cell_uv(name)
        for loop in f.loops:
            loop[uv_layer].uv = (u, v)
bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
body_mesh = bpy.data.meshes.new(NAME + "_Body")
bm.to_mesh(body_mesh)
bm.free()
body_mesh.polygons.foreach_set("use_smooth", [True] * len(body_mesh.polygons))
body = bpy.data.objects.new(NAME + "_Body", body_mesh)
scene.collection.objects.link(body)
parts = [body]

# ---------------------------------------------------------------- 흰 아이싱: 앞면을 지그재그로 가로지르는 선
curve = bpy.data.curves.new(NAME + "_Drizzle", "CURVE")
curve.dimensions = "3D"
curve.bevel_depth = 0.024
curve.bevel_resolution = 2
spline = curve.splines.new("POLY")
N = DRIZZLE_ZIGS * 12
spline.points.add(N)
reach = [rng.uniform(0.55, 0.95) for _ in range(DRIZZLE_ZIGS * 2 + 1)]  # 꺾이는 곳마다 닿는 정도를 조금씩 다르게 (손으로 뿌린 느낌)
for n in range(N + 1):
    t = n / N
    a = 2 * math.pi * t + 0.03 * math.sin(t * 57)
    phase = t * DRIZZLE_ZIGS * 2
    tri = 1 - abs(phase % 2 - 1) * 2  # -1 ~ 1 세모 물결
    b = math.radians(-90 + tri * ICING_COVER * reach[int(phase + 0.5) % len(reach)])
    p = surface(a, b, ICING_LIFT + 0.02)
    spline.points[n].co = (p.x, p.y, p.z, 1.0)
spline.use_cyclic_u = True
dz = bpy.data.objects.new(NAME + "_Drizzle_curve", curve)
scene.collection.objects.link(dz)
depsgraph = bpy.context.evaluated_depsgraph_get()
dz_mesh = bpy.data.meshes.new_from_object(dz.evaluated_get(depsgraph))
bpy.data.objects.remove(dz, do_unlink=True)
bpy.data.curves.remove(curve)
drizzle = bpy.data.objects.new(NAME + "_Drizzle", dz_mesh)
scene.collection.objects.link(drizzle)
paint_all(dz_mesh, "White")
parts.append(drizzle)

# ---------------------------------------------------------------- 크랜베리: 아이싱 위 작은 빨간 조각
bm = bmesh.new()
placed = 0
tries = 0
while placed < BERRIES and tries < 500:
    tries += 1
    a = rng.uniform(0, 2 * math.pi)
    b = math.radians(-90 + rng.uniform(-1, 1) * (ICING_COVER - 12))
    if not iced(a, b):
        continue
    size = rng.uniform(0.055, 0.085)
    piece = bmesh.ops.create_icosphere(bm, subdivisions=1, radius=size)["verts"]
    # 살짝 찌그러뜨리고 돌려서 말린 과일 조각처럼
    sx, sy, sz = rng.uniform(0.8, 1.4), rng.uniform(0.6, 0.9), rng.uniform(0.8, 1.4)
    pos = surface(a, b, ICING_LIFT + size * 0.3)
    for vtx in piece:
        vtx.co = Vector((vtx.co.x * sx, vtx.co.y * sy, vtx.co.z * sz))
    bmesh.ops.rotate(bm, verts=piece, cent=(0, 0, 0),
                     matrix=Euler((rng.random() * 3, rng.random() * 3, rng.random() * 3)).to_matrix())
    bmesh.ops.translate(bm, verts=piece, vec=pos)
    placed += 1
berry_mesh = bpy.data.meshes.new(NAME + "_Berries")
bm.to_mesh(berry_mesh)
bm.free()
berries = bpy.data.objects.new(NAME + "_Berries", berry_mesh)
scene.collection.objects.link(berries)
paint_all(berry_mesh, "Red")
parts.append(berries)

for obj in parts:
    obj.data.materials.append(material)

# ---------------------------------------------------------------- 저장
bpy.ops.object.select_all(action="DESELECT")
for obj in parts:
    obj.select_set(True)
bpy.context.view_layer.objects.active = body
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
    embed_textures=True,  # 색 그림을 FBX 안에 넣는다
    object_types={"MESH"},
)
print(f"[크리스마스 링 도넛] 삼각형 {total}개. 저장: {fbx_path}")
