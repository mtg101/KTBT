"""The tent's cat in pixel art, drawn in code (ART.md, "The cat"): one picture for each of its
coats (scripts/rules/cat_rules.gd CAT_COATS) in each pose: asleep, curled up (by the stove, on
a lap), sitting up (on the counter, at someone's feet, staring at their food), and the four
frames of its walk (prowling, padding off into the street). Side on, facing right (the game
mirrors it to face left), 24 x 14 pixels on the grid, its feet on the bottom row. Lit from above
(the bulbs over the counter) on its coat's light ramp (tools/art/palette.py), a darker edge all round so it reads
on a dark floor; a tabby's stripes, a calico's patches.

    python3 tools/art/cat.py               (all of them, into art/cats/, the manifest and LICENSE-ASSETS)
    python3 tools/art/cat.py --sheet out.png
"""
import os, re, sys
import numpy as np
from PIL import Image

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import palette

W, H = 24, 14
SOURCE = "drawn in code by tools/art/cat.py"
LICENCE = "CC BY-SA 4.0 (this project)"
LEVELS = [0.15, 0.3, 0.45, 0.62, 0.85, 1.15, 1.5]  # light to step (as tent.py)
POSES = ["sleep", "sit", "walk_0", "walk_1", "walk_2", "walk_3"]
INK = "1a1a20"
NOSE = "d98a8f"
GOLD = "e8c24a"  # a black cat's eyes (ink wouldn't show)
GINGER = "d9883a"
BLACK = "2b2a33"


def coats():
    """The cat's coats, from the game (cat_rules.gd CAT_COATS): {name: colour}."""
    text = open(os.path.join(palette.ROOT, "scripts/rules/cat_rules.gd"), encoding="utf-8").read()
    line = text[text.index("const CAT_COATS"):]
    line = line[:line.index("}")]
    return dict(re.findall(r'"(\w+)":\s*"([0-9a-fA-F]{6})"', line))


class Cat:
    """A picture: each pixel's colour (before the light) and how lit it is."""

    def __init__(self, coat):
        self.coat = coat
        self.colour = np.full((H, W), "", object)
        self.light = np.zeros((H, W))
        self.edge_ok = np.ones((H, W), bool)  # (eyes and nose: never darkened as an edge)

    def dot(self, x, y, colour=None, light=None):
        if 0 <= x < W and 0 <= y < H:
            self.colour[y, x] = colour or self.coat
            # Lit from above: lighter up top, the same either way it faces (it's mirrored).
            self.light[y, x] = light if light is not None else 0.98 - 0.035 * y

    def ellipse(self, cx, cy, rx, ry, colour=None, light_add=0.0):
        for y in range(H):
            for x in range(W):
                if ((x + 0.5 - cx) / rx) ** 2 + ((y + 0.5 - cy) / ry) ** 2 <= 1.0:
                    self.dot(x, y, colour)
                    self.light[y, x] += light_add

    def rect(self, x0, y0, x1, y1, colour=None, light=None):
        for y in range(y0, y1):
            for x in range(x0, x1):
                self.dot(x, y, colour, light)

    def mark(self, x, y, colour):
        """An eye or the nose: its own colour, never an edge."""
        self.dot(x, y, colour, 1.0)
        if 0 <= x < W and 0 <= y < H:
            self.edge_ok[y, x] = False

    def image(self):
        drawn = self.colour != ""
        out = np.zeros((H, W, 4), np.uint8)
        for y in range(H):
            for x in range(W):
                if not drawn[y, x]:
                    continue
                edge = self.edge_ok[y, x] and any(not (0 <= x + dx < W and 0 <= y + dy < H) or not drawn[y + dy, x + dx]
                                                  for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)))
                step = int(np.clip(np.floor(np.interp(self.light[y, x], LEVELS, range(7)) + 0.5), 0, 6))
                if edge:
                    step = max(0, min(step, 3) - 1)  # a darker edge all round
                out[y, x, :3] = palette.ramp(palette.hexc(self.colour[y, x]))[step]
                out[y, x, 3] = 255
        return Image.fromarray(out, "RGBA")


def _tail(cat, points):
    for x, y in points:
        cat.dot(x, y)


