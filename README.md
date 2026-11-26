# KTBT: Korean Tent Bar Tropes

Think *Coffee Talk*, but with soju, tteokbokki and a heavy dose of K-drama tropes.

And it's all AI! During a week off work I decided to see what I could do vibe-coding with Claude, and running local AIs on my 5yo 3080ti gfx card. 

Every owner and customer is invented by and voiced by a local AI. All the gfx are generated, 

Night after night, the bar fills with characters who fit the hour: salarymen fleeing a company dinner, nurses off a night shift, a newly dumped office worker drinking alone, maybe a chaebol heir in disguise. They order from the menu, eat, drink and pour their hearts out to the owner, an AI-invented ajumma or ajusshi who has seen it all.

## Status

✅ **Latest (20 Nov):** a round of polish. One light for the people and the backdrop (lit from above, no dither, the bulbs' glow the light's own); **Let the crew run it**, autoplay from the menu for so many nights, shown on screen and safe to stop (after tonight, or taking over there and then); a toolbar over the transcript (search, All · Talk · Events, text size, Compact, catching up to the latest); a quiet console, each night's notes in its own file; the camera on the owner; and the cat keeping someone on its lap, being slipped a bit from a plate, and answering to its name (야옹) now and then.

**Before that (20 Nov):** the platform ladder. A new bar's show starts as a phone stream (views and likes) and climbs (or drops) three rungs season by season: an online video channel (its total subscribers) and network TV (시청률 ratings), each expecting more than the last, never off air. The season's verdict moves it, said in plain words ("Your show's been picked up by an online video channel!"). Moving on is to absolute targets: 1,000+ views a night over a season gets a channel, 10,000 subscribers gets a TV deal; the rules, and how the season's going, are on the numbers' hover in the top bar, and the whole story's in the side panel's The show. While a new bar's being made, the PD can set up the show (Enter) and start it on any rung. The owner's niece or nephew films the phone stream (named by the AI, with their stream's handle), and every channel the show's booked on is named by the AI too (달빛TV, Moonlight TV), never a real one.

**Before that (19 Nov):** seasons. Every eight episodes is a season: the eighth is the finale, and at 3am after it the season's looked back on (each episode's title, ratings and pinned line) and the channel gives its verdict, from the average ratings with a bonus for a new best or a hit: a hit season, renewed, or a warning (two quiet seasons in a row and the channel loses patience).

