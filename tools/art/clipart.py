"""The edit's clipart, drawn in code (ART.md, "The edit's clipart"; PLAN.md, "Variety-show clipart"):
the little drawings Korean TV sticks to people on screen as a caption pops (a crow flapping past
an awkward silence, a rain cloud over someone sad, hearts floating up). One picture for each
frame of each clipart the game lists (scripts/rules/clipart.gd CLIPS: its name and how many
frames), on the pixel grid (the game shows it a pixel to 3, as the people), in the palette's
colours (tools/art/palette.py: each colour snapped to the nearest ramp step), with a dark edge
all round so it reads over anything. Unlit: it's the edit's, laid over the picture, not in the tent.

    python3 tools/art/clipart.py               (all of them, into art/clipart/, the manifest and LICENSE-ASSETS)
    python3 tools/art/clipart.py --sheet out.png
"""
import math, os, re, sys
import numpy as np
from PIL import Image

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import palette

SOURCE = "drawn in code by tools/art/clipart.py"
LICENCE = "CC BY-SA 4.0 (this project)"
EDGE = "1a1a20"  # the dark edge round everything (the palette's ink)

# The colours it draws in (snapped to the palette's ramps as it draws).
WHITE, INK, BLACK = "f5f2ea", "1a1a20", "2b2a33"
YELLOW, GOLD, ORANGE, RED = "ffd23f", "e8c24a", "e8833a", "c8443a"
PINK, DEEP_PINK, SKY, BLUE = "ff8fc0", "e0507e", "9cc4e4", "6fa8ff"
GREY, DARK_GREY, STEEL = "a0a0a8", "6e6a78", "9a9ab0"
WOOD, STRAW, LEAF = "8a5a33", "cdb894", "3f8f4a"


def clips():
    """The clipart the game lists (rules/clipart.gd CLIPS): {name: frames}."""
    text = open(os.path.join(palette.ROOT, "scripts/rules/clipart.gd"), encoding="utf-8").read()
    table = text[text.index("const CLIPS"):]
    table = table[:table.index("\n}")]
    return {name: int(frames) for name, frames in re.findall(r'"(\w+)":\s*\{"frames":\s*(\d+)', table)}


_snapped = {}


def snap(colour):
    """A colour's nearest in the palette (any ramp's step), so the clipart's in the game's colours."""
    if colour not in _snapped:
        rgbs, _, _ = palette.ramped()
        labs = palette.to_lab(rgbs)
        k = int(np.argmin(np.linalg.norm(labs - palette.to_lab(palette.hexc(colour)), axis=1)))
        _snapped[colour] = tuple(int(c) for c in rgbs[k])
    return _snapped[colour]


class Pic:
    """A picture being drawn: RGBA, and which pixels get no dark edge (rain, sparkles, beams)."""

    def __init__(self, w, h):
        self.w, self.h = w, h
        self.px = np.zeros((h, w, 4), np.uint8)
        self.bare = np.zeros((h, w), bool)

    def dot(self, x, y, colour, alpha=255, bare=False):
        x, y = int(round(x)), int(round(y))
        if 0 <= x < self.w and 0 <= y < self.h:
            self.px[y, x] = (*snap(colour), alpha)
            self.bare[y, x] = bare

    def rect(self, x0, y0, x1, y1, colour, **kw):  # (x1, y1 not included)
        for y in range(y0, y1):
            for x in range(x0, x1):
                self.dot(x, y, colour, **kw)

    def ellipse(self, cx, cy, rx, ry, colour, **kw):
        for y in range(self.h):
            for x in range(self.w):
                if ((x + 0.5 - cx) / rx) ** 2 + ((y + 0.5 - cy) / ry) ** 2 <= 1.0:
                    self.dot(x, y, colour, **kw)

    def ring(self, cx, cy, rx, ry, colour, thick=0.35, **kw):
        for y in range(self.h):
            for x in range(self.w):
                d = math.hypot((x + 0.5 - cx) / rx, (y + 0.5 - cy) / ry)
                if abs(d - 1.0) <= thick:
                    self.dot(x, y, colour, **kw)

    def poly(self, points, colour, **kw):
        """A filled polygon (pixel centres inside it)."""
        for y in range(self.h):
            for x in range(self.w):
                if _inside(x + 0.5, y + 0.5, points):
                    self.dot(x, y, colour, **kw)

    def line(self, x0, y0, x1, y1, colour, **kw):
        steps = int(max(abs(x1 - x0), abs(y1 - y0)) * 2) + 1
        for k in range(steps + 1):
            t = k / steps
            self.dot(x0 + (x1 - x0) * t, y0 + (y1 - y0) * t, colour, **kw)

    def image(self):
        """Padded by a pixel, the dark edge round everything drawn (but the bare bits)."""
        px = np.zeros((self.h + 2, self.w + 2, 4), np.uint8)
        px[1:-1, 1:-1] = self.px
        bare = np.zeros((self.h + 2, self.w + 2), bool)
        bare[1:-1, 1:-1] = self.bare
        solid = (px[..., 3] > 0) & ~bare
        edge = np.zeros_like(solid)
        for dy, dx in ((-1, 0), (1, 0), (0, -1), (0, 1)):
            edge |= np.roll(np.roll(solid, dy, 0), dx, 1)
        edge &= px[..., 3] == 0
        px[edge] = (*snap(EDGE), 255)
        return Image.fromarray(px, "RGBA")


