"""Eco-Ranger "Lunti" sprite sheet (8 x 8 grid of 64 px frames, same layout
the player AnimationPlayer already uses):
    0-9  run      30-33 idle      42 crouch/plant      45 jump      48 fall
Drawn on a 32 x 32 pixel grid, outlined, then scaled 2x (nearest).
Run from the project root:  python the_last_forest/tools/generate_ranger.py
"""
import math, os
from PIL import Image, ImageDraw

OUT = "the_last_forest/art/ranger.png"
S = 32
SKIN, SKIN_D = (176, 112, 74), (140, 84, 54)
HAIR = (34, 26, 22)
HAT, HAT_D, BAND = (190, 160, 96), (150, 122, 70), (64, 132, 58)
SHIRT, SHIRT_D = (74, 142, 72), (52, 108, 54)
BADGE = (246, 201, 69)
SHORTS, SHORTS_D = (150, 120, 80), (118, 92, 60)
BOOT = (92, 58, 36)
STRAP, BAG, BAG_D = (120, 76, 40), (150, 98, 52), (112, 70, 36)
OUTLINE = (30, 24, 20)


def limb(d, x, y, ang, length, col, w=2):
    """ang in degrees, 0 = straight down, positive = forward (right)."""
    ex = x + math.sin(math.radians(ang)) * length
    ey = y + math.cos(math.radians(ang)) * length
    d.line([(x, y), (ex, ey)], fill=col, width=w)
    return ex, ey


def leg(d, hx, hy, thigh, shin, length=3.6, back=False):
    kx, ky = limb(d, hx, hy, thigh, length, SHORTS_D if back else SHORTS, 3)
    fx, fy = limb(d, kx, ky, shin, length, SKIN_D if back else SKIN, 3)
    d.rectangle([round(fx) - 1, round(fy) - 1, round(fx) + 2, round(fy) + 1], fill=BOOT)


def arm(d, sx, sy, upper, fore, back=False):
    ex, ey = limb(d, sx, sy, upper, 3.4, SHIRT_D if back else SHIRT, 2)
    hx, hy = limb(d, ex, ey, fore, 3.0, SKIN_D if back else SKIN, 2)
    return hx, hy


def frame(pose, t=0.0):
    im = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    bob = 0
    hip_y = 22
    if pose == "run":
        s = math.sin(t * 2 * math.pi)
        c = math.cos(t * 2 * math.pi)
        bob = -1 if abs(s) > 0.7 else 0
        lt, rt = 38 * s, -38 * s
        ls, rs = lt - 30 - 20 * max(0, -c), rt - 30 - 20 * max(0, c)
        al, ar = -40 * s, 40 * s
    elif pose == "idle":
        bob = 1 if t >= 0.5 else 0
        lt, rt, ls, rs = 6, -6, 6, -6
        al, ar = 10, -8
    elif pose == "jump":
        lt, ls, rt, rs = 55, -20, -15, -10
        al, ar = 150, -150
        bob = -1
    elif pose == "fall":
        lt, ls, rt, rs = 25, 10, -30, -15
        al, ar = 115, -120
    elif pose == "crouch":
        hip_y = 25
        lt, ls, rt, rs = 80, -10, -40, -120
        al, ar = 70, 20
    hy = hip_y + bob
    ty = hy - 8  # torso top
    # back limbs first (darker)
    leg(d, 14, hy, rt, rs, back=True)
    arm(d, 13, ty + 1, ar, ar + 25, back=True)
    # satchel strap + bag (behind torso on the left hip)
    d.rectangle([10, hy - 4, 12, hy - 1], fill=BAG)
    d.point((10, hy - 4), fill=BAG_D)
    # torso
    d.rectangle([12, ty, 18, hy - 2], fill=SHIRT)
    d.line([(12, ty), (12, hy - 2)], fill=SHIRT_D)
    d.rectangle([12, hy - 2, 18, hy], fill=SHORTS)
    d.line([(13, ty), (18, hy - 3)], fill=STRAP)
    d.point((17, ty + 2), fill=BADGE)
    # front leg + arm
    leg(d, 17, hy, lt, ls)
    # head
    hx0, hy0 = 12, ty - 8
    d.rectangle([hx0 + 1, hy0 + 1, hx0 + 7, hy0 + 7], fill=SKIN)
    d.rectangle([hx0 + 1, hy0 + 1, hx0 + 3, hy0 + 4], fill=HAIR)   # hair at back
    d.rectangle([hx0 + 5, hy0 + 3, hx0 + 5, hy0 + 4], fill=OUTLINE)  # eye
    d.point((hx0 + 7, hy0 + 6), fill=SKIN_D)                       # mouth
    d.point((hx0 + 3, hy0 + 5), fill=SKIN_D)                       # ear
    # ranger hat: crown + wide brim + green band
    d.rectangle([hx0 + 2, hy0 - 2, hx0 + 7, hy0 + 1], fill=HAT)
    d.line([(hx0 + 2, hy0 + 0), (hx0 + 7, hy0 + 0)], fill=BAND)
    d.line([(hx0 - 1, hy0 + 1), (hx0 + 10, hy0 + 1)], fill=HAT_D)
    d.point((hx0 + 3, hy0 - 2), fill=HAT_D)
    arm(d, 17, ty + 1, al, al + (-30 if pose != "crouch" else -60))
    d.point((17, ty + 2), fill=BADGE)
    # outline pass
    px = im.load()
    out = im.copy()
    op = out.load()
    for y in range(S):
        for x in range(S):
            if px[x, y][3] == 0:
                for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                    nx, ny = x + dx, y + dy
                    if 0 <= nx < S and 0 <= ny < S and px[nx, ny][3] > 0:
                        op[x, y] = OUTLINE + (255,)
                        break
    return out.resize((64, 64), Image.NEAREST)


def main():
    sheet = Image.new("RGBA", (512, 512), (0, 0, 0, 0))
    def put(i, img):
        sheet.alpha_composite(img, ((i % 8) * 64, (i // 8) * 64))
    for i in range(10):
        put(i, frame("run", i / 10))
    for k, i in enumerate(range(30, 34)):
        put(i, frame("idle", k / 4))
    put(42, frame("crouch"))
    put(45, frame("jump"))
    put(48, frame("fall"))
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    sheet.save(OUT)
    print("wrote", OUT)


if __name__ == "__main__":
    main()
