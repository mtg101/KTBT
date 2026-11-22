"""Portraits, stage 1: trying it without Godot (PLAN.md, "Portraits").

An image model's head-and-shoulders picture becomes a portrait layer in the people's own encoding
(tools/art/people.py: each pixel's light step and what it's made of: skin, hair, cloth or a fixed
colour), so the game can paint it onto anyone's hair, skin and clothes ramps the way it paints the
people on stage (scripts/ui/people_art.gd), and one picture serves every colour.

Ask the model for black hair and a plain bright red top on a flat green background (the prompt
in PROMPT below): black, red and skin are far apart, so the picture splits into its parts cleanly.

    python3 tools/art/portraits.py <picture> [<picture>...] --sheet out.png [--layers folder]
        [--width 64 --height 80] [--sizes out.png]
    python3 tools/art/portraits.py --batch      (the library's jobs, for the helper's queue_art_batch)
    python3 tools/art/portraits.py --reactions  (the reaction faces' jobs: every kept portrait in every TV mood)
    python3 tools/art/portraits.py --pick art/raw/portrait_pick   (pick sheets, and art/raw/portrait_picks.json)
    python3 tools/art/portraits.py --keep       (the picks into art/portraits/, the manifest and LICENSE-ASSETS)
    python3 tools/art/portraits.py --react-pick art/raw/react_pick [--only w_20s]   (the reaction faces' close-ups,
        split once into art/raw/react_split/, pick sheets, and art/raw/reaction_picks.json)
    python3 tools/art/portraits.py --react-keep  (the reaction picks into art/reactions/, the manifest and LICENSE-ASSETS)
    python3 tools/art/portraits.py --self-test
    python3 tools/art/portraits.py --expect tests/support/portraits   (what the game's own split, scripts/rules/
        portrait_split.gd, should make of the pictures there: each one's layer and expected.json, for its test;
        a folder of react_ pictures, as tests/support/reactions, gets the reaction split's close-ups, layers and picks)

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

The reaction faces (PLAN.md): each kept portrait redrawn by Klein in each TV mood, then cut to a close-up
of the face (close_up()) before the split, which also keeps three colours of their own as fixed colours
(the whites of the eyes and teeth, tears, a blush), so a recolour can't muddy them. Pre-picked by how much
the hair and outline match the calm close-up (a different person's the risk) and whether the mood's own
colour came through.
"""
import argparse, os, re, sys
import numpy as np
from PIL import Image, ImageFilter

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import palette, pixelate

PROMPT = ("Head and shoulders portrait of a Korean {who} with {hair}, wearing a plain bright red top, facing the "
          "viewer, neutral friendly expression. Flat cel-shaded illustration, simple shapes, clean dark outlines, "
          "two tones of shading, like a cozy visual novel character portrait. Plain flat green background, no text.")

# The library (PLAN.md, Portraits): every gender x age range x hairstyle looks.gd can pick (balding only
# from 50; non-binary customers, one in a hundred, are left to the pick rule), with and without glasses,
# each hairstyle by its shape, not its name ("a perm" came back a plain cut). BATCH_SEEDS of each to pick from.
HAIR_SHAPES = {
    "long": "long straight black hair falling past the shoulders",
    "bob": "black hair cut in a chin-length bob",
    "ponytail": "black hair pulled back tightly into a ponytail behind the head, forehead showing",
    "bun": "black hair pulled up into a round bun on top of the head, forehead showing",
    "pixie": "very short cropped black hair, a pixie cut with the ears showing",
    "perm": "very curly, tightly permed short black hair in small curls all over",
    "short": "short neat black hair",
    "side_part": "black hair neatly combed with a side parting",
    "buzz": "a very short black buzz cut, close to the scalp",
    "two_block": "black hair in a two-block cut, shaved short at the sides and longer on top, with a long fringe over the forehead",
    "balding": "a bald top with a receding hairline and a little short black hair at the sides",
}
HAIRS_BY_GENDER = {"woman": ["long", "bob", "ponytail", "bun", "pixie", "perm"],
                   "man": ["short", "side_part", "buzz", "two_block", "balding"]}
AGES = {"20s": ("twenties", ""), "30s": ("thirties", ""), "40s": ("forties", ""),
        "50s": ("fifties", "a few lines on {p} face"), "60s": ("sixties", "lines and wrinkles on {p} face"),
        "70s": ("seventies", "an old, wrinkled face")}
BATCH_SEEDS = 3
BATCH_FIRST_SEED = 8000


