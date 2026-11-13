# KTBT: Korean Tent Bar Tropes

*A pojangmacha simulation with AI-generated K-drama characters.*

## The idea

A cosy, Coffee Talk-style scene set in a pojangmacha under a Seoul overpass. Over the course of a night, AI-invented customers turn up, order soju and street food, and chat with the tent's owner. Each customer is generated to fit the time of night, so the after-work crowd gives way to night-shift workers and heartbroken stragglers as the hours pass.

**Version one is a simulation, not a game.** The player just watches. Orders are served automatically. Talking to customers yourself (the "game" part) comes later.

## Core design rule

**The game owns the facts; the AI owns the flavour.**

- The game decides the time, weather, menu, prices, seats and when people arrive and leave.
- The AI invents people and dialogue *within* those limits.
- Anything the AI returns that the game depends on (customer profiles, orders) comes back as JSON and is checked by the game. An order for something not on the menu is rejected and retried.

## Characters

### The owner
- Invented by the AI **once per bar (save)** and then kept. They're the constant heart of the tent.
- Every customer talks to the owner (not to each other, for now).
- Later, the player can step into the owner's role.

### Customers
- Generated per visit, shaped by the time of night, the day and the weather.
- Profile (JSON): name, age, job, mood, why they're here tonight, how they talk.
- Visits are short: arrive, order from the menu, eat and drink, around 6–10 exchanges with the owner, pay, leave.
- **Later:** regulars who return and remember previous visits, via a short stored summary of each.

## Saving and loading

Each **save is one bar**: its owner, its regulars, its history. You can have several and come back to any of them.

- **Title screen:** *New bar* or *Load bar* (a list of saves showing bar name, owner, nights run and last played).
- **New bar:** the AI invents the owner (and the bar's name), and a new save is created straight away.
- **Autosave, always.** The game saves as it goes, with no save button and no "your progress will be lost" prompt. Close the window at any time, and next time you load, it carries on from where you left off.
- **When it saves:** at natural moments (a customer arrives, orders, says a line, leaves, or the clock ticks over an hour) and again when the window is closed.
- **What's saved:** the owner, the clock (night number and time), the weather, the menu, who's seated and their conversation so far, and (from the Regulars and relationships stage) regulars and their memory summaries.
- **Resuming mid-conversation:** a customer who was seated when you quit is still there on load, and their chat continues from the saved transcript. If the AI was halfway through a reply, that one line is simply asked for again.
- **Safe writes:** each save is written to a temporary file and then swapped in, so a crash mid-save can't corrupt the bar.
- **Format:** one JSON file per bar in Godot's `user://saves/` folder (on Windows: `%APPDATA%\Godot\app_userdata\KTBT\saves\`). It's human-readable, which is handy for debugging, or for peeking at what the AI invented.

## K-drama style guide

Included in every AI prompt so all characters feel like they belong to the same show. The AI riffs on these rather than copying them.

**Setting:** orange-tarp tent, plastic stools, green soju bottles, steam off the tteokbokki, a single bulb swinging, rain more often than not.

**Owner archetypes:**
- The gruff-but-soft ajumma who scolds customers for not eating properly
- The quiet ajusshi with a mysterious past who gives one line of perfect advice
- The ex-something (gangster, chef, idol trainee) who left it all behind

**Customer archetypes:**
- Salarymen escaping a hoesik (company dinner)
- A newly dumped office worker drinking alone
- Exhausted nurses after a night shift
- A chaebol heir in disguise
- Students celebrating the end of exams
- A taxi driver on his break
- Old friends reuniting after years apart
- Someone working up the courage to confess their feelings

**Tone:** warm, melodramatic, a little melancholy. "One more bottle", unspoken feelings, late-night honesty, with humour mixed in.

## Menu and ordering

The current menu is a fixed placeholder (see bar-specific menus in [PLAN.md](PLAN.md) for where it's heading). Prices live in `scripts/menu.gd`.

- **Drinks:** soju, makgeolli, beer, somaek (soju dropped in beer)
- **Mains:** tteokbokki, sundae, dakgalbi, pajeon, ramyeon
- **Sides:** odeng (fish cake skewers), gyeran-mari, gonggibap (a bowl of rice), bokkeumbap (fried rice made in the leftover sauce; only ordered later, after a main)
- **Free banchan** (kimchi and pickled radish) comes with every order and isn't on the bill.

**How people order** (game rules, checked on every AI order):

- **First order:** at least one drink and one food, because nobody drinks on an empty stomach. Usually one main and one drink, maybe a side. The game decides who's **hungry** (may order two mains) or having a **rough night** (may order two drinks).
- **Later orders:** half of customers order once; the rest order more partway through the conversation (one more bottle, a side, rice), and a few order a third time. Never a new main, at most one more drink each time, and it has to sound like ordering more.

## Tech

| Piece | Choice |
|---|---|
| Engine | Godot 4, GDScript |
| AI | Local model via Ollama (RTX 3080, so 7–9B models; try Llama 3.1 8B, Gemma and Qwen to compare). Per-machine AI settings choose Ollama or an offline mode with pre-written characters |
| Connection | Godot `HTTPRequest` to Ollama's local API, JSON output mode for structured replies |
| Art | Placeholder shapes first, then a consistent CC0 pack (e.g. Kenney) |
| Assets log | `CREDITS.md`, recording the source and licence of every asset |

Show a "typing…" indicator while the AI replies.

## Plan

What we're building next is in [PLAN.md](PLAN.md), what's been done so far is in [DEVLOG.md](DEVLOG.md), and AI quirks are in [LLM-TUNING.md](LLM-TUNING.md).
