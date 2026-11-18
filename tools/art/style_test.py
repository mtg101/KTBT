# The style test (ART.md): a range of the game's bars in pixel art, lit with each colour's light ramp.
# Usage: python3 tools/art/style_test.py <folder>   (writes tents_range.png, tent_lit.png, palette_ramps.png there)
# Needs Python 3 with Pillow and NumPy, and a Noto Sans CJK font (the stand-in for a pixel Korean font).
# A reference for how the ramps work (ramp, lit_ramped), not part of the game.
import numpy as np, random, sys
from PIL import Image, ImageDraw, ImageFont, ImageFilter
W, H, GROUND = 480, 270, 214
FONT = "/usr/share/fonts/opentype/noto/NotoSansCJK-Bold.ttc"
def hexc(h): h = h.lstrip("#"); return tuple(int(h[i:i+2], 16) for i in (0, 2, 4))
def mix(a, b, t): return "#%02x%02x%02x" % tuple(int(x + (y - x) * t) for x, y in zip(hexc(a), hexc(b)))
def dark(a, t): return mix(a, "#000000", t)

def scene(look, seed):
    rnd = random.Random(seed)
    base = Image.new("RGB", (W, H)); d = ImageDraw.Draw(base)
    emit = Image.new("RGB", (W, H)); e = ImageDraw.Draw(emit)
    def R(x0, y0, x1, y1, c, glow=None):
        d.rectangle([x0, y0, x1, y1], fill=hexc(c)); e.rectangle([x0, y0, x1, y1], fill=hexc(glow) if glow else (0, 0, 0))
    def P(pts, c, glow=None):
        d.polygon(pts, fill=hexc(c)); e.polygon(pts, fill=hexc(glow) if glow else (0, 0, 0))
    def E(box, c, glow=None):
        d.ellipse(box, fill=hexc(c)); e.ellipse(box, fill=hexc(glow) if glow else (0, 0, 0))
    def text(s, x, y, size, c, glow=None, vertical=False):
        font = ImageFont.truetype(FONT, size, index=1)
        for k, ch in enumerate(s):
            m = Image.new("L", (size + 4, size + 4)); ImageDraw.Draw(m).text((1, -size // 5), ch, font=font, fill=255)
            m = m.point(lambda v: 255 if v > 110 else 0)
            at = (x, y + k * (size + 1)) if vertical else (x + k * (size + 1), y)
            base.paste(hexc(c), at, m); emit.paste(hexc(glow) if glow else (0, 0, 0), at, m)
    # sky, stars, buildings, overpass
    for y in range(GROUND):
        band = min(int(y / GROUND * 6), 5)
        d.line([(0, y), (W, y)], fill=hexc(mix("#0a0e22", "#232848", (band + 0.5) / 6)))
    for _ in range(40): base.putpixel((rnd.randrange(W), rnd.randrange(70)), hexc("#8890b8"))
    x = 0
    while x < W:
        w = rnd.randrange(26, 60); top = rnd.randrange(55, 120)
        R(x, top, x + w, GROUND, rnd.choice(["#1b2038", "#20263f", "#252b47"]))
        for wy in range(top + 6, GROUND - 10, 9):
            for wx in range(x + 4, x + w - 4, 7):
                r = rnd.random()
                R(wx, wy, wx + 2, wy + 3, *(("#d9a95a", "#8a5a20") if r < 0.28 else ("#8fc7e8", "#2f5f88") if r < 0.36 else ("#171b2e",)))
        x += w + rnd.randrange(0, 4)
    R(0, 18, W, 40, "#3b4058"); R(0, 40, W, 46, "#2a2e42")
    for px in (34, 438): R(px, 46, px + 16, GROUND, "#33384e")
    lamps = list(range(70, W, 96))
    for lx in lamps: R(lx, 46, lx + 4, 48, "#ffcf7a", "#ffaa40")
    R(456, 46, W, GROUND, "#2a2338"); text("노래방", 462, 50, 15, "#ffd2ec", "#ff3d9a", vertical=True)
    R(0, GROUND, W, H, "#16181f"); R(0, GROUND, W, GROUND + 2, "#2c2f3a")
    for lx in range(10, W, 46): R(lx, 246, lx + 20, 247, "#3a3d46")
    # the tent
    main, stripe = look["tarp"]; main = "#" + main; stripe = ("#" + stripe) if stripe else ""
    shade, glow = dark(main, 0.2), dark(main, 0.55)
    L, RT = 18, 462
    eave = 104
    def striped(x0, y0, x1, y1):   # a tarp panel, striped if the tarp is
        R(x0, y0, x1, y1, main, glow)
        if stripe:
            for sx in range(x0, x1, 24): R(sx, y0, min(sx + 11, x1), y1, stripe, dark(stripe, 0.6))
    shape = look["shape"]
    if shape == "peaked":
        P([(L + 8, eave), (240, 74), (RT - 8, eave)], main, glow)
        if stripe:
            for sx in range(L + 8, RT - 8, 24):
                top = lambda x: eave - (eave - 74) * (1 - abs(x - 240) / (240 - L - 8))
                P([(sx, eave), (sx, top(sx)), (sx + 11, top(sx + 11)), (sx + 11, eave)], stripe, dark(stripe, 0.6))
    elif shape == "rounded":
        E([L + 4, 70, RT - 4, eave + 34], main, glow); R(L + 4, eave, RT - 4, eave + 34, "#000000")  # (cut below by the walls)
        d.rectangle([L + 4, eave + 1, RT - 4, eave + 34], fill=hexc("#16181f"))
    elif shape == "awning":
        striped(L, 88, RT, eave)
    else:  # classic, scalloped: a low sloped tarp
        P([(L + 6, eave), (L + 40, 84), (RT - 40, 84), (RT - 6, eave)], main, glow)
        if stripe:
            for sx in range(L + 20, RT - 20, 24): R(sx, 86, sx + 11, eave - 1, stripe, dark(stripe, 0.6))
    R(L, eave, RT, eave + 8, shade, dark(main, 0.7))                         # the eave band
    if shape == "scalloped":
        for sx in range(L, RT, 12): E([sx, eave + 4, sx + 12, eave + 14], shade, dark(main, 0.7))
    if shape == "awning":
        for sx in range(L, RT, 10): P([(sx, eave + 8), (sx + 10, eave + 8), (sx + 5, eave + 14)], shade, dark(main, 0.7))
    striped(L + 4, eave + 8, L + 18, GROUND - 1); striped(RT - 18, eave + 8, RT - 4, GROUND - 1)
    IL, IR = L + 18, RT - 18
    top_in = eave + 14 if shape in ("scalloped", "awning") else eave + 8
    R(IL, top_in, IR, top_in + 4, "#f3d6a8", "#3a2a14")
    R(IL, top_in + 4, IR, GROUND - 1, mix(main, "#f0c890", 0.55))           # inside: the tarp, lit through
    for mx in range(IL + 90, IR - 90, 40):
        R(mx, 126, mx + 18, 148, "#fbf3e2")
        for ly in range(130, 146, 4): R(mx + 3, ly, mx + 13, ly, "#c0392b")
    R(150, 144, 166, 166, "#eaeaea"); R(152, 148, 164, 166, "#d8d0c0")
    R(153, 133, 163, 143, "#e9b98d"); R(152, 130, 164, 134, "#9a9a9a")
    R(IL + 6, 166, IR - 6, 170, "#a8703f"); R(IL + 6, 170, IR - 6, 186, "#7a4a2a")
    R(IL + 16, 156, IL + 40, 166, "#9aa0a8"); R(IL + 18, 154, IL + 38, 156, "#c0c6cc")
    for k in range(10): d.point((IL + 20 + rnd.randrange(16), 142 - k * 3), fill=hexc("#f5efe6"))
    for bx in (230, 236, 330, 380):
        R(bx, 156, bx + 3, 166, "#2f8a4a", "#0e3a1c"); R(bx + 1, 152, bx + 2, 156, "#3fa65a", "#124a22")
    R(237, top_in + 2, 242, top_in + 6, "#fff4c8", "#ffffff")
    SEATS = 5
    STOOLS = [IL + 40 + k * ((IR - IL - 92) // (SEATS - 1)) for k in range(SEATS)]
    for sx in STOOLS:
        R(sx, 198, sx + 12, 200, "#d8332a"); R(sx + 1, 200, sx + 3, GROUND - 1, "#b02820"); R(sx + 9, 200, sx + 11, GROUND - 1, "#b02820")
    for k, coat in look["people"]:
        cx = STOOLS[k] - 2; R(cx + 2, 172, cx + 14, 198, coat); R(cx + 4, 163, cx + 12, 172, "#1c1c22")
    # the sign: on the roof's front, middle
    board, ink = look["sign"]
    sw = len(look["name"]) * 13 + 10
    R(240 - sw // 2, 88 if shape != "peaked" else 84, 240 + sw // 2, (88 if shape != "peaked" else 84) + 15, "#" + board,
      dark("#" + board, 0.5) if look["sign_style"] in ("lightbox",) else None)
    text(look["name"], 240 - sw // 2 + 5, (88 if shape != "peaked" else 84) + 1, 12, "#" + ink,
         "#" + ink if look["sign_style"] in ("neon", "lightbox") else None)
    # touches
    if "string_lights" in look["touches"]:
        for sx in range(L + 6, RT - 6, 9): R(sx, eave + 2, sx + 1, eave + 3, "#ffe9a8", "#ffd060")
    if "lanterns" in look["touches"]:
        for lx in (L + 26, RT - 34):
            R(lx + 3, eave + 8, lx + 4, eave + 12, "#333333"); E([lx, eave + 12, lx + 8, eave + 22], "#d8282a", "#a01010")
    return base, emit

import colorsys
LEVELS = [0.22, 0.36, 0.52, 0.72, 1.0, 1.22, 1.42]      # a ramp's steps: deep shadow ... highlight
def ramp(rgb):
    """A colour's light ramp: 7 steps, shadows cooler (bluer, a little more saturated), light warmer."""
    h, sat, v = colorsys.rgb_to_hsv(*[c / 255.0 for c in rgb])
    out = []
    for k, f in enumerate(LEVELS):
        t = (k - 4) / 4.0                                 # -1 (deepest shadow) .. +0.5 (highlight)
        hh = h
        if t < 0:   # toward blue
            hh = h + ((0.64 - h + 0.5) % 1.0 - 0.5) * 0.12 * -t
        else:       # toward warm yellow
            hh = h + ((0.11 - h + 0.5) % 1.0 - 0.5) * 0.10 * t
        ss = min(1.0, sat * (1 + 0.15 * -t)) if t < 0 else sat * (1 - 0.25 * t)
        vv = min(1.0, v * f) if f <= 1 else min(1.0, v + (1 - v) * (f - 1) * 1.4)
        out.append(tuple(int(c * 255) for c in colorsys.hsv_to_rgb(hh % 1.0, ss, vv)))
    return out

def lit_ramped(base, emit):
    """The lit scene in the palette: each pixel keeps its own colour's ramp; the light picks the step."""
    b = np.asarray(base).astype(np.int64); em = np.asarray(emit, dtype=float) / 255.0
    yy, xx = np.mgrid[0:H, 0:W]
    light = np.zeros((H, W))
    def lamp(cx, cy, rad, power):
        dist = np.sqrt((xx - cx) ** 2 + ((yy - cy) * 1.3) ** 2)
        return np.clip(1 - dist / rad, 0, 1) ** 1.4 * power
    inside = (xx >= 36) & (xx <= 444) & (yy >= 112) & (yy < GROUND)
    bulb = lamp(240, 116, 260, 0.75); bulb[~inside] *= 0.1
    light += 0.42 + bulb + lamp(240, GROUND + 6, 230, 0.35) * (yy >= GROUND)
    light += lamp(470, 72, 60, 0.35)
    for lx in range(70, W, 96): light += lamp(lx + 2, 50, 50, 0.25)
    glow = np.asarray(Image.fromarray((np.clip(em, 0, 1) * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(5)), dtype=float).mean(axis=2) / 255.0
    light += em.mean(axis=2) * 1.6 + glow * 0.9              # what glows is bright, and lights what's round it
    # which step: by the light, the edges between steps dithered (4x4 Bayer)
    bayer = np.array([[0, 8, 2, 10], [12, 4, 14, 6], [3, 11, 1, 9], [15, 7, 13, 5]]) / 16.0 - 0.5
    t = np.interp(light, [0.15, 0.3, 0.45, 0.62, 0.85, 1.15, 1.5], range(7))
    level = np.clip(np.floor(t + 0.5 + bayer[yy % 4, xx % 4] * 0.9), 0, 6).astype(int)
    packed = (b[..., 0] << 16) | (b[..., 1] << 8) | b[..., 2]
    out = np.zeros((H, W, 3), dtype=np.uint8)
    palette = {}
    for key in np.unique(packed):
        rgb = ((key >> 16) & 255, (key >> 8) & 255, key & 255)
        r = ramp(rgb); palette[rgb] = r
        m = packed == key
        out[m] = np.array(r)[level[m]]
    # the wet road: what's bright above, mirrored, as ripples, in the road's own (lighter) colours
    above = out[GROUND - (H - GROUND):GROUND][::-1].astype(float) / 255.0
    bright = np.clip(above.mean(axis=2) - 0.45, 0, 1)
    rip = random.Random(3)
    road = out[GROUND:].astype(float) / 255.0
    for row in range(H - GROUND):
        if row % 3 == 2: continue
        shift = rip.randint(-3, 3)
        rb = np.roll(bright[row], shift); rc = np.roll(above[row], shift, axis=0)
        a = np.clip(rb * 2.2 * (1 - row / (H - GROUND)), 0, 0.85)[:, None]
        road[row] = road[row] * (1 - a) + rc * a
    out[GROUND:] = (road * 255).astype(np.uint8)
    return Image.fromarray(out), palette

def lit(base, emit):
    b = np.asarray(base, dtype=float) / 255.0; em = np.asarray(emit, dtype=float) / 255.0
    yy, xx = np.mgrid[0:H, 0:W]
    night = np.array([0.34, 0.37, 0.56]); light = np.zeros((H, W, 3))
    def lamp(cx, cy, rad, col, power):
        dist = np.sqrt((xx - cx) ** 2 + ((yy - cy) * 1.3) ** 2)
        return (np.clip(1 - dist / rad, 0, 1) ** 1.4 * power)[..., None] * np.array(col)
    inside = (xx >= 36) & (xx <= 444) & (yy >= 112) & (yy < GROUND)
    bulb = lamp(240, 116, 260, (1.0, 0.72, 0.48), 0.8); bulb[~inside] *= 0.1
    light += bulb + lamp(240, GROUND + 6, 230, (0.9, 0.5, 0.25), 0.45) * (yy >= GROUND)[..., None]
    light += lamp(470, 72, 60, (1.0, 0.25, 0.6), 0.45)
    for lx in range(70, W, 96): light += lamp(lx + 2, 50, 50, (1.0, 0.65, 0.3), 0.3)
    # finer steps, their edges dithered (a 4x4 Bayer pattern): pixel art's way of softening a gradient
    bayer = np.array([[0, 8, 2, 10], [12, 4, 14, 6], [3, 11, 1, 9], [15, 7, 13, 5]]) / 16.0 - 0.5
    steps = 9
    light = night + np.floor(light * steps + 0.5 + bayer[yy % 4, xx % 4][..., None] * 0.9) / steps
    out = b * light + em * 0.6
    g = Image.fromarray((np.clip(em, 0, 1) * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(5))
    out += np.asarray(g, dtype=float) / 255.0 * 0.55
    above = out[GROUND - (H - GROUND):GROUND][::-1].copy(); bright = np.clip(above - 0.35, 0, 1) * 1.6
    rip = random.Random(3)
    for row in range(H - GROUND):
        bright[row] = 0 if row % 3 == 2 else np.roll(bright[row], rip.randint(-3, 3), axis=0)
    out[GROUND:] += bright * np.linspace(0.5, 0.1, H - GROUND)[:, None, None]
    img = Image.fromarray((np.clip(out, 0, 1) * 255).astype(np.uint8))
    return img.quantize(72, method=Image.Quantize.MEDIANCUT, dither=Image.Dither.NONE).convert("RGB")

BARS = [
    {"tarp": ["e8833a", ""], "shape": "peaked", "sign": ["7a5230", "f2e3c4"], "sign_style": "wood", "name": "골목포차", "touches": ["string_lights"],
     "people": [(1, "#2d4a7a"), (2, "#6a3a4a"), (4, "#3a3a40")]},
    {"tarp": ["3a6ec8", "f5f2ea"], "shape": "awning", "sign": ["141224", "ff5fa8"], "sign_style": "neon", "name": "바다포차", "touches": ["lanterns"],
     "people": [(0, "#7a5a2a"), (3, "#2d4a7a")]},
    {"tarp": ["c8443a", "f5f2ea"], "shape": "scalloped", "sign": ["f2d24a", "b8281f"], "sign_style": "banner", "name": "이모네", "touches": ["string_lights", "lanterns"],
     "people": [(1, "#3a3a40"), (2, "#2a5a4a"), (3, "#5a2a5a"), (4, "#2d4a7a")]},
    {"tarp": ["3f9e5a", ""], "shape": "classic", "sign": ["f5f2ea", "2a52a0"], "sign_style": "lightbox", "name": "달빛포차", "touches": [],
     "people": [(2, "#6a3a4a")]},
    {"tarp": ["8a2c3e", ""], "shape": "rounded", "sign": ["141224", "ff5fa8"], "sign_style": "neon", "name": "별밤", "touches": ["string_lights"],
     "people": [(0, "#2d4a7a"), (1, "#3a3a40"), (3, "#7a5a2a")]},
    {"tarp": ["e8c03a", ""], "shape": "peaked", "sign": ["7a5230", "f2e3c4"], "sign_style": "wood", "name": "할매포차", "touches": ["lanterns"],
     "people": [(1, "#2a5a4a"), (4, "#6a3a4a")]},
]
out = Image.new("RGB", (W * 2 * 2 + 12, H * 2 * 3 + 24), (14, 14, 20))
swatches = {}
for k, look in enumerate(BARS):
    base, emit = scene(look, 7 + k)
    img, pal = lit_ramped(base, emit)
    swatches.update(pal)
    out.paste(img.resize((W * 2, H * 2), Image.NEAREST), ((k % 2) * (W * 2 + 12), (k // 2) * (H * 2 + 12)))
    if k == 0: img.resize((W * 4, H * 4), Image.NEAREST).save(sys.argv[1] + "/tent_lit.png")
out.save(sys.argv[1] + "/tents_range.png")
# the palette: each colour's ramp, a row each
keys = sorted(swatches, key=lambda c: colorsys.rgb_to_hsv(*[x / 255 for x in c])[0])
sw = Image.new("RGB", (7 * 18 + 8, len(keys) * 12 + 8), (14, 14, 20)); sd = ImageDraw.Draw(sw)
for i, key in enumerate(keys):
    for j, c in enumerate(swatches[key]):
        sd.rectangle([4 + j * 18, 4 + i * 12, 4 + j * 18 + 16, 4 + i * 12 + 10], fill=c)
sw.resize((sw.width * 3, sw.height * 3), Image.NEAREST).save(sys.argv[1] + "/palette_ramps.png")
print(len(keys), "colours with ramps")
