"""맵(크리스마스 마켓 광장) 로우폴리 에셋을 만들어 .blend / .fbx 로 저장한다. 목록·크기: docs/MAP_ASSETS.md

실행 (Blender):
  /Applications/Blender.app/Contents/MacOS/Blender -b -P tools/blender/make_map_assets.py -- assets/models/map [preview.png]
실행 (pip install bpy 한 파이썬):
  python tools/blender/make_map_assets.py -- assets/models/map [preview.png]

규칙
- 1 Blender 단위 = 1 스터드. Studio에서 가져올 때 크기가 다르면 docs/MAP_ASSETS.md의 크기 표에 맞춘다.
- 원점 = 바닥 가운데. 앞면 = -Y (FBX에서는 -Z = Studio의 Front).
- 텍스처 없음. 색 하나 = 오브젝트 하나 (Studio에서 MeshPart 하나가 되고 Color로 칠한다).
- 이름이 Glow로 시작하는 파트는 Studio에서 Material을 Neon으로 바꾸면 불이 켜진 것처럼 보인다.
"""
import math
import os
import sys

import bpy  # isort: skip  (pip로 깐 bpy에서는 bpy를 먼저 불러야 bmesh가 잡힌다)
import bmesh
from mathutils import Matrix, Vector

argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
OUT_DIR = os.path.abspath(argv[0] if argv else "assets/models/map")
PREVIEW = argv[1] if len(argv) > 1 else None
os.makedirs(OUT_DIR, exist_ok=True)

# 색 (RGB 0~255). 이름이 오브젝트 이름 뒤에 붙는다
COLORS = {
    "Wood": (138, 86, 50),
    "WoodDark": (95, 58, 32),
    "WoodLight": (176, 122, 76),
    "Snow": (244, 248, 255),
    "Cream": (246, 241, 230),
    "Red": (216, 50, 58),
    "Green": (47, 154, 92),
    "GreenDark": (37, 107, 75),
    "Purple": (138, 92, 240),
    "Blue": (58, 111, 216),
    "Gold": (255, 216, 74),
    "Iron": (43, 47, 58),
    "Stone": (141, 127, 134),
    "Orange": (255, 154, 60),
    "Coal": (30, 30, 34),
    "GlowWarm": (255, 226, 150),
    "GlowGold": (255, 216, 74),
    "GlowRed": (232, 65, 60),
    "GlowBlue": (90, 160, 240),
    "GlowGreen": (120, 230, 190),
    "Potion": (180, 92, 255),
    "Glass": (191, 230, 255),
}

materials = {}


def material(name):
    if name in materials:
        return materials[name]
    r, g, b = (c / 255 for c in COLORS[name])
    lin = tuple(c ** 2.2 for c in (r, g, b))
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes["Principled BSDF"]
    bsdf.inputs["Base Color"].default_value = (*lin, 1.0)
    bsdf.inputs["Roughness"].default_value = 0.8
    if name.startswith("Glow"):
        bsdf.inputs["Emission Color"].default_value = (*lin, 1.0)
        bsdf.inputs["Emission Strength"].default_value = 6.0
    mat.diffuse_color = (*lin, 1.0)
    materials[name] = mat
    return mat


def T(x=0, y=0, z=0):
    return Matrix.Translation((x, y, z))


def RX(deg):
    return Matrix.Rotation(math.radians(deg), 4, "X")


def RY(deg):
    return Matrix.Rotation(math.radians(deg), 4, "Y")


def RZ(deg):
    return Matrix.Rotation(math.radians(deg), 4, "Z")


def S(x, y, z):
    return Matrix.Diagonal((x, y, z, 1))


