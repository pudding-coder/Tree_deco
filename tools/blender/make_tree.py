"""크리스마스 트리 나무(장식 없음)를 만들어 .blend / .fbx 로 저장한다.

실행:
  GAP=1.0 NAME=ChristmasTree_generated /Applications/Blender.app/Contents/MacOS/Blender -b -P tools/blender/make_tree.py -- <출력폴더> [preview.png]

assets/models/ChristmasTree.blend/.fbx 는 이 스크립트로 만든 뒤 Blender에서 손으로 고친 것이다.
기본 이름(ChristmasTree_generated)은 그 파일을 덮어쓰지 않으려고 다르게 둔다.
"""
import math
import os
import sys

import bmesh
import bpy

argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
OUT_DIR = os.path.abspath(argv[0] if argv else "assets/models")
PREVIEW = argv[1] if len(argv) > 1 else None
os.makedirs(OUT_DIR, exist_ok=True)

SEGMENTS = 40  # 둘레 분할 수 (서브디비전 전)

# 단면 (r 비율, z 비율): 위 꼭대기 -> 바깥 둥근 테두리 -> 아랫면 -> 중심
PROFILE = [
    (0.00, 1.00),
    (0.22, 0.92),
    (0.45, 0.70),
    (0.68, 0.42),
    (0.88, 0.16),
    (1.00, 0.02),
    (1.03, -0.10),
    (0.96, -0.20),
    (0.82, -0.18),
    (0.55, -0.02),
    (0.25, 0.12),
    (0.00, 0.16),
]

# (반지름, 높이, 바닥 z, 물결 수, 회전)
TIERS = [
    (1.55, 0.95, 1.10, 9, 0.00),
    (1.32, 0.90, 1.78, 9, 0.20),
    (1.10, 0.85, 2.42, 8, 0.45),
    (0.86, 0.80, 3.02, 7, 0.10),
    (0.60, 0.80, 3.56, 6, 0.30),
]

# 층 간격 비율. 1보다 작으면 층이 더 겹친다. 실행할 때 GAP=0.75 처럼 바꿀 수 있다.
GAP = float(os.environ.get("GAP", "1.0"))
NAME = os.environ.get("NAME", "ChristmasTree_generated")
_base = TIERS[0][2]
TIERS = [(r, h, _base + (z - _base) * GAP, n, p) for r, h, z, n, p in TIERS]


def clear_scene():
    bpy.ops.wm.read_factory_settings(use_empty=True)


def make_material(name, color, roughness, spec=0.5):
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes["Principled BSDF"]
    bsdf.inputs["Base Color"].default_value = (*color, 1.0)
    bsdf.inputs["Roughness"].default_value = roughness
    if "Specular IOR Level" in bsdf.inputs:
        bsdf.inputs["Specular IOR Level"].default_value = spec
    return mat


def tier_mesh(bm, radius, height, base_z, lobes, phase):
    rings = []
    n = len(PROFILE)
    for i, (pr, pz) in enumerate(PROFILE):
        if pr == 0.0:
            rings.append(bm.verts.new((0.0, 0.0, base_z + pz * height)))
            continue
        # 바깥쪽일수록 물결이 커진다
        w = min(1.0, pr) ** 2
        ring = []
        for s in range(SEGMENTS):
            t = 2 * math.pi * s / SEGMENTS
            wave = math.cos(lobes * t + phase)
            r = radius * pr * (1 + 0.07 * wave * w)
            z = base_z + pz * height - 0.10 * height * wave * w  # 튀어나온 곳은 아래로 처진다
            ring.append(bm.verts.new((r * math.cos(t), r * math.sin(t), z)))
        rings.append(ring)

    for i in range(n - 1):
        a, b = rings[i], rings[i + 1]
        for s in range(SEGMENTS):
            s2 = (s + 1) % SEGMENTS
            if isinstance(a, list) and isinstance(b, list):
                bm.faces.new((a[s], b[s], b[s2], a[s2]))
            elif isinstance(a, list):  # b가 중심점
                bm.faces.new((a[s], b, a[s2]))
            else:  # a가 중심점
                bm.faces.new((a, b[s], b[s2]))


def make_foliage(mat):
    me = bpy.data.meshes.new("TreeFoliage")
    bm = bmesh.new()
    for radius, height, base_z, lobes, phase in TIERS:
        tier_mesh(bm, radius, height, base_z, lobes, phase)
    # 꼭대기 뾰족한 끝
    tip_base = TIERS[-1][2] + TIERS[-1][1] * 0.85
    bmesh.ops.create_cone(bm, cap_ends=True, segments=16, radius1=0.13, radius2=0.0,
                          depth=0.45, matrix=__import__("mathutils").Matrix.Translation((0, 0, tip_base + 0.2)))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bm.to_mesh(me)
    bm.free()
    obj = bpy.data.objects.new("TreeFoliage", me)
    bpy.context.collection.objects.link(obj)
    obj.data.materials.append(mat)
    sub = obj.modifiers.new("Subsurf", "SUBSURF")
    sub.levels = sub.render_levels = 1
    for p in me.polygons:
        p.use_smooth = True
    return obj


