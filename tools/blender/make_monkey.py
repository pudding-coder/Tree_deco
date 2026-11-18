"""트리에 매달리는 원숭이 오너먼트를 만들어 .blend / .fbx 로 저장한다.

나뭇가지에 두 손과 한 발로 매달린 모습: 위쪽 작은 나뭇가지를 잡고 몸은 아래로 늘어뜨리고, 머리는 옆으로 갸웃 기울여 앞을 본다.
나뭇가지가 걸이 역할이라 게임에서 트리에 붙는 뒷면(+Y)은 나뭇가지 뒤쪽이다.
색마다 오브젝트를 나눠 두어 Roblox에서 파트별 색이 유지된다.

실행:
  /Applications/Blender.app/Contents/MacOS/Blender -b -P tools/blender/make_monkey.py -- assets/models/decorations [preview.png]

출력: <폴더>/MonkeyOrnament.blend, MonkeyOrnament.fbx
앞(얼굴)은 Blender의 -Y 쪽(Front 뷰에서 보이는 쪽), 트리에 붙는 뒤는 +Y, 위는 +Z.
"""
import math
import os
import sys

import bpy
from mathutils import Euler, Matrix, Vector

argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
OUT_DIR = os.path.abspath(argv[0] if argv else "assets/models/decorations")
PREVIEW = argv[1] if len(argv) > 1 else None
SIDE = os.environ.get("SIDE") == "1"  # 옆에서 본 미리보기
NAME = "MonkeyOrnament"
os.makedirs(OUT_DIR, exist_ok=True)

# 색 (Roblox에서도 이 색으로 보이게 오브젝트마다 하나씩)
COLORS = {
    "Fur": (0.48, 0.37, 0.32),
    "Face": (0.95, 0.91, 0.87),
    "Eyes": (0.04, 0.03, 0.03),
    "EyeShine": (1.0, 1.0, 1.0),
    "Cheeks": (1.0, 0.55, 0.62),
    "Mouth": (0.25, 0.14, 0.13),
    "Branch": (0.36, 0.24, 0.14),
}

# 처음 장면(정육면체 등)을 비운다
bpy.ops.wm.read_factory_settings(use_empty=True)
scene = bpy.context.scene

materials = {}
for name, rgb in COLORS.items():
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes["Principled BSDF"]
    bsdf.inputs["Base Color"].default_value = (*rgb, 1.0)
    bsdf.inputs["Roughness"].default_value = 0.25 if name == "Eyes" else 0.6
    mat.diffuse_color = (*rgb, 1.0)
    materials[name] = mat

parts = {name: [] for name in COLORS}


def finish(obj, group):
    obj.data.materials.clear()
    obj.data.materials.append(materials[group])
    for poly in obj.data.polygons:
        poly.use_smooth = True
    parts[group].append(obj)
    return obj


def sphere(group, loc, scale, rot=(0, 0, 0), segments=24, rings=12):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=segments, ring_count=rings, radius=1, location=loc, rotation=rot)
    obj = bpy.context.active_object
    obj.scale = scale
    return finish(obj, group)


def tube(group, points, radius, resolution=8):
    """점들을 지나는 둥근 관 (팔·다리·꼬리·입). 끝은 둥글게 막는다"""
    curve = bpy.data.curves.new("tube", "CURVE")
    curve.dimensions = "3D"
    curve.bevel_depth = radius
    curve.bevel_resolution = 3
    curve.use_fill_caps = True
    curve.resolution_u = resolution
    spline = curve.splines.new("BEZIER")
    spline.bezier_points.add(len(points) - 1)
    for bp, p in zip(spline.bezier_points, points):
        bp.co = p
        bp.handle_left_type = bp.handle_right_type = "AUTO"
    obj = bpy.data.objects.new("tube", curve)
    scene.collection.objects.link(obj)
    bpy.context.view_layer.objects.active = obj
    obj.select_set(True)
    bpy.ops.object.convert(target="MESH")
    obj = bpy.context.active_object
    obj.select_set(False)
    # 끝을 둥글게: 양 끝에 작은 공
    sphere(group, points[0], (radius, radius, radius), segments=16, rings=8)
    sphere(group, points[-1], (radius, radius, radius), segments=16, rings=8)
    return finish(obj, group)


def all_objects():
    return [o for objs in parts.values() for o in objs]


def move_group(objs, pivot, target, rot_deg):
    """objs를 pivot 기준으로 rot_deg(x, y, z 도)만큼 돌리고 pivot이 target에 오게 옮긴다"""
    bpy.context.view_layer.update()  # 방금 바꾼 크기·위치를 matrix_world에 반영
    rot = Euler(tuple(math.radians(a) for a in rot_deg)).to_matrix().to_4x4()
    m = Matrix.Translation(target) @ rot @ Matrix.Translation(-Vector(pivot))
    for o in objs:
        o.matrix_world = m @ o.matrix_world


