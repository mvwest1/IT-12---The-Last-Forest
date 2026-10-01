"""THE LAST FOREST - level builder.

Generates the four stage scenes from the layouts at the bottom of this file:
    python the_last_forest/tools/build_levels.py      (run from project root)

Why a script instead of hand-placed tiles: every stage uses the same
asset rules, so a layout change is a one-line edit and stays consistent.
    ground      -> TileMapLayer with environment/forest_tileset.tres
    trees       -> art/env/tree_1.png, tree_2.png
    bushes etc. -> art/env/bush_1, fern_1, grass_1..3, flowers, rock, vines
    background  -> environment/forest_background.tscn (sky, distant cliffs, clouds)
  Smart reuse (recoloured copies made by recolor_env.py):
    clouds       -> grey smoke plumes over burnt ground, pale fog in pits,
                    the rain cloud in Stage 3
    tileset tree -> leafless burnt snag;  tree trunk -> burnt stump
    bush         -> dry straw bush (Stage 3, turns green when watered)
    sparkle      -> glowing embers rising with the smoke
  Burnt remains, smoke and embers FADE OUT as trees mature (vanish_at_N);
  green trees, flowers and ferns FADE IN (appear_at_N). Tier 0 = always shown.
To swap in new art later, replace the PNGs in art/env/ (same names) - no
scene edits needed. Re-running this script OVERWRITES scenes/stage_1..4.tscn.

Layout units: 1 column = 64 px. A column's "row" is the tile row of its
grass surface; the walkable surface is at y = row * 64 + 10.
Rules kept for 9-10 year old players (player jump ~125 px, double ~250 px):
  * required steps are 1 tile (64 px) high, gaps at most 2 tiles wide
  * anything higher than one tile is optional (bonus seeds on ledges)
  * a checkpoint sits after every pit
"""
import base64, os, random, struct

from PIL import Image, ImageDraw

TILE = 64
BOTTOM_ROW = 13          # last tile row; the world floor ends at y = 896
SURF_OFF = 10            # tile collision top is 22 px below the tile's top edge... centre-22 = row*64+10

def surf_y(row):
    return row * TILE + SURF_OFF

def col_x(col):
    return col * TILE + TILE // 2

# Source ids in level/tileset.tres (copied to forest_tileset.tres)
T_TOP, T_TOP_EDGE = 0, 2            # grass surface / surface with right side edge
T_LEDGE_MID, T_LEDGE_END = 3, 4     # floating one-way ledge
T_FILL, T_SIDE = 6, 7               # rock body / rock body with right side edge
T_FILL_ALT = 18
T_TOP_ALT = (11, 13)                # grass surface variants


# ------------------------------------------------------------------ shared resources
def write_tileset(root):
    src = open(os.path.join(root, "level/tileset.tres")).read()
    head, rest = src.split("\n", 1)
    head = '[gd_resource type="TileSet" format=3]'
    rest = rest.replace('[ext_resource type="Texture2D" uid="uid://8bv0mysvxgle" path="res://level/tiles.webp" id="1"]',
                        '[ext_resource type="Texture2D" path="res://the_last_forest/art/env/tiles.png" id="1"]')
    assert 'art/env/tiles.png' in rest
    # Floating ledges (sources 3 and 4) become one-way: jump up through them.
    out, cur = [], None
    for line in rest.split("\n"):
        out.append(line)
        if line.startswith("[sub_resource"):
            cur = line
        if cur and ("TileSetAtlasSource_vhpsr" in cur or "TileSetAtlasSource_cyfft" in cur) \
                and "/physics_layer_0/polygon_0/points" in line:
            out.append(line.split("/points")[0] + "/one_way = true")
    path = os.path.join(root, "the_last_forest/environment/forest_tileset.tres")
    open(path, "w").write(head + "\n" + "\n".join(out))
    # sanity: sources 3/4 are the ones with margins (128,0)/(192,0)
    assert "TileSetAtlasSource_vhpsr" in src and "TileSetAtlasSource_cyfft" in src


def write_checkpoint_art(root):
    for name, cloth in (("checkpoint_off.png", (150, 150, 140)), ("checkpoint_on.png", (96, 190, 70))):
        im = Image.new("RGBA", (24, 52), (0, 0, 0, 0))
        d = ImageDraw.Draw(im)
        d.rectangle([3, 4, 6, 51], fill=(92, 62, 40, 255))          # post
        d.rectangle([3, 4, 4, 51], fill=(122, 84, 54, 255))
        d.polygon([(7, 6), (22, 11), (7, 18)], fill=cloth + (255,))  # pennant
        d.line([(7, 18), (22, 11)], fill=tuple(int(c * 0.7) for c in cloth) + (255,))
        d.ellipse([1, 1, 8, 7], fill=(246, 201, 69, 255))            # gold knob
        d.rectangle([0, 48, 10, 51], fill=(70, 52, 40, 255))
        im.save(os.path.join(root, "the_last_forest/art", name))


CHECKPOINT_TSCN = """[gd_scene format=3]

[ext_resource type="Script" path="res://the_last_forest/stage/checkpoint.gd" id="1"]
[ext_resource type="Texture2D" path="res://the_last_forest/art/checkpoint_off.png" id="2"]
[ext_resource type="Texture2D" path="res://the_last_forest/art/checkpoint_on.png" id="3"]

[sub_resource type="RectangleShape2D" id="cp_area"]
size = Vector2(48, 120)

[node name="Checkpoint" type="Area2D"]
collision_layer = 0
collision_mask = 1
script = ExtResource("1")
active_texture = ExtResource("3")

[node name="Sprite2D" type="Sprite2D" parent="."]
position = Vector2(0, -26)
texture = ExtResource("2")

[node name="CollisionShape2D" type="CollisionShape2D" parent="."]
position = Vector2(0, -50)
shape = SubResource("cp_area")
"""


