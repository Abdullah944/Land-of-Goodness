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


TREE = "res://assets/nature/plants/ghaf.png"
SIDR = "res://assets/nature/plants/sidr.png"
ACACIA = "res://assets/nature/plants/acacia.png"
ROCK = "res://assets/nature/Chunky desert rock sprite.png"
STALL = "res://assets/building/village/Market stall.png"
DHOW = "res://assets/building/harbor/Dhow.png"


def props(s, rows, prefix="Prop"):
    for i, (name, x, y) in enumerate(rows):
        s.mark("%s%d" % (prefix, i), PROP % name, x, y, block=None if name in ("lantern", "torch") else (12, 6))


def village():
    s = Scene("Village")
    s.bounds(-780, -600, 1560, 1200)
    s.spawn("PlayerSpawn", -160, 40)
    s.spawn("RoadReturn", -720, -116)
    s.spawn("ForestReturn", -590, 530)
    s.spawn("HarborReturn", 170, 530)
    s.spawn("OrchardReturn", -170, -530)
    s.door("ExitRoad", -772, -118, ROAD, "VillageReturn", 24, 90)
    s.door("ExitWoods", -600, 590, FOREST, "VillageReturn", 90, 24)
    s.door("ExitHarbor", 178, 590, HARBOR, "PlayerSpawn", 90, 24)
    s.door("ExitOrchard", -176, -590, ORCHARD, "PlayerSpawn", 90, 24)
    # The market square in the middle of town.
    s.mark("Stall", STALL, 10, -110, fit=64, block=(56, 16))
    s.mark("StallProduce", PROP % "stall_produce", -90, -108, fit=64, block=(56, 16))
    s.mark("StallPots", PROP % "stall_pots", 110, -108, fit=64, block=(56, 16))
    s.mark("StallFar", PROP % "stall_produce", -90, 40, fit=64, block=(56, 16))
    s.mark("StallFar2", PROP % "stall_pots", 110, 40, fit=64, block=(56, 16))
    s.mark("Counter", PROP % "counter", 200, -20, fit=70, block=(62, 12))
    s.mark("ShelfSeeds", PROP % "shelf_seeds", 214, -90, block=(36, 10))
    # Homes spread around the square, with gardens between them.
    for i, (x, y, fit) in enumerate([(-340, -220, 150), (-470, 60, 150), (-40, -300, 140), (230, -300, 150), (-310, 340, 150),
                                     (-60, 470, 140), (310, 240, 150), (690, -290, 150), (690, 230, 140), (-600, -330, 140), (-560, 260, 130)]):
        s.mark("House%d" % i, HOUSE, x, y, fit=fit, block=(int(fit * 0.84), int(fit * 0.29)))
    for i, part in enumerate(["wall_window", "wall_door", "wall_plain", "wall_door"]):
        s.mark("Shop%d" % i, PROP % part, -240 + i * 64, -180, fit=72, block=(64, 22))
    props(s, [("lantern", -240, -60), ("lantern", 260, -170), ("lantern", -230, 120), ("lantern", 250, 120), ("lantern", 470, -80), ("lantern", 600, -80),
              ("barrel", 150, -150), ("crate", 180, -150), ("basket", -160, -140), ("sack", -190, -130), ("pot_big", -220, 80), ("pot_green", -194, 84),
              ("basket", 230, 60), ("crate", 330, 110), ("crate", 346, 122), ("sack", 310, 124), ("barrel", -420, 110), ("barrel", -440, 116),
              ("pot_big", -280, 400), ("plant", -210, 330), ("plant", -30, 540), ("plant", 200, 300), ("plant", -400, -170), ("plant", 300, -240),
              ("pot_green", 600, -240), ("barrel", 640, 280), ("basket", -520, 320)])
    s.mark("Workyard", PROP % "table", 300, 100, block=(24, 8))
    for i, (x, y) in enumerate([(-500, -130), (-260, 220), (-120, 240), (60, 200), (250, 400), (-480, 180), (-90, -420), (130, -420), (360, -420),
                                (-420, -420), (620, -120), (660, 90), (620, 400), (-200, 530), (60, 340), (390, -120), (-680, 130), (-690, -220)]):
        s.mark("Palm%d" % i, PALM, x, y, block=(10, 6))
    s.mark("Elder", PEOPLE % "Elder", -300, -140, fit=36, role="elder")
    s.route("Elder", [(-300, -140), (-160, -30), (60, 110), (-320, -160)], [6, 11, 15, 19])
    s.mark("Merchant", PEOPLE % "Merchant", 10, -60, fit=36, role="merchant")
    s.route("Merchant", [(10, -60), (170, -30), (10, -60), (230, -170)], [6, 12, 14, 20])
    s.mark("Carpenter", PEOPLE % "Carpenter", 340, 80, fit=36, role="carpenter")
    s.route("Carpenter", [(340, 80), (130, 90), (340, 80), (260, -170)], [6, 12, 13, 18])
    s.save("src/scenes/world/village/Village.tscn")


