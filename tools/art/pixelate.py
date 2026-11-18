"""The pixelate tool: an image model's picture to KTBT pixel art (ART.md, "Where the art comes from").

    python3 tools/art/pixelate.py <picture> --height 16 [--out out.png] [--outline]
        [--key touch/lucky_cat --source "..." --licence "..."]   (into the game's art folder)
    python3 tools/art/pixelate.py --self-test

What it does, in order:
 1. Cuts out the background: the picture's own transparency if it has any, otherwise whatever
    joins the edges and is close to the edges' colour. So ask the model for one thing on a plain,
    flat green background (white would take a white cat with it).
 2. Crops to what's left, and shrinks it onto the pixel grid (--height or --width game pixels),
    in the palette (palette.py): each of a few samples a pixel goes to the nearest colour on any
    colour's light ramp (so its colour and its shading both stay, and the game's light can move
    it along), and the pixel takes the colour most of them are, except that a dark line that's a
    fair part of it wins, so outlines and eyes survive; a pixel less than half covered is
    see-through, and the soft edge between the thing and the background is left out.
 3. Tidies it: a lone pixel unlike everything round it takes its neighbours' colour, and a stray
    pixel with nothing next to it goes. --outline adds a dark edge, for things against the night.
 4. Writes the result, and a preview (the picture beside the result, 8x) next to it.
With --key, it goes into art/ (art/<kind>s/<id>.png), into art/manifest.json and LICENSE-ASSETS.md,
which the game's tests check (test_art.gd). A picture from generate_art (art/raw/) has a note
beside it of how it was made, which becomes its source. Text a model draws is never real Korean: crop it out
or paint it over before this, and put real text back in a font.
"""
import argparse, json, os, sys
import numpy as np
from PIL import Image

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import palette

BG_CLOSE = 45.0  # Lab distance: this close to the edges' colour (and joined to an edge) is background,
# with the soft edge a model paints between them (--bg-close to change it; for something green,
# ask for a magenta background instead)


def cut_background(rgba, close=BG_CLOSE):
    """The foreground mask (bool, h x w)."""
    alpha = rgba[..., 3]
    if alpha.min() < 250:  # it has its own transparency
        return alpha >= 128
    rgb = rgba[..., :3]
    border = np.concatenate([rgb[0], rgb[-1], rgb[:, 0], rgb[:, -1]])
    bg_lab = palette.to_lab(np.median(border, axis=0))
    distance = np.linalg.norm(palette.to_lab(rgb) - bg_lab, axis=-1)
    near = distance < close
    # Flood in from the edges through the near-background pixels (so a white collar stays).
    h, w = near.shape
    background = np.zeros_like(near)
    stack = [(y, x) for y in range(h) for x in (0, w - 1) if near[y, x]] + [(y, x) for x in range(w) for y in (0, h - 1) if near[y, x]]
    while stack:
        y, x = stack.pop()
        if background[y, x]:
            continue
        background[y, x] = True
        for dy, dx in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            ny, nx = y + dy, x + dx
            if 0 <= ny < h and 0 <= nx < w and near[ny, nx] and not background[ny, nx]:
                stack.append((ny, nx))
    # The background's own colour anywhere, even shut in (between cables and poles), is background.
    background |= distance < close * 0.5
    # The soft edge a model paints between the thing and the background: just beside the
    # background, and nearer its colour than the thing's, it goes with the background too.
    from PIL import ImageFilter
    beside = np.asarray(Image.fromarray(background.astype(np.uint8) * 255).filter(ImageFilter.MaxFilter(7))) > 0
    return ~(background | (beside & (distance < close * 1.8)))


SUB = 8  # each game pixel is judged from SUB x SUB samples of the picture (picked, not blended)
DARK = 38.0  # Lab lightness below this is a line (an outline, an eye): it wins a cell it's a fair part of
DARK_SHARE = 18  # ... of the SUB x SUB samples


def nearest_colour(rgb, labs):
    """For each colour (n, 3), the index of the nearest of labs: each distinct colour once, in chunks."""
    distinct, back = np.unique(rgb.round().astype(np.int32), axis=0, return_inverse=True)
    picked = np.empty(len(distinct), int)
    for start in range(0, len(distinct), 4096):
        chunk = palette.to_lab(distinct[start:start + 4096])
        picked[start:start + 4096] = np.argmin(np.linalg.norm(chunk[:, None, :] - labs[None, :, :], axis=-1), axis=1)
    return picked[back.ravel()]


