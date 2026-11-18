"""레퍼런스 사진 그대로의 원숭이 오너먼트를 만들어 .blend / .fbx 로 저장한다.

큰 머리에 하트 모양 밝은 얼굴, 작은 점 눈, ω 입. 살짝 각진 로우폴리 느낌.
작은 몸은 머리 뒤로 엎드려 있고 앞발은 앞으로, 꼬리는 뒤에서 위로 말린다.
색마다 오브젝트를 나눠 두어 Roblox에서 파트별 색이 유지된다.

실행:
  /Applications/Blender.app/Contents/MacOS/Blender -b -P tools/blender/make_monkey_photo.py -- assets/models/decorations [preview.png]

출력: <폴더>/MonkeyPhoto.blend, MonkeyPhoto.fbx
앞(얼굴)은 Blender의 -Y 쪽(Front 뷰에서 보이는 쪽), 트리에 붙는 뒤는 +Y, 위는 +Z.
"""
import math
import os
import sys

import bpy
import bmesh  # bpy 다음에 불러와야 한다 (bpy 모듈로 실행할 때)
from mathutils import Euler, Matrix, Vector

argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
OUT_DIR = os.path.abspath(argv[0] if argv else "assets/models/decorations")
PREVIEW = argv[1] if len(argv) > 1 else None
VIEW = os.environ.get("VIEW", "photo")  # 미리보기 카메라: photo(사진 각도) / front / side / back
NAME = "MonkeyPhoto"
os.makedirs(OUT_DIR, exist_ok=True)

# 값은 Blender 선형 색. 미리보기는 Standard 보기로 렌더해서 화면 색 ≈ 사진 색
COLORS = {
    "Fur": (0.62, 0.41, 0.25),  # 따뜻한 베이지
    "Ear": (0.82, 0.63, 0.47),
    "Face": (0.8, 0.62, 0.46),  # 크림색
    "Eyes": (0.02, 0.02, 0.02),
    "Mouth": (0.02, 0.02, 0.02),
}
FLAT = {"Fur", "Ear", "Face"}  # 각진 로우폴리 느낌

bpy.ops.wm.read_factory_settings(use_empty=True)
scene = bpy.context.scene

materials = {}
for name, rgb in COLORS.items():
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes["Principled BSDF"]
    bsdf.inputs["Base Color"].default_value = (*rgb, 1.0)
    bsdf.inputs["Roughness"].default_value = 0.7
    mat.diffuse_color = (*rgb, 1.0)
    materials[name] = mat

parts = {name: [] for name in COLORS}


def finish(obj, group):
    obj.data.materials.clear()
    obj.data.materials.append(materials[group])
    smooth = group not in FLAT
    for poly in obj.data.polygons:
        poly.use_smooth = smooth
    parts[group].append(obj)
    return obj


def sphere(group, loc, scale, rot=(0, 0, 0), segments=18, rings=10):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=segments, ring_count=rings, radius=1, location=loc, rotation=rot)
    obj = bpy.context.active_object
    obj.scale = scale
    return finish(obj, group)


def tube(group, points, radius, resolution=8, caps=True):
    curve = bpy.data.curves.new("tube", "CURVE")
    curve.dimensions = "3D"
    curve.bevel_depth = radius
    curve.bevel_resolution = 2
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
    if caps:
        sphere(group, points[0], (radius, radius, radius), segments=10, rings=6)
        sphere(group, points[-1], (radius, radius, radius), segments=10, rings=6)
    return finish(obj, group)


def all_objects():
    return [o for objs in parts.values() for o in objs]


def move_group(objs, pivot, target, rot_deg):
    bpy.context.view_layer.update()
    rot = Euler(tuple(math.radians(a) for a in rot_deg)).to_matrix().to_4x4()
    m = Matrix.Translation(Vector(target)) @ rot @ Matrix.Translation(-Vector(pivot))
    for o in objs:
        o.matrix_world = m @ o.matrix_world


# ---------------------------------------------------------------- 머리 (원점에서 만들고 나중에 기울인다)
HEAD_R = Vector((0.56, 0.5, 0.47))  # 옆으로 조금 넓은 둥근 머리
sphere("Fur", (0, 0, 0), HEAD_R, segments=20, rings=12)


def on_head(x, z, lift=0.0):
    """머리 앞면 위의 점 (x, z는 머리 가운데 기준)"""
    nx, nz = x / HEAD_R.x, z / HEAD_R.z
    k = max(0.0, 1 - nx * nx - nz * nz)
    return Vector((x, -HEAD_R.y * math.sqrt(k) - lift, z))


# 하트 모양 얼굴: 머리 표면을 본뜬 얇은 막에서 하트 안쪽만 남긴다 (머리 곡면을 그대로 따라간다)
def in_heart(x, z):
    # 위 두 봉우리(원 두 개) + 아래 둥근 부분(타원)
    for s in (-1, 1):
        if ((x - s * 0.19) / 0.22) ** 2 + ((z - 0.1) / 0.21) ** 2 <= 1:
            return True
    return (x / 0.42) ** 2 + ((z + 0.04) / 0.3) ** 2 <= 1 and z <= 0.12


