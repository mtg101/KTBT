# KTBT: Art direction

How KTBT looks, and the rules every picture in it follows. What's still to build is in [PLAN.md](PLAN.md) ("Real art"); what's been done, in [DEVLOG.md](DEVLOG.md).

**In one line:** a pocha at night in pixel art, its tarp glowing from inside under a Seoul overpass, lit by real light.

## The style

- **Pixel art with real lighting.** The art is drawn in code, and a local image model makes the parts that need variety and detail (see **Where the art comes from**). Pixel art suits both: a model's picture can be shrunk onto the grid and repainted in the palette, and people built from layers are palette swaps, matching the looks the game already decides.
- **The mood is the light**, not the detail: a warm bulb under the tarp, the tarp glowing, steam, neon across the street, light spilling onto a wet road. The same scene unlit is clean but cold (the style test, 18 Nov).
- **Only the stage is pixel art.** The transcript, the PD's desk, the stats and every other panel stay sharp text in the K-TV look (`ui/ktv_style.gd`).

## The stage

- **624×154 pixels, each 3 on screen: 1872×462** (nearest-neighbour: never smoothed), across the top of the screen, with the transcript, the PD's desk and the stats below it (decided 18 Nov: the stage grew from 380 tall so more street and sky show, and the panels gave up the room; 540 left the PD's desk too little, so 462; the style test's full-screen 480×270 didn't allow for the panels). The tent's stage keeps its 1872×380 at the bottom of it; the street (`bar/street_art.gd`) is behind the whole of it, reaching 82 above the stage. The tent, its light and the people move onto the grid later.
- **Laid out from the game's facts, never by eye.** The style test first drew 4 stools by eye; the game has 5 (`NightRules.SEATS`). Whatever the game counts or decides is read from the game: the seats, the tarp, the tent's shape, the sign and its text, the touches (`rules/bar_look.gd`), the weather, the time, who's sitting where, what's on the counter.
- **The tent is most of the stage**, as it is today: it's where everything happens (in the game the tent's open at the back, so the street shows through it too). In the style test: the tent's sides at x 18 and 462, the ground at y 214, the counter at y 166 to 186, the seats evenly along it, the owner behind it. The street shows at the edges and above the roof: the overpass, apartment windows, a neon sign down a building's side.
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

## People