def road():
    s = Scene("Road")
    s.bounds(-320, -190, 640, 380)
    s.spawn("PlayerSpawn", -280, 6)
    s.spawn("VillageReturn", 280, 6)
    s.door("ExitFarm", -312, 6, HOME, "VillageReturn", 16, 56)
    s.door("ExitVillage", 312, 6, VILLAGE, "RoadReturn", 16, 56)
    s.mark("Rest", PROP % "stall_produce", 30, -32, block=(40, 12))
    s.mark("RestPots", PROP % "stall_pots", 80, -32, block=(40, 12))
    s.mark("Shade", PROP % "table", -80, 70, block=(24, 8))
    props(s, [("crate", 120, -34), ("sack", 140, -30), ("barrel", -20, -34), ("basket", 10, 58), ("crate", -110, 62), ("sack", -58, 62),
              ("lantern", -6, -30), ("lantern", 106, -30)])
    for i, (x, y) in enumerate([(-260, -120), (-170, -150), (-90, -130), (170, -140), (250, -110), (-250, 130), (-150, 150), (60, 140), (170, 120), (270, 150)]):
        s.mark("Palm%d" % i, PALM, x, y, block=(10, 6))
    s.mark("RoadsideDate", PALM, 200, -56, group="date")
    s.mark("RoadsideHerb", HERB, -210, 60, group="forage")
    s.save("src/scenes/world/road/Road.tscn")


def forest():
    s = Scene("Forest")
    s.bounds(-735, -635, 1470, 1270)
    s.spawn("PlayerSpawn", 0, -560)
    s.spawn("VillageReturn", 670, 0)
    s.door("ExitFarm", 0, -620, HOME, "ForestReturn", 76, 24)
    s.door("ExitVillage", 722, 0, VILLAGE, "ForestReturn", 24, 76)
    for i, (x, y) in enumerate([(-180, -300), (210, -340), (420, -210), (250, 160), (-60, -120), (-480, 400)]):
        s.mark("Wood%d" % i, TREE, x, y, group="tree", block=(14, 8))
    for i, (x, y) in enumerate([(60, -140), (150, 40), (290, 70), (-520, -240), (480, 180), (-280, 380), (360, 430), (-560, 90)]):
        s.mark("Herb%d" % i, HERB, x, y, group="forage")
    for i, (x, y) in enumerate([(200, 300), (-600, 240), (540, -300)]):
        s.mark("Stone%d" % i, ROCK, x, y, fit=26, group="rock")
    trees = [(-420, -400), (-300, -480), (-160, -520), (160, -500), (320, -470), (470, -400), (580, -160), (560, 110), (620, 300), (480, 380), (300, 470),
             (180, 560), (-180, 500), (-330, 520), (-500, 500), (-620, 340), (-640, 40), (-620, -160), (-520, -340), (-90, -300), (120, -220), (330, -20),
             (440, 60), (120, 170), (-470, -110), (-90, 300), (280, 300), (400, 250), (-400, 300)]
    for i, (x, y) in enumerate(trees):
        s.mark("Palm%d" % i, (TREE, SIDR, TREE, ACACIA)[i % 4], x, y, block=(14, 8))
    s.save("src/scenes/world/forest/Forest.tscn")