def _inside(x, y, points):
    inside = False
    for k in range(len(points)):
        (x0, y0), (x1, y1) = points[k], points[k - 1]
        if (y0 > y) != (y1 > y) and x < (x1 - x0) * (y - y0) / (y1 - y0) + x0:
            inside = not inside
    return inside


def sparkle(pic, x, y, colour=WHITE, big=False):
    """A four-pointed twinkle."""
    pic.dot(x, y, colour, bare=True)
    for d in ((1, 0), (-1, 0), (0, 1), (0, -1)):
        pic.dot(x + d[0], y + d[1], colour, bare=True)
        if big:
            pic.dot(x + 2 * d[0], y + 2 * d[1], colour, 170, bare=True)


def heart(pic, cx, cy, size, colour=PINK, shine=WHITE):
    """A heart, size its half-width."""
    pic.ellipse(cx - size * 0.5, cy - size * 0.2, size * 0.58, size * 0.58, colour)
    pic.ellipse(cx + size * 0.5, cy - size * 0.2, size * 0.58, size * 0.58, colour)
    pic.poly([(cx - size * 1.05, cy), (cx + size * 1.05, cy), (cx, cy + size * 1.1)], colour)
    pic.dot(cx - size * 0.6, cy - size * 0.45, shine)


# --- Awkward ---------------------------------------------------------------------------------

def crow(frame):
    """A crow flapping (it flies across them, left to right): wings up, level, down, level."""
    pic = Pic(17, 12)
    pic.ellipse(8, 6.5, 4.2, 2.4, BLACK)  # the body
    pic.poly([(4.5, 5.5), (0.5, 4.5), (0.5, 8), (4.5, 7.5)], BLACK)  # the tail
    pic.ellipse(12.5, 5, 2.2, 2.0, BLACK)  # the head
    pic.poly([(14.2, 4.2), (16.8, 5.2), (14.2, 6.0)], GOLD)  # the beak
    pic.dot(13, 4.5, WHITE)  # the eye
    wing = [[(6, 5.5), (9, 0.2), (11, 5.5)], [(5, 5.5), (2, 3.5), (11, 5.5)],
            [(6, 7), (8, 11.8), (11, 7)], [(5, 5.5), (2, 3.5), (11, 5.5)]][frame]
    pic.poly(wing, DARK_GREY if frame != 2 else BLACK)
    return pic


def sweat(frame):
    """The big sweat drop, sliding down."""
    pic = Pic(7, 12)
    y = frame * 1.2
    pic.poly([(3.5, 0.2 + y), (6.2, 5.5 + y), (0.8, 5.5 + y)], SKY)
    pic.ellipse(3.5, 6.5 + y, 2.8, 2.6, SKY)
    pic.dot(2.4, 5.6 + y, WHITE)
    return pic


def tumbleweed(frame):
    """A tumbleweed rolling past their feet (it turns as it rolls)."""
    pic = Pic(14, 14)
    pic.ring(7, 7, 6, 6, WOOD, 0.13)
    turn = frame * math.pi / 8
    for k in range(4):
        a = turn + k * math.pi / 4
        pic.line(7 - 5.6 * math.cos(a), 7 - 5.6 * math.sin(a), 7 + 5.6 * math.cos(a), 7 + 5.6 * math.sin(a), STRAW if k % 2 else WOOD)
    pic.ring(7, 7, 3.2, 3.2, STRAW, 0.2)
    return pic


# --- Sad -------------------------------------------------------------------------------------

