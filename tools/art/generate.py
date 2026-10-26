"""Pixel art for Kingdom Tiles (GDD §13): tiles, buildings, level badges, resource icons and the
wood + paper UI frames. Everything is drawn here from code, so running the script again redraws
the whole set with the same palette. Hand-drawn PNGs can replace any output file (same name).

Run from the project folder:  python tools/art/generate.py
Needs Pillow. Writes into assets/. Board art is drawn at its pixel size (16×16 tiles) and the game
scales it ×2 with nearest filtering; icons and UI frames are written already scaled ×2.
"""

import random

from pixel import ASSETS, CLEAR, P, UI_SCALE, Canvas, speckle, speckle_area
import battle_art
import portrait_art
import world_art


# --- Tiles (16×16, seamless, no outline) -------------------------------------------------------

def tile_grass(seed: int = 1) -> Canvas:
    rng = random.Random(seed)
    c = Canvas(16, 16, P["grass"])
    speckle(c, rng, [P["grass_dark"], P["grass_light"]], 22)
    for _ in range(3):  # small tufts
        x, y = rng.randrange(1, 14), rng.randrange(2, 15)
        c.px(x, y, P["grass_dark"])
        c.px(x + 1, y - 1, P["grass_dark"])
        c.px(x + 2, y, P["grass_dark"])
    return c


def tile_farmland() -> Canvas:
    """A rice paddy: raised earth bund around water with rows of rice."""
    c = Canvas(16, 16, P["paddy_water"])
    c.rect(1, 1, 14, 14, P["paddy"])
    for y in range(2, 15, 3):
        for x in range(2, 15, 2):
            c.px(x, y, P["paddy_dark"])
            c.px(x, y - 1, P["grass_light"])
    c.hline(0, 15, 0, P["bund"])
    c.vline(0, 0, 15, P["bund"])
    c.hline(0, 15, 15, P["bund_dark"])
    c.vline(15, 0, 15, P["bund_dark"])
    c.px(6, 4, P["paddy_water"])
    c.px(11, 10, P["paddy_water"])
    return c


def tree(c: Canvas, x: int, y: int) -> None:
    """A round canopy 7px wide with its trunk; (x, y) is the canopy's top-left."""
    shape = Canvas(9, 9)
    shape.ellipse(4.5, 3.6, 3.6, 3.4, P["leaf"])
    shape.vline(4, 6, 8, P["trunk"])
    shape.px(3, 1, P["leaf_light"])
    shape.px(2, 2, P["leaf_light"])
    shape.px(3, 2, P["leaf_light"])
    shape.px(5, 5, P["leaf_dark"])
    shape.px(6, 4, P["leaf_dark"])
    shape.outline(P["leaf_dark"])
    c.paste(shape, x - 1, y - 1)


def tile_forest() -> Canvas:
    rng = random.Random(7)
    c = Canvas(16, 16, P["grass_dark"])
    speckle(c, rng, [P["leaf_dark"], P["grass"]], 16)
    for x, y in ((1, 0), (8, -1), (4, 6), (10, 7), (-2, 8)):
        tree(c, x, y)
    return c


def rock(c: Canvas, x: int, y: int, w: int, h: int) -> None:
    shape = Canvas(w + 2, h + 2)
    shape.ellipse((w + 2) / 2, (h + 2) / 2 + 0.4, w / 2, h / 2, P["rock"])
    for yy in range(shape.height):
        for xx in range(shape.width):
            if shape.get(xx, yy)[3] and yy > (h + 2) * 0.62:
                shape.px(xx, yy, P["rock_dark"])
    shape.px(2, 2, P["rock_light"])
    shape.px(3, 2, P["rock_light"])
    shape.px(2, 3, P["rock_light"])
    shape.outline()
    c.paste(shape, x - 1, y - 1)