def _head(cat, cx, cy, eye, closed=False):
    """A head in profile, facing right: round, two ears, the muzzle, an eye and the nose."""
    cat.ellipse(cx, cy, 3.1, 2.7, light_add=0.08)
    for x, y in ((int(cx) - 2, int(cy) - 3), (int(cx) - 2, int(cy) - 4), (int(cx) - 1, int(cy) - 3),
                 (int(cx) + 1, int(cy) - 3), (int(cx) + 1, int(cy) - 4), (int(cx), int(cy) - 3)):
        cat.dot(x, y)  # the ears
    cat.dot(int(cx) + 3, int(cy))  # the muzzle
    cat.dot(int(cx) + 3, int(cy) + 1)
    if closed:
        cat.mark(int(cx) + 1, int(cy), eye)  # asleep: the eye a line
        cat.mark(int(cx), int(cy), eye)
    else:
        cat.mark(int(cx) + 1, int(cy) - 1, eye)
    cat.mark(int(cx) + 3, int(cy) - 0, NOSE if cat.coat not in (BLACK,) else "4a3a40")


# The walk: [near back, far back, near front, far front] legs' x, and which are lifted.
STRIDE = [
    ([5, 8, 17, 14], []),
    ([6, 7, 16, 15], [0, 3]),
    ([8, 5, 14, 17], []),
    ([7, 6, 15, 16], [1, 2]),
]


def walk(coat, frame):
    cat = Cat(coat)
    legs, lifted = STRIDE[frame]
    for k in (1, 3):  # the far legs first, darker
        cat.rect(legs[k], 10, legs[k] + 2, 12 if k in lifted else 14, light=0.6)
    _tail(cat, [(4, 8), (3, 7), (2, 6), (2, 5), (2, 4), (3 if frame % 2 else 1, 3)])
    cat.ellipse(11.5, 8.0, 7.2, 3.3)
    for k in (0, 2):  # the near legs
        cat.rect(legs[k], 10, legs[k] + 2, 12 if k in lifted else 14, light=0.95)
    _head(cat, 19.5, 5.6, GOLD if coat == BLACK else INK)
    return cat


def sit(coat):
    cat = Cat(coat)
    _tail(cat, [(x, 13) for x in range(3, 9)] + [(2, 12)])  # curled round on the ground
    cat.ellipse(9.5, 10.0, 4.8, 3.6)  # the haunch
    cat.rect(11, 5, 16, 13)  # the chest
    cat.rect(14, 9, 16, 14, light=0.95)  # the front legs
    cat.rect(12, 10, 14, 14, light=0.6)
    _head(cat, 15.8, 4.0, GOLD if coat == BLACK else INK)
    return cat


def sleep(coat):
    cat = Cat(coat)
    cat.ellipse(11.5, 10.4, 8.2, 3.5)  # curled up, a loaf
    _head(cat, 18.0, 9.6, INK if coat != BLACK else "4a4652", closed=True)
    for x in range(8, 19):  # the tail wrapped round the front
        cat.dot(x, 13, None, 0.62)
    return cat


def markings(cat, coat_name):
    """A tabby's darker stripes; a calico's ginger and black patches."""
    drawn = cat.colour != ""
    for y in range(H):
        for x in range(W):
            if not drawn[y, x] or not cat.edge_ok[y, x]:
                continue
            if coat_name == "tabby" and (x + y // 3) % 4 == 0 and y < 12:
                cat.light[y, x] -= 0.3
            elif coat_name == "calico":
                if (x - 8) ** 2 + (y - 8) ** 2 < 7 or (x - 18) ** 2 + (y - 3) ** 2 < 3:
                    cat.colour[y, x] = GINGER
                elif (x - 13) ** 2 + (y - 7) ** 2 < 4 or (x - 4) ** 2 + (y - 11) ** 2 < 3:
                    cat.colour[y, x] = BLACK
    return cat


def pictures():
    out = {}
    for name, colour in coats().items():
        for pose in POSES:
            cat = sleep(colour) if pose == "sleep" else sit(colour) if pose == "sit" else walk(colour, int(pose[-1]))
            out["%s_%s" % (name, pose)] = markings(cat, name).image()
    return out


if __name__ == "__main__":
    if len(sys.argv) > 2 and sys.argv[1] == "--sheet":
        made = pictures()
        sheet = Image.new("RGBA", (len(POSES) * (W + 2), len(coats()) * (H + 2)), (24, 22, 40, 255))
        for k, (key, img) in enumerate(made.items()):
            sheet.alpha_composite(img, ((k % len(POSES)) * (W + 2), (k // len(POSES)) * (H + 2)))
        sheet.resize((sheet.width * 6, sheet.height * 6), Image.NEAREST).save(sys.argv[2])
        sys.exit(0)
    from pixelate import add_to_game
    made = pictures()
    for ident, image in made.items():
        add_to_game(image, "cat/" + ident, SOURCE, LICENCE)
    print("%d pictures of the cat drawn into art/cats/" % len(made))
