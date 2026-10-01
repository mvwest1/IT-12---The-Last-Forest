"""Generate only the four 16x16 gameplay icons used when no production sprite exists."""

from pathlib import Path
from PIL import Image, ImageDraw

OUT = Path(__file__).resolve().parents[1] / "assets" / "placeholders"
OUT.mkdir(parents=True, exist_ok=True)

def make(name: str, draw_fn) -> None:
    image = Image.new("RGBA", (16, 16), (0, 0, 0, 0))
    draw_fn(ImageDraw.Draw(image))
    image.save(OUT / name)

def seed(d):
    d.polygon([(7,2),(9,2),(12,5),(13,9),(11,13),(8,15),(5,13),(3,10),(4,6)], fill="#d6a13a", outline="#573d25")
    d.polygon([(4,6),(6,3),(10,3),(12,6),(11,8),(5,8)], fill="#79502b")
    d.line([(6,9),(7,12),(9,13)], fill="#f3d27a")
    d.point((9,1), fill="#72502c")

def water(d):
    d.polygon([(8,1),(12,6),(14,10),(13,13),(10,15),(6,15),(3,13),(2,10),(4,6)], fill="#26b9d2", outline="#145d84")
    d.line([(5,8),(7,5),(8,4)], fill="#c0f5f2")
    d.point((4,10), fill="#76e5e6")

def pest(d):
    d.line([(5,5),(3,2)], fill="#4c294e"); d.line([(10,5),(13,2)], fill="#4c294e")
    d.line([(4,10),(1,12)], fill="#4c294e"); d.line([(5,12),(3,15)], fill="#4c294e")
    d.line([(11,10),(14,12)], fill="#4c294e"); d.line([(10,12),(12,15)], fill="#4c294e")
    d.ellipse((3,4,13,13), fill="#9d3e78", outline="#412546")
    d.ellipse((1,6,6,11), fill="#614078", outline="#412546")
    d.line([(8,5),(8,12)], fill="#592c59"); d.point((5,6), fill="#f1a4b3")

def sprout(d):
    d.line([(8,15),(8,8)], fill="#496d32", width=2)
    d.ellipse((1,4,8,10), fill="#65a747", outline="#345d31")
    d.ellipse((8,2,15,8), fill="#8acb55", outline="#345d31")
    d.line([(4,6),(6,7)], fill="#c5e67c"); d.line([(11,4),(13,4)], fill="#d6ee8e")
    d.line([(6,15),(10,15)], fill="#65472d")

make("seed.png", seed)
make("water_drop.png", water)
make("pest.png", pest)
make("sapling_sprout.png", sprout)
