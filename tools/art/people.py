"""The people's layers, drawn in code (ART.md, "People"): body (by clothes), head, hair (by
style), and extras, facing us ("front") and from behind seated ("back"), 27 x 50 pixels on the
grid. Each layer is drawn in shades only: every pixel says how lit it is (a step of 0 to 6) and
what it's made of (a slot: skin, hair, cloth, or one of the FIXED colours). The game paints
the layers onto each person's colours' ramps (scripts/ui/people_art.gd), so one bob serves
every hair colour and one coat every cloth colour.

A layer's pixels: red = step x 36, green = slot x 36, blue = the fixed colour's index x 8
(slot 0); alpha 255 where it's drawn.

    python3 tools/art/people.py            (all of them, into art/people/, the manifest and LICENSE-ASSETS)
    python3 tools/art/people.py --sheet out.png
"""
import os, re, sys
import numpy as np
from PIL import Image

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import palette

W, H = 27, 50
SKIN, HAIR, CLOTH, FIXED_SLOT = 1, 2, 3, 0
SOURCE = "drawn in code by tools/art/people.py"
LICENCE = "CC BY-SA 4.0 (this project)"
LEVELS = [0.15, 0.3, 0.45, 0.62, 0.85, 1.15, 1.5]  # light to step (as tent.py)


def fixed_colours():
    """The fixed colours, shared with the game (people_art.gd FIXED)."""
    text = open(os.path.join(palette.ROOT, "scripts/ui/people_art.gd"), encoding="utf-8").read()
    block = text[text.index("const FIXED"):text.index("]", text.index("const FIXED"))]
    return re.findall(r'"([0-9a-fA-F]{6})"', block)


def fixed(name):
    return {"trousers": 0, "ink": 1, "white_shirt": 2, "blue_shirt": 3, "tie": 4, "cream": 5, "gold": 6,
            "apron": 7, "strap": 8, "tote": 9, "backpack": 10, "hair_tie": 11, "briefcase": 12}[name]


class Layer:
    """A layer: each pixel's slot, fixed colour and light; rect() and dot() paint them."""

    def __init__(self, light=1.0, fall=0.15):
        self.slot = np.zeros((H, W), int)
        self.fix = np.zeros((H, W), int)
        self.mask = np.zeros((H, W), bool)
        self.light = light - fall * np.mgrid[0:H, 0:W][0] / (H - 1)

    def rect(self, x0, y0, x1, y1, what, light=None):
        """what: SKIN, HAIR, CLOTH, or a fixed colour's name."""
        x0, x1, y0, y1 = max(0, x0), min(W, x1), max(0, y0), min(H, y1)
        if x0 >= x1 or y0 >= y1:
            return
        if isinstance(what, str):
            self.slot[y0:y1, x0:x1] = FIXED_SLOT
            self.fix[y0:y1, x0:x1] = fixed(what)
        else:
            self.slot[y0:y1, x0:x1] = what
        self.mask[y0:y1, x0:x1] = True
        if light is not None:
            self.light[y0:y1, x0:x1] = light

    def dot(self, x, y, what, light=None):
        self.rect(x, y, x + 1, y + 1, what, light)

    def side_lit(self, x0, y0, x1, y1, what, base=1.0):
        """Lit from the upper left: its right side in shadow."""
        for x in range(x0, x1):
            self.rect(x, y0, x + 1, y1, what, base - 0.28 * (x - x0) / max(x1 - x0 - 1, 1))

    def ellipse(self, cx, cy, rx, ry, what, light=None, rows=None):
        for y in range(int(cy - ry) - 1, int(cy + ry) + 2):
            for x in range(int(cx - rx) - 1, int(cx + rx) + 2):
                if ((x + 0.5 - cx) / rx) ** 2 + ((y + 0.5 - cy) / ry) ** 2 <= 1.0 and (rows is None or rows[0] <= y < rows[1]):
                    self.dot(x, y, what, light if light is not None else 1.05 - 0.2 * (x - (cx - rx)) / (2 * rx))

    def image(self, down=0):
        """down: how many rows lower it's drawn (from behind, seated: SEATED_DOWN)."""
        if down:
            for a in ("slot", "fix", "mask", "light"):
                arr = getattr(self, a)
                moved = np.zeros_like(arr)
                moved[down:] = arr[:-down]
                setattr(self, a, moved)
        step = np.clip(np.floor(np.interp(self.light, LEVELS, range(7)) + 0.5), 0, 6).astype(int)
        out = np.zeros((H, W, 4), np.uint8)
        out[..., 0] = step * 36
        out[..., 1] = self.slot * 36
        out[..., 2] = self.fix * 8
        out[..., 3] = self.mask * 255
        out[~self.mask] = 0
        return Image.fromarray(out, "RGBA")