class Asset:
    """색별로 메시를 모았다가 색 하나당 오브젝트 하나로 만든다"""

    def __init__(self, name):
        self.name = name
        self.parts = {}

    def bm(self, color):
        if color not in self.parts:
            self.parts[color] = bmesh.new()
        return self.parts[color]

    def box(self, color, sx, sy, sz, x=0, y=0, z=0, rot=None):
        """z는 상자 바닥 높이"""
        m = T(x, y, z + sz / 2) @ (rot or Matrix.Identity(4)) @ S(sx, sy, sz)
        bmesh.ops.create_cube(self.bm(color), size=1, matrix=m)

    def cyl(self, color, r1, r2, h, x=0, y=0, z=0, seg=8, rot=None):
        """z는 바닥 높이. r2=0이면 원뿔"""
        m = T(x, y, z) @ (rot or Matrix.Identity(4)) @ T(0, 0, h / 2)
        bmesh.ops.create_cone(self.bm(color), cap_ends=True, segments=seg, radius1=r1, radius2=r2, depth=h, matrix=m)

    def ball(self, color, r, x=0, y=0, z=0, sub=1, scale=(1, 1, 1)):
        """z는 공 가운데 높이"""
        m = T(x, y, z) @ S(*scale)
        bmesh.ops.create_icosphere(self.bm(color), subdivisions=sub, radius=r, matrix=m)

    def prism(self, color, pts, depth, x=0, y=0, z=0):
        """XZ 평면의 다각형(pts)을 Y 방향으로 depth만큼 두껍게. 앞면이 -Y"""
        bm = self.bm(color)
        front = [bm.verts.new((x + px, y - depth / 2, z + pz)) for px, pz in pts]
        back = [bm.verts.new((x + px, y + depth / 2, z + pz)) for px, pz in pts]
        n = len(pts)
        # 오목한 다각형도 되게 가운데 점에서 부채꼴로 채운다
        cx = sum(p[0] for p in pts) / n
        cz = sum(p[1] for p in pts) / n
        cf = bm.verts.new((x + cx, y - depth / 2, z + cz))
        cb = bm.verts.new((x + cx, y + depth / 2, z + cz))
        for i in range(n):
            j = (i + 1) % n
            bm.faces.new((cf, front[i], front[j]))
            bm.faces.new((cb, back[j], back[i]))
            bm.faces.new((front[i], back[i], back[j], front[j]))

    def tube(self, color, pts, r, seg=6):
        """점들을 잇는 굵은 줄 (아치, 팔 등)"""
        for a, b in zip(pts, pts[1:]):
            a, b = Vector(a), Vector(b)
            d = b - a
            rot = d.to_track_quat("Z", "Y").to_matrix().to_4x4()
            m = T(*a) @ rot @ T(0, 0, d.length / 2)
            bmesh.ops.create_cone(self.bm(color), cap_ends=True, segments=seg, radius1=r, radius2=r, depth=d.length * 1.08, matrix=m)

    def build(self):
        root = bpy.data.objects.new(self.name, None)
        bpy.context.collection.objects.link(root)
        objs = []
        tris = 0
        for color, bm in self.parts.items():
            bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
            me = bpy.data.meshes.new(f"{self.name}_{color}")
            bm.to_mesh(me)
            bm.free()
            obj = bpy.data.objects.new(f"{self.name}_{color}", me)
            bpy.context.collection.objects.link(obj)
            obj.data.materials.append(material(color))
            obj.parent = root
            tris += sum(len(p.vertices) - 2 for p in me.polygons)
            objs.append(obj)
        return root, objs, tris


# ---------------------------------------------------------------- 에셋


