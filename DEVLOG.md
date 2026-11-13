# KTBT: Devlog

A running record of what we've done on KTBT and why, newest first. What's coming next is in [PLAN.md](PLAN.md), and AI quirks are in [LLM-TUNING.md](LLM-TUNING.md).

## 13 November 2026

- **Tuning notes renamed:** `TUNING.md` is now `LLM-TUNING.md` (title "LLM Tuning notes"), to make clear it's about tuning the local LLM's output. Links and test comments updated.
- **Ordering like a real pojangmacha:** a run of playtesting fixes, each with regression tests (details in [LLM-TUNING.md](LLM-TUNING.md)):
  - **Food stays on the table:** the style guide no longer names any dish, and conversation lines that mention food that isn't on the table are rejected.
  - **Sensible orders:** a drink and a food every time, usually one main and one drink, with the game deciding who's hungry (two mains) or having a rough night (two drinks). Menu foods are now marked main or side, and free banchan comes with every order.
  - **Later orders:** half of customers order once, 40% order more partway through, 10% a third time: one more bottle, a side, or rice. New menu items: gonggibap (rice) and bokkeumbap (fried rice, only after a main). Later orders sound like ordering more, never come straight after the food, and add to the conversation rather than replacing it.
  - **Fast mode on by default** while we're testing a lot.
  - **Tests:** 106 in total, all passing.
- **Conversations that listen (a bit) better:** a visit produced a conversation where the owner and customer ignored each other (she ordered tteokbokki; he asked if she'd eat). Two quick prompt fixes: the serving now appears in the transcript the AI reads, and every dialogue prompt ends with a "what just happened" recap. Noticeably better, still needs work later; details in [LLM-TUNING.md](LLM-TUNING.md). 3 new regression tests, 64 in total, all passing.
- **First tests pass:** moved the game's rules (every check on the AI's replies, plus the bill, order names and text tidying) out of `visit.gd` into a new `scripts/rules.gd`, so they can be tested without a scene or the AI. Wrote 61 GdUnit4 tests in `tests/`: menu (12), rules (40) and prompts (9), including regression tests for each fixed issue in [LLM-TUNING.md](LLM-TUNING.md). All 61 pass first time, which also confirms GdUnit4 v6.2.0 works with Godot 4.7.2.
- **GdUnit4 installed:** the project has moved to `godot-gdunit-labs/gdUnit4` on GitHub, where the latest release is v6.2.2 (7 October 2026), officially supporting Godot up to 4.7.1. Godot 4.7 has replaced the old AssetLib tab with the new Godot Asset Store, which only had v6.2.0, so we installed that (same v6.2 line) and enabled the plugin. The GdUnit tab appears in the editor. Install steps and version table updated in `TOOLCHAIN.md`.
- **Future ideas mapped out:** added to [PLAN.md](PLAN.md)'s later ideas, grouped as essentials, richer play, presentation and lower priority. New: bar-specific menus (catalogue staples plus AI signature dishes), character art (silhouettes, then modular portraits; live AI portraits noted as theoretically possible), ambience, voices (babble, system voices or AI voices), content boundaries as a setting, prepare-ahead AI calls, settings and accessibility, packaging and first-run setup, a calendar with Korean holidays, drama arcs, a journal and trope book, and more.
- **Docs restructured:** the plan no longer numbers its stages (we'd already had to slot in a "stage 2.5"), and only lists what's still to do. Finished work now lives in this devlog, and tuning notes moved to their own file (now [LLM-TUNING.md](LLM-TUNING.md)).
- **No-GPU plan:** started working on a laptop without an NVIDIA GPU, so the local LLM can't run well there. Planned AI settings (backend, server address, model) and an offline **canned AI** mode as part of the Tests stage, and documented three ways to work without a suitable GPU in [TOOLCHAIN.md](TOOLCHAIN.md#5a-machines-without-a-suitable-gpu): canned AI, a small model on the CPU, or the desktop's Ollama over the home network.
- **Laptop setup:** cloned the repo to the laptop. Claude's shell isn't available there (the desktop app doesn't offer it on that machine, though virtualization, memory and disk all check out), so on the laptop Claude edits files by copying them back and forth, and the developer runs Godot, tests and git.
- **Testing planned:** chose **GdUnit4** over GUT, for click-through UI tests, built-in mocks, and VS Code and GitHub integration. Wrote [TESTS.md](TESTS.md) and a GdUnit4 section in `TOOLCHAIN.md`. Note: GdUnit4 v6.2.x lists support up to Godot 4.7.1, and we're on 4.7.2, so we'll confirm it works when installing.

## 12 November 2026

- **Concept and setup:** settled on Godot 4 (free, open source, scripts that Claude can write as plain text) and a local LLM via Ollama, to keep the game free to run. Wrote [CONCEPT.md](CONCEPT.md) and [TOOLCHAIN.md](TOOLCHAIN.md). Toolchain verified on the desktop: Godot 4.7.2, Ollama with `llama3.1:8b`, RTX 3080 12GB. The only surprise was a slow first reply, which turned out to be the model loading into GPU memory.
- **Licence:** GPL-3.0 for code, CC BY-SA 4.0 for docs and original creative assets (including the prompt text).
- **Pipeline test stage done:** press a button, and the local LLM invents a customer whose profile appears on screen. Godot, Ollama and the model talked to each other first time.
- **One visit stage done:** the AI invents an owner, then one customer at a time arrives, orders from the menu, is served automatically, chats with the owner, pays and leaves, all in grey-box art. The owner was pulled forward from the Bars and saves stage so customers have someone to talk to; it isn't saved yet. The game checks every AI reply and retries with feedback when it's wrong.
- **Tuning fixes:** fixed customers ordering twice with mismatched orders, and owners with wrong or speaker-dependent titles; added an interim fix for strangers acting like regulars. Details in [LLM-TUNING.md](LLM-TUNING.md).
- **Small touches:** customers now arrive from, and leave towards, a random side of the street.
- **Docs:** split the concept from the plan, and standardised list formatting.
