"""Story illustration: Elder Narra hands Eco-Ranger Lunti the seed satchel.
Writes the_last_forest/art/ranger_portrait.png (480 x 270, pixel art x6).
Run from the project root:  python the_last_forest/tools/generate_story_art.py
"""
import sys, os
from PIL import Image, ImageDraw
sys.path.insert(0, os.path.dirname(__file__))
import generate_ranger as gr

W, H = 80, 45  # drawn small, scaled x6
OUTLINE = (30, 24, 20)


def elder():
    S = 32
    im = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    skin, skin_d = (160, 104, 70), (128, 80, 52)
    hair = (214, 214, 206)
    shawl, shawl_d = (52, 120, 70), (36, 92, 52)
    skirt = (120, 70, 40)
    stick = (110, 74, 40)
    # stick
    d.line([(8, 12), (6, 30)], fill=stick, width=1)
    d.point((8, 11), fill=(70, 140, 60))
    # skirt / body
    d.polygon([(12, 18), (19, 18), (21, 29), (10, 29)], fill=skirt)
    d.rectangle([12, 12, 19, 19], fill=shawl)
    d.line([(12, 12), (12, 19)], fill=shawl_d)
    d.rectangle([11, 29, 13, 30], fill=(70, 46, 30))
    d.rectangle([18, 29, 20, 30], fill=(70, 46, 30))
    # arm to stick
    d.line([(13, 14), (9, 17)], fill=shawl_d, width=2)
    d.point((8, 17), fill=skin)
    # head
    d.rectangle([12, 4, 18, 11], fill=skin)
    d.rectangle([12, 3, 18, 6], fill=hair)
    d.rectangle([11, 4, 12, 9], fill=hair)
    d.rectangle([17, 2, 19, 4], fill=hair)  # bun
    d.point((13, 7), fill=OUTLINE)
    d.point((12, 9), fill=skin_d)
    px = im.load(); out = im.copy(); op = out.load()
    for y in range(S):
        for x in range(S):
            if px[x, y][3] == 0:
                for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                    nx, ny = x + dx, y + dy
                    if 0 <= nx < S and 0 <= ny < S and px[nx, ny][3] > 0:
                        op[x, y] = OUTLINE + (255,)
                        break
    return out.transpose(Image.FLIP_LEFT_RIGHT)  # faces left, toward Lunti


def scene():
    im = Image.new("RGBA", (W, H))
    d = ImageDraw.Draw(im)
    for y in range(H):
        t = y / H
        d.line([(0, y), (W, y)], fill=(int(250 - 70 * t), int(196 - 40 * t), int(140 + 20 * t)))
    d.ellipse([56, 4, 66, 14], fill=(255, 236, 170))
    # far burnt hills (left) turning green (right)
    for x in range(W):
        h = 30 + int(4 * __import__("math").sin(x / 7.0))
        g = x / W
        col = (int(110 - 50 * g), int(100 + 40 * g), int(90 - 30 * g))
        d.line([(x, h), (x, H)], fill=col)
    # ground
    d.rectangle([0, 38, W, H], fill=(96, 74, 50))
    d.rectangle([0, 37, W, 38], fill=(84, 140, 62))
    # charred snag on the left, young tree on the right
    d.line([(8, 37), (8, 22)], fill=(50, 40, 36), width=2)
    d.line([(8, 27), (4, 23)], fill=(50, 40, 36))
    d.line([(70, 37), (70, 29)], fill=(110, 76, 44), width=1)
    d.ellipse([66, 23, 75, 31], fill=(70, 150, 60))
    d.ellipse([68, 21, 73, 26], fill=(96, 176, 80))
    return im


def main():
    bg = scene()
    lunti = gr.frame("idle", 0.0)          # 64 x 64 (already x2)
    lunti = lunti.resize((32, 32), Image.NEAREST)
    el = elder()
    bg.alpha_composite(lunti, (22, 8))
    bg.alpha_composite(el, (40, 8))
    # seed satchel being handed over
    d = ImageDraw.Draw(bg)
    d.rectangle([37, 24, 40, 27], fill=(150, 98, 52))
    d.point((38, 23), fill=(120, 76, 40))
    d.point((39, 25), fill=(246, 201, 69))
    out = bg.resize((W * 6, H * 6), Image.NEAREST)
    path = "the_last_forest/art/ranger_portrait.png"
    out.save(path)
    print("wrote", path)


if __name__ == "__main__":
    main()