def harbor():
    s = Scene("Harbor")
    s.bounds(-730, -380, 1460, 760, [(-730, 96, 740, 284), (110, 96, 620, 284), (10, 340, 100, 40)])
    s.spawn("PlayerSpawn", 176, -320)
    s.door("ExitVillage", 180, -370, VILLAGE, "HarborReturn", 90, 24)
    s.area("FishingSpot", "res://src/scripts/World/fish_spot.gd", 60, 310, 80, 30)
    s.mark("Dhow", DHOW, 320, 240, fit=170)
    s.mark("DhowSmall", DHOW, -240, 220, fit=100)
    s.mark("ShoreCrate", PROP % "crate_fish", -160, 62, group="shore")
    for i, (x, y, fit) in enumerate([(-440, -120, 150), (-140, -200, 140), (470, -160, 150), (-600, 40, 130), (610, 20, 130)]):
        s.mark("Hut%d" % i, HOUSE, x, y, fit=fit, block=(int(fit * 0.84), int(fit * 0.29)))
    props(s, [("crate_fish", 130, 70), ("barrel", -20, 70), ("crate", 170, 60), ("crate", 184, 70), ("sack", 148, 40), ("basket", -60, 40), ("barrel", 36, 110),
              ("lantern", 6, 200), ("lantern", 114, 200), ("lantern", 6, 330), ("lantern", 114, 330), ("crate_fish", -300, 30), ("barrel", -330, 40), ("basket", 300, 40),
              ("pot_big", -390, -60), ("plant", 420, -70), ("sack", 260, -40), ("crate", -100, -110)])
    s.mark("StallFish", PROP % "stall_produce", 30, -60, fit=64, block=(56, 16))
    for i, (x, y) in enumerate([(-680, -300), (-560, -280), (-300, -320), (20, -320), (360, -320), (620, -290), (680, -140), (-260, -40), (300, -20), (-520, -90), (560, -40), (700, 60), (-700, 60)]):
        s.mark("Palm%d" % i, PALM, x, y, block=(10, 6))
    s.mark("Fisherman", PEOPLE % "Fisherman", 60, 280, fit=36, role="fisherman")
    s.route("Fisherman", [(60, 280), (40, 40), (60, 280), (-140, -130)], [6, 11, 15, 19])
    s.save("src/scenes/world/harbor/Harbor.tscn")


def orchard():
    s = Scene("Orchard")
    s.bounds(-505, -325, 1010, 650)
    s.spawn("PlayerSpawn", 0, 280)
    s.door("ExitVillage", 0, 318, VILLAGE, "OrchardReturn", 76, 24)
    s.mark("Oasis", "res://assets/nature/Oasis pond.png", -300, -60, fit=200, block=(164, 140))
    s.mark("DatePalm", PALM, -80, -60, group="date")
    s.mark("DatePalm2", PALM, 80, -120, group="date")
    s.mark("DatePalm3", PALM, -180, 180, group="date")
    s.mark("Herb", HERB, -20, 140, group="forage")
    s.mark("Herb2", HERB, 120, 120, group="forage")
    s.mark("Herb3", HERB, -360, 80, group="forage")
    for i, (x, y) in enumerate([(-440, -250), (220, -240), (360, -180), (-400, 240), (120, 260), (420, 260), (-240, -240), (0, -240), (-60, 240), (260, 220),
                                (400, 120), (-450, 140), (180, -40), (-120, -180), (330, -40), (300, 100), (440, -60), (-300, 180)]):
        s.mark("Palm%d" % i, PALM, x, y, fit=72, block=(10, 6))
    props(s, [("basket", 180, -20), ("sack", 208, -24), ("pot_big", -120, 80), ("plant", 300, 160)])
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
