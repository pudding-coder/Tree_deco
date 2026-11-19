"""별 기둥(StarPole)의 별을 면이 깎인 입체 별로 다시 만들어 .blend / .fbx 로 저장한다.

원래 StarPole.fbx(맵 에셋)를 불러와 별 파트(StarPole_GlowGold)만 바꾸고 나머지(받침·기둥·재질 이름)는 그대로 둔다.
별: 가운데가 앞뒤로 볼록하고 가장자리는 얇은 별(앞뒤 피라미드 두 개를 붙인 모양). 면은 각지게(로우폴리).

실행:
  /Applications/Blender.app/Contents/MacOS/Blender -b -P tools/blender/make_starpole.py -- assets/models/map/StarPole.fbx assets/models/map
출력: <폴더>/StarPole.fbx(색 그림 포함), StarPole.blend, StarPole_palette.png
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

# ---------------------------------------------------------------- 색을 그림(팔레트)으로 구워 넣기
# Roblox Import 3D는 재질 색은 안 가져오고 그림(텍스처)만 가져온다. 색마다 칸이 하나씩 있는 작은 그림을 만들고,
# 면마다 자기 색 칸을 가리키게(UV) 해서 FBX에 그림을 함께 넣는다. 그러면 불러오기만 해도 색이 보인다.
PALETTE = {  # 이름: (R, G, B) 0~255
    "StarLight": (240, 200, 60),  # 별 뿔의 밝은 쪽
    "StarDark": (196, 150, 30),  # 별 뿔의 진한 쪽 (밝은 쪽과 번갈아 윤곽이 보이게)
    "Pole": (38, 38, 42),  # 기둥
    "Collar": (30, 30, 34),  # 기둥 아래 받침 고리
    "Cap": (45, 45, 50),  # 별 아래 캡
    "BaseTop": (52, 52, 58),  # 받침 윗단
    "BaseRim": (110, 70, 45),  # 받침 아랫단 (갈색 테두리)
}
PART_COLOR = {  # 파트 이름: 팔레트 이름 (별은 아래에서 따로)
    "StarPole_Wood": "Pole",
    "StarPole_WoodDark": "Collar",
    "StarPole_Gold": "Cap",
    "StarPole_Cream": "BaseTop",
    "StarPole_Stone": "BaseRim",
}
CELLS = 4  # 그림을 4×4칸으로 나눈다 (16색까지)
SIZE = 64
names = list(PALETTE)
image = bpy.data.images.new("StarPole_palette", SIZE, SIZE)
pixels = [0.0] * (SIZE * SIZE * 4)


cell = SIZE // CELLS
for i, name in enumerate(names):
    cx, cy_ = i % CELLS, i // CELLS
    rgb = PALETTE[name]
    for y in range(cy_ * cell, (cy_ + 1) * cell):
        for x in range(cx * cell, (cx + 1) * cell):
            j = (y * SIZE + x) * 4
            pixels[j:j + 4] = [c / 255 for c in rgb] + [1.0]
image.pixels = pixels
image.filepath_raw = os.path.join(OUT_DIR, "StarPole_palette.png")
image.file_format = "PNG"
image.save()


def cell_uv(name):
    i = names.index(name)
    return ((i % CELLS + 0.5) / CELLS, (i // CELLS + 0.5) / CELLS)


material = bpy.data.materials.new("StarPole_Palette")
material.use_nodes = True
nodes = material.node_tree.nodes
tex = nodes.new("ShaderNodeTexImage")
tex.image = image
tex.interpolation = "Closest"  # 칸 경계가 섞이지 않게
material.node_tree.links.new(tex.outputs["Color"], nodes["Principled BSDF"].inputs["Base Color"])

for obj in [o for o in bpy.data.objects if o.type == "MESH"]:
    mesh = obj.data
    mesh.materials.clear()
    mesh.materials.append(material)
    uv = mesh.uv_layers.new(name="UVMap") if not mesh.uv_layers else mesh.uv_layers[0]
    for poly in mesh.polygons:
        if obj.name == "StarPole_GlowGold":
            # 별: 면이 20개(앞 10, 뒤 10). 뿔마다 왼쪽·오른쪽 면을 밝게·진하게 번갈아 칠한다
            name = "StarLight" if (poly.index // 2) % 2 == 0 else "StarDark"
        else:
            name = PART_COLOR.get(obj.name, "Pole")
        u, v = cell_uv(name)
        for li in poly.loop_indices:
            uv.data[li].uv = (u, v)
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(OUT_DIR, "StarPole.blend"))
bpy.ops.export_scene.fbx(
    filepath=os.path.join(OUT_DIR, "StarPole.fbx"),
    use_selection=False,
    axis_forward="-Z",
    axis_up="Y",
    apply_unit_scale=True,
    apply_scale_options="FBX_SCALE_NONE",
    mesh_smooth_type="FACE",
    path_mode="COPY",
    embed_textures=True,  # 팔레트 그림을 FBX 안에 넣는다
    object_types={"EMPTY", "MESH"},
)
print("[starpole] saved", OUT_DIR)
