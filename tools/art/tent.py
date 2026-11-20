"""The tent's tarp in pixel art, drawn in code (ART.md: small and exact things in code, big and
varied ones from the model). The counter, the stools, the fittings, signs and touches (fittings.py); and one image for each tarp colour and shape the game offers
(rules/bar_look.gd's BAR_TARPS and TENT_SHAPES), shaded for its shape only, in
clean steps of the palette's light ramps (no dither, and no bulbs' glow drawn in: the game's
light does that, the same as on the people: ART.md, 20 Nov), onto the street's pixel grid (each pixel 3 on
screen), the same outline as the stage's code tarp (tent_view.gd tent_shape), so everything
hung from it still lines up.

    python3 tools/art/tent.py            (all of them, into art/tarps/, the manifest and LICENSE-ASSETS)
    python3 tools/art/tent.py --preview out.png
"""
import math, os, re, sys
import numpy as np
from PIL import Image, ImageDraw

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import palette

STAGE_W = 1872  # the tent's stage (visit.gd STAGE_SIZE.x), drawn at a third: one grid pixel to 3
GRID = 3
ROWS = 46  # the image's height in grid pixels: the stage's top 138, down past the scallops
EAVE = 112  # the cover's front edge, on the stage
SOURCE = "drawn in code by tools/art/tent.py"
LICENCE = "CC BY-SA 4.0 (this project)"


def tarps():
    """The game's tarps: {id: (main colour, stripe colour or "")}, from bar_look.gd."""
    text = open(os.path.join(palette.ROOT, "scripts/rules/bar_look.gd"), encoding="utf-8").read()
    block = text[text.index("const BAR_TARPS"):text.index("}", text.index("const BAR_TARPS"))]
    return {m[0]: (m[1], m[2]) for m in re.findall(r'"(\w+)": \["([0-9a-fA-F]{6})", "([0-9a-fA-F]{0,6})"\]', block)}


def sign_styles():
    """The game's sign styles: {id: (board colour, text colour)}, from bar_look.gd."""
    text = open(os.path.join(palette.ROOT, "scripts/rules/bar_look.gd"), encoding="utf-8").read()
    block = text[text.index("const SIGN_STYLES"):text.index("}", text.index("const SIGN_STYLES"))]
    return {m[0]: (m[1], m[2]) for m in re.findall(r'"(\w+)": \["([0-9a-fA-F]{6})", "([0-9a-fA-F]{6})"\]', block)}


def shapes():
    text = open(os.path.join(palette.ROOT, "scripts/rules/bar_look.gd"), encoding="utf-8").read()
    block = text[text.index("const TENT_SHAPES"):text.index("}", text.index("const TENT_SHAPES"))]
    return re.findall(r'"(\w+)": "', block)


def outline(shape):
    """The cover's outline on the stage (as tent_view.gd tent_shape)."""
    w = STAGE_W
    if shape == "peaked":
        return [(22, 112), (160, 62), (w / 2, 26), (w - 160, 62), (w - 22, 112)]
    if shape == "awning":
        return [(22, 72), (w - 22, 72), (w - 22, 112), (22, 112)]
    if shape == "rounded":
        return [(22 + t / 24 * (w - 44), 112 - math.sin(t / 24 * math.pi) * 80) for t in range(25)]
    return [(100, 40), (w - 100, 40), (w - 22, 112), (22, 112)]


def darkened(rgb, amount):
    return tuple(int(round(c * (1 - amount))) for c in rgb)