def tile_hill() -> Canvas:
    rng = random.Random(3)
    c = Canvas(16, 16, P["grass"])
    speckle(c, rng, [P["grass_dark"], P["grass_light"]], 14)
    rock(c, 2, 3, 10, 8)
    rock(c, 9, 9, 6, 5)
    rock(c, 1, 11, 4, 3)
    return c


def tile_wild() -> Canvas:
    rng = random.Random(5)
    c = Canvas(16, 16, P["wild"])
    speckle(c, rng, [P["wild_dot"], P["wild_dark"]], 26)
    return c


def key_frame() -> Canvas:
    """Drawn over key cells, above buildings, so ×2 cells stay visible: thick gold corner brackets
    and a small diamond in the top-left corner."""
    c = Canvas(16, 16)
    for x0, y0, dx, dy in ((0, 0, 1, 1), (15, 0, -1, 1), (0, 15, 1, -1), (15, 15, -1, -1)):
        for d in range(5):
            for w in range(2):
                c.px(x0 + dx * d, y0 + dy * w, P["gold"])
                c.px(x0 + dx * w, y0 + dy * d, P["gold"])
        c.px(x0, y0, P["gold_light"])
    for dy in range(-2, 3):  # mini diamond centered at (4, 4)
        half = 2 - abs(dy)
        c.hline(4 - half, 4 + half, 4 + dy, P["gold_light"] if dy < 0 else P["gold"])
    c.outline()
    return c


def key_marker() -> Canvas:
    """Gold diamond for key cells (◆), drawn over the tile."""
    c = Canvas(16, 16)
    for dy in range(-3, 4):
        half = 3 - abs(dy)
        c.hline(8 - half - 1, 8 + half - 1, 8 + dy - 1, P["gold"])
    c.px(6, 6, P["gold_light"])
    c.px(7, 5, P["gold_light"])
    c.px(7, 6, P["gold_light"])
    c.px(8, 9, P["gold_dark"])
    c.px(7, 10, P["gold_dark"])
    c.outline()
    return c


# --- Buildings (transparent, outlined) ----------------------------------------------------------

def curved_roof(c: Canvas, x: int, y: int, w: int, h: int) -> None:
    """East Asian roof: tiled, wider at the eaves, eave tips curling up."""
    for row in range(h):
        inset = (h - 1 - row)
        color = P["roof"] if row < h - 1 else P["roof_dark"]
        c.hline(x + inset, x + w - 1 - inset, y + row, color)
    c.hline(x + h - 1, x + w - h, y, P["roof_light"])
    c.px(x - 1, y + h - 2, P["roof_dark"])
    c.px(x + w, y + h - 2, P["roof_dark"])
    for col in range(x + h, x + w - h, 2):
        c.px(col, y + 1, P["roof_dark"]) if h > 2 else None


def crenels(c: Canvas, x0: int, x1: int, y: int) -> None:
    """Battlements along the top of a wall: a merlon every other pixel pair."""
    for x in range(x0, x1 + 1):
        if (x - x0) % 3 != 2:
            c.px(x, y, P["stone_light"])


def tower(c: Canvas, x: int, y: int, level: int) -> None:
    """A 7×8 corner tower; roofed from castle level 4, gold-tipped at level 6."""
    c.rect(x, y + 2, 7, 6, P["stone_dark"])
    c.rect(x + 1, y + 2, 5, 5, P["stone"])
    c.px(x + 3, y + 4, P["door"])
    if level >= 4:
        for row in range(3):
            c.hline(x + 2 - row, x + 4 + row, y - 1 + row, P["roof"] if row < 2 else P["roof_dark"])
        c.px(x + 3, y - 2, P["gold"] if level >= 6 else P["roof_light"])
    else:
        crenels(c, x, x + 6, y + 1)


