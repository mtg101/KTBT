"""Portraits, stage 1: trying it without Godot (PLAN.md, "Portraits").

An image model's head-and-shoulders picture becomes a portrait layer in the people's own encoding
(tools/art/people.py: each pixel's light step and what it's made of: skin, hair, cloth or a fixed
colour), so the game can paint it onto anyone's hair, skin and clothes ramps the way it paints the
people on stage (scripts/ui/people_art.gd), and one picture serves every colour.

Ask the model for black hair and a plain bright red top on a flat green background (the prompt
in PROMPT below): black, red and skin are far apart, so the picture splits into its parts cleanly.

    python3 tools/art/portraits.py <picture> [<picture>...] --sheet out.png [--layers folder]
        [--width 64 --height 80] [--sizes out.png]
    python3 tools/art/portraits.py --self-test

What it does, for each picture:
 1. Cuts the background out (pixelate.py's cut_background).
 2. Says what each of the picture's pixels is: cloth (strongly red), hair (the big dark and grey
    areas: thin dark lines don't survive an opening, so outlines, brows, eyes and glasses frames
    are left as lines), a line (dark, not hair), or skin (the rest: face, neck, lips, ears).
 3. Each part's light: its own median is the plain-light step (4), and each pixel a step up or
    down for every STEP_L of lightness from it, so black hair keeps its shine on blonde too.
 4. Onto the grid (the picture's frame, 4:5 like 64x80): each game pixel the part most of its
    samples are (a line wins if it's a fair share), at that part's commonest step.
 5. The layer (people.py's encoding: red = step x 36, green = slot x 36, blue = fixed x 8), and
    previews painted onto looks from rules/looks.gd's own colours, all on one contact sheet.
Prints each portrait's share of hair, skin, cloth and lines, so a bad split shows in the log.
"""
import argparse, os, re, sys
import numpy as np
from PIL import Image, ImageFilter

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import palette, pixelate

PROMPT = ("Head and shoulders portrait of a Korean {who} with {hair}, wearing a plain bright red top, facing the "
          "viewer, neutral friendly expression. Flat cel-shaded illustration, simple shapes, clean dark outlines, "
          "two tones of shading, like a cozy visual novel character portrait. Plain flat green background, no text.")

W, H = 64, 80  # the portrait on the grid (stage 1's pick; --width/--height to try others)
SKIN, HAIR, CLOTH, FIXED_SLOT = 1, 2, 3, 0  # as people.py
INK = 1  # people_art.gd FIXED: "ink"
LINE = 9  # (a part of its own while working: drawn as the fixed ink)
STEP_L = 11.0  # Lab lightness per light step, from a part's median
LINE_SHARE = 0.22  # a line wins a game pixel it's this much of
HAIR_MIN = 0.003  # a dark area this much of the picture (after the opening) is hair, not a line
NIGHT = (40, 38, 64)


def looks_colours():
    """Hair, clothes and skin colours from rules/looks.gd, so the previews are the game's."""
    text = open(os.path.join(palette.ROOT, "scripts/rules/looks.gd"), encoding="utf-8").read()

    def block(name):
        start = text.index("const %s" % name)
        return text[start:text.index("\n}", start)]
    hair = dict(re.findall(r'"(\w+)": \["([0-9a-f]{6})"', block("HAIR_COLOURS")))
    clothes = dict(re.findall(r'"(\w+)": \["([0-9a-f]{6})"', block("CLOTHES_COLOURS")))
    line = text[text.index("const SKIN_TONES"):]
    skins = re.findall(r'"([0-9a-f]{6})"', line[:line.index("]")])
    return hair, clothes, skins


def fixed_colours():
    text = open(os.path.join(palette.ROOT, "scripts/ui/people_art.gd"), encoding="utf-8").read()
    block = text[text.index("const FIXED"):text.index("]", text.index("const FIXED"))]
    return re.findall(r'"([0-9a-fA-F]{6})"', block)


def open_mask(mask, size):
    """An opening: what's thinner than size goes (lines), big areas stay."""
    img = Image.fromarray(mask.astype(np.uint8) * 255)
    return np.asarray(img.filter(ImageFilter.MinFilter(size)).filter(ImageFilter.MaxFilter(size))) > 0