def stall(name, awning, icon):
    """마켓 부스: 폭 14 x 깊이 9 x 높이 약 15 (간판·아이콘 포함)"""
    a = Asset(name)
    a.box("Wood", 14, 7, 3.5, y=0.5)  # 판매대 몸통
    a.box("WoodLight", 15, 8, 0.4, y=0.3, z=3.5)  # 판매대 윗판
    a.box("WoodDark", 14, 0.5, 9, y=3.75)  # 뒷벽
    for px in (-6.7, 6.7):
        for py in (-2.7, 3.7):
            a.box("WoodDark", 0.6, 0.6, 9, x=px, y=py)
    a.box("GlowWarm", 12.6, 0.2, 4.6, y=3.4, z=4.1)  # 불 켜진 안쪽
    # 진열 상품
    for i, c in enumerate(["GlowRed", "Gold", "GlowBlue", "GlowGreen", "GlowRed", "Gold"]):
        a.ball(c, 0.55, x=-5 + i * 2, y=-1.2, z=4.45)
    # 줄무늬 차양 (앞이 낮고 뒤가 높다)
    slope = math.degrees(math.atan2(2.6, 10))
    length = math.hypot(2.6, 10)
    n = 8
    for i in range(n):
        w = 16 / n
        a.box(awning if i % 2 == 0 else "Cream", w, length, 0.35, x=-8 + w * (i + 0.5), y=-0.6, z=9.35, rot=RX(slope))
    a.box("Snow", 15.4, length * 0.5, 0.5, y=1.8, z=10.25, rot=RX(slope))  # 지붕에 쌓인 눈
    # 차양 아래 전구 줄
    for i in range(9):
        a.ball("GlowWarm", 0.28, x=-7.2 + i * 1.8, y=-5.3, z=7.75, sub=1)
    # 간판 (글자는 Studio에서 SurfaceGui로)
    a.box("WoodDark", 8, 0.5, 2.4, y=-3.2, z=10.3)
    a.box("Snow", 8.4, 0.9, 0.4, y=-3.2, z=12.7)
    # 아이콘
    iz = 14.6
    if icon == "wheel":
        a.cyl("Gold", 1.9, 1.9, 0.5, y=-3.2 + 0.25, z=iz, seg=12, rot=RX(90))
        for k in range(6):
            t = math.radians(k * 60 + 30)
            a.ball(["GlowRed", "GlowBlue", "GlowGreen"][k % 3], 0.42, x=1.25 * math.cos(t), y=-3.55, z=iz + 1.25 * math.sin(t))
        a.ball("Iron", 0.35, y=-3.55, z=iz)
        a.prism("Red", [(-0.5, 1.1), (0.5, 1.1), (0, 0)], 0.4, y=-3.2, z=iz + 1.7)
    elif icon == "arrow":
        a.prism("GlowGold", [(0, 2.2), (1.8, 0.2), (0.7, 0.2), (0.7, -1.8), (-0.7, -1.8), (-0.7, 0.2), (-1.8, 0.2)], 0.7, y=-3.2, z=iz + 0.2)
    elif icon == "potion":
        a.ball("Potion", 1.4, y=-3.2, z=iz - 0.3, sub=1, scale=(1, 0.8, 0.95))
        a.cyl("Glass", 0.45, 0.45, 1.3, y=-3.2, z=iz + 0.7, seg=8)
        a.cyl("WoodLight", 0.5, 0.4, 0.45, y=-3.2, z=iz + 2.0, seg=8)
    return a


def lamp_post():
    """가로등: 높이 12"""
    a = Asset("LampPost")
    a.cyl("Iron", 0.9, 0.7, 0.6, seg=8)
    a.cyl("Iron", 0.25, 0.2, 9.4, z=0.6, seg=6)
    a.cyl("Iron", 0.8, 0.8, 0.25, z=10.0, seg=6)
    a.cyl("GlowWarm", 0.55, 0.75, 1.4, z=10.25, seg=6)
    a.cyl("Iron", 1.0, 0.0, 0.7, z=11.65, seg=6)
    a.cyl("Snow", 0.6, 0.0, 0.45, z=11.95, seg=6)
    return a


def star_pole():
    """가운데 별 기둥(스폰): 단 지름 12, 높이 약 27"""
    a = Asset("StarPole")
    a.cyl("Stone", 6, 6, 0.8, seg=12)
    a.cyl("Cream", 5, 5, 0.5, z=0.8, seg=12)
    a.cyl("WoodDark", 1.0, 0.8, 1.5, z=1.3, seg=8)
    a.cyl("Wood", 0.5, 0.4, 20, z=1.3, seg=8)
    a.cyl("Gold", 0.8, 0.8, 0.5, z=21.0, seg=8)  # 전구 줄을 묶는 고리 자리
    pts = []
    for i in range(10):
        t = math.pi / 2 + i * math.pi / 5
        r = 3.2 if i % 2 == 0 else 1.35
        pts.append((r * math.cos(t), r * math.sin(t)))
    a.prism("GlowGold", pts, 1.0, z=24.2)
    return a