- **Their size, against the tent:** 32×72 pixels on the grid (96×216 on the stage): a pocha's counter is about a metre (123 on the stage), so a person's about 1.7 of them, and the stools are knee high (their seat 60 above the ground). The first size, 27×50, kept from the shapes before, made the people tiny against the bar.
- **Built in layers, like a paper doll,** from the facts the game decides (`rules/looks.gd`: age range, hairstyle and colour, clothes and colour, skin, glasses, a bag, the owner's apron), so a regular looks the same every visit: body, clothes, head, hair, extras, in two views (facing us; from behind, seated at the counter).
- **Drawn in code, in shades only** (decided 18 Nov; `tools/art/people.py`, 54 layers): each layer says how lit each pixel is (a step of 0 to 6) and what it's made of (skin, hair, cloth, or a fixed colour), and the game paints it onto that colour's light ramp when someone's dressed (`ui/people_art.gd`: on the CPU, once a look, which turned out simpler than a shader), so one bob serves every hair colour and one coat every cloth colour. The layers have to line up pixel for pixel (the same shoulders under every coat), which an image model can't keep; pixel-art games draw them by hand.
- **The same size sitting as standing, on the same ground:** everyone's picture stands on the ground (its top at 156 on the stage), walking, coming in, sitting or leaving; seated from behind, they're drawn with the standing figure's proportions, the seat on the stool and the lower legs down either side of it. (A first try drew them the picture's full height seated, so anyone walking past looked smaller, and they rose off the ground to sit down and flew off again.)
- **Moving:** on the grid's lines wherever they go, and breathing (the head and shoulders rise a pixel now and then; `ui/pixel_person.gd`), walking from the side whenever they move (a stride of four frames, legs and arms swinging, a frame every 20 they go; drawn facing right and mirrored to walk left: 47 more layers, a body for each kind of clothes, the head, every hairstyle, the extras, and the legs and arms by frame), and facing us again when they stop; four frames of stepping facing us looked like marching on the spot, and they'd glide facing us with a bob without the side layers; the oldest stoop (their head and neck a little lower, into their shoulders); a big moment's mood shows in the pose of whoever it's about (a laugh shakes their shoulders, a sad one slumps them, a shock jolts them up, a warm or sweet one's a nod, an awkward one a fidget); umbrellas and the snow on them are drawn in the grid's pixels as they're made (`ui/pixel_shape.gd`), the phone in whole pixels; to come, poses that need arms of their own (a hand to the head, a glass raised) (slumped, laughing, a hand on the head, a glass raised).
- **Later, an idea:** a portrait of each character from the image model, for the hover or the diary.

## Where the art comes from

- **Big from the model, small in code** (decided 18 Nov, from the first lucky cat): a model's detail survives only on things with room for it. At 24 to 32 pixels tall the cat kept its face, collar and bell; at 9 to 12, the size a counter ornament is on the stage, it was a white blob with ears. So:
- **Drawn in code:** what's small (under about 16 pixels: the touches, bottles, glasses, lanterns, string lights, dishes on the table), where every pixel is a choice and code places it exactly; and what has to follow the game's facts: the tent, the counter, the stools, people's layers, animation. In the same palette and light, so it all matches.
- **The tent in code, in pixels** (`tools/art/tent.py`): one cover for each tarp colour and shape the game offers (50), the counter and red and blue plastic stools, and in `fittings.py` the stove, the odeng pot, the drinks fridge, a sign board for each style (its words stay text over it, to hover), a menu board for each of its styles, the bulbs (drawn pale, tinted by the hour), the neon's board, and every touch (string lights, lanterns, a radio, plants, a calendar, the lucky cat, photos, a fishing net, knives), each lit from inside by the bulbs on the palette's ramps with a dithered step, a dark line along a cover's top; drawn on the street's grid at the stage's own outlines (the stage's top on a row of the grid, so they line up), so everything hung from the cover and stood on the counter still fits. The game uses them where they're there (`tent_view.gd`, `visit.gd` `_pixel_piece`) and the shapes where they aren't.
- **Dishes and drinks** stay drawn from their shapes (`rules/dish_art.gd`), but in whole pixels of the grid's size (`dish_view.gd`), so they sit with the rest.
- **Made by a local image model, through the pixelate tool:** what's big and needs variety and detail: the street and buildings behind the tent, the overpass, the skyline (and maybe, later, portraits of the characters). Thin lines (power cables) come out dotted: code draws those. The tool shrinks a picture onto the grid, repaints it in the palette, cuts out its background and paints out any text. The model runs on the desktop's GPU in a session of its own, never while Ollama's playing, with a licence that allows it (checked first).
- **The pixelate tool** (`tools/art/pixelate.py`, with the palette in `tools/art/palette.py`): cuts out the background (ask the model for one thing on a flat green background; magenta for something green), shrinks it onto the grid in the palette (each pixel sampled 8×8 times, each sample to the nearest colour on any light ramp, keeping its colour and its shading; the pixel takes the colour most samples are, but a dark line that's a fair part of it wins, so outlines and eyes survive), tidies lone pixels, and can add a dark outline. With `--key` it goes straight into `art/`, the manifest and LICENSE-ASSETS. The palette's base colours are read from the game's own tables (`bar_look.gd`, `looks.gd`) plus a fixed set of materials, near-duplicates merged (46 now). Text a model draws is never real Korean: cropped out or painted over first.
- **Every asset logged in LICENSE-ASSETS.md**, with where it came from and its licence.

## The art folder

- **`art/manifest.json` maps the game's facts to images:** `"touch/lucky_cat": {"file": "touches/lucky_cat.png", "source": ..., "licence": ...}`. A key is a kind of thing the game draws and the id the game has for it (`scripts/ui/art.gd`, `ids()`: the bar's touches for now; the street, people and food come with their stages).
- **A piece at a time:** whatever has an image is drawn from it, in pixels (4×, never smoothed), standing on or hanging from the spot the game draws it at; whatever hasn't is drawn in code as before. An image that won't load is an error (in the log, and an autoplay batch's summary) and is drawn in code. Which was which is in the night's stats ("Art: images 1 · drawn in code 3").
- **Kept honest by the tests** (`test_art.gd`): every key one the game has, every file there, its source and licence given, and listed in LICENSE-ASSETS.md.
- **Export:** the manifest is JSON, not an imported resource, so the export presets will need `art/*.json` in their extra files (when there's an export).

## How it'll work in Godot

- **The stage in its own 480×270 viewport**, shown scaled with nearest filtering.
- **Lighting by palette:** each sprite's pixels say which colour (and so which ramp) they are; the lights decide each pixel's step; a shader looks the step up in a ramp texture, with the Bayer dither. So the light never makes a colour that isn't in the palette, and it runs fine on the laptop.
- **Lights are data:** the bulb, the lamps, the neon, the windows, from what the game says is there (and the weather and the time of night).
- **Screenshot tests** once the art settles.
