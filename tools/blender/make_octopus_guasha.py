"""문어 괄사(OctopusGuaSha) 장식 모델을 만들어 .blend / .fbx 로 저장한다.

둥근 머리 + 아래로 벌어지며 내려오는 다리 6개. 메타볼(서로 녹아 붙는 공)로 만들어 이음매 없이 매끈하다.
색은 Studio에서 입힌다 (Import 3D는 Blender 재질 색을 가져오지 않는다. docs/DECORATION_MODELS.md 참고).

실행 (둘 중 하나):
  1) Blender 화면: 위쪽 Scripting 탭 -> Open -> 이 파일 -> Run Script (재생 버튼)
  2) 명령: blender -b -P tools/blender/make_octopus_guasha.py -- <저장할 폴더>
출력: <폴더>/OctopusGuaSha.fbx, OctopusGuaSha.blend
     (폴더를 안 주면 내 사용자 폴더의 Tree_deco/assets/models/decorations)
"""
import math
import os
import sys

import bpy

# ---------------------------------------------------------------- 모양 숫자 (바꿔 보면서 다듬기)
LEGS = 6              # 다리 수
HEAD_R = 0.95         # 머리 반지름
HEAD_Z = 1.95         # 머리 가운데 높이
HEAD_TALL = 1.12      # 머리 세로 늘림 (1 = 동그란 공)
LEG_TOP_R = 0.30      # 다리 굵기 (윗부분)
LEG_END_R = 0.21      # 다리 굵기 (끝)
LEG_SPREAD = 1.25     # 다리 끝이 가운데에서 벌어진 거리
LEG_START_Z = 1.25    # 다리가 시작하는 높이
LEG_END_Z = 0.22      # 다리 끝 높이 (바닥)
DETAIL = 0.045        # 표면 촘촘함 (작을수록 매끈, 대신 무거움)
MAX_TRIS = 6000       # 삼각형 수 상한 (Roblox 메시 한 개 한도 20000보다 넉넉히 작게)

argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
OUT_DIR = os.path.abspath(argv[0]) if argv else os.path.join(
    os.path.expanduser("~"), "Tree_deco", "assets", "models", "decorations")
os.makedirs(OUT_DIR, exist_ok=True)

# ---------------------------------------------------------------- 장면 비우기
for obj in list(bpy.data.objects):
    bpy.data.objects.remove(obj, do_unlink=True)
for coll in (bpy.data.meshes, bpy.data.metaballs, bpy.data.materials):
    for item in list(coll):
        if item.users == 0:
            coll.remove(item)

# ---------------------------------------------------------------- 메타볼로 모양 잡기
mb = bpy.data.metaballs.new("OctopusShape")
mb.resolution = DETAIL
mb.render_resolution = DETAIL
mb.threshold = 0.6
shape = bpy.data.objects.new("OctopusShape", mb)
bpy.context.scene.collection.objects.link(shape)


def ball(x, y, z, r, tall=1.0):
    el = mb.elements.new(type="ELLIPSOID")
    el.co = (x, y, z)
    el.radius = r
    el.size_x, el.size_y, el.size_z = 1.0, 1.0, tall
    el.stiffness = 2.0


# 머리 + 머리 밑 목 (머리와 다리를 부드럽게 이어 준다)
ball(0, 0, HEAD_Z, HEAD_R * 1.55, HEAD_TALL)
ball(0, 0, LEG_START_Z + 0.1, HEAD_R * 1.05, 0.8)

# 다리: 가운데 아래에서 나와 바깥으로 벌어졌다가 거의 수직으로 내려온다 (2차 베지어 곡선)
STEPS = 14
for k in range(LEGS):
    a = 2 * math.pi * k / LEGS  # 다리 6개면 앞(-Y)에 다리 사이 틈이 온다
    dx, dy = math.cos(a), math.sin(a)
    p0 = (0.25, LEG_START_Z)              # (가운데에서 거리, 높이)
    p1 = (LEG_SPREAD * 0.95, LEG_START_Z - 0.05)
    p2 = (LEG_SPREAD, LEG_END_Z)
    for i in range(STEPS + 1):
        t = i / STEPS
        rr = (1 - t) ** 2 * p0[0] + 2 * (1 - t) * t * p1[0] + t ** 2 * p2[0]
        zz = (1 - t) ** 2 * p0[1] + 2 * (1 - t) * t * p1[1] + t ** 2 * p2[1]
        thick = LEG_TOP_R + (LEG_END_R - LEG_TOP_R) * t
        if i == STEPS:
            thick *= 1.12  # 끝을 살짝 동그랗게
        ball(dx * rr, dy * rr, zz, thick * 1.55)

# ---------------------------------------------------------------- 메시로 바꾸고 가볍게
depsgraph = bpy.context.evaluated_depsgraph_get()
mesh = bpy.data.meshes.new_from_object(shape.evaluated_get(depsgraph))
mesh.name = "OctopusGuaSha"
bpy.data.objects.remove(shape, do_unlink=True)
bpy.data.metaballs.remove(mb)

obj = bpy.data.objects.new("OctopusGuaSha", mesh)
bpy.context.scene.collection.objects.link(obj)

tris = sum(len(p.vertices) - 2 for p in mesh.polygons)
if tris > MAX_TRIS:
    mod = obj.modifiers.new("Decimate", "DECIMATE")
    mod.ratio = MAX_TRIS / tris
    depsgraph = bpy.context.evaluated_depsgraph_get()
    light = bpy.data.meshes.new_from_object(obj.evaluated_get(depsgraph))
    obj.modifiers.clear()
    old = obj.data
    obj.data = light
    bpy.data.meshes.remove(old)
    light.name = "OctopusGuaSha"
    mesh = light

mesh.polygons.foreach_set("use_smooth", [True] * len(mesh.polygons))
mesh.update()

# 바닥을 높이 0에 맞추고 가운데를 원점에
zs = [v.co.z for v in mesh.vertices]
mesh.transform(__import__("mathutils").Matrix.Translation((0, 0, -min(zs))))

# Blender 화면에서 볼 때 분홍색 (Studio에는 안 넘어간다)
mat = bpy.data.materials.new("RoseQuartz")
mat.diffuse_color = (0.95, 0.55, 0.55, 1.0)
mesh.materials.append(mat)

tris = sum(len(p.vertices) - 2 for p in mesh.polygons)

# ---------------------------------------------------------------- 저장
bpy.ops.object.select_all(action="DESELECT")
obj.select_set(True)
bpy.context.view_layer.objects.active = obj
blend_path = os.path.join(OUT_DIR, "OctopusGuaSha.blend")
fbx_path = os.path.join(OUT_DIR, "OctopusGuaSha.fbx")
bpy.ops.wm.save_as_mainfile(filepath=blend_path)
bpy.ops.export_scene.fbx(filepath=fbx_path, use_selection=True, object_types={"MESH"},
                         apply_scale_options="FBX_SCALE_ALL", mesh_smooth_type="FACE")
print(f"[문어 괄사] 삼각형 {tris}개. 저장: {fbx_path}")