def draw(tarp, shape):
    """The base colours (RGB) and what's tarp (mask), on the grid."""
    main, stripe = tarps()[tarp]
    main = palette.hexc(main)
    stripe = palette.hexc(stripe) if stripe else None
    W = STAGE_W // GRID
    base = Image.new("RGBA", (W, ROWS), (0, 0, 0, 0))
    d = ImageDraw.Draw(base)
    g = lambda pts: [(x / GRID, y / GRID) for x, y in pts]
    cover = g(outline(shape))
    d.polygon(cover, fill=main + (255,))
    if stripe:  # stripes, cut to the shape of the cover
        mask = Image.new("L", (W, ROWS), 0)
        ImageDraw.Draw(mask).polygon(cover, fill=255)
        bands = Image.new("RGBA", (W, ROWS), (0, 0, 0, 0))
        bd = ImageDraw.Draw(bands)
        for k in range(14):
            a = 22 + (k + 0.25) / 14 * (STAGE_W - 44)
            b = 22 + (k + 0.6) / 14 * (STAGE_W - 44)
            bd.rectangle([a / GRID, 0, b / GRID - 1, ROWS], fill=stripe + (255,))
        arr = np.asarray(base).copy()
        arr[(np.asarray(mask) > 0) & (np.asarray(bands)[..., 3] > 0)] = stripe + (255,)
        base = Image.fromarray(arr, "RGBA")
        d = ImageDraw.Draw(base)
    if shape != "awning":  # the front edge's band
        d.rectangle([22 / GRID, EAVE / GRID, (STAGE_W - 22) / GRID - 1, (EAVE + 10) / GRID - 1], fill=darkened(main, 0.2) + (255,))
    if shape == "scalloped":
        for x in range(22, STAGE_W - 22, 52):
            pts = [(x + t / 8 * 52, 122 + math.sin(t / 8 * math.pi) * 14) for t in range(9)]
            d.polygon(g(pts), fill=darkened(main, 0.2) + (255,))
    if shape == "awning":
        for x in range(22, STAGE_W - 22, 40):
            d.polygon(g([(x, 112), (x + 40, 112), (x + 20, 130)]), fill=(stripe or darkened(main, 0.25)) + (255,))
    return base


def lit(base):
    """Shaded for its shape: brighter towards the front edge (the bulbs are under it, below the
    eave), the back in shade, in clean steps on each colour's own ramp; and a dark line along
    the top, pixel art's way. The glow round each bulb is the game's light (pixel_light.gd)."""
    arr = np.asarray(base).copy()
    h, w = arr.shape[:2]
    yy, xx = np.mgrid[0:h, 0:w]
    filled = arr[..., 3] > 0
    top = np.argmax(filled, axis=0)  # each column's first row of tarp
    span = np.maximum(EAVE / GRID - top, 1)
    depth = np.clip((yy - top[None, :]) / span[None, :], 0, 1.3)
    light = 0.55 + 0.35 * depth
    step = steps(light, yy, xx)
    edge = filled & ~np.roll(filled, 1, axis=0)  # the top line
    edge[0] = filled[0]
    step[edge] = 1
    out = np.zeros_like(arr)
    for colour in {tuple(c) for c in arr[filled][:, :3]}:
        r = np.array(palette.ramp(colour))
        m = filled & np.all(arr[..., :3] == colour, axis=-1)
        out[m, :3] = r[step[m]]
        out[m, 3] = 255
    return Image.fromarray(out, "RGBA")


COUNTER = (99, 249, 1791, 372)  # the counter on the stage: left, top, right, bottom (on the grid's lines)
COUNTER_TOP = 18  # its top's depth on the stage, then the front


def counter():
    """The counter, wood, lit from above: the top brighter, the front's planks each a step of
    their own, darker further down, a bright line along the top's edge (the bulbs' pools of
    light on it are the game's: pixel_light.gd)."""
    x0, y0, x1, y1 = COUNTER
    w, h = (x1 - x0) // GRID, (y1 - y0) // GRID
    top_rows = COUNTER_TOP // GRID
    base = np.zeros((h, w, 3), int)
    base[:top_rows] = palette.hexc("8a5a33")
    base[top_rows:] = palette.hexc("5c3820")
    yy, xx = np.mgrid[0:h, 0:w]
    plank = np.maximum(yy - top_rows - 1, 0) // 9  # (which plank: their lines every 9 rows)
    light = np.where(yy < top_rows, 0.95, 0.85 - 0.12 * plank)
    step = steps(light, yy, xx)
    step[0] = 5  # the top's front edge catching the light
    step[top_rows] = 1  # the shadow under the top's lip
    for row in range(top_rows + 9, h, 9):  # the front's planks
        step[row] = np.maximum(step[row] - 2, 0)
    return ramped(base, step, np.ones((h, w), bool))


