"""The people's style test (ART.md, "People"): a few people drawn in layers (body, clothes,
head, hair, extras) at the game's size, 27 x 50 pixels on the grid, facing us and from behind,
on their colours' light ramps. A test to judge the look, not yet the game's: the layers here
paint their colours directly; in the game a shader will.

    python3 tools/art/people_test.py <screenshot without people> <out folder>
"""
import os, sys
import numpy as np
from PIL import Image

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from fittings import Sprite

W, H = 27, 50
SKIN = ["f2d6bd", "e9c7a6", "ddb291", "c99c78"]
HAIR = {"black": "1d1c22", "dark_brown": "3e2c22", "grey": "9b9ba0", "white": "dcdcdc", "ash_brown": "8a7766"}
CLOTH = {"beige": "cdb894", "black": "26252b", "navy": "2c3a5c", "charcoal": "4a4a52", "cream": "efe6d2", "camel": "b08a5a",
         "pastel_pink": "e8b4c4", "white": "e8e6e0", "red": "b8323a", "mint": "a8dcc8"}
TROUSERS = "2a2a33"
SHOES = "1a1a20"


def ellipse(s, cx, cy, rx, ry, colour, light=None, rows=None):
    for y in range(int(cy - ry) - 1, int(cy + ry) + 2):
        for x in range(int(cx - rx) - 1, int(cx + rx) + 2):
            if ((x + 0.5 - cx) / rx) ** 2 + ((y + 0.5 - cy) / ry) ** 2 <= 1.0 and (rows is None or rows[0] <= y < rows[1]):
                l = light if light is not None else 1.05 - 0.2 * (x - (cx - rx)) / (2 * rx)  # lit from the left
                s.dot(x, y, colour, l)


def side_lit(s, x0, y0, x1, y1, colour, base=1.0):
    """A block lit from the upper left: its right side and its lower part in shadow."""
    for x in range(x0, x1):
        across = (x - x0) / max(x1 - x0 - 1, 1)
        s.rect(x, y0, x + 1, y1, colour, base - 0.28 * across)


