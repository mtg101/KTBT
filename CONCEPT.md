# KTBT: Korean Tent Bar Tropes

*A pojangmacha simulation with AI-generated K-drama characters.*

## The idea

A cosy, Coffee Talk-style scene set in a pojangmacha under a Seoul overpass. Over the course of a night, AI-invented customers turn up, order soju and street food, and chat with the tent's owner. Each customer is generated to fit the time of night, so the after-work crowd gives way to night-shift workers and heartbroken stragglers as the hours pass.

**A night** runs from 6pm to 3am on a clock that always runs: at most about five minutes of real time, since time runs faster while the tent's quiet (6× when it's empty, 2× with one customer, normal from two). About twenty customers arrive, at times that suit the hour: a trickle after work, a rush from 9pm to 1am, and nobody new after 2:30am. At 3am the owner calls last orders; once the last customer has gone, a summary shows the night's customers, takings and most memorable line, and the bar is ready for another night. Each bar goes round the week, night by night.

**The tent** has five stools and one owner, who is also the only cook. Drinks and banchan come straight away; cooked dishes queue at the stove, the AI is told what's still cooking, and the owner carries each dish over as soon as it's ready. The owner talks to one customer at a time and moves round: greeting newcomers first (quickly when it's busy), then settling up with whoever's leaving, otherwise chatting with whoever's been left alone longest. Now and then, customers chat to each other instead, and sometimes the owner or another customer joins in. When every stool is taken, newcomers wait a while, then walk on.

**The player is the show's PD.** The night is an episode of a show, and it runs itself: orders are served, people talk, the owner works. The player is its PD (producer-director), and nothing they do pauses it: they choose whose story the camera follows (that person gets the airtime), and play a few **plant cards** a night (a regular rung and asked to come down, a sudden downpour, a phone ringing at the counter, a word from the show's sponsor), things that happen, which the people they happen to take up or don't. When a moment gets a TV caption, the PD has two seconds to pick its spin: the AI's own, the opposite, or a cheeky roast in the editors' voice. One card a night is a **write-in**: the PD types it (a cue card held up behind the camera, an interview question, a text someone gets), and the AI answers the player's own words, framed as what happened in the scene, never as instructions, and checked like any line. Doing nothing is always fine. Everyone at the counter knows they're on a show. Typing to the customers directly comes later.

### The PD's cards

- **A pack of tropey cards, five dealt a night** from their own dice (so dealing never shifts anything else's rolls): three events, one **write-in** and a word from our sponsor (PPL, with the show's own made-up sponsors). Not last night's cards again, and not one that can't happen tonight (no first snow in summer); one that can't happen *yet* stays in the hand, greyed out with why.
- **Two kinds:** a **situation** (something that happens, told to whoever it happens to, as what just happened and as a moment for their next line) is a data entry and the words that show it was taken up, no code; a **fact** (it changes something the game owns: the weather, an arrival, a round on someone's bill, the lights) is a data entry and a small handler. A write-in is a situation with a blank the PD fills. Many cards have variants (who's calling, how the two know each other, which song), picked as they're dealt.
- **Aimed with the camera:** a card that happens to someone happens to whoever the camera's on (with nobody followed, the game picks someone, and the card's hover says who). The tent's cards (the rain, the song) are for everyone.
- **Write-ins, the PD's own words:** a one-line box on the desk, never a pop-up, while the night carries on. What's typed is framed as what happened in the scene, never as instructions, and every reply still goes through every check, so typed words can't change a game fact. What's typed is checked too (length, hard limits, no teasing about looks), and any Korean in it is explained for the AI. Offline, write-ins are greyed out (the canned lines can't answer free text).
- **Counted:** each card played, whether the lines given it took it up, and whether it came up in anyone's lines while it mattered (for a card aimed at someone, as long as they're here).

## Core design rule

**The game owns the facts; the AI owns the flavour.**

- The game decides the time, weather, menu, prices, seats, when people arrive and leave, and how everyone looks (gender, age range, hair, clothes).
- The AI invents people and dialogue *within* those limits.
- Anything the AI returns that the game depends on (customer profiles, orders) comes back as JSON and is checked by the game. An order for something not on the menu is rejected and retried.