def batch_jobs():
    """The library's jobs for the helper's queue_art_batch: [{name, prompt, seed, count, width, height}]."""
    jobs = []
    for gender, hairs in HAIRS_BY_GENDER.items():
        p = "her" if gender == "woman" else "his"
        for age, age_words in AGES.items():
            for hair in hairs:
                if hair == "balding" and age in ("20s", "30s", "40s"):
                    continue
                for glasses in (False, True):
                    decade, face = age_words
                    who = "%s in %s %s" % (gender, p, decade)
                    look = HAIR_SHAPES[hair] + (", " + face.format(p=p) if face else "") + (", and thin-framed glasses" if glasses else ", and no glasses")
                    name = "portrait_%s_%s_%s%s" % (gender[0], age, hair, "_glasses" if glasses else "")
                    jobs.append({"name": name, "prompt": PROMPT.format(who=who, hair=look),
                                 "seed": BATCH_FIRST_SEED + 10 * len(jobs), "count": BATCH_SEEDS,
                                 "width": W * 12, "height": H * 12})
    return jobs


# The reaction faces (PLAN.md, TV pop-ups): each kept portrait redrawn by Klein's edit workflow with
# the expression of each TV mood (rules/captions.gd REACTIONS), everything else kept.
# Glasses said outright: "same glasses if any" put glasses on nearly every face that had none (22 Nov).
REACT_PROMPT = ("Same person, same face, same hair, {glasses}, same red top, same flat green background, "
                "same framing and the same flat cel-shaded illustration style. Change only the facial expression: {face}.")
REACT_GLASSES = {True: "same glasses", False: "no glasses (bare eyes, as in the picture)"}
MOOD_FACES = {
    "shock": "wide-eyed with shock, eyebrows raised high, mouth dropped open",
    "sad": "sad, eyes glistening with tears, a tear on one cheek, mouth turned down",
    "sweet": "shy and flustered, pink blushing cheeks, a small bashful smile, eyes glancing aside",
    "warm": "deeply touched, a soft warm smile, eyes a little teary",
    "funny": "laughing hard, eyes squeezed shut, mouth wide open",
    "awkward": "awkward, a stiff forced smile, eyes glancing sideways, a bead of sweat on the forehead",
    "roast": "caught out and indignant, frowning, cheeks puffed out, pouting",
}
REACT_SEEDS = 2
REACT_FIRST_SEED = 20000
REACT_BARE_FIRST_SEED = 40000  # (the faces without glasses, made again with REACT_GLASSES said: new seeds, new pictures)


def reaction_jobs():
    """Every kept portrait (portrait_picks.json) in every mood: jobs for the helper's queue_art_batch, each
    with its reference picture."""
    import json
    picks = json.load(open(os.path.join(palette.ROOT, "art", "raw", "portrait_picks.json"), encoding="utf-8"))
    jobs = []
    for name, seed in sorted(picks.items()):
        if seed is None:
            continue
        glasses = name.endswith("_glasses")
        for mood, face in MOOD_FACES.items():
            first = REACT_FIRST_SEED if glasses else REACT_BARE_FIRST_SEED
            jobs.append({"name": "react_%s_%s" % (name.replace("portrait_", ""), mood),
                         "prompt": REACT_PROMPT.format(face=face, glasses=REACT_GLASSES[glasses]),
                         "seed": first + 10 * len(jobs), "count": REACT_SEEDS, "width": W * 12, "height": H * 12,
                         "reference": "%s_%d.png" % (name, seed)})
    return jobs


W, H = 64, 80  # the portrait on the grid (stage 1's pick; --width/--height to try others)
SKIN, HAIR, CLOTH, FIXED_SLOT = 1, 2, 3, 0  # as people.py
INK = 1  # people_art.gd FIXED: "ink"
LINE = 9  # (a part of its own while working: drawn as the fixed ink)
# The reaction faces' own colours (parts of their own while working, drawn as fixed colours, like the
# people's FIXED ones), so a recolour can't muddy them: the whites of the eyes (and teeth), tears, a blush.
WHITE, TEAR, BLUSH = 10, 11, 12
FIXED_OF = {LINE: INK, WHITE: 2, TEAR: 14, BLUSH: 15}  # people_art.gd FIXED: ink, white_shirt, tear, blush
EXTRAS = (WHITE, TEAR, BLUSH)
EXTRA_SHARE = 0.3  # one of them wins a game pixel it's this much of (after the lines)
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