# ---------------------------------------------------------------- 머리 (원점 근처에서 만들고 나중에 옮긴다)
HEAD = Vector((0, -0.08, 1.05))
before_head = set(all_objects())
sphere("Fur", HEAD, (0.62, 0.55, 0.56), segments=40, rings=20)
# 귀
for s in (-1, 1):
    sphere("Fur", (s * 0.6, -0.04, 1.12), (0.2, 0.12, 0.2))
    sphere("Face", (s * 0.63, -0.12, 1.12), (0.12, 0.05, 0.12))

# 얼굴: 밝은 둥근 부분 (털이 테두리로 보이게 머리보다 작게)
FACE_C = Vector((0, -0.37, 0.97))
FACE_R = Vector((0.45, 0.29, 0.39))
sphere("Face", FACE_C, FACE_R, segments=40, rings=20)


def face_y(x, z, lift=0.0):
    """얼굴 앞면(타원체 FACE)의 y 좌표 + 앞으로 lift만큼"""
    nx = (x - FACE_C.x) / FACE_R.x
    nz = (z - FACE_C.z) / FACE_R.z
    k = max(0.0, 1 - nx * nx - nz * nz)
    return FACE_C.y - FACE_R.y * math.sqrt(k) - lift


# 눈: 크고 동그란 까만 눈 + 하이라이트 두 개 (더 귀엽게)
for s in (-1, 1):
    ex, ez = s * 0.18, 1.0
    sphere("Eyes", (ex, face_y(ex, ez, -0.035), ez), (0.09, 0.05, 0.115))
    # 큰 반짝임 (왼쪽 위), 작은 반짝임 (오른쪽 아래)
    hx, hz = ex - 0.035, ez + 0.045
    sphere("EyeShine", (hx, face_y(ex, ez, 0.012), hz), (0.035, 0.015, 0.035), segments=16, rings=8)
    lx, lz = ex + 0.04, ez - 0.05
    sphere("EyeShine", (lx, face_y(ex, ez, 0.008), lz), (0.016, 0.01, 0.016), segments=12, rings=6)

# 볼터치
for s in (-1, 1):
    cx, cz = s * 0.3, 0.88
    sphere("Cheeks", (cx, face_y(cx, cz, -0.015), cz), (0.09, 0.025, 0.06))

# 입: 작은 ω
mouth = []
for x, z in ((-0.09, 0.86), (-0.045, 0.825), (0.0, 0.852), (0.045, 0.825), (0.09, 0.86)):
    mouth.append(Vector((x, face_y(x, z, 0.004), z)))
tube("Mouth", mouth, 0.014)

# 머리를 몸 왼쪽 위로 옮긴다 (얼굴은 기울이지 않고 정면)
HEAD_POS = Vector((-0.36, -0.06, 1.12))
head_objs = [o for o in all_objects() if o not in before_head]
move_group(head_objs, HEAD, HEAD_POS, (0, 0, 0))  # 얼굴은 똑바로 정면

# ---------------------------------------------------------------- 나뭇가지 (걸이)
# 위쪽에서 오른쪽으로 살짝 내려가는 짧은 가지. 뒤쪽 끝(y = BRANCH_Y + 반지름)이 게임에서 트리에 붙는다
BRANCH_Y = 0.36
BRANCH_R = 0.1
def branch_z(x):
    return 2.0 - 0.12 * x
tube("Branch", [Vector((-1.15, BRANCH_Y, branch_z(-1.15))), Vector((0.0, BRANCH_Y, branch_z(0.0) + 0.02)), Vector((1.2, BRANCH_Y, branch_z(1.2)))], BRANCH_R)
tube("Branch", [Vector((-0.75, BRANCH_Y, branch_z(-0.75))), Vector((-0.95, BRANCH_Y - 0.05, branch_z(-0.75) + 0.28))], 0.045)  # 잔가지

# ---------------------------------------------------------------- 몸 (오른쪽 아래로 늘어진다)
BODY = Vector((0.3, 0.12, 0.82))
sphere("Fur", BODY, (0.36, 0.3, 0.5), rot=(0, math.radians(-15), 0))
sphere("Face", BODY + Vector((-0.02, -0.17, -0.04)), (0.23, 0.18, 0.33), rot=(0, math.radians(-15), 0))  # 배


def grip(x, side_scale=1.0):
    """나뭇가지를 감싸 쥔 손발: 가지 앞쪽과 위쪽에 둥근 덩어리"""
    z = branch_z(x)
    sphere("Fur", (x, BRANCH_Y - 0.09, z + 0.02), (0.11 * side_scale, 0.08, 0.12))
    sphere("Face", (x, BRANCH_Y - 0.15, z - 0.02), (0.08 * side_scale, 0.04, 0.07))  # 밝은 손바닥·손가락