def shrink(rgba, mask, colours, height=None, width=None, close=BG_CLOSE):
    """Onto the grid, in the palette: an index into colours for each game pixel (-1: see-through).
    The picture's sampled SUB x SUB times a pixel (picked, not blended, so a line stays a line); each sample goes to its nearest palette colour; then each pixel is the colour most
    of its samples are, except that a dark line wins if it's a fair part of the cell, so a
    model's thin outlines and eyes survive being shrunk."""
    ys, xs = np.nonzero(mask)
    if len(ys) == 0:
        raise SystemExit("Nothing left once the background's cut out: is the background plain?")
    box = (int(xs.min()), int(ys.min()), int(xs.max()) + 1, int(ys.max()) + 1)
    picture = Image.fromarray(np.ascontiguousarray(rgba[..., :3])).crop(box)
    m = Image.fromarray((mask * 255).astype(np.uint8)).crop(box)
    h, w = m.height, m.width
    if height:
        out_h = height; out_w = max(1, round(w * height / h))
    else:
        out_w = width; out_h = max(1, round(h * width / w))
    small = np.asarray(picture.resize((out_w * SUB, out_h * SUB), Image.NEAREST)).astype(float)
    covered = np.asarray(m.resize((out_w * SUB, out_h * SUB), Image.NEAREST)) >= 128
    labs = palette.to_lab(colours)
    nearest = np.full(covered.shape, -1)
    nearest[covered] = nearest_colour(small[covered], labs)
    dark = labs[:, 0] < DARK
    index = np.full((out_h, out_w), -1)
    for j in range(out_h):
        for i in range(out_w):
            cell = nearest[j * SUB:(j + 1) * SUB, i * SUB:(i + 1) * SUB].ravel()
            cell = cell[cell >= 0]
            if len(cell) < SUB * SUB / 2:
                continue
            lines = cell[dark[cell]]
            pick = lines if len(lines) >= DARK_SHARE else cell
            values, counts = np.unique(pick, return_counts=True)
            index[j, i] = values[np.argmax(counts)]
    return index


def tidy(index):
    """Lone odd pixels take their neighbours' colour; a pixel with nothing beside it goes."""
    h, w = index.shape
    out = index.copy()
    for y in range(h):
        for x in range(w):
            if index[y, x] < 0:
                continue
            around = [index[y + dy, x + dx] for dy in (-1, 0, 1) for dx in (-1, 0, 1)
                      if (dy or dx) and 0 <= y + dy < h and 0 <= x + dx < w]
            beside = [index[y + dy, x + dx] for dy, dx in ((1, 0), (-1, 0), (0, 1), (0, -1)) if 0 <= y + dy < h and 0 <= x + dx < w]
            if all(c < 0 for c in beside):
                out[y, x] = -1  # (a stray speck)
                continue
            filled = [c for c in around if c >= 0]
            if len(filled) >= 6 and index[y, x] not in filled:
                values, counts = np.unique(filled, return_counts=True)
                if counts.max() >= 5:
                    out[y, x] = values[np.argmax(counts)]
    return out


def outline(index, bases, steps, colours):
    """A dark edge round it: each see-through pixel beside it takes the darkest step of its neighbour's ramp."""
    h, w = index.shape
    out = index.copy()
    for y in range(h):
        for x in range(w):
            if index[y, x] >= 0:
                continue
            for dy, dx in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                ny, nx = y + dy, x + dx
                if 0 <= ny < h and 0 <= nx < w and index[ny, nx] >= 0:
                    base = bases[index[ny, nx]]
                    out[y, x] = int(np.nonzero((bases == base) & (steps == 0))[0][0])
                    break
    return out


def pixelate(picture, height=None, width=None, with_outline=False, close=BG_CLOSE):
    """The picture as pixel art: an RGBA PIL image in the palette's colours."""
    rgba = np.asarray(picture.convert("RGBA"))
    colours, bases, steps = palette.ramped()
    mask = cut_background(rgba, close)
    index = tidy(shrink(rgba, mask, colours, height, width, close))
    if with_outline:
        # (a pixel's room all round, for the edge)
        index = np.pad(index, 1, constant_values=-1)
        index = outline(index, bases, steps, colours)
    out = np.zeros(index.shape + (4,), np.uint8)
    out[index >= 0, :3] = colours[index[index >= 0]]
    out[index >= 0, 3] = 255
    return Image.fromarray(out, "RGBA")


def preview(picture, result, path):
    """The picture beside the result (8x), on the night's colour."""
    big = result.resize((result.width * 8, result.height * 8), Image.NEAREST)
    pic = picture.convert("RGBA"); pic.thumbnail((big.width * 2, big.height))
    sheet = Image.new("RGBA", (pic.width + big.width + 24, max(pic.height, big.height) + 16), (40, 38, 64, 255))
    sheet.paste(pic, (8, 8), pic); sheet.paste(big, (pic.width + 16, 8), big)
    sheet.save(path)


