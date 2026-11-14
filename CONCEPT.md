# KTBT: Korean Tent Bar Tropes

*A pojangmacha simulation with AI-generated K-drama characters.*

## The idea

A cosy, Coffee Talk-style scene set in a pojangmacha under a Seoul overpass. Over the course of a night, AI-invented customers turn up, order soju and street food, and chat with the tent's owner. Each customer is generated to fit the time of night, so the after-work crowd gives way to night-shift workers and heartbroken stragglers as the hours pass.

**A night** runs from 6pm to 3am on a clock that always runs: at most about five minutes of real time, since time runs faster while the tent's quiet (6× when it's empty, 2× with one customer, normal from two). About twenty customers arrive, at times that suit the hour: a trickle after work, a rush from 9pm to 1am, and nobody new after 2:30am. At 3am the owner calls last orders; once the last customer has gone, a summary shows the night's customers, takings and most memorable line, and the bar is ready for another night. Each bar goes round the week, night by night.

**The tent** has five stools and one owner, who is also the only cook. Drinks and banchan come straight away; cooked dishes queue at the stove, the AI is told what's still cooking, and the owner carries each dish over as soon as it's ready. The owner talks to one customer at a time and moves round: greeting newcomers first (quickly when it's busy), then settling up with whoever's leaving, otherwise chatting with whoever's been left alone longest. Now and then, customers chat to each other instead, and sometimes the owner or another customer joins in. When every stool is taken, newcomers wait a while, then walk on.

**Version one is a simulation, not a game.** The player just watches. Orders are served automatically. Talking to customers yourself (the "game" part) comes later.

## Core design rule

**The game owns the facts; the AI owns the flavour.**

- The game decides the time, weather, menu, prices, seats and when people arrive and leave.
- The AI invents people and dialogue *within* those limits.
- Anything the AI returns that the game depends on (customer profiles, orders) comes back as JSON and is checked by the game. An order for something not on the menu is rejected and retried.

## Characters

### The owner
- Invented by the AI **once per bar (save)** and then kept. They're the constant heart of the tent.
- Every customer talks to the owner, and sometimes customers talk to each other too.
- Later, the player can step into the owner's role.

### Customers
- Generated per visit, shaped by the time of night, the day and the weather, in two steps: first a name and gender (so a name that's already at the counter can be swapped quickly), then the rest.
- Profile (JSON): name, gender, age, job, mood, why they're here tonight, how they talk.
- **Gender:** decided by the game: half women, half men, and about one in a hundred non-binary (they/them). The AI names them. Shown on screen as ♀ ♂ ⚲ next to names, since Korean names don't make it obvious.
- **Game facts about each customer:** how long they'll stay (30–60 game minutes, longer for someone here to talk), their mood for company (chatty, keeps to themselves, or here to talk to the owner), whether they're hungry or having a rough night, and whether they'll order more later.
- Visits: arrive, order from the menu, eat and drink, talk with the owner (and maybe other customers), then say goodbye, pay and leave when their time's up.
- **Nobody knows more than they should:** the AI is told what everyone can see (how someone looks) and that nobody knows another's name, age, job, reason for coming or secret until it's been said. Everyone speaks fluent, natural English (they're speaking Korean), with the odd Korean word a K-drama fan would know.
- **What conversations turn to:** the game picks a topic for each spell of chat (their day, what's on their mind, a story from the owner's past, the weather, the cat, food…), so talk doesn't get stuck on one thing.
- **Strangers talk politely:** nobody at the counter knows anyone yet, so terms like oppa, hyung, nuna and eonni (for people who are close) are ruled out, and no two people there share a name.
- **Later:** regulars who return and remember previous visits, via a short stored summary of each.

### The cat
- Every bar has a cat, saved with it: the game picks its coat, personality (lazy, affectionate, greedy, grumpy or curious) and sex (she or he), and the AI names it (no two bars' cats share a name).
- The game decides where it is all night (asleep by the stove, on someone's lap, out in the street…), by its personality, and everyone talks about it as it really is: nobody strokes it unless it's on their lap.

## Saving and loading

Each **save is one bar**: its owner, its regulars, its history. You can have several and come back to any of them.

- **Title screen:** *New bar* or a list of saved bars (bar name, owner, nights and visits, takings and last played), each of which can be opened or deleted (two clicks, so a stray one can't lose a bar).
- **New bar:** the AI invents the owner and the bar's name (a Korean name, checked by the game like everything else the AI writes), and a new save is created straight away.
- **Autosave, always.** The game saves as it goes, with no save button and no "your progress will be lost" prompt. Close the window at any time, and next time you load, it carries on with the next customer.
- **When it saves:** when a bar is created, after every visit, at the end of each night, when you close the bar, and when the window is closed.
- **What's saved:** the bar's name and its meaning, the owner, the cat, the takings, the visit and night counts, a short history of recent visits (who came, what they ordered, the bill), a log of recent nights (day, weather, customers, takings, memorable line), the day of the week it started on, and later the menu and (from the Regulars and relationships stage) regulars and their memory summaries.
- **Quitting mid-night:** for now, a night you leave before 3am isn't counted, and opening the bar again starts that night afresh at 6pm; resuming mid-night is a later idea. An unfinished visit simply ends when you quit. Resuming mid-conversation (the customer still on their stool, the chat picking up from the saved transcript) is a later idea in [PLAN.md](PLAN.md).
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
