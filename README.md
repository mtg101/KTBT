# KTBT: Korean Tent Bar Tropes

A cosy simulation of a Korean pojangmacha (street tent bar), where every owner and customer is invented by an AI. Think *Coffee Talk*, but with soju, tteokbokki and a heavy dose of K-drama tropes.

Night after night, the bar fills with characters who fit the hour: salarymen fleeing a company dinner, nurses off a night shift, a newly dumped office worker drinking alone, maybe a chaebol heir in disguise. They order from the menu, eat, drink and pour their hearts out to the owner, an AI-invented ajumma or ajusshi who has seen it all.

## Status

✅ **Latest:** a playtest review, and what came of it: Korean words explained on hover (the menu, pocha words, terms of address), table customs and sharing as hints, tonight's specials and cravings, orders that don't all sound the same, more TV reactions, and a street of umbrellas, phones and people walking together. Before that: "Previously on…", the owner's diary, and Korean TV captions.

**Next up:** see [PLAN.md](PLAN.md): the night as a story is done; next could be the refactor, real art and sound, or the game itself. See [PLAN.md](PLAN.md) for what's next and [DEVLOG.md](DEVLOG.md) for what's been done.

### What's in it so far

- **Bars:** start a new bar from the title screen (the AI invents its owner and a Korean name), carry on with a saved one, or delete old ones. Each bar saves itself as you go.
- **Nights:** 6pm to 3am, with time running faster while the tent's quiet. About twenty customers turn up, most in the late-evening rush, for five stools; when it's full, people walk on by. Each night is an episode: at 3am the owner writes it up in their diary (with the numbers behind a Stats button), and you can flip back through the diary any time. Opening a bar plays "Previously on…", a K-drama recap of last time.
- **Customers:** invented by the AI, each with a look the game decides (age range, hair, clothes, colours) and a name in Hangul too ("김지호 Kim Ji-ho"). They order from the menu, get drinks straight away while cooked dishes queue at the one stove, chat with the owner, sometimes talk to each other, and leave when their time's up.
- **Regulars:** two founding regulars per bar, and new customers can become regulars: they come back as themselves (★), remember what was said last time, get to know each other (∞), and fade away if they stop coming.
- **Who calls whom:** the game decides who may call whom what (oppa, eonni, imo, sajangnim…), and regulars can earn friendlier terms ("Can I call you eonni?"). Terms are coloured by warmth.
- **Korean words:** the menu, pocha words (banchan, jjan, aigoo, daebak…) and terms of address explain themselves on hover, in the transcript and the diary.
- **The owner:** AI-invented, with a secret and a fixed life (family, what they did before) the AI keeps to.
- **The cat:** with a personality, going where it likes; everyone talks about it as it really is.
- **Korean TV captions:** variety-show pop-ups with a sound sting for noteworthy moments ("짠! JJAN! CHEERS!", and "만석! FULL HOUSE!" with a flashing red light), and captions the AI writes for the big moments in conversation ("충격! SHE QUIT HER JOB?!").
- **Look and sound:** each bar's own look (a Hangul-and-English sign, the cover's shape and colour), a sky that darkens through the night, weather, passers-by (in twos and threes, on their phones, under umbrellas, or running for it), speech bubbles, a K-TV title and loading screen; rain on the tarp, traffic, the odeng pot, and Arirang now and then. All placeholder art and sound, made in code.
- **Offline mode:** runs without the AI too.
- **For testing:** a debug stats panel, nightly stats logs and night transcripts, and 451 automated tests (rules, prompts, asking the AI, offline mode, saves, stats, and whole visits, bars and nights played by clicking).

Version one is a **simulation**: you watch the bar run itself. Talking to customers yourself comes later.

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

**Stats:** while we're testing, a debug stats panel shows tonight's numbers (F3 hides it), and each night writes a stats log (JSON) to `stats/` in the same user data folder, to compare runs.

**Transcripts:** each night's transcript is written, as it goes, to `logs/transcripts/` in the project folder when you play from the Godot editor (kept out of git by `.gitignore`), so you can read or share how a night went.

