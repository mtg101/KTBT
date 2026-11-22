"""A quick look at the tent's light, without the game: the tarp, the owner behind the counter,
the stools and people seated from behind, from the art in art/, lit at an hour as the game's
shader lights them (scripts/ui/pixel_light.gd: each pixel moved along its colour's ramp by the
night's light plus the bulbs'). For checking a change to how the art's shaded (ART.md) before
importing it into Godot.

    python3 tools/art/light_preview.py out.png [--minutes 1440] [--tarp orange_classic]
"""
import argparse, os, sys
import numpy as np
from PIL import Image

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import palette

GRID = 3
STAGE = (1872, 380)
SKY = (24, 26, 48)
# As pixel_light.gd (keep in step with it).
AMBIENT = [[18 * 60, -0.4], [19 * 60 + 30, -0.9], [21 * 60, -1.4], [24 * 60, -1.7], [26 * 60, -1.9], [27 * 60, -1.6]]
BULB_STEPS, BULB_REACH, BRIGHTEST = 1.25, 1000.0, 0.25
POOL_STEPS, POOL_REACH = 0.8, 450.0  # (read from pixel_light.gd)
KINDS = {"tent": 1.0, "people": 1.0, "tarp": 0.45}
DOWN_VALUE, UP_VALUE, BLUE_HUE, WARM_HUE = 0.72, 0.35, 0.64, 0.11
BULBS = [(621.0, 155.0), (1251.0, 155.0)]
SEAT_X = [470.0, 760.0, 1050.0, 1340.0, 1630.0]
FIXED = ["2a2a33", "1a1a20", "eef0f2", "9cc4e4", "8a2a35", "efe6d2", "f2c14a", "f5f2ea", "8a5a33", "cdb894",
         "3a3946", "c8443a", "5a3a2a", "2f8f4e", "8ec8f0", "f2899a"]
PEOPLE = [  # skin, hair, cloth, clothes, hair style
    ("e0b48e", "222026", "3a5a8a", "knit", "ponytail"),
    ("c99a74", "8a8c96", "4a3a2a", "padded", "short"),
    ("e8c0a0", "2a2026", "7a3a3a", "hoodie", "bob"),
    ("b88a64", "1a1a20", "5a5a64", "suit", "two_block"),
]
OWNER = ("d8a882", "a8a8b0", "c8443a", "knit", "perm")


def read_pixel_light():
    """The light's numbers from pixel_light.gd itself, so the preview can't drift from it."""
    global BULB_STEPS, BULB_REACH, BRIGHTEST, POOL_STEPS, POOL_REACH
    text = open(os.path.join(palette.ROOT, "scripts/ui/pixel_light.gd"), encoding="utf-8").read()
    import re
    for name in ("BULB_STEPS", "BULB_REACH", "BRIGHTEST", "POOL_STEPS", "POOL_REACH"):
        m = re.search(r"const %s := ([0-9.]+)" % name, text)
        if m:
            globals()[name] = float(m.group(1))


def art(path):
    return np.asarray(Image.open(os.path.join(palette.ROOT, "art", path)).convert("RGBA"))


def person(look, view):
    skin, hair, cloth, clothes, style = look
    ids = (["%s_hairback_long" % view] if style == "long" else []) + ["%s_body_%s" % (view, clothes)]
    if view == "front":
        ids.append("front_apron")
    ids += ["%s_head" % view, "%s_hair_%s" % (view, style)]
    out = np.zeros((72, 32, 4), np.uint8)
    slots = {1: skin, 2: hair, 3: cloth}
    for ident in ids:
        a = art("people/%s.png" % ident).astype(int)
        drawn = a[..., 3] > 0
        step = np.clip(np.round(a[..., 0] / 36), 0, 6).astype(int)
        slot = np.clip(np.round(a[..., 1] / 36), 0, 3).astype(int)
        fix = np.clip(np.round(a[..., 2] / 8), 0, len(FIXED) - 1).astype(int)
        for y, x in zip(*np.nonzero(drawn)):
            colour = slots[slot[y, x]] if slot[y, x] else FIXED[fix[y, x]]
            out[y, x, :3] = palette.ramp(palette.hexc(colour))[step[y, x]]
            out[y, x, 3] = 255
    return out


def ambient(minutes):
    for i in range(1, len(AMBIENT)):
        if minutes <= AMBIENT[i][0]:
            a, b = AMBIENT[i - 1], AMBIENT[i]
            return a[1] if minutes <= a[0] else a[1] + (b[1] - a[1]) * (minutes - a[0]) / (b[0] - a[0])
    return AMBIENT[-1][1]


def rgb_to_hsv(c):
    mx, mn = c.max(-1), c.min(-1)
    d = mx - mn
    h = np.zeros_like(mx)
    r, g, b = c[..., 0], c[..., 1], c[..., 2]
    nz = d > 1e-9
    h = np.where(nz & (mx == r), ((g - b) / np.where(nz, d, 1)) % 6, h)
    h = np.where(nz & (mx == g) & (mx != r), (b - r) / np.where(nz, d, 1) + 2, h)
    h = np.where(nz & (mx == b) & (mx != r) & (mx != g), (r - g) / np.where(nz, d, 1) + 4, h)
    return np.stack([h / 6.0, np.where(mx > 0, d / np.where(mx > 0, mx, 1), 0), mx], -1)