def person(look, view):
    """One person: look = {"skin", "hair", "hair_colour", "clothes", "colour", "glasses", "apron", "bag", "age"}."""
    s = Sprite(W, H, light=1.0, fall=0.15)
    skin = SKIN[look.get("skin", 0)]
    hair = HAIR[look["hair_colour"]]
    cloth = CLOTH[look["colour"]]
    clothes = look["clothes"]
    front = view == "front"
    old = look.get("age", "30s") in ("60s", "70s")
    stoop = 1 if look.get("age") == "70s" else 0
    cx = 13.5
    # --- behind everything: long hair, the hood, a backpack
    if look["hair"] == "long":
        s.rect(7, 4, 20, 24 if not front else 22, hair, 0.85)
    if clothes == "hoodie" and not front:
        ellipse(s, cx, 13 + stoop, 6.5, 3.5, cloth, 0.75)
    # --- the legs (standing) or the seat (from behind, seated)
    if front:
        long_coat = clothes in ("trench", "padded")
        hem = 42 if long_coat else 33
        side_lit(s, 8, hem, 13, 48, TROUSERS, 0.85)
        side_lit(s, 14, hem, 19, 48, TROUSERS, 0.8)
        s.rect(7, 48, 13, 50, SHOES, 0.8)
        s.rect(14, 48, 20, 50, SHOES, 0.75)
    else:  # sitting on the stool: the seat of the trousers, wider, and the legs either side of it
        side_lit(s, 4, 40, 23, 46, TROUSERS, 0.8)
        side_lit(s, 3, 46, 7, 50, TROUSERS, 0.7)
        side_lit(s, 20, 46, 24, 50, TROUSERS, 0.65)
    # --- the body: shoulders, torso, arms
    top = 14 + stoop
    bottom = 42 if (front and clothes in ("trench", "padded")) else (34 if front else 41)
    shoulder = 4 if clothes != "padded" else 3
    side_lit(s, shoulder, top + 1, W - shoulder, bottom, cloth, 1.05)
    s.rect(shoulder + 1, top, W - shoulder - 1, top + 1, cloth, 1.1)  # the shoulders' line
    if front:  # arms down at the sides, a shade darker, hands showing
        side_lit(s, shoulder - 1, top + 2, shoulder + 2, bottom - 4, cloth, 0.8)
        side_lit(s, W - shoulder - 2, top + 2, W - shoulder + 1, bottom - 4, cloth, 0.7)
        sleeve_end = top + 8 if clothes == "tshirt" else bottom - 4
        if clothes == "tshirt":
            s.rect(shoulder - 1, sleeve_end, shoulder + 2, bottom - 4, skin, 0.95)
            s.rect(W - shoulder - 2, sleeve_end, W - shoulder + 1, bottom - 4, skin, 0.8)
        s.rect(shoulder - 1, bottom - 4, shoulder + 2, bottom - 2, skin, 0.95)  # hands
        s.rect(W - shoulder - 2, bottom - 4, W - shoulder + 1, bottom - 2, skin, 0.8)
        # what's at the front of the clothes
        if clothes in ("suit", "blazer"):
            shirt = "eef0f2" if clothes == "suit" else "9cc4e4"
            for k in range(6):  # the V of the shirt between the lapels
                s.rect(int(cx) - 3 + k // 2, top + 1 + k, int(cx) + 4 - k // 2, top + 2 + k, shirt, 1.15)
            if clothes == "suit":
                s.rect(int(cx), top + 2, int(cx) + 1, top + 10, "8a2a35", 1.0)  # the tie
            for y in (top + 12, top + 15):
                s.dot(int(cx), y, "1a1a20", 1.0)  # buttons
        elif clothes == "cardigan":
            s.rect(int(cx) - 2, top + 1, int(cx) + 3, bottom, "efe6d2", 1.1)  # the top underneath
            for y in range(top + 4, bottom - 2, 4):
                s.dot(int(cx) + 3, y, "f2c14a", 1.2)  # buttons
        elif clothes == "trench":
            s.rect(int(cx) - 4, top, int(cx) - 1, top + 4, cloth, 1.25)  # the collar
            s.rect(int(cx) + 2, top, int(cx) + 5, top + 4, cloth, 1.2)
            s.rect(shoulder, top + 16, W - shoulder, top + 18, cloth, 0.6)  # the belt
            s.rect(int(cx), top + 4, int(cx) + 1, bottom, cloth, 0.7)  # where it closes
        elif clothes == "padded":
            for y in range(top + 4, bottom, 5):
                s.rect(shoulder, y, W - shoulder, y + 1, cloth, 0.6)  # the quilting
            s.rect(int(cx) - 4, top - 1, int(cx) + 5, top + 2, cloth, 1.15)  # the high collar
        elif clothes == "hoodie":
            s.rect(int(cx) - 5, top, int(cx) + 6, top + 3, cloth, 1.2)  # the hood round the neck
            s.rect(int(cx) - 1, top + 3, int(cx), top + 8, "eef0f2", 1.0)  # the strings
            s.rect(int(cx) + 1, top + 3, int(cx) + 2, top + 7, "eef0f2", 1.0)
            s.rect(int(cx) - 4, bottom - 8, int(cx) + 5, bottom - 4, cloth, 0.7)  # the pocket
        elif clothes == "knit":
            s.rect(shoulder, bottom - 2, W - shoulder, bottom, cloth, 0.7)  # the ribbed hem
            s.rect(int(cx) - 3, top, int(cx) + 4, top + 1, cloth, 0.7)
    else:  # from behind: the back's seam, the collar, a hood
        if clothes in ("suit", "blazer", "trench"):
            s.rect(int(cx), top + 6, int(cx) + 1, bottom, cloth, 0.75)  # the back seam (a jacket's vent)
            s.rect(int(cx) - 3, top, int(cx) + 4, top + 1, cloth, 1.2)  # the collar
        elif clothes == "padded":
            for y in range(top + 4, bottom, 5):
                s.rect(shoulder, y, W - shoulder, y + 1, cloth, 0.6)
        elif clothes == "hoodie":
            ellipse(s, cx, top + 1, 6, 3, cloth, 0.95)  # the hood, down on the back
        side_lit(s, shoulder - 1, top + 2, shoulder + 2, bottom - 3, cloth, 0.8)  # arms, forward to the counter
        side_lit(s, W - shoulder - 2, top + 2, W - shoulder + 1, bottom - 3, cloth, 0.7)
    if look.get("apron") and front:
        s.rect(7, top + 4, 20, bottom + 4, "f5f2ea", 1.15)  # the apron, over the clothes
        s.rect(8, top, 9, top + 4, "f5f2ea", 1.1)  # its straps
        s.rect(18, top, 19, top + 4, "f5f2ea", 1.0)
        s.rect(10, top + 12, 17, top + 15, "f5f2ea", 0.85)  # its pocket
    if look.get("bag") == "tote" and front:
        s.rect(W - 5, top + 1, W - 4, top + 12, "8a5a33", 0.9)  # the strap
        s.rect(W - 6, top + 12, W - 1, top + 20, "cdb894", 0.95)
    # --- the neck and the head
    head_y = 1 + stoop
    s.rect(11, head_y + 11, 16, top + 1, skin, 0.75)  # the neck
    ellipse(s, cx, head_y + 6, 5.5, 6.5, skin)
    if front:
        s.dot(8, head_y + 6, skin, 0.8)  # ears
        s.dot(19, head_y + 6, skin, 0.7)
        s.dot(11, head_y + 6, "1a1a20", 1.0)  # eyes
        s.dot(16, head_y + 6, "1a1a20", 1.0)
        s.rect(12, head_y + 9, 16, head_y + 10, skin, 0.7)  # the mouth, a shadow
        if old:
            s.dot(10, head_y + 8, skin, 0.8)  # lines by the eyes
            s.dot(17, head_y + 8, skin, 0.8)
        if look.get("glasses"):
            for gx in (10, 15):
                s.rect(gx, head_y + 5, gx + 3, head_y + 6, "1a1a20", 0.9)
                s.dot(gx, head_y + 6, "1a1a20", 0.9)
                s.dot(gx + 2, head_y + 6, "1a1a20", 0.9)
            s.dot(13, head_y + 5, "1a1a20", 0.9)
    else:
        s.dot(8, head_y + 6, skin, 0.8)
        s.dot(19, head_y + 6, skin, 0.7)
    # --- the hair
    h = look["hair"]
    if front:
        rows = {"long": 5, "bob": 5, "ponytail": 4, "bun": 4, "pixie": 4, "perm": 5, "short": 4, "side_part": 4,
                "buzz": 3, "two_block": 6, "balding": 0}[h]
        if h == "perm":
            for k, x in enumerate(range(7, 21, 2)):  # tight curls, a bumpy crown
                ellipse(s, x + 1, head_y + 2 + (k % 2), 1.8, 2.2, hair)
            ellipse(s, 8, head_y + 6, 1.5, 2.5, hair)
            ellipse(s, 19, head_y + 6, 1.5, 2.5, hair)
        elif h == "balding":
            s.rect(7, head_y + 4, 9, head_y + 8, hair, 0.9)  # what's left, over the ears
            s.rect(18, head_y + 4, 20, head_y + 8, hair, 0.8)
        else:
            ellipse(s, cx, head_y + 4, 6, 4.5, hair, rows=(0, head_y + rows + 1))
            if h in ("long", "bob"):
                s.rect(7, head_y + 3, 9, head_y + (14 if h == "long" else 10), hair, 0.9)  # down the sides
                s.rect(18, head_y + 3, 20, head_y + (14 if h == "long" else 10), hair, 0.8)
            if h == "side_part":
                s.rect(10, head_y + 1, 11, head_y + 3, hair, 1.25)  # the parting's shine
            if h == "two_block":
                s.rect(9, head_y + 4, 17, head_y + 6, hair, 0.95)  # the long fringe
            if h == "bun":
                ellipse(s, cx, head_y - 1.5, 2.5, 2, hair)
            if h == "ponytail":
                s.rect(20, head_y + 4, 22, head_y + 11, hair, 0.8)
    else:  # from behind, the hair covers the head
        if h == "balding":
            s.rect(8, head_y + 7, 20, head_y + 11, hair, 0.85)  # what's left, low round the back
            s.rect(8, head_y + 5, 10, head_y + 7, hair, 0.8)
            s.rect(18, head_y + 5, 20, head_y + 7, hair, 0.75)
        elif h == "perm":
            for k, x in enumerate(range(7, 21, 2)):
                for y in (head_y + 2, head_y + 5, head_y + 8):
                    ellipse(s, x + 1, y + (k % 2), 1.8, 2, hair)
        else:
            bottom_hair = {"long": 22, "bob": 11, "buzz": 9, "pixie": 10}.get(h, 10)
            ellipse(s, cx, head_y + 6, 6, 6.5, hair, rows=(0, head_y + min(bottom_hair, 12)))
            if h == "long":
                s.rect(8, head_y + 10, 20, head_y + bottom_hair, hair, 0.85)
            if h == "ponytail":
                s.rect(12, head_y + 9, 15, head_y + 17, hair, 0.85)
                s.rect(12, head_y + 8, 15, head_y + 9, "c8443a", 1.0)  # the tie
            if h == "bun":
                ellipse(s, cx, head_y + 2, 3, 2.5, hair, 1.1)
    if look.get("bag") == "backpack" and not front:
        side_lit(s, 8, top + 3, 19, top + 16, "3a3946", 0.9)
        s.rect(8, top + 3, 19, top + 4, "3a3946", 1.1)
    return s.image(dither=0)


PEOPLE = {
    "owner": {"skin": 1, "hair": "perm", "hair_colour": "grey", "clothes": "cardigan", "colour": "mint", "apron": True, "age": "60s"},
    "salaryman": {"skin": 0, "hair": "side_part", "hair_colour": "black", "clothes": "suit", "colour": "navy", "glasses": True, "age": "30s"},
    "student": {"skin": 2, "hair": "two_block", "hair_colour": "dark_brown", "clothes": "hoodie", "colour": "charcoal", "bag": "backpack", "age": "20s"},
    "grandad": {"skin": 3, "hair": "balding", "hair_colour": "white", "clothes": "padded", "colour": "black", "age": "70s"},
    "nurse": {"skin": 0, "hair": "long", "hair_colour": "ash_brown", "clothes": "trench", "colour": "beige", "bag": "tote", "age": "20s"},
}


if __name__ == "__main__":
    shot, out = sys.argv[1], sys.argv[2]
    # A sheet: each, facing us and from behind, big.
    names = list(PEOPLE)
    sheet = Image.new("RGBA", (len(names) * (W * 2 + 6) + 6, H + 8), (40, 38, 64, 255))
    for k, name in enumerate(names):
        sheet.alpha_composite(person(PEOPLE[name], "front"), (6 + k * (W * 2 + 6), 4))
        sheet.alpha_composite(person(PEOPLE[name], "back"), (6 + k * (W * 2 + 6) + W, 4))
    sheet.resize((sheet.width * 6, sheet.height * 6), Image.NEAREST).save(os.path.join(out, "people_sheet.png"))
    # In the tent: the owner behind the counter (facing us), three at the counter (from behind),
    # one walking past (facing us). Stage coordinates, as the game's; the stage's top at 141 on screen.
    scene = Image.open(shot).convert("RGBA")
    def put(img, stage_x, stage_y):
        big = img.resize((W * 3, H * 3), Image.NEAREST)
        scene.alpha_composite(big, (int(24 + stage_x), int(141 + stage_y)))
    counter_top = scene.crop((24 + 99, 141 + 249, 24 + 1791, 141 + 372))  # (the counter goes back in front of the owner)
    put(person(PEOPLE["owner"], "front"), 900, 150)
    scene.alpha_composite(counter_top, (24 + 99, 141 + 249))
    for seat_x, name in [(470, "salaryman"), (1050, "student"), (1340, "grandad")]:
        put(person(PEOPLE[name], "back"), seat_x - 40, 190)
    put(person(PEOPLE["nurse"], "front"), 1700, 222)
    scene.crop((0, 0, 1920, 540)).save(os.path.join(out, "people_in_tent.png"))
    print("people_sheet.png, people_in_tent.png")
