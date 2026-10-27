"""Equipment art (GDD §8 "Trang bị", M12e): 16×16 item icons by type and for each legendary item,
24×24 slot frames by rarity (patterns from Hiếm up), and the forge building. Called by generate.py.

Item types match Item.type_key() in scripts/equipment/item.gd; legendary ids match
data/legendary_items/.
"""

from pixel import CLEAR, P, Canvas, hex_color

K = {
    "steel": hex_color("dde3ea"), "steel_dark": hex_color("9aa4b2"), "edge": hex_color("ffffff"),
    "iron": hex_color("7d8796"), "iron_dark": hex_color("4e5662"), "black_iron": hex_color("3a3f48"),
    "shaft": hex_color("8a5a32"), "lacquer": hex_color("a8322a"), "gold": hex_color("f2c23c"),
    "gold_dark": hex_color("b9862a"), "gold_light": hex_color("fff0a0"), "tassel": hex_color("d23a2a"),
    "jade": hex_color("4fb38a"), "jade_dark": hex_color("2e7a5c"), "jade_light": hex_color("9de0c0"),
    "leather": hex_color("8a5a34"), "leather_dark": hex_color("5e3b22"), "cloth": hex_color("3e6fb0"),
    "cloth_dark": hex_color("2a4a7a"), "cloth_light": hex_color("7aa2d8"), "feather": hex_color("f6f1e4"),
    "feather_dark": hex_color("c9bfa8"), "paper": hex_color("efe3c2"), "purple": hex_color("6a3e9a"),
    "purple_dark": hex_color("432463"), "purple_light": hex_color("a77ad6"), "white": hex_color("ffffff"),
    "bronze": hex_color("b0703a"), "bronze_dark": hex_color("6e4120"), "bronze_light": hex_color("d6a06a"),
    "dark_blade": hex_color("4a4f5c"), "red_light": hex_color("ff8a6a"),
}


def line(c: Canvas, x0: int, y0: int, x1: int, y1: int, color) -> None:
    """Bresenham line."""
    dx, dy = abs(x1 - x0), -abs(y1 - y0)
    sx, sy = (1 if x0 < x1 else -1), (1 if y0 < y1 else -1)
    err = dx + dy
    while True:
        c.px(x0, y0, color)
        if x0 == x1 and y0 == y1:
            break
        e2 = 2 * err
        if e2 >= dy:
            err += dy
            x0 += sx
        if e2 <= dx:
            err += dx
            y0 += sy


def sparkle(c: Canvas) -> None:
    """A little star in the corner of legendary icons."""
    for x, y in ((2, 1), (1, 2), (2, 2), (3, 2), (2, 3)):
        c.px(x, y, K["gold_light"] if (x, y) != (2, 2) else K["white"])


# --- Icons (diagonal weapons point to the top right) ------------------------------------------

def dao(blade="steel", shaft="shaft", trim="gold", legendary=False) -> Canvas:
    c = Canvas(16, 16)
    line(c, 2, 14, 9, 7, K[shaft])
    line(c, 3, 14, 10, 7, K[shaft])
    # A slim blade curving back from the tip, its edge on the outside, a notch on the back.
    for y, (x0, x1) in enumerate(((14, 14), (13, 14), (13, 14), (12, 13), (11, 13), (10, 12), (10, 11))):
        c.hline(x0, x1, 1 + y, K[blade])
        c.px(x1, 1 + y, K["edge"])
    c.px(12, 3, K[blade])
    c.hline(8, 11, 8, K[trim])
    c.px(7, 10, K["tassel"])
    c.px(6, 11, K["tassel"])
    if legendary:
        for x, y in ((5, 11), (7, 9)):
            c.px(x, y, K[trim])
    c.outline()
    if legendary:
        sparkle(c)
    return c


def thuong(tip="steel", shaft="shaft", wavy=False, legendary=False) -> Canvas:
    c = Canvas(16, 16)
    line(c, 1, 14, 10, 5, K[shaft])
    line(c, 2, 14, 11, 5, K[shaft])
    if wavy:  # a snake-like tip
        for x, y in ((11, 4), (12, 4), (12, 3), (13, 3), (13, 2), (14, 1), (12, 2)):
            c.px(x, y, K[tip])
    else:
        for x, y in ((11, 4), (12, 3), (13, 2), (14, 1), (12, 4), (11, 3), (13, 3)):
            c.px(x, y, K[tip])
    c.px(13, 2, K["edge"])
    for x, y in ((9, 6), (8, 6), (9, 7), (8, 8)):
        c.px(x, y, K["tassel"])
    c.outline()
    if legendary:
        sparkle(c)
    return c