def plot_base():
    """트리 자리 단: 지름 18, 높이 1.2 (트리 폭 약 13)"""
    a = Asset("PlotBase")
    a.cyl("Wood", 9, 9, 0.8, seg=14)
    a.cyl("Snow", 8.6, 8.2, 0.4, z=0.8, seg=14)
    for i in range(14):
        t = 2 * math.pi * (i + 0.5) / 14
        a.ball(["GlowRed", "GlowGold", "GlowBlue", "GlowGreen"][i % 4], 0.32, x=8.95 * math.cos(t), y=8.95 * math.sin(t), z=0.75)
    # 이름표 말뚝 (앞쪽)
    a.box("WoodDark", 0.4, 0.4, 2.4, x=6.3, y=-6.3, z=0.8)
    a.box("WoodLight", 3.2, 0.3, 1.4, x=6.3, y=-6.5, z=2.4)
    return a


def photo_arch():
    """포토존 아치: 폭 22, 높이 약 18"""
    a = Asset("PhotoArch")
    pts = [(-10, 0, 0), (-10, 0, 6)]
    for i in range(1, 12):
        t = math.pi - i * math.pi / 12
        pts.append((10 * math.cos(t), 0, 6 + 9 * math.sin(t)))
    pts += [(10, 0, 6), (10, 0, 0)]
    a.tube("GreenDark", pts, 1.1, seg=6)
    cols = ["GlowRed", "GlowGold", "GlowBlue", "GlowGreen"]
    k = 0
    for (p, q) in zip(pts, pts[1:]):
        for f in (0.25, 0.75):
            x, z = p[0] + (q[0] - p[0]) * f, p[2] + (q[2] - p[2]) * f
            a.ball(cols[k % 4], 0.4, x=x, y=-1.15, z=z)
            k += 1
    for sx in (-10, 10):
        a.cyl("WoodDark", 1.6, 1.4, 1.0, x=sx, seg=8)
        a.cyl("Snow", 1.5, 0.6, 0.5, x=sx, z=1.0, seg=8)
    a.box("WoodDark", 9, 0.6, 2.6, y=-0.6, z=15.3)  # 간판 (글자는 SurfaceGui)
    a.box("Snow", 9.6, 1.2, 0.5, y=-0.6, z=17.9)
    return a


def gift_box():
    """큰 선물상자: 6 x 6 x 6 (+리본)"""
    a = Asset("GiftBox")
    a.box("Red", 6, 6, 5.2)
    a.box("Red", 6.4, 6.4, 1.0, z=5.0)  # 뚜껑
    a.box("Gold", 1.0, 6.5, 6.05)
    a.box("Gold", 6.5, 1.0, 6.05)
    for sx in (-1, 1):
        a.ball("Gold", 1.1, x=sx * 1.0, z=6.7, sub=1, scale=(1.2, 0.6, 0.8))
    a.ball("Gold", 0.5, z=6.5)
    a.box("Snow", 5.6, 5.6, 0.3, z=6.0)
    return a


def snowman():
    """눈사람: 높이 약 9"""
    a = Asset("Snowman")
    a.ball("Snow", 2.4, z=2.1, sub=2, scale=(1, 1, 0.9))
    a.ball("Snow", 1.75, z=5.0, sub=2, scale=(1, 1, 0.92))
    a.ball("Snow", 1.25, z=7.2, sub=2)
    a.cyl("Coal", 1.5, 1.5, 0.2, z=8.1, seg=10)
    a.cyl("Coal", 1.0, 0.95, 1.3, z=8.3, seg=10)
    a.cyl("Red", 1.02, 1.0, 0.3, z=8.35, seg=10)
    a.cyl("Red", 1.35, 1.45, 0.55, z=6.0, seg=10)  # 목도리
    a.box("Red", 0.7, 0.3, 1.8, x=0.9, y=-1.25, z=4.4)
    a.cyl("Orange", 0.22, 0.0, 1.2, y=-1.15, z=7.2, seg=6, rot=RX(90))
    for sx in (-0.45, 0.45):
        a.ball("Coal", 0.15, x=sx, y=-1.12, z=7.55)
    for bz in (4.3, 5.1, 5.9):
        a.ball("Coal", 0.17, y=-1.72 if bz < 5.5 else -1.5, z=bz)
    a.tube("WoodDark", [(-1.5, 0, 5.3), (-3.3, 0, 6.6)], 0.12, seg=5)
    a.tube("WoodDark", [(1.5, 0, 5.3), (3.3, 0, 6.4)], 0.12, seg=5)
    return a


