#!/usr/bin/env python3
# tools/build_places.py
# Purpose: Writes the village, harbor, orchard, and cave scenes from one readable layout list.
# Run from the project root: python3 tools/build_places.py

import os
import random
import struct
import zlib

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
HOME = "res://src/scenes/world/home/Home.tscn"
VILLAGE = "res://src/scenes/world/village/Village.tscn"
HARBOR = "res://src/scenes/world/harbor/Harbor.tscn"
ORCHARD = "res://src/scenes/world/orchard/Orchard.tscn"
ROAD = "res://src/scenes/world/road/Road.tscn"
FOREST = "res://src/scenes/world/forest/Forest.tscn"


def write_png(path, width, height, pixels):
    rows = b"".join(b"\x00" + bytes(c for px in pixels[y * width:(y + 1) * width] for c in px) for y in range(height))

    def chunk(tag, data):
        return struct.pack(">I", len(data)) + tag + data + struct.pack(">I", zlib.crc32(tag + data) & 0xFFFFFFFF)

    header = struct.pack(">IIBBBBB", width, height, 8, 6, 0, 0, 0)
    with open(path, "wb") as out:
        out.write(b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", header) + chunk(b"IDAT", zlib.compress(rows, 9)) + chunk(b"IEND", b""))


def draw_grass():
    path = os.path.join(ROOT, "assets/props/ground_grass.png")
    rng = random.Random(7)
    shades = [(126, 166, 92, 255), (118, 158, 86, 255), (134, 174, 98, 255)]
    pixels = [shades[0]] * 256
    for i in range(256):
        pixels[i] = shades[rng.choice([0, 0, 0, 1, 2])]
    for x, y in [(3, 4), (11, 2), (7, 10), (13, 12), (2, 13)]:
        pixels[y * 16 + x] = (98, 140, 72, 255)
        pixels[(y - 1) * 16 + x] = (108, 150, 78, 255)
    write_png(path, 16, 16, pixels)


class Scene:
    def __init__(self, name, sort=True, k=1):
        self.name = name
        # Every position and floor is multiplied by k, so a place can grow while people keep their size.
        self.k = k
        self.sort = sort
        self.ext = []
        self.sub = []
        self.nodes = []

    def res(self, kind, path):
        for rid, k, p in self.ext:
            if p == path:
                return rid
        rid = "%d_%s" % (len(self.ext) + 1, os.path.splitext(os.path.basename(path))[0].replace(" ", "_").lower()[:12])
        self.ext.append((rid, kind, path))
        return rid

    def box(self, w, h):
        sid = "Rect_%dx%d" % (w, h)
        if not any(s[0] == sid for s in self.sub):
            self.sub.append((sid, "RectangleShape2D", "size = Vector2(%d, %d)" % (w, h)))
        return sid

    def node(self, name, kind, parent=".", props=None):
        self.nodes.append((name, kind, parent, props or []))

    def ground(self, name, texture, points):
        self.node(name, "Polygon2D", props=[
            "texture_filter = 1",
            "texture_repeat = 2",
            'texture = ExtResource("%s")' % self.res("Texture2D", texture),
            "polygon = PackedVector2Array(%s)" % ", ".join("%d, %d" % p for p in points),
        ])

    def rect_ground(self, name, texture, x, y, w, h):
        k = self.k
        x, y, w, h = int(x * k), int(y * k), int(w * k), int(h * k)
        self.ground(name, texture, [(x, y), (x + w, y), (x + w, y + h), (x, y + h)])

    def mark(self, name, texture, x, y, fit=0, feet=True, block=None, group="", role=""):
        props = [
            "position = Vector2(%d, %d)" % (x * self.k, y * self.k),
            'script = ExtResource("%s")' % self.res("Script", "res://src/scripts/World/spot_mark.gd"),
            'person = ExtResource("%s")' % self.res("Texture2D", texture),
        ]
        if fit:
            props.append("fit_pixels = %d" % fit)
        if feet:
            props.append("stand_on_feet = true")
        if group:
            props.append('group_name = "%s"' % group)
        if role:
            props.append('role = "%s"' % role)
        if block:
            props.append("block_size = Vector2(%d, %d)" % block)
        self.node(name, "Node2D", props=props)

    def route(self, person, spots, hours):
        self.node("Route", "Node", parent=person, props=[
            'script = ExtResource("%s")' % self.res("Script", "res://src/scripts/World/npc_route.gd"),
            "spots = PackedVector2Array(%s)" % ", ".join("%d, %d" % (s[0] * self.k, s[1] * self.k) for s in spots),
            "hours = PackedFloat32Array(%s)" % ", ".join("%g" % h for h in hours),
        ])

    def door(self, name, x, y, scene, spawn, w=28, h=16):
        self.node(name, "Area2D", props=[
            "position = Vector2(%d, %d)" % (x * self.k, y * self.k),
            'script = ExtResource("%s")' % self.res("Script", "res://src/scripts/house/door.gd"),
            'next_scene_path = "%s"' % scene,
            'spawn_name = "%s"' % spawn,
        ])
        self.node("CollisionShape2D", "CollisionShape2D", parent=name, props=['shape = SubResource("%s")' % self.box(int(w * self.k), int(h * self.k))])

    def area(self, name, script, x, y, w=16, h=16):
        self.node(name, "Area2D", props=[
            "position = Vector2(%d, %d)" % (x * self.k, y * self.k),
            'script = ExtResource("%s")' % self.res("Script", script),
        ])
        self.node("CollisionShape2D", "CollisionShape2D", parent=name, props=['shape = SubResource("%s")' % self.box(int(w * self.k), int(h * self.k))])

    def spawn(self, name, x, y):
        self.node(name, "Marker2D", props=["position = Vector2(%d, %d)" % (x * self.k, y * self.k)])

    def bounds(self, x, y, w, h, blocks=()):
        props = [
            'script = ExtResource("%s")' % self.res("Script", "res://src/scripts/World/place_bounds.gd"),
            "area = Rect2(%d, %d, %d, %d)" % (x * self.k, y * self.k, w * self.k, h * self.k),
        ]
        if blocks:
            props.append("blocks = Array[Rect2]([%s])" % ", ".join("Rect2(%d, %d, %d, %d)" % tuple(n * self.k for n in b) for b in blocks))
        self.node("Bounds", "Node2D", props=props)

    def save(self, rel_path):
        lines = ["[gd_scene format=3]", ""]
        for rid, kind, path in self.ext:
            lines.append('[ext_resource type="%s" path="%s" id="%s"]' % (kind, path, rid))
        lines.append("")
        for sid, kind, body in self.sub:
            lines += ['[sub_resource type="%s" id="%s"]' % (kind, sid), body, ""]
        lines.append('[node name="%s" type="Node2D"]' % self.name)
        if self.sort:
            lines.append("y_sort_enabled = true")
        lines.append("")
        for name, kind, parent, props in self.nodes:
            lines.append('[node name="%s" type="%s" parent="%s"]' % (name, kind, parent))
            lines += props
            lines.append("")
        with open(os.path.join(ROOT, rel_path), "w") as out:
            out.write("\n".join(lines).rstrip() + "\n")


PROP = "res://assets/props/%s.png"
PALM = "res://assets/nature/Date palm.png"
HERB = "res://assets/nature/Wild herb.png"
HOUSE = "res://assets/building/house/Desert Adobe Rooftop House Sprite.png"
PEOPLE = "res://assets/characters/village/%s.png"


def village():
    s = Scene("Village", k=2)
    s.rect_ground("Floor", PROP % "ground_sand", -432, -288, 864, 576)
    s.rect_ground("GreenWest", PROP % "ground_grass", -432, 32, 412, 264)
    s.rect_ground("GreenEast", PROP % "ground_grass", 20, 32, 412, 264)
    s.rect_ground("GreenNorthWest", PROP % "ground_grass", -432, -288, 240, 280)
    s.rect_ground("Road", PROP % "ground_cobble", -432, -8, 864, 40)
    s.rect_ground("Lane", PROP % "ground_cobble", -20, 32, 40, 264)
    s.rect_ground("Square", PROP % "ground_cobble", -64, -56, 128, 48)
    s.bounds(-240, -150, 480, 300)
    s.spawn("PlayerSpawn", 0, 70)
    s.spawn("HarborReturn", 196, 0)
    s.spawn("OrchardReturn", -196, 0)
    s.spawn("RoadReturn", -196, -110)
    s.spawn("ForestReturn", 0, 118)
    s.door("ExitFarm", 0, 140, FOREST, "VillageReturn", 40, 16)
    s.door("ExitRoad", -228, -110, ROAD, "VillageReturn", 16, 40)
    s.door("ExitHarbor", 228, 10, HARBOR, "PlayerSpawn", 16, 40)
    s.door("ExitOrchard", -228, 10, ORCHARD, "PlayerSpawn", 16, 40)
    s.mark("HouseWest", HOUSE, -170, -64, fit=150, block=(126, 44))
    s.mark("HouseElder", HOUSE, -96, -84, fit=140, block=(116, 40))
    s.mark("HouseNorth", HOUSE, 20, -112, fit=130, block=(108, 38))
    s.mark("HouseSouth", HOUSE, 104, 140, fit=130, block=(108, 38))
    for i, part in enumerate(["wall_window", "wall_door", "wall_plain", "wall_window", "wall_door"]):
        s.mark("Shop%d" % i, PROP % part, 88 + i * 32, -96, fit=72, block=(64, 22))
    s.mark("LanternA", PROP % "lantern", 72, -96)
    s.mark("LanternB", PROP % "lantern", 248 - 16, -96)
    s.mark("Stall", "res://assets/building/village/Market stall.png", 0, -60, fit=36, block=(32, 12))
    s.mark("StallProduce", PROP % "stall_produce", -44, -58, block=(40, 12))
    s.mark("StallPots", PROP % "stall_pots", 46, -58, block=(40, 12))
    s.mark("StallFar", PROP % "stall_produce", -44, -24, block=(40, 12))
    s.mark("StallFar2", PROP % "stall_pots", 46, -24, block=(40, 12))
    s.mark("ShelfSeeds", PROP % "shelf_seeds", 196, -40, block=(36, 10))
    s.mark("Counter", PROP % "counter", 140, -40, block=(60, 10))
    s.mark("Workyard", PROP % "table", 96, 72, block=(24, 8))
    for i, (name, x, y) in enumerate([("crate", 120, 70), ("crate", 124, 82), ("sack", 70, 76), ("barrel", -80, 72),
                                      ("barrel", -94, 76), ("pot_big", -150, 40), ("pot_green", -136, 44),
                                      ("basket", 70, -40), ("sack", -70, -40), ("plant", -60, 120), ("plant", 60, 120),
                                      ("barrel", 62, -34), ("crate", 84, -30), ("basket", -58, -30), ("pot_big", -34, -22),
                                      ("pot_green", 30, -22), ("sack", 104, -32), ("crate", 190, 34), ("barrel", 206, 36),
                                      ("plant", -120, 60), ("plant", -30, -100), ("basket", 150, 74), ("pot_big", 60, 44)]):
        s.mark("Prop%d" % i, PROP % name, x, y, block=(12, 6))
    for i, (x, y) in enumerate([(-210, 120), (210, 120), (-140, 100), (150, 104), (226, -124), (-226, 56), (222, 62), (40, 136), (-60, 136), (168, 28)]):
        s.mark("Palm%d" % i, PALM, x, y, block=(10, 6))
    s.mark("Elder", PEOPLE % "Elder", -110, -40, fit=36, role="elder")
    s.route("Elder", [(-110, -40), (-180, 40), (-40, 50), (-96, -50)], [6, 11, 15, 19])
    s.mark("Merchant", PEOPLE % "Merchant", 0, -34, fit=36, role="merchant")
    s.route("Merchant", [(0, -34), (140, -20), (0, -34), (152, -72)], [6, 12, 14, 20])
    s.mark("Carpenter", PEOPLE % "Carpenter", 100, 92, fit=36, role="carpenter")
    s.route("Carpenter", [(100, 92), (36, 60), (100, 92), (120, -72)], [6, 12, 13, 18])
    s.save("src/scenes/world/village/Village.tscn")


def road():
    s = Scene("Road", k=1)
    s.rect_ground("Floor", PROP % "ground_sand", -420, -260, 840, 520)
    s.rect_ground("Track", PROP % "ground_cobble", -420, -16, 840, 44)
    s.bounds(-320, -190, 640, 380)
    s.spawn("PlayerSpawn", -280, 6)
    s.spawn("VillageReturn", 280, 6)
    s.door("ExitFarm", -312, 6, HOME, "VillageReturn", 16, 56)
    s.door("ExitVillage", 312, 6, VILLAGE, "RoadReturn", 16, 56)
    s.mark("Rest", PROP % "stall_produce", 30, -32, block=(40, 12))
    s.mark("RestPots", PROP % "stall_pots", 80, -32, block=(40, 12))
    s.mark("Shade", PROP % "table", -80, 70, block=(24, 8))
    for i, (name, x, y) in enumerate([("crate", 120, -34), ("sack", 140, -30), ("barrel", -20, -34), ("basket", 10, 58),
                                      ("crate", -110, 62), ("sack", -58, 62), ("lantern", -6, -30), ("lantern", 106, -30)]):
        s.mark("Prop%d" % i, PROP % name, x, y, block=(12, 6) if name != "lantern" else None)
    for i, (x, y) in enumerate([(-260, -120), (-170, -150), (-90, -130), (170, -140), (250, -110), (-250, 130), (-150, 150), (60, 140), (170, 120), (270, 150)]):
        s.mark("Palm%d" % i, PALM, x, y, block=(10, 6))
    s.mark("RoadsideDate", PALM, 200, -56, group="date")
    s.mark("RoadsideHerb", HERB, -210, 60, group="forage")
    s.save("src/scenes/world/road/Road.tscn")


def forest():
    s = Scene("Forest", k=1)
    tree = "res://assets/nature/Leafy 16-Bit Farm Tree Sprite.png"
    rock = "res://assets/nature/Chunky desert rock sprite.png"
    s.rect_ground("Floor", PROP % "ground_grass", -560, -400, 1120, 800)
    s.bounds(-480, -320, 960, 640)
    s.spawn("PlayerSpawn", 0, -270)
    s.spawn("VillageReturn", 440, 0)
    s.door("ExitFarm", 0, -306, HOME, "ForestReturn", 64, 20)
    s.door("ExitVillage", 468, 0, VILLAGE, "ForestReturn", 16, 64)
    s.mark("Pond", "res://assets/nature/Oasis pond.png", -220, 40, fit=200, block=(168, 140))
    s.mark("Pond2", "res://assets/nature/Oasis pond.png", 240, 230, fit=130, block=(108, 92))
    for i, (x, y) in enumerate([(-120, -180), (140, -170), (260, -60), (70, 90), (-60, 230), (-300, 220)]):
        s.mark("Wood%d" % i, tree, x, y, fit=96, group="tree", block=(14, 8))
    for i, (x, y) in enumerate([(40, -80), (-140, 110), (180, 40), (-340, -160), (330, 110), (-40, 150)]):
        s.mark("Herb%d" % i, HERB, x, y, group="forage")
    for i, (x, y) in enumerate([(120, 180), (-400, 110), (360, -200)]):
        s.mark("Stone%d" % i, rock, x, y, fit=26, group="rock")
    spots = [(-440, -280), (-360, -270), (-280, -290), (-200, -270), (-120, -290), (120, -290), (200, -270), (280, -290), (360, -270), (440, -280),
             (-450, -200), (-440, -100), (-450, 0), (-450, 100), (-440, 200), (-450, 300), (-360, 300), (-260, 300), (-160, 300), (-60, 300),
             (40, 300), (140, 300), (340, 300), (440, 300), (450, 200), (450, 110), (450, -100), (450, -200), (-260, -140), (-200, -60),
             (40, -200), (250, -210), (340, 0), (160, 110), (-20, 40), (-300, 140), (60, 200), (-120, 300)]
    for i, (x, y) in enumerate(spots):
        s.mark("Palm%d" % i, tree, x, y, fit=88 + i % 3 * 12, block=(14, 8))
    s.save("src/scenes/world/forest/Forest.tscn")


def harbor():
    s = Scene("Harbor", k=2)
    s.rect_ground("Gulf", PROP % "ground_water", -432, -352, 864, 312)
    s.rect_ground("Sand", PROP % "ground_sand", -432, -40, 864, 336)
    s.rect_ground("Dock", PROP % "ground_planks", 16, -144, 64, 112)
    s.bounds(-240, -150, 480, 300, [(-240, -150, 256, 102), (80, -150, 160, 102)])
    s.spawn("PlayerSpawn", -190, 60)
    s.door("ExitVillage", -228, 70, VILLAGE, "HarborReturn", 16, 40)
    s.area("FishingSpot", "res://src/scripts/World/fish_spot.gd", 48, -128, 40, 20)
    s.mark("Dhow", "res://assets/building/harbor/Dhow.png", 150, -70, fit=170)
    s.mark("DhowSmall", "res://assets/building/harbor/Dhow.png", -130, -76, fit=100)
    for i, (name, x, y) in enumerate([("crate_fish", 60, -36), ("crate_fish", -20, 20), ("barrel", 20, -36),
                                      ("barrel", -36, 30), ("crate", 110, 20), ("crate", 122, 30), ("sack", 96, 30),
                                      ("basket", -60, 24), ("lantern", 14, -60), ("lantern", 82, -60)]):
        s.mark("Prop%d" % i, PROP % name, x, y, block=(12, 6) if name != "lantern" else None)
    s.mark("ShoreCrate", PROP % "crate_fish", 110, -24, group="shore")
    s.mark("Hut", HOUSE, -150, 20, fit=140, block=(116, 40))
    s.mark("HutEast", HOUSE, 170, 90, fit=130, block=(108, 38))
    for i, (x, y) in enumerate([(200, 120), (-60, 130), (180, 40), (-210, 120), (60, 80), (-100, 90), (225, 20), (-225, -10)]):
        s.mark("Palm%d" % i, PALM, x, y, block=(10, 6))
    s.mark("Fisherman", PEOPLE % "Fisherman", 48, -90, fit=36, role="fisherman")
    s.route("Fisherman", [(48, -90), (-10, 50), (48, -90), (-150, 40)], [6, 11, 15, 19])
    s.save("src/scenes/world/harbor/Harbor.tscn")


def orchard():
    s = Scene("Orchard", k=2)
    s.rect_ground("Floor", PROP % "ground_grass", -432, -288, 864, 576)
    s.rect_ground("Path", PROP % "ground_sand", -432, -8, 864, 32)
    s.rect_ground("Track", PROP % "ground_sand", 120, 24, 32, 272)
    s.bounds(-240, -150, 480, 300)
    s.spawn("PlayerSpawn", 186, 8)
    s.door("ExitVillage", 228, 10, VILLAGE, "OrchardReturn", 16, 40)
    s.mark("Oasis", PROP % "oasis", -150, -70, fit=190, block=(150, 56))
    s.mark("DatePalm", PALM, -40, -40, group="date")
    s.mark("DatePalm2", PALM, 40, -70, group="date")
    s.mark("DatePalm3", PALM, -90, 90, group="date")
    s.mark("Herb", HERB, -10, 70, group="forage")
    s.mark("Herb2", HERB, 60, 60, group="forage")
    s.mark("Herb3", HERB, -180, 40, group="forage")
    for i, (x, y) in enumerate([(-220, -120), (110, -120), (180, -90), (-200, 120), (60, 130), (210, 130),
                                (-120, -120), (0, -120), (-30, 120), (130, 110), (200, 60), (-225, 70), (90, -50), (-60, -90)]):
        s.mark("Palm%d" % i, PALM, x, y, fit=72, block=(10, 6))
    for i, (name, x, y) in enumerate([("basket", 90, -10), ("sack", 104, -12), ("pot_big", -60, 40), ("plant", 150, 80)]):
        s.mark("Prop%d" % i, PROP % name, x, y, block=(12, 6))
    s.save("src/scenes/world/orchard/Orchard.tscn")


def cave():
    s = Scene("Cave", k=1.5)
    s.rect_ground("Floor", PROP % "ground_cave", -352, -272, 704, 544)
    s.bounds(-160, -80, 320, 220)
    s.spawn("PlayerSpawn", 0, 80)
    s.door("Exit", 0, 128, "uid://nsyej5gfqkfs", "CaveDoor", 32, 16)
    s.area("Rock", "res://src/scripts/World/rock.gd", 48, 40)
    s.area("Copper", "res://src/scripts/World/copper_vein.gd", -48, 24)
    for i in range(10):
        s.mark("Wall%d" % i, PROP % "cave_wall", -144 + i * 32, -64, fit=52)
    for i, (name, x, y) in enumerate([("torch", -100, -40), ("torch", 100, -40), ("mine_cart", 110, 60),
                                      ("pot_big", -120, 40), ("sack", 130, -10), ("barrel", -130, 100),
                                      ("crate", 130, 110), ("lantern", -20, 112), ("lantern", 20, 112)]):
        s.mark("Prop%d" % i, PROP % name, x, y, block=(12, 6) if name not in ("torch", "lantern") else None)
    s.save("src/scenes/world/cave/Cave.tscn")


if __name__ == "__main__":
    os.makedirs(os.path.join(ROOT, "src/scenes/world/road"), exist_ok=True)
    os.makedirs(os.path.join(ROOT, "src/scenes/world/forest"), exist_ok=True)
    village()
    road()
    forest()
    harbor()
    orchard()
    cave()
