# KTBT: Korean Tent Bar Tropes

A cosy simulation of a Korean pojangmacha (street tent bar), where every owner and customer is invented by an AI. Think *Coffee Talk*, but with soju, tteokbokki and a heavy dose of K-drama tropes.

Night after night, the bar fills with characters who fit the hour: salarymen fleeing a company dinner, nurses off a night shift, a newly dumped office worker drinking alone, maybe a chaebol heir in disguise. They order from the menu, eat, drink and pour their hearts out to the owner, an AI-invented ajumma or ajusshi who has seen it all.

## Status

✅ **Latest: one visit.** The AI invents the tent's owner; press **Next customer** and one AI-invented customer arrives, orders from the menu, is served, chats with the owner, pays and leaves. Grey-box art. Customers order like at a real pojangmacha: a drink and a food, free banchan, and sometimes one more bottle later. Automated tests (106 so far) cover the game's rules and prompts. Next up: click-through tests and an offline mode. See [PLAN.md](PLAN.md) for what's next and [DEVLOG.md](DEVLOG.md) for what's been done.

Version one is a **simulation**: you watch the bar run itself. Talking to customers yourself comes later.

## Documents

| File | What's in it |
|---|---|
| [CONCEPT.md](CONCEPT.md) | The game concept, characters, K-drama style guide, saving/loading, menu, tech |
| [PLAN.md](PLAN.md) | What we're building next: upcoming stages and later ideas |
| [DEVLOG.md](DEVLOG.md) | A dated record of what's been done and why |
| [LLM-TUNING.md](LLM-TUNING.md) | LLM tuning notes: quirks in the local model's output and how we handle them |
| [TOOLCHAIN.md](TOOLCHAIN.md) | Setting up Godot, Ollama and the local model on Windows, with troubleshooting, and installing the test framework |
| [TESTS.md](TESTS.md) | How KTBT is tested: what's automated, what's playtested, conventions and coverage |

## Tech

- **Engine:** [Godot 4](https://godotengine.org) (GDScript)
- **AI characters:** a local LLM (Llama 3.1 8B to start) served by [Ollama](https://ollama.com), called from Godot over HTTP
- **Target platform:** Windows PC, with an NVIDIA GPU of roughly 10GB+ VRAM for the local model (or offline mode without one, from the Tests stage)

## Running it

1. Set up the toolchain using [TOOLCHAIN.md](TOOLCHAIN.md).
2. Make sure Ollama is running and the model is pulled.
3. Open Godot, **Import** `project.godot` from this folder, and press **Play** (F5).

**No suitable GPU?** From the Tests stage, the game has an offline mode with canned characters, and it can also use a small model on the CPU or another machine's Ollama. See [TOOLCHAIN.md](TOOLCHAIN.md#5a-machines-without-a-suitable-gpu).

**Tests** (from the Tests stage): open the **GdUnit** panel in Godot and click **Run All**. See [TESTS.md](TESTS.md).

## Project layout

| Path | What it is |
|---|---|
| `project.godot` | Godot project settings (main scene: `scenes/visit.tscn`) |
| `scenes/visit.tscn` | The one-visit scene (its UI and grey-box tent are built in code) |
| `scenes/pipeline_test.tscn` | The pipeline test, kept as a quick AI check (open it and press F6) |
| `scripts/ollama_client.gd` | Talks to Ollama's local HTTP API |
| `scripts/ai.gd` | Asks the AI for JSON, validates the reply, and retries with feedback if it's wrong |
| `scripts/prompts.gd` | The K-drama style guide and every prompt sent to the AI |
| `scripts/menu.gd` | The menu and prices (the game's facts) |
| `scripts/rules.gd` | The game's rules: checks on every AI reply, bills, text tidying (no scene or AI, so easy to test) |
| `scripts/visit.gd` | One-visit logic: owner, arrival, order, serving, conversation, bill |
| `scripts/pipeline_test.gd` | Pipeline test logic |
| `tests/` | GdUnit4 tests (see [TESTS.md](TESTS.md)) |
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

- invent each bar's owner and name when a new bar is started
- invent customers suited to the time of night, day and weather
- choose each customer's order from the bar's current menu
- write the conversation between each customer and the owner

Design guard-rails:

- **The game owns the facts; the AI owns the flavour.** Time, menu, prices and seating are controlled by game code. The AI's structured output (JSON) is checked, and anything invalid, such as an order for a dish that isn't on the menu, is rejected and retried.
- **Everything runs locally.** No cloud AI service is called, no API key is needed, and nothing you see in the game leaves your machine.
- **Generated content is unscripted.** Characters and dialogue are created fresh each time and aren't reviewed by a human, so expect occasional oddities. A shared style guide in every prompt keeps the tone warm, melodramatic and K-drama flavoured.

## Assets and credits

No third-party assets yet. Any art, sound or music added later will be listed with its source and licence in `CREDITS.md`.

## Licence

KTBT is free and open source, under share-alike licences:

- **Code** (GDScript, scenes, project files): [GNU General Public License v3.0](LICENSE). You can use, modify and share it, including commercially, but any distributed version must also be released under the GPL with its source.
- **Docs and original creative assets** (documentation, art, audio, writing, prompts): [CC BY-SA 4.0](LICENSE-ASSETS.md).
- **Third-party assets** keep their own licences, listed in `CREDITS.md`.
- **Godot Engine** is MIT-licensed. See https://godotengine.org/license.