def stool(colour):
    """A plastic stool (78 wide by 60, its seat a person's knee high): its round seat, lit on
    top, and its flared body in shadow under the seat, with the holes you carry it by."""
    w, h = 26, 20
    mask = np.zeros((h, w), bool)
    mask[0, 1:25] = True  # the seat, round at its ends
    mask[1:3, 0:26] = True
    for row in range(3, h):
        inset = 6 - (row - 3) * 5 // 16  # the body flares out towards the floor
        mask[row, inset:w - inset] = True
    base = np.zeros((h, w, 3), int)
    base[:] = palette.hexc(colour)
    yy, xx = np.mgrid[0:h, 0:w]
    light = np.where(yy < 3, 1.05, 0.68)
    step = steps(light, yy, xx)
    step[0] = 5  # the seat's top, lit
    step[3] = 1  # the shadow under the seat
    for hole in (7, 16):  # the carrying holes, either side
        mask[7:12, hole:hole + 3] = False
    mask[h - 1, 8:18] = False  # (its feet: the body's open at the bottom between them)
    return ramped(base, step, mask)


def steps(light, yy, xx, dither=0.0):
    """Each pixel's step on its ramp, from the light: clean steps (20 Nov: a 4x4 Bayer dither
    between them before, the C64 look, which clashed with the people's clean steps and the
    game's smooth light; dither > 0 brings it back, for a test)."""
    bayer = np.array([[0, 8, 2, 10], [12, 4, 14, 6], [3, 11, 1, 9], [15, 7, 13, 5]]) / 16.0 - 0.5
    t = np.interp(light, [0.15, 0.3, 0.45, 0.62, 0.85, 1.15, 1.5], range(7))
    return np.clip(np.floor(t + 0.5 + bayer[yy % 4, xx % 4] * dither), 0, 6).astype(int)


def ramped(base, step, mask):
    """Base colours and steps to an RGBA image in the palette's ramps."""
    h, w = mask.shape
    out = np.zeros((h, w, 4), np.uint8)
    for colour in {tuple(c) for c in base[mask]}:
        r = np.array(palette.ramp(colour))
        m = mask & np.all(base == colour, axis=-1)
        out[m, :3] = r[step[m]]
        out[m, 3] = 255
    return Image.fromarray(out, "RGBA")


if __name__ == "__main__":
    if len(sys.argv) > 2 and sys.argv[1] == "--preview":
        sheet = Image.new("RGBA", (STAGE_W // GRID, ROWS * 4 + 12), (28, 26, 50, 255))
        for k, (tarp, shape) in enumerate([("orange", "peaked"), ("blue_stripes", "awning"), ("red_stripes", "scalloped"), ("green", "rounded")]):
            img = lit(draw(tarp, shape))
            sheet.alpha_composite(img, (0, k * (ROWS + 4)))
        sheet.resize((sheet.width * 3, sheet.height * 3), Image.NEAREST).save(sys.argv[2])
        sys.exit(0)
    from pixelate import add_to_game
    n = 0
    for tarp in tarps():
        for shape in shapes():
            add_to_game(lit(draw(tarp, shape)), "tarp/%s_%s" % (tarp, shape), SOURCE, LICENCE)
            n += 1
    import fittings
    add_to_game(counter(), "tent/counter", SOURCE, LICENCE)
    for key, image in [("tent/fridge", fittings.fridge()), ("tent/odeng_pot", fittings.odeng_pot()), ("tent/stove", fittings.stove())]:
        add_to_game(image, key, SOURCE, LICENCE)
    for style, colours in sign_styles().items():
        add_to_game(fittings.sign(style, colours), "sign/" + style, SOURCE, LICENCE)
    for style in fittings.MENU_SIZES:
        add_to_game(fittings.menu_board(style), "menu/" + style, SOURCE, LICENCE)
    add_to_game(fittings.bulb(), "tent/bulb", SOURCE, LICENCE)
    add_to_game(fittings.neon_board(), "tent/neon_board", SOURCE, LICENCE)
    for touch, image in fittings.touches().items():
        add_to_game(image, "touch/" + touch, SOURCE, LICENCE)
    add_to_game(stool("c8443a"), "tent/stool_red", SOURCE, LICENCE)
    add_to_game(stool("3a6ec8"), "tent/stool_blue", SOURCE, LICENCE)
    print("%d tarps, the counter, stools, fittings, signs and touches drawn into art/" % n)