def hsv_to_rgb(hsv):
    h, s, v = hsv[..., 0], hsv[..., 1], hsv[..., 2]
    p = np.abs(((h[..., None] + np.array([1.0, 2 / 3, 1 / 3])) % 1.0) * 6 - 3)
    return v[..., None] * (1 + (np.clip(p - 1, 0, 1) - 1) * s[..., None])


def towards(h, to, share):
    return (h + (((to - h + 0.5) % 1.0) - 0.5) * share) % 1.0


def walk(hsv, n):
    hsv = hsv.copy()
    for i in range(4):
        down, up = i < -n, i < n
        z = np.where(down, hsv[..., 2] * DOWN_VALUE, np.where(up, hsv[..., 2] + (1 - hsv[..., 2]) * UP_VALUE, hsv[..., 2]))
        x = np.where(down, towards(hsv[..., 0], BLUE_HUE, 0.06), np.where(up, towards(hsv[..., 0], WARM_HUE, 0.05), hsv[..., 0]))
        y = np.where(down, np.minimum(1, hsv[..., 1] * 1.04), np.where(up, hsv[..., 1] * 0.94, hsv[..., 1]))
        hsv = np.stack([x, y, z], -1)
    return hsv


def lit(layer, kind, minutes):
    """A stage-sized RGBA layer lit as the shader lights that kind."""
    h, w = layer.shape[:2]
    yy, xx = np.mgrid[0:h, 0:w].astype(float)
    light = np.zeros((h, w))
    for bx, by in BULBS:
        d = np.hypot(xx - bx, yy - by)
        light += BULB_STEPS * np.clip(1 - d / BULB_REACH, 0, 1)
        if POOL_STEPS > 0:
            light += POOL_STEPS * np.clip(1 - d / POOL_REACH, 0, 1) ** 2
    steps = np.minimum(ambient(minutes) + KINDS[kind] * light, BRIGHTEST)
    hsv = rgb_to_hsv(layer[..., :3] / 255.0)
    if kind != "tarp":
        sm = lambda a, b, x: np.clip((x - a) / (b - a), 0, 1) ** 2 * (3 - 2 * np.clip((x - a) / (b - a), 0, 1))
        steps = steps * (1 - sm(0.78, 0.92, hsv[..., 2]) * sm(0.3, 0.55, hsv[..., 1]))
    whole = np.floor(steps)
    out = np.zeros((h, w, 3))
    for n in np.unique(whole).astype(int):
        m = whole == n
        below, above = hsv_to_rgb(walk(hsv[m], n)), hsv_to_rgb(walk(hsv[m], n + 1))
        f = (steps[m] - n)[:, None]
        out[m] = below * (1 - f) + above * f
    return np.concatenate([np.clip(out * 255, 0, 255), layer[..., 3:4]], -1).astype(np.uint8)


def place(canvas, img, at):
    big = np.repeat(np.repeat(img, GRID, 0), GRID, 1)
    x, y = int(at[0]), int(at[1])
    h, w = big.shape[:2]
    y0, x0 = max(y, 0), max(x, 0)
    y1, x1 = min(y + h, canvas.shape[0]), min(x + w, canvas.shape[1])
    part = big[y0 - y:y1 - y, x0 - x:x1 - x]
    m = part[..., 3] > 0
    canvas[y0:y1, x0:x1][m] = part[m]


def scene(minutes, tarp):
    out = Image.new("RGBA", STAGE, SKY + (255,))
    layers = [("tarp", [(art("tarps/%s.png" % tarp), (0, 0))]),
              ("people", [(person(OWNER, "front"), (936 - 48, 372 - 216 - 30))]),
              ("tent", [(art("tents/counter.png"), (99, 249))] + [(art("tents/stool_%s.png" % ("red" if k % 2 == 0 else "blue")), (x - 39, 312)) for k, x in enumerate(SEAT_X)]),
              ("people", [(person(PEOPLE[k % len(PEOPLE)], "back"), (x - 48, 372 - 216)) for k, x in enumerate(SEAT_X[:4])])]
    for kind, pieces in layers:
        canvas = np.zeros((STAGE[1], STAGE[0], 4), np.uint8)
        for img, at in pieces:
            place(canvas, img, at)
        out.alpha_composite(Image.fromarray(lit(canvas, kind, minutes), "RGBA"))
    return out


if __name__ == "__main__":
    ap = argparse.ArgumentParser()
    ap.add_argument("out")
    ap.add_argument("--minutes", type=float, default=24 * 60)
    ap.add_argument("--tarp", default="orange_classic")
    args = ap.parse_args()
    read_pixel_light()
    scene(args.minutes, args.tarp).save(args.out)
    print("wrote", args.out)
