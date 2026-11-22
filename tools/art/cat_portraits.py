"""The cat's portraits (PLAN.md, "The cat's portrait"): a face for each coat (rules/cat_rules.gd
CAT_COATS), for its hover and the captions about it, from the image model in the people's
portraits' style (tools/art/portraits.py's PROMPT, with a cat in it).

Unlike the people's portraits these are kept in the picture's own colours (there are only a few
coats, one picture each), so no split into hair, skin and cloth: the pixelate tool's palette
(pixelate.py) and its tidy, onto the same 64 x 80 frame the people's portraits use, the picture's
model's whole sitting cat framed to its head and chest, so a cat's head sits where a person's does.

    python3 tools/art/cat_portraits.py --sheet out.png   (every candidate in art/raw/, side by side)
    python3 tools/art/cat_portraits.py --keep            (the picks below into art/cat_portraits/,
                                                           the manifest and LICENSE-ASSETS)
    python3 tools/art/cat_portraits.py --self-test
"""
import argparse, glob, json, os, re, sys
import numpy as np
from PIL import Image

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import palette, pixelate

W, H = 64, 80  # as the people's portraits (portraits.py W, H)
RAW = os.path.join(palette.ROOT, "art", "raw")
COATS = ["ginger", "black", "white", "tabby", "calico", "grey"]  # (cat_rules.gd CAT_COATS; the self-test checks)
DESCRIBE = {
    "ginger": "a ginger cat, bright orange fur with paler stripes and a cream chin",
    "black": "a black cat, glossy jet black fur, bright yellow-green eyes",
    "white": "a white cat, fluffy pure white fur, pink nose and pink inner ears, blue eyes",
    "tabby": "a brown tabby cat, warm brown fur with bold dark brown tabby stripes and an M on the forehead",
    "calico": "a calico cat, mostly white fur with big patches of orange and black",
    "grey": "a grey cat, smooth solid blue-grey fur, amber eyes",
}
PROMPT = ("Head and shoulders portrait of {cat}, sitting and facing the viewer, ears up, neutral friendly expression. "
          "Flat cel-shaded illustration, simple shapes, clean dark outlines, two tones of shading, like a cozy visual "
          "novel character portrait. Plain flat green background, no text.")
PICKS = {"ginger": 9101, "black": 9102, "white": 9100, "tabby": 9100, "calico": 9102, "grey": 9100}  # coat -> the seed kept (picked from the sheet, 22 Nov 2026)


CLOSE = 25.0  # the background cut's closeness (pixelate.py's is 45): a ginger's cream chest and a tabby's tan
# face are near that green, and the cut flooded through them
FRAME = (1.05, 0.05)  # the close-up: as wide as the cat (times this), 4:5, its top this much of its height above the ears


def portrait(picture, close=CLOSE):
    """The picture as a 64 x 80 portrait in the palette's colours: RGBA PIL image. The model draws a
    whole cat sitting, so it's framed head and chest (FRAME), as a person's head and shoulders are."""
    rgba = np.asarray(picture.convert("RGBA"))
    colours, _, _ = palette.ramped()
    mask = pixelate.cut_background(rgba, close)
    ys, xs = np.nonzero(mask)
    if len(ys) == 0:
        raise SystemExit("Nothing left once the background's cut out")
    # The cat's body (its whiskers and shadow aside): the columns most of it is in.
    cols = np.nonzero(mask.sum(axis=0) > 0.15 * mask.sum(axis=0).max())[0]
    middle = (cols.min() + cols.max()) / 2
    fw = (cols.max() - cols.min() + 1) * FRAME[0]
    fh = fw * H / W
    top = ys.min() - FRAME[1] * fh
    box = (int(round(middle - fw / 2)), int(round(top)), int(round(middle + fw / 2)), int(round(top + fh)))
    pad = 600  # (room round the picture, see-through, for a box past its edge)
    big = np.zeros((rgba.shape[0] + 2 * pad, rgba.shape[1] + 2 * pad, 4), np.uint8)
    big[pad:-pad, pad:-pad] = rgba
    big_mask = np.zeros(big.shape[:2], bool)
    big_mask[pad:-pad, pad:-pad] = mask
    x0, y0, x1, y1 = (v + pad for v in box)
    crop, crop_mask = big[y0:y1, x0:x1], big_mask[y0:y1, x0:x1]
    scale = H / crop.shape[0]
    cy, cx = np.nonzero(crop_mask)
    out_h = max(1, round((cy.max() + 1 - cy.min()) * scale))
    index = pixelate.tidy(pixelate.shrink(crop, crop_mask, colours, height=out_h))
    frame = np.full((H, W), -1)
    left, top_px = round(cx.min() * scale), round(cy.min() * scale)
    h, w = min(index.shape[0], H - top_px), min(index.shape[1], W - left)
    frame[top_px:top_px + h, left:left + w] = index[:h, :w]
    out = np.zeros((H, W, 4), np.uint8)
    out[frame >= 0, :3] = colours[frame[frame >= 0]]
    out[frame >= 0, 3] = 255
    return Image.fromarray(out, "RGBA")