def parts(rgba, fg=None):
    """Each picture pixel's part (-1 background, SKIN, HAIR, CLOTH, LINE) and its Lab lightness (fg: the
    foreground, if it's known already)."""
    fg = pixelate.cut_background(rgba) if fg is None else fg
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
            extra = max(EXTRAS, key=lambda e: (cp == e).sum())
            if (cp == extra).sum() >= EXTRA_SHARE * len(cp):
                out_part[j, i] = extra; out_step[j, i] = 4
                continue
            plain = (cp != LINE) & ~np.isin(cp, EXTRAS)
            values, counts = np.unique(cp[plain], return_counts=True)
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
    fixed = np.isin(gp, list(FIXED_OF))
    slot = np.where(fixed, FIXED_SLOT, gp)
    out[..., 0] = np.where(gp == LINE, 0, np.where(fixed, 4, gs)) * 36
    out[..., 1] = np.clip(slot, 0, 7) * 36
    out[..., 2] = sum(np.where(gp == p, f * 8, 0) for p, f in FIXED_OF.items())
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
    fixed = fixed_colours()
    for p in EXTRAS:
        out[gp == p, :3] = palette.hexc(fixed[FIXED_OF[p]]); out[gp == p, 3] = 255
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



# --- The library: picking the keepers (PLAN.md, Portraits) ------------------------------------

PICKS = os.path.join(palette.ROOT, "art", "raw", "portrait_picks.json")
RAW = os.path.join(palette.ROOT, "art", "raw")
EYES = (0.32, 0.52)  # the band of the portrait (top to bottom) the eyes and glasses are in


def score(gp, name):
    """How cleanly a candidate split (lower is better): parts in sensible shares, and glasses only if asked for."""
    drawn = max(1, (gp >= 0).sum())
    share = {p: (gp == p).sum() / drawn for p in (HAIR, SKIN, CLOTH, LINE)}
    bad = 0.0

    def outside(v, lo, hi):
        return max(0.0, lo - v, v - hi)
    hair_lo, hair_hi = (0.01, 0.15) if "balding" in name else (0.10, 0.45)
    bad += 4 * outside(share[HAIR], hair_lo, hair_hi) + 4 * outside(share[SKIN], 0.15, 0.45)
    bad += 4 * outside(share[CLOTH], 0.25, 0.55) + 6 * outside(share[LINE], 0.0, 0.12)
    band = gp[int(EYES[0] * gp.shape[0]):int(EYES[1] * gp.shape[0])]
    lines = (band == LINE).sum() / max(1, band.size)  # (glasses' frames are lines: far more of them in the band)
    bad += (0.12 - lines) * 3 if name.endswith("_glasses") else lines * 3
    if (gp[0] >= 0).sum() > gp.shape[1] * 0.6 or (gp[:, 0] >= 0).sum() > gp.shape[0] * 0.9:
        bad += 1  # (cut off at the top, or filling the side: framed oddly)
    return bad


def candidates():
    """{job name: ([(seed, path)...], all made)} for every job in the batch's list with pictures made."""
    import json
    jobs = json.load(open(os.path.join(RAW, "portrait_batch.json"), encoding="utf-8"))
    out = {}
    for job in jobs:
        made = [(job["seed"] + k, os.path.join(RAW, "%s_%d.png" % (job["name"], job["seed"] + k))) for k in range(job["count"])]
        made = [m for m in made if os.path.exists(m[1])]
        if made:
            out[job["name"]] = (made, len(made) == job["count"])  # (and whether all are in: only then is it pre-picked)
    return out


