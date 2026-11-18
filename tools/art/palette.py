"""KTBT's palette and its light ramps (ART.md, "The palette and its light ramps").

The base colours come from the game itself (the tarps, signs and touches in rules/bar_look.gd;
hair, clothes and skin in rules/looks.gd), so they never drift from what the game decides, plus
a fixed set for materials. Every base colour gets a ramp of 7 steps, from deep shadow (bluer) to
highlight (warmer). Art is drawn in ramp colours: a pixel's base colour says which ramp it's on,
and its step how lit it is (the game's light shader will move it along its own ramp).

Used by pixelate.py; run on its own to write a swatch: python3 tools/art/palette.py <out.png>
"""
import colorsys, os, re, sys
import numpy as np

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))  # the project

# Where the game keeps the colours it decides.
GAME_FILES = ["scripts/rules/bar_look.gd", "scripts/rules/looks.gd"]

# Materials the game draws but doesn't choose (ART.md, "The palette").
MATERIALS = {
    "wood": "8a5a33", "dark_wood": "5c3820", "red_plastic": "c8443a", "blue_plastic": "3a6ec8",
    "green_glass": "3f9e5a", "steel": "9a9ab0", "dark_steel": "3a3946", "steam": "eef0f2",
    "paper": "f2ead8", "ink": "1a1a20", "bulb": "ffd27f", "tarmac": "2a2840", "concrete": "6e6a78",
    "brick": "8a4a3a", "leaf": "3f8f4a", "fishcake": "e0c48a", "soup": "c8642a", "rice": "f5f2ea",
    # The street's buildings (the first street from the model went navy without them):
    "render": "c9b8a0", "grey_render": "8c8a90", "dark_render": "4a4850", "brown_render": "7a5a44",
    "dark_brown": "4a3428", "shutter": "a0a0a8", "window_glow": "ffe4a8", "rust": "8a3a2a",
}

LEVELS = [0.22, 0.36, 0.52, 0.72, 1.0, 1.22, 1.42]  # a ramp's steps: deep shadow ... highlight
BASE_STEP = 4  # the step a colour sits at in plain light
NEAR = 6.0  # base colours closer than this (in Lab) are one colour


def hexc(h):
    h = h.lstrip("#")
    return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4))


def ramp(rgb):
    """A colour's light ramp: 7 steps, shadows cooler (bluer, a little more saturated), light warmer."""
    h, sat, v = colorsys.rgb_to_hsv(*[c / 255.0 for c in rgb])
    out = []
    for k, f in enumerate(LEVELS):
        t = (k - BASE_STEP) / 4.0  # -1 (deepest shadow) .. +0.5 (highlight)
        hh = h
        if t < 0:  # toward blue
            hh = h + ((0.64 - h + 0.5) % 1.0 - 0.5) * 0.12 * -t
        else:  # toward warm yellow
            hh = h + ((0.11 - h + 0.5) % 1.0 - 0.5) * 0.10 * t
        ss = min(1.0, sat * (1 + 0.15 * -t)) if t < 0 else sat * (1 - 0.25 * t)
        vv = min(1.0, v * f) if f <= 1 else min(1.0, v + (1 - v) * (f - 1) * 1.4)
        out.append(tuple(int(round(c * 255)) for c in colorsys.hsv_to_rgb(hh % 1.0, ss, vv)))
    return out


def to_lab(rgb_array):
    """sRGB (0..255, shape (..., 3)) to CIE Lab, for judging how close colours look."""
    c = np.asarray(rgb_array, dtype=float) / 255.0
    c = np.where(c > 0.04045, ((c + 0.055) / 1.055) ** 2.4, c / 12.92)
    xyz = c @ np.array([[0.4124, 0.2126, 0.0193], [0.3576, 0.7152, 0.1192], [0.1805, 0.0722, 0.9505]])
    xyz = xyz / np.array([0.95047, 1.0, 1.08883])
    f = np.where(xyz > 0.008856, np.cbrt(xyz), 7.787 * xyz + 16 / 116)
    return np.stack([116 * f[..., 1] - 16, 500 * (f[..., 0] - f[..., 1]), 200 * (f[..., 1] - f[..., 2])], axis=-1)


def game_colours(root=ROOT):
    """Every colour the game's own tables name ("e8833a" in bar_look.gd and looks.gd)."""
    found = []
    for name in GAME_FILES:
        with open(os.path.join(root, name), encoding="utf-8") as f:
            found += re.findall(r'"([0-9a-fA-F]{6})"', f.read())
    return [c.lower() for c in found]


def base_colours(root=ROOT):
    """The palette's base colours: the game's, then the materials, near-duplicates merged."""
    kept = []
    for h in game_colours(root) + list(MATERIALS.values()):
        lab = to_lab(hexc(h))
        if all(np.linalg.norm(lab - to_lab(hexc(k))) >= NEAR for k in kept):
            kept.append(h)
    return kept


def ramped(root=ROOT):
    """Every colour art may use: (rgb array (n, 3), base index of each, step of each)."""
    rgbs, bases, steps = [], [], []
    for b, h in enumerate(base_colours(root)):
        for s, rgb in enumerate(ramp(hexc(h))):
            rgbs.append(rgb); bases.append(b); steps.append(s)
    return np.array(rgbs), np.array(bases), np.array(steps)


if __name__ == "__main__":
    from PIL import Image
    bases = base_colours()
    sw = Image.new("RGB", (7 * 12, len(bases) * 12))
    for row, h in enumerate(bases):
        for k, rgb in enumerate(ramp(hexc(h))):
            sw.paste(rgb, (k * 12, row * 12, k * 12 + 12, row * 12 + 12))
    sw.resize((sw.width * 3, sw.height * 3), Image.NEAREST).save(sys.argv[1] if len(sys.argv) > 1 else "palette.png")
    print("%d base colours, %d with their ramps" % (len(bases), len(bases) * 7))