def kiem(blade="steel", hilt="gold", legendary=False) -> Canvas:
    c = Canvas(16, 16)
    line(c, 5, 10, 13, 2, K[blade])
    line(c, 6, 10, 13, 3, K[blade])
    line(c, 6, 9, 13, 2, K["edge"])
    line(c, 3, 9, 6, 12, K[hilt])  # guard
    line(c, 2, 13, 4, 11, K["leather_dark"])
    c.px(2, 14, K[hilt])
    c.outline()
    if legendary:
        sparkle(c)
    return c


def kich(blade="steel", shaft="shaft", double=False, legendary=False) -> Canvas:
    c = Canvas(16, 16)
    line(c, 1, 14, 10, 5, K[shaft])
    line(c, 2, 14, 11, 5, K[shaft])
    for x, y in ((11, 4), (12, 3), (13, 2), (14, 1), (12, 4)):
        c.px(x, y, K[blade])
    for x, y in ((8, 3), (8, 4), (9, 2), (10, 2), (7, 5), (7, 6)):  # crescent side blade
        c.px(x, y, K[blade])
    if double:
        for x, y in ((12, 7), (13, 7), (13, 8), (14, 6), (14, 5)):
            c.px(x, y, K[blade])
    c.px(9, 6, K["tassel"])
    c.outline()
    if legendary:
        sparkle(c)
    return c


def chuy(head="iron", head_dark="iron_dark", legendary=False) -> Canvas:
    c = Canvas(16, 16)
    line(c, 2, 14, 7, 9, K["shaft"])
    line(c, 3, 14, 8, 9, K["shaft"])
    c.ellipse(10.5, 5.5, 3.6, 3.6, K[head])
    c.ellipse(11.0, 6.2, 2.0, 2.0, K[head_dark])
    for x, y in ((10, 1), (14, 5), (10, 10), (6, 5), (13, 2), (13, 9), (7, 2)):
        c.px(x, y, K[head])
    c.px(9, 4, K["edge"])
    c.outline()
    if legendary:
        sparkle(c)
    return c


