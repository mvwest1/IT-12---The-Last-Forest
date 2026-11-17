"""Production art pack matching the Chapter III asset descriptions.
Run from the project root:  python the_last_forest/tools/generate_production_art.py

  seeds/       Narra, Lauan and Dao seed pouches
  guard.png / guard_fence.png      bamboo-and-mesh tree guard
  beetle.png (2 frames) / caterpillar.png (2 frames)   non-violent pests
  butterfly.png / bird.png (2 frames each)             returning wildlife
  sluice.png    wooden irrigation channel for the Stage 3 lever
  parchment.png 9-slice parchment-and-leaf card for fact cards / journal
  ui_*.png      HUD icons (pause, journal, trophy, settings, sound)
  logo.png, icon_*.png, splash.png  game logo, app icons, boot splash
"""
import math, os, random
from PIL import Image, ImageDraw, ImageFilter, ImageFont

ART = "the_last_forest/art"
OUTLINE = (34, 28, 22, 255)
rnd = random.Random(12)


def outline(im, col=OUTLINE):
    px = im.load(); out = im.copy(); op = out.load()
    for y in range(im.height):
        for x in range(im.width):
            if px[x, y][3] == 0:
                for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                    nx, ny = x + dx, y + dy
                    if 0 <= nx < im.width and 0 <= ny < im.height and px[nx, ny][3] > 128:
                        op[x, y] = col; break
    return out


def save(im, name, scale=1):
    if scale != 1:
        im = im.resize((im.width * scale, im.height * scale), Image.NEAREST)
    path = os.path.join(ART, name)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    im.save(path)
    return path


# ------------------------------------------------------------------ seeds
def seed_pouch(cloth, cloth_d, seed_col, seed_shape):
    im = Image.new("RGBA", (16, 16), (0, 0, 0, 0)); d = ImageDraw.Draw(im)
    d.polygon([(4, 6), (11, 6), (13, 14), (2, 14)], fill=cloth)          # pouch body
    d.line([(3, 14), (12, 14)], fill=cloth_d)
    d.rectangle([5, 4, 10, 6], fill=cloth_d)                              # neck tie
    d.line([(6, 3), (9, 3)], fill=(196, 160, 98))                         # string
    if seed_shape == "pod":      # Narra: round winged pod
        d.ellipse([5, 8, 10, 13], fill=seed_col); d.point((7, 10), fill=(90, 64, 30))
    elif seed_shape == "wing":   # Lauan (dipterocarp): winged seed
        d.ellipse([6, 10, 9, 13], fill=seed_col)
        d.line([(7, 10), (5, 7)], fill=(214, 186, 120)); d.line([(8, 10), (10, 7)], fill=(214, 186, 120))
    else:                        # Dao: oval nut
        d.ellipse([5, 8, 10, 12], fill=seed_col); d.line([(6, 10), (9, 10)], fill=(70, 44, 24))
    return outline(im)


SEEDS = {
    "narra": ((178, 132, 70), (140, 100, 50), (160, 116, 52), "pod"),
    "lauan": ((116, 150, 82), (86, 116, 60), (176, 120, 66), "wing"),
    "dao": ((170, 86, 70), (128, 62, 50), (120, 78, 44), "nut"),
}


