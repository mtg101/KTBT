# KTBT: Start here

The short version, for a new chat (Claude) picking the project up. Read this and PLAN.md's **Next stages**; open anything else only for the part you're touching. It's kept short on purpose: add a gotcha when one bites, and nothing else.

## What it is

A Korean tent bar (pojangmacha) at night, as a reality show: the night runs itself (Godot 4.7.2, GDScript; customers, owner and talk from a local LLM through Ollama, or the canned AI offline), and the player is the show's PD (camera, plant cards, write-ins, pins, the edit). Pixel art drawn in code (`tools/art/*.py`) or from an image model, lit by a shader. See CONCEPT.md only if you need the design.

## Where things are

- `scripts/visit.gd`: the tent scene, ~6,000 lines. **Never read it whole**: grep its `# ---` section headers (The owner, The night, The edit, Let the crew run it, Tasks, Customers chatting, The cat, The PD's camera, The PD's plant cards, Building the screen, Regulars…) and read the section.
- `scripts/rules/`: pure rules and checks, no scene (talk, captions, cat_rules, hangul meanings, glossary, menu, ratings, ladder…). `scripts/ai/`: the AI (prompts, `canned_ai.gd`). `scripts/bar/`: parts of the tent (camera, pd_desk, night_stats, night_events, kitchen, street…). `scripts/ui/`: drawn things (people_art, pixel_light, transcript_view, crew_controls…). `scripts/save/`, `scripts/sound/`.
- `scripts/game.gd`: the autoload (`Game`): the open bar, saves, autoplay. `scripts/autoplay.gd`: batches and the crew. `scripts/debug_log.gd`: notes. `scripts/test_hooks.gd`: every test switch (`Hooks.*`).
- `tests/`: GdUnit4; scene tests extend `tests/support/bar_test.gd`. `tools/art/`: the art in Python (`people.py`, `tent.py`, `cat.py`, `light_preview.py` to look without Godot).
- The full map of files is ARCHITECTURE.md's "The files, by job": look up the one row you need.

## Gotchas (each cost a crash or a round trip)

- **Warnings are errors** (project.godot): a local or parameter that shadows a member, a base class's method or a global (`log`, `crew`, GdUnit's `before`/`after`, `owner`), an unused variable or parameter (prefix `_`), and a `const X = preload(...)` named like a global `class_name` (`Ambience`, `Music`, `Bubble`, `Caption`, `LoadingScreen`: use them directly).
- **A new night event kind** goes in `scripts/bar/night_events.gd` KINDS, or `_event()` asserts and the game stops.
- **Notes:** `DebugLog.say("Kind", "...")`, never `print` (console kinds: `debug_log.gd` CONSOLE).
- **Hovers** go through `Text.tip`; **Hangul on screen** needs its meaning in `rules/hangul.gd` MEANINGS (or the glossary).
- **Clicks:** stage containers that only hold things (rows, layers) are `MOUSE_FILTER_IGNORE`, or they swallow clicks on whoever's behind them.
- **Tests:** a test file's count and the total are checked against TESTS.md and the README (`test_code.gd`); every script must appear in ARCHITECTURE.md or the README, every test file in TESTS.md. TESTS.md's line must read "All N tests pass".
- **Timing in scene tests:** the night carries on while a test awaits; don't assert on which exact line got something.
- **Freeing a child you'll look for again this frame:** `remove_child` before `queue_free`.
- **The helper (`tools/autoplay_mcp.ps1`) can't be tested here** (no PowerShell in the VM), and one parse error takes all its tools down until the desktop app restarts. In a string, `$name:` reads as a drive (`$env:`-style): write `$($name):`. `ConvertFrom-Json` in Windows PowerShell 5.1 hands a JSON list back as one item (and `@(...)` round it doesn't help): store it, then `@($parsed | ForEach-Object { $_ })`.
- **Claude can't run Godot** (the shell on the PC is a Linux VM): the user runs the tests (VS Code, or GitHub CI). Godot's log is in the user folder (`…/Godot/app_userdata/KTBT/logs/godot.log`), test results in `reports/report_N/results.xml`, each night's notes in `logs/debug/`, transcripts in `logs/transcripts/`.

## How to work

- **Definition of done** (ARCHITECTURE.md has it in full): tests; counted in `night_stats.gd` (in its section); logged; docs (DEVLOG entry with the test count; PLAN.md only ever what's left; TESTS.md; ARCHITECTURE/README if a file or feature is new); Korean explained on hover; nothing private or branded.
- **A quick fix** ("quick fix" in the ask): the fix, a regression test if it can break again, a line in DEVLOG. No docs sweep.
- **Read little:** grep first, read the lines around the hit. DEVLOG is long: search it, never read it whole.
- **Art changes:** edit `tools/art/*.py`, run it (it writes `art/`, the manifest and LICENSE-ASSETS), check with `tools/art/light_preview.py`; the user imports in Godot.
- **Commits:** the user commits from VS Code. When asked, update the docs and suggest a commit message (no private details; AI co-author line is fine).