BACKGROUND_TSCN = """[gd_scene format=3]

[ext_resource type="Texture2D" path="res://the_last_forest/art/env/sky.png" id="sky"]
[ext_resource type="Texture2D" path="res://the_last_forest/art/env/distant_platforms_1.png" id="dp1"]
[ext_resource type="Texture2D" path="res://the_last_forest/art/env/distant_platforms_2.png" id="dp2"]
[ext_resource type="Texture2D" path="res://the_last_forest/art/env/cloud_1.png" id="c1"]
[ext_resource type="Texture2D" path="res://the_last_forest/art/env/cloud_2.png" id="c2"]
[ext_resource type="Texture2D" path="res://the_last_forest/art/env/cloud_3.png" id="c3"]

[node name="Background" type="Node2D"]
z_index = -100
z_as_relative = false

[node name="Sky" type="Parallax2D" parent="."]
scroll_scale = Vector2(0.1, 1)
repeat_size = Vector2(4096, 0)

[node name="Sprite2D" type="Sprite2D" parent="Sky"]
position = Vector2(0, -256)
scale = Vector2(2, 2.25)
texture = ExtResource("sky")
centered = false

[node name="Clouds" type="Parallax2D" parent="."]
scroll_scale = Vector2(0.15, 1)
repeat_size = Vector2(1800, 0)
autoscroll = Vector2(-6, 0)
{clouds}
[node name="FarCliffs" type="Parallax2D" parent="."]
scroll_scale = Vector2(0.25, 1)
repeat_size = Vector2(1524, 0)
{far}
[node name="NearCliffs" type="Parallax2D" parent="."]
scroll_scale = Vector2(0.45, 1)
repeat_size = Vector2(1568, 0)
{near}"""


def write_background(root):
    rnd = random.Random(7)
    clouds = ""
    for i, (tex, x, y, s) in enumerate([("c2", 60, 10, 1.0), ("c1", 420, 120, 0.8), ("c3", 700, 40, 1.0),
                                        ("c2", 1000, 150, 0.7), ("c1", 1350, 30, 1.0), ("c3", 1580, 170, 0.7)]):
        clouds += '\n[node name="Cloud%d" type="Sprite2D" parent="Clouds"]\nposition = Vector2(%d, %d)\nscale = Vector2(%s, %s)\ntexture = ExtResource("%s")\ncentered = false\n' % (i, x, y, s, s, tex)
    far = ""
    for i in range(2):
        far += '\n[node name="Far%d" type="Sprite2D" parent="FarCliffs"]\nposition = Vector2(%d, 430)\nscale = Vector2(1, 1.85)\nmodulate = Color(1, 1, 1, 0.9)\ntexture = ExtResource("dp2")\ncentered = false\n' % (i, i * 762)
    near = ""
    for i in range(2):
        near += '\n[node name="Near%d" type="Sprite2D" parent="NearCliffs"]\nposition = Vector2(%d, 500)\nscale = Vector2(1, 1.6)\ntexture = ExtResource("dp1")\ncentered = false\n' % (i, i * 784)
    open(os.path.join(root, "the_last_forest/environment/forest_background.tscn"), "w").write(
        BACKGROUND_TSCN.format(clouds=clouds, far=far, near=near))


# ------------------------------------------------------------------ level model
class Level:
    def __init__(self, name, segments, seed):
        self.name = name
        self.heights = []
        for count, row in segments:
            self.heights += [row] * count
        self.width = len(self.heights)
        self.ledges = []   # (row, c0, c1)
        self.rnd = random.Random(seed)
        self.nodes = []    # raw node text blocks appended after the generated decor
        self.reserved = set()  # columns with gameplay objects (keep decor light)

    def h(self, col):
        if 0 <= col < self.width:
            return self.heights[col]
        return 0  # outside = solid wall

    def ledge(self, row, c0, c1):
        self.ledges.append((row, c0, c1))

    def ground_y(self, col):
        r = self.heights[col]
        assert r is not None, "%s: column %d is a pit" % (self.name, col)
        return surf_y(r)

    # ---- tiles
    def cells(self):
        cells = []
        for c, r in enumerate(self.heights):
            if r is None:
                continue
            hl, hr = self.h(c - 1), self.h(c + 1)
            for row in range(r, BOTTOM_ROW + 1):
                open_l = hl is None or hl > row
                open_r = hr is None or hr > row
                if row == r:
                    if open_r and not open_l:
                        cells.append((c, row, T_TOP_EDGE, 0))
                    elif open_l and not open_r:
                        cells.append((c, row, T_TOP_EDGE, 1))
                    else:
                        src = T_TOP if self.rnd.random() < 0.7 else self.rnd.choice(T_TOP_ALT)
                        cells.append((c, row, src, self.rnd.randint(0, 1)))
                else:
                    if open_r and not open_l:
                        cells.append((c, row, T_SIDE, 0))
                    elif open_l and not open_r:
                        cells.append((c, row, T_SIDE, 1))
                    else:
                        src = T_FILL if self.rnd.random() < 0.85 else T_FILL_ALT
                        cells.append((c, row, src, self.rnd.randint(0, 1)))
        for row, c0, c1 in self.ledges:
            for c in range(c0, c1 + 1):
                if c == c0:
                    cells.append((c, row, T_LEDGE_END, 1))
                elif c == c1:
                    cells.append((c, row, T_LEDGE_END, 0))
                else:
                    cells.append((c, row, T_LEDGE_MID, self.rnd.randint(0, 1)))
        return cells

    def tile_data(self):
        b = bytearray(b"\x00\x00")
        for c, r, src, alt in self.cells():
            b += struct.pack("<hhHHHH", c, r, src, 0, 0, alt)
        return base64.b64encode(bytes(b)).decode()

    def flat_cols(self):
        out = []
        for c, r in enumerate(self.heights):
            if r is None or r == 0:
                continue
            if self.h(c - 1) == r and self.h(c + 1) == r:
                out.append(c)
        return out