# ------------------------------------------------------------------ bamboo guard
def bamboo_guard(w, h, stakes):
    im = Image.new("RGBA", (w, h), (0, 0, 0, 0)); d = ImageDraw.Draw(im)
    for i in range(stakes):
        x = round(1 + i * (w - 4) / (stakes - 1))
        d.rectangle([x, 1, x + 2, h - 1], fill=(196, 176, 92))
        d.line([(x, 1), (x, h - 1)], fill=(150, 132, 60))
        for y in range(4, h - 1, 7):
            d.line([(x, y), (x + 2, y)], fill=(120, 104, 44))           # bamboo nodes
    for y in range(4, h - 2, 4):                                          # mesh
        for x in range(1, w - 1, 4):
            d.point((x + (y // 4) % 2 * 2, y), fill=(210, 210, 200, 200))
    d.line([(0, h // 3), (w - 1, h // 3)], fill=(140, 96, 52))           # rattan ties
    d.line([(0, 2 * h // 3), (w - 1, 2 * h // 3)], fill=(140, 96, 52))
    return outline(im)


# ------------------------------------------------------------------ pests & wildlife
def beetle(frame):
    im = Image.new("RGBA", (22, 18), (0, 0, 0, 0)); d = ImageDraw.Draw(im)
    if frame == 1:
        d.ellipse([3, 1, 10, 7], fill=(220, 236, 240, 170)); d.ellipse([11, 1, 18, 7], fill=(220, 236, 240, 170))
    d.ellipse([4, 6, 17, 16], fill=(52, 150, 96))                         # shell (leaf beetle)
    d.line([(10, 7), (10, 15)], fill=(28, 96, 60))
    d.point((7, 9), fill=(140, 220, 160)); d.point((13, 9), fill=(140, 220, 160))
    d.ellipse([15, 8, 20, 13], fill=(30, 40, 30))                         # head
    d.point((18, 10), fill=(250, 250, 240))
    d.line([(19, 8), (21, 5)], fill=(30, 40, 30))
    for x in (7, 11, 14):
        d.line([(x, 15), (x - 1, 17)], fill=(30, 40, 30))
    return outline(im)


def caterpillar(frame):
    im = Image.new("RGBA", (26, 13), (0, 0, 0, 0)); d = ImageDraw.Draw(im)
    hump = [0, 2, 0] if frame == 0 else [1, 0, 1]
    for i in range(5):
        y = 5 - (2 if (i == 2 and frame == 0) else (1 if i in (1, 3) and frame == 1 else 0))
        d.ellipse([1 + i * 4, y, 7 + i * 4, y + 6], fill=(150, 196, 64) if i % 2 else (126, 176, 52))
        d.point((4 + i * 4, y + 2), fill=(246, 210, 72))
    d.ellipse([19, 2, 25, 9], fill=(214, 120, 52))                       # head
    d.point((23, 4), fill=(30, 30, 30))
    d.line([(21, 2), (20, 0)], fill=(60, 40, 20)); d.line([(23, 2), (24, 0)], fill=(60, 40, 20))
    return outline(im)


def butterfly(frame):
    im = Image.new("RGBA", (12, 10), (0, 0, 0, 0)); d = ImageDraw.Draw(im)
    col, col2 = (246, 178, 56), (236, 110, 60)
    if frame == 0:
        d.ellipse([0, 0, 5, 5], fill=col); d.ellipse([6, 0, 11, 5], fill=col)
        d.ellipse([1, 4, 5, 8], fill=col2); d.ellipse([6, 4, 10, 8], fill=col2)
    else:
        d.ellipse([3, 1, 5, 7], fill=col); d.ellipse([6, 1, 8, 7], fill=col)
    d.line([(5, 1), (5, 8)], fill=(40, 30, 20)); d.line([(6, 1), (6, 8)], fill=(40, 30, 20))
    return outline(im)


def bird(frame):
    im = Image.new("RGBA", (18, 12), (0, 0, 0, 0)); d = ImageDraw.Draw(im)
    body = (86, 132, 196)
    d.ellipse([4, 5, 13, 10], fill=body)                                  # body
    d.ellipse([11, 3, 16, 8], fill=body)                                  # head
    d.point((14, 5), fill=(20, 20, 20)); d.line([(16, 6), (17, 6)], fill=(246, 190, 60))
    d.polygon([(4, 7), (0, 5), (1, 9)], fill=(60, 100, 160))              # tail
    if frame == 0:
        d.polygon([(6, 6), (10, 6), (7, 0)], fill=(60, 100, 160))         # wing up
    else:
        d.polygon([(6, 7), (11, 7), (8, 11)], fill=(60, 100, 160))        # wing down
    d.ellipse([7, 7, 11, 9], fill=(232, 220, 180))                        # belly
    return outline(im)


def strip(frames):
    w, h = frames[0].size
    s = Image.new("RGBA", (w * len(frames), h), (0, 0, 0, 0))
    for i, f in enumerate(frames):
        s.alpha_composite(f, (i * w, 0))
    return s


# ------------------------------------------------------------------ sluice / parchment / UI
def sluice():
    im = Image.new("RGBA", (150, 12), (0, 0, 0, 0)); d = ImageDraw.Draw(im)
    d.rectangle([0, 2, 149, 11], fill=(132, 88, 48))
    d.rectangle([0, 0, 149, 2], fill=(160, 112, 64))
    for x in range(0, 150, 25):
        d.line([(x, 0), (x, 11)], fill=(96, 62, 32))
        d.point((x + 3, 6), fill=(70, 46, 26)); d.point((x + 21, 6), fill=(70, 46, 26))
    d.line([(0, 11), (149, 11)], fill=(80, 52, 28))
    return im


def parchment():
    w = h = 64
    im = Image.new("RGBA", (w, h), (0, 0, 0, 0)); d = ImageDraw.Draw(im)
    d.rounded_rectangle([1, 1, w - 2, h - 2], 9, fill=(244, 232, 196), outline=(122, 92, 48), width=2)
    d.rounded_rectangle([5, 5, w - 6, h - 6], 6, outline=(96, 150, 70), width=1)
    px = im.load()
    for y in range(4, h - 4):
        for x in range(4, w - 4):
            if px[x, y][3] and rnd.random() < 0.18:
                r, g, b, a = px[x, y]
                k = rnd.randint(-10, 6)
                px[x, y] = (max(0, r + k), max(0, g + k), max(0, b + k), a)
    # small leaves in corners
    for cx, cy, fl in ((8, 8, 1), (w - 9, 8, -1), (8, h - 9, 1), (w - 9, h - 9, -1)):
        d.polygon([(cx, cy), (cx + 5 * fl, cy - 2), (cx + 3 * fl, cy + 3)], fill=(84, 150, 64))
    return im


def icon(kind, size=24):
    im = Image.new("RGBA", (size, size), (0, 0, 0, 0)); d = ImageDraw.Draw(im)
    W = (250, 248, 236)
    if kind == "pause":
        d.rectangle([6, 4, 10, 19], fill=W); d.rectangle([14, 4, 18, 19], fill=W)
    elif kind == "journal":
        d.rectangle([4, 3, 19, 20], fill=(150, 98, 52)); d.rectangle([6, 4, 18, 19], fill=(244, 232, 196))
        d.polygon([(9, 15), (12, 7), (15, 15)], fill=(84, 150, 64)); d.line([(12, 9), (12, 17)], fill=(52, 100, 44))
    elif kind == "trophy":
        d.rectangle([7, 3, 16, 10], fill=(246, 201, 69)); d.ellipse([7, 6, 16, 13], fill=(246, 201, 69))
        d.rectangle([10, 13, 13, 16], fill=(214, 168, 46)); d.rectangle([7, 17, 16, 19], fill=(150, 98, 52))
        d.arc([2, 3, 9, 11], 90, 270, fill=(246, 201, 69), width=2); d.arc([14, 3, 21, 11], 270, 90, fill=(246, 201, 69), width=2)
    elif kind == "settings":
        d.ellipse([5, 5, 18, 18], fill=W)
        for a in range(0, 360, 45):
            x = 11.5 + math.cos(math.radians(a)) * 9; y = 11.5 + math.sin(math.radians(a)) * 9
            d.rectangle([x - 2, y - 2, x + 2, y + 2], fill=W)
        d.ellipse([9, 9, 14, 14], fill=(0, 0, 0, 0))
    elif kind == "story":
        d.rectangle([3, 5, 11, 19], fill=W); d.rectangle([12, 5, 20, 19], fill=(230, 226, 210))
        d.line([(5, 9), (9, 9)], fill=(120, 110, 90)); d.line([(14, 9), (18, 9)], fill=(120, 110, 90))
        d.line([(5, 12), (9, 12)], fill=(120, 110, 90)); d.line([(14, 12), (18, 12)], fill=(120, 110, 90))
    return outline(im)


# ------------------------------------------------------------------ logo / icon / splash
FONT_SERIF = "/usr/share/fonts/truetype/dejavu/DejaVuSerif-Bold.ttf"
FONT_PIXEL = "gui/kenney_mini_square.ttf"


def tree_emblem(size, burnt_half=True):
    """A tree in a gold ring: left half burnt and smoky, right half green and
    sunny, telling the game's burnt -> restored story in one picture."""
    S = size * 4  # draw large, downsample for smooth edges
    im = Image.new("RGBA", (S, S), (0, 0, 0, 0)); d = ImageDraw.Draw(im)
    d.rectangle([0, 0, S // 2, S], fill=(118, 116, 112))               # smoky sky
    d.rectangle([S // 2, 0, S, S], fill=(132, 200, 226))               # clear sky
    d.ellipse([S * 0.66, S * 0.12, S * 0.84, S * 0.30], fill=(250, 220, 110))  # sun
    d.rectangle([0, S * 0.70, S // 2, S], fill=(70, 62, 56))           # ash ground
    d.rectangle([S // 2, S * 0.70, S, S], fill=(92, 150, 62))          # grass
    d.rectangle([S * 0.47, S * 0.42, S * 0.53, S * 0.74], fill=(112, 76, 44))  # trunk
    canopy = [(0.5, 0.34, 0.2), (0.35, 0.44, 0.14), (0.65, 0.44, 0.14), (0.5, 0.22, 0.13)]
    for x, y, r in canopy:
        d.ellipse([S * (x - r), S * (y - r), S * (x + r), S * (y + r)], fill=(80, 166, 74))
    if burnt_half:
        px = im.load()
        for yy in range(S):
            for xx in range(S // 2):
                r, g, b, a = px[xx, yy]
                if (r, g, b) in ((80, 166, 74), (112, 76, 44)):
                    px[xx, yy] = (52, 48, 46, a) if (r, g, b) == (80, 166, 74) else (40, 34, 30, a)
        for k in range(5):  # smoke puffs
            cx, cy = S * (0.12 + 0.07 * k), S * (0.18 + 0.03 * (k % 2))
            d.ellipse([cx - S * 0.05, cy - S * 0.04, cx + S * 0.05, cy + S * 0.04], fill=(150, 148, 144))
        d.line([(S // 2, 0), (S // 2, S)], fill=(232, 190, 80), width=max(2, S // 120))
    mask = Image.new("L", (S, S), 0)
    ImageDraw.Draw(mask).ellipse([S * 0.04, S * 0.04, S * 0.96, S * 0.96], fill=255)
    out = Image.new("RGBA", (S, S), (0, 0, 0, 0)); out.paste(im, (0, 0), mask)
    ImageDraw.Draw(out).ellipse([S * 0.04, S * 0.04, S * 0.96, S * 0.96], outline=(232, 190, 80), width=S // 22)
    return out.resize((size, size), Image.LANCZOS)


def logo(w=900, h=420):
    im = Image.new("RGBA", (w, h), (0, 0, 0, 0)); d = ImageDraw.Draw(im)
    for y in range(h):  # forest-green gradient like the official logo
        t = y / h
        col = (int(34 + 30 * t), int(76 + 50 * t), int(44 + 36 * t), 255)
        d.line([(0, y), (w, y)], fill=col)
    d.rectangle([12, 12, w - 13, h - 13], outline=(214, 182, 96), width=5)
    f1 = ImageFont.truetype(FONT_SERIF, 74); f2 = ImageFont.truetype(FONT_SERIF, 28)
    title = "THE LAST FOREST"
    tw = d.textlength(title, font=f1)
    d.text(((w - tw) / 2 + 3, 113), title, font=f1, fill=(60, 40, 18))
    d.text(((w - tw) / 2, 110), title, font=f1, fill=(244, 214, 120))
    tag = "Plant. Protect. Restore the Canopy."
    d.text(((w - d.textlength(tag, font=f2)) / 2, 222), tag, font=f2, fill=(240, 244, 232))
    em = tree_emblem(110)
    im.alpha_composite(em, ((w - 110) // 2, 280))
    return im


def app_icon(size):
    im = Image.new("RGBA", (size, size), (0, 0, 0, 0)); d = ImageDraw.Draw(im)
    d.rounded_rectangle([0, 0, size - 1, size - 1], size // 6, fill=(34, 82, 48))
    d.rounded_rectangle([size * 0.05, size * 0.05, size * 0.95, size * 0.95], size // 8, outline=(232, 190, 80), width=max(2, size // 40))
    em = tree_emblem(int(size * 0.8))
    im.alpha_composite(em, (int(size * 0.1), int(size * 0.1)))
    return im


def adaptive_fg(size=432):
    # Android adaptive icons crop to the inner ~66 %: keep the emblem in the safe zone.
    im = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    em = tree_emblem(int(size * 0.62))
    im.alpha_composite(em, (int(size * 0.19), int(size * 0.19)))
    return im


def adaptive_bg(size=432):
    im = Image.new("RGBA", (size, size)); d = ImageDraw.Draw(im)
    for y in range(size):
        t = y / size
        d.line([(0, y), (size, y)], fill=(int(30 + 30 * t), int(70 + 50 * t), int(42 + 30 * t), 255))
    return im


def splash(w=1280, h=720):
    im = Image.new("RGBA", (w, h), (24, 52, 32, 255))
    lg = logo(900, 420)
    im.alpha_composite(lg, ((w - 900) // 2, (h - 420) // 2 - 20))
    d = ImageDraw.Draw(im)
    f = ImageFont.truetype(FONT_SERIF, 22)
    t = "IT 12  •  University of Perpetual Help System Laguna"
    d.text(((w - d.textlength(t, font=f)) / 2, h - 70), t, font=f, fill=(200, 214, 196))
    return im


def main():
    for name, (c, cd, s, shape) in SEEDS.items():
        save(seed_pouch(c, cd, s, shape), "seeds/seed_%s.png" % name)
    save(seed_pouch(*SEEDS["narra"]), "seed.png")                       # HUD/default seed icon
    save(bamboo_guard(20, 22, 4), "guard.png")
    save(bamboo_guard(40, 26, 6), "guard_fence.png")
    save(strip([beetle(0), beetle(1)]), "beetle.png")
    save(strip([caterpillar(0), caterpillar(1)]), "caterpillar.png")
    save(strip([butterfly(0), butterfly(1)]), "butterfly.png")
    save(strip([bird(0), bird(1)]), "bird.png")
    save(sluice(), "sluice.png")
    save(parchment(), "parchment.png")
    for k in ("pause", "journal", "trophy", "settings", "story"):
        save(icon(k), "ui_%s.png" % k)
    save(logo(), "logo.png")
    save(app_icon(512), "icon_512.png")
    save(app_icon(192), "icon_192.png")
    save(adaptive_fg(), "icon_adaptive_fg.png")
    save(adaptive_bg(), "icon_adaptive_bg.png")
    save(splash(), "splash.png")
    app_icon(256).save("icon.png")                                        # project icon
    print("production art written to", ART)


if __name__ == "__main__":
    main()
