"""World map art (GDD §13, M12c): an old map on paper. Parchment, mountains, trees, a small fort
per clan (its roof trim and banner in a "_team" layer tinted with the clan's color) and pixel
icons for war, alliance and non-aggression pact. Called by generate.py.
"""

import random

from pixel import P, Canvas, hex_color

INK = hex_color("4a3220")
INK_LIGHT = hex_color("7a5a3a")
GRAY_BASE, GRAY_SHADE = hex_color("e0e0e0"), hex_color("909090")


def parchment() -> Canvas:
    """Tileable 64×64 paper with fibers and faint stains."""
    rng = random.Random(9)
    c = Canvas(64, 64, hex_color("e8d6a8"))
    for _ in range(260):
        c.px(rng.randrange(64), rng.randrange(64), rng.choice([hex_color("e1cd9b"), hex_color("efdfb6"),
                                                               hex_color("dcc592")]))
    for _ in range(3):
        cx, cy = rng.randrange(64), rng.randrange(64)
        for _ in range(40):
            c.px((cx + rng.randint(-5, 5)) % 64, (cy + rng.randint(-4, 4)) % 64, hex_color("d8c08a"))
    return c


def mountain() -> Canvas:
    """A peak drawn like ink on an old map (24×16): ink outline, hatching on the shaded side."""
    c = Canvas(24, 16)
    for y in range(16):
        half = y * 0.75
        x0, x1 = round(11.5 - half), round(11.5 + half)
        for x in range(x0, x1 + 1):
            c.px(x, y, hex_color("cdb88a") if x > 11 else hex_color("b9a275"))
        c.px(x0, y, INK)
        c.px(x1, y, INK)
    for y in range(4, 15, 2):  # hatching
        c.hline(round(11.5 - y * 0.75) + 2, 10, y, INK_LIGHT)
    c.hline(10, 13, 0, hex_color("f4ecd8"))
    c.px(11, 1, hex_color("f4ecd8"))
    return c


def trees() -> Canvas:
    """A small cluster of ink-drawn trees (18×14)."""
    c = Canvas(18, 14)
    for x0, y0 in ((1, 3), (7, 0), (11, 4)):
        for y in range(7):
            half = y * 0.6
            c.hline(round(x0 + 3 - half), round(x0 + 3 + half), y0 + y, hex_color("8a9a5a"))
        c.vline(x0 + 3, y0 + 7, y0 + 9, INK)
    c.outline(INK)
    return c


def fort() -> tuple:
    """A clan's walled fort (24×22): stone walls and gate, a roofed keep, a banner. The banner and
    the roof trim are in the team layer."""
    c = Canvas(24, 22)
    team = Canvas(24, 22)
    c.rect(2, 12, 20, 9, P["stone"])
    for x in range(2, 22, 3):
        c.rect(x, 10, 2, 2, P["stone"])
    c.hline(2, 21, 20, P["stone_dark"])
    c.rect(10, 15, 4, 6, P["door"])
    c.rect(6, 6, 12, 6, P["wall"])
    for row in range(3):
        c.hline(5 - row + 2, 18 + row - 2, 3 + row, P["roof"] if row < 2 else P["roof_dark"])
    team.hline(4, 19, 6, GRAY_BASE)  # roof trim
    c.vline(12, 0, 3, P["wood_dark"])
    team.rect(13, 0, 5, 3, GRAY_BASE)  # banner
    team.px(17, 2, GRAY_SHADE)
    for x, y in ((9, 8), (14, 8)):
        c.px(x, y, P["door"])
    full = Canvas(24, 22)
    full.paste(c, 0, 0)
    full.paste(team, 0, 0)
    full.outline(INK)
    for y in range(22):  # keep the outline in the base layer only
        for x in range(24):
            if full.get(x, y) == INK and not team.get(x, y)[3]:
                c.px(x, y, INK)
    return c, team


def icon_war() -> Canvas:
    """Crossed swords (12×12)."""
    c = Canvas(12, 12)
    for i in range(9):
        c.px(1 + i, 1 + i, P["rock_light"])
        c.px(10 - i, 1 + i, P["rock_light"])
    for x, y in ((2, 8), (3, 9), (9, 8), (8, 9)):
        c.px(x, y, P["gold"])
    c.outline(INK)
    return c


def icon_alliance() -> Canvas:
    """Two joined rings (12×12)."""
    c = Canvas(12, 12)
    for cx in (4, 8):
        for y in range(12):
            for x in range(12):
                d = ((x + 0.5 - cx) ** 2 + (y + 0.5 - 6) ** 2) ** 0.5
                if 2.2 <= d <= 3.4:
                    c.px(x, y, hex_color("5ac8e6"))
    c.outline(INK)
    return c


def icon_pact() -> Canvas:
    """A sealed scroll (12×12)."""
    c = Canvas(12, 12)
    c.rect(2, 3, 8, 6, hex_color("f4ecd8"))
    c.vline(1, 2, 9, P["wood"])
    c.vline(10, 2, 9, P["wood"])
    c.hline(3, 8, 5, INK_LIGHT)
    c.hline(3, 7, 7, INK_LIGHT)
    c.rect(7, 7, 2, 2, P["red"])
    c.outline(INK)
    return c


def draw_all() -> None:
    parchment().save("world/parchment.png")
    mountain().save("world/mountain.png")
    trees().save("world/trees.png")
    base, team = fort()
    base.save("world/fort.png")
    team.save("world/fort_team.png")
    icon_war().save("world/icon_war.png")
    icon_alliance().save("world/icon_alliance.png")
    icon_pact().save("world/icon_pact.png")
