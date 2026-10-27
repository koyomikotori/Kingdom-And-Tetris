"""Map life art (GDD §13, M13c): the tiny walkers on the kingdom map (villagers, carried loads,
patrolling soldiers, horses, ox carts, deer, birds). Called by generate.py.

Every sprite is a horizontal strip of frames (2 for walking, wings flapping), facing right; the
game mirrors them. Soldiers come with a "_team" strip holding their clothes in grays, tinted with
the player's color like the battle sprites.
"""

from pixel import P, Canvas, hex_color

TEAM = hex_color("ff00ff")
TEAM_DARK = hex_color("800080")
TEAM_GRAYS = {TEAM: hex_color("e0e0e0"), TEAM_DARK: hex_color("8e8e8e")}

SKIN = hex_color("f2c9a0")
HAIR = hex_color("2e1e14")
# Villager clothes: two looks so a crowd is not all one color.
VILLAGER_CLOTHES = {"villager_a": (hex_color("8a6a44"), hex_color("6a4e30")),
                    "villager_b": (hex_color("5f7d94"), hex_color("455d70"))}


def villager(frame: int, cloth, cloth_dark) -> Canvas:
    """A villager in a straw hat (5×8): legs apart on frame 1."""
    c = Canvas(7, 10)
    c.hline(1, 5, 1, P["thatch"])
    c.hline(2, 4, 0, P["thatch"])
    c.rect(2, 2, 3, 2, SKIN)
    c.px(4, 3, HAIR)
    c.rect(2, 4, 3, 3, cloth)
    c.vline(2, 4, 6, cloth_dark)
    c.px(5, 5, SKIN)
    legs = (2, 4) if frame == 1 else (3, 3)
    for x in legs:
        c.vline(x, 7, 8, P["wood_deep"])
    c.outline()
    return c


def carry(kind: str) -> Canvas:
    """What a villager carries home on their head (5×4)."""
    c = Canvas(6, 5)
    if kind == "food":
        c.ellipse(3, 2.5, 2.2, 1.8, P["thatch"])
        c.px(2, 2, P["thatch_dark"])
        c.px(4, 1, P["thatch_dark"])
    elif kind == "wood":
        c.hline(1, 4, 2, P["wood"])
        c.hline(1, 4, 3, P["wood_dark"])
        c.px(4, 2, P["wood_light"])
    elif kind == "stone":
        c.rect(1, 2, 3, 2, P["rock"])
        c.px(1, 2, P["rock_light"])
    elif kind == "ore":
        c.rect(1, 2, 3, 2, P["ore"])
        c.px(2, 2, P["ore_light"])
    c.outline()
    return c


def soldier(frame: int) -> Canvas:
    """A patrolling spearman (5×9) in the side's color with a conical hat."""
    c = Canvas(7, 12)
    c.vline(6, 0, 9, P["wood_dark"])
    c.px(6, 0, P["rock_light"])
    c.hline(1, 5, 2, P["thatch"])
    c.hline(2, 4, 1, P["thatch"])
    c.rect(2, 3, 3, 2, SKIN)
    c.px(4, 4, HAIR)
    c.rect(2, 5, 3, 3, TEAM)
    c.vline(2, 5, 7, TEAM_DARK)
    c.px(5, 6, SKIN)
    legs = (2, 4) if frame == 1 else (3, 3)
    for x in legs:
        c.vline(x, 8, 9, P["wood_deep"])
    c.outline()
    return c


def horse(frame: int) -> Canvas:
    """A grazing horse (9×7): legs apart on frame 1."""
    c = Canvas(11, 9)
    c.rect(2, 3, 6, 3, P["horse"])
    c.hline(2, 7, 5, P["horse_dark"])
    c.rect(7, 1, 2, 3, P["horse"])
    c.px(9, 2, P["horse"])
    c.px(8, 1, P["mane"])
    c.vline(7, 1, 3, P["mane"])
    c.px(1, 3, P["mane"])
    c.px(1, 4, P["mane"])
    legs = (2, 4, 6, 7) if frame == 0 else (3, 4, 6, 8)
    for x in legs:
        c.vline(x, 6, 7, P["horse_dark"])
    c.outline()
    return c