face_mesh = bpy.data.meshes.new("FaceMask")
bm = bmesh.new()
bmesh.ops.create_uvsphere(bm, u_segments=160, v_segments=80, radius=1)  # 촘촘해야 하트 테두리가 덜 울퉁불퉁
for v in bm.verts:
    v.co = Vector((v.co.x * HEAD_R.x, v.co.y * HEAD_R.y, v.co.z * HEAD_R.z)) * 1.012
bmesh.ops.delete(bm, geom=[f for f in bm.faces if not (f.calc_center_median().y < 0 and in_heart(f.calc_center_median().x, f.calc_center_median().z))], context="FACES")
bm.to_mesh(face_mesh)
bm.free()
face_obj = bpy.data.objects.new("FaceMask", face_mesh)
scene.collection.objects.link(face_obj)
solid = face_obj.modifiers.new("Solidify", "SOLIDIFY")
solid.thickness = 0.015
bpy.context.view_layer.objects.active = face_obj
bpy.ops.object.modifier_apply(modifier="Solidify")
finish(face_obj, "Face")

# 귀: 머리 양옆에 납작한 타원 판 (밖을 향한다)
for s in (-1, 1):
    sphere("Ear", (s * 0.57, 0.06, 0.04), (0.05, 0.14, 0.19), rot=(0, math.radians(s * 10), 0), segments=12, rings=8)

# 눈: 작은 까만 점
for s in (-1, 1):
    sphere("Eyes", on_head(s * 0.2, 0.03, 0.006), (0.05, 0.02, 0.055), segments=12, rings=6)

# 입: 굵은 ω. 왼쪽 끝은 위로 짧게 올라간 갈고리
mouth = [on_head(x, z, 0.014) for x, z in (
    (-0.14, 0.0), (-0.15, -0.06), (-0.11, -0.12), (-0.05, -0.12),
    (-0.01, -0.08),
    (0.03, -0.12), (0.09, -0.15), (0.15, -0.12),
)]
tube("Mouth", mouth, 0.02, resolution=6)

head_objs = list(all_objects())
# 사진처럼 오른쪽 아래를 보며 살짝 갸웃
HEAD_POS = Vector((0.05, -0.05, 0.72))
move_group(head_objs, (0, 0, 0), HEAD_POS, (8, -12, 6))

# ---------------------------------------------------------------- 몸 (머리 뒤로 엎드린 작은 몸)
sphere("Fur", (-0.12, 0.32, 0.3), (0.32, 0.4, 0.27), rot=(0, 0, math.radians(20)))

# 앞발: 앞으로 뻗어 바닥(가지)에 짚는다
for start, end in (
    (Vector((-0.1, 0.05, 0.3)), Vector((0.0, -0.3, 0.1))),
    (Vector((-0.36, 0.12, 0.3)), Vector((-0.36, -0.18, 0.1))),
):
    mid = (start + end) / 2 + Vector((0, 0, 0.05))
    tube("Fur", [start, mid, end], 0.1)
    sphere("Fur", end, (0.12, 0.14, 0.09))

# 뒷발: 몸 뒤 왼쪽에 웅크린다
sphere("Fur", (-0.42, 0.48, 0.12), (0.14, 0.18, 0.12))

# 꼬리: 엉덩이에서 왼쪽 뒤로 나와 위로 말린다
tail = [
    Vector((-0.35, 0.6, 0.32)),
    Vector((-0.7, 0.62, 0.38)),
    Vector((-0.98, 0.55, 0.7)),
    Vector((-0.95, 0.5, 1.02)),
    Vector((-0.82, 0.48, 1.08)),
]
tube("Fur", tail, 0.06, resolution=10)

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
    world.node_tree.nodes["Background"].inputs[0].default_value = (0.86, 0.9, 0.86, 1)
    world.node_tree.nodes["Background"].inputs[1].default_value = 0.9
    scene.world = world

    sun = bpy.data.objects.new("Sun", bpy.data.lights.new("Sun", "SUN"))
    sun.data.energy = 3.0
    sun.rotation_euler = (math.radians(40), math.radians(-15), math.radians(-25))
    scene.collection.objects.link(sun)

    cam = bpy.data.objects.new("Cam", bpy.data.cameras.new("Cam"))
    cam.data.lens = 70
    scene.collection.objects.link(cam)
    cam.location = {
        "photo": (2.6, -6.0, 2.6),
        "front": (0.0, -6.5, 0.9),
        "side": (6.5, 0.2, 0.9),
        "back": (-2.2, 6.2, 1.6),
    }[VIEW]
    direction = Vector((-0.15, 0.1, 0.55)) - cam.location
    cam.rotation_euler = direction.to_track_quat("-Z", "Y").to_euler()
    scene.camera = cam

    scene.view_settings.view_transform = "Standard"
    scene.render.engine = "CYCLES"
    scene.cycles.device = "CPU"
    scene.cycles.samples = 48
    scene.render.resolution_x = 800
    scene.render.resolution_y = 700
    scene.render.filepath = os.path.abspath(PREVIEW)
    bpy.ops.render.render(write_still=True)
    print("[monkey] preview", PREVIEW)
