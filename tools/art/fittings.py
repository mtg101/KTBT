"""The tent's fittings and the bars' touches in pixel art, drawn in code (ART.md: small and
exact things in code). Each is drawn in base colours with how lit each pixel is, then put on
its colours' light ramps with a dithered step (as tent.py), at the size the stage draws it
(a pixel to 3 on screen). Used by tent.py.
"""
import numpy as np
from PIL import Image

import palette
from tent import steps, ramped


class Sprite:
    """A little picture in base colours and light: rect() and dot() paint both."""

    def __init__(self, w, h, light=0.95, fall=0.25):
        self.w, self.h = w, h
        self.base = np.zeros((h, w, 3), int)
        self.mask = np.zeros((h, w), bool)
        yy = np.mgrid[0:h, 0:w][0]
        self.light = light - fall * yy / max(h - 1, 1)  # lit from above, a little darker lower down

    def rect(self, x0, y0, x1, y1, colour, light=None):
        """Fills x0..x1-1, y0..y1-1 (clipped)."""
        x0, x1 = max(0, x0), min(self.w, x1)
        y0, y1 = max(0, y0), min(self.h, y1)
        if x0 >= x1 or y0 >= y1:
            return
        self.base[y0:y1, x0:x1] = palette.hexc(colour)
        self.mask[y0:y1, x0:x1] = True
        if light is not None:
            self.light[y0:y1, x0:x1] = light

    def dot(self, x, y, colour, light=None):
        self.rect(x, y, x + 1, y + 1, colour, light)

    def clear(self, x0, y0, x1, y1):
        self.mask[max(0, y0):y1, max(0, x0):x1] = False

    def image(self):
        yy, xx = np.mgrid[0:self.h, 0:self.w]
        return ramped(self.base, steps(self.light, yy, xx), self.mask)


GLOW = 1.4  # what glows by itself: lit to the top of its ramp