**Recently:** the show's ratings (시청률), worked out at 3am from what happened; the PD's desk (camera, plant cards, write-ins, the edit's spin on a caption, pins); a lighter, cheekier night that stays warm, not "bants"; the stage in pixel art, lit by the hour (the street, the tent, the people and the cat, words in a pixel Korean font); each bar's own menu. The whole story is in [DEVLOG.md](DEVLOG.md).

**How we work:** every change ships with tests, stats and docs (the definition of done is in [ARCHITECTURE.md](ARCHITECTURE.md)). A new chat with Claude starts from [START-HERE.md](START-HERE.md): the map, the gotchas and how to work, in two pages.

**Next up:** the next stage isn't picked yet: see the ideas in [PLAN.md](PLAN.md).

### What's in it so far

- **Bars:** start a new bar from the title screen (the AI invents its owner and a Korean name), carry on with a saved one, or delete old ones. Each bar saves itself as you go.
- **Nights:** 6pm to 3am, with time running faster while the tent's quiet. About twenty customers turn up, most in the late-evening rush, for five stools; when it's full, people walk on by. Each night is an episode: at 3am the owner writes it up in their diary (with the numbers behind a Stats button), the customers' posts about their night stuck round the page (on 달밤 Dalbam, the game's own app: a selfie, a food pic, the cat mid-theft or words alone, with real snapshots of the stage), and you can flip back through the diary, posts and all, any time. Opening a bar plays "Previously on…", a K-drama recap of last time, which now and then ends on what the internet said (a post or a viewer's comment, its card slammed on under 네티즌 반응 NETIZENS REACT).
- **Customers:** invented by the AI, each with a look the game decides (age range, hair, clothes, colours) and a name in Hangul too ("김지호 Kim Ji-ho"). They order from the menu, get drinks straight away while cooked dishes queue at the one stove, chat with the owner, sometimes talk to each other, and leave when their time's up.
- **Regulars:** two founding regulars per bar, and new customers can become regulars: they come back as themselves (★), remember what was said last time, get to know each other (∞), and fade away if they stop coming.
- **Who calls whom:** the game decides who may call whom what (oppa, eonni, imo, sajangnim…), and regulars can earn friendlier terms ("Can I call you eonni?"). Terms are coloured by warmth.
- **Korean words:** the menu, pocha words (banchan, jjan, aigoo, daebak…) and terms of address explain themselves on hover, in the transcript and the diary, and so does any Hangul (captions, names, stamps).
- **The owner:** AI-invented, with a secret and a fixed life (family, what they did before) the AI keeps to.
- **The cat:** with a personality, going where it likes, and a greedy one steals fish cakes; everyone talks about it (and now and then to it) as it really is.
- **Korean TV captions:** variety-show pop-ups with a sound sting for noteworthy moments ("짠! JJAN! CHEERS!", and "만석! FULL HOUSE!" with a flashing red light), and captions the AI writes for the big moments in conversation ("충격! SHE QUIT HER JOB?!"); the face of whoever it's about is slapped on, tilted, in that mood (shocked in a starburst, crying, blushing…), and the night's first big moment zooms over the whole window.
- **Look and sound:** each bar's own look (a Hangul-and-English sign, the cover's shape and colour), a sky that darkens through the night, weather, passers-by (in twos and threes, on their phones, under umbrellas, or running for it), speech bubbles, a K-TV title and loading screen; rain on the tarp, traffic, the odeng pot, and Arirang now and then. All placeholder art and sound, made in code.
- **You're the PD:** the night runs itself, and you shape the episode without ever pausing it: follow someone with the camera (they get the airtime; the cat, or the owner, too), play plant cards from tonight's hand of six (a regular rung and asked down, a downpour, the power going, a word from the show's made-up sponsor…), type write-ins the AI answers (two a night: a cue card, an interview question, a text someone gets), give a big moment's caption its spin in five seconds (the AI's own, the flip, or a roast), pin up to three lines a night for the episode (they're its quote, the diary's, and "Previously on…"), and, the next day, step in to cut the episode (its title, scenes and cliffhanger) before "Previously on…" airs. Every episode gets its TV ratings at 3am, and good ones bring a few more customers; every eight make a season, and its verdict moves the show up or down a ladder from a phone stream to a network.
- **The mood of a night:** lighter before midnight (teasing between friends, the owner's nagging, food fights, embarrassing stories), more open after it, and teasing that stays warm (see [CONCEPT.md](CONCEPT.md), "Cheeky, not 'bants'").
- **Offline mode:** runs without the AI too.
- **For testing:** a debug stats panel, nightly stats logs and night transcripts, and 916 automated tests (rules, prompts, asking the AI, offline mode, saves, stats, and whole visits, bars and nights played by clicking).

The bar runs itself; you play its PD. Talking to customers yourself comes later.

## Documents

| File | What's in it |
|---|---|
| [CONCEPT.md](CONCEPT.md) | The game concept, characters, K-drama style guide, saving/loading, menu, tech |
| [PLAN.md](PLAN.md) | What we're building next: upcoming stages and later ideas |
| [DEVLOG.md](DEVLOG.md) | A dated record of what's been done and why |
| [LLM-TUNING.md](LLM-TUNING.md) | LLM tuning notes: quirks in the local model's output and how we handle them |
| [TOOLCHAIN.md](TOOLCHAIN.md) | Setting up Godot, Ollama and the local model on Windows, with troubleshooting, and installing the test framework |
| [ARCHITECTURE.md](ARCHITECTURE.md) | How the code is laid out: the layers, and which file does what |
| [TESTS.md](TESTS.md) | How KTBT is tested: what's automated, what's playtested, conventions and coverage |
| [ART.md](ART.md) | The art direction: pixel art with real lighting, the stage, the palette and its light ramps, and what never goes in |

## Tech

- **Engine:** [Godot 4](https://godotengine.org) (GDScript)
- **AI characters:** a local LLM (Llama 3.1 8B to start) served by [Ollama](https://ollama.com), called from Godot over HTTP
- **Target platform:** Windows PC, with an NVIDIA GPU of roughly 10GB+ VRAM for the local model (or offline mode without one, from the Tests stage)

## Running it

1. Set up the toolchain using [TOOLCHAIN.md](TOOLCHAIN.md).
2. Make sure Ollama is running and the model is pulled.
3. Open Godot, **Import** `project.godot` from this folder, and press **Play** (F5). Start a **New bar**, or open a saved one.

**Saves** live in `saves/` in Godot's user data folder, one readable JSON file per bar. On Windows that's `%APPDATA%\Godot\app_userdata\KTBT\saves\` (paste it into Explorer's address bar), or in Godot use **Project → Open User Data Folder**. Saving is automatic, and each machine keeps its own saves. Delete old bars from the title screen.

**Sound settings:** the Sound on/off and volume, and the Music volume, are kept in `settings.cfg` in the same user data folder.

**The screen:** the tent on top; underneath, the transcript, the PD's desk (the camera, tonight's plant cards, the writing box and the edit), and a side panel in four tabs: Here now (the owner, the cat, everyone at the counter), The show (who films it, where it goes out, how it's doing and what moves it on, the last episodes, the channels it's been on: a click on the top bar's numbers opens it), Diary (the owner's diary, popped up full size) and Stats (tonight's debug stats, every section, from a dropdown). The Esc menu (the screen dimmed behind it, as in most games) has the Commands (Resume, Close the bar, letting the crew run it, Quit game) and the Options (Screen: bubbles, captions, reading pauses; Sound: sound and music). **Stats:** and each night writes a stats log (JSON), to compare runs: to `logs/stats/` in the project folder when you play from the Godot editor, beside the transcripts, otherwise to `stats/` in the same user data folder.

**Transcripts:** each night's transcript is written, as it goes, to `logs/transcripts/` in the project folder when you play from the Godot editor (kept out of git by `.gitignore`), so you can read or share how a night went. To follow a night in a terminal, as it goes: `Get-Content (Get-ChildItem logs\transcripts | Sort LastWriteTime | Select -Last 1).FullName -Wait -Tail 40` (PowerShell).

**Debug notes:** what the game decides as it goes (regulars turning up, facts and threads remembered, who came in together, the ratings, the street…) goes to each night's own file in `logs/debug/` beside its transcript, each with the time. The console (VS Code's Debug Console, the terminal) stays quiet: the light once an hour (it's ticking along), autoplay and the crew, the season, and where the night's files are, plus any errors. Run with `-- --log-all` to put everything on the console too.

**Choosing the AI:** each machine has an `ai_settings.cfg` (in Godot, **Project → Open User Data Folder**) with `backend` set to `auto` (Ollama, falling back to offline mode), `ollama` or `canned` (offline mode: pre-written characters, no AI), plus the Ollama `server` and `model`, and `faces` (`owner_and_regulars` by default, `owner`, or `off`: faces of their own made by the image model, with `comfyui` its folder, or `tools/comfyui_path.txt`'s). See [TOOLCHAIN.md](TOOLCHAIN.md#5b-ai-settings-choosing-which-ai-the-game-uses).

**No suitable GPU?** Use offline mode, a small model on the CPU, or another machine's Ollama. See [TOOLCHAIN.md](TOOLCHAIN.md#5a-machines-without-a-suitable-gpu).

**Making art:** `python3 tools/art/tent.py` draws the tent's own pixel art in code (every tarp colour and shape, the counter, the stools, the fittings, sign boards and touches) into `art/`, `python3 tools/art/people.py` the people's layers, `python3 tools/art/cat.py` the cat, and `python3 tools/art/clipart.py` the edit's clipart (`--sheet out.png` to look at it); `python3 tools/art/light_preview.py out.png` shows the tent and people lit at an hour as the game lights them, to check a change to the art's shading. `python3 tools/art/pixelate.py <picture> --height 16 --key touch/lucky_cat --source "..." --licence "..."` turns an image model's picture into the game's pixel art (background cut out, onto the grid, into the palette) and adds it to `art/` with its source and licence; `--self-test` checks the tool. `python3 tools/art/portraits.py <pictures> --sheet out.png` turns the model's head-and-shoulders pictures into portraits (split into hair, skin and clothes, in the people's layer encoding) and paints them onto several looks on a contact sheet; `--batch` writes the library's list for the helper's `queue_art_batch`, `--pick <folder>` makes the pick sheets (best of each three pre-picked, in `art/raw/portrait_picks.json`) and `--keep` puts the picks into `art/portraits/`; `--reactions` writes the reaction faces' list (every kept portrait in every TV mood), `--react-pick <folder>` their close-ups' pick sheets (in `art/raw/reaction_picks.json`) and `--react-keep` puts them into `art/reactions/`; `--expect <folder>` writes what the game's own split (`scripts/rules/portrait_split.gd`) should make of the pictures there, for its test. See [ART.md](ART.md).

**Autoplay (test nights while you're away):** run the VS Code task **Autoplay nights** (Ctrl+Shift+P, **Tasks: Run Task**; it asks how many), or double-click `tools/autoplay.bat`, to play 10 nights by themselves with the real AI (`autoplay.bat 5` for 5; `autoplay.bat 5 <bar id>` to carry on a bar). It needs Ollama running, and Godot's path in `tools/godot_path.txt` (one line; it's this PC's own, so not in git). To let Claude start one from your phone, add `tools/autoplay_mcp.ps1` to the Claude desktop app (see [TOOLCHAIN.md](TOOLCHAIN.md), "Autoplay from your phone"). It starts a bar of its own ("played by autoplay" on the title screen), logs each night as usual, writes a summary to `logs/autoplay/` (and, while it runs, `running.json` there, saying so), and stops after its nights, or at the end of a night if Ollama stops answering. An autopilot PD plays the desk too: the cards (at their own times, write-ins with words from a small list), the camera now and then, a few pins, the edit's spins, and stepping in to cut the episode, all marked "(Autopilot PD …)" in the transcript.

**The transcript (bottom left):** a toolbar over it: search (Ctrl+F; words or someone's name, every match marked, Enter and Shift+Enter to go through them, Esc to clear), All, Talk (only what people say: the lines you can pin) or Events (only what happens), A− and A+ for the text size, and Compact (lines closer together, each with its time). Scrolled up to read something, new lines wait: "↓ 7 new lines" (or End) takes you back to the latest. The size and Compact are remembered.

**Let the crew run it (autoplay in the game):** the menu (Esc) has a row to hand the bar to the crew for so many nights (5 by default, up to 30): the PD's desk and opening the next night play themselves, as in a batch, on the bar that's open (tonight, if it's open, is the first). While they're running it the top bar says so ("▶ CREW RUNNING · NIGHT 3 OF 10"), and whatever would upset the run is locked (closing the bar, the desk, stepping in, opening the next night, reading pauses); everything you only look at works. Stop (the badge, the menu, or Close the bar) asks: after tonight (played out and written up, then the bar's yours), or now (tonight's yours from there). When their nights are done the bar's handed back, not quit. Its summary goes to `logs/autoplay/` like a batch's; it isn't on the phone helper's list (no `running.json`: the helper's Stop ends the game). A batch from the command line can be stopped the same way, and then hands the bar back too.

**Tests:** `python tools/run_tests.py` runs them all headless in three Godots at once (`--quick` leaves out a few slow picture checks; Godot's path from `tools/godot_path.txt`), with one pass or fail and the failures at the end. Or open the **GdUnit** panel in Godot and click **Run All**, or use gdUnit's own command-line runner. They don't need Ollama. See [TESTS.md](TESTS.md).

## Project layout

| Path | What it is |
|---|---|
| `project.godot` | Godot project settings (main scene: `scenes/title.tscn`; autoload: `Game`) |
| `scenes/title.tscn` | The title screen: New bar, or open a saved one |
| `scenes/visit.tscn` | The bar itself: owner, customers, orders and conversation (its UI, the tent and the people are drawn in code) |
| `scenes/pipeline_test.tscn` | The pipeline test, kept as a quick AI check (open it and press F6) |
| `logs/` | Night transcripts, written when playing from the editor (not committed) |
| `scripts/game.gd` | The `Game` autoload: which bar is open, opening and closing bars, saving on close, and the music (which carries on between scenes) |
| `scripts/pipeline_test.gd` | Pipeline test logic |
| `scripts/test_hooks.gd` | Every test hook in one place (the game only reads them) |
| `scripts/title.gd` | Title screen logic (and its Music slider) |
| `scripts/visit.gd` | The bar's night: new or saved bar, the clock and its loop, arrivals, what the owner does next, orders, asking the AI for each line, stays, bills, the night summary and autosave, putting the parts in `scripts/bar/` together |
| `tests/` | GdUnit4 tests (with a shared base in `tests/support/`): rules, menu, prompts, offline mode, saves, stats, and click-through visits, bars and nights (see [TESTS.md](TESTS.md)) |
| `.github/workflows/tests.yml` | Runs all the tests on GitHub on every push |
| `addons/gdUnit4/` | The GdUnit4 test framework (v6.2.0) |
| `scripts/ai/ai.gd` | Asks the AI for JSON, validates the reply, and retries with feedback if it's wrong; picks Ollama or offline mode |
| `scripts/ai/ai_settings.gd` | Reads each machine's `ai_settings.cfg` (backend, server, model, faces, ComfyUI's folder) |
| `scripts/ai/canned_ai.gd` | Offline mode: pre-written owners, customers, orders and lines, built to pass the game's rules; also the tests' fake AI |
| `scripts/ai/ollama_client.gd` | Talks to Ollama's local HTTP API |
| `scripts/ai/portrait_maker.gd` | Faces of their own: drives ComfyUI on this PC (starts it, queues Klein, fetches and splits the pictures, stops it) |
| `scripts/ai/prompts.gd` | The K-drama style guide and every prompt sent to the AI |
| `scripts/bar/` | The tent's parts, each with one job and its own tests: the tent's look (`tent_view.gd`), drawing people (`people_view.gd`), the street (`street.gd`), the cat (`cat.gd`), the stove (`kitchen.gd`), TV captions on screen (`captions_on_screen.gd`), the transcript and the recap's facts (`story_keeper.gd`), regulars tonight (`regulars_tonight.gd`), customer chats (`counter_chats.gd`), who calls whom (`friendliness.gd`), what each line is given (`conversation.gd`), the PD's cards waiting their turn (`card_slots.gd`), the tent's fixtures (`scenery.gd`), the stats panel's tabs (`stats_panel.gd`), the PD's camera (`camera.gd`), the PD's desk (`pd_desk.gd`), tonight's shared state (`night.gd`), the stage's layout (`layout.gd`) and small drawing helpers (`draw.gd`) |
| `scripts/bar/night_events.gd` | The night's events, announced once each, for the stats, captions and diary |
| `scripts/bar/snapshots.gd` | Real snapshots of the stage for the customers' posts, with no bubbles, captions or panels in them |
| `scripts/bar/night_stats.gd` | The debug stats for a night: the stats panel and the nightly stats log |
| `scripts/rules/` | The game's rules, one file per area (see [ARCHITECTURE.md](ARCHITECTURE.md)): pure functions and their tables, no scene or AI, so easy to test |
| `scripts/rules/menu.gd` | The menu, prices and each dish's Hangul (the game's facts) |
| `scripts/rules/regulars.gd` | Regulars: who comes back, how often, how they fade, and a simulation of months of nights |
| `scripts/rules/ladder.gd` | The platform ladder: three rungs, a phone stream, an online video channel and network TV, each showing the night's score in its own units and judging a season against its own targets |
| `scripts/rules/channels.gd` | The show's people and places: the owner's niece or nephew who films it, and the channels it's booked on, named by the AI and checked |
| `scripts/rules/ladder_sim.gd` | The ladder simulated: many shows through many seasons in a moment, no scene or AI, to see how it's paced |
| `scripts/rules/socials.gd` | The customers' posts at 3am: which (0–3, from what happened), what the AI writes them from and the check of its words, the game's own words and hashtags, the check, and which moments want a snapshot |
| `scripts/rules/viewers.gd` | The viewers' comments at 3am, by rung: what about (tonight's figure first), how many and their likes (from the night's score), what the AI writes them from and the check of its words, the game's own words |
| `scripts/rules/show_seasons.gd` | The show's seasons of eight episodes: the finale, the season looked back on, the channel's verdict |
| `scripts/save/save_store.gd` | Reads, writes and deletes each bar's save file, safely |
| `scripts/sound/ambience.gd` | The tent's background sound: loops and one-off sounds made in code, following the scene |
| `scripts/sound/music.gd` | The background music: Arirang, arranged in code, from the title screen on |
| `scripts/ui/art.gd` | The art arriving a piece at a time: `art/manifest.json` maps the game's facts to images, drawn in pixels; anything without one is drawn in code |
| `scripts/ui/bubble.gd` | A speech bubble: over the speaker, who it's to, a line to the listener, and long lines a page at a time |
| `scripts/ui/caption.gd` | A Korean TV caption: Hangul over a coloured English tag, popping in and fading |
| `scripts/ui/caption_reel.gd` | Captions popping up by themselves, for the title and loading screens |
| `scripts/ui/diary_book.gd` | The owner's diary as a book: a page at a time, older and newer |
| `scripts/ui/diary_page.gd` | A page of the owner's diary: the episode, the day, the entry and a stamp, and the night's polaroids if it has them |
| `scripts/ui/polaroid.gd` | A polaroid on the diary page: someone's portrait in a white frame, taped down at a tilt, their name written under it |
| `scripts/ui/social_post.gd` | A customer's post on 달밤 (Dalbam, the game's own feed app): their handle, the snapshot in a phone photo's frame (or one drawn), the words and hashtags |
| `scripts/ui/social_feed.gd` | The night's posts stuck round the diary page, at 3am and in the diary book (and the viewers' comments, bottom right) |
| `scripts/ui/viewer_comments.gd` | The viewers' comments on the episode: the phone stream's live chat, the channel's comments or TV's viewer board, with their hearts, likes or recommends |
| `scripts/ui/dish_view.gd` | A dish or drink on the table in pixel art, painted from its shapes (see `rules/dish_art.gd`) on their colours' ramps, lit from above, a darker edge round it, lit by the hour |
| `scripts/ui/ktv_style.gd` | The game's look in one place: the K-TV palette, labels, pills and title-card text |
| `scripts/ui/loading_screen.gd` | The loading screen shown while a bar is set up or reopened, over its own tent (a placeholder for a new bar until its look is chosen), with the channel the show's on |
| `scripts/ui/menu_board.gd` | The menu board, in the bar's style: click it to read the whole menu (specials, food, drinks, the favourite and sold-out marked) |
| `scripts/ui/recap_screen.gd` | "Previously on…": the K-drama recap, in one of four K-TV styles, with a post's or comment's card beside a beat that cuts to the internet |
| `scripts/ui/show_setup.gd` | Setting up the show: while a new bar's being made, the PD chooses where it starts on the ladder (more of the setup later) |
| `scripts/ui/recast_screen.gd` | Recasting a regular's face: at 3am, the PD has three new casting photos taken of a regular and picks one |
| `scripts/ui/season_page.gd` | The season looked back on (시즌 결산), after a finale: an episode a row, and the verdict |

## AI usage

AI is used in two quite different ways in this project.

### 1. Building it: vibe coded with Claude
This project is an experiment in **vibe coding**. The code and documentation are written by [Claude](https://claude.ai) (Anthropic's AI assistant), working from the developer's direction.

- **The developer** owns the idea, makes the design decisions, runs and playtests each build, and reports what's broken or what feels wrong.
- **Claude** writes the GDScript, scenes and docs, and fixes issues based on that feedback.
- Work proceeds in small, playable stages (see [PLAN.md](PLAN.md) and [DEVLOG.md](DEVLOG.md)) so every change is tested by a human before moving on.

Commits made by Claude are marked with a `Co-Authored-By: Claude` line.

### 2. Running it: a local LLM generates the characters
At runtime the game uses a **local** language model (via Ollama) to:

- invent each bar's owner and name when a new bar is started, and choose its look (sign, tent cover, touches) from options the game offers
- invent customers suited to the time of night, day and weather, to fit the gender, age range and look the game has decided
- choose each customer's order from the bar's current menu
- write the conversation between each customer and the owner

Design guard-rails:

- **The game owns the facts; the AI owns the flavour.** Time, menu, prices and seating are controlled by game code. The AI's structured output (JSON) is checked, and anything invalid, such as an order for a dish that isn't on the menu, is rejected and retried.
- **Everything runs locally.** No cloud AI service is called, no API key is needed, and nothing you see in the game leaves your machine (unless you point the settings at another PC's Ollama on your own network).
- **Offline mode is clearly marked.** Without the AI, the game uses pre-written characters and lines instead, and shows an **OFFLINE MODE** badge so they're never mistaken for AI output.
- **Generated content is unscripted.** Characters and dialogue are created fresh each time and aren't reviewed by a human, so expect occasional oddities. A shared style guide in every prompt keeps the tone warm, melodramatic and K-drama flavoured.

## Assets and credits

No third-party assets yet: the art, sounds and music are placeholders made in code, original to the project (the music is Arirang, a traditional folk song in the public domain). Any third-party art, sound or music added later will be listed with its source and licence in `CREDITS.md`.

## Licence

KTBT is free and open source, under share-alike licences:

- **Code** (GDScript, scenes, project files): [GNU General Public License v3.0](LICENSE). You can use, modify and share it, including commercially, but any distributed version must also be released under the GPL with its source.
- **Docs and original creative assets** (documentation, art, audio, writing, prompts): [CC BY-SA 4.0](LICENSE-ASSETS.md).
- **Third-party assets** keep their own licences, listed in `CREDITS.md`.
- **Godot Engine** is MIT-licensed. See https://godotengine.org/license.
