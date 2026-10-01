"""Makes green copies of the demo's autumn environment art.
Run from the project root:  python the_last_forest/tools/recolor_env.py
Orange/brown foliage pixels are hue-shifted to leaf green; purple rock,
trunks, sky and clouds are untouched. Originals in level/ are not modified.
Output: the_last_forest/art/env/*.png
"""
import colorsys, os
from PIL import Image

SRC = {
    "tiles.png": "level/tiles.webp",
    "tree_1.png": "level/props/tree_1.webp",
    "tree_2.png": "level/props/tree_2.webp",
    "bush_1.png": "level/props/bush_1.webp",
    "fern_1.png": "level/props/fern_1.webp",
    "grass_1.png": "level/props/grass_1.webp",
    "grass_2.png": "level/props/grass_2.webp",
    "grass_3.png": "level/props/grass_3.webp",
    "vine_1.png": "level/props/vine_1.webp",
    "vine_2.png": "level/props/vine_2.webp",
    "rock_1.png": "level/props/rock_1.webp",
    "flower_1.png": "level/props/flower_1.webp",
    "ground_flowers_1.png": "level/props/ground_flowers_1.webp",
    "distant_platforms_1.png": "level/background/distant_platforms_1.webp",
    "distant_platforms_2.png": "level/background/distant_platforms_2.webp",
    "sky.png": "level/background/sky.webp",
    "cloud_1.png": "level/background/cloud_1.webp",
    "cloud_2.png": "level/background/cloud_2.webp",
    "cloud_3.png": "level/background/cloud_3.webp",
}
OUT = "the_last_forest/art/env"
# Foliage hues (magenta-red-orange-yellow, -38..62 deg) are remapped into a natural
# leaf-green band (78..128 deg), keeping light/dark shading.
HUE_LO, HUE_HI = -38.0, 62.0
GREEN_LO, GREEN_HI = 78.0, 128.0
NO_RED_REMAP = {"flower_1.png", "ground_flowers_1.png"}  # keep pink petals
MIN_SAT = {"distant_platforms_1.png": 0.08}


def green(c, name):
    r, g, b, a = c
    if a == 0:
        return c
    h, s, v = colorsys.rgb_to_hsv(r / 255, g / 255, b / 255)
    deg = h * 360.0
    if deg > 300.0:
        deg -= 360.0
    lo = 8.0 if name in NO_RED_REMAP else HUE_LO
    if lo <= deg <= HUE_HI and s > MIN_SAT.get(name, 0.22):
        t = (deg - HUE_LO) / (HUE_HI - HUE_LO)
        # orange highlights -> yellow-green, deep red shadows -> blue-green
        nh = GREEN_HI - t * (GREEN_HI - GREEN_LO)
        h = nh / 360.0
        s = min(1.0, s * 0.80)
        v = v * (0.80 + 0.12 * (1.0 - v))
        r, g, b = (int(round(x * 255)) for x in colorsys.hsv_to_rgb(h, s, v))
    return (r, g, b, a)


def main():
    os.makedirs(OUT, exist_ok=True)
    for name, src in SRC.items():
        im = Image.open(src).convert("RGBA")
        px = im.load()
        for y in range(im.height):
            for x in range(im.width):
                px[x, y] = green(px[x, y], name)
        im.save(os.path.join(OUT, name))
        print("wrote", name, im.size)


if __name__ == "__main__":
    main()


# ---------------------------------------------------------------- derived props
# Smart reuse: the same demo pictures, recoloured for new jobs.
#   clouds  -> smoke (burnt areas), pit fog, rain cloud (Stage 3 water source)
#   tileset tree -> leafless burnt snag;  tree trunk -> burnt stump
#   bush    -> dry straw bush (Stage 3 before the water arrives)
#   sparkle -> glowing ember
def _is_foliage(p):
    r, g, b, a = p
    if a == 0:
        return False
    h, s, v = colorsys.rgb_to_hsv(r / 255, g / 255, b / 255)
    deg = h * 360.0
    return (deg <= 62.0 or deg >= 322.0) and s > 0.25


def _char(p, dark=0.42):
    r, g, b, a = p
    gray = 0.299 * r + 0.587 * g + 0.114 * b
    return (int(gray * dark + 18), int(gray * dark + 12), int(gray * dark + 10), a)


def _recolor(img, fn):
    img = img.convert("RGBA")
    px = img.load()
    for y in range(img.height):
        for x in range(img.width):
            px[x, y] = fn(px[x, y])
    return img


def _cloud_tint(rgb, alpha_scale, value_scale):
    def fn(p):
        r, g, b, a = p
        if a == 0:
            return p
        lum = (0.299 * r + 0.587 * g + 0.114 * b) / 255.0 * value_scale
        return (int(rgb[0] * lum), int(rgb[1] * lum), int(rgb[2] * lum), int(a * alpha_scale))
    return fn


def derived():
    jobs = {
        "smoke.png": _recolor(Image.open("level/background/cloud_3.webp"), _cloud_tint((150, 146, 142), 0.85, 0.95)),
        "fog.png": _recolor(Image.open("level/background/cloud_2.webp"), _cloud_tint((226, 228, 240), 0.62, 1.0)),
        "rain_cloud.png": _recolor(Image.open("level/background/cloud_3.webp"), _cloud_tint((104, 118, 142), 1.0, 1.0)),
    }
    # leafless burnt snag from the tall tileset tree (atlas column 4, above the ground strip)
    tall = Image.open("level/tiles.webp").convert("RGBA").crop((256, 0, 320, 190))
    jobs["snag.png"] = _recolor(tall, lambda p: (0, 0, 0, 0) if _is_foliage(p) else _char(p, 0.5))
    # burnt stump: trunk of tree_2 with the leaves removed
    trunk = Image.open("level/props/tree_2.webp").convert("RGBA")
    trunk = _recolor(trunk, lambda p: (0, 0, 0, 0) if _is_foliage(p) else _char(p, 0.55))
    jobs["stump.png"] = trunk.crop(trunk.getbbox())
    # dry straw-coloured bush (same shape as the green one)
    def straw(p):
        r, g, b, a = p
        if a == 0:
            return p
        h, s, v = colorsys.rgb_to_hsv(r / 255, g / 255, b / 255)
        r2, g2, b2 = colorsys.hsv_to_rgb(38 / 360.0, min(s, 0.45) * 0.8, v * 0.85)
        return (int(r2 * 255), int(g2 * 255), int(b2 * 255), a)
    jobs["dry_bush.png"] = _recolor(Image.open("level/props/bush_1.webp"), straw)
    # ember: the generated sparkle, made orange
    spark = Image.open("the_last_forest/art/sparkle.png").convert("RGBA")
    jobs["ember.png"] = _recolor(spark, lambda p: (255, int(110 + p[1] * 0.3), 30, p[3]) if p[3] else p)
    for name, img in jobs.items():
        img.save(os.path.join(OUT, name))
        print("wrote", name, img.size)


if __name__ == "__main__":
    derived()