def big_areas(mask, share):
    """The parts of mask that join up into areas at least share of the picture (worked on small)."""
    h, w = mask.shape
    sw, sh = max(1, w // 4), max(1, h // 4)
    small = np.asarray(Image.fromarray(mask.astype(np.uint8) * 255).resize((sw, sh), Image.NEAREST)) > 0
    seen = np.zeros_like(small); keep = np.zeros_like(small)
    for y0 in range(sh):
        for x0 in range(sw):
            if not small[y0, x0] or seen[y0, x0]:
                continue
            area, stack = [], [(y0, x0)]
            seen[y0, x0] = True
            while stack:
                y, x = stack.pop(); area.append((y, x))
                for dy, dx in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                    ny, nx = y + dy, x + dx
                    if 0 <= ny < sh and 0 <= nx < sw and small[ny, nx] and not seen[ny, nx]:
                        seen[ny, nx] = True; stack.append((ny, nx))
            if len(area) >= share * sw * sh:
                for y, x in area:
                    keep[y, x] = True
    return np.asarray(Image.fromarray(keep.astype(np.uint8) * 255).resize((w, h), Image.NEAREST)) > 0


def parts(rgba):
    """Each picture pixel's part (-1 background, SKIN, HAIR, CLOTH, LINE) and its Lab lightness."""
    fg = pixelate.cut_background(rgba)
    lab = palette.to_lab(rgba[..., :3])
    L, a, b = lab[..., 0], lab[..., 1], lab[..., 2]
    chroma = np.hypot(a, b)
    cloth = fg & (a > 38) & (L < 62) & (chroma > 45)
    hairish = fg & ~cloth & (L < 62) & (chroma < 16)
    size = max(5, rgba.shape[1] // 70) | 1  # (thicker than the model's outlines: 11 at 768 wide; odd, for PIL)
    hair_core = big_areas(open_mask(hairish, size), HAIR_MIN)
    near_core = np.asarray(Image.fromarray(hair_core.astype(np.uint8) * 255).filter(ImageFilter.MaxFilter(size + 2))) > 0
    hair = hairish & near_core
    line = fg & ~cloth & ~hair & (L < 40)
    part = np.full(L.shape, -1)
    part[fg] = SKIN
    part[cloth] = CLOTH
    part[hair] = HAIR
    part[line] = LINE
    return part, L


def steps_of(part, L):
    """Each pixel's light step on its part's ramp: the part's median is step 4."""
    step = np.full(part.shape, 4)
    for p, (lo, hi) in ((SKIN, (1, 6)), (HAIR, (1, 6)), (CLOTH, (1, 6))):
        where = part == p
        if where.any():
            mid = np.median(L[where])
            step[where] = np.clip(4 + np.round((L[where] - mid) / STEP_L), lo, hi).astype(int)
    return step


def to_grid(part, step, width=W, height=H):
    """The game pixels: (part, step) each, from the picture's whole frame."""
    h, w = part.shape
    out_part = np.full((height, width), -1); out_step = np.zeros((height, width), int)
    ys = np.linspace(0, h, height + 1).astype(int); xs = np.linspace(0, w, width + 1).astype(int)
    for j in range(height):
        for i in range(width):
            cp = part[ys[j]:ys[j + 1], xs[i]:xs[i + 1]].ravel()
            cs = step[ys[j]:ys[j + 1], xs[i]:xs[i + 1]].ravel()
            drawn = cp >= 0
            if drawn.sum() < len(cp) / 2:
                continue
            cp, cs = cp[drawn], cs[drawn]
            if (cp == LINE).sum() >= LINE_SHARE * len(cp):
                out_part[j, i] = LINE
                continue
            values, counts = np.unique(cp[cp != LINE], return_counts=True)
            if len(values) == 0:
                out_part[j, i] = LINE
                continue
            p = values[np.argmax(counts)]
            sv, sc = np.unique(cs[cp == p], return_counts=True)
            out_part[j, i] = p; out_step[j, i] = sv[np.argmax(sc)]
    return out_part, out_step


def portrait(picture, width=W, height=H):
    """A picture to its portrait: (part, step) grids, and each part's share."""
    rgba = np.asarray(picture.convert("RGBA").resize((width * 12, height * 12), Image.LANCZOS)
                      if picture.size != (width * 12, height * 12) else picture.convert("RGBA"))
    part, L = parts(rgba)
    gp, gs = to_grid(part, steps_of(part, L), width, height)
    drawn = max(1, (gp >= 0).sum())
    shares = {name: (gp == p).sum() / drawn for name, p in (("hair", HAIR), ("skin", SKIN), ("cloth", CLOTH), ("lines", LINE))}
    return gp, gs, shares


def layer(gp, gs):
    """people.py's encoding: red = step x 36, green = slot x 36, blue = fixed x 8; alpha where drawn."""
    out = np.zeros(gp.shape + (4,), np.uint8)
    drawn = gp >= 0
    slot = np.where(gp == LINE, FIXED_SLOT, gp)
    out[..., 0] = np.where(gp == LINE, 0, gs) * 36
    out[..., 1] = np.clip(slot, 0, 7) * 36
    out[..., 2] = np.where(gp == LINE, INK * 8, 0)
    out[..., 3] = np.where(drawn, 255, 0)
    return Image.fromarray(out, "RGBA")


def paint(gp, gs, hair, skin, cloth, ink):
    """The portrait painted onto a look's colours (hex each), each pixel on its part's ramp."""
    ramps = {HAIR: palette.ramp(palette.hexc(hair)), SKIN: palette.ramp(palette.hexc(skin)),
             CLOTH: palette.ramp(palette.hexc(cloth))}
    out = np.zeros(gp.shape + (4,), np.uint8)
    for p, r in ramps.items():
        for s in range(7):
            where = (gp == p) & (gs == s)
            out[where, :3] = r[s]; out[where, 3] = 255
    out[gp == LINE, :3] = palette.hexc(ink); out[gp == LINE, 3] = 255
    return Image.fromarray(out, "RGBA")


# The looks on the sheet: (hair colour, skin tone, clothes colour), by looks.gd's ids.
LOOKS = [("black", 0, "red"), ("dark_brown", 1, "beige"), ("ash_brown", 0, "black"), ("pink", 2, "navy"),
         ("blonde", 3, "sky_blue"), ("grey", 3, "camel"), ("white", 1, "mint")]


def sheet(pictures, path, width=W, height=H, scale=3, layers_to=None):
    """One row per picture: the picture, then the portrait painted onto each of LOOKS."""
    hairs, clothes, skins = looks_colours()
    ink = fixed_colours()[INK]
    cell_w, cell_h = width * scale + 8, height * scale + 8
    rows = []
    for name in pictures:
        picture = Image.open(name)
        gp, gs, shares = portrait(picture, width, height)
        print("%s: %dx%d, %s" % (os.path.basename(name), width, height,
                                 ", ".join("%s %d%%" % (k, round(v * 100)) for k, v in shares.items())))
        if layers_to:
            os.makedirs(layers_to, exist_ok=True)
            layer(gp, gs).save(os.path.join(layers_to, os.path.splitext(os.path.basename(name))[0] + "_layer.png"))
        thumb = picture.convert("RGBA"); thumb.thumbnail((cell_w - 8, cell_h - 8))
        row = Image.new("RGBA", (cell_w * (len(LOOKS) + 1), cell_h), NIGHT + (255,))
        row.paste(thumb, (4, 4), thumb)
        for k, (h, s, c) in enumerate(LOOKS):
            img = paint(gp, gs, hairs[h], skins[s], clothes[c], ink).resize((width * scale, height * scale), Image.NEAREST)
            row.paste(img, (cell_w * (k + 1) + 4, 4), img)
        rows.append(row)
    out = Image.new("RGBA", (rows[0].width, cell_h * len(rows)), NIGHT + (255,))
    for k, row in enumerate(rows):
        out.paste(row, (0, k * cell_h))
    out.save(path)
    print("sheet: %s (%d portraits x %d looks)" % (path, len(rows), len(LOOKS)))


def sizes(pictures, path, scale=3):
    """The same portraits at a few sizes, each shown at the same scale on screen (for settling the size)."""
    hairs, clothes, skins = looks_colours()
    ink = fixed_colours()[INK]
    trial = [(40, 50), (48, 60), (64, 80), (80, 100)]
    col_w = max(w for w, _ in trial) * scale + 8
    out = Image.new("RGBA", (col_w * len(trial), (100 * scale + 8) * len(pictures)), NIGHT + (255,))
    for r, name in enumerate(pictures):
        picture = Image.open(name)
        for k, (w, h) in enumerate(trial):
            gp, gs, _ = portrait(picture, w, h)
            img = paint(gp, gs, hairs["dark_brown"], skins[1], clothes["beige"], ink).resize((w * scale, h * scale), Image.NEAREST)
            out.paste(img, (k * col_w + 4, r * (100 * scale + 8) + 4), img)
    out.save(path)
    print("sizes: %s (%s)" % (path, ", ".join("%dx%d" % t for t in trial)))


def self_test():
    """A made-up portrait (black hair, skin face with dark eyes and a red top, blurred, on green) splits right."""
    rng = np.random.default_rng(2)
    pic = np.zeros((960, 768, 3), float); pic[:] = (120, 180, 110)
    yy, xx = np.mgrid[0:960, 0:768]
    pic[((xx - 384) / 230) ** 2 + ((yy - 330) / 280) ** 2 < 1] = (20, 20, 24)  # the hair
    face = ((xx - 384) / 170) ** 2 + ((yy - 380) / 210) ** 2 < 1
    pic[face] = (245, 222, 200)
    for ex in (320, 448):
        pic[((xx - ex) / 18) ** 2 + ((yy - 370) / 6) ** 2 < 1] = (15, 15, 18)  # thin dark eyes: lines, not hair
    pic[(yy > 620)] = (225, 45, 45)  # the red top
    pic[(yy > 616) & (yy < 626)] = (15, 15, 18)  # its neckline, a line
    img = Image.fromarray(np.clip(pic, 0, 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(2))
    noisy = np.clip(np.asarray(img).astype(float) + rng.normal(0, 4, pic.shape), 0, 255).astype(np.uint8)
    gp, gs, shares = portrait(Image.fromarray(noisy))
    problems = []
    if gp[70, 32] != CLOTH:
        problems.append("the top isn't cloth (%d)" % gp[70, 32])
    if gp[32, 32] != SKIN:
        problems.append("the middle of the face isn't skin (%d)" % gp[32, 32])
    if gp[10, 32] != HAIR:
        problems.append("the top of the head isn't hair (%d)" % gp[10, 32])
    eyes = gp[30:33, 25:29]
    if not (eyes == LINE).any():
        problems.append("the eyes went (or became hair)")
    if (eyes == HAIR).any():
        problems.append("an eye became hair")
    if gp[2, 2] != -1:
        problems.append("the background's still there")
    enc = np.asarray(layer(gp, gs))
    if not ((enc[..., 1] // 36 == SKIN) & (enc[..., 3] == 255)).any():
        problems.append("the layer has no skin slot")
    hairs, clothes, skins = looks_colours()
    blonde = np.asarray(paint(gp, gs, hairs["blonde"], skins[0], clothes["navy"], fixed_colours()[INK]))
    if tuple(blonde[10, 32, :3]) not in [tuple(c) for c in palette.ramp(palette.hexc(hairs["blonde"]))]:
        problems.append("blonde hair isn't on the blonde ramp")
    print("\n".join(problems) if problems else "portraits self-test: OK (%s)" % ", ".join("%s %d%%" % (k, round(v * 100)) for k, v in shares.items()))
    return not problems


if __name__ == "__main__":
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("pictures", nargs="*")
    ap.add_argument("--sheet"); ap.add_argument("--sizes"); ap.add_argument("--layers")
    ap.add_argument("--width", type=int, default=W); ap.add_argument("--height", type=int, default=H)
    ap.add_argument("--self-test", action="store_true")
    a = ap.parse_args()
    if a.self_test:
        sys.exit(0 if self_test() else 1)
    if not a.pictures or not (a.sheet or a.sizes):
        ap.error("pictures, and --sheet and/or --sizes")
    if a.sheet:
        sheet(a.pictures, a.sheet, a.width, a.height, layers_to=a.layers)
    if a.sizes:
        sizes(a.pictures[:3], a.sizes)
