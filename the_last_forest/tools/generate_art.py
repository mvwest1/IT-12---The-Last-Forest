# Usage: python3 generate_art.py ../art   (needs Pillow)
"""THE LAST FOREST — procedural pixel-art set (original art, generated).
Run: python3 art.py <out_dir>
Everything is drawn at native pixel size; Godot shows it with nearest filtering.
"""
import sys, os, math, random
from PIL import Image, ImageDraw

OUT = sys.argv[1] if len(sys.argv) > 1 else "art"
os.makedirs(OUT, exist_ok=True)
random.seed(7)

# ---------------------------------------------------------------- palette
OUTL = (43, 29, 22, 255)
LEAF = [(36, 84, 40, 255), (52, 115, 48, 255), (79, 155, 62, 255), (126, 196, 82, 255), (178, 226, 112, 255)]
BARK = [(70, 44, 26, 255), (98, 64, 37, 255), (133, 90, 52, 255)]
SOIL = [(46, 33, 27, 255), (66, 49, 38, 255), (92, 69, 52, 255)]
ASH = [(74, 68, 64, 255), (104, 97, 90, 255), (140, 132, 122, 255)]
EMBER = [(224, 112, 42, 255), (246, 178, 66, 255)]
WATER = [(35, 92, 190, 255), (66, 150, 232, 255), (160, 214, 255, 255)]
WOOD = [(110, 70, 36, 255), (150, 98, 52, 255), (201, 145, 82, 255)]
BAMBOO = [(76, 110, 44, 255), (118, 160, 66, 255), (176, 206, 104, 255)]
PARCH = [(244, 235, 208, 255), (226, 210, 168, 255)]
RED = [(140, 31, 45, 255), (217, 56, 74, 255), (255, 140, 150, 255)]
GOLD = [(176, 120, 30, 255), (246, 201, 69, 255), (255, 236, 150, 255)]
SKY = [(110, 170, 225, 255), (170, 214, 245, 255)]
SMOKE = [(120, 110, 104, 255), (156, 146, 138, 255)]
T = (0, 0, 0, 0)


def new(w, h, bg=T):
    im = Image.new("RGBA", (w, h), bg)
    return im, ImageDraw.Draw(im)


def save(im, name):
    im.save(os.path.join(OUT, name))


def outline(im, color=OUTL):
    """1-px outline around opaque pixels (pixel-art style)."""
    w, h = im.size
    src = im.load()
    out = im.copy()
    o = out.load()
    for y in range(h):
        for x in range(w):
            if src[x, y][3] == 0:
                for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                    nx, ny = x + dx, y + dy
                    if 0 <= nx < w and 0 <= ny < h and src[nx, ny][3] > 0:
                        o[x, y] = color
                        break
    return out


def blob(d, cx, cy, r, colors, light=(-0.4, -0.5)):
    """Shaded round leaf clump."""
    for y in range(int(cy - r), int(cy + r) + 1):
        for x in range(int(cx - r), int(cx + r) + 1):
            dx, dy = x - cx, y - cy
            dist = math.hypot(dx, dy)
            if dist <= r:
                shade = (dx * light[0] + dy * light[1]) / max(r, 1)
                k = 1 if shade < -0.25 else (2 if shade < 0.35 else 3)
                if dist > r - 1.2:
                    k = 0
                k = min(len(colors) - 1, k)
                d.point((x, y), fill=colors[k])


def canopy(d, cx, top, w, h, colors):
    """Cluster of blobs forming a tree crown."""
    r = w / 4
    pts = [(cx, top + h * 0.45, w * 0.42), (cx - w * 0.25, top + h * 0.6, w * 0.3),
           (cx + w * 0.25, top + h * 0.6, w * 0.3), (cx - w * 0.12, top + h * 0.3, w * 0.28),
           (cx + w * 0.14, top + h * 0.32, w * 0.27)]
    for (x, y, rr) in pts:
        blob(d, x, y, rr, colors)
    # highlights
    for i in range(int(w * h / 90)):
        x = random.randint(int(cx - w * 0.35), int(cx + w * 0.35))
        y = random.randint(int(top + h * 0.15), int(top + h * 0.7))
        if 0 <= x < d.im.size[0] and 0 <= y < d.im.size[1] and d.im.getpixel((x, y))[3] > 0:
            d.point((x, y), fill=colors[-1])