def rain_cloud(frame):
    """Their own rain cloud, raining on them."""
    pic = Pic(24, 18)
    for k in range(5):  # the rain first, so the cloud's over its tops
        x = 4 + k * 4
        y = 9 + (k * 3 + frame * 3) % 8
        pic.line(x, y, x - 0.5, y + 1.5, SKY, bare=True)
    pic.ellipse(7, 6, 5, 3.6, DARK_GREY)
    pic.ellipse(13, 4.5, 6, 4.2, DARK_GREY)
    pic.ellipse(18, 6.5, 4.6, 3.3, DARK_GREY)
    pic.rect(3, 6, 22, 9, DARK_GREY)
    pic.ellipse(12, 3.6, 4, 2, GREY)  # lighter on top
    return pic


def tears(frame):
    """Tears pouring from both eyes, arcing out either side (TV's waterfall tears)."""
    pic = Pic(28, 14)
    for side in (-1, 1):
        eye = 14 + side * 3
        for k in range(18):
            t = k / 2.0
            x = eye + side * t
            y = 1 + t * t / 5.5
            pic.dot(x, y, BLUE if k % 4 == (frame + side) % 4 else SKY)
            pic.dot(x, y + 1, SKY)
        t = 9 + (frame * 0.6)
        pic.dot(eye + side * (t + 1), 1 + (t + 1) ** 2 / 5.5 + 1.5, SKY, bare=True)  # a drop flying off
    return pic


# --- Sweet -----------------------------------------------------------------------------------

def hearts(frame):
    """Hearts floating up (the sticker floats them up; here they beat, one after another)."""
    pic = Pic(22, 18)
    for k, (x, y) in enumerate([(5, 11), (11, 4), (17, 10)]):
        big = (k + frame) % 4 == 0
        heart(pic, x, y, 3.4 if big else 2.6, PINK if k != 1 else DEEP_PINK)
    return pic


def blush(frame):
    """Blushing cheeks: two pink patches, their lines."""
    pic = Pic(24, 6)
    for x in (4.5, 19.5):
        pic.ellipse(x, 3, 4, 2.2, PINK, alpha=210)
        for k in range(3):
            lx = x - 2 + k * 2
            pic.line(lx + 1, 1, lx, 4 - frame, DEEP_PINK, bare=True)
    return pic


def flowers(frame):
    """Flowers blooming behind them (behind their head, in an arc)."""
    pic = Pic(38, 30)
    for k in range(7):
        a = math.pi * (1.05 + k * 0.15)
        cx, cy = 19 + 15 * math.cos(a), 18 + 14 * math.sin(a)
        petal = PINK if k % 2 else YELLOW
        for p in range(5):
            b = p * 2 * math.pi / 5 + k
            pic.ellipse(cx + 2.2 * math.cos(b), cy + 2.2 * math.sin(b), 1.6, 1.6, petal)
        pic.ellipse(cx, cy, 1.2, 1.2, ORANGE if petal == YELLOW else YELLOW)
    for k in range(3):  # twinkles between, coming and going
        a = math.pi * (1.12 + k * 0.38 + frame * 0.07)
        sparkle(pic, 19 + 10 * math.cos(a), 18 + 9.5 * math.sin(a))
    return pic


# --- Shock -----------------------------------------------------------------------------------

def lightning(frame):
    """A lightning bolt striking down at them, flashing."""
    pic = Pic(14, 24)
    bolt = [(8, 0), (13, 0), (8.5, 9), (12, 9), (3, 23.5), (5.5, 12), (2, 12)]
    pic.poly(bolt, YELLOW if frame == 0 else WHITE)
    if frame == 0:
        pic.poly([(9, 1), (11.5, 1), (8, 8)], WHITE)
    else:
        sparkle(pic, 2, 3, YELLOW, True)
        sparkle(pic, 12, 17, YELLOW, True)
    return pic


def bang(frame):
    """!! by their head, jumping."""
    pic = Pic(10, 14)
    for k, x in enumerate((2, 7)):
        lift = (frame + k) % 2
        pic.poly([(x - 1.8, 0.5 + lift), (x + 1.8, 0.5 + lift), (x + 0.9, 8.5 + lift), (x - 0.9, 8.5 + lift)], RED)
        pic.rect(x - 1, 10 + lift, x + 1, 12 + lift, RED)
    return pic