**Choosing the AI:** each machine has an `ai_settings.cfg` (in Godot, **Project → Open User Data Folder**) with `backend` set to `auto` (Ollama, falling back to offline mode), `ollama` or `canned` (offline mode: pre-written characters, no AI), plus the Ollama `server` and `model`. See [TOOLCHAIN.md](TOOLCHAIN.md#5b-ai-settings-choosing-which-ai-the-game-uses).

**No suitable GPU?** Use offline mode, a small model on the CPU, or another machine's Ollama. See [TOOLCHAIN.md](TOOLCHAIN.md#5a-machines-without-a-suitable-gpu).

**Tests:** open the **GdUnit** panel in Godot and click **Run All**, or run them headless with gdUnit's command-line runner so nothing takes the mouse (they don't need Ollama). See [TESTS.md](TESTS.md).

## Project layout

| Path | What it is |
|---|---|
| `project.godot` | Godot project settings (main scene: `scenes/title.tscn`; autoload: `Game`) |
| `scenes/title.tscn` | The title screen: New bar, or open a saved one |
| `scenes/visit.tscn` | The bar itself: owner, customers, orders and conversation (its UI, the tent and the people are drawn in code) |
| `scenes/pipeline_test.tscn` | The pipeline test, kept as a quick AI check (open it and press F6) |
| `scripts/ollama_client.gd` | Talks to Ollama's local HTTP API |
| `scripts/ai.gd` | Asks the AI for JSON, validates the reply, and retries with feedback if it's wrong; picks Ollama or offline mode |
| `scripts/ai_settings.gd` | Reads each machine's `ai_settings.cfg` (backend, server, model) |
| `scripts/canned_ai.gd` | Offline mode: pre-written owners, customers, orders and lines, built to pass the game's rules; also the tests' fake AI |
| `scripts/prompts.gd` | The K-drama style guide and every prompt sent to the AI |
| `scripts/loading_screen.gd` | The loading screen shown while a new bar is set up |
| `scripts/regulars.gd` | Regulars: who comes back, how often, how they fade, and a simulation of months of nights |
| `scripts/night_events.gd` | The night's events, announced once each, for the stats, captions and diary |
| `scripts/ktv_style.gd` | The game's look in one place: the K-TV palette, labels, pills and title-card text |
| `scripts/caption.gd` | A Korean TV caption: Hangul over a coloured English tag, popping in and fading |
| `scripts/caption_reel.gd` | Captions popping up by themselves, for the title and loading screens |
| `scripts/bubble.gd` | A speech bubble: over the speaker, who it's to, a line to the listener, and long lines a page at a time |
| `scripts/ambience.gd` | The tent's background sound: loops and one-off sounds made in code, following the scene |
| `scripts/music.gd` | The background music: Arirang, arranged in code, from the title screen on |
| `scripts/menu.gd` | The menu, prices and each dish's Hangul (the game's facts) |
| `scripts/rules/` | The game's rules, one file per area (see [ARCHITECTURE.md](ARCHITECTURE.md)): pure functions and their tables, no scene or AI, so easy to test |
| `scripts/game.gd` | The `Game` autoload: which bar is open, opening and closing bars, saving on close, and the music (which carries on between scenes) |
| `scripts/diary_page.gd` | A page of the owner's diary: the episode, the day, the entry and a stamp |
| `scripts/diary_book.gd` | The owner's diary as a book: a page at a time, older and newer |
| `scripts/recap_screen.gd` | "Previously on…": the K-drama recap, in one of four K-TV styles |
| `scripts/save_store.gd` | Reads, writes and deletes each bar's save file, safely |
| `scripts/night_stats.gd` | The debug stats for a night: the stats panel and the nightly stats log |
| `scripts/title.gd` | Title screen logic (and its Music slider) |
| `scripts/visit.gd` | The bar's logic: new or saved bar, the night and its clock, five stools, the stove's queue, what the owner does next, arrivals, orders, conversations and customer chats, stays, bills, the night summary, debug stats, autosave; and drawing it all: the tent and its look, the light and weather, passers-by, the cat, and everyone in their look |
| `scripts/pipeline_test.gd` | Pipeline test logic |
| `logs/` | Night transcripts, written when playing from the editor (not committed) |
| `scripts/test_hooks.gd` | Every test hook in one place (the game only reads them) |
| `.github/workflows/tests.yml` | Runs all the tests on GitHub on every push |
| `tests/` | GdUnit4 tests (with a shared base in `tests/support/`): rules, menu, prompts, offline mode, saves, stats, and click-through visits, bars and nights (see [TESTS.md](TESTS.md)) |
| `addons/gdUnit4/` | The GdUnit4 test framework (v6.2.0) |

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
