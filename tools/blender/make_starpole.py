"""별 기둥(StarPole)의 별을 면이 깎인 입체 별로 다시 만들어 .blend / .fbx 로 저장한다.

원래 StarPole.fbx(맵 에셋)를 불러와 별 파트(StarPole_GlowGold)만 바꾸고 나머지(받침·기둥·재질 이름)는 그대로 둔다.
별: 가운데가 앞뒤로 볼록하고 가장자리는 얇은 별(앞뒤 피라미드 두 개를 붙인 모양). 면은 각지게(로우폴리).

실행:
  /Applications/Blender.app/Contents/MacOS/Blender -b -P tools/blender/make_starpole.py -- assets/models/map/StarPole.fbx assets/models/map
출력: <폴더>/StarPole.fbx, StarPole.blend
"""
import math
import os
import sys

import bpy
import bmesh  # bpy 다음에 불러와야 한다 (bpy 모듈로 실행할 때)

argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
SRC = os.path.abspath(argv[0] if argv else "assets/models/map/StarPole.fbx")
OUT_DIR = os.path.abspath(argv[1] if len(argv) > 1 else "assets/models/map")
os.makedirs(OUT_DIR, exist_ok=True)

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.fbx(filepath=SRC)
star = bpy.data.objects["StarPole_GlowGold"]
mw = star.matrix_world.copy()
# 월드 좌표 기준으로 새 별을 만든다 (원래 별과 같은 크기·위치)
R, r = 3.2, 1.35       # 바깥·안쪽 반지름
cy = 21.61 + 0.809 * R  # 별 가운데 높이
depth = 0.75           # 가운데가 앞뒤로 볼록한 정도
bm = bmesh.new()
rim = []
for k in range(10):
    a = math.pi / 2 + k * math.pi / 5
    rad = R if k % 2 == 0 else r
    rim.append(bm.verts.new((math.cos(a) * rad, 0.0, cy + math.sin(a) * rad)))
front = bm.verts.new((0, -depth, cy))
back = bm.verts.new((0, depth, cy))
for k in range(10):
    n = (k + 1) % 10
    bm.faces.new((front, rim[n], rim[k]))
    bm.faces.new((back, rim[k], rim[n]))
bmesh.ops.recalc_face_normals(bm, faces=bm.faces)  # 모든 면이 바깥을 보게 (Roblox는 뒷면을 그리지 않는다)
bm.normal_update()
mesh = bpy.data.meshes.new("StarPole_GlowGold")
bm.to_mesh(mesh); bm.free()
for poly in mesh.polygons:
    poly.use_smooth = False
mesh.materials.append(star.data.materials[0])
mesh.transform(mw.inverted())  # 오브젝트 좌표로
old = star.data
star.data = mesh
bpy.data.meshes.remove(old)

star.data.name = "StarPole_GlowGold"
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(OUT_DIR, "StarPole.blend"))
bpy.ops.export_scene.fbx(
    filepath=os.path.join(OUT_DIR, "StarPole.fbx"),
    use_selection=False,
    axis_forward="-Z",
    axis_up="Y",
    apply_unit_scale=True,
    apply_scale_options="FBX_SCALE_NONE",
    mesh_smooth_type="FACE",
)
print("[starpole] saved", OUT_DIR)