def fridge():
    """The drinks fridge (92 by 134 on the stage): the cabinet, its red header strip, the lit
    inside with three shelves (green soju bottles, gold beer cans, white makgeolli), the handle."""
    s = Sprite(31, 45)
    s.rect(0, 0, 31, 45, "d8dce4")
    s.rect(0, 0, 31, 5, "c8443a")
    s.rect(1, 0, 30, 1, "c8443a", 1.15)  # (its top edge catching the light)
    s.rect(2, 6, 29, 44, "23344a", 1.2)  # inside, lit
    shelves = [("3fae6a", 6, 3, 2), ("e0b23c", 5, 3, 0), ("e9e4d4", 5, 3, 2)]  # colour, how many, wide, neck
    for row, (colour, count, wide, neck) in enumerate(shelves):
        floor = 6 + (row + 1) * 9 + (1 if row == 2 else 0)
        gap = (27 - count * wide) // (count + 1)
        for k in range(count):
            x = 2 + gap + k * (wide + gap)
            s.rect(x, floor - 5, x + wide, floor, colour, 1.15)
            if neck:
                s.rect(x + 1, floor - 5 - neck, x + 2, floor - 5, colour, 1.15)
            s.dot(x, floor - 5, colour, 1.45)  # light catching the glass
        s.rect(2, floor, 29, floor + 1, "9aa6b4", 1.0)  # the shelf
    s.rect(27, 13, 28, 27, "8a8c96", 0.9)  # the handle
    for k in range(10):  # light catching the door's glass, a slant
        s.dot(5 + k // 3, 40 - k * 3, "eef0f2", 1.5)
    return s.image()


def odeng_pot():
    """The odeng pot (66 by 46 on the stage, from 3 left of the pot and 14 above it): a square
    metal pot, its rim, the broth, and fish cake skewers poking out at a slant."""
    s = Sprite(22, 16)
    for k in range(4):
        x = 3 + k * 4 + (k % 2)
        top = (k % 2) * 1
        for j in range(5):  # the skewer, leaning
            s.dot(x + (1 if j < 2 and k % 2 == 0 else 0), top + j, "d8c49a", 1.1)
        s.rect(x - 1, 4 + top, x + 2, 7 + top, "c9a26b", 1.05)  # a folded fish cake
    s.rect(0, 6, 22, 7, "b0b2bc", 1.25)  # the rim
    s.rect(1, 7, 21, 16, "8a8c96", 0.85)  # the pot
    s.rect(2, 7, 20, 8, "c9a26b", 1.1)  # the broth
    s.rect(1, 15, 21, 16, "8a8c96", 0.55)
    return s.image()


def stove():
    """The stove along the back of the counter (236 by 6, a flame on it): 80 by 4 from (102, 240)."""
    s = Sprite(80, 4)
    s.rect(0, 1, 79, 4, "3a3946", 0.8)
    s.rect(0, 1, 79, 2, "3a3946", 1.1)  # its top edge
    s.rect(9, 0, 23, 1, "e8833a", GLOW)  # the flame
    for x in range(10, 23, 3):
        s.dot(x, 0, "ffd27f", GLOW)
    return s.image()


SIGN_SIZE = (140, 21)  # the sign's board (420 by 62 on the stage)


def sign(style, colours):
    """The sign's board in its style (the Hangul and the name stay text over it, to hover):
    wood (planks and a frame), neon (a dark board, a tube round its edge), banner (cloth, tied
    at its corners), lightbox (a lit white box in a frame)."""
    board, ink = colours
    w, h = SIGN_SIZE
    s = Sprite(w, h, light=1.0, fall=0.2)
    if style == "wood":
        s.rect(0, 0, w, h, board, 0.95)
        for row in (6, 13):
            s.rect(1, row, w - 1, row + 1, board, 0.6)  # the joins between planks
        for x in range(9, w, 23):
            s.dot(x, 3, board, 0.7)
            s.dot(x + 11, 10, board, 0.7)
            s.dot(x + 5, 17, board, 0.7)
        for edge in [(0, 0, w, 1), (0, h - 1, w, h), (0, 0, 1, h), (w - 1, 0, w, h)]:
            s.rect(*edge, board, 0.5)  # the frame
    elif style == "neon":
        s.rect(0, 0, w, h, board, 0.9)
        for edge in [(2, 2, w - 2, 3), (2, h - 3, w - 2, h - 2), (2, 2, 3, h - 2), (w - 3, 2, w - 2, h - 2)]:
            s.rect(*edge, ink, GLOW)  # the tube round its edge
    elif style == "banner":
        s.rect(0, 1, w, h - 1, board, 1.0)
        for x in range(0, w, 2):  # the cloth's hem, top and bottom
            s.dot(x, 1, board, 0.75)
            s.dot(x + 1, h - 2, board, 0.75)
        for x in (0, w - 2):
            s.rect(x, 0, x + 2, 2, "8a5a33", 0.9)  # the ties at its corners
            s.rect(x, h - 2, x + 2, h, "8a5a33", 0.9)
    else:  # lightbox
        s.rect(0, 0, w, h, "6e6a78", 0.8)  # the frame
        s.rect(2, 2, w - 2, h - 2, board, 1.25)  # the lit face
        s.rect(2, 2, w - 2, 3, board, 1.45)
    return s.image()


def touches():
    """The bars' touches, at the size the stage draws them: {id: image}. Each image goes at each
    of its spots (tent_view.gd touch_spots)."""
    out = {}
    s = Sprite(600, 3, light=1.0, fall=0)  # string lights: the whole string, its wire sagging between bulbs
    colours = ["ffd27f", "ff7aa8", "7ad3ff", "a8ff7a"]
    for x in range(600):
        s.dot(x, 0 if (x % 19) in (0, 1, 18) else 1, "55536b", 0.7)
    for k, x in enumerate(range(0, 600, 19)):
        s.rect(x, 1, x + 2, 3, colours[k % 4], GLOW)
    out["string_lights"] = s.image()
    s = Sprite(8, 13)  # a red paper lantern on its cord, its gold bands
    s.rect(3, 0, 5, 3, "55536b", 0.8)
    s.rect(1, 3, 7, 12, "d8352f", 1.3)
    s.rect(0, 4, 8, 11, "d8352f", 1.25)
    s.rect(0, 4, 8, 5, "f2c14a", 1.2)
    s.rect(0, 10, 8, 11, "f2c14a", 1.0)
    s.rect(3, 12, 5, 13, "f2c14a", 1.0)  # its tassel
    s.rect(2, 6, 3, 9, "ffd27f", 1.5)  # the candle's light through the paper
    out["lanterns"] = s.image()
    s = Sprite(14, 14)  # an old radio, its aerial up
    s.rect(11, 0, 12, 6, "9a9ab0", 1.0)
    s.rect(0, 6, 14, 14, "6b4a2e", 0.95)
    s.rect(1, 8, 6, 13, "2b2a33", 0.7)  # the speaker
    for y in (9, 11):
        s.rect(2, y, 5, y + 1, "2b2a33", 1.1)
    s.rect(8, 8, 13, 10, "e0c48a", 1.3)  # the dial, lit
    s.dot(10, 8, "c8443a", 1.2)
    s.rect(8, 11, 9, 12, "e0c48a", 1.0)
    s.rect(11, 11, 12, 12, "e0c48a", 1.0)
    out["radio"] = s.image()
    s = Sprite(13, 23)  # a potted plant
    s.rect(2, 16, 11, 23, "8a5a33", 0.9)
    s.rect(1, 16, 12, 17, "8a5a33", 1.15)
    for (x, y, r) in [(6, 9, 5), (3, 12, 3), (9, 11, 3), (6, 4, 3)]:
        for dy in range(-r, r + 1):
            for dx in range(-r, r + 1):
                if dx * dx + dy * dy <= r * r + 1:
                    s.dot(x + dx, y + dy, "4fa85a" if dy < 0 else "3f8f4a", 1.05 - 0.04 * dy)
    out["plants"] = s.image()
    s = Sprite(9, 12)  # a paper calendar, its red top, the days
    s.rect(0, 0, 9, 12, "f2ead8", 1.05)
    s.rect(0, 0, 9, 3, "c8443a", 1.0)
    for y in range(4, 11, 2):
        for x in range(1, 8, 2):
            s.dot(x, y, "6e6a78", 1.0)
    s.dot(5, 6, "c8443a", 1.1)  # a day marked
    out["calendar"] = s.image()
    s = Sprite(9, 12)  # the waving lucky cat
    s.rect(7, 0, 9, 5, "f5f2ea", 1.15)  # the raised paw
    s.rect(1, 1, 7, 6, "f5f2ea", 1.15)  # its head
    s.dot(1, 0, "f5f2ea", 1.1)
    s.dot(6, 0, "f5f2ea", 1.1)
    s.dot(2, 3, "1a1a20", 1.0)
    s.dot(5, 3, "1a1a20", 1.0)
    s.rect(0, 6, 8, 12, "f5f2ea", 1.0)
    s.rect(0, 6, 8, 7, "c8443a", 1.0)  # its collar
    s.dot(4, 7, "f2c14a", 1.3)  # the bell
    s.rect(2, 9, 6, 11, "f2c14a", 0.95)  # the coin it holds
    out["lucky_cat"] = s.image()
    s = Sprite(6, 7)  # an old photo, taped up
    s.rect(0, 0, 6, 7, "f2ead8", 1.0)
    s.rect(1, 1, 5, 5, "c9a87a", 0.9)
    s.rect(2, 2, 4, 4, "8a7766", 0.85)
    s.rect(2, 0, 4, 1, "e6dcc6", 1.2)  # the tape
    out["photos"] = s.image()
    s = Sprite(52, 27, light=0.85, fall=0.1)  # a fishing net hung in a corner, sagging
    for x in range(0, 52, 7):
        for y in range(27):
            s.dot(x + (y // 9) % 2, y, "cdb894", 0.85)
    for y in range(0, 27, 5):
        for x in range(52):
            s.dot(x, y + (1 if 12 < x < 40 else 0), "cdb894", 0.85)
    s.rect(0, 0, 52, 1, "8a5a33", 0.9)  # the cord it hangs from
    out["fishing_net"] = s.image()
    s = Sprite(26, 10)  # a rack of kitchen knives
    s.rect(0, 0, 26, 4, "3a2a1e", 0.9)
    for k in range(5):
        x = 3 + k * 5
        s.rect(x, 4, x + 1, 10 - (k % 2), "c8c8d8", 1.25)
        s.rect(x, 1, x + 2, 3, "1a1a20", 1.0)  # its handle in the rack
    out["knife_rack"] = s.image()
    return out