# ------------------------------------------------------------------ scene writer
EXT = [
    ("TileSet", "res://the_last_forest/environment/forest_tileset.tres", "tiles"),
    ("PackedScene", "res://the_last_forest/environment/forest_background.tscn", "bg"),
    ("Texture2D", "res://the_last_forest/art/env/tree_1.png", "tree1"),
    ("Texture2D", "res://the_last_forest/art/env/tree_2.png", "tree2"),
    ("Texture2D", "res://the_last_forest/art/env/bush_1.png", "bush"),
    ("Texture2D", "res://the_last_forest/art/env/fern_1.png", "fern"),
    ("Texture2D", "res://the_last_forest/art/env/grass_1.png", "grass1"),
    ("Texture2D", "res://the_last_forest/art/env/grass_2.png", "grass2"),
    ("Texture2D", "res://the_last_forest/art/env/grass_3.png", "grass3"),
    ("Texture2D", "res://the_last_forest/art/env/flower_1.png", "flower"),
    ("Texture2D", "res://the_last_forest/art/env/ground_flowers_1.png", "gflower"),
    ("Texture2D", "res://the_last_forest/art/env/rock_1.png", "rock"),
    ("Texture2D", "res://the_last_forest/art/env/vine_1.png", "vine1"),
    ("Texture2D", "res://the_last_forest/art/env/vine_2.png", "vine2"),
    ("Texture2D", "res://the_last_forest/art/env/snag.png", "snag"),
    ("Texture2D", "res://the_last_forest/art/env/stump.png", "stump"),
    ("Texture2D", "res://the_last_forest/art/env/smoke.png", "smoke"),
    ("Texture2D", "res://the_last_forest/art/env/ember.png", "ember"),
    ("Texture2D", "res://the_last_forest/art/env/fog.png", "fog"),
    ("Texture2D", "res://the_last_forest/art/env/dry_bush.png", "drybush"),
    ("Material", "res://level/props/wind_sway.tres", "wind"),
    ("Script", "res://the_last_forest/stage/stage_controller.gd", "ctl"),
    ("Script", "res://the_last_forest/stage/fact_trigger.gd", "fact"),
    ("Script", "res://the_last_forest/environment/restoration_controller.gd", "resctl"),
    ("PackedScene", "res://the_last_forest/player/forest_player.tscn", "player"),
    ("PackedScene", "res://the_last_forest/planting/planting_zone.tscn", "zone"),
    ("PackedScene", "res://the_last_forest/planting/seed_pickup.tscn", "seed"),
    ("PackedScene", "res://the_last_forest/ui/hud.tscn", "hud"),
    ("PackedScene", "res://the_last_forest/scenes/stage_exit_gate.tscn", "gate"),
    ("PackedScene", "res://the_last_forest/stage/checkpoint.tscn", "checkpoint"),
]
EXTRA_EXT = {
    "sign": ("PackedScene", "res://the_last_forest/scenes/tutorial_sign.tscn"),
    "pest": ("PackedScene", "res://the_last_forest/pests/pest.tscn"),
    "sapling": ("PackedScene", "res://the_last_forest/planting/sapling.tscn"),
    "guard": ("PackedScene", "res://the_last_forest/pests/tree_guard_pickup.tscn"),
    "arid": ("PackedScene", "res://the_last_forest/water/arid_zone.tscn"),
    "source": ("PackedScene", "res://the_last_forest/water/water_source.tscn"),
    "diverter": ("PackedScene", "res://the_last_forest/water/diverter.tscn"),
}


def v2(x, y):
    return "Vector2(%s, %s)" % (_n(x), _n(y))


def _n(v):
    return str(int(v)) if float(v).is_integer() else "%.2f" % v


def sprite(name, parent, tex, x, y, z=0, scale=1.0, flip=False, wind=False, groups=None,
           offset=None, centered=True, modulate=None):
    g = ' groups=[%s]' % ", ".join('"%s"' % s for s in groups) if groups else ""
    s = '[node name="%s" type="Sprite2D" parent="%s"%s]\n' % (name, parent, g)
    if z:
        s += "z_index = %d\n" % z
    if wind:
        s += 'material = ExtResource("wind")\n'
    if modulate:
        s += "modulate = Color(%s, %s, %s, 1)\n" % modulate
    s += "position = %s\n" % v2(x, y)
    if scale != 1.0 or flip:
        s += "scale = %s\n" % v2(-scale if flip else scale, scale)
    s += 'texture = ExtResource("%s")\n' % tex
    if not centered:
        s += "centered = false\n"
    if offset:
        s += "offset = %s\n" % v2(*offset)
    return s + "\n"