def mind_blown(frame):
    """멘붕, the mind-blown crumble: a burst over their head, the bits falling away."""
    pic = Pic(26, 22)
    size = [0.45, 0.8, 1.0, 0.9][frame]
    if frame < 3:
        for k in range(9):
            a = k * 2 * math.pi / 9 + 0.3
            r = 10 * size
            pic.poly([(13, 12), (13 + r * math.cos(a - 0.25), 12 + r * math.sin(a - 0.25)),
                      (13 + r * 1.25 * math.cos(a), 12 + r * 1.25 * math.sin(a)),
                      (13 + r * math.cos(a + 0.25), 12 + r * math.sin(a + 0.25))], ORANGE)
        pic.ellipse(13, 12, 6.5 * size, 5.5 * size, YELLOW)
        pic.ellipse(13, 12, 3.2 * size, 2.8 * size, WHITE)
    else:
        pic.ellipse(13, 10, 6, 4, GREY, alpha=200)  # the smoke left
        pic.ellipse(9, 8, 3.5, 3, GREY, alpha=200)
    for k in range(6):  # the bits of their brain, falling
        a = k * math.pi / 3 + 0.5
        r = 3 + frame * 3
        x, y = 13 + r * math.cos(a), 12 + r * 0.7 * math.sin(a) + frame * frame * 0.6
        pic.rect(int(x), int(y), int(x) + 2, int(y) + 2, PINK if k % 2 else DEEP_PINK)
    return pic


# --- Funny -----------------------------------------------------------------------------------

def haha(frame):
    """ㅋㅋㅋ (kekeke: lol) by their head, each letter bouncing in turn."""
    pic = Pic(22, 10)
    for k in range(3):
        x0 = k * 7 + 1
        y0 = 1 if (k + frame) % 3 == 0 else 2
        pic.rect(x0, y0, x0 + 6, y0 + 2, YELLOW)  # ㅋ: the top stroke,
        pic.rect(x0 + 4, y0, x0 + 6, y0 + 8, YELLOW)  # down the right,
        pic.rect(x0, y0 + 3, x0 + 5, y0 + 5, YELLOW)  # and the middle one
    return pic


def laugh_tears(frame):
    """Laughing till they cry: tears squirting sideways from both eyes."""
    pic = Pic(30, 10)
    reach = [5, 9, 12][frame]
    for side in (-1, 1):
        eye = 15 + side * 3
        for k in range(reach):
            x = eye + side * k
            y = 4 - math.sin(k / reach * math.pi) * 2.2 + (k / reach) * 2
            pic.dot(x, y, SKY)
            if k < reach - 2:
                pic.dot(x, y + 1, SKY)
        pic.dot(eye + side * (reach + 1), 5, BLUE, bare=True)
    return pic


# --- Warm ------------------------------------------------------------------------------------

def sunbeams(frame):
    """Sunbeams fanning out from behind them, turning slowly."""
    pic = Pic(48, 48)
    turn = frame * math.pi / 12
    for k in range(12):
        a = turn + k * math.pi / 6
        near, far, width = 9, 23.5, 0.11
        pic.poly([(24 + near * math.cos(a - width), 24 + near * math.sin(a - width)),
                  (24 + far * math.cos(a - width * 1.6), 24 + far * math.sin(a - width * 1.6)),
                  (24 + far * math.cos(a + width * 1.6), 24 + far * math.sin(a + width * 1.6)),
                  (24 + near * math.cos(a + width), 24 + near * math.sin(a + width))],
                 YELLOW if k % 2 else WHITE, alpha=185, bare=True)
    return pic


def halo(frame):
    """A halo over their head, and sparkles round it."""
    pic = Pic(22, 9)
    pic.ring(11, 5, 8.5, 2.4, GOLD, 0.28)
    pic.ring(11, 4.6, 8.5, 2.4, YELLOW, 0.14)
    for k, (x, y) in enumerate([(1, 1), (20, 2), (11, 0)]):
        if (k + frame) % 3 != 2:
            sparkle(pic, x, y, WHITE)
    return pic


# --- A roast ---------------------------------------------------------------------------------

def arrow(frame):
    """뼈 때림: an arrow through the chest (the head out one side, the feathers the other)."""
    pic = Pic(42, 9)
    wobble = frame
    pic.rect(1, 4, 13, 5, WOOD)  # the shaft, the feathers' end
    pic.rect(29, 4, 36, 5, WOOD)  # ...and out the other side
    pic.poly([(35, 0.5), (41.5, 4.5), (35, 8.5)], STEEL)  # the head
    for k in range(3):  # the feathers, quivering
        x = 2 + k * 3
        pic.line(x, 4, x - 2, 1 + wobble, RED)
        pic.line(x, 5, x - 2, 8 - wobble, RED)
    return pic


# --- The game's own captions -------------------------------------------------------------------