def cart(frame: int) -> Canvas:
    """An ox pulling a cart loaded with sacks (13×8); the wheel spokes turn."""
    c = Canvas(15, 10)
    c.rect(1, 2, 6, 3, P["wood"])
    c.hline(1, 6, 2, P["wood_light"])
    c.rect(2, 0, 3, 2, P["thatch"])
    c.px(3, 0, P["thatch_dark"])
    c.ellipse(3.5, 6.5, 1.8, 1.8, P["wood_dark"])
    c.px(3 + frame, 6, P["wood_light"])
    c.hline(7, 8, 4, P["wood_dark"])
    c.rect(9, 3, 4, 3, P["rock_dark"])
    c.rect(12, 2, 2, 2, P["rock_dark"])
    c.px(13, 1, P["wall"])
    legs = (9, 12) if frame == 0 else (10, 11)
    for x in legs:
        c.vline(x, 6, 7, P["wood_deep"])
    c.outline()
    return c


def deer(frame: int) -> Canvas:
    """A deer with small antlers (7×7)."""
    c = Canvas(9, 9)
    c.rect(1, 4, 5, 2, P["dirt"])
    c.hline(1, 5, 5, P["dirt_dark"])
    c.rect(5, 2, 2, 2, P["dirt"])
    c.px(6, 0, P["wood_dark"])
    c.px(5, 1, P["wood_dark"])
    c.px(7, 1, P["wood_dark"])
    c.px(1, 3, P["wall"])
    legs = (1, 5) if frame == 0 else (2, 4)
    for x in legs:
        c.vline(x, 6, 7, P["dirt_dark"])
    c.outline()
    return c


def bird(frame: int) -> Canvas:
    """A small dark bird, wings up (frame 0) or down (frame 1)."""
    c = Canvas(7, 5)
    c.px(3, 2, P["outline"])
    c.px(4, 2, P["outline"])
    if frame == 0:
        c.px(2, 1, P["outline"])
        c.px(1, 0, P["outline"])
        c.px(5, 1, P["outline"])
        c.px(6, 0, P["outline"])
    else:
        c.px(2, 3, P["outline"])
        c.px(1, 3, P["outline"])
        c.px(5, 3, P["outline"])
        c.px(6, 3, P["outline"])
    return c


def strip(frames: list) -> Canvas:
    out = Canvas(frames[0].width * len(frames), frames[0].height)
    for i, frame in enumerate(frames):
        out.paste(frame, i * frames[0].width, 0)
    return out


def split_team(full: Canvas) -> tuple:
    base = Canvas(full.width, full.height)
    team = Canvas(full.width, full.height)
    for y in range(full.height):
        for x in range(full.width):
            color = full.get(x, y)
            if color in TEAM_GRAYS:
                team.px(x, y, TEAM_GRAYS[color])
            elif color[3]:
                base.px(x, y, color)
    return base, team


def draw_all() -> None:
    for name, (cloth, dark) in VILLAGER_CLOTHES.items():
        strip([villager(f, cloth, dark) for f in range(2)]).save(f"map/{name}.png")
    for kind in ("food", "wood", "stone", "ore"):
        carry(kind).save(f"map/carry_{kind}.png")
    base, team = split_team(strip([soldier(f) for f in range(2)]))
    base.save("map/soldier.png")
    team.save("map/soldier_team.png")
    strip([horse(f) for f in range(2)]).save("map/horse.png")
    strip([cart(f) for f in range(2)]).save("map/cart.png")
    strip([deer(f) for f in range(2)]).save("map/deer.png")
    strip([bird(f) for f in range(2)]).save("map/bird.png")