# 두 팔: 어깨에서 위로 뻗어 가지를 잡는다
for shoulder, hand_x in ((Vector((0.12, 0.1, 1.2)), 0.05), (Vector((0.48, 0.1, 1.16)), 0.58)):
    hand = Vector((hand_x, BRANCH_Y - 0.08, branch_z(hand_x) - 0.06))
    mid = (shoulder + hand) / 2 + Vector((0.06, -0.06, 0))
    tube("Fur", [shoulder, mid, hand], 0.095)
    grip(hand_x)

# 오른발: 무릎을 굽혀 위로 올려 가지를 잡는다
foot_x = 1.0
hip = Vector((0.5, 0.12, 0.45))
knee = Vector((0.95, 0.0, 0.85))
foot = Vector((foot_x, BRANCH_Y - 0.08, branch_z(foot_x) - 0.08))
tube("Fur", [hip, knee, foot], 0.09)
grip(foot_x, 1.1)

# 왼발: 아래로 대롱대롱
tube("Fur", [Vector((0.2, 0.12, 0.42)), Vector((0.22, 0.04, 0.12)), Vector((0.28, -0.02, -0.06))], 0.09)
sphere("Fur", (0.29, -0.08, -0.1), (0.11, 0.14, 0.09))
sphere("Face", (0.29, -0.2, -0.1), (0.07, 0.03, 0.06))

# 꼬리: 엉덩이 뒤에서 아래로 내려와 돌돌
tail = [
    Vector((0.45, 0.38, 0.45)),
    Vector((0.65, 0.42, 0.15)),
    Vector((0.6, 0.42, -0.2)),
    Vector((0.38, 0.4, -0.3)),
    Vector((0.32, 0.38, -0.12)),
    Vector((0.45, 0.36, -0.08)),
]
tube("Fur", tail, 0.055, resolution=12)

# ---------------------------------------------------------------- 색마다 하나로 합치기
final = []
for group, objs in parts.items():
    if not objs:
        continue
    bpy.ops.object.select_all(action="DESELECT")
    for obj in objs:
        obj.select_set(True)
    bpy.context.view_layer.objects.active = objs[0]
    bpy.ops.object.join()
    obj = bpy.context.active_object
    obj.name = group
    obj.data.name = group
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
    final.append(obj)

# 원점을 모델 가운데 아래로 (Roblox에서 다루기 쉽게)
bpy.ops.object.select_all(action="SELECT")
bpy.context.view_layer.objects.active = final[0]
bpy.ops.object.origin_set(type="ORIGIN_CURSOR")

tris = sum(sum(len(p.vertices) - 2 for p in o.data.polygons) for o in final)
print(f"[monkey] objects={len(final)} tris={tris}")

blend_path = os.path.join(OUT_DIR, NAME + ".blend")
fbx_path = os.path.join(OUT_DIR, NAME + ".fbx")
bpy.ops.wm.save_as_mainfile(filepath=blend_path)
bpy.ops.export_scene.fbx(
    filepath=fbx_path,
    use_selection=False,
    apply_scale_options="FBX_SCALE_ALL",
    axis_forward="-Z",
    axis_up="Y",
    mesh_smooth_type="FACE",
    use_mesh_modifiers=True,
)
print("[monkey] saved", blend_path, fbx_path)

# ---------------------------------------------------------------- 미리보기
if PREVIEW:
    world = bpy.data.worlds.new("World")
    world.use_nodes = True
    world.node_tree.nodes["Background"].inputs[0].default_value = (0.82, 0.88, 0.95, 1)
    world.node_tree.nodes["Background"].inputs[1].default_value = 0.8
    scene.world = world

    sun = bpy.data.objects.new("Sun", bpy.data.lights.new("Sun", "SUN"))
    sun.data.energy = 3.5
    sun.rotation_euler = (math.radians(50), math.radians(-20), math.radians(-30))
    scene.collection.objects.link(sun)

    cam = bpy.data.objects.new("Cam", bpy.data.cameras.new("Cam"))
    cam.data.lens = 70
    scene.collection.objects.link(cam)
    cam.location = (7.2, -0.6, 1.4) if SIDE else (1.2, -7.2, 1.5)
    direction = Vector((0.05, 0, 0.95)) - cam.location
    cam.rotation_euler = direction.to_track_quat("-Z", "Y").to_euler()
    scene.camera = cam

    scene.render.engine = "CYCLES"
    scene.cycles.device = "CPU"
    scene.cycles.samples = 48
    scene.render.resolution_x = 700
    scene.render.resolution_y = 800
    scene.render.filepath = os.path.abspath(PREVIEW)
    bpy.ops.render.render(write_still=True)
    print("[monkey] preview", PREVIEW)