def soul(frame):
    """영혼 가출, the soul leaving the body: a little ghost of them floating up, waving."""
    pic = Pic(14, 18)
    pic.ellipse(7, 6, 5.5, 5.5, WHITE, alpha=215)
    pic.rect(2, 6, 13, 13, WHITE, alpha=215)
    for k in range(4):  # its wavy tail
        x = 2 + k * 3
        down = 15 + (1 if (k + frame) % 2 else -1)
        pic.poly([(x - 0.5, 12), (x + 3, 12), (x + 1.5, down)], WHITE, alpha=215)
    pic.dot(5, 6, INK)
    pic.dot(9, 6, INK)
    pic.ellipse(7, 9, 1.1, 1.0 + frame % 2 * 0.4, INK)  # a little "o"
    for side, x in ((-1, 0.5), (1, 13.5)):  # arms up, waving goodbye
        pic.dot(x, 6 - (frame + (side > 0)) % 2, WHITE, alpha=215)
    return pic


def flames(frame):
    """Flames behind them (a bill fight, a drinking game): flickering up."""
    pic = Pic(40, 30)
    rng = np.random.default_rng(7 + frame)
    tips = 14 + 8 * np.sin(np.arange(40) / 2.3 + frame * 1.7) + rng.uniform(-2, 2, 40)
    for x in range(40):
        middle = 1 - abs(x - 19.5) / 22
        top = 29 - tips[x] * (0.55 + 0.6 * middle)
        for y in range(int(top), 30):
            f = (y - top) / max(1.0, 29 - top)
            pic.dot(x, y, YELLOW if f > 0.62 else ORANGE if f > 0.25 else RED)
    return pic


def stars(frame):
    """Stars spinning round their head (another round: the room's going round)."""
    pic = Pic(36, 16)
    for k in range(3):
        a = frame * math.pi / 2 + k * 2 * math.pi / 3
        x, y = 18 + 13 * math.cos(a), 8 + 3.6 * math.sin(a)
        near = math.sin(a) > -0.2
        pic.poly([(x + 4.2 * math.cos(b) * (1 if p % 2 == 0 else 0.45) * (1 if near else 0.7),
                   y + 4.2 * math.sin(b) * (1 if p % 2 == 0 else 0.45) * (1 if near else 0.7))
                  for p, b in enumerate(np.arange(10) * math.pi / 5 - math.pi / 2)], YELLOW if near else GOLD)
    return pic


def siren(frame):
    """The emergency siren on their head, its light going round."""
    pic = Pic(20, 13)
    pic.ellipse(10, 7.5, 4.5, 5.2, RED)
    pic.rect(5, 7, 15, 10, RED)
    pic.rect(4, 10, 16, 13, STEEL)
    spot = [7, 10, 13, None][frame]
    if spot is not None:
        pic.rect(spot - 1, 4, spot + 1, 9, YELLOW)
        pic.dot(spot - 1, 4, WHITE)
        if spot != 10:  # its beam, out to the side
            side = -1 if spot < 10 else 1
            for k in range(3):
                pic.line(10 + side * 6, 6 + k * 1.5, 10 + side * 9.5, 4 + k * 2.5, YELLOW, alpha=190, bare=True)
    return pic


DRAW = {"crow": crow, "sweat": sweat, "tumbleweed": tumbleweed, "rain_cloud": rain_cloud, "tears": tears,
        "hearts": hearts, "blush": blush, "flowers": flowers, "lightning": lightning, "bang": bang,
        "mind_blown": mind_blown, "haha": haha, "laugh_tears": laugh_tears, "sunbeams": sunbeams, "halo": halo,
        "arrow": arrow, "soul": soul, "flames": flames, "stars": stars, "siren": siren}


def pictures():
    out = {}
    for name, frames in clips().items():
        if name not in DRAW:
            raise SystemExit("clipart.gd lists \"%s\", which clipart.py doesn't draw" % name)
        for frame in range(frames):
            out["%s_%d" % (name, frame)] = DRAW[name](frame).image()
    return out


if __name__ == "__main__":
    if len(sys.argv) > 2 and sys.argv[1] == "--sheet":
        made = pictures()
        names = clips()
        cell = max(max(img.width, img.height) for img in made.values()) + 2
        sheet = Image.new("RGBA", (max(names.values()) * cell, len(names) * cell), (60, 52, 90, 255))
        for row, (name, frames) in enumerate(names.items()):
            for frame in range(frames):
                img = made["%s_%d" % (name, frame)]
                sheet.alpha_composite(img, (frame * cell + (cell - img.width) // 2, row * cell + (cell - img.height) // 2))
        sheet.resize((sheet.width * 4, sheet.height * 4), Image.NEAREST).save(sys.argv[2])
        sys.exit(0)
    from pixelate import add_to_game
    made = pictures()
    for ident, image in made.items():
        add_to_game(image, "clipart/" + ident, SOURCE, LICENCE)
    print("%d frames of clipart drawn into art/clipart/" % len(made))