PARTICLE_SUBRESOURCES = """[sub_resource type="Curve" id="smoke_grow"]
max_value = 2.0
_data = [Vector2(0, 0.5), 0.0, 0.0, 0, 0, Vector2(1, 1.7), 0.0, 0.0, 0, 0]
point_count = 2

[sub_resource type="Gradient" id="smoke_fade"]
offsets = PackedFloat32Array(0, 0.2, 1)
colors = PackedColorArray(1, 1, 1, 0, 1, 1, 1, 0.7, 1, 1, 1, 0)

[sub_resource type="Gradient" id="ember_fade"]
offsets = PackedFloat32Array(0, 0.6, 1)
colors = PackedColorArray(1, 0.85, 0.4, 1, 1, 0.45, 0.1, 0.9, 0.8, 0.2, 0.05, 0)
"""


def smoke_plume(name, x, y, groups, big=False):
    g = ' groups=[%s]' % ", ".join('"%s"' % s for s in groups) if groups else ""
    return ('[node name="%s" type="CPUParticles2D" parent="Smoke"%s]\nz_index = -1\nposition = %s\n'
            'amount = %d\nlifetime = %s\npreprocess = 5.0\ntexture = ExtResource("smoke")\n'
            'emission_shape = 3\nemission_rect_extents = Vector2(16, 4)\ndirection = Vector2(0.25, -1)\n'
            'spread = 10.0\ngravity = Vector2(5, -4)\ninitial_velocity_min = 16.0\ninitial_velocity_max = 26.0\n'
            'scale_amount_min = %s\nscale_amount_max = %s\nscale_amount_curve = SubResource("smoke_grow")\n'
            'color_ramp = SubResource("smoke_fade")\n'
            % (name, g, v2(x, y), 9 if big else 6, "5.0" if big else "4.0",
               "0.22" if big else "0.15", "0.34" if big else "0.24"))


def embers(name, x, y, groups):
    g = ' groups=[%s]' % ", ".join('"%s"' % s for s in groups) if groups else ""
    return ('[node name="%s" type="CPUParticles2D" parent="Smoke"%s]\nz_index = 1\nposition = %s\n'
            'amount = 6\nlifetime = 2.0\npreprocess = 2.0\ntexture = ExtResource("ember")\n'
            'emission_shape = 3\nemission_rect_extents = Vector2(18, 3)\ndirection = Vector2(0, -1)\n'
            'spread = 35.0\ngravity = Vector2(0, -12)\ninitial_velocity_min = 18.0\ninitial_velocity_max = 38.0\n'
            'scale_amount_min = 0.7\nscale_amount_max = 1.3\ncolor_ramp = SubResource("ember_fade")\n'
            % (name, g, v2(x, y)))