def bench():
    """벤치: 폭 8, 깊이 3, 높이 4"""
    a = Asset("Bench")
    for i in range(3):
        a.box("Wood", 8, 0.75, 0.3, y=-0.9 + i * 0.9, z=1.8)
    for i in range(2):
        a.box("Wood", 8, 0.3, 0.8, y=1.25, z=2.5 + i * 0.95)
    for sx in (-3.4, 3.4):
        a.box("Iron", 0.4, 2.6, 0.4, x=sx, z=1.4)
        a.box("Iron", 0.4, 0.4, 1.4, x=sx, y=-1.0)
        a.box("Iron", 0.4, 0.4, 4.0, x=sx, y=1.1)
    a.box("Snow", 7.6, 1.0, 0.25, y=0.4, z=2.1)
    return a


def leaderboard():
    """리더보드 판: 폭 14, 높이 16 (Screen 파트 앞면에 SurfaceGui)"""
    a = Asset("Leaderboard")
    for sx in (-6, 6):
        a.box("Wood", 0.9, 0.9, 15, x=sx)
        a.cyl("Snow", 0.8, 0.0, 0.6, x=sx, z=15, seg=6)
    a.box("WoodDark", 13, 0.7, 10, z=4.5)
    a.box("Iron", 11.6, 0.2, 8.6, y=-0.4, z=5.2)  # Screen
    a.box("Snow", 13.6, 1.3, 0.6, z=14.5)
    a.box("WoodLight", 6, 0.4, 1.6, y=-0.6, z=14.2)  # 제목판
    return a


def pine_tree():
    """숲 나무: 높이 22, 폭 12"""
    a = Asset("PineTree")
    a.cyl("WoodDark", 0.9, 0.7, 3.5, seg=6)
    for i, (r, z, h) in enumerate([(6, 2.5, 7), (4.9, 6.8, 6.4), (3.8, 10.8, 5.8), (2.7, 14.4, 5.2)]):
        a.cyl("Green" if i % 2 == 0 else "GreenDark", r, 0.0, h, z=z, seg=7, rot=RZ(i * 25))
        a.cyl("Snow", r * 0.55, 0.0, h * 0.55, z=z + h * 0.47, seg=7, rot=RZ(i * 25))
    return a


def snow_hill():
    """눈 언덕: 폭 60, 깊이 44, 높이 16"""
    a = Asset("SnowHill")
    bm = a.bm("Snow")
    bmesh.ops.create_icosphere(bm, subdivisions=2, radius=1, matrix=S(30, 22, 16))
    import random
    rnd = random.Random(3)
    for v in bm.verts:
        v.co += Vector((rnd.uniform(-1.6, 1.6), rnd.uniform(-1.6, 1.6), rnd.uniform(-1.2, 1.2)))
    geom = bm.verts[:] + bm.edges[:] + bm.faces[:]
    bmesh.ops.bisect_plane(bm, geom=geom, plane_co=(0, 0, 0), plane_no=(0, 0, 1), clear_inner=True)
    return a


def string_light():
    """전구 줄 한 칸: 길이 4 (Studio에서 이어 붙이거나 Beam으로 대신해도 된다)"""
    a = Asset("StringLight")
    a.tube("Iron", [(-2, 0, 0.5), (0, 0, 0.3), (2, 0, 0.5)], 0.06, seg=4)
    a.cyl("Iron", 0.14, 0.14, 0.2, z=0.1, seg=6)
    a.ball("GlowWarm", 0.3, z=-0.15)
    return a


