"""Shared pixel-art helpers for tools/art (GDD §13): the palette, a small RGBA canvas with
drawing primitives and outlines, and where the PNGs go."""

from pathlib import Path
import random

from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
ASSETS = ROOT / "assets"
UI_SCALE = 2


def hex_color(value: str, alpha: int = 255) -> tuple:
    value = value.lstrip("#")
    return (int(value[0:2], 16), int(value[2:4], 16), int(value[4:6], 16), alpha)


# --- Palette (bright, Kairosoft-like, East Asian setting) ---------------------------------------
P = {
    "outline": hex_color("2b1d14"),
    "grass": hex_color("78c159"), "grass_dark": hex_color("5aa443"), "grass_light": hex_color("9bd66f"),
    "paddy": hex_color("a9c94c"), "paddy_dark": hex_color("7f9f34"), "paddy_water": hex_color("86b7c9"),
    "bund": hex_color("c9ad72"), "bund_dark": hex_color("a68a55"),
    "leaf": hex_color("2f7d3e"), "leaf_dark": hex_color("1e5a2c"), "leaf_light": hex_color("53a454"),
    "trunk": hex_color("6b4423"),
    "rock": hex_color("a8a092"), "rock_dark": hex_color("7a7266"), "rock_light": hex_color("d1c9b8"),
    "wild": hex_color("5d5b45"), "wild_dot": hex_color("6c6a51"), "wild_dark": hex_color("4e4c3a"),
    "gold": hex_color("f2c23c"), "gold_dark": hex_color("b9862a"), "gold_light": hex_color("fff0a0"),
    "wall": hex_color("f1ead8"), "wall_shade": hex_color("cfc4aa"),
    "stone": hex_color("b3a78f"), "stone_dark": hex_color("857a66"), "stone_light": hex_color("d6ccb4"),
    "courtyard": hex_color("cdb98c"), "courtyard_dark": hex_color("b8a274"),
    "roof": hex_color("3e5c8a"), "roof_dark": hex_color("2a4166"), "roof_light": hex_color("5d7fb0"),
    "red": hex_color("c8412e"), "red_dark": hex_color("8e2a1e"), "red_light": hex_color("e8664c"),
    "thatch": hex_color("d9b45a"), "thatch_dark": hex_color("a98636"),
    "wood": hex_color("9a6638"), "wood_dark": hex_color("6b4423"), "wood_light": hex_color("c08a52"),
    "wood_deep": hex_color("4e3019"),
    "paper": hex_color("f0e2bf"), "paper_shade": hex_color("e2cf9f"), "paper_fiber": hex_color("e8d7ac"),
    "door": hex_color("3b2617"),
    "rice": hex_color("fbf8ef"), "bowl": hex_color("b0452f"), "bowl_dark": hex_color("7d2c1f"),
    "ore": hex_color("6c7fd1"), "ore_dark": hex_color("3f4c94"), "ore_light": hex_color("b4c2ff"),
    "hardwood": hex_color("7a3a2a"), "hardwood_light": hex_color("a8604a"), "hardwood_ring": hex_color("d0a07a"),
    "horse": hex_color("8a5a34"), "horse_dark": hex_color("5a3820"), "mane": hex_color("2e1e14"),
    "white": hex_color("ffffff"), "black": hex_color("000000"),
}
CLEAR = (0, 0, 0, 0)


class Canvas:
    def __init__(self, width: int, height: int, fill=CLEAR):
        self.image = Image.new("RGBA", (width, height), fill)
        self.width = width
        self.height = height

    def px(self, x: int, y: int, color) -> None:
        if 0 <= x < self.width and 0 <= y < self.height:
            self.image.putpixel((x, y), color)

    def get(self, x: int, y: int):
        return self.image.getpixel((x, y))

    def rect(self, x: int, y: int, w: int, h: int, color) -> None:
        for yy in range(y, y + h):
            for xx in range(x, x + w):
                self.px(xx, yy, color)

    def hline(self, x0: int, x1: int, y: int, color) -> None:
        for x in range(x0, x1 + 1):
            self.px(x, y, color)

    def vline(self, x: int, y0: int, y1: int, color) -> None:
        for y in range(y0, y1 + 1):
            self.px(x, y, color)

    def ellipse(self, cx: float, cy: float, rx: float, ry: float, color) -> None:
        for y in range(self.height):
            for x in range(self.width):
                if ((x + 0.5 - cx) / rx) ** 2 + ((y + 0.5 - cy) / ry) ** 2 <= 1.0:
                    self.px(x, y, color)

    def outline(self, color=None) -> None:
        """Draws a 1px outline around every opaque area (outside it, on transparent pixels)."""
        color = color or P["outline"]
        solid = [[self.get(x, y)[3] > 0 for x in range(self.width)] for y in range(self.height)]
        for y in range(self.height):
            for x in range(self.width):
                if solid[y][x]:
                    continue
                for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                    nx, ny = x + dx, y + dy
                    if 0 <= nx < self.width and 0 <= ny < self.height and solid[ny][nx]:
                        self.px(x, y, color)
                        break

    def paste(self, other: "Canvas", x: int, y: int) -> None:
        self.image.alpha_composite(other.image, (x, y))

    def save(self, relative: str, scale: int = 1) -> None:
        path = ASSETS / relative
        path.parent.mkdir(parents=True, exist_ok=True)
        image = self.image
        if scale != 1:
            image = image.resize((self.width * scale, self.height * scale), Image.NEAREST)
        image.save(path)


def speckle(canvas: Canvas, rng: random.Random, colors: list, count: int) -> None:
    for _ in range(count):
        canvas.px(rng.randrange(canvas.width), rng.randrange(canvas.height), rng.choice(colors))


def speckle_area(c: Canvas, rng: random.Random, x0: int, y0: int, x1: int, y1: int, color, count: int) -> None:
    for _ in range(count):
        c.px(rng.randint(x0, x1), rng.randint(y0, y1), color)
