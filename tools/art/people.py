"""The people's layers, drawn in code (ART.md, "People"): body (by clothes), head, hair (by
style), and extras, facing us ("front") and from behind seated ("back"), 32 x 72 pixels on the
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

W, H = 32, 72
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
            "apron": 7, "strap": 8, "tote": 9, "backpack": 10, "hair_tie": 11, "briefcase": 12, "bottle": 13,
            "tear": 14, "blush": 15}[name]  # (the last two: the reaction faces', portraits.py)


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

    def rounded(self, x0, y0, x1, y1, what, base=0.97):
        """Lit from above (the bulbs hang over the counter): even across, only its edge columns
        turning away into shadow, the same either side, so nobody's lit from one side."""
        mid, half = (x0 + x1) / 2, max((x1 - x0) / 2, 1)
        for x in range(x0, x1):
            self.rect(x, y0, x + 1, y1, what, base - 0.25 * (abs(x + 0.5 - mid) / half) ** 4)

    def ellipse(self, cx, cy, rx, ry, what, light=None, rows=None):
        for y in range(int(cy - ry) - 1, int(cy + ry) + 2):
            for x in range(int(cx - rx) - 1, int(cx + rx) + 2):
                if ((x + 0.5 - cx) / rx) ** 2 + ((y + 0.5 - cy) / ry) ** 2 <= 1.0 and (rows is None or rows[0] <= y < rows[1]):
                    self.dot(x, y, what, light if light is not None else top_lit(x, y, cx, cy, rx, ry))

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


def top_lit(x, y, cx, cy, rx, ry):
    """A round thing's light, lit from above: a touch darker lower down, and its rim either side
    turning into shadow (the same both sides: 20 Nov, it was lit from the upper left, and with
    the ramp's few steps that drew a hard bright stripe down the left of every head)."""
    return 0.97 - 0.32 * (abs(x + 0.5 - cx) / rx) ** 3 - 0.08 * (y + 0.5 - (cy - ry)) / (2 * ry)


CX = 16.0
## A person's height, against the tent (a pocha's counter's about a metre: 123 on the stage):
## standing, 72 rows (216 on the stage, from the root's top at the ground's 372 less that).
## Seated on a stool (its seat at 312 on the stage: 52 rows down), from behind, the same person:
## drawn SEATED_DOWN rows lower with the standing figure's proportions (the head, the torso to
## the waist, the seat on the stool), their lower legs down either side of it. So nobody's
## smaller sitting or standing, and coming in, sitting down and leaving they stay on the ground.
SEATED_DOWN = 2
TOP = 20  # the shoulders' line
HEAD_Y = 1
WAIST = 44  # the torso's foot (a short top's hem; long coats go on down)
COAT_HEM = 60
SHOULDER = 5  # the shoulders' inset from the picture's sides


