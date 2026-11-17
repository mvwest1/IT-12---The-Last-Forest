"""Copies the tiles we use from Kenney's "UI Pack - Pixel Adventure" (CC0)
into the_last_forest/art/ui_kenney/ with readable names, plus a few
derived states (hover = brighter, focus = gold frame, translucent HUD,
3-piece ribbon joined into one strip).
The full pack stays in kenney_ui-pack-pixel-adventure/ (ignored by Godot
through its .gdignore file).  Run from the project root:
    python the_last_forest/tools/import_kenney_ui.py
Then:  godot --headless --path . -s res://the_last_forest/tools/make_theme.gd
"""
import os
from PIL import Image, ImageEnhance

PACK = "kenney_ui-pack-pixel-adventure/Tiles"
OUT = "the_last_forest/art/ui_kenney"
GOLD = (246, 201, 69, 255)


def tile(size, idx):
    folder = "Small tiles" if size == "S" else "Large tiles"
    return Image.open(os.path.join(PACK, folder, "Thick outline", "tile_%04d.png" % idx)).convert("RGBA")


def save(im, name):
    os.makedirs(OUT, exist_ok=True)
    im.save(os.path.join(OUT, name + ".png"))
    print("wrote", name)


def recolor(im, rgba):
    px = im.load()
    out = im.copy(); po = out.load()
    for y in range(im.height):
        for x in range(im.width):
            if px[x, y][3] > 0:
                po[x, y] = rgba
    return out


def main():
    btn = tile("S", 34)
    save(btn, "button_normal")
    save(ImageEnhance.Brightness(btn).enhance(1.18), "button_hover")
    # pressed / toggled-on: same button, darker, so it reads as "pushed in"
    save(ImageEnhance.Brightness(btn).enhance(0.72), "button_pressed")
    save(tile("S", 36), "button_disabled")
    save(recolor(tile("S", 69), GOLD), "focus_frame")
    # darker wood so the (lighter) buttons and white text stand out on it
    save(ImageEnhance.Brightness(tile("L", 17)).enhance(0.68), "panel_wood")
    save(tile("L", 18), "panel_parchment")
    hud = tile("S", 13)
    px = hud.load()
    for y in range(hud.height):
        for x in range(hud.width):
            r, g, b, a = px[x, y]
            if a:
                px[x, y] = (r, g, b, 215)
    save(hud, "panel_hud")
    save(tile("S", 33), "field")
    save(tile("S", 18), "bar_back")
    save(tile("S", 98), "bar_fill")
    save(tile("S", 24), "slider_grabber")
    ribbon = Image.new("RGBA", (48, 16))
    for k, idx in enumerate((106, 107, 108)):
        ribbon.alpha_composite(tile("S", idx), (k * 16, 0))
    save(ribbon, "ribbon")


if __name__ == "__main__":
    main()