## Characters

### The owner
- Invented by the AI **once per bar (save)** and then kept. They're the constant heart of the tent.
- **How they look:** the game decides (their age range, hair, clothes and colours, always with an apron), and the AI invents someone who'd look like that.
- **Their diary:** every night is an episode, and at 3am the owner writes it up in their diary, in their own voice, from the facts the game picked (the big moments, who came, the regulars, the takings). The diaries pile up into the bar's story, a book you can flip back through from the bar or the title screen. Opening a bar plays "Previously on…": a K-drama recap of last time, done over the top in a different K-TV style each time (melodrama, makjang, variety show, nostalgic).
- **Their life is fixed:** a secret they only hint at, their family ("widowed young; a grown daughter in Daejeon") and what they did before the tent. The AI writes these once, the game keeps them, and every conversation has to fit them, so the owner's story never changes.
- Every customer talks to the owner, and sometimes customers talk to each other too.
- The player makes the show (see above); typing to the customers comes later.

### Customers
- Generated per visit, shaped by the time of night, the day and the weather, in two steps: first a name and gender (so a name that's already at the counter can be swapped quickly), then the rest.
- Profile (JSON): name, gender, age, job, mood, why they're here tonight, how they talk, and their look.
- **How they look:** decided by the game, like gender: an age range, hair (by gender and age), clothes (by the weather), colours (mostly beige and black, as in Seoul), and sometimes glasses or a bag. The AI invents someone who'd look like that, and the game draws them: facing us as they come and go, and from behind once they're sat at the counter.
- **Names in Hangul:** every name (customers, the owner, the cat) is shown in Hangul too, before the romanised one, like the sign, so the player gets used to seeing Korean names. The AI writes it; the game checks it fits and leaves it off rather than show it wrong.
- **Gender:** decided by the game: half women, half men, and about one in a hundred non-binary (they/them). The AI names them. Shown on screen as ♀ ♂ ⚲ next to names, since Korean names don't make it obvious.
- **Game facts about each customer:** how long they'll stay (30–60 game minutes, longer for someone here to talk), their mood for company (chatty, keeps to themselves, or here to talk to the owner: someone keeping to themselves never starts a chat, but a chatty one with nobody else to talk to may turn to them, once a night), whether they're hungry or having a rough night, and whether they'll order more later.
- Visits: arrive, order from the menu, eat and drink, talk with the owner (and maybe other customers), then say goodbye, pay and leave when their time's up.
- **Nobody knows more than they should:** the AI is told what everyone can see (how someone looks) and that nobody knows another's name, age, job, reason for coming or secret until it's been said. Everyone speaks fluent, natural English (they're speaking Korean), with the odd Korean word a K-drama fan would know.
- **What conversations turn to:** the game picks a topic for each spell of chat (their day, what's on their mind, a story from the owner's past, the weather, the cat, food, the owner's nagging, a silly food fight, an embarrassing story, teasing between friends…), so talk doesn't get stuck on one thing. The night has a shape: lighter before midnight, more open after it.
- **Strangers talk politely:** nobody at the counter knows anyone yet, so terms like oppa, hyung, nuna and eonni (for people who are close) are ruled out, and no two people there share a name.
- **Regulars:** every bar opens with two long-standing regulars, each with a role in the tent; new customers can become regulars, who come back more the more regular they are, fade away if they stop coming, and come back as themselves (the same name, look and personality, their usual). Everyone knows only what they've actually learned: whose names have been said, how many visits, what each knows about the other. After each visit, the owner and the customer each remember the gist (a sentence or two), the things that stick (job, family, home town) are kept if they were really said, and the AI's verdict on the night decides whether someone comes back. Who may call whom what (oppa, eonni, imo, sajangnim…) is a game rule, from gender, age, owner or customer and closeness; regulars who chat get to know each other, and after a few meetings the younger may ask to use a friendlier term, which is allowed from then on. Terms are coloured by warmth on screen, with their meaning on hover.

### The cat
- Every bar has a cat, saved with it: the game picks its coat, personality (lazy, affectionate, greedy, grumpy or curious) and sex (she or he), and it's a stray that wandered in and stayed, so it isn't anyone's: the owner and the regulars gave it a nickname, the kind Koreans give street cats (나비 Nabi, butterfly; 고등어 Godeungeo, mackerel, for a striped tabby; 치즈 Chijeu, cheese, for a ginger), which the AI picks from the game's list for its coat (no two bars' cats share one, and never a person's name). Its meaning is on its hover.
- A greedy cat sometimes steals a fish cake skewer off someone's table and bolts (a game fact, with the red light).
- The game decides where it is all night (asleep by the stove, on someone's lap, out in the street…), by its personality, and everyone talks about it as it really is: nobody strokes it unless it's on their lap.

### The tent's look
- **Every bar looks like its own:** the AI chooses its look to suit the owner and the name, from options the game offers, and it's saved with the bar. The sign shows the name in Hangul with the romanised name under it, in wood, neon, banner or lightbox style. The tent cover has a shape (classic, peaked, scalloped, awning or rounded) and a colour (ten, three of them striped); each new bar is offered a random shortlist of colours and shapes, so they vary. One or two little touches finish it off (string lights, lanterns, a lucky cat…).
- **Speech bubbles:** each line also pops up over whoever's speaking, with who it's to and a line to the listener; the transcript keeps everything.
- **Korean TV captions:** the night is edited like a variety show. When something noteworthy happens, a caption pops up in Hangul and English with a sound sting ("짠! JJAN! CHEERS!", "폭풍 흡입! INHALING IT!", and for emergencies a flashing red light and siren). The game decides when and owns the words, and for the big moments in a conversation the AI writes the caption while the game keeps the Korean ("충격! SHE QUIT HER JOB?!").
- **What you hear:** the street, the weather and the tent (rain on the tarp, traffic on the overpass, the odeng pot, sizzling while something cooks, the counter's murmur, glasses and stools), all following what the game knows is happening, and Arirang now and then.
- **The night around it:** the sky darkens through the night and the tent's glow changes with it; behind the tent, the city (APT blocks with their numbers on the side, office towers, neon crosses), each bar's own, its windows going dark as the night goes on; the nights run through the year's seasons (with the summer monsoon), and the weather follows on from night to night, with the first snow of each winter a moment of its own; the weather is something you see (rain, snow, fog, haze, a swinging bulb in a breeze); and most people in the street walk past without coming in, busiest in the evening: alone, in twos and threes, on their phones, under umbrellas of all shapes when it's wet (customers fold theirs down under the tarp), or now and then running for it.
- **Korean words explained:** the menu, the words people say at a pocha (banchan, jjan, aigoo, hwaiting…) and the terms of address are coloured, and explain themselves on hover. The rule: any Korean that stays on screen (the bar's sign, the neon across the street) has a hover saying what it is, and so does any Hangul in the transcript, the info panel and the diary (captions, names, stamps), so you can tell a translation from something else; captions and recaps that pop up and go show their English alongside instead. The game's own Hangul has its meaning written once and checked by a test; Korean the AI invents (a bar's name, later a dish's) comes with its meaning in the same reply, kept as a game fact; the AI never translates live, since its Korean isn't reliable.
- **Conditions, not scripts:** the game never hands the AI a line to say. Now and then it sets a scene instead, only when it's true: how someone orders tonight, a craving ("rain like this always makes them crave pajeon and makgeolli"), a table custom (nobody pours their own glass), a chance to share. The AI decides whether anything comes of it.

## Saving and loading

Each **save is one bar**: its owner, its regulars, its history. You can have several and come back to any of them.

- **Title screen:** *New bar* or a list of saved bars (bar name, owner, nights and visits, takings and last played), each of which can be opened or deleted (two clicks, so a stray one can't lose a bar).
- **New bar:** the AI invents the owner and the bar's name (a Korean name, checked by the game like everything else the AI writes), and a new save is created straight away.
- **Autosave, always.** The game saves as it goes, with no save button and no "your progress will be lost" prompt. Close the window at any time, and next time you load, it carries on with the next customer.
- **When it saves:** when a bar is created, after every visit, at the end of each night, when you close the bar, and when the window is closed.
- **What's saved:** the bar's name and its meaning, the owner, the cat, the takings, the visit and night counts, a short history of recent visits (who came, what they ordered, the bill), a log of recent nights (day, weather, customers, takings, memorable line), the day of the week it started on, and later the menu and (from the Regulars and relationships stage) regulars and what they remember.
- **Closing up early:** **Close the bar** during a night closes up early: a 마감 CLOSED board goes out front and a bulb goes off, nobody new comes in, and the owner tells the counter why (her own reason, from the AI, also on TV). Whoever's here finishes their night at their own pace; once the tent's empty the night ends there, counted, with the owner's diary (giving the same reason) and a 조기 마감 CLOSED EARLY stamp. From the diary page you can open the next night or go back to the title.
- **Quitting mid-night:** closing the window instead (its X, or Alt-F4) just saves and quits: for now, a night you leave that way isn't counted, and opening the bar again starts that night afresh at 6pm; resuming mid-night is a later idea. An unfinished visit simply ends when you quit. Resuming mid-conversation (the customer still on their stool, the chat picking up from the saved transcript) is a later idea in [PLAN.md](PLAN.md).
- **Safe writes:** each save is written to a temporary file and then swapped in, so a crash mid-save can't corrupt the bar.
- **Format:** one JSON file per bar in Godot's `user://saves/` folder (on Windows: `%APPDATA%\Godot\app_userdata\KTBT\saves\`). It's human-readable, which is handy for debugging, or for peeking at what the AI invented.

## K-drama style guide

Included in every AI prompt so all characters feel like they belong to the same show. The AI riffs on these rather than copying them.

**Setting:** a tarp tent (each bar's own shape and colour), plastic stools, green soju bottles, steam off the tteokbokki, bare bulbs swinging, rain more often than not.

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

### Cheeky, not "bants"

The tent isn't all sad: friends rib each other, the owner nags, people argue about whether the sauce goes on or the pork goes in it. That cheek is affection, and the game keeps it that way. What it never does is the kind of "bants" some people use as a cover for harassment, sexual or otherwise.

- **Affection, and both sides know it:** only between people who are already close, or from the owner to a regular. Never at strangers, never at someone who has just sat down.
- **Down or sideways, never a pile-on:** one person teases, the table doesn't gang up.
- **What you do, not who you are:** slurping noodles, losing the table game, the karaoke song, still not texting back. Never bodies, looks, weight, gender, sexuality, age as an insult, or anything sexual. Being single only if they brought it up.
- **They can give it back:** if the target can't answer, it isn't teasing.
- **The owner is the line:** when someone goes too far, the owner shuts it down.

This holds at every content setting. A future Adult setting can have adult things in it, between grown-ups who want them. It still won't have people who use "it's just a joke" to justify hurting someone.

### Real people, brands and shows

The game is full of Korean references, and should be. But what's in it is written live by an AI nobody reviews, so it never uses real people, brands or shows by name. (Not legal advice: just staying well clear. Korean TV is famously careful about this too, blurring logos and inventing brands.) The joke works without the name.

- **No real people:** no celebrities, TV chefs, idols, actors, athletes or politicians, in dialogue, captions, the diary, recaps, or anything else the game shows. Describe the trope instead: "salts it from shoulder height like a TV chef showing off", not the chef's name.
- **No brands or products:** "mix coffee" (믹스커피) or "a vending-machine coffee stick", not the brand; "the green bottle" of soju, not its maker; "the convenience store", not the chain. Generic Korean food and drink names are fine (soju, makgeolli, banana milk, ramyeon, mix coffee). No logos in the art, ever.
- **No real shows, films, songs or games by name:** "that fridge cooking show", "a K-drama", "a variety show", "the game he plays all night".
- **What's fine:** real places (Seoul, Busan, Hongdae, the Han river), public holidays and customs (Chuseok, Seollal), public-domain music (Arirang and other folk songs, classical pieces), and the tropes themselves.
- **Our own stand-ins:** when a reference needs a name, the game can own a fictional one (a celebrity chef, a coffee brand, a drama everyone's watching), clearly our own and not a near-copy of a real name.
- **The same for anything public:** the store page, screenshots, the trailer, the game's own text. (The design docs can mention real games and shows as inspiration, like *Coffee Talk*: that's talking about the game, not what's in it.)
- **How it's kept:** the AI's style guide says so, and lines, captions, diaries and recaps naming an obvious brand are sent back (`Talk.REAL_BRANDS`). Real people can't be listed reliably, so for them it's the prompt; anything that slips through goes in [LLM-TUNING.md](LLM-TUNING.md).

## Menu and ordering

Each bar has its own menu, chosen when it opens from a catalogue of real pocha dishes (`scripts/rules/catalogue.gd`): the staples everywhere (soju, beer, a bowl of rice), most of the pocha classics, the owner's own picks to suit them, and their signature dishes, on a board in the tent you can click to read. The AI chooses within the game's house rules (how many dishes, prices within each dish's range). Bars from before menus, and the tests, keep the **classic menu** (`scripts/rules/menu.gd`):

- **Drinks:** soju, makgeolli, beer, somaek (soju dropped in beer)
- **Mains:** tteokbokki, sundae, dakgalbi, pajeon, ramyeon
- **Sides:** odeng (fish cake skewers), gyeran-mari, gonggibap (a bowl of rice), bokkeumbap (fried rice made in the leftover sauce; only ordered later, after a main)
- **Free banchan** (kimchi and pickled radish) comes with every order and isn't on the bill.
- **Signature dishes:** one or two of the owner's own, invented from their story ("grandma's knife-cut noodles"), first on the board under 대표 메뉴.
- **Tonight's specials:** the game picks a dish from the bar's own menu by the weather and the season (rain is always a pancake and makgeolli), now and then the owner's own dish or a drink worth pushing, never the staples or last night's again; marked on the menu customers see.
- **Sold out:** now and then a dish has run out: struck through on the board, and it can't be ordered.
- **Menus change slowly:** every few weeks, a dish hardly anyone orders comes off the board and the owner chooses something seasonal to go on instead (never a regular's usual, never the classics or their own dishes). The diary mentions it.

**How people order** (game rules, checked on every AI order):

- **What they say is what they get:** an order line that names a different drink or main is asked for again; a side it asks for but the AI left out is added.
- **First order:** at least one drink and one food, because nobody drinks on an empty stomach. Usually one main and one drink, maybe a side. The game decides who's **hungry** (may order two mains) or having a **rough night** (may order two drinks).
- **Later orders:** half of customers order once; the rest order more partway through the conversation (one more bottle, a side, rice), and a few order a third time. Never a new main, at most one more drink each time, and it has to sound like ordering more.

## Tech

| Piece | Choice |
|---|---|
| Engine | Godot 4, GDScript |
| AI | Local model via Ollama (RTX 3080, so 7–9B models; try Llama 3.1 8B, Gemma and Qwen to compare). Per-machine AI settings choose Ollama or an offline mode with pre-written characters |
| Connection | Godot `HTTPRequest` to Ollama's local API, JSON output mode for structured replies |
| Art | Placeholder shapes drawn in code for now (the tent, the people, the weather), then real art (see **Character art** in [PLAN.md](PLAN.md)) |
| Sound and music | Made in code for now (`ambience.gd`, `music.gd`), then CC0 recordings and a real arrangement |
| Assets log | `CREDITS.md`, recording the source and licence of every asset |

Show a "typing…" indicator while the AI replies.

## Plan

What we're building next is in [PLAN.md](PLAN.md), what's been done so far is in [DEVLOG.md](DEVLOG.md), and AI quirks are in [LLM-TUNING.md](LLM-TUNING.md).