def pick_sheets(folder, only=None):
    """A sheet for each gender and age range: a row each hairstyle (and with glasses), its candidates
    side by side (the picture, then the portrait on brown hair, the second skin and beige), the
    pre-pick framed in gold; and portrait_picks.json, the picks (a seed, or null for none), keeping
    any picks already in it (yours to change)."""
    import json
    from PIL import ImageDraw
    hairs, clothes, skins = looks_colours()
    ink = fixed_colours()[INK]
    picks = json.load(open(PICKS, encoding="utf-8")) if os.path.exists(PICKS) else {}
    groups = {}
    for name, (made, complete) in candidates().items():
        groups.setdefault(name.split("_")[1] + "_" + name.split("_")[2], []).append((name, made, complete))
    os.makedirs(folder, exist_ok=True)
    thumb_w, thumb_h, scale, label_w = 80, 100, 2, 170
    cell = thumb_w + W * scale + 16
    for group, rows in sorted(groups.items()):
        if only and group not in only:
            continue
        sheet = Image.new("RGBA", (label_w + cell * 3, (H * scale + 10) * len(rows)), NIGHT + (255,))
        draw = ImageDraw.Draw(sheet)
        for r, (name, made, complete) in enumerate(rows):
            y = r * (H * scale + 10) + 5
            scored = []
            for k, (seed, path) in enumerate(made):
                picture = Image.open(path)
                gp, gs, _ = portrait(picture)
                scored.append((score(gp, name), seed))
                x = label_w + k * cell
                thumb = picture.convert("RGBA").resize((thumb_w, thumb_h))
                sheet.paste(thumb, (x, y))
                img = paint(gp, gs, hairs["dark_brown"], skins[1], clothes["beige"], ink).resize((W * scale, H * scale), Image.NEAREST)
                sheet.paste(img, (x + thumb_w + 4, y), img)
                draw.text((x + 2, y + thumb_h + 4), "%s %d" % ("abc"[k], seed), fill=(220, 220, 230))
            if name not in picks and complete:
                picks[name] = min(scored)[1]
            chosen = picks.get(name, "waiting")
            for k, (seed, _) in enumerate(made):
                if seed == chosen:
                    x = label_w + k * cell
                    draw.rectangle((x - 3, y - 3, x + cell - 10, y + H * scale + 2), outline=(242, 193, 74), width=2)
            draw.text((6, y + 4), name.replace("portrait_", ""), fill=(235, 235, 240))
            draw.text((6, y + 20), "pick: " + ("none" if chosen is None else "abc"[[s for s, _ in made].index(chosen)] if chosen in [s for s, _ in made] else str(chosen)), fill=(242, 193, 74))
        path = os.path.join(folder, "pick_%s.png" % group)
        sheet.save(path)
        print("%s: %d rows" % (path, len(rows)))
    with open(PICKS, "w", encoding="utf-8") as f:
        json.dump(dict(sorted(picks.items())), f, indent=1)
    print("%s: %d picks (yours to change: a seed, or null for none)" % (PICKS, len(picks)))


def keep(only=None):
    """The picks into the game: art/portraits/<id>.png in the layer encoding, the manifest and LICENSE-ASSETS."""
    import json
    picks = json.load(open(PICKS, encoding="utf-8"))
    kept = 0
    for name, seed in sorted(picks.items()):
        if seed is None or (only and "_".join(name.split("_")[1:3]) not in only):
            continue
        path = os.path.join(RAW, "%s_%d.png" % (name, seed))
        made = json.load(open(os.path.splitext(path)[0] + ".json", encoding="utf-8-sig"))
        gp, gs, _ = portrait(Image.open(path))
        source = "%s via ComfyUI, seed %s, then portraits.py: \"%s\"" % (made["model"], made["seed"], made["prompt"])
        pixelate.add_to_game(layer(gp, gs), "portrait/" + name.replace("portrait_", ""), source, "CC BY-SA 4.0 (this project)")
        kept += 1
    print("%d portraits into art/portraits/, the manifest and LICENSE-ASSETS" % kept)


# --- The reaction faces: close-ups, split with their own colours, picked and kept (PLAN.md) -------

REACT_PICKS = os.path.join(RAW, "reaction_picks.json")
REACT_CACHE = os.path.join(RAW, "react_split")  # each picture's split, made once (it's the slow part)
CLOSE_UP = (0.56, 0.08)  # the face: the middle 56% across, from 8% down, 4:5 (decided 20 Nov)
CLOSE_SCALE = 7  # picture pixels per game pixel while splitting (the crop's own size: no upscale)
MOOD_NEEDS = {"sad": (TEAR, 3), "sweet": (BLUSH, 6), "shock": (WHITE, 6)}  # a mood's own colour, and how many pixels of it
NO_MOOD = 0.3  # a candidate without its mood's colour scores this much worse


def close_up(picture):
    """The picture cut to the face (CLOSE_UP), still 4:5."""
    w, h = picture.size
    cw = round(w * CLOSE_UP[0]); ch = round(cw * H / W)
    x, y = (w - cw) // 2, round(h * CLOSE_UP[1])
    return picture.crop((x, y, x + cw, min(h, y + ch)))


def react_parts(rgba):
    """parts(), and on the skin the reaction faces' own colours: the whites of the eyes and teeth (very
    light, no colour), tears (light and blue), a blush (light and pink, bluer than lips or a mouth)."""
    part, L = parts(rgba, rgba[..., 3] >= 128)  # (the background's cut from the whole picture: react_split())
    lab = palette.to_lab(rgba[..., :3])
    a, b = lab[..., 1], lab[..., 2]
    skin = part == SKIN
    part[skin & (L > 92) & (np.hypot(a, b) < 6)] = WHITE
    part[skin & (L > 70) & (b < -3) & (a < 2)] = TEAR
    part[skin & (L > 60) & (a > 28) & (b < 0.4 * a)] = BLUSH
    return part, L