def trunk(d, cx, top, bottom, width):
    d.rectangle((cx - width // 2, top, cx + width // 2, bottom), fill=BARK[1])
    d.line((cx - width // 2, top, cx - width // 2, bottom), fill=BARK[0])
    d.line((cx + width // 2, top + 2, cx + width // 2, bottom), fill=BARK[2])


def tree(d, cx, base, h, colors=LEAF[1:], trunk_w=None):
    w = int(h * 0.75)
    tw = trunk_w or max(3, h // 9)
    trunk(d, cx, base - int(h * 0.45), base, tw)
    canopy(d, cx, base - h, w, int(h * 0.75), colors)


def burnt_tree(d, cx, base, h):
    d.line((cx, base, cx, base - h), fill=(30, 22, 18, 255), width=max(2, h // 12))
    d.line((cx, base - h * 0.6, cx - h * 0.25, base - h * 0.85), fill=(30, 22, 18, 255), width=2)
    d.line((cx, base - h * 0.45, cx + h * 0.22, base - h * 0.7), fill=(30, 22, 18, 255), width=2)


def ground(d, w, h, y, colors, top_colors=None):
    d.rectangle((0, y, w, h), fill=colors[1])
    for x in range(0, w):
        yy = y + int(2 * math.sin(x / 9.0))
        d.line((x, yy, x, y + 3), fill=(top_colors or colors)[0 if top_colors is None else 2])
    for i in range(w * (h - y) // 40):
        d.point((random.randint(0, w - 1), random.randint(y + 4, h - 1)), fill=colors[0])


# ================================================================ SPRITES
def sapling_stages():
    # 0 seedling
    im, d = new(16, 16)
    d.rectangle((3, 13, 12, 15), fill=SOIL[2])
    d.line((8, 13, 8, 8), fill=LEAF[1])
    d.ellipse((3, 6, 8, 9), fill=LEAF[3]); d.ellipse((8, 5, 13, 8), fill=LEAF[2])
    save(outline(im), "sapling_0.png")
    # 1 sprout
    im, d = new(24, 32)
    d.rectangle((5, 28, 18, 31), fill=SOIL[2])
    d.line((12, 28, 12, 12), fill=BARK[2], width=2)
    for (x, y, r, c) in [(7, 16, 4, 2), (17, 14, 4, 3), (10, 9, 4, 3), (15, 21, 3, 2), (8, 22, 3, 1)]:
        blob(d, x, y, r, LEAF[1:])
    save(outline(im), "sapling_1.png")
    # 2 young tree
    im, d = new(40, 56)
    d.rectangle((10, 52, 29, 55), fill=SOIL[2])
    tree(d, 20, 52, 46, trunk_w=4)
    save(outline(im), "sapling_2.png")
    # 3 mature tree
    im, d = new(64, 88)
    d.rectangle((14, 84, 49, 87), fill=SOIL[2])
    tree(d, 32, 84, 80, LEAF[:], trunk_w=7)
    # a few fruit/flowers for life
    for (x, y) in [(18, 30), (44, 26), (30, 18), (38, 44), (22, 46)]:
        d.point((x, y), fill=(255, 210, 90, 255)); d.point((x + 1, y), fill=(255, 150, 80, 255))
    save(outline(im), "sapling_3.png")


def seed():
    im, d = new(16, 16)
    d.ellipse((4, 3, 11, 13), fill=(176, 120, 64, 255))
    d.ellipse((5, 4, 9, 9), fill=(214, 160, 96, 255))
    d.line((8, 5, 8, 12), fill=(130, 84, 44, 255))
    d.point((6, 5), fill=(255, 236, 190, 255))
    im = outline(im)
    # glow sparkle
    for (x, y) in [(1, 2), (14, 4), (13, 13)]:
        im.putpixel((x, y), GOLD[2])
    save(im, "seed.png")


def pest():
    im, d = new(22, 18)
    d.ellipse((2, 0, 9, 6), fill=(220, 236, 255, 200)); d.ellipse((10, 0, 17, 6), fill=(220, 236, 255, 200))
    d.ellipse((3, 5, 17, 15), fill=(120, 150, 40, 255))
    d.ellipse((5, 6, 12, 10), fill=(160, 190, 60, 255))
    for x in (6, 10, 14):
        d.line((x, 7, x, 14), fill=(84, 104, 28, 255))
    d.ellipse((14, 6, 20, 12), fill=(84, 104, 28, 255))
    d.point((17, 8), fill=(255, 255, 255, 255)); d.point((18, 8), fill=(20, 20, 20, 255))
    d.line((19, 7, 21, 4), fill=OUTL)
    save(outline(im), "pest.png")


def guard_pickup():
    im, d = new(20, 22)
    for x in (3, 9, 15):
        d.rectangle((x, 3, x + 3, 21), fill=BAMBOO[1]); d.line((x, 3, x, 21), fill=BAMBOO[2])
        d.line((x, 9, x + 3, 9), fill=BAMBOO[0]); d.line((x, 16, x + 3, 16), fill=BAMBOO[0])
    d.rectangle((1, 7, 19, 8), fill=WOOD[1]); d.rectangle((1, 14, 19, 15), fill=WOOD[1])
    save(outline(im), "guard.png")


def guard_fence():
    im, d = new(40, 26)
    for x in range(2, 40, 6):
        d.rectangle((x, 4, x + 3, 25), fill=BAMBOO[1]); d.line((x, 4, x, 25), fill=BAMBOO[2])
        d.point((x + 1, 3), fill=BAMBOO[2])
    d.rectangle((0, 9, 39, 10), fill=WOOD[1]); d.rectangle((0, 18, 39, 19), fill=WOOD[1])
    save(outline(im), "guard_fence.png")


def water_drop():
    im, d = new(10, 12)
    d.polygon([(5, 0), (1, 6), (9, 6)], fill=WATER[1])
    d.ellipse((1, 3, 9, 11), fill=WATER[1])
    d.point((3, 6), fill=WATER[2]); d.point((3, 7), fill=WATER[2])
    save(outline(im, (20, 50, 120, 255)), "water_drop.png")


def soil_mound():
    im, d = new(56, 16)
    d.ellipse((2, 4, 53, 22), fill=SOIL[1])
    d.ellipse((6, 5, 49, 16), fill=SOIL[2])
    for (x, y) in [(14, 8), (30, 7), (41, 9), (22, 11)]:
        d.point((x, y), fill=EMBER[0]); d.point((x + 1, y), fill=EMBER[1])
    for (x, y) in [(10, 10), (36, 12), (46, 11)]:
        d.point((x, y), fill=ASH[2])
    save(outline(im), "soil_mound.png")


def sign():
    im, d = new(30, 38)
    d.rectangle((13, 18, 16, 37), fill=WOOD[0])
    d.rounded_rectangle((1, 1, 28, 20), 3, fill=WOOD[2])
    d.rectangle((3, 3, 26, 18), fill=WOOD[1])
    # "?"
    d.arc((10, 4, 19, 12), 180, 90, fill=PARCH[0], width=2)
    d.line((15, 11, 15, 13), fill=PARCH[0], width=2); d.rectangle((14, 15, 15, 16), fill=PARCH[0])
    save(outline(im), "sign.png")


def lever():
    im, d = new(18, 38)
    d.rectangle((2, 30, 15, 37), fill=WOOD[1]); d.line((2, 30, 15, 30), fill=WOOD[2])
    d.rectangle((7, 4, 10, 31), fill=WOOD[0]); d.line((7, 4, 7, 31), fill=WOOD[2])
    d.ellipse((4, 0, 13, 9), fill=RED[1]); d.point((6, 2), fill=RED[2])
    save(outline(im), "lever.png")


def spout():
    im, d = new(34, 22)
    d.rectangle((0, 4, 30, 13), fill=BAMBOO[1]); d.line((0, 4, 30, 4), fill=BAMBOO[2])
    d.line((10, 4, 10, 13), fill=BAMBOO[0]); d.line((21, 4, 21, 13), fill=BAMBOO[0])
    d.ellipse((24, 8, 33, 18), fill=BAMBOO[0]); d.ellipse((26, 10, 31, 16), fill=WATER[0])
    save(outline(im), "spout.png")


def gate(open_):
    im, d = new(56, 104)
    # posts
    d.rectangle((2, 20, 11, 103), fill=WOOD[1]); d.line((2, 20, 2, 103), fill=WOOD[2])
    d.rectangle((44, 20, 53, 103), fill=WOOD[1]); d.line((44, 20, 44, 103), fill=WOOD[2])
    # arch beam
    d.rectangle((0, 12, 55, 22), fill=WOOD[0]); d.line((0, 12, 55, 12), fill=WOOD[2])
    leaf_cols = LEAF[1:] if open_ else [(80, 70, 50, 255), (110, 92, 62, 255), (138, 116, 78, 255)]
    for (x, y, r) in [(6, 10, 7), (18, 7, 7), (30, 8, 8), (43, 7, 7), (52, 11, 6), (3, 26, 5), (52, 28, 5)]:
        blob(d, x, y, r, leaf_cols)
    if open_:
        # glowing portal
        for i in range(10):
            a = 60 + i * 12
            d.rectangle((12 + i // 2, 24 + i, 43 - i // 2, 103), fill=(120, 230, 140, a))
        for (x, y) in [(20, 50), (34, 40), (26, 70), (38, 82), (17, 88)]:
            d.point((x, y), fill=GOLD[2])
        for (x, y) in [(12, 40), (46, 60), (10, 80), (48, 90)]:
            blob(d, x, y, 3, LEAF[2:])
    else:
        # tangled dry vines across the doorway
        for k in range(5):
            y0 = 30 + k * 15
            pts = [(12 + j * 4, y0 + int(4 * math.sin(j + k))) for j in range(9)]
            d.line(pts, fill=(96, 70, 46, 255), width=2)
    save(outline(im), "gate_open.png" if open_ else "gate_closed.png")


def icons():
    # hearts 18x16
    for name, cols in (("heart_full.png", RED), ("heart_empty.png", [(70, 60, 60, 255), (104, 92, 92, 255), (140, 128, 128, 255)])):
        im, d = new(18, 16)
        d.ellipse((1, 1, 9, 9), fill=cols[1]); d.ellipse((8, 1, 16, 9), fill=cols[1])
        d.polygon([(1, 6), (16, 6), (9, 15)], fill=cols[1])
        d.point((4, 3), fill=cols[2]); d.point((5, 3), fill=cols[2]); d.point((4, 4), fill=cols[2])
        save(outline(im), name)
    im, d = new(18, 18); tree(d, 9, 17, 16, trunk_w=3); save(outline(im), "tree_icon.png")
    im, d = new(16, 18); d.polygon([(8, 1), (2, 10), (14, 10)], fill=WATER[1]); d.ellipse((2, 6, 14, 17), fill=WATER[1]); d.point((5, 10), fill=WATER[2]); save(outline(im), "water_icon.png")
    # star 28x27
    for name, cols in (("star_full.png", GOLD), ("star_empty.png", [(90, 80, 70, 255), (130, 118, 104, 255), (160, 150, 136, 255)])):
        im, d = new(28, 27)
        pts = []
        for i in range(10):
            ang = -math.pi / 2 + i * math.pi / 5
            r = 13 if i % 2 == 0 else 5.5
            pts.append((14 + r * math.cos(ang), 14 + r * math.sin(ang)))
        d.polygon(pts, fill=cols[1]); d.polygon([(14, 4), (11, 12), (14, 12)], fill=cols[2])
        save(outline(im), name)
    # leaf particle 6x5, sparkle 5x5, lock 14x16, check 14x12
    im, d = new(6, 5); d.ellipse((0, 0, 5, 4), fill=LEAF[3]); d.point((1, 1), fill=LEAF[4]); save(im, "leaf.png")
    im, d = new(5, 5); d.line((2, 0, 2, 4), fill=GOLD[2]); d.line((0, 2, 4, 2), fill=GOLD[2]); save(im, "sparkle.png")
    im, d = new(14, 16); d.arc((2, 0, 11, 11), 180, 360, fill=ASH[2], width=2); d.rectangle((1, 6, 12, 15), fill=GOLD[1]); d.rectangle((6, 9, 7, 12), fill=OUTL); save(outline(im), "lock.png")
    im, d = new(14, 12); d.line([(1, 6), (5, 10), (12, 1)], fill=LEAF[3], width=3); save(outline(im), "check.png")


# ================================================================ SCENES (thumbnails / facts / menu)
def sky(d, w, h, burnt=0.0):
    for y in range(h):
        t = y / h
        a = SKY[0] if burnt < 0.5 else SMOKE[0]
        b = SKY[1] if burnt < 0.5 else SMOKE[1]
        c = tuple(int(a[i] + (b[i] - a[i]) * t) for i in range(3)) + (255,)
        d.line((0, y, w, y), fill=c)


def cloud(d, x, y, s=1.0, col=(250, 250, 255, 255)):
    for (dx, dy, r) in [(0, 0, 6), (7, -3, 7), (14, 0, 6), (7, 2, 6)]:
        d.ellipse((x + dx * s - r * s, y + dy * s - r * s, x + dx * s + r * s, y + dy * s + r * s), fill=col)


def sun(d, x, y, r=9):
    d.ellipse((x - r, y - r, x + r, y + r), fill=GOLD[2]); d.ellipse((x - r + 3, y - r + 3, x + r - 3, y + r - 3), fill=(255, 248, 200, 255))


def thumb_burnt(w=160, h=90):
    im, d = new(w, h); sky(d, w, h, burnt=1)
    for x in range(10, w, 26): burnt_tree(d, x + random.randint(-4, 4), 72, random.randint(26, 40))
    ground(d, w, h, 72, SOIL)
    for (x, y) in [(30, 70), (88, 69), (130, 71)]:
        d.point((x, y), fill=EMBER[1]); d.point((x + 1, y - 1), fill=EMBER[0])
    tree(d, 60, 74, 22, trunk_w=3); tree(d, 104, 74, 16, trunk_w=2)
    return im


def thumb_pests(w=160, h=90):
    im, d = new(w, h); sky(d, w, h)
    cloud(d, 30, 18); cloud(d, 118, 12, 0.8)
    ground(d, w, h, 70, SOIL, LEAF)
    for x in (34, 80, 126): tree(d, x, 72, 30, trunk_w=3)
    gf = Image.open(os.path.join(OUT, "guard_fence.png")); im.alpha_composite(gf.resize((30, 20), Image.NEAREST), (65, 52))
    p = Image.open(os.path.join(OUT, "pest.png"))
    for (x, y) in [(46, 30), (100, 22), (140, 40)]: im.alpha_composite(p, (x, y))
    return im


def thumb_water(w=160, h=90):
    im, d = new(w, h); sky(d, w, h)
    cloud(d, 120, 16)
    ground(d, w, h, 72, SOIL, LEAF)
    d.rectangle((60, 72, 130, 76), fill=(196, 160, 110, 255))
    for x in range(64, 128, 9): d.line((x, 73, x + 4, 76), fill=(130, 100, 70, 255))
    sp = Image.open(os.path.join(OUT, "spout.png")); im.alpha_composite(sp, (20, 26))
    d.line((40, 52, 70, 60), fill=BAMBOO[1], width=3)
    for (x, y) in [(52, 40), (55, 47), (72, 60), (78, 66), (86, 70)]:
        d.ellipse((x - 2, y - 2, x + 2, y + 2), fill=WATER[1])
    lv = Image.open(os.path.join(OUT, "lever.png")); im.alpha_composite(lv, (8, 38))
    tree(d, 100, 74, 22, trunk_w=3); tree(d, 142, 74, 28, trunk_w=3)
    return im


def thumb_sanctuary(w=160, h=90):
    im, d = new(w, h); sky(d, w, h)
    sun(d, 130, 18); cloud(d, 30, 16)
    ground(d, w, h, 70, SOIL, LEAF)
    for x in range(0, w + 20, 22): tree(d, x + random.randint(-3, 3), 72, random.randint(30, 44), trunk_w=3)
    eagle(d, 70, 22)
    for (x, y) in [(20, 74), (60, 76), (120, 75)]:
        d.point((x, y), fill=(255, 120, 160, 255)); d.point((x + 1, y), fill=GOLD[1])
    return im


def eagle(d, x, y, s=1):
    body = (98, 70, 44, 255); wing = (78, 54, 34, 255); cream = (236, 226, 200, 255)
    d.polygon([(x - 18 * s, y + 2 * s), (x - 4 * s, y - 4 * s), (x, y + 2 * s)], fill=wing)
    d.polygon([(x + 18 * s, y + 2 * s), (x + 4 * s, y - 4 * s), (x, y + 2 * s)], fill=wing)
    d.ellipse((x - 4 * s, y - 3 * s, x + 4 * s, y + 6 * s), fill=body)
    d.ellipse((x - 3 * s, y - 8 * s, x + 3 * s, y - 2 * s), fill=cream)
    d.polygon([(x + 2 * s, y - 6 * s), (x + 6 * s, y - 5 * s), (x + 2 * s, y - 4 * s)], fill=GOLD[1])


def fact_carbon(w=192, h=108):
    im, d = new(w, h); sky(d, w, h); sun(d, 170, 18); ground(d, w, h, 88, SOIL, LEAF)
    tree(d, 96, 90, 70, trunk_w=6)
    for (x, y) in [(20, 30), (36, 52), (160, 44), (150, 66)]:
        d.ellipse((x - 9, y - 7, x + 9, y + 7), fill=(200, 200, 210, 255))
        d.text((x - 7, y - 5), "CO2", fill=(60, 60, 70, 255))
    d.line((30, 40, 70, 50), fill=(255, 255, 255, 255), width=2); d.polygon([(70, 46), (76, 51), (69, 54)], fill=(255, 255, 255, 255))
    d.line((152, 54, 122, 58), fill=(255, 255, 255, 255), width=2); d.polygon([(122, 54), (116, 59), (123, 62)], fill=(255, 255, 255, 255))
    return im


def fact_burning(w=192, h=108):
    im, d = new(w, h); sky(d, w, h, burnt=1); ground(d, w, h, 86, SOIL)
    for x in range(14, w, 28): burnt_tree(d, x, 88, random.randint(30, 50))
    for x in range(20, w, 36):
        d.polygon([(x, 88), (x + 6, 70), (x + 12, 88)], fill=EMBER[0]); d.polygon([(x + 3, 88), (x + 6, 78), (x + 9, 88)], fill=EMBER[1])
    for i, (x, y) in enumerate([(40, 40), (90, 26), (140, 36)]):
        d.ellipse((x - 14, y - 9, x + 14, y + 9), fill=SMOKE[1])
        d.text((x - 8, y - 5), "CO2", fill=(50, 40, 40, 255))
    return im


def fact_roots(w=192, h=108):
    im, d = new(w, h); sky(d, w, h); ground(d, w, h, 46, SOIL, LEAF)
    tree(d, 96, 48, 40, trunk_w=5)
    for (dx, dy) in [(-40, 30), (-24, 44), (0, 50), (22, 44), (44, 30), (-10, 26), (14, 28)]:
        d.line((96, 48, 96 + dx, 48 + dy), fill=BARK[2], width=2)
        d.line((96 + dx * 0.6, 48 + dy * 0.6, 96 + dx * 0.6 - 6, 48 + dy * 0.6 + 6), fill=BARK[2])
    for i in range(30):
        x, y = random.randint(0, w), random.randint(54, h)
        d.ellipse((x - 2, y - 1, x + 2, y + 1), fill=SOIL[2])
    return im


def fact_helpers(w=192, h=108):
    im, d = new(w, h); sky(d, w, h); cloud(d, 40, 16); ground(d, w, h, 88, SOIL, LEAF)
    tree(d, 60, 90, 54, trunk_w=5)
    # ladybug
    d.ellipse((110, 70, 132, 86), fill=RED[1]); d.line((121, 70, 121, 86), fill=OUTL)
    for (x, y) in [(115, 75), (126, 74), (116, 81), (127, 81)]: d.ellipse((x - 2, y - 2, x + 2, y + 2), fill=OUTL)
    d.ellipse((130, 74, 138, 82), fill=OUTL)
    # bird
    d.ellipse((150, 30, 172, 46), fill=(80, 120, 200, 255)); d.ellipse((166, 26, 178, 38), fill=(80, 120, 200, 255))
    d.polygon([(178, 31), (186, 33), (178, 35)], fill=GOLD[1]); d.point((172, 30), fill=OUTL)
    d.polygon([(152, 36), (140, 28), (158, 40)], fill=(60, 90, 160, 255))
    p = Image.open(os.path.join(OUT, "pest.png")); im.alpha_composite(p, (138, 60))
    return im


def fact_care(w=192, h=108):
    im, d = new(w, h); sky(d, w, h); sun(d, 30, 20); ground(d, w, h, 86, SOIL, LEAF)
    sp = Image.open(os.path.join(OUT, "sapling_2.png")); im.alpha_composite(sp, (76, 34))
    gf = Image.open(os.path.join(OUT, "guard_fence.png")); im.alpha_composite(gf, (76, 64))
    # watering can
    d.rectangle((130, 50, 154, 68), fill=(110, 150, 200, 255)); d.line((154, 54, 166, 46), fill=(110, 150, 200, 255), width=3)
    d.arc((134, 40, 150, 56), 180, 360, fill=(80, 110, 160, 255), width=2)
    for (x, y) in [(160, 56), (156, 62), (150, 68)]: d.ellipse((x - 2, y - 2, x + 2, y + 2), fill=WATER[1])
    return im


def fact_rain(w=192, h=108):
    im, d = new(w, h); sky(d, w, h); ground(d, w, h, 88, SOIL, LEAF)
    cloud(d, 70, 18, 1.6, (235, 240, 250, 255)); cloud(d, 120, 22, 1.3, (225, 232, 245, 255))
    for x in range(56, 150, 10):
        for y in range(34, 70, 14): d.line((x, y + (x % 7), x - 2, y + 5 + (x % 7)), fill=WATER[1])
    for x in (40, 96, 152): tree(d, x, 90, 40, trunk_w=4)
    for (x, y) in [(40, 46), (96, 46), (152, 46)]:
        d.line((x, y, x, y - 8), fill=(255, 255, 255, 200)); d.polygon([(x - 2, y - 8), (x, y - 12), (x + 2, y - 8)], fill=(255, 255, 255, 200))
    return im


def fact_home(w=192, h=108):
    im, d = new(w, h); sky(d, w, h); sun(d, 172, 16); ground(d, w, h, 90, SOIL, LEAF)
    for x in range(0, w + 30, 26): tree(d, x, 92, random.randint(40, 62), trunk_w=4)
    eagle(d, 96, 30, 2)
    return im


def menu_bg(w=400, h=240):
    im, d = new(w, h)
    for y in range(h):
        t = y / h
        for x in range(w):
            k = x / w  # left burnt -> right green
            a = tuple(int(SMOKE[0][i] * (1 - k) + SKY[0][i] * k) for i in range(3))
            b = tuple(int(SMOKE[1][i] * (1 - k) + SKY[1][i] * k) for i in range(3))
            d.point((x, y), fill=tuple(int(a[i] + (b[i] - a[i]) * t) for i in range(3)) + (255,))
    sun(d, 360, 34, 14); cloud(d, 300, 40, 1.4); cloud(d, 230, 26, 1.1)
    for x in range(-4, w + 20, 18):
        k = x / w
        base = 200 + int(6 * math.sin(x / 30))
        if k < 0.38: burnt_tree(d, x, base, random.randint(36, 64))
        elif k < 0.55:
            if random.random() < 0.6: burnt_tree(d, x, base, random.randint(30, 50))
            else: tree(d, x, base, random.randint(20, 34), trunk_w=3)
        else: tree(d, x, base, random.randint(46, 80), trunk_w=5)
    for x in range(w):
        k = x / w
        col = SOIL if k < 0.45 else SOIL
        top = 196 + int(4 * math.sin(x / 20))
        d.line((x, top, x, h), fill=col[1])
        g = LEAF[2] if k > 0.5 else (ASH[1] if k < 0.4 else LEAF[1])
        d.line((x, top, x, top + 3), fill=g)
    for (x, y) in [(40, 199), (90, 201), (130, 198)]:
        d.point((x, y), fill=EMBER[1]); d.point((x + 1, y), fill=EMBER[0])
    for i in range(14):
        x = random.randint(int(w * 0.55), w - 5); y = random.randint(204, h - 4)
        d.point((x, y), fill=(255, 130, 170, 255)); d.point((x + 1, y), fill=GOLD[1])
    eagle(d, 300, 80, 1)
    return im.resize((w * 2, h * 2), Image.NEAREST)


def main():
    sapling_stages(); seed(); pest(); guard_pickup(); guard_fence(); water_drop()
    soil_mound(); sign(); lever(); spout(); gate(False); gate(True); icons()
    for name, fn in [("thumb_stage_1", thumb_burnt), ("thumb_stage_2", thumb_pests),
                     ("thumb_stage_3", thumb_water), ("thumb_stage_4", thumb_sanctuary)]:
        save(fn(), name + ".png")
    for name, fn in [("fact_trees_store_carbon", fact_carbon), ("fact_burning_releases_co2", fact_burning),
                     ("fact_roots_hold_soil", fact_roots), ("fact_natural_helpers", fact_helpers),
                     ("fact_care_after_planting", fact_care), ("fact_trees_make_rain", fact_rain),
                     ("fact_forest_home", fact_home)]:
        save(fn(), name + ".png")
    save(menu_bg(), "menu_bg.png")


if __name__ == "__main__":
    main()