CX = 13.5
## Seated, someone's no taller than standing (they're the same size of person): from behind
## they're drawn this many rows lower, so they sit on the stool at the picture's foot with
## the standing figure's proportions (head, the torso to row 34, the seat and legs below).
SEATED_DOWN = 8
TOP = 14  # the shoulders' line
HEAD_Y = 1


def body(clothes, view):
    """The body in its clothes: legs (standing) or the seat (seated from behind), the torso and
    arms in the cloth, hands, and what's at the front (or back) of the clothes."""
    s = Layer()
    front = view == "front"
    if clothes == "hoodie" and not front:
        s.ellipse(CX, TOP - 1, 6.5, 3.5, CLOTH, 0.75)  # the hood, down behind the neck
    long_coat = clothes in ("trench", "padded")
    if front:
        hem = 42 if long_coat else 33
        s.side_lit(8, hem, 13, 48, "trousers", 0.85)
        s.side_lit(14, hem, 19, 48, "trousers", 0.8)
        s.rect(7, 48, 13, 50, "ink", 0.8)
        s.rect(14, 48, 20, 50, "ink", 0.75)
    else:  # sitting on the stool: the seat of the trousers, and the legs either side of it
        s.side_lit(4, 34, 23, 40, "trousers", 0.8)
        s.side_lit(3, 40, 7, 42, "trousers", 0.7)
        s.side_lit(20, 40, 24, 42, "trousers", 0.65)
    bottom = (42 if long_coat else 34) if front else 35
    shoulder = 3 if clothes == "padded" else 4
    s.side_lit(shoulder, TOP + 1, W - shoulder, bottom, CLOTH, 1.05)
    s.rect(shoulder + 1, TOP, W - shoulder - 1, TOP + 1, CLOTH, 1.1)
    c = int(CX)
    if front:
        s.side_lit(shoulder - 1, TOP + 2, shoulder + 2, bottom - 4, CLOTH, 0.8)  # arms
        s.side_lit(W - shoulder - 2, TOP + 2, W - shoulder + 1, bottom - 4, CLOTH, 0.7)
        if clothes == "tshirt":  # short sleeves
            s.rect(shoulder - 1, TOP + 8, shoulder + 2, bottom - 4, SKIN, 0.95)
            s.rect(W - shoulder - 2, TOP + 8, W - shoulder + 1, bottom - 4, SKIN, 0.8)
        s.rect(shoulder - 1, bottom - 4, shoulder + 2, bottom - 2, SKIN, 0.95)  # hands
        s.rect(W - shoulder - 2, bottom - 4, W - shoulder + 1, bottom - 2, SKIN, 0.8)
        if clothes in ("suit", "blazer"):
            for k in range(6):  # the shirt's V between the lapels
                s.rect(c - 3 + k // 2, TOP + 1 + k, c + 4 - k // 2, TOP + 2 + k, "white_shirt" if clothes == "suit" else "blue_shirt", 1.15)
            if clothes == "suit":
                s.rect(c, TOP + 2, c + 1, TOP + 10, "tie", 1.0)
            for y in (TOP + 12, TOP + 15):
                s.dot(c, y, "ink", 1.0)
        elif clothes == "cardigan":
            s.rect(c - 2, TOP + 1, c + 3, bottom, "cream", 1.1)
            for y in range(TOP + 4, bottom - 2, 4):
                s.dot(c + 3, y, "gold", 1.2)
        elif clothes == "trench":
            s.rect(c - 4, TOP, c - 1, TOP + 4, CLOTH, 1.25)
            s.rect(c + 2, TOP, c + 5, TOP + 4, CLOTH, 1.2)
            s.rect(shoulder, TOP + 16, W - shoulder, TOP + 18, CLOTH, 0.6)  # the belt
            s.rect(c, TOP + 4, c + 1, bottom, CLOTH, 0.7)
        elif clothes == "padded":
            for y in range(TOP + 4, bottom, 5):
                s.rect(shoulder, y, W - shoulder, y + 1, CLOTH, 0.6)  # the quilting
            s.rect(c - 4, TOP - 1, c + 5, TOP + 2, CLOTH, 1.15)  # the high collar
        elif clothes == "hoodie":
            s.rect(c - 5, TOP, c + 6, TOP + 3, CLOTH, 1.2)
            s.rect(c - 1, TOP + 3, c, TOP + 8, "white_shirt", 1.0)  # the strings
            s.rect(c + 1, TOP + 3, c + 2, TOP + 7, "white_shirt", 1.0)
            s.rect(c - 4, bottom - 8, c + 5, bottom - 4, CLOTH, 0.7)  # the pocket
        elif clothes == "knit":
            s.rect(shoulder, bottom - 2, W - shoulder, bottom, CLOTH, 0.7)
            s.rect(c - 3, TOP, c + 4, TOP + 1, CLOTH, 0.7)
        elif clothes == "scrubs":
            for k in range(4):  # the V-neck
                s.rect(c - 2 + k // 2, TOP + k, c + 3 - k // 2, TOP + 1 + k, SKIN, 0.85)
            s.rect(shoulder + 2, TOP + 6, shoulder + 6, TOP + 9, CLOTH, 0.75)  # the chest pocket
        elif clothes == "work_jacket":
            s.rect(c - 4, TOP, c + 5, TOP + 2, CLOTH, 1.2)  # the collar
            s.rect(c, TOP + 2, c + 1, bottom, "ink", 0.9)  # the zip
            s.rect(shoulder + 2, TOP + 9, shoulder + 7, TOP + 12, CLOTH, 0.7)  # pockets
            s.rect(W - shoulder - 7, TOP + 9, W - shoulder - 2, TOP + 12, CLOTH, 0.65)
            s.rect(shoulder, TOP + 14, W - shoulder, TOP + 15, "white_shirt", 1.0)  # its reflective band
        elif clothes == "tshirt":
            s.rect(c - 2, TOP, c + 3, TOP + 1, SKIN, 0.85)  # the round neck
    else:  # from behind
        if clothes in ("suit", "blazer", "trench"):
            s.rect(c, TOP + 6, c + 1, bottom, CLOTH, 0.75)  # the back seam
            s.rect(c - 3, TOP, c + 4, TOP + 1, CLOTH, 1.2)
            if clothes == "suit":
                s.rect(c - 3, TOP - 1, c + 4, TOP, "white_shirt", 1.1)  # the shirt collar
        elif clothes == "padded":
            for y in range(TOP + 4, bottom, 5):
                s.rect(shoulder, y, W - shoulder, y + 1, CLOTH, 0.6)
        elif clothes == "hoodie":
            s.ellipse(CX, TOP + 1, 6, 3, CLOTH, 0.95)
        elif clothes == "work_jacket":
            s.rect(shoulder, TOP + 14, W - shoulder, TOP + 15, "white_shirt", 1.0)
            s.rect(shoulder, TOP + 19, W - shoulder, TOP + 20, "white_shirt", 0.95)
        elif clothes == "knit":
            s.rect(shoulder, bottom - 2, W - shoulder, bottom, CLOTH, 0.7)
        s.side_lit(shoulder - 1, TOP + 2, shoulder + 2, bottom - 3, CLOTH, 0.8)  # arms, forward
        s.side_lit(W - shoulder - 2, TOP + 2, W - shoulder + 1, bottom - 3, CLOTH, 0.7)
    return s.image(SEATED_DOWN if view == "back" else 0)


def head(view, old=False):
    """The neck and head: facing us, the ears, eyes and a shadow of a mouth (and lines by the
    eyes, older); from behind, the ears and the back of the neck (the hair covers the rest)."""
    s = Layer()
    s.rect(11, HEAD_Y + 11, 16, TOP + 1, SKIN, 0.75)
    s.ellipse(CX, HEAD_Y + 6, 5.5, 6.5, SKIN)
    s.dot(8, HEAD_Y + 6, SKIN, 0.8)
    s.dot(19, HEAD_Y + 6, SKIN, 0.7)
    if view == "front":
        s.dot(11, HEAD_Y + 6, "ink", 1.0)
        s.dot(16, HEAD_Y + 6, "ink", 1.0)
        s.rect(12, HEAD_Y + 9, 16, HEAD_Y + 10, SKIN, 0.7)
        if old:
            s.dot(10, HEAD_Y + 8, SKIN, 0.8)
            s.dot(17, HEAD_Y + 8, SKIN, 0.8)
    return s.image(SEATED_DOWN if view == "back" else 0)


def hair(style, view, behind=False):
    """The hair, on the head (or, behind=True, what hangs behind the body: long hair)."""
    s = Layer()
    y = HEAD_Y
    if behind:
        if style == "long":
            s.rect(7, 4, 20, 24 if view == "back" else 22, HAIR, 0.85)
        return s.image(SEATED_DOWN if view == "back" else 0)
    if view == "front":
        rows = {"long": 5, "bob": 5, "ponytail": 4, "bun": 4, "pixie": 4, "perm": 5, "short": 4, "side_part": 4,
                "buzz": 3, "two_block": 6, "balding": 0}[style]
        if style == "perm":
            for k, x in enumerate(range(7, 21, 2)):  # tight curls, a bumpy crown
                s.ellipse(x + 1, y + 2 + (k % 2), 1.8, 2.2, HAIR)
            s.ellipse(8, y + 6, 1.5, 2.5, HAIR)
            s.ellipse(19, y + 6, 1.5, 2.5, HAIR)
        elif style == "balding":
            s.rect(7, y + 4, 9, y + 8, HAIR, 0.9)
            s.rect(18, y + 4, 20, y + 8, HAIR, 0.8)
        else:
            s.ellipse(CX, y + 4, 6, 4.5 if style != "buzz" else 4, HAIR, rows=(0, y + rows + 1))
            if style in ("long", "bob"):
                s.rect(7, y + 3, 9, y + (14 if style == "long" else 10), HAIR, 0.9)
                s.rect(18, y + 3, 20, y + (14 if style == "long" else 10), HAIR, 0.8)
            if style == "side_part":
                s.rect(10, y + 1, 11, y + 3, HAIR, 1.25)
            if style == "two_block":
                s.rect(9, y + 4, 17, y + 6, HAIR, 0.95)
            if style == "bun":
                s.ellipse(CX, y - 1.5, 2.5, 2, HAIR)
            if style == "ponytail":
                s.rect(20, y + 4, 22, y + 11, HAIR, 0.8)
            if style == "pixie":
                s.rect(8, y + 4, 10, y + 7, HAIR, 0.9)  # a wisp by the ear
    else:
        if style == "balding":
            s.rect(8, y + 7, 20, y + 11, HAIR, 0.85)
            s.rect(8, y + 5, 10, y + 7, HAIR, 0.8)
            s.rect(18, y + 5, 20, y + 7, HAIR, 0.75)
        elif style == "perm":
            for k, x in enumerate(range(7, 21, 2)):
                for yy in (y + 2, y + 5, y + 8):
                    s.ellipse(x + 1, yy + (k % 2), 1.8, 2, HAIR)
        else:
            reach = {"long": 22, "bob": 11, "buzz": 9, "pixie": 10, "two_block": 9}.get(style, 10)
            s.ellipse(CX, y + 6, 6, 6.5, HAIR, rows=(0, y + min(reach, 12)))
            if style == "long":
                s.rect(8, y + 10, 20, y + reach, HAIR, 0.85)
            if style == "ponytail":
                s.rect(12, y + 9, 15, y + 17, HAIR, 0.85)
                s.rect(12, y + 8, 15, y + 9, "hair_tie", 1.0)
            if style == "bun":
                s.ellipse(CX, y + 2, 3, 2.5, HAIR, 1.1)
            if style == "two_block":
                s.rect(9, y + 9, 18, y + 11, SKIN, 0.8)  # the shaved underneath
    return s.image(SEATED_DOWN if view == "back" else 0)


def extra(name, view):
    """glasses, the apron, a tote, a briefcase, a backpack (its straps facing us)."""
    s = Layer()
    c = int(CX)
    if name == "glasses" and view == "front":
        for gx in (10, 15):
            s.rect(gx, HEAD_Y + 5, gx + 3, HEAD_Y + 6, "ink", 0.9)
            s.dot(gx, HEAD_Y + 6, "ink", 0.9)
            s.dot(gx + 2, HEAD_Y + 6, "ink", 0.9)
        s.dot(13, HEAD_Y + 5, "ink", 0.9)
    elif name == "apron":
        if view == "front":
            s.rect(7, TOP + 4, 20, 38, "apron", 1.15)
            s.rect(8, TOP, 9, TOP + 4, "apron", 1.1)
            s.rect(18, TOP, 19, TOP + 4, "apron", 1.0)
            s.rect(10, TOP + 12, 17, TOP + 15, "apron", 0.85)
        else:
            s.rect(4, TOP + 18, 23, TOP + 19, "apron", 1.0)  # its strings, tied behind
            s.rect(c - 1, TOP + 18, c + 2, TOP + 22, "apron", 0.95)
    elif name == "tote" and view == "front":
        s.rect(W - 5, TOP + 1, W - 4, TOP + 12, "strap", 0.9)
        s.rect(W - 6, TOP + 12, W - 1, TOP + 20, "tote", 0.95)
    elif name == "briefcase" and view == "front":
        s.rect(W - 4, 30, W - 3, 32, "ink", 0.9)  # its handle, in the hand
        s.rect(W - 6, 32, W, 39, "briefcase", 0.9)
    elif name == "backpack":
        if view == "back":
            s.side_lit(8, TOP + 3, 19, TOP + 16, "backpack", 0.9)
            s.rect(8, TOP + 3, 19, TOP + 4, "backpack", 1.1)
        else:
            s.rect(6, TOP, 8, TOP + 14, "backpack", 0.8)  # the straps over the shoulders
            s.rect(19, TOP, 21, TOP + 14, "backpack", 0.75)
    return s.image(SEATED_DOWN if view == "back" else 0)


def layers():
    """Every layer: {id: image}, ids "<view>_<part>" (people_art.gd builds a person from them)."""
    out = {}
    clothes = ["suit", "blazer", "trench", "padded", "hoodie", "cardigan", "scrubs", "work_jacket", "tshirt", "knit"]
    styles = ["long", "bob", "ponytail", "bun", "pixie", "perm", "short", "side_part", "buzz", "two_block", "balding"]
    for view in ("front", "back"):
        for kind in clothes:
            out["%s_body_%s" % (view, kind)] = body(kind, view)
        out["%s_head" % view] = head(view)
        for style in styles:
            out["%s_hair_%s" % (view, style)] = hair(style, view)
        out["%s_hairback_long" % view] = hair("long", view, behind=True)
        for name in ("apron", "backpack"):
            out["%s_%s" % (view, name)] = extra(name, view)
    out["front_head_old"] = head("front", old=True)
    for name in ("glasses", "tote", "briefcase"):
        out["front_%s" % name] = extra(name, "front")
    return out


if __name__ == "__main__":
    if len(sys.argv) > 2 and sys.argv[1] == "--sheet":
        # (a quick look at the layers' shades: step as grey)
        all_layers = layers()
        sheet = Image.new("L", (len(all_layers) * (W + 2), H), 40)
        for k, img in enumerate(all_layers.values()):
            a = np.asarray(img)
            g = np.where(a[..., 3] > 0, 60 + a[..., 0], 40).astype(np.uint8)
            sheet.paste(Image.fromarray(g, "L"), (k * (W + 2), 0))
        sheet.resize((sheet.width * 3, sheet.height * 3), Image.NEAREST).save(sys.argv[2])
        sys.exit(0)
    from pixelate import add_to_game
    for ident, image in layers().items():
        add_to_game(image, "person/" + ident, SOURCE, LICENCE)
    print("%d people's layers drawn into art/people/" % len(layers()))