ASSETS = [
    lambda: stall("StallRoulette", "Red", "wheel"),
    lambda: stall("StallUpgrade", "Green", "arrow"),
    lambda: stall("StallPotion", "Purple", "potion"),
    star_pole, plot_base, lamp_post, photo_arch, gift_box, snowman, bench, leaderboard, pine_tree, snow_hill, string_light,
]


# ---------------------------------------------------------------- 저장


def export_fbx(root, objs):
    bpy.ops.object.select_all(action="DESELECT")
    root.select_set(True)
    for o in objs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = root
    bpy.ops.export_scene.fbx(
        filepath=os.path.join(OUT_DIR, f"{root.name}.fbx"),
        use_selection=True, apply_unit_scale=True, axis_forward="-Z", axis_up="Y",
        mesh_smooth_type="FACE", object_types={"MESH", "EMPTY"},
    )


def render_preview(path, extent):
    scene = bpy.context.scene
    scene.render.engine = "CYCLES"
    scene.cycles.samples = 96
    scene.cycles.use_denoising = True
    scene.render.resolution_x, scene.render.resolution_y = 1800, 1000
    world = bpy.data.worlds.new("World")
    scene.world = world
    world.use_nodes = True
    world.node_tree.nodes["Background"].inputs[0].default_value = (0.03, 0.05, 0.14, 1)
    world.node_tree.nodes["Background"].inputs[1].default_value = 1.0

    ground = bpy.data.meshes.new("Ground")
    gb = bmesh.new()
    bmesh.ops.create_grid(gb, x_segments=1, y_segments=1, size=400)
    gb.to_mesh(ground)
    gb.free()
    gobj = bpy.data.objects.new("PreviewGround", ground)
    scene.collection.objects.link(gobj)
    gobj.data.materials.append(material("Snow"))

    cam_data = bpy.data.cameras.new("Cam")
    cam_data.type = "ORTHO"
    cam_data.ortho_scale = extent
    cam = bpy.data.objects.new("Cam", cam_data)
    scene.collection.objects.link(cam)
    cam.location = (45, -170, 75)
    cam.rotation_euler = ((Vector((0, 0, 6)) - cam.location)).to_track_quat("-Z", "Y").to_euler()
    scene.camera = cam

    sun = bpy.data.lights.new("Moon", "SUN")
    sun.energy = 2.2
    sun.color = (0.75, 0.82, 1.0)
    so = bpy.data.objects.new("Moon", sun)
    so.rotation_euler = (math.radians(50), 0, math.radians(35))
    scene.collection.objects.link(so)
    scene.render.filepath = path
    bpy.ops.render.render(write_still=True)
    for o in (gobj, cam, so):
        bpy.data.objects.remove(o)


def main():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    built = []
    for make in ASSETS:
        root, objs, tris = make().build()
        export_fbx(root, objs)
        box = [o.matrix_world @ Vector(c) for o in objs for c in o.bound_box]
        size = [max(v[i] for v in box) - min(v[i] for v in box) for i in range(3)]
        print(f"ASSET {root.name}: {tris} tris, {len(objs)} parts, size {size[0]:.1f} x {size[1]:.1f} x {size[2]:.1f} (폭 x 깊이 x 높이)")
        built.append((root, size))

    # 한 장면에 늘어놓기 (.blend와 미리보기용)
    rows = [built[:5], built[5:10], built[10:]]
    y = 0
    for row in rows:
        width = sum(s[0] for _, s in row) + 8 * (len(row) - 1)
        x = -width / 2
        for root, s in row:
            root.location = (x + s[0] / 2, y, 0)
            x += s[0] + 8
        y -= 34
    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(OUT_DIR, "MapAssets.blend"))
    if PREVIEW:
        for root, _ in built:
            root.location.y += 30
        render_preview(PREVIEW, 150)


main()