def candidates():
    """{coat: [(seed, path)]} from art/raw/catportrait_<coat>_<seed>.png."""
    found = {}
    for path in sorted(glob.glob(os.path.join(RAW, "catportrait_*_*.png"))):
        m = re.match(r"catportrait_([a-z]+)_(\d+)\.png$", os.path.basename(path))
        if m and m.group(1) in COATS:
            found.setdefault(m.group(1), []).append((int(m.group(2)), path))
    return found


def sheet(path, scale=4):
    """Each coat a row: every candidate, the picture small and the portrait beside it."""
    found = candidates()
    cols = max((len(v) for v in found.values()), default=1)
    cell = (W * scale * 2 + 24, H * scale + 24)
    out = Image.new("RGBA", (cell[0] * cols, cell[1] * len(COATS)), (40, 38, 64, 255))
    for row, coat in enumerate(COATS):
        for col, (seed, pic_path) in enumerate(found.get(coat, [])):
            picture = Image.open(pic_path)
            small = picture.convert("RGBA").resize((W * scale, H * scale))
            big = portrait(picture).resize((W * scale, H * scale), Image.NEAREST)
            x, y = col * cell[0] + 8, row * cell[1] + 8
            out.paste(small, (x, y))
            out.paste(big, (x + W * scale + 8, y), big)
            print("%s %d: %d%% covered" % (coat, seed, round(100 * (np.asarray(big)[..., 3] > 0).mean())))
    out.save(path)


def keep():
    """The picks into the game: art/cat_portraits/<coat>.png, the manifest and LICENSE-ASSETS."""
    for coat, seed in sorted(PICKS.items()):
        path = os.path.join(RAW, "catportrait_%s_%d.png" % (coat, seed))
        made = json.load(open(os.path.splitext(path)[0] + ".json", encoding="utf-8-sig"))
        source = "%s via ComfyUI, seed %s, then cat_portraits.py: \"%s\"" % (made["model"], made["seed"], made["prompt"])
        pixelate.add_to_game(portrait(Image.open(path)), "cat_portrait/" + coat, source, "CC BY-SA 4.0 (this project)")
    print("%d cat portraits into art/cat_portraits/, the manifest and LICENSE-ASSETS" % len(PICKS))


def self_test():
    rules = open(os.path.join(palette.ROOT, "scripts", "rules", "cat_rules.gd"), encoding="utf-8").read()
    line = rules[rules.index("const CAT_COATS"):].split("\n")[0]
    assert re.findall(r'"([a-z]+)":', line) == COATS, "COATS should be cat_rules.gd's CAT_COATS, in order"
    assert set(DESCRIBE) == set(COATS)
    # A made-up cat: a tall orange oval (sitting) in a green 768 x 960 frame, with dark eyes.
    pic = Image.new("RGB", (768, 960), (60, 200, 60))
    a = np.asarray(pic).copy()
    yy, xx = np.mgrid[0:960, 0:768]
    a[((xx - 384) / 250.0) ** 2 + ((yy - 560) / 380.0) ** 2 < 1] = (217, 136, 58)
    a[((xx - 300) ** 2 + (yy - 300) ** 2 < 30 ** 2) | ((xx - 468) ** 2 + (yy - 300) ** 2 < 30 ** 2)] = (20, 20, 25)
    out = portrait(Image.fromarray(a))
    assert out.size == (W, H)
    alpha = np.asarray(out)[..., 3]
    assert alpha[0, 0] == 0 and alpha[50, 32] == 255, "background cut, the cat kept"
    assert alpha[:2].sum() == 0 and alpha[5:].max() == 255, "framed from just above its top"
    assert alpha[-1].sum() > 0, "the close-up runs off the bottom, as a person's shoulders do"
    print("cat_portraits.py self-test: ok")


if __name__ == "__main__":
    ap = argparse.ArgumentParser()
    ap.add_argument("--sheet")
    ap.add_argument("--keep", action="store_true")
    ap.add_argument("--self-test", action="store_true")
    args = ap.parse_args()
    if args.self_test:
        self_test()
    if args.sheet:
        sheet(args.sheet)
    if args.keep:
        keep()