def react_split(path):
    """A picture's close-up on the grid: (part, step), cached in REACT_CACHE."""
    cached = os.path.join(REACT_CACHE, os.path.splitext(os.path.basename(path))[0] + ".npz")
    if os.path.exists(cached) and os.path.getmtime(cached) >= os.path.getmtime(path):
        got = np.load(cached)
        return got["part"], got["step"]
    gp, gs = react_grid(react_face(Image.open(path)))
    os.makedirs(REACT_CACHE, exist_ok=True)
    np.savez_compressed(cached, part=gp, step=gs)
    return gp, gs


def react_face(picture):
    """A picture's close-up at the split's size (W x H at CLOSE_SCALE), its background cut away (alpha)."""
    whole = picture.convert("RGBA")
    # The background's cut from the whole picture (at half size, for speed): a close-up's edges are
    # face and hair, which cut_background would take for the background.
    half = whole.resize((whole.width // 2, whole.height // 2), Image.LANCZOS)
    fg = Image.fromarray(pixelate.cut_background(np.asarray(half)).astype(np.uint8) * 255).resize(whole.size, Image.NEAREST)
    whole.putalpha(fg)
    return close_up(whole).resize((W * CLOSE_SCALE, H * CLOSE_SCALE), Image.LANCZOS)


def react_grid(face):
    """A close-up (react_face()) on the grid: (part, step)."""
    part, L = react_parts(np.asarray(face))
    return to_grid(part, steps_of(part, L))


def overlap(x, y):
    """How much two masks are the same (shared over either)."""
    either = (x | y).sum()
    return (x & y).sum() / either if either else 1.0


def react_score(gp, calm, mood):
    """How good a candidate is (lower is better): the same hair and outline as the calm close-up (a
    different person's the risk), its mood's own colour there, and not all lines."""
    bad = (1 - overlap(gp == HAIR, calm == HAIR)) + (1 - overlap(gp >= 0, calm >= 0))
    if mood in MOOD_NEEDS:
        part, least = MOOD_NEEDS[mood]
        bad += NO_MOOD if (gp == part).sum() < least else 0
    lines = (gp == LINE).sum() / max(1, (gp >= 0).sum())
    return bad + 6 * max(0.0, lines - 0.15)


def react_candidates(only=None):
    """{portrait id: (calm picture, {mood: [(seed, path)...]})} from reaction_batch.json, the pictures made."""
    import json
    out = {}
    for job in json.load(open(os.path.join(RAW, "reaction_batch.json"), encoding="utf-8")):
        mood = job["name"].rsplit("_", 1)[1]
        ident = job["name"][len("react_"):-len(mood) - 1]
        if only and "_".join(ident.split("_")[:2]) not in only:
            continue
        made = [(job["seed"] + k, os.path.join(RAW, "%s_%d.png" % (job["name"], job["seed"] + k))) for k in range(job["count"])]
        calm, moods = out.setdefault(ident, (os.path.join(RAW, job["reference"]), {}))
        moods[mood] = [m for m in made if os.path.exists(m[1])]
    return out


def react_pick_sheets(folder, only=None):
    """A sheet for each gender and age range: a row each portrait, its calm close-up, then each mood's
    candidates (painted on brown hair, the second skin and beige), the pre-pick framed in gold; and
    reaction_picks.json (a seed, or null for none), keeping any picks already in it. Prints each mood's
    picks without its own colour, and any portrait whose pick looks like someone else."""
    import json
    from PIL import ImageDraw
    hairs, clothes, skins = looks_colours()
    ink = fixed_colours()[INK]
    picks = json.load(open(REACT_PICKS, encoding="utf-8")) if os.path.exists(REACT_PICKS) else {}
    groups = {}
    found = react_candidates(only)
    paths = [calm for calm, _ in found.values()] + [path for _, moods in found.values() for made in moods.values() for _, path in made]
    from multiprocessing import Pool
    with Pool(os.cpu_count() or 1) as pool:  # (split once each, side by side: the slow part)
        pool.map(react_split, paths, chunksize=4)
    for ident, (calm, moods) in found.items():
        groups.setdefault("_".join(ident.split("_")[:2]), []).append((ident, calm, moods))
    os.makedirs(folder, exist_ok=True)
    scale, label_w = 2, 150
    cell = W * scale + 6
    moods = list(MOOD_FACES)
    for group, rows in sorted(groups.items()):
        sheet = Image.new("RGBA", (label_w + cell * (1 + 2 * len(moods)), 16 + (H * scale + 8) * len(rows)), NIGHT + (255,))
        draw = ImageDraw.Draw(sheet)
        for m, mood in enumerate(moods):
            draw.text((label_w + cell * (1 + 2 * m) + 4, 2), mood, fill=(235, 235, 240))
        for r, (ident, calm, made_by_mood) in enumerate(rows):
            y = 16 + r * (H * scale + 8)
            calm_gp, calm_gs = react_split(calm)
            img = paint(calm_gp, calm_gs, hairs["dark_brown"], skins[1], clothes["beige"], ink).resize((W * scale, H * scale), Image.NEAREST)
            sheet.paste(img, (label_w, y), img)
            draw.text((6, y + 4), ident, fill=(235, 235, 240))
            for m, mood in enumerate(moods):
                made = made_by_mood.get(mood, [])
                key = "%s_%s" % (ident, mood)
                scored = []
                for k, (seed, path) in enumerate(made):
                    gp, gs = react_split(path)
                    scored.append((react_score(gp, calm_gp, mood), seed))
                    img = paint(gp, gs, hairs["dark_brown"], skins[1], clothes["beige"], ink).resize((W * scale, H * scale), Image.NEAREST)
                    sheet.paste(img, (label_w + cell * (1 + 2 * m + k), y), img)
                if picks.get(key) is not None and picks[key] not in [seed for seed, _ in made]:
                    del picks[key]  # (a pick from pictures no longer in the batch: made again since)
                if key not in picks and made and len(made) == REACT_SEEDS:
                    picks[key] = min(scored)[1]
                    best = min(scored)[0]
                    if mood in MOOD_NEEDS and not any((react_split(path)[0] == MOOD_NEEDS[mood][0]).sum() >= MOOD_NEEDS[mood][1] for _, path in made):
                        print("%s: neither has its %s colour" % (key, mood))
                    elif best > 0.6 + (NO_MOOD if mood in MOOD_NEEDS else 0):
                        print("%s: the pick's hair or outline differs from the calm one (%.2f)" % (key, best))
                for k, (seed, _) in enumerate(made):
                    if seed == picks.get(key):
                        x = label_w + cell * (1 + 2 * m + k)
                        draw.rectangle((x - 2, y - 2, x + W * scale + 1, y + H * scale + 1), outline=(242, 193, 74), width=2)
        path = os.path.join(folder, "react_%s.png" % group)
        sheet.save(path)
        print("%s: %d portraits" % (path, len(rows)))
    with open(REACT_PICKS, "w", encoding="utf-8") as f:
        json.dump(dict(sorted(picks.items())), f, indent=1)
    print("%s: %d picks (yours to change: a seed, or null for none)" % (REACT_PICKS, len(picks)))


def react_keep(only=None):
    """The reaction picks into the game: art/reactions/<portrait id>_<mood>.png in the layer encoding,
    the manifest and LICENSE-ASSETS. Prints how many of each mood's faces have its own colour."""
    import json
    picks = json.load(open(REACT_PICKS, encoding="utf-8"))
    kept, coloured = 0, {}
    for key, seed in sorted(picks.items()):
        if seed is None or (only and "_".join(key.split("_")[:2]) not in only):
            continue
        mood = key.rsplit("_", 1)[1]
        path = os.path.join(RAW, "react_%s_%d.png" % (key, seed))
        made = json.load(open(os.path.splitext(path)[0] + ".json", encoding="utf-8-sig"))
        gp, gs = react_split(path)
        if mood in MOOD_NEEDS:
            part, least = MOOD_NEEDS[mood]
            coloured.setdefault(mood, [0, 0])[0] += int((gp == part).sum() >= least)
            coloured[mood][1] += 1
        source = "%s via ComfyUI (edit, from %s), seed %s, then portraits.py's close-up: \"%s\"" % (
            made["model"], os.path.basename(made.get("reference", "its calm portrait")), made["seed"], made["prompt"])
        pixelate.add_to_game(layer(gp, gs), "reaction/" + key, source, "CC BY-SA 4.0 (this project)")
        kept += 1
    print("%d reaction faces into art/reactions/, the manifest and LICENSE-ASSETS (%s)" % (kept, ", ".join(
        "%s with its colour %d of %d" % (m, c[0], c[1]) for m, c in sorted(coloured.items()))))


def react_self_test():
    """A made-up close-up (skin face, white eyes with dark pupils, a blue tear, pink cheeks, black hair)
    keeps its whites, tear and blush, and the layer draws them in their fixed colours."""
    pic = np.zeros((H * CLOSE_SCALE, W * CLOSE_SCALE, 3), float); pic[:] = (120, 180, 110)
    yy, xx = np.mgrid[0:H * CLOSE_SCALE, 0:W * CLOSE_SCALE]
    cx = W * CLOSE_SCALE / 2
    pic[((xx - cx) / 200) ** 2 + ((yy - 230) / 260) ** 2 < 1] = (20, 20, 24)  # the hair
    pic[((xx - cx) / 170) ** 2 + ((yy - 300) / 220) ** 2 < 1] = (250, 228, 212)  # the face
    for ex in (cx - 70, cx + 70):
        pic[((xx - ex) / 34) ** 2 + ((yy - 260) / 20) ** 2 < 1] = (252, 252, 252)  # an eye's white
        pic[((xx - ex) / 9) ** 2 + ((yy - 260) / 12) ** 2 < 1] = (15, 15, 18)  # its pupil
    pic[(np.abs(xx - (cx - 70)) < 9) & (yy > 300) & (yy < 380)] = (150, 205, 245)  # a tear
    pic[((xx - (cx + 90)) / 40) ** 2 + ((yy - 330) / 22) ** 2 < 1] = (245, 140, 160)  # a blush
    rgb = np.clip(pic, 0, 255).astype(np.uint8)
    rgba = np.dstack([rgb, np.where(pixelate.cut_background(np.dstack([rgb, np.full(rgb.shape[:2], 255, np.uint8)])), 255, 0).astype(np.uint8)])
    part, L = react_parts(rgba)
    gp, gs = to_grid(part, steps_of(part, L))
    problems = []
    for p, name in ((WHITE, "eye whites"), (TEAR, "tear"), (BLUSH, "blush")):
        if not (gp == p).any():
            problems.append("no %s" % name)
    if not (gp == HAIR).any() or not (gp == SKIN).any():
        problems.append("the hair or skin went")
    enc = np.asarray(layer(gp, gs))
    blush = gp == BLUSH
    if blush.any() and not ((enc[blush][:, 1] // 36 == FIXED_SLOT).all() and (np.round(enc[blush][:, 2] / 8) == FIXED_OF[BLUSH]).all()):
        problems.append("the blush isn't drawn as its fixed colour")
    cw, ch = close_up(Image.new("RGB", (768, 960))).size
    if abs(ch / cw - H / W) > 0.01:
        problems.append("the close-up isn't 4:5 (%dx%d)" % (cw, ch))
    print("\n".join(problems) if problems else "reaction faces self-test: OK (whites %d, tear %d, blush %d pixels)" % (
        (gp == WHITE).sum(), (gp == TEAR).sum(), (gp == BLUSH).sum()))
    return not problems


def react_expect(folder):
    """expect() for a folder of reaction faces: one calm picture (portrait_<id>_<seed>.png) and its moods'
    candidates (react_<id>_<mood>_<seed>.png). For each, <same>_face.png (the Python's close-up, so the
    game's split can be checked on it exactly) and <same>_layer.png; each candidate's score and its moods'
    own colours in expected.json, and each mood's pick."""
    import json
    names = sorted(n for n in os.listdir(folder) if n.endswith(".png") and not n.endswith(("_layer.png", "_face.png")))
    calm = [n for n in names if n.startswith("portrait_")]
    assert len(calm) == 1, "one calm picture (portrait_<id>_<seed>.png), not %d" % len(calm)
    grids = {}
    for name in names:
        face = react_face(Image.open(os.path.join(folder, name)))
        face.save(os.path.join(folder, name.replace(".png", "_face.png")))
        gp, gs = react_grid(face)
        layer(gp, gs).save(os.path.join(folder, name.replace(".png", "_layer.png")))
        grids[name] = gp
    ident = re.match(r"portrait_(.+)_\d+\.png$", calm[0]).group(1)
    calm_gp = grids[calm[0]]
    out, scored = {}, {}
    for name in names:
        if name == calm[0]:
            continue
        mood, seed = re.match(r"react_%s_([a-z]+)_(\d+)\.png$" % re.escape(ident), name).groups()
        gp = grids[name]
        sc = react_score(gp, calm_gp, mood)
        out[name] = {"mood": mood, "seed": int(seed), "score": sc,
                     "colours": {"white": int((gp == WHITE).sum()), "tear": int((gp == TEAR).sum()), "blush": int((gp == BLUSH).sum())}}
        scored.setdefault(mood, []).append((sc, int(seed)))
    picks = {mood: min(s)[1] for mood, s in scored.items()}
    with open(os.path.join(folder, "expected.json"), "w", encoding="utf-8") as f:
        json.dump({"id": ident, "calm": calm[0], "pictures": out, "picks": picks}, f, indent=1)
    print("%s: %s and %d candidates, picks %s" % (folder, calm[0], len(out), picks))


def expect(folder):
    """The Python's answer for the game's port of the split (scripts/rules/portrait_split.gd) to be checked
    against: for each picture in folder (portrait_<id>_<seed>.png), <same>_layer.png and its score and
    shares in expected.json, and which of each id's candidates it pre-picks."""
    import json
    out, scored = {}, {}
    for name in sorted(os.listdir(folder)):
        if not name.endswith(".png") or name.endswith("_layer.png"):
            continue
        ident, seed = re.match(r"portrait_(.+)_(\d+)\.png$", name).groups()
        gp, gs, shares = portrait(Image.open(os.path.join(folder, name)))
        layer(gp, gs).save(os.path.join(folder, name.replace(".png", "_layer.png")))
        out[name] = {"id": ident, "seed": int(seed), "score": score(gp, ident), "shares": shares}
        scored.setdefault(ident, []).append((score(gp, ident), int(seed)))
    picks = {ident: min(s)[1] for ident, s in scored.items() if len(s) > 1}
    with open(os.path.join(folder, "expected.json"), "w", encoding="utf-8") as f:
        json.dump({"pictures": out, "pre_picks": picks}, f, indent=1)
    print("%s: %d pictures, pre-picks %s" % (folder, len(out), picks))


if __name__ == "__main__":
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("pictures", nargs="*")
    ap.add_argument("--sheet"); ap.add_argument("--sizes"); ap.add_argument("--layers")
    ap.add_argument("--width", type=int, default=W); ap.add_argument("--height", type=int, default=H)
    ap.add_argument("--self-test", action="store_true")
    ap.add_argument("--expect", metavar="FOLDER", help="the Python's split of FOLDER's pictures, for the game's port's test")
    ap.add_argument("--pick", metavar="FOLDER", help="pick sheets of the batch's pictures into FOLDER, and art/raw/portrait_picks.json")
    ap.add_argument("--only", help="with --pick, --keep, --react-pick or --react-keep: just these groups (w_20s,m_70s...), so a run fits in a shell call")
    ap.add_argument("--keep", action="store_true", help="the picks (portrait_picks.json) into art/portraits/, the manifest and LICENSE-ASSETS")
    ap.add_argument("--reactions", action="store_true", help="write art/raw/reaction_batch.json: every kept portrait in every TV mood, for queue_art_batch")
    ap.add_argument("--batch", action="store_true", help="write art/raw/portrait_batch.json, the library's jobs for the helper's queue_art_batch")
    ap.add_argument("--react-pick", metavar="FOLDER", help="the reaction faces' close-ups split, pick sheets into FOLDER, and art/raw/reaction_picks.json")
    ap.add_argument("--react-keep", action="store_true", help="the reaction picks into art/reactions/, the manifest and LICENSE-ASSETS")
    a = ap.parse_args()
    if a.self_test:
        sys.exit(0 if self_test() and react_self_test() else 1)
    if a.expect:
        (react_expect if any(n.startswith("react_") for n in os.listdir(a.expect)) else expect)(a.expect)
        sys.exit(0)
    if a.react_pick:
        react_pick_sheets(a.react_pick, a.only.split(",") if a.only else None)
        sys.exit(0)
    if a.react_keep:
        react_keep(a.only.split(",") if a.only else None)
        sys.exit(0)
    if a.pick:
        pick_sheets(a.pick, a.only.split(",") if a.only else None)
        sys.exit(0)
    if a.keep:
        keep(a.only.split(",") if a.only else None)
        sys.exit(0)
    if a.batch or a.reactions:
        import json
        jobs = reaction_jobs() if a.reactions else batch_jobs()
        path = os.path.join(palette.ROOT, "art", "raw", "reaction_batch.json" if a.reactions else "portrait_batch.json")
        os.makedirs(os.path.dirname(path), exist_ok=True)
        with open(path, "w", encoding="utf-8") as f:
            json.dump(jobs, f, indent=1, ensure_ascii=False)
        print("%s: %d jobs, %d pictures (about %d minutes in ComfyUI)" % (path, len(jobs), sum(j["count"] for j in jobs), sum(j["count"] for j in jobs) * 6 // 60))
        sys.exit(0)
    if not a.pictures or not (a.sheet or a.sizes):
        ap.error("pictures, and --sheet and/or --sizes")
    if a.sheet:
        sheet(a.pictures, a.sheet, a.width, a.height, layers_to=a.layers)
    if a.sizes:
        sizes(a.pictures[:3], a.sizes)
