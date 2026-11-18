# KTBT: Art direction

How KTBT looks, and the rules every picture in it follows. What's still to build is in [PLAN.md](PLAN.md) ("Real art"); what's been done, in [DEVLOG.md](DEVLOG.md).

**In one line:** a pocha at night in pixel art, its tarp glowing from inside under a Seoul overpass, lit by real light.

## The style

- **Pixel art with real lighting.** The art is drawn in code, and a local image model makes the parts that need variety and detail (see **Where the art comes from**). Pixel art suits both: a model's picture can be shrunk onto the grid and repainted in the palette, and people built from layers are palette swaps, matching the looks the game already decides.
- **The mood is the light**, not the detail: a warm bulb under the tarp, the tarp glowing, steam, neon across the street, light spilling onto a wet road. The same scene unlit is clean but cold (the style test, 18 Nov).
- **Only the stage is pixel art.** The transcript, the PD's desk, the stats and every other panel stay sharp text in the K-TV look (`ui/ktv_style.gd`).

## The stage

- **480×270 pixels, scaled 4× to 1920×1080** (nearest-neighbour: never smoothed). At other screen sizes it scales by a whole number and sits centred, so pixels stay square.
- **Laid out from the game's facts, never by eye.** The style test first drew 4 stools by eye; the game has 5 (`NightRules.SEATS`). Whatever the game counts or decides is read from the game: the seats, the tarp, the tent's shape, the sign and its text, the touches (`rules/bar_look.gd`), the weather, the time, who's sitting where, what's on the counter.
- **The tent is most of the stage**, as it is today: it's where everything happens. In the style test: the tent's sides at x 18 and 462, the ground at y 214, the counter at y 166 to 186, the seats evenly along it, the owner behind it. The street shows at the edges and above the roof: the overpass, apartment windows, a neon sign down a building's side.
- **Every bar its own, all the same game:** the tarp's colour (and stripes), its shape (classic, peaked, scalloped, awning, rounded), the sign's style (wood, neon, banner, lightbox), one or two touches (string lights, red lanterns...). See `logs/screens/tents_range.png` from the style test (not in git: re-made by `tools/art/style_test.py`).

## The palette and its light ramps

- **Every colour has a ramp of 7 steps**, from deep shadow to highlight, made by `ramp()` in `tools/art/style_test.py`: the shadow end shifts towards blue (and a little more saturated), the light end towards warm yellow (and a little less). A blue night lit by a warm bulb, in every colour.
- **The light picks a step in each pixel's own ramp.** A pixel never takes another colour's shade, so small things keep their colour (a single shared colour reduction turned the green bottles grey; with ramps they stay green).
- **Between steps, a 4×4 Bayer dither**, so the light falls in soft bands rather than hard rings.
- **The colours themselves come from the game** where the game has them (the tarps, signs and touches in `bar_look.gd`; people's looks), and from a fixed set for materials: wood, red and blue plastic, green glass (never labelled), steel, steam, paper, skin tones, hair colours.
- **Watch the glow's strength.** With ramps, the tarps came out evenly bright rather than glowing out of the dark: how much a glowing thing lifts its own step, against how dark the night is, is to tune in the game.

## Lighting rules (what the style test taught)

- **What's in front hides what glowed behind it** (the apartment windows shone through the tent until it did).
- **The bulb does the work; the tarp glows dim.** A tarp glowing hard washed the inside out to yellow-white.
- **The tarp holds the light in**: the bulb lights the inside; outside, it's the tarp's own glow and the pool of light on the ground in front.
- **The wet road reflects only what's bright**, mirrored and broken into horizontal ripples, fading with distance (vertical streaks read as a fence).
- **The night is cool and dark**; lamps, neon, windows, string lights and lanterns glow by themselves, and light what's round them a little.

## The mood board (in words)

An orange tarp is the classic; ours vary (see above). Red and blue plastic stools. Green soju-style bottles with no label. Steam from the pots. Handwritten menus pinned to the tarp's back wall. A bare bulb. The overpass's concrete overhead, its sodium lamps. Apartment windows, some lit. A 노래방 sign in neon across the street. Rain drumming on the tarp, snow on its roof, wet tarmac.

## What never goes in

- **No brands:** no logos, no real labels, no real products (the show's sponsors are its own made-up ones, `rules/plants.gd`). No real business's sign or name.
- **No made-up Hangul.** Any Korean on screen is a real word, from the game's data, and explains itself on hover (as everywhere in KTBT). A model's picture loses any text it drew; real text is put back in a font.
- **No real people**, and no likeness of anyone.
- **Nothing a Korean player would wince at:** all the art is part of the Korean cultural review before anyone else plays (PLAN, "A cultural review").

## Text on the stage

- **Hangul in a free pixel Korean font** (Galmuri is the first to look at; its licence, the SIL Open Font Licence, to check), logged in LICENSE-ASSETS. Never drawn by a model. The style test used the system's Noto Sans CJK, thresholded, as a stand-in.
- **English on signs** in a pixel font from the same family, where there is one.

## People (a later stage)

Bigger figures at the counter, built from layers the game's facts choose (age range, hair, clothes, colours, extras), so a regular looks the same every visit, with moods shown in pose (slumped, laughing, a hand on the head). Same palette, same ramps, same light. Details to come with that stage.

## Where the art comes from

- **Drawn in code:** what has to be consistent and follow the game's facts: the tent, the counter, the stools, people's layers, animation.
- **Made by a local image model, through the pixelate tool:** what needs variety and detail: the street and buildings behind, the skyline, props, dishes. The tool shrinks a picture onto the grid, repaints it in the palette, cuts out its background and paints out any text. The model runs on the desktop's GPU in a session of its own, never while Ollama's playing, with a licence that allows it (checked first).
- **Every asset logged in LICENSE-ASSETS.md**, with where it came from and its licence.

## How it'll work in Godot

- **The stage in its own 480×270 viewport**, shown scaled with nearest filtering.
- **Lighting by palette:** each sprite's pixels say which colour (and so which ramp) they are; the lights decide each pixel's step; a shader looks the step up in a ramp texture, with the Bayer dither. So the light never makes a colour that isn't in the palette, and it runs fine on the laptop.
- **Lights are data:** the bulb, the lamps, the neon, the windows, from what the game says is there (and the weather and the time of night).
- **Screenshot tests** once the art settles.