def make_trunk(mat):
    me = bpy.data.meshes.new("TreeTrunk")
    bm = bmesh.new()
    segs = 16
    # (반지름, z): 바닥이 살짝 퍼지고 위로 좁아진다
    prof = [(0.0, 0.0), (0.42, 0.0), (0.36, 0.08), (0.28, 0.30), (0.25, 0.70), (0.22, 1.30), (0.18, 2.4), (0.0, 2.4)]
    rings = []
    for r, z in prof:
        if r == 0.0:
            rings.append(bm.verts.new((0, 0, z)))
            continue
        ring = []
        for s in range(segs):
            t = 2 * math.pi * s / segs
            rr = r * (1 + 0.04 * math.sin(5 * t))  # 나무껍질 울퉁불퉁
            ring.append(bm.verts.new((rr * math.cos(t), rr * math.sin(t), z)))
        rings.append(ring)
    for i in range(len(rings) - 1):
        a, b = rings[i], rings[i + 1]
        for s in range(segs):
            s2 = (s + 1) % segs
            if isinstance(a, list) and isinstance(b, list):
                bm.faces.new((a[s], a[s2], b[s2], b[s]))
            elif isinstance(a, list):
                bm.faces.new((a[s], a[s2], b))
            else:
                bm.faces.new((a, b[s2], b[s]))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bm.to_mesh(me)
    bm.free()
    obj = bpy.data.objects.new("TreeTrunk", me)
    bpy.context.collection.objects.link(obj)
    obj.data.materials.append(mat)
    sub = obj.modifiers.new("Subsurf", "SUBSURF")
    sub.levels = sub.render_levels = 1
    for p in me.polygons:
        p.use_smooth = True
    return obj


def apply_modifiers(obj):
    bpy.context.view_layer.objects.active = obj
    for m in list(obj.modifiers):
        bpy.ops.object.modifier_apply(modifier=m.name)


def tri_count(obj):
    return sum(len(p.vertices) - 2 for p in obj.data.polygons)


def setup_preview(path):
    scene = bpy.context.scene
    scene.render.engine = "BLENDER_EEVEE_NEXT" if "BLENDER_EEVEE_NEXT" in [e.identifier for e in bpy.types.RenderSettings.bl_rna.properties["engine"].enum_items] else "BLENDER_EEVEE"
    scene.render.resolution_x, scene.render.resolution_y = 768, 1024
    world = bpy.data.worlds.new("World")
    scene.world = world
    world.use_nodes = True
    world.node_tree.nodes["Background"].inputs[0].default_value = (0.08, 0.30, 0.15, 1)
    world.node_tree.nodes["Background"].inputs[1].default_value = 0.35

    cam_data = bpy.data.cameras.new("Cam")
    cam_data.lens = 70
    cam = bpy.data.objects.new("Cam", cam_data)
    scene.collection.objects.link(cam)
    cam.location = (0, -11.5, 3.2)
    cam.rotation_euler = (math.radians(87), 0, 0)
    scene.camera = cam

    for loc, energy in (((4, -5, 7), 900), ((-5, -3, 4), 300), ((0, 5, 6), 400)):
        ld = bpy.data.lights.new("L", "AREA")
        ld.energy = energy
        ld.size = 4
        lo = bpy.data.objects.new("L", ld)
        lo.location = loc
        d = lo.location.copy()
        lo.rotation_euler = (-d).to_track_quat("-Z", "Y").to_euler()
        scene.collection.objects.link(lo)
    scene.render.filepath = path
    bpy.ops.render.render(write_still=True)


def main():
    clear_scene()
    green = make_material("Foliage", (0.045, 0.16, 0.025), 0.3)
    brown = make_material("Bark", (0.22, 0.11, 0.05), 0.6)
    foliage = make_foliage(green)
    trunk = make_trunk(brown)
    for o in (foliage, trunk):
        apply_modifiers(o)
        print(f"{o.name}: {tri_count(o)} triangles")

    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(OUT_DIR, f"{NAME}.blend"))
    bpy.ops.object.select_all(action="SELECT")
    # Roblox: 1 스터드 = 0.28m 정도라 크기는 Studio에서 맞춘다. 위쪽은 Y.
    bpy.ops.export_scene.fbx(
        filepath=os.path.join(OUT_DIR, f"{NAME}.fbx"),
        use_selection=True, apply_unit_scale=True, axis_forward="-Z", axis_up="Y",
        mesh_smooth_type="FACE", object_types={"MESH"},
    )
    if PREVIEW:
        setup_preview(PREVIEW)


main()