def armor(plate="iron", plate_dark="iron_dark", trim="gold", legendary=False) -> Canvas:
    c = Canvas(16, 16)
    c.rect(4, 3, 8, 10, K[plate])
    c.rect(2, 3, 2, 4, K[plate_dark])  # shoulder guards
    c.rect(12, 3, 2, 4, K[plate_dark])
    for y in (5, 8, 11):
        for x in range(4 + (y // 3) % 2, 12, 2):
            c.px(x, y, K[plate_dark])
    c.hline(4, 11, 9, K["leather_dark"])  # belt
    c.px(7, 9, K[trim])
    c.px(8, 9, K[trim])
    c.hline(6, 9, 2, K[trim])  # collar
    if legendary:
        c.vline(4, 3, 12, K[trim])
        c.vline(11, 3, 12, K[trim])
    c.outline()
    if legendary:
        sparkle(c)
    return c


def token(body="gold", body_dark="gold_dark", tiger=False, legendary=False) -> Canvas:
    """A command token (lệnh bài / hổ phù) with a red cord."""
    c = Canvas(16, 16)
    if tiger:  # a crouching tiger tally
        c.rect(3, 7, 10, 4, K[body])
        c.rect(10, 5, 3, 3, K[body])
        c.hline(4, 12, 10, K[body_dark])
        for x in (5, 8, 11):
            c.px(x, 8, K[body_dark])
        c.px(12, 6, K["black_iron"])
        c.vline(3, 11, 12, K[body])
        c.vline(11, 11, 12, K[body])
    else:
        c.rect(5, 4, 6, 9, K[body])
        c.hline(6, 9, 3, K[body])
        c.vline(5, 4, 12, K[body_dark])
        c.hline(7, 8, 6, K["lacquer"])
        c.hline(7, 8, 8, K["lacquer"])
        c.hline(7, 8, 10, K["lacquer"])
    c.vline(8 if not tiger else 7, 0, 2 if not tiger else 6, K["tassel"])
    c.px(9, 1, K["tassel"])
    c.outline()
    if legendary:
        sparkle(c)
    return c


def fan(feather="feather", feather_dark="feather_dark", rim="gold_dark", legendary=False) -> Canvas:
    c = Canvas(16, 16)
    c.ellipse(9.5, 6.0, 5.5, 5.0, K[feather])
    for i in range(5):
        line(c, 7, 11, 5 + i * 2, 2 + abs(2 - i), K[feather_dark])
    c.hline(5, 13, 10, K[rim])
    line(c, 6, 11, 3, 14, K[rim])
    line(c, 7, 11, 4, 14, K["lacquer"])
    c.outline()
    if legendary:
        sparkle(c)
    return c


def robe(cloth="cloth", cloth_dark="cloth_dark", cloth_light="cloth_light", bagua=False, legendary=False) -> Canvas:
    c = Canvas(16, 16)
    for row in range(12):
        half = 3 + row // 3
        c.hline(8 - half, 7 + half, 2 + row, K[cloth])
    c.rect(1, 4, 3, 5, K[cloth_dark])  # sleeves
    c.rect(12, 4, 3, 5, K[cloth_dark])
    line(c, 6, 2, 8, 6, K["paper"])  # crossed collar
    line(c, 9, 2, 8, 6, K["paper"])
    c.hline(4, 11, 8, K[cloth_light])
    if bagua:
        c.ellipse(8, 11, 2.2, 2.2, K["gold"])
        c.px(7, 11, K["black_iron"])
        c.px(8, 10, K["white"])
    c.outline()
    if legendary:
        sparkle(c)
    return c


def pendant(stone="jade", stone_dark="jade_dark", seal=False, legendary=False) -> Canvas:
    c = Canvas(16, 16)
    if seal:  # a square seal with a dragon knob
        c.rect(4, 8, 8, 6, K[stone])
        c.hline(4, 11, 13, K[stone_dark])
        c.rect(6, 4, 4, 4, K["gold"])
        c.px(7, 3, K["gold"])
        c.px(9, 5, K["gold_dark"])
        c.hline(5, 10, 10, K["lacquer"])
    else:  # a round jade disc with a hole and a red cord
        c.ellipse(8, 10, 4.6, 4.2, K[stone])
        c.ellipse(8, 10, 1.4, 1.4, CLEAR)
        c.px(6, 8, K["jade_light"] if stone == "jade" else K["white"])
        c.vline(8, 1, 5, K["tassel"])
        c.px(7, 2, K["tassel"])
        c.px(9, 2, K["tassel"])
    c.outline()
    if legendary:
        sparkle(c)
    return c


ICONS = {
    "dao": lambda: dao(),
    "thuong": lambda: thuong(),
    "kiem": lambda: kiem(),
    "kich": lambda: kich(),
    "chuy": lambda: chuy(),
    "general_armor": lambda: armor(),
    "general_accessory": lambda: token(),
    "advisor_weapon": lambda: fan(),
    "advisor_armor": lambda: robe(),
    "advisor_accessory": lambda: pendant(),
    # Legendary items: the type's shape in their own colors, with a sparkle.
    "thanh_long_dao": lambda: dao(shaft="jade_dark", trim="gold", legendary=True),
    "do_long_dao": lambda: dao(blade="dark_blade", shaft="lacquer", trim="gold", legendary=True),
    "truong_bat_xa_mau": lambda: thuong(wavy=True, shaft="black_iron", legendary=True),
    "phuong_thien_hoa_kich": lambda: kich(blade="steel", shaft="lacquer", double=True, legendary=True),
    "y_thien_kiem": lambda: kiem(blade="edge", hilt="jade", legendary=True),
    "bat_qua_chuy": lambda: chuy(head="gold", head_dark="gold_dark", legendary=True),
    "thiet_lan_giap": lambda: armor(plate="black_iron", plate_dark="iron_dark", trim="gold", legendary=True),
    "ho_phu_tin_lang": lambda: token(tiger=True, legendary=True),
    "quat_long_ngoa_long": lambda: fan(rim="gold", legendary=True),
    "bat_quai_dao_bao": lambda: robe("purple", "purple_dark", "purple_light", bagua=True, legendary=True),
    "ngoc_ty_truyen_quoc": lambda: pendant(seal=True, legendary=True),
}


# --- Frames -----------------------------------------------------------------------------------

# (base, light, dark) border colors by rarity, then the empty slot.
FRAME_COLORS = [
    ("iron", "steel_dark", "iron_dark"),
    ("jade_dark", "jade", "jade_dark"),
    ("cloth", "cloth_light", "cloth_dark"),
    ("purple", "purple_light", "purple_dark"),
    ("gold", "gold_light", "gold_dark"),
]


def frame(size: int, colors: tuple, pattern: int, inner=None, width: int = 2) -> Canvas:
    """A beveled border `width` px wide inside a dark outline. `pattern`: 0 none, 1 corner studs,
    2 corner ornaments and edge studs, 3 rich: longer ornaments, studs all round and an inner gold
    line. Ornaments grow with the frame (one unit per 24 px)."""
    base, light, dark = (K[name] for name in colors)
    unit = max(1, size // 24)
    c = Canvas(size, size)
    if inner is not None:
        c.rect(1 + width, 1 + width, size - 2 - 2 * width, size - 2 - 2 * width, inner)
    last = size - 1
    for i in range(size):
        for x, y in ((i, 0), (i, last), (0, i), (last, i)):
            c.px(x, y, P["outline"])
    for d in range(1, 1 + width):
        for i in range(d, size - d):
            c.px(i, d, light if d == 1 else base)
            c.px(d, i, light if d == 1 else base)
            c.px(i, last - d, dark if d == 1 else base)
            c.px(last - d, i, dark if d == 1 else base)
    stud = K["gold_light"] if colors[0] != "gold" else K["white"]

    def dot(x: int, y: int, color) -> None:
        c.rect(x - (unit - 1) // 2, y - (unit - 1) // 2, unit, unit, color)

    corners = ((1 + width, 1 + width, 1, 1), (last - 1 - width, 1 + width, -1, 1),
               (1 + width, last - 1 - width, 1, -1), (last - 1 - width, last - 1 - width, -1, -1))
    if pattern >= 1:
        for x, y, sx, sy in corners:
            dot(x + sx * (unit // 2), y + sy * (unit // 2), stud)
    if pattern >= 2:
        reach = (2 + pattern) * unit
        for x, y, sx, sy in corners:
            for k in range(1, reach):
                for w in range(unit):
                    c.px(x + sx * k, y + sy * w, base)
                    c.px(x + sx * w, y + sy * k, base)
            for k in range(unit, 2 * unit):
                for w in range(unit, 2 * unit):
                    c.px(x + sx * k, y + sy * w, base)
            dot(x + sx * reach, y + sy * (unit // 2), stud)
            dot(x + sx * (unit // 2), y + sy * reach, stud)
        mid = size // 2
        for x, y in ((mid, width), (width, mid), (mid, last - width), (last - width, mid)):
            dot(x, y, stud)
    if pattern >= 3:
        step = max(6, size // 8)
        for i in range(step, size - step + 1, step):
            for x, y in ((i, 1 + width // 2), (1 + width // 2, i), (i, last - 1 - width // 2), (last - 1 - width // 2, i)):
                dot(x, y, stud)
        for i in range(3 + width, size - 3 - width):  # inner gold line
            for x, y in ((i, 1 + width), (1 + width, i), (i, last - 1 - width), (last - 1 - width, i)):
                if c.get(x, y)[3] == 0:
                    c.px(x, y, K["gold_dark"])
    return c


def item_frames() -> list:
    """Item slots (24×24): the empty slot, then one per rarity (patterns from Hiếm up)."""
    empty = frame(24, ("leather", "leather", "leather_dark"), 0, hex_color("e6d7b2"))
    frames = [frame(24, colors, max(0, rarity - 1), hex_color("f3e8cc")) for rarity, colors in enumerate(FRAME_COLORS)]
    return [empty] + frames


# --- The forge (16×16 building) ---------------------------------------------------------------

def forge() -> Canvas:
    """A smithy: dark tile roof, stone chimney with a glow and smoke, an anvil by the open front."""
    c = Canvas(16, 16)
    c.rect(2, 8, 11, 6, P["wall"])
    c.hline(2, 12, 13, P["wall_shade"])
    for row in range(4):
        inset = 3 - row
        c.hline(1 + inset, 13 - inset, 4 + row, P["roof_dark"] if row == 3 else P["roof"])
    c.rect(11, 1, 3, 6, P["stone_dark"])  # chimney
    c.hline(11, 13, 1, P["stone"])
    c.px(12, 0, P["rock_light"])
    c.rect(4, 10, 4, 4, P["door"])  # open front with the fire inside
    c.px(5, 12, K["tassel"])
    c.px(6, 12, K["gold"])
    c.px(5, 11, K["red_light"])
    c.rect(9, 11, 4, 1, K["iron_dark"])  # anvil
    c.rect(10, 12, 2, 2, K["iron_dark"])
    c.px(12, 11, K["iron"])
    c.outline()
    return c


def draw_all() -> None:
    for name, draw in ICONS.items():
        draw().save(f"items/{name}.png")
    frames = item_frames()
    frames[0].save("items/frame_empty.png")
    for rarity, canvas in enumerate(frames[1:]):
        canvas.save(f"items/frame_{rarity}.png")
    forge().save("buildings/forge.png")
