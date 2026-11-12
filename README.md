# KTBT: Korean Tent Bar Tropes

A cosy simulation of a Korean pojangmacha (street tent bar), where every owner and customer is invented by an AI. Think *Coffee Talk*, but with soju, tteokbokki and a heavy dose of K-drama tropes.

Night after night, the bar fills with characters who fit the hour: salarymen fleeing a company dinner, nurses off a night shift, a newly dumped office worker drinking alone, maybe a chaebol heir in disguise. They order from the menu, eat, drink and pour their hearts out to the owner, an AI-invented ajumma or ajusshi who has seen it all.

## Status

🚧 **Pre-code.** Concept and toolchain are documented, and stage 1 (the AI pipeline test) is next.

Version one is a **simulation**: you watch the bar run itself. Talking to customers yourself comes later.

## Documents

| File | What's in it |
|---|---|
| [CONCEPT.md](CONCEPT.md) | The game concept, characters, K-drama style guide, saving/loading, build stages |
| [TOOLCHAIN.md](TOOLCHAIN.md) | Setting up Godot, Ollama and the local model on Windows, with troubleshooting |

## Tech

- **Engine:** [Godot 4](https://godotengine.org) (GDScript)
- **AI characters:** a local LLM (Llama 3.1 8B to start) served by [Ollama](https://ollama.com), called from Godot over HTTP
- **Target platform:** Windows PC, with an NVIDIA GPU of roughly 10GB+ VRAM for the local model

## Running it

Not playable yet. Once stage 1 exists:

1. Set up the toolchain using [TOOLCHAIN.md](TOOLCHAIN.md).
2. Make sure Ollama is running and the model is pulled.
3. Open Godot, **Import** `project.godot` from this folder, and press **Play**.

## AI usage

AI is used in two quite different ways in this project.

### 1. Building it: vibe coded with Claude
This project is an experiment in **vibe coding**. The code and documentation are written by [Claude](https://claude.ai) (Anthropic's AI assistant), working from the developer's direction.

- **The developer** owns the idea, makes the design decisions, runs and playtests each build, and reports what's broken or what feels wrong.
- **Claude** writes the GDScript, scenes and docs, and fixes issues based on that feedback.
- Work proceeds in small, playable stages (see [CONCEPT.md](CONCEPT.md)) so every change is tested by a human before moving on.

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
