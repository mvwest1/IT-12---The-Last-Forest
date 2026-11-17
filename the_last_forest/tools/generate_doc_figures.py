"""Asset boards for the manuscript (Chapter III, 3.2 Game Assets).
Every picture is cut from the REAL game files or real in-game screenshots,
so the panel sees exactly what is in the build.
Usage (project root):
  python the_last_forest/tools/generate_doc_figures.py <screenshot_dir>
Screenshots come from tests/production_shots.gd. Output: docs/figures/
"""
import os, sys
from PIL import Image, ImageDraw, ImageFont

ART = "the_last_forest/art"
OUT = "docs/figures"
SHOTS = sys.argv[1] if len(sys.argv) > 1 else "shots"
W, H = 1560, 470
GREEN, CREAM, INK, GOLD = (28, 70, 42), (244, 236, 214), (52, 40, 26), (232, 186, 64)


def font(size, bold=False):
    for f in (["DejaVuSans-Bold.ttf"] if bold else []) + ["DejaVuSans.ttf"]:
        for d in ("/usr/share/fonts/truetype/dejavu/", ""):
            try:
                return ImageFont.truetype(d + f, size)
            except OSError:
                pass
    return ImageFont.load_default()


def frame(sheet, idx, n=8, cell=64):
    im = Image.open(os.path.join(ART, sheet)).convert("RGBA")
    return im.crop(((idx % n) * cell, (idx // n) * cell, (idx % n + 1) * cell, (idx // n + 1) * cell))


def strip(name, frames, i):
    im = Image.open(os.path.join(ART, name)).convert("RGBA")
    w = im.width // frames
    return im.crop((i * w, 0, (i + 1) * w, im.height))


def art(name):
    return Image.open(os.path.join(ART, name)).convert("RGBA")


def shot(name, box=None):
    im = Image.open(os.path.join(SHOTS, name)).convert("RGBA")
    return im.crop(box) if box else im


def board(fname, title, subtitle, tiles):
    """tiles: list of (image, caption, file_label, pixel_art?)"""
    img = Image.new("RGB", (W, H), GREEN)
    d = ImageDraw.Draw(img)
    d.text((22, 14), title, fill=(255, 255, 255), font=font(26, True))
    d.text((22, 50), subtitle, fill=(200, 222, 200), font=font(17))
    n = len(tiles)
    gap = 16
    tw = (W - 2 * 22 - gap * (n - 1)) // n
    th = H - 100 - 22
    for k, (im, cap, lab, pixel) in enumerate(tiles):
        x0 = 22 + k * (tw + gap)
        y0 = 90
        d.rounded_rectangle([x0, y0, x0 + tw, y0 + th], radius=10, fill=CREAM, outline=GOLD, width=3)
        area = (tw - 24, th - 86)
        scale = min(area[0] / im.width, area[1] / im.height)
        if pixel and scale >= 1:
            scale = max(1, int(scale))
        new = (max(1, int(im.width * scale)), max(1, int(im.height * scale)))
        pic = im.resize(new, Image.NEAREST if pixel else Image.LANCZOS)
        bg = Image.new("RGBA", (area[0], area[1]), (36, 84, 52, 255))
        bg.alpha_composite(pic, ((area[0] - new[0]) // 2, (area[1] - new[1]) // 2))
        img.paste(bg.convert("RGB"), (x0 + 12, y0 + 12))
        f1, f2 = font(18, True), font(14)
        cw = d.textlength(cap, font=f1)
        d.text((x0 + (tw - cw) / 2, y0 + th - 66), cap, fill=INK, font=f1)
        lw = d.textlength(lab, font=f2)
        d.text((x0 + (tw - lw) / 2, y0 + th - 38), lab, fill=(110, 90, 60), font=f2)
    os.makedirs(OUT, exist_ok=True)
    img.save(os.path.join(OUT, fname))
    print("wrote", fname)


def main():
    board("asset_a_ranger.png", "a. Main Character - Eco-Ranger Lunti",
          "res://the_last_forest/art/ranger.png  (8 x 8 sheet of 64 px frames, ranger hat + seed satchel)", [
              (frame("ranger.png", 30), "Idle", "frames 30-33", True),
              (frame("ranger.png", 3), "Run", "frames 0-9", True),
              (frame("ranger.png", 45), "Jump", "frame 45", True),
              (frame("ranger.png", 48), "Fall", "frame 48", True),
              (frame("ranger.png", 42), "Kneel / plant / lever", "frame 42", True),
              (art("ranger_portrait.png"), "Story: Elder Narra", "ranger_portrait.png", True),
          ])
    board("asset_b_seeds.png", "b. Native Seeds and Saplings (Stage 1)",
          "res://the_last_forest/art/seeds/ and sapling_0..3.png  (growth: seedling > sprout > young tree > mature)", [
              (art("seeds/seed_narra.png"), "Narra seed", "seed_narra.png", True),
              (art("seeds/seed_lauan.png"), "Lauan seed", "seed_lauan.png", True),
              (art("seeds/seed_dao.png"), "Dao seed", "seed_dao.png", True),
              (art("soil_mound.png"), "Burnt soil", "soil_mound.png", True),
              (art("sapling_0.png"), "1 Seedling", "sapling_0.png", True),
              (art("sapling_1.png"), "2 Sprout", "sapling_1.png", True),
              (art("sapling_2.png"), "3 Young tree", "sapling_2.png", True),
              (art("sapling_3.png"), "4 Mature tree", "sapling_3.png", True),
          ])
    board("asset_c_guards_pests.png", "c. Bamboo Tree Guards and Non-violent Forest Pests (Stage 2)",
          "Pests are shooed away by bumping into them - they are never hurt and never hurt the player", [
              (art("guard.png"), "Tree guard pickup", "guard.png", True),
              (art("guard_fence.png"), "Guard around sapling", "guard_fence.png", True),
              (strip("beetle.png", 2, 0), "Leaf beetle (flies)", "beetle.png (2 frames)", True),
              (strip("caterpillar.png", 2, 0), "Caterpillar (crawls)", "caterpillar.png (2 frames)", True),
              (shot("v1_13_stage2_beetle_caterpillar.png", (300, 120, 900, 400)), "In game: Stage 2", "stage_2.tscn", False),
          ])
    board("asset_d_water.png", "d. Water Lever and Wooden Sluice Channel (Stage 3)",
          "Turning the lever tilts the sluice so rainwater reaches the dry gully; the gully turns green when watered", [
              (art("lever.png"), "Water lever", "lever.png", True),
              (art("sluice.png"), "Wooden sluice", "sluice.png", True),
              (art("water_drop.png"), "Rain drop", "water_drop.png", True),
              (art("spout.png"), "Bamboo spout", "spout.png", True),
              (shot("v1_14_stage3_sluice.png", (230, 120, 830, 380)), "In game: Stage 3", "stage_3.tscn", False),
          ])
    board("asset_e_cards_journal.png", "e. Bilingual Fact Cards and Leaf Journal",
          "Parchment cards show English and Filipino together; the Leaf Journal is saved per learner in the database", [
              (shot("v1_10_fact_card_bilingual.png", (230, 0, 836, 480)), "Fact card (EN + FIL)", "fact_card_popup.tscn", False),
              (shot("v1_06_journal.png"), "Leaf Journal", "leaf_journal.tscn", False),
              (shot("v1_07_journal_page_bilingual.png", (180, 0, 886, 480)), "Journal page", "parchment.png", False),
          ])
    board("asset_f_restoration.png", "f. Environment Tilemaps, Restoration Shader and Returning Wildlife",
          "restoration.gdshader fades burnt to green; butterflies return at 50 %, birds at 100 % (wildlife.gd)", [
              (shot("v1_11_stage1_touch_controls.png", (0, 40, 1066, 400)), "Burnt (0 %)", "stage start", False),
              (shot("v1_12_stage1_restored_wildlife.png", (0, 40, 1066, 400)), "Restored (100 %)", "after 3 trees", False),
              (strip("butterfly.png", 2, 0), "Butterfly", "butterfly.png", True),
              (strip("bird.png", 2, 0), "Bird", "bird.png", True),
          ])
    # Branding
    board("asset_g_branding.png", "Branding - logo, app icon and splash",
          "Original artwork made for the project (the_last_forest/tools/generate_production_art.py)", [
              (art("logo.png"), "Game logo", "logo.png", False),
              (art("icon_512.png"), "App icon", "icon_512.png", False),
              (art("splash.png"), "Boot splash", "splash.png", False),
          ])


if __name__ == "__main__":
    main()