def build_scene(lv, cfg):
    rnd = lv.rnd
    exts = list(EXT) + [(EXTRA_EXT[k][0], EXTRA_EXT[k][1], k) for k in cfg["extra_ext"]]
    out = ['[gd_scene format=4]\n']
    for typ, path, rid in exts:
        out.append('[ext_resource type="%s" path="%s" id="%s"]' % (typ, path, rid))
    out.append("")
    out.append('[ext_resource type="Resource" path="%s" id="data"]' % cfg["data"])
    out.append('[ext_resource type="Resource" path="%s" id="quiz"]' % cfg["quiz"])
    out.append('\n[sub_resource type="RectangleShape2D" id="StageMilestoneShape"]\nsize = Vector2(56, 112)\n')
    out.append(PARTICLE_SUBRESOURCES)
    out.append('[node name="%s" type="Node2D"]\n' % cfg["root"])
    out.append('[node name="Background" parent="." instance=ExtResource("bg")]\n')
    out.append('[node name="TileMapLayer" type="TileMapLayer" parent="."]\n'
               'tile_map_data = PackedByteArray("%s")\ntile_set = ExtResource("tiles")\nrendering_quadrant_size = 32\n' % lv.tile_data())

    # ---------------- decor (consistent rules for every stage)
    flat = lv.flat_cols()
    tiers = cfg.get("decor_tiers", {"flowers": 2, "ferns": 3, "bushes": 4})

    def tier_group(kind, tier):
        return ["%s_%d" % (kind, tier)] if tier else None

    out.append('[node name="Trees" type="Node2D" parent="."]\n')
    for i, entry in enumerate(cfg["trees"]):
        c, kind = entry[0], entry[1]
        tier = entry[2] if len(entry) > 2 else 0
        if any(c0 - 1 <= c <= c1 + 1 and lv.heights[c] - row <= 3 for row, c0, c1 in lv.ledges):
            continue  # a tree here would poke through the ledge above
        x = col_x(c) + rnd.randint(-14, 14)
        sc = rnd.uniform(0.95, 1.2)
        out.append(sprite("Tree%d" % i, "Trees", "tree%d" % kind, x, lv.ground_y(c) + 6, z=-1, scale=sc,
                          flip=rnd.random() < 0.5, wind=True, centered=False, offset=(-64, -128),
                          groups=tier_group("appear_at", tier)))
    out.append('[node name="Bushes" type="Node2D" parent="."]\n')
    for i, c in enumerate(cfg["bushes"]):
        grp = tier_group("appear_at", tiers["bushes"]) if i % 2 else None
        out.append(sprite("Bush%d" % i, "Bushes", "bush", col_x(c) + rnd.randint(-10, 10), lv.ground_y(c) + 4, z=-1,
                          scale=rnd.uniform(0.8, 1.05), flip=rnd.random() < 0.5, wind=True, centered=False,
                          offset=(-32, -64), groups=grp))
    out.append('[node name="Rocks" type="Node2D" parent="."]\n')
    for i, c in enumerate(cfg.get("rocks", [])):
        out.append(sprite("Rock%d" % i, "Rocks", "rock", col_x(c), lv.ground_y(c) + 2, z=-1, scale=0.7,
                          flip=rnd.random() < 0.5, centered=False, offset=(-32, -64)))
    # grass tufts on (almost) every surface tile, ferns & flowers fade in with restoration
    out.append('[node name="Grass" type="Node2D" parent="."]\n')
    out.append('[node name="Ferns" type="Node2D" parent="."]\n')
    out.append('[node name="Flowers" type="Node2D" parent="."]\n')
    gi = fi = wi = 0
    for c, r in enumerate(lv.heights):
        if r is None or r == 0:
            continue
        y = surf_y(r)
        for k in range(2):
            if rnd.random() < 0.75:
                out.append(sprite("G%d" % gi, "Grass", "grass%d" % rnd.randint(1, 3),
                                  c * TILE + 8 + k * 32 + rnd.randint(-6, 6), y - 10, z=1,
                                  scale=rnd.uniform(0.8, 1.0), flip=rnd.random() < 0.5, wind=True))
                gi += 1
        if c in flat and c not in lv.reserved:
            roll = rnd.random()
            if roll < cfg.get("fern_rate", 0.18):
                out.append(sprite("F%d" % fi, "Ferns", "fern", col_x(c) + rnd.randint(-12, 12), y - 22, z=-1,
                                  scale=rnd.uniform(0.7, 0.9), flip=rnd.random() < 0.5, wind=True,
                                  groups=tier_group("appear_at", tiers["ferns"])))
                fi += 1
            elif roll < cfg.get("fern_rate", 0.18) + cfg.get("flower_rate", 0.22):
                tex = rnd.choice(["flower", "gflower"])
                out.append(sprite("W%d" % wi, "Flowers", tex, col_x(c) + rnd.randint(-16, 16), y - 12, z=1,
                                  scale=0.8, wind=tex == "flower", groups=tier_group("appear_at", tiers["flowers"])))
                wi += 1
    out.append('[node name="Vines" type="Node2D" parent="."]\n')
    vi = 0
    for row, c0, c1 in lv.ledges:
        for c in range(c0, c1 + 1):
            if rnd.random() < 0.5:
                out.append(sprite("V%d" % vi, "Vines", "vine%d" % rnd.randint(1, 2), c * TILE + rnd.randint(14, 50),
                                  row * TILE + 70, z=-1, wind=True))
                vi += 1

    # burnt remains: charred snags and stumps that fade as the forest returns.
    # Kept OUT of the restoration shader roots (they are already charred).
    out.append('[node name="Burnt" type="Node2D" parent="."]\n')
    for i, (c, kind, tier) in enumerate(cfg.get("burnt", [])):
        if kind == "snag":
            out.append(sprite("Snag%d" % i, "Burnt", "snag", col_x(c) + rnd.randint(-10, 10), lv.ground_y(c) + 8, z=-1,
                              scale=rnd.uniform(0.85, 1.05), flip=rnd.random() < 0.5, centered=False,
                              offset=(-32, -190), groups=tier_group("vanish_at", tier)))
        else:
            out.append(sprite("Stump%d" % i, "Burnt", "stump", col_x(c) + rnd.randint(-10, 10), lv.ground_y(c) + 6, z=-1,
                              scale=1.4, flip=rnd.random() < 0.5, centered=False, offset=(-13, -41),
                              groups=tier_group("vanish_at", tier)))
    # smoke plumes + embers: still smouldering until the trees grow back
    out.append('[node name="Smoke" type="Node2D" parent="."]\n')
    for i, (c, tier, big) in enumerate(cfg.get("smoke", [])):
        out.append(smoke_plume("Smoke%d" % i, col_x(c), lv.ground_y(c) - 4, tier_group("vanish_at", tier), big))
        out.append(embers("Embers%d" % i, col_x(c), lv.ground_y(c) - 6, tier_group("vanish_at", tier)))
    # pale fog in every pit, so a hole reads as deep and dangerous
    out.append('[node name="Fog" type="Node2D" parent="."]\n')
    fi2, c = 0, 0
    while c < lv.width:
        if lv.heights[c] is None:
            start = c
            while c < lv.width and lv.heights[c] is None:
                c += 1
            mid = (start + c) / 2.0 * TILE
            for k, (dy, a, sx_) in enumerate(((0, 0.95, 1.0), (-70, 0.6, 0.8))):
                s_ = sprite("Fog%d" % fi2, "Fog", "fog", mid + (k * 16 - 8), (BOTTOM_ROW + 1) * TILE - 60 + dy, z=2,
                            scale=0.62 * sx_)
                out.append(s_.replace("position", "modulate = Color(1, 1, 1, %s)\nposition" % a, 1))
                fi2 += 1
        c += 1
    # Stage 3: straw bushes by the dry land that turn green once it is watered
    out.append('[node name="DryLand" type="Node2D" parent="."]\n')
    for i, c in enumerate(cfg.get("dry_bushes", [])):
        x = col_x(c) + rnd.randint(-8, 8); y = lv.ground_y(c) + 4; sc = rnd.uniform(0.8, 1.0); fl = rnd.random() < 0.5
        out.append(sprite("Dry%d" % i, "DryLand", "drybush", x, y, z=-1, scale=sc, flip=fl, wind=True,
                          centered=False, offset=(-32, -64), groups=["dry_decor"]))
        out.append(sprite("Wet%d" % i, "DryLand", "bush", x, y, z=-1, scale=sc, flip=fl, wind=True,
                          centered=False, offset=(-32, -64), groups=["wet_decor"]))

    # ---------------- gameplay
    sx = cfg["spawn_x"]; sy = lv.ground_y(int(sx // TILE)) - 42
    out.append('[node name="StageController" type="Node" parent="." node_paths=PackedStringArray("player", "spawn_point", "exit_gate")]\n'
               'script = ExtResource("ctl")\ndata = ExtResource("data")\nquiz = ExtResource("quiz")\n'
               'player = NodePath("../Player")\nspawn_point = NodePath("../SpawnPoint")\nexit_gate = NodePath("../ExitGate")\n')
    out.append('[node name="SpawnPoint" type="Marker2D" parent="."]\nposition = %s\n' % v2(sx, sy))
    out.append('[node name="PlantingZones" type="Node2D" parent="."]\n')
    for name, x, extra in cfg["zones"]:
        c = int(x // TILE)
        np = ' node_paths=PackedStringArray("arid_zone")' if "arid_zone" in extra else ""
        s = '[node name="%s" parent="PlantingZones"%s instance=ExtResource("zone")]\nposition = %s\n' % (name, np, v2(x, lv.ground_y(c)))
        for k, v in extra.items():
            s += "%s = %s\n" % (k, v)
        out.append(s)
    out.append('[node name="Seeds" type="Node2D" parent="."]\n')
    for i, (c, row) in enumerate(cfg["seeds"]):
        y = surf_y(row if row is not None else lv.heights[c]) - 20
        out.append('[node name="Seed%d" parent="Seeds" instance=ExtResource("seed")]\nposition = %s\n' % (i + 1, v2(col_x(c), y)))
    out.append('[node name="Checkpoints" type="Node2D" parent="."]\n')
    for i, c in enumerate(cfg.get("checkpoints", [])):
        out.append('[node name="Checkpoint%d" parent="Checkpoints" instance=ExtResource("checkpoint")]\nposition = %s\n' % (i + 1, v2(col_x(c), lv.ground_y(c))))
    mc = cfg["milestone_col"]
    out.append('[node name="MilestoneTrigger" type="Area2D" parent="."]\nposition = %s\ncollision_layer = 0\ncollision_mask = 1\n'
               'script = ExtResource("fact")\nfact_id = &"%s"\n' % (v2(col_x(mc), lv.ground_y(mc) - 50), cfg["milestone_fact"]))
    out.append('[node name="CollisionShape2D" type="CollisionShape2D" parent="MilestoneTrigger"]\nshape = SubResource("StageMilestoneShape")\n')
    for block in cfg.get("extra_nodes", []):
        out.append(block)
    gc = cfg["gate_col"]
    out.append('[node name="ExitGate" parent="." instance=ExtResource("gate")]\nposition = %s\n' % v2(col_x(gc), lv.ground_y(gc)))
    out.append('[node name="Player" parent="." instance=ExtResource("player")]\nposition = %s\n' % v2(sx, sy))
    out.append('[node name="HUDLayer" type="CanvasLayer" parent="."]\nlayer = 100\n')
    out.append('[node name="HUD" parent="HUDLayer" instance=ExtResource("hud")]\n')
    out.append('[node name="RestorationController" type="Node" parent="."]\nscript = ExtResource("resctl")\n')
    return "\n".join(out)


# ------------------------------------------------------------------ the four stages
def stage_1():
    # Burnt Grove - tutorial. Flat start, one step, a small hill, three zones.
    lv = Level("stage_1", [(2, 0), (12, 10), (4, 9), (6, 10), (3, 9), (2, 8), (3, 9), (9, 10), (2, 0)], seed=11)
    signs = [("Marker1", 4, "SIGN_1"), ("Marker2", 10, "SIGN_2"), ("Marker3", 22, "SIGN_3"), ("Marker4", 37, "SIGN_4")]
    zones = [("Zone1", col_x(12), {}), ("Zone2", col_x(20), {}), ("Zone3", col_x(34), {})]
    lv.reserved |= {3, 4, 10, 12, 20, 22, 34, 36, 37, 39}
    extra = ['[node name="TutorialSigns" type="Node2D" parent="."]\n']
    for name, c, key in signs:
        extra.append('[node name="%s" parent="TutorialSigns" instance=ExtResource("sign")]\nposition = %s\n'
                     'prompt_title = "%s_TITLE"\nprompt_message = "%s_BODY"\n' % (name, v2(col_x(c), lv.ground_y(c)), key, key))
    cfg = dict(root="Stage1", data="res://the_last_forest/stage/stages/stage_1_burnt_grove.tres",
               quiz="res://the_last_forest/quiz/quizzes/stage_1_quiz.tres", extra_ext=["sign"],
               spawn_x=col_x(3) - 32, zones=zones,
               seeds=[(6, None), (8, None), (16, None), (28, None)],
               # The grove starts as charred snags; each one is replaced by a green tree
               # as the player's trees mature (tier = milestone 1..4).
               trees=[(2, 1, 2), (7, 2, 2), (15, 1, 3), (25, 2, 3), (30, 1, 4), (33, 2, 4), (40, 1, 4)],
               burnt=[(2, "snag", 2), (7, "snag", 2), (15, "snag", 3), (25, "snag", 3), (30, "snag", 4),
                      (33, "snag", 4), (40, "snag", 4), (9, "stump", 3), (17, "stump", 4), (26, "stump", 4), (38, "stump", 4)],
               smoke=[(5, 1, True), (16, 2, False), (24, 2, True), (29, 3, False), (35, 3, True)],
               bushes=[5, 9, 17, 24, 29, 32, 38], rocks=[13, 26],
               milestone_col=36, milestone_fact="fact_burning_releases_co2", gate_col=39,
               extra_nodes=extra, fern_rate=0.15, flower_rate=0.2)
    return lv, cfg


def stage_2():
    # Pest Control - plateaus with the young trees, a dip with a guard.
    lv = Level("stage_2", [(2, 0), (8, 10), (5, 9), (2, 10), (3, 11), (7, 10), (4, 9), (4, 8), (3, 9), (10, 10), (2, 0)], seed=22)
    lv.ledge(6, 29, 32)
    zones = [("Zone1", col_x(8), {}), ("Zone2", col_x(22), {}), ("Zone3", col_x(25), {}), ("Zone4", col_x(40), {})]
    lv.reserved |= {3, 8, 13, 18, 22, 25, 33, 40, 42, 44, 46}
    extra = []
    for name, c in (("CanopySapling1", 13), ("CanopySapling2", 33)):
        extra.append('[node name="%s" parent="." instance=ExtResource("sapling")]\nposition = %s\n' % (name, v2(col_x(c), lv.ground_y(c))))
    for i, (c, rng) in enumerate(((11, 50), (24, 50), (37, 42))):
        extra.append('[node name="Pest%d" parent="." instance=ExtResource("pest")]\nposition = %s\npatrol_range = %s.0\n'
                     % (i + 1, v2(col_x(c), lv.ground_y(c) - 100), rng))
    extra.append('[node name="GuardPickups" type="Node2D" parent="."]\n')
    for i, c in enumerate((18, 42)):
        extra.append('[node name="Guard%d" parent="GuardPickups" instance=ExtResource("guard")]\nposition = %s\n' % (i + 1, v2(col_x(c), lv.ground_y(c) - 22)))
    cfg = dict(root="Stage2", data="res://the_last_forest/stage/stages/stage_2_pest_control.tres",
               quiz="res://the_last_forest/quiz/quizzes/stage_2_quiz.tres", extra_ext=["pest", "sapling", "guard"],
               spawn_x=col_x(3) - 32, zones=zones,
               seeds=[(5, None), (11, None), (20, None), (28, None), (31, 6)],
               trees=[(2, 2), (6, 1), (11, 2), (16, 1), (21, 2), (27, 1), (34, 2), (36, 1), (39, 2), (43, 1), (47, 2)],
               burnt=[(17, "stump", 3), (30, "stump", 4), (38, "snag", 4), (45, "stump", 4)],
               smoke=[(19, 2, False)],
               decor_tiers={"flowers": 3, "ferns": 2, "bushes": 0},
               bushes=[4, 10, 15, 19, 23, 28, 35, 41, 45], rocks=[17, 38],
               milestone_col=44, milestone_fact="fact_natural_helpers", gate_col=46,
               extra_nodes=extra, fern_rate=0.18, flower_rate=0.22)
    return lv, cfg


def stage_3():
    # Water Management. The irrigation puzzle keeps the EXACT geometry that was
    # simulated and tested (wall face -> diverter 278 px -> source +50 -> dry land +216),
    # then the path crosses two small gaps with a checkpoint after each.
    lv = Level("stage_3", [(2, 0), (16, 10), (2, None), (5, 10), (3, 9), (3, 8), (2, None), (3, 8), (4, 9), (12, 10), (2, 0)], seed=33)
    F = 2 * TILE                       # inner face of the left wall
    gully = F + 544
    lv.ledge(7, 24, 26)
    lv.reserved |= set(range(2, 16)) | {21, 34, 42, 47, 50}
    zones = [("Zone1", col_x(42), {}),
             ("Zone2", gully, {"arid_zone": 'NodePath("../../DryGully")'}),
             ("Zone3", gully - 116, {"arid_zone": 'NodePath("../../DryGully")'})]
    extra = ['[node name="DryGully" parent="." instance=ExtResource("arid")]\nposition = %s\ndrops_needed = 24\n' % v2(gully, surf_y(10) - 10),
             '[node name="IrrigationSource" parent="." instance=ExtResource("source")]\nposition = %s\n' % v2(F + 328, surf_y(10) - 110),
             '[node name="Diverter" parent="." instance=ExtResource("diverter")]\nposition = %s\nramp_offset = Vector2(50, -50)\n' % v2(F + 278, surf_y(10))]
    cfg = dict(root="Stage3", data="res://the_last_forest/stage/stages/stage_3_water.tres",
               quiz="res://the_last_forest/quiz/quizzes/stage_3_quiz.tres", extra_ext=["arid", "source", "diverter"],
               spawn_x=F + 224, zones=zones,
               seeds=[(3, None), (16, None), (23, None), (25, 7), (45, None)],
               trees=[(16, 1), (22, 2), (29, 1), (34, 2), (37, 1), (41, 2), (46, 1), (49, 2)],
               bushes=[17, 24, 33, 39, 44, 48], rocks=[3, 36],
               dry_bushes=[7, 9, 12, 14],
               decor_tiers={"flowers": 0, "ferns": 0, "bushes": 0},
               checkpoints=[21, 34],
               milestone_col=47, milestone_fact="fact_trees_make_rain", gate_col=50,
               extra_nodes=extra, fern_rate=0.2, flower_rate=0.22)
    return lv, cfg


def stage_4():
    # Forest Sanctuary - the restored forest to explore. Hills, two gaps,
    # high one-way ledges with bonus seeds, lots of trees.
    lv = Level("stage_4", [(2, 0), (8, 10), (3, 9), (3, 8), (2, None), (6, 8), (3, 9), (6, 10), (4, 11), (4, 10),
                           (2, None), (5, 10), (4, 9), (12, 10), (2, 0)], seed=44)
    lv.ledge(6, 19, 22)
    lv.ledge(7, 49, 51)
    lv.ledge(8, 55, 57)
    lv.reserved |= {3, 19, 29, 34, 44, 53, 60}
    cfg = dict(root="Stage4", data="res://the_last_forest/stage/stages/stage_4_sanctuary.tres",
               quiz="res://the_last_forest/quiz/quizzes/stage_4_quiz.tres", extra_ext=[],
               spawn_x=col_x(3) - 32, zones=[("Zone1", col_x(29), {})],
               seeds=[(6, None), (14, None), (21, 6), (34, None), (50, 7)],
               trees=[(2, 1), (5, 2), (8, 1), (11, 2), (14, 1), (18, 2), (21, 1), (23, 2), (26, 1), (31, 2),
                      (35, 1), (38, 2), (43, 1), (46, 2), (49, 1), (52, 2), (54, 1), (58, 2), (61, 1)],
               bushes=[4, 7, 12, 20, 25, 28, 32, 36, 39, 45, 48, 53, 56, 58],
               rocks=[10, 37, 47],
               checkpoints=[19, 44],
               milestone_col=53, milestone_fact="fact_forest_home", gate_col=60,
               extra_nodes=[], fern_rate=0.3, flower_rate=0.35,
               decor_tiers={"flowers": 0, "ferns": 0, "bushes": 0})  # restored forest: lush from the start
    return lv, cfg


def validate(lv, cfg):
    """Layout rules checked on every build; raises with a clear message."""
    problems = []
    def flat(c):
        r = lv.heights[c]
        return r is not None and lv.h(c - 1) == r and lv.h(c + 1) == r
    anchors = [("zone " + n, int(x // TILE)) for n, x, _ in cfg["zones"]]
    anchors += [("gate", cfg["gate_col"]), ("milestone", cfg["milestone_col"])]
    anchors += [("checkpoint", c) for c in cfg.get("checkpoints", [])]
    for name, c in anchors:
        if not flat(c):
            problems.append("%s at column %d is not on flat ground" % (name, c))
    zone_cols = sorted(int(x // TILE) for _, x, _ in cfg["zones"])
    for a, b in zip(zone_cols, zone_cols[1:]):
        if b - a < 2:
            problems.append("planting zones at columns %d and %d are too close" % (a, b))
    for c, row in cfg["seeds"]:
        if row is None and lv.heights[c] is None:
            problems.append("seed at column %d floats over a pit" % c)
        if row is not None and not any(r == row and c0 <= c <= c1 for r, c0, c1 in lv.ledges):
            problems.append("seed at column %d row %d has no ledge under it" % (c, row))
    # walkable path: steps of at most one tile, gaps of at most two columns
    prev_row, gap = None, 0
    for c in range(2, lv.width - 2):
        r = lv.heights[c]
        if r is None:
            gap += 1
            if gap > 2:
                problems.append("gap wider than 2 columns at column %d" % c)
            continue
        if prev_row is not None and prev_row - r > 1:
            problems.append("step up of %d tiles at column %d (max 1)" % (prev_row - r, c))
        prev_row, gap = r, 0
    # every pit must have a checkpoint somewhere after it (before the next pit)
    pits = [c for c in range(lv.width) if lv.heights[c] is None and lv.heights[c - 1] is not None]
    for i, p in enumerate(pits):
        nxt = pits[i + 1] if i + 1 < len(pits) else lv.width
        if not any(p < cp < nxt for cp in cfg.get("checkpoints", [])):
            problems.append("no checkpoint after the pit at column %d" % p)
    if problems:
        raise SystemExit("%s layout problems:\n  - " % lv.name + "\n  - ".join(problems))


def main():
    root = os.getcwd()
    assert os.path.exists(os.path.join(root, "project.godot")), "run from the project root"
    write_tileset(root)
    write_background(root)
    write_checkpoint_art(root)
    open(os.path.join(root, "the_last_forest/stage/checkpoint.tscn"), "w").write(CHECKPOINT_TSCN)
    for fn in (stage_1, stage_2, stage_3, stage_4):
        lv, cfg = fn()
        validate(lv, cfg)
        path = os.path.join(root, "the_last_forest/scenes/%s.tscn" % lv.name)
        open(path, "w").write(build_scene(lv, cfg))
        print("wrote %s  (%d columns = %d px wide, %d ledges)" % (path, lv.width, lv.width * TILE, len(lv.ledges)))


if __name__ == "__main__":
    main()