def castle(level: int) -> Canvas:
    """A walled fortress filling the 2×2 castle footprint (32×32): stone walls with battlements,
    four corner towers and a gate around a courtyard, and a keep in the middle that gains roof
    tiers, banners and gold trim with the castle level."""
    rng = random.Random(level)
    c = Canvas(32, 32)
    # Courtyard.
    c.rect(3, 8, 26, 17, P["courtyard"])
    speckle_area(c, rng, 4, 9, 27, 23, P["courtyard_dark"], 30)
    # Back and side walls (seen from above), front wall (seen from the front, taller).
    c.rect(2, 6, 28, 3, P["stone"])
    crenels(c, 2, 29, 5)
    c.rect(1, 6, 3, 19, P["stone"])
    c.rect(28, 6, 3, 19, P["stone"])
    c.vline(3, 8, 23, P["stone_dark"])
    c.vline(28, 8, 23, P["stone_dark"])
    c.rect(1, 24, 30, 7, P["stone"])
    for y in (26, 28):
        for x in range(2 + (y // 2) % 2 * 2, 30, 4):
            c.hline(x, x + 2, y, P["stone_dark"])
    c.hline(1, 30, 30, P["stone_dark"])
    crenels(c, 1, 30, 23)
    # Gate.
    c.rect(13, 25, 6, 6, P["door"])
    c.hline(14, 17, 24, P["door"])
    c.vline(16, 26, 30, P["wood_dark"])
    # Keep: tiers 1, 1, 2, 2, 3, 3 by castle level.
    tiers = (level + 1) // 2
    width, base = 18, 21
    top = base
    for tier in range(tiers):
        left = 16 - width // 2
        wall_h = 4 if tier == 0 else 3
        c.rect(left + 2, top - wall_h + 1, width - 4, wall_h, P["wall"])
        c.hline(left + 2, left + width - 3, top, P["wall_shade"])
        if tier == 0:
            c.rect(15, top - 2, 2, 3, P["door"])
            c.px(left + 4, top - 2, P["door"])
            c.px(left + width - 5, top - 2, P["door"])
        else:
            c.px(16, top - 1, P["door"])
        top -= wall_h + 3
        curved_roof(c, left, top + 1, width, 3)
        width -= 4
    # Corner towers over the walls.
    for x, y in ((0, 3), (25, 3), (0, 20), (25, 20)):
        tower(c, x, y, level)
    if level >= 2:  # banner on the keep
        c.vline(16, top - 4, top, P["wood_dark"])
        c.rect(17, top - 4, 3, 2, P["red"])
    if level >= 5:  # banners on the front towers
        for x in (3, 28):
            c.vline(x, 14, 18, P["wood_dark"])
            c.rect(x + 1 if x < 16 else x - 3, 14, 3, 2, P["red"])
    if level >= 6:  # gold trim on every roof ridge
        for y in range(c.height):
            for x in range(c.width):
                if c.get(x, y) == P["roof_light"]:
                    c.px(x, y, P["gold"])
    c.outline()
    return c


def hall(roof: str, roof_dark: str, wall_w: int = 12) -> Canvas:
    c = Canvas(16, 16)
    left = (16 - wall_w) // 2
    c.rect(left, 8, wall_w, 6, P["wall"])
    c.hline(left, left + wall_w - 1, 13, P["wall_shade"])
    for row in range(4):
        inset = 3 - row
        c.hline(left - 1 + inset, left + wall_w - inset, 4 + row, P[roof] if row < 3 else P[roof_dark])
    c.px(left - 2, 6, P[roof_dark])
    c.px(left + wall_w + 1, 6, P[roof_dark])
    return c


def barracks() -> Canvas:
    c = hall("red", "red_dark", 12)
    c.rect(7, 10, 3, 4, P["door"])
    c.rect(4, 10, 2, 2, P["door"])
    c.rect(11, 10, 2, 2, P["door"])
    c.vline(14, 2, 13, P["wood_dark"])  # spear by the door
    c.px(14, 1, P["rock_light"])
    c.rect(1, 3, 1, 10, P["wood_dark"])  # banner pole
    c.rect(2, 3, 3, 3, P["roof"])
    c.outline()
    return c


def watchtower() -> Canvas:
    c = Canvas(16, 16)
    for x in (5, 10):
        c.vline(x, 6, 14, P["wood_dark"])
    for y in (9, 12):
        c.hline(5, 10, y, P["wood"])
    c.px(7, 10, P["wood"])
    c.px(8, 11, P["wood"])
    c.rect(4, 5, 8, 2, P["wood"])
    c.rect(5, 3, 6, 2, P["wall"])
    for row in range(3):
        c.hline(3 + 2 - row, 12 - 2 + row, row, P["red"] if row < 2 else P["red_dark"])
    c.px(7, 3, P["door"])
    c.outline()
    return c


def farm() -> Canvas:
    c = Canvas(16, 16)
    c.rect(2, 9, 9, 5, P["wall"])
    c.rect(5, 10, 2, 4, P["door"])
    for row in range(5):
        inset = 4 - row
        c.hline(1 + inset, 11 - inset, 4 + row, P["thatch"] if row % 2 == 0 else P["thatch_dark"])
    c.ellipse(13, 12, 2.6, 2.6, P["thatch"])  # haystack
    c.px(12, 11, P["thatch_dark"])
    c.px(14, 13, P["thatch_dark"])
    c.outline()
    return c


def lumber_mill() -> Canvas:
    c = hall("wood", "wood_dark", 9)
    c.rect(5, 10, 2, 4, P["door"])
    for i, y in enumerate((11, 13)):  # log pile
        c.hline(9, 14, y, P["wood"])
        c.px(14, y, P["wood_light"])
        c.hline(9, 14, y + 1, P["wood_dark"]) if i == 1 else None
    c.px(9, 11, P["wood_light"])
    c.vline(1, 8, 13, P["rock_light"])  # saw blade leaning on the wall
    c.vline(2, 9, 12, P["rock"])
    c.outline()
    return c


def mine() -> Canvas:
    c = Canvas(16, 16)
    c.ellipse(8, 11, 7.2, 5.6, P["rock"])
    for y in range(c.height):
        for x in range(c.width):
            if c.get(x, y)[3] and y >= 12:
                c.px(x, y, P["rock_dark"])
    c.rect(5, 9, 6, 6, P["door"])  # tunnel with timber frame
    c.vline(5, 9, 14, P["wood"])
    c.vline(10, 9, 14, P["wood"])
    c.hline(5, 10, 9, P["wood_light"])
    c.px(3, 8, P["rock_light"])
    c.px(4, 7, P["rock_light"])
    c.px(12, 12, P["ore"])
    c.px(13, 10, P["ore_light"])
    c.outline()
    return c


DIGITS = {
    1: ["010", "110", "010", "010", "111"], 2: ["110", "001", "010", "100", "111"],
    3: ["110", "001", "010", "001", "110"], 4: ["101", "101", "111", "001", "001"],
    5: ["111", "100", "110", "001", "110"], 6: ["011", "100", "110", "101", "010"],
}


def level_badge(level: int) -> Canvas:
    """A small wooden plate with the building level in gold."""
    c = Canvas(7, 9)
    c.rect(1, 1, 5, 7, P["wood_dark"])
    for row, line in enumerate(DIGITS[level]):
        for col, bit in enumerate(line):
            if bit == "1":
                c.px(2 + col, 2 + row, P["gold"])
    c.outline()
    return c


# --- Resource icons (12×12, saved ×2) -----------------------------------------------------------

def icon_food() -> Canvas:
    c = Canvas(12, 12)
    c.ellipse(6, 5.6, 4.2, 3.2, P["rice"])
    c.px(4, 4, P["white"])
    c.hline(1, 10, 6, P["bowl"])
    c.hline(2, 9, 7, P["bowl"])
    c.hline(2, 9, 8, P["bowl_dark"])
    c.hline(3, 8, 9, P["bowl_dark"])
    c.hline(4, 7, 10, P["bowl_dark"])
    c.outline()
    return c


def log(c: Canvas, y: int, x0: int, x1: int, bark: str, ring: str) -> None:
    c.rect(x0, y, x1 - x0, 3, P[bark])
    c.hline(x0, x1 - 1, y, P[bark + "_light"] if bark + "_light" in P else P[bark])
    c.rect(x1, y, 2, 3, P[ring])
    c.px(x1, y + 1, P["wood_dark"])


def icon_wood() -> Canvas:
    c = Canvas(12, 12)
    log(c, 6, 1, 8, "wood", "wood_light")
    log(c, 2, 2, 9, "wood", "wood_light")
    c.outline()
    return c


def icon_hardwood() -> Canvas:
    c = Canvas(12, 12)
    log(c, 4, 1, 9, "hardwood", "hardwood_ring")
    c.px(3, 5, P["hardwood_light"])
    c.px(6, 6, P["hardwood_light"])
    c.outline()
    return c


def icon_stone() -> Canvas:
    c = Canvas(12, 12)
    c.rect(1, 6, 5, 4, P["rock"])
    c.rect(6, 6, 5, 4, P["rock_dark"])
    c.rect(3, 2, 6, 4, P["rock"])
    c.hline(3, 8, 2, P["rock_light"])
    c.hline(1, 5, 6, P["rock_light"])
    c.px(6, 7, P["rock"])
    c.outline()
    return c


def icon_ore() -> Canvas:
    c = Canvas(12, 12)
    c.ellipse(6, 7.5, 4.6, 3.2, P["rock_dark"])
    for x, h in ((4, 5), (6, 7), (8, 4)):
        c.vline(x, 9 - h, 8, P["ore"])
        c.vline(x + 1, 10 - h, 8, P["ore_dark"])
        c.px(x, 9 - h, P["ore_light"])
    c.outline()
    return c


def icon_horses() -> Canvas:
    """A horse head in profile."""
    c = Canvas(12, 12)
    c.rect(4, 2, 4, 5, P["horse"])
    c.rect(2, 5, 4, 3, P["horse"])
    c.rect(5, 7, 4, 4, P["horse"])
    c.px(2, 7, P["horse_dark"])
    c.px(5, 3, P["black"])
    c.vline(8, 2, 9, P["mane"])
    c.vline(9, 3, 9, P["mane"])
    c.px(5, 1, P["horse"])
    c.px(6, 1, P["horse_dark"])
    c.outline()
    return c


# --- UI frames (designed in art pixels, saved ×2) -----------------------------------------------

def wood_grain(c: Canvas, rng: random.Random, x0: int, y0: int, x1: int, y1: int) -> None:
    for y in range(y0, y1 + 1):
        for x in range(x0, x1 + 1):
            c.px(x, y, P["wood"])
        if (y - y0) % 4 == 3:
            c.hline(x0, x1, y, P["wood_dark"])
    for _ in range((x1 - x0 + 1) * (y1 - y0 + 1) // 10):
        c.px(rng.randint(x0, x1), rng.randint(y0, y1), P["wood_light"])


def panel_paper() -> Canvas:
    """Paper with a 3px wooden frame (9-slice margin 4 art px)."""
    rng = random.Random(11)
    c = Canvas(16, 16, P["outline"])
    c.rect(1, 1, 14, 14, P["wood"])
    c.hline(1, 14, 1, P["wood_light"])
    c.vline(1, 1, 14, P["wood_light"])
    c.hline(1, 14, 14, P["wood_deep"])
    c.vline(14, 1, 14, P["wood_deep"])
    c.rect(3, 3, 10, 10, P["paper"])
    c.hline(3, 12, 3, P["paper_shade"])
    c.vline(3, 3, 12, P["paper_shade"])
    speckle_area(c, rng, 4, 4, 12, 12, P["paper_fiber"], 8)
    c.rect(2, 2, 1, 12, P["wood_dark"])
    c.rect(2, 2, 12, 1, P["wood_dark"])
    c.rect(13, 2, 1, 12, P["wood_dark"])
    c.rect(2, 13, 12, 1, P["wood_dark"])
    return c


def panel_wood() -> Canvas:
    rng = random.Random(13)
    c = Canvas(16, 16, P["outline"])
    wood_grain(c, rng, 1, 1, 14, 14)
    c.hline(1, 14, 1, P["wood_light"])
    c.hline(1, 14, 14, P["wood_deep"])
    return c


def panel_inset() -> Canvas:
    """A sunken paper area for lists and info boxes."""
    c = Canvas(8, 8, P["paper_shade"])
    c.hline(0, 7, 0, P["bund_dark"])
    c.vline(0, 0, 7, P["bund_dark"])
    c.rect(1, 1, 6, 6, P["paper_fiber"])
    return c


def button(state: str) -> Canvas:
    """Raised wooden button, 16×12, 9-slice margin 3 art px."""
    base = {"normal": "wood", "hover": "wood_light", "pressed": "wood_dark", "disabled": "wood"}[state]
    c = Canvas(16, 12, P["outline"])
    c.rect(1, 1, 14, 10, P[base])
    if state == "pressed":
        c.hline(1, 14, 1, P["wood_deep"])
    else:
        c.hline(1, 14, 1, P["wood_light"] if state != "hover" else P["thatch"])
        c.hline(1, 14, 9, P["wood_dark"])
        c.hline(1, 14, 10, P["wood_deep"])
    if state == "disabled":
        gray = Canvas(16, 12)
        for y in range(12):
            for x in range(16):
                r, g, b, a = c.get(x, y)
                v = (r + g + b) // 3
                gray.px(x, y, ((v + 90) // 2, (v + 80) // 2, (v + 70) // 2, a))
        return gray
    return c


def tab(selected: bool) -> Canvas:
    """A hanging card tab, 12×12, open at the bottom (it joins the panel below)."""
    c = Canvas(12, 12, P["outline"])
    if selected:
        c.rect(1, 1, 10, 11, P["paper"])
        c.hline(1, 10, 1, P["wood_light"])
        c.hline(1, 10, 2, P["wood"])
    else:
        c.rect(1, 1, 10, 10, P["wood_dark"])
        c.hline(1, 10, 1, P["wood"])
        c.hline(0, 11, 11, P["outline"])
    return c


def main() -> None:
    tile_grass().save("tiles/grass.png")
    tile_farmland().save("tiles/farmland.png")
    tile_forest().save("tiles/forest.png")
    tile_hill().save("tiles/hill.png")
    tile_wild().save("tiles/wild.png")
    key_marker().save("tiles/key.png")
    key_frame().save("tiles/key_frame.png")
    for level in range(1, 7):
        castle(level).save(f"buildings/castle_{level}.png")
        level_badge(level).save(f"buildings/level_{level}.png")
    barracks().save("buildings/barracks.png")
    watchtower().save("buildings/watchtower.png")
    farm().save("buildings/farm.png")
    lumber_mill().save("buildings/lumber_mill.png")
    mine().save("buildings/mine.png")
    for name, draw in (("food", icon_food), ("wood", icon_wood), ("stone", icon_stone), ("ore", icon_ore),
                       ("hardwood", icon_hardwood), ("horses", icon_horses)):
        draw().save(f"icons/{name}.png", UI_SCALE)
    panel_paper().save("ui/panel_paper.png", UI_SCALE)
    panel_wood().save("ui/panel_wood.png", UI_SCALE)
    panel_inset().save("ui/panel_inset.png", UI_SCALE)
    for state in ("normal", "hover", "pressed", "disabled"):
        button(state).save(f"ui/button_{state}.png", UI_SCALE)
    tab(True).save("ui/tab_selected.png", UI_SCALE)
    tab(False).save("ui/tab_unselected.png", UI_SCALE)
    battle_art.draw_all()
    portrait_art.draw_all()
    world_art.draw_all()
    print("Art written to", ASSETS)


if __name__ == "__main__":
    main()