def add_to_game(result, key, source, licence):
    """Into art/, its manifest, and LICENSE-ASSETS.md (each replaced if it was there)."""
    kind, ident = key.split("/")
    file = "%ss/%s.png" % (kind, ident)
    path = os.path.join(palette.ROOT, "art", file)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    result.save(path)
    manifest_path = os.path.join(palette.ROOT, "art", "manifest.json")
    manifest = json.load(open(manifest_path, encoding="utf-8")) if os.path.exists(manifest_path) else {}
    manifest[key] = {"file": file, "source": source, "licence": licence}
    with open(manifest_path, "w", encoding="utf-8") as f:
        json.dump(dict(sorted(manifest.items())), f, indent="\t", ensure_ascii=False)
        f.write("\n")
    licences_path = os.path.join(palette.ROOT, "LICENSE-ASSETS.md")
    text = open(licences_path, encoding="utf-8").read()
    row = "| `art/%s` | %s | %s | %s |" % (file, key, source.replace("|", "/"), licence.replace("|", "/"))
    lines = [line for line in text.split("\n") if not line.startswith("| `art/%s`" % file)]
    header = lines.index("| --- | --- | --- | --- |")  # (the Art table's)
    lines.insert(header + 1, row)
    text = "\n".join(lines).replace("None yet: everything on screen is still drawn in code.\n", "")
    open(licences_path, "w", encoding="utf-8").write(text)
    return path


def self_test():
    """A model-like picture (a small sprite blown up, blurred, noisy, on a plain green) comes back clean."""
    from PIL import ImageFilter
    rng = np.random.default_rng(1)
    colours, _, _ = palette.ramped()
    sprite = np.zeros((16, 12, 4), np.uint8)
    sprite[3:9, 2:9] = (245, 242, 234, 255); sprite[9:16, 1:10] = (245, 242, 234, 255)  # a white cat
    sprite[9, 1:10] = (200, 68, 58, 255)  # its red collar
    big = Image.fromarray(sprite, "RGBA").resize((12 * 40, 16 * 40), Image.NEAREST)
    page = Image.new("RGBA", (big.width + 200, big.height + 160), (40, 170, 80, 255))  # (ask the model for a plain green background)
    page.paste(big, (100, 80), big)
    noisy = np.asarray(page.convert("RGB").filter(ImageFilter.GaussianBlur(6))).astype(float)
    noisy += rng.normal(0, 6, noisy.shape)
    picture = Image.fromarray(np.clip(noisy, 0, 255).astype(np.uint8), "RGB")
    result = pixelate(picture, height=16)
    arr = np.asarray(result)
    problems = []
    if result.size != (12, 16) and result.size != (11, 16):
        problems.append("size %s, not about 12x16" % (result.size,))
    seen = {tuple(p[:3]) for p in arr.reshape(-1, 4) if p[3] == 255}
    palette_set = {tuple(c) for c in colours}
    if not seen <= palette_set:
        problems.append("%d colours not in the palette" % len(seen - palette_set))
    if (arr[..., 3] == 255).sum() < 0.6 * (sprite[..., 3] == 255).sum():
        problems.append("too little left: the cat was cut out with the background")
    if arr[0, 0, 3] != 0:
        problems.append("the background's still there")
    reds = [p for p in arr.reshape(-1, 4) if p[3] == 255 and int(p[0]) > int(p[1]) + 60]
    if not reds:
        problems.append("the red collar's gone")
    with_edge = pixelate(picture, height=16, with_outline=True)
    if with_edge.size != (result.width + 2, result.height + 2):
        problems.append("the outline didn't add a pixel round it")
    print("\n".join(problems) if problems else "pixelate self-test: OK (%dx%d, %d colours, all in the palette)" % (result.width, result.height, len(seen)))
    return not problems


if __name__ == "__main__":
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("picture", nargs="?")
    ap.add_argument("--height", type=int); ap.add_argument("--width", type=int)
    ap.add_argument("--out"); ap.add_argument("--outline", action="store_true")
    ap.add_argument("--key"); ap.add_argument("--source"); ap.add_argument("--licence")
    ap.add_argument("--bg-close", type=float, default=BG_CLOSE)
    ap.add_argument("--self-test", action="store_true")
    a = ap.parse_args()
    if a.self_test:
        sys.exit(0 if self_test() else 1)
    if not a.picture or not (a.height or a.width):
        ap.error("a picture and --height or --width (in game pixels)")
    picture = Image.open(a.picture)
    result = pixelate(picture, a.height, a.width, a.outline, a.bg_close)
    out = a.out or os.path.splitext(a.picture)[0] + "_pixel.png"
    result.save(out)
    preview(picture, result, os.path.splitext(out)[0] + "_preview.png")
    print("%s: %dx%d" % (out, result.width, result.height))
    if a.key:
        note = os.path.splitext(a.picture)[0] + ".json"  # (generate_art's note of how it was made)
        if os.path.exists(note) and not a.source:
            made = json.load(open(note, encoding="utf-8-sig"))
            a.source = "%s via ComfyUI, seed %s, then pixelate.py: \"%s\"" % (made["model"], made["seed"], made["prompt"])
            a.licence = a.licence or "CC BY-SA 4.0 (this project)"
        if not (a.source and a.licence):
            ap.error("--key needs --source (where the picture came from: model, prompt, seed) and --licence")
        print("into the game: %s" % add_to_game(result, a.key, a.source, a.licence))
