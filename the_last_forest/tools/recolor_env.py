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