def body(clothes, view):
    """The body in its clothes: legs (standing) or the seat and lower legs (seated from behind),
    the torso and arms in the cloth, hands, and what's at the front (or back) of the clothes."""
    s = Layer()
    front = view == "front"
    c = int(CX)
    long_coat = clothes in ("trench", "padded")
    if clothes == "hoodie" and not front:
        s.ellipse(CX, TOP - 1, 7.5, 4, CLOTH, 0.75)  # the hood, down behind the neck
    if front:
        hem = COAT_HEM if long_coat else WAIST
        s.rounded(10, hem, 15, 68, "trousers", 0.85)
        s.rounded(17, hem, 22, 68, "trousers", 0.85)
        s.rect(9, 68, 15, 72, "ink", 0.78)  # shoes
        s.rect(17, 68, 23, 72, "ink", 0.78)
    else:  # seated: the seat of the trousers on the stool; their legs are forward, under the
        # counter, out of sight (20 Nov: drawn down either side of the stool, they were over it)
        s.rounded(5, WAIST, 27, WAIST + 6, "trousers", 0.8)
    bottom = (COAT_HEM if long_coat else WAIST) if front else WAIST + 1
    shoulder = SHOULDER - 1 if clothes == "padded" else SHOULDER
    s.rounded(shoulder, TOP + 1, W - shoulder, bottom, CLOTH)
    s.rect(shoulder + 1, TOP, W - shoulder - 1, TOP + 1, CLOTH, 1.1)
    arm_end = WAIST + 2
    if front:
        s.rounded(shoulder - 2, TOP + 2, shoulder + 2, arm_end - 4, CLOTH, 0.72)  # arms
        s.rounded(W - shoulder - 2, TOP + 2, W - shoulder + 2, arm_end - 4, CLOTH, 0.72)
        if clothes == "tshirt":  # short sleeves
            s.rect(shoulder - 2, TOP + 10, shoulder + 2, arm_end - 4, SKIN, 0.88)
            s.rect(W - shoulder - 2, TOP + 10, W - shoulder + 2, arm_end - 4, SKIN, 0.88)
        s.rect(shoulder - 2, arm_end - 4, shoulder + 2, arm_end, SKIN, 0.88)  # hands
        s.rect(W - shoulder - 2, arm_end - 4, W - shoulder + 2, arm_end, SKIN, 0.88)
        if clothes in ("suit", "blazer"):
            for k in range(9):  # the shirt's V between the lapels
                s.rect(c - 4 + k // 2, TOP + 1 + k, c + 4 - k // 2, TOP + 2 + k, "white_shirt" if clothes == "suit" else "blue_shirt", 1.15)
            for k in range(10):  # the lapels
                s.dot(c - 5 + k // 2, TOP + 1 + k, CLOTH, 0.68)
                s.dot(c + 4 - k // 2, TOP + 1 + k, CLOTH, 0.68)
            if clothes == "suit":
                s.rect(c - 1, TOP + 2, c + 1, TOP + 14, "tie", 1.0)
            for y in (TOP + 15, TOP + 19):
                s.dot(c, y, "ink", 1.0)
        elif clothes == "cardigan":
            s.rect(c - 3, TOP + 1, c + 3, bottom, "cream", 1.1)
            for y in range(TOP + 5, bottom - 2, 5):
                s.dot(c + 3, y, "gold", 1.2)
        elif clothes == "trench":
            s.rect(c - 6, TOP, c - 1, TOP + 6, CLOTH, 1.22)  # the collar
            s.rect(c + 1, TOP, c + 6, TOP + 6, CLOTH, 1.22)
            s.rect(shoulder, TOP + 21, W - shoulder, TOP + 24, CLOTH, 0.6)  # the belt
            s.dot(c, TOP + 22, "gold", 1.1)  # its buckle
            s.rect(c, TOP + 6, c + 1, bottom, CLOTH, 0.7)
        elif clothes == "padded":
            for y in range(TOP + 5, bottom, 6):
                s.rect(shoulder, y, W - shoulder, y + 1, CLOTH, 0.6)  # the quilting
            s.rect(c - 5, TOP - 2, c + 5, TOP + 3, CLOTH, 1.15)  # the high collar
            s.rect(c, TOP + 3, c + 1, bottom, CLOTH, 0.7)  # the zip
        elif clothes == "hoodie":
            s.rect(c - 7, TOP, c + 7, TOP + 4, CLOTH, 1.2)
            s.rect(c - 2, TOP + 4, c - 1, TOP + 11, "white_shirt", 1.0)  # the strings
            s.rect(c + 1, TOP + 4, c + 2, TOP + 10, "white_shirt", 1.0)
            s.rect(c - 6, bottom - 11, c + 6, bottom - 5, CLOTH, 0.7)  # the pocket
        elif clothes == "knit":
            s.rect(shoulder, bottom - 3, W - shoulder, bottom, CLOTH, 0.7)
            s.rect(c - 4, TOP, c + 4, TOP + 2, CLOTH, 0.7)
            for x in range(shoulder + 2, W - shoulder - 1, 4):
                s.rect(x, TOP + 4, x + 1, bottom - 3, CLOTH, 0.9)  # the cable's lines
        elif clothes == "scrubs":
            for k in range(6):  # the V-neck
                s.rect(c - 3 + k // 2, TOP + k, c + 3 - k // 2, TOP + 1 + k, SKIN, 0.85)
            s.rect(shoulder + 2, TOP + 8, shoulder + 7, TOP + 12, CLOTH, 0.75)  # the chest pocket
        elif clothes == "work_jacket":
            s.rect(c - 5, TOP, c + 5, TOP + 3, CLOTH, 1.2)  # the collar
            s.rect(c, TOP + 3, c + 1, bottom, "ink", 0.9)  # the zip
            s.rect(shoulder + 2, TOP + 12, shoulder + 8, TOP + 16, CLOTH, 0.68)  # pockets
            s.rect(W - shoulder - 8, TOP + 12, W - shoulder - 2, TOP + 16, CLOTH, 0.68)
            s.rect(shoulder, TOP + 19, W - shoulder, TOP + 20, "white_shirt", 1.0)  # its reflective band
        elif clothes == "tshirt":
            s.rect(c - 3, TOP, c + 3, TOP + 2, SKIN, 0.85)  # the round neck
    else:  # from behind
        if clothes in ("suit", "blazer", "trench"):
            s.rect(c, TOP + 8, c + 1, bottom, CLOTH, 0.75)  # the back seam
            s.rect(c - 4, TOP, c + 4, TOP + 2, CLOTH, 1.2)
            if clothes == "suit":
                s.rect(c - 4, TOP - 1, c + 4, TOP, "white_shirt", 1.1)  # the shirt collar
            if clothes == "trench":
                s.rect(shoulder, TOP + 21, W - shoulder, TOP + 24, CLOTH, 0.6)
        elif clothes == "padded":
            for y in range(TOP + 5, bottom, 6):
                s.rect(shoulder, y, W - shoulder, y + 1, CLOTH, 0.6)
            s.rect(c - 5, TOP - 2, c + 5, TOP + 2, CLOTH, 1.1)
        elif clothes == "hoodie":
            s.ellipse(CX, TOP + 2, 7, 4, CLOTH, 0.95)
        elif clothes == "work_jacket":
            s.rect(shoulder, TOP + 19, W - shoulder, TOP + 20, "white_shirt", 1.0)
            s.rect(shoulder, TOP + 13, W - shoulder, TOP + 14, "white_shirt", 0.95)
        elif clothes == "knit":
            s.rect(shoulder, bottom - 3, W - shoulder, bottom, CLOTH, 0.7)
        s.rounded(shoulder - 2, TOP + 2, shoulder + 2, bottom - 4, CLOTH, 0.72)  # arms, forward to the counter
        s.rounded(W - shoulder - 2, TOP + 2, W - shoulder + 2, bottom - 4, CLOTH, 0.72)
    return s.image(SEATED_DOWN if view == "back" else 0)


def head(view, old=False):
    """The neck and head: facing us, the ears, eyes, brows and a mouth (and lines by the eyes,
    older); from behind, the ears and the back of the neck (the hair covers the rest)."""
    s = Layer()
    y = HEAD_Y
    s.rect(13, y + 14, 19, TOP + 1, SKIN, 0.75)  # the neck
    s.ellipse(CX, y + 8, 6.5, 8, SKIN)
    s.rect(9, y + 7, 10, y + 11, SKIN, 0.78)  # ears
    s.rect(22, y + 7, 23, y + 11, SKIN, 0.78)
    if view == "front":
        for ex in (12, 19):
            s.dot(ex, y + 9, "ink", 1.0)  # eyes
            s.dot(ex + 1, y + 9, "ink", 1.0)
            s.rect(ex, y + 7, ex + 2, y + 8, SKIN, 0.75)  # brows' shadow
        s.dot(16, y + 11, SKIN, 0.75)  # the nose's shadow
        s.rect(14, y + 13, 18, y + 14, SKIN, 0.68)  # the mouth
        if old:
            s.dot(11, y + 11, SKIN, 0.8)  # lines by the eyes
            s.dot(21, y + 11, SKIN, 0.8)
            s.rect(13, y + 15, 19, y + 16, SKIN, 0.82)  # and under the chin
    return s.image(SEATED_DOWN if view == "back" else 0)


def hair(style, view, behind=False):
    """The hair, on the head (or, behind=True, what hangs behind the body: long hair)."""
    s = Layer()
    y = HEAD_Y
    if behind:
        if style == "long":
            s.rect(8, y + 5, 24, y + (34 if view == "back" else 30), HAIR, 0.85)
        return s.image(SEATED_DOWN if view == "back" else 0)
    if view == "front":
        crown = {"long": 7, "bob": 7, "ponytail": 6, "bun": 6, "pixie": 6, "perm": 7, "short": 6, "side_part": 6,
                 "buzz": 4, "two_block": 8, "balding": 0}[style]
        if style == "perm":
            for k, x in enumerate(range(8, 25, 2)):  # tight curls, a bumpy crown
                s.ellipse(x + 1, y + 3 + (k % 2), 2, 2.5, HAIR)
            s.ellipse(9, y + 8, 1.8, 3, HAIR)
            s.ellipse(23, y + 8, 1.8, 3, HAIR)
        elif style == "balding":
            s.rect(8, y + 5, 10, y + 11, HAIR, 0.85)
            s.rect(22, y + 5, 24, y + 11, HAIR, 0.85)
        else:
            s.ellipse(CX, y + 5, 7, 5.5 if style != "buzz" else 5, HAIR, rows=(0, y + crown + 1))
            if style in ("long", "bob"):
                s.rect(8, y + 4, 10, y + (22 if style == "long" else 14), HAIR, 0.85)  # down the sides
                s.rect(22, y + 4, 24, y + (22 if style == "long" else 14), HAIR, 0.85)
            if style == "side_part":
                s.rect(12, y + 1, 13, y + 4, HAIR, 1.25)  # the parting's shine
                s.rect(9, y + 5, 15, y + 7, HAIR, 0.95)
            if style == "two_block":
                s.rect(10, y + 5, 21, y + 8, HAIR, 0.95)  # the long fringe
            if style == "bun":
                s.ellipse(CX, y - 1, 3, 2.5, HAIR)
            if style == "ponytail":
                s.rect(23, y + 5, 26, y + 15, HAIR, 0.8)
            if style == "pixie":
                s.rect(9, y + 5, 11, y + 9, HAIR, 0.9)  # a wisp by the ear
            if style == "short":
                s.rect(9, y + 5, 10, y + 8, HAIR, 0.82)
                s.rect(22, y + 5, 23, y + 8, HAIR, 0.82)
    else:
        if style == "balding":
            s.rect(9, y + 9, 23, y + 14, HAIR, 0.85)  # what's left, low round the back
            s.rect(9, y + 6, 11, y + 9, HAIR, 0.78)
            s.rect(21, y + 6, 23, y + 9, HAIR, 0.78)
        elif style == "perm":
            for k, x in enumerate(range(8, 25, 2)):
                for yy in (y + 3, y + 7, y + 11):
                    s.ellipse(x + 1, yy + (k % 2), 2, 2.2, HAIR)
        else:
            reach = {"long": 30, "bob": 15, "buzz": 12, "pixie": 13, "two_block": 12}.get(style, 13)
            s.ellipse(CX, y + 8, 7, 8, HAIR, rows=(0, y + min(reach, 16)))
            if style == "long":
                s.rect(9, y + 13, 23, y + reach, HAIR, 0.85)
            if style == "ponytail":
                s.rect(14, y + 12, 18, y + 24, HAIR, 0.85)
                s.rect(14, y + 11, 18, y + 12, "hair_tie", 1.0)
            if style == "bun":
                s.ellipse(CX, y + 3, 3.5, 3, HAIR, 1.1)
            if style == "two_block":
                s.rect(10, y + 12, 22, y + 15, SKIN, 0.8)  # the shaved underneath
    return s.image(SEATED_DOWN if view == "back" else 0)


def extra(name, view):
    """glasses, the apron, a tote, a briefcase, a backpack (its straps facing us)."""
    s = Layer()
    c = int(CX)
    y = HEAD_Y
    if name == "glasses" and view == "front":
        for gx in (11, 18):
            s.rect(gx, y + 8, gx + 4, y + 9, "ink", 0.9)
            s.rect(gx, y + 9, gx + 1, y + 11, "ink", 0.9)
            s.rect(gx + 3, y + 9, gx + 4, y + 11, "ink", 0.9)
            s.rect(gx, y + 10, gx + 4, y + 11, "ink", 0.85)
        s.rect(15, y + 8, 18, y + 9, "ink", 0.9)
    elif name == "apron":
        if view == "front":
            s.rect(8, TOP + 5, 24, 56, "apron", 1.15)
            s.rect(9, TOP, 10, TOP + 5, "apron", 1.08)  # its straps
            s.rect(22, TOP, 23, TOP + 5, "apron", 1.08)
            s.rect(11, TOP + 16, 21, TOP + 21, "apron", 0.85)  # its pocket
        else:
            s.rect(SHOULDER, WAIST - 4, W - SHOULDER, WAIST - 3, "apron", 1.0)  # its strings, tied behind
            s.rect(c - 1, WAIST - 4, c + 2, WAIST + 1, "apron", 0.95)
    elif name == "tote" and view == "front":
        s.rect(W - 6, TOP + 1, W - 5, TOP + 16, "strap", 0.9)
        s.rect(W - 8, TOP + 16, W - 1, TOP + 27, "tote", 0.95)
    elif name == "briefcase" and view == "front":
        s.rect(W - 4, WAIST - 1, W - 3, WAIST + 2, "ink", 0.9)  # its handle, in the hand
        s.rect(W - 7, WAIST + 2, W, WAIST + 11, "briefcase", 0.9)
    elif name == "backpack":
        if view == "back":
            s.rounded(9, TOP + 3, 23, TOP + 21, "backpack", 0.9)
            s.rect(9, TOP + 3, 23, TOP + 4, "backpack", 1.1)
            s.rect(11, TOP + 12, 21, TOP + 13, "backpack", 0.7)  # its pocket's seam
        else:
            s.rect(7, TOP, 9, TOP + 18, "backpack", 0.78)  # the straps over the shoulders
            s.rect(23, TOP, 25, TOP + 18, "backpack", 0.78)
    return s.image(SEATED_DOWN if view == "back" else 0)


# --- From the side, walking (facing right; the game mirrors them to walk left) -------------
# Four frames of a stride: 0 the near leg forward, the far arm forward; 1 passing (the far foot
# lifted); 2 the far leg forward; 3 passing (the near foot lifted). The legs and arms are layers
# of their own, by frame; the body, head, hair and extras are the same in every frame.
SIDE_X = 16  # the body's middle
HIP = (16, WAIST)
SHOULDER_AT = (16, TOP + 2)
FEET = {0: ((22, 0), (9, 0)), 1: ((16, 0), (13, 3)), 2: ((10, 0), (21, 0)), 3: ((13, 3), (16, 0))}  # (near, far): x, lift
HANDS = {0: ((11, WAIST), (21, WAIST - 1)), 1: ((15, WAIST + 1), (17, WAIST + 1)), 2: ((21, WAIST - 1), (11, WAIST)),
         3: ((17, WAIST + 1), (15, WAIST + 1))}  # (near, far): where the hand swings to


def _strip(s, top, bottom, width, what, light):
    """A limb: from top (x, y) to bottom (x, y), width wide, row by row."""
    (x0, y0), (x1, y1) = top, bottom
    for y in range(y0, y1):
        t = (y - y0) / max(y1 - y0, 1)
        x = x0 + (x1 - x0) * t
        s.rect(int(round(x - width / 2)), y, int(round(x + width / 2)), y + 1, what, light)


def side_legs(frame):
    s = Layer()
    for (fx, lift), light in reversed(list(zip(FEET[frame], (0.85, 0.62)))):
        foot_y = 68 - lift
        _strip(s, HIP, (fx, foot_y), 5, "trousers", light)
        s.rect(fx - 3, foot_y, fx + 4, foot_y + 3, "ink", light - 0.05)  # the shoe, its toe forward
    return s.image()


def side_arm(frame, near, bare=False):
    """An arm swinging (near: in front of the body; far: behind it, in shadow), the sleeve in the
    cloth (or bare, a T-shirt's) and the hand."""
    s = Layer()
    hand = HANDS[frame][0 if near else 1]
    light = 0.9 if near else 0.6
    elbow = ((SHOULDER_AT[0] + hand[0]) / 2, (SHOULDER_AT[1] + hand[1]) / 2)
    _strip(s, SHOULDER_AT, (int(elbow[0]), int(elbow[1])), 4, CLOTH, light)
    _strip(s, (int(elbow[0]), int(elbow[1])), (hand[0], hand[1] - 3), 4 if not bare else 3, SKIN if bare else CLOTH, light - 0.05)
    s.rect(hand[0] - 2, hand[1] - 3, hand[0] + 2, hand[1], SKIN, light + 0.05)
    return s.image()


def side_body(clothes):
    """The torso from the side, in its clothes: its back at the left, its front at the right."""
    s = Layer()
    long_coat = clothes in ("trench", "padded")
    bottom = COAT_HEM if long_coat else WAIST + 1
    back, front = (10, 23) if clothes == "padded" else (11, 22)
    if clothes == "hoodie":
        s.ellipse(12, TOP, 3.5, 3, CLOTH, 0.8)  # the hood, at the back of the neck
    for x in range(back, front):
        s.rect(x, TOP + 1, x + 1, bottom, CLOTH, 1.05 - 0.3 * (front - 1 - x) / (front - back))  # lit from the front (the tent's side)
    s.rect(back + 1, TOP, front - 1, TOP + 1, CLOTH, 1.1)  # the shoulder
    if clothes in ("suit", "blazer"):
        s.rect(front - 3, TOP + 1, front, TOP + 8, "white_shirt" if clothes == "suit" else "blue_shirt", 1.15)
        s.rect(front - 4, TOP + 1, front - 3, TOP + 10, CLOTH, 0.7)  # the lapel
        if clothes == "suit":
            s.rect(front - 1, TOP + 2, front, TOP + 13, "tie", 1.0)
    elif clothes == "cardigan":
        s.rect(front - 2, TOP + 1, front, bottom, "cream", 1.1)
    elif clothes == "trench":
        s.rect(front - 5, TOP, front, TOP + 4, CLOTH, 1.25)  # the collar
        s.rect(back, TOP + 21, front, TOP + 24, CLOTH, 0.6)  # the belt
    elif clothes == "padded":
        for y in range(TOP + 5, bottom, 6):
            s.rect(back, y, front, y + 1, CLOTH, 0.6)
        s.rect(back + 2, TOP - 2, front - 1, TOP + 2, CLOTH, 1.1)  # the high collar
    elif clothes == "hoodie":
        s.rect(front - 6, WAIST - 10, front, WAIST - 5, CLOTH, 0.7)  # the pocket
        s.rect(front - 2, TOP + 2, front - 1, TOP + 9, "white_shirt", 1.0)  # a string
    elif clothes == "knit":
        s.rect(back, bottom - 3, front, bottom, CLOTH, 0.7)
    elif clothes == "scrubs":
        s.rect(front - 5, TOP + 8, front - 1, TOP + 12, CLOTH, 0.75)
    elif clothes == "work_jacket":
        s.rect(back, TOP + 19, front, TOP + 20, "white_shirt", 1.0)
        s.rect(front - 5, TOP, front, TOP + 3, CLOTH, 1.2)
    elif clothes == "tshirt":
        s.rect(front - 3, TOP, front, TOP + 1, SKIN, 0.85)
    return s.image()


def side_head(old=False):
    """The head in profile, facing right: the neck, the ear, the eye, the nose and the mouth."""
    s = Layer()
    y = HEAD_Y
    s.rect(13, y + 14, 19, TOP + 1, SKIN, 0.8)  # the neck
    s.ellipse(16, y + 8, 6, 8, SKIN, None)
    s.rect(22, y + 8, 23, y + 11, SKIN, 1.0)  # the nose
    s.dot(23, y + 10, SKIN, 0.9)
    s.dot(19, y + 8, "ink", 1.0)  # the eye
    s.rect(19, y + 6, 22, y + 7, SKIN, 0.75)  # the brow
    s.rect(19, y + 13, 22, y + 14, SKIN, 0.7)  # the mouth
    s.rect(13, y + 8, 15, y + 12, SKIN, 0.75)  # the ear
    if old:
        s.dot(18, y + 11, SKIN, 0.8)
        s.rect(17, y + 15, 21, y + 16, SKIN, 0.82)
    return s.image()


def side_hair(style):
    s = Layer()
    y = HEAD_Y
    def cap(front_x, low_back, crown_rows):
        s.ellipse(15.5, y + 6, 6.5, 6, HAIR, rows=(0, y + crown_rows))  # over the top
        s.rect(10, y + 4, 14, y + low_back, HAIR, 0.85)  # down the back of the head
        s.rect(14, y + 1, front_x, y + 4, HAIR, 1.0)
    if style == "balding":
        s.rect(10, y + 8, 14, y + 13, HAIR, 0.85)
        s.rect(13, y + 6, 15, y + 8, HAIR, 0.8)
    elif style == "perm":
        for x in range(10, 22, 2):
            for yy in (y + 2, y + 5):
                s.ellipse(x + 1, yy + (x // 2) % 2, 2, 2.2, HAIR)
        for yy in (y + 8, y + 11):
            s.ellipse(11, yy, 2, 2.2, HAIR)
    elif style == "buzz":
        s.ellipse(15.5, y + 6, 6.5, 5.5, HAIR, 0.9, rows=(0, y + 4))
        s.rect(10, y + 4, 13, y + 10, HAIR, 0.85)
    else:
        cap(21, {"long": 13, "bob": 15, "ponytail": 12, "bun": 12, "pixie": 11, "short": 11, "side_part": 11, "two_block": 9}[style], 7)
        if style == "long":
            s.rect(8, y + 8, 13, y + 32, HAIR, 0.85)  # down the back
        if style == "bob":
            s.rect(9, y + 8, 14, y + 16, HAIR, 0.85)
            s.rect(18, y + 3, 22, y + 6, HAIR, 0.95)  # the fringe
        if style == "ponytail":
            s.rect(7, y + 6, 10, y + 18, HAIR, 0.85)
            s.rect(9, y + 6, 11, y + 8, "hair_tie", 1.0)
        if style == "bun":
            s.ellipse(9.5, y + 5, 2.8, 2.8, HAIR, 1.0)
        if style == "two_block":
            s.rect(17, y + 3, 23, y + 7, HAIR, 0.95)  # the long fringe, forward
            s.rect(10, y + 9, 14, y + 13, SKIN, 0.8)  # the shaved underneath
        if style == "side_part":
            s.rect(15, y + 1, 18, y + 2, HAIR, 1.25)
        if style == "pixie":
            s.rect(19, y + 3, 22, y + 5, HAIR, 0.95)
    return s.image()


def side_extra(name):
    s = Layer()
    y = HEAD_Y
    if name == "glasses":
        s.rect(18, y + 7, 22, y + 8, "ink", 0.9)
        s.rect(18, y + 7, 19, y + 11, "ink", 0.9)
        s.rect(21, y + 7, 22, y + 11, "ink", 0.9)
        s.rect(18, y + 10, 22, y + 11, "ink", 0.85)
        s.rect(14, y + 8, 18, y + 9, "ink", 0.8)  # the arm back to the ear
    elif name == "apron":
        s.rect(20, TOP + 5, 23, 56, "apron", 1.15)  # over the front
        s.rect(11, WAIST - 4, 21, WAIST - 3, "apron", 1.0)  # its string round the waist
        s.rect(9, WAIST - 4, 11, WAIST + 2, "apron", 0.95)  # tied at the back
    elif name == "tote":
        s.rect(13, TOP + 1, 15, TOP + 14, "strap", 0.9)
        s.rect(11, TOP + 14, 18, TOP + 26, "tote", 0.95)  # at the hip
    elif name == "backpack":
        s.rounded(5, TOP + 2, 12, TOP + 20, "backpack", 0.9)
        s.rect(11, TOP + 1, 13, TOP + 4, "backpack", 0.8)  # its strap over the shoulder
    return s.image()


def side_briefcase(frame):
    """A briefcase in the near hand, swinging with it."""
    s = Layer()
    hx, hy = HANDS[frame][0]
    s.rect(hx - 1, hy - 1, hx + 1, hy + 1, "ink", 0.9)  # its handle
    s.rect(hx - 4, hy + 1, hx + 4, hy + 9, "briefcase", 0.95)
    s.rect(hx - 4, hy + 1, hx + 4, hy + 2, "briefcase", 1.15)
    return s.image()


## Holding a phone: the arm it's in, bent up to hold it (facing us, at the chest; from the
## side, up in front of the face), in place of the arm hanging or swinging. people_art.gd takes
## the hanging arm away first (facing us: the columns outside the torso, ARM_CLEAR).
PHONE_HAND_FRONT = (21, 31)  # the phone's held here (the hand's middle), facing us
PHONE_HAND_SIDE = (23, 25)  # ...and from the side, in front of the face


def phone_arm(view, bare=False):
    s = Layer()
    if view == "front":
        shoulder, elbow, hand = (W - SHOULDER, TOP + 2), (W - SHOULDER + 1, TOP + 15), PHONE_HAND_FRONT
        light = 0.75
    else:
        shoulder, elbow, hand = SHOULDER_AT, (SHOULDER_AT[0] + 2, TOP + 13), PHONE_HAND_SIDE
        light = 0.9
    _strip(s, shoulder, elbow, 4, CLOTH, light)
    for k in range(9):  # the forearm, up from the elbow to the hand
        t = k / 8
        x = elbow[0] + (hand[0] - elbow[0]) * t
        y = elbow[1] + (hand[1] - elbow[1]) * t
        s.rect(int(round(x - 2)), int(round(y - 1)), int(round(x + 2)), int(round(y + 2)), SKIN if bare else CLOTH, light - 0.05)
    s.rect(hand[0] - 2, hand[1] - 1, hand[0] + 2, hand[1] + 2, SKIN, light + 0.15)  # the hand
    return s.image()


# Something on their head (the look's "hat": looks.gd), over the hair, in their clothes' colour:
# a baseball cap, a knitted beanie (a cold night), an older man's flat cap. Facing us, from
# behind (seated) and from the side (walking, facing right: a brim forward).
HATS = ("cap", "beanie", "flat_cap")


def hat(kind, view):
    s = Layer()
    y = HEAD_Y
    if view == "side":
        if kind == "beanie":
            s.ellipse(15.5, y + 5, 7, 6, CLOTH, rows=(0, y + 6))
            s.rect(9, y + 5, 23, y + 7, CLOTH, 1.2)  # its turned-up cuff
        else:
            low = 4 if kind == "cap" else 5
            s.ellipse(15.5, y + 5, 7, 5.5 if kind == "cap" else 4.5, CLOTH, rows=(0, y + low))
            s.rect(9, y + low, 22, y + low + 1, CLOTH, 0.8)
            s.rect(21, y + low, 26 if kind == "cap" else 24, y + low + 1, CLOTH, 0.65)  # the brim, forward
        return s.image()
    down = SEATED_DOWN if view == "back" else 0
    if kind == "beanie":
        s.ellipse(CX, y + 5, 7.5, 6.5, CLOTH, rows=(0, y + 6))
        s.rect(9, y + 5, 24, y + 7, CLOTH, 1.2)  # the cuff
        for x in range(10, 23, 3):
            s.rect(x, y + 1, x + 1, y + 5, CLOTH, 0.85)  # its knit
    elif kind == "cap":
        s.ellipse(CX, y + 4, 7.5, 5, CLOTH, rows=(0, y + 5))
        if view == "front":
            s.rect(8, y + 4, 25, y + 6, CLOTH, 0.7)  # the brim, towards us
            s.dot(16, y, CLOTH, 1.3)  # the button on top
        else:
            s.rect(13, y + 4, 19, y + 6, SKIN, 0.85)  # the gap at the back, over the strap
            s.rect(13, y + 4, 19, y + 5, CLOTH, 0.75)
    else:  # flat cap
        s.ellipse(CX, y + 4, 7.5, 3.5, CLOTH, rows=(y + 1, y + 6))
        s.rect(8, y + 5, 25, y + 6, CLOTH, 0.7)
    return s.image(down)


def lanyard():
    """An ID card on a lanyard round the neck (an office's, a hospital's), facing us."""
    s = Layer()
    for k in range(12):  # the strap, down each side of the neck to the card
        s.dot(13 + k // 4, TOP + k, "blue_shirt", 0.9)
        s.dot(19 - k // 4, TOP + k, "blue_shirt", 0.9)
    s.rect(14, TOP + 12, 19, TOP + 18, "white_shirt", 1.15)  # the card
    s.rect(15, TOP + 13, 17, TOP + 15, "ink", 0.9)  # its photo
    return s.image()


# Facing us (the owner, mostly), the arm on our right (the one a phone's held in) doing something for a moment: pouring from a green bottle, carrying a
# bowl, stirring a pot at the stove (two frames, the ladle up and down), waving someone in (two
# frames), a hand to the head. people_art.gd takes the hanging arm away first (ARM_CLEAR).
FRONT_GESTURES = {  # elbow, hand
    "pour": ((29, TOP + 12), (22, TOP + 13)),
    "carry": ((29, TOP + 12), (22, TOP + 15)),
    "cook_0": ((29, TOP + 13), (23, TOP + 19)),
    "cook_1": ((29, TOP + 12), (22, TOP + 13)),
    "wave_0": ((30, TOP + 2), (29, TOP - 9)),
    "wave_1": ((30, TOP + 2), (31, TOP - 7)),
    "head": ((31, TOP - 2), (21, 3)),
}


def _limb(s, a, b, what, light, width=4):
    """A straight piece of arm from a to b (x, y), width wide, as a line of little squares."""
    steps = max(abs(b[0] - a[0]), abs(b[1] - a[1]), 1)
    for k in range(steps + 1):
        t = k / steps
        x = a[0] + (b[0] - a[0]) * t
        y = a[1] + (b[1] - a[1]) * t
        s.rect(int(round(x - width / 2)), int(round(y - 1)), int(round(x + width / 2)), int(round(y + 2)), what, light)


def front_gesture(kind, bare=False):
    s = Layer()
    shoulder = (W - SHOULDER, TOP + 2)
    elbow, hand = FRONT_GESTURES[kind]
    _limb(s, shoulder, elbow, CLOTH, 0.75)  # the upper arm
    _limb(s, elbow, hand, SKIN if bare else CLOTH, 0.72)  # the forearm
    s.rect(hand[0] - 2, hand[1] - 1, hand[0] + 2, hand[1] + 2, SKIN, 0.95)  # the hand
    if kind == "pour":  # a green bottle, tipped down to the left, pouring
        _limb(s, (hand[0] - 1, hand[1] - 2), (hand[0] - 7, hand[1] + 3), "bottle", 0.9, width=3)
        s.dot(hand[0] - 8, hand[1] + 4, "bottle", 1.2)  # its neck
    elif kind == "carry":  # a steel bowl of something red and hot, held out (steel, not white: the apron's white)
        s.rect(hand[0] - 6, hand[1] - 3, hand[0] + 3, hand[1] - 2, "tie", 1.3)  # what's in it, heaped
        s.rect(hand[0] - 7, hand[1] - 2, hand[0] + 4, hand[1] - 1, "blue_shirt", 1.2)  # the rim
        s.rect(hand[0] - 6, hand[1] - 1, hand[0] + 3, hand[1] + 1, "blue_shirt", 0.85)
        s.rect(hand[0] - 5, hand[1] + 1, hand[0] + 2, hand[1] + 2, "blue_shirt", 0.65)
    elif kind.startswith("cook"):  # a ladle, up from the hand
        _limb(s, (hand[0] - 1, hand[1]), (hand[0] - 4, hand[1] - 7), "strap", 0.9, width=1)
    return s.image()


# Seated at the counter, from behind, their right arm (on our right) up for a moment: a glass
# raised to their mouth, food on its way up on chopsticks, a hand to the head (a sad or awkward
# moment). people_art.gd takes the arm resting on the counter away first (BACK_ARM_CLEAR).
GESTURES = {  # elbow, hand (from behind: the hand by the mouth is just beside the head)
    "drink": ((30, TOP + 9), (25, 13)),
    "eat": ((30, TOP + 11), (25, 15)),
    "head": ((31, TOP - 3), (21, 3)),
}


def back_gesture(kind, bare=False):
    s = Layer()
    shoulder = (W - SHOULDER, TOP + 2)
    elbow, hand = GESTURES[kind]
    upper = (shoulder, elbow) if elbow[1] > shoulder[1] else (elbow, shoulder)
    _strip(s, upper[0], upper[1], 4, CLOTH, 0.75)  # the upper arm, out to the elbow
    s.rect(elbow[0] - 2, elbow[1] - 2, elbow[0] + 2, elbow[1] + 2, CLOTH, 0.7)  # the elbow
    for k in range(9):  # the forearm, from the elbow to the hand
        t = k / 8
        x = elbow[0] + (hand[0] - elbow[0]) * t
        y = elbow[1] + (hand[1] - elbow[1]) * t
        s.rect(int(round(x - 2)), int(round(y - 1)), int(round(x + 2)), int(round(y + 2)), SKIN if bare and t > 0.3 else CLOTH, 0.72)
    s.rect(hand[0] - 2, hand[1] - 1, hand[0] + 2, hand[1] + 2, SKIN, 0.9)  # the hand
    if kind == "drink":  # a little soju glass, tipped up
        s.rect(hand[0] - 1, hand[1] - 5, hand[0] + 2, hand[1] - 1, "white_shirt", 1.25)
        s.rect(hand[0] - 1, hand[1] - 5, hand[0] + 2, hand[1] - 4, "white_shirt", 1.45)  # its rim catching the light
    elif kind == "eat":  # chopsticks, up past the head
        for k in range(4):
            s.dot(hand[0] - 1 - k, hand[1] - 2 - k, "ink", 1.0)
    return s.image(SEATED_DOWN)


def side_layers():
    out = {}
    clothes = ["suit", "blazer", "trench", "padded", "hoodie", "cardigan", "scrubs", "work_jacket", "tshirt", "knit"]
    styles = ["long", "bob", "ponytail", "bun", "pixie", "perm", "short", "side_part", "buzz", "two_block", "balding"]
    for kind in clothes:
        out["side_body_%s" % kind] = side_body(kind)
    for frame in range(4):
        out["side_legs_%d" % frame] = side_legs(frame)
        out["side_briefcase_%d" % frame] = side_briefcase(frame)
        for near in (True, False):
            out["side_arm%s_%d" % ("" if near else "_far", frame)] = side_arm(frame, near)
            out["side_arm_bare%s_%d" % ("" if near else "_far", frame)] = side_arm(frame, near, bare=True)
    for bare in (False, True):
        out["front_arm_phone%s" % ("_bare" if bare else "")] = phone_arm("front", bare)
        out["side_arm_phone%s" % ("_bare" if bare else "")] = phone_arm("side", bare)
    out["side_head"] = side_head()
    out["side_head_old"] = side_head(old=True)
    for style in styles:
        out["side_hair_%s" % style] = side_hair(style)
    for name in ("glasses", "apron", "tote", "backpack"):
        out["side_%s" % name] = side_extra(name)
    return out


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
    for kind in HATS:
        for view in ("front", "back", "side"):
            out["%s_hat_%s" % (view, kind)] = hat(kind, view)
    out["front_lanyard"] = lanyard()
    for kind in FRONT_GESTURES:
        out["front_arm_%s" % kind] = front_gesture(kind)
        out["front_arm_%s_bare" % kind] = front_gesture(kind, bare=True)
    for kind in GESTURES:
        out["back_arm_%s" % kind] = back_gesture(kind)
        out["back_arm_%s_bare" % kind] = back_gesture(kind, bare=True)
    out.update(side_layers())
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
