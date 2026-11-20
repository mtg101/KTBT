# KTBT: Plan

What's left to build for [KTBT](CONCEPT.md). Only what's left goes here: when something's built, it moves to [DEVLOG.md](DEVLOG.md) (and how it works, to CONCEPT.md), and a part-built item keeps only what's still to do. AI quirks are in [LLM-TUNING.md](LLM-TUNING.md).

## Next stages

- **Seasons and the platform ladder (next):** a reason to play. The ratings are the score; the show climbs or drops a ladder of platforms, season by season, and is never taken off air. The bar, its regulars, bonds, diary and story carry through every rung: only the show's reach changes.
  - **Where it starts:** a new bar's first episodes are filmed by the owner's niece or nephew (a game fact: who they are, their name, their gender), on a good phone with a live video production app. They're the PD: the player has every PD tool from the first night (cards, the camera, pins, spins, the edit suite). When the show moves up, they go with it (a junior PD at the channel, then the show's PD).
  - **Named channels:** every booking is with a channel that has a name: the AI invents it (the game decides the rung; the AI the name, in Hangul and English, with its meaning on hover), checked against real ones (no KBS, MBC, SBS, EBS, tvN, JTBC, Mnet, TV Chosun, Channel A, MBN, ENA, nor any real app or video site) and against the bar's earlier channels. The phone stream's is the niece or nephew's own handle. Each season's announced with it ("You've been booked for a season on 달빛TV, Moonlight TV!"); staying up means renewed by the same channel, moving to another rung means a new one ("Moonlight TV didn't renew, but Hanbit Plus has picked the show up"). The bar keeps its channel history (which channel, which seasons, how they went) for the diary, "Previously on…" and the title screen. Offline, the canned names do.
  - **Small touches of flavour:** the channel on the loading screen and "Previously on…"'s card (with named channels).
  - **Tuning the ladder:** check the targets and the units against a batch (1,000 views a night on the stream, 10,000 subscribers on the channel, 10% a hit and under 5% quiet on TV; 120 views and 150 subscribers a point of the score, less 300 unsubscribes an episode: a great season moves up in one, a good one in two), as the autopilot PD's nights average about 9.5; perhaps shorter seasons (6) on the lower rungs.
  - **The season on TV:** the new season's premiere opening with "Previously on…" over the whole last season (the AI's, from the season page's rows), and the seasons in the diary book (each season's page between its episodes).
- **More of the show's setup:** the setup screen (a new bar's, while it's being made) choosing more than the rung: the niece or nephew, the season's length, the content setting, perhaps the owner's kind or the bar's look.
  -- both sandbox mode and makes testing specific features easier

## Future ideas and improvements

### Richer play

- **Memories and relationships, follow-ups:**
  - **Contradictions:** lines contradicting someone's family (married, widowed, divorced, single; children or none) are sent back. If "contradictions caught" runs high, the prompts need to lean on the facts harder; other facts (a job, a home town) aren't checked yet.
  - **Terms of address in every line:** watch whether "most lines need none" brought it down.
  - **Banmal too soon:** close regulars talk casually now; a stranger slipping into banmal too soon could be a small rudeness the other notices.
  - **Check in the next batch:** "lines told who they know here", "regulars remembered each other" (and failed), facts by kind and who heard them, threads asked and answered, the closeness line; and in the transcripts, whether lines use what they're told without overdoing it.
- **Customers coming in together, the rest:**
  - **Threes and fours:** three nurses off a night shift, a team after a hoesik; waiting for three stools or squeezing in; a three-way bill fight.
  - **Greeted and ordering together, sometimes:** the owner greets a pair with one welcome ("two of you tonight?"), and one orders for both ("two somaek and the pajeon to share", one line, both served), the game deciding when; the sharing moments (pouring for each other, ssam) made for them.
  - **The story:** who came in with whom in the diary and "Previously on…".
  - **Speaking for the right person:** in a three- or four-way chat, small models are likelier to write someone else's line, or a whole exchange: the checks that strip "Name:" and cut off second lines should know every name in the chat.
- **The game, as the PD (next steps):** 
  - **More of being on a show:** now and then a fly-on-the-wall trope beyond noticing the camera: someone hiding their face, someone playing up to it, a regular asking if they'll be in this week's episode, an "off the record" confession that isn't. Not every night: it's still mostly a tent bar.
  - **More cards:** the owner's past walks in (near their secret, so it fits their fixed life); the cat brings something in; an **overheard** write-in (someone at the counter overhears what you write); choosing a card's variant, or typing your own ("they worked out they ___"); rare cards (towards the roguelike PD); cards that never land (from the logs) reworded or dropped; later, cards players write.
- **Drinking too much (with a content setting first):** past three or four bottles, someone dozes face-down on the counter (the owner drapes something over them), someone heartbroken makes the 2am call to an ex (술김에?! on TV), and one of a pair piggybacks the other home. Drunkenness played for drama, so alongside **Content boundaries**.
- **Drama incidents and story arcs:** K-drama beats: a confession at the counter, a drunk sent home in a taxi, a breakup at the next table, the owner's secret slowly coming out, redevelopers threatening to tear the tent down. A light **drama director** picks a beat for the night (a game fact) and the AI writes it. Over many nights, **long-term relationships**: a regular moving away, a romance at the counter, an old friend falling out with the owner.
- **Cliffhangers the night can answer, more often:** the first recaps ended on questions no night can answer ("other"). Watch HIGHLIGHTS and THE STORY; if it persists, steer the recap prompt to the kinds on the list.
- **Cliffhangers about what's said (a stage of its own):** "will she finally confess?", "will he quit?", "is the secret out?": the AI judges after a conversation whether it was answered (like the TV reaction check), with a check and tests for each kind.
- **Regulars book:** 
  - a page per bar (from the title screen and a button in the bar), a card per regular: their look drawn small, name in Hangul and English, their role, closeness as soju cups 🍶 filling up, how often they come ("most Fridays", "hasn't been in for a while"), visits, first and last, their usual, the things that stuck, each side's latest memory, the regulars they know. A first piece of the journal.
  - can have local AI generated portraits (see above)
- **Where people are from:** a home town as a game fact (Seoul, Busan, Daegu, Jeju, a village in Jeolla…) shaping how they talk: Busan's blunt, warm Gyeongsang satoori as flavour in fluent English (the odd "mwo-kko?", a gruffer rhythm), not broken English. Ties into the things that stick.
- **More cat:** customers ordering something for it, a night out on a curious streak, a cat that only likes certain people. Game events, like the rest of it.
- **Weather that changes:** one weather at 6pm today; it could change during the night (rain setting in after midnight), the sound and visuals fading across.
- **Non-Korean visitors:** tourists and expats, naturally using Western name order (see LLM-TUNING.md).
- **Focus camera on owner:** can focus on customers and cat, owner makes sense too
- **Calendar, holidays and events:** Korean occasions from the date (`rules/seasons.gd`: Seollal, Chuseok, Christmas, 11/11...) as game facts shaping who turns up, what they order and what they talk about; and any occasion a line mentions checked against tonight's date (19 Nov: Chuseok came up in November).


### An actual game or experience

- **A roguelike PD:** the plant cards as a game of their own: a deck built up over a season, cards earned from good ratings, rarer cards (a chaebol heir in disguise, a long-lost sibling, a typhoon), combos, a network executive's demands each run (a ratings target, "more romance this week"), the season ending in renewal or cancellation. The tent still runs itself; the run is the PD's.
- **Sharing an episode:** an "episode card" (the title, the line of the night, the TV reaction, the people drawn small) saved as an image or a short clip. Suits a game that's open about its AI, and feeds the store page.
- **social media responses: ** at end of day summary, alongside diary, affects ratings (future: popsup live during show)
- **Player customisation:** the style guide, archetypes and menu catalogue as editable files, so players can make their own bar; and settings like time speed and weather.
- **A first night for someone new:** a guided first episode, the producer explaining one control per beat (the desk, cards, pins, spins, the edit suite).


### Presentation

- **Portraits:** a picture of each character (for the hover or the diary).
  - **Pre-generated:** the local image model (FLUX.2 Klein, set up for the street) makes portraits or parts in one style, tagged by age, gender, job and so on; the keepers are curated and shipped, and the game picks the best match. Nothing runs during play, so no GPU contention, and it works on the laptop.
  - **Mixed (probably the right balance):** regulars get their own portrait made between nights.
  - **Live:** drawn as each customer arrives: competes with the LLM for GPU memory, takes seconds, drifts off-style, can't run on the laptop.
- **Ambience (sound and animation):** 
  - **Varying the music:** more public-domain tunes Korean TV uses, arranged in code: folk songs (Doraji taryeong, Milyang and Jindo Arirang, Ganggang-sullae, Saeya saeya) and the classical pieces variety shows love (Flight of the Bumblebee for a rush, a Chopin nocturne at 2am, Vivaldi, the Can-can), chosen by the game from the scene, never over a reaction's sting.
  - **Background animation:** the occasional street cat, more vessels and bits as dishes are added. (Cars on the overpass were tried: lights above the tent looked wrong.)
- **Voices:** characters speak their lines, a setting choosing **off**, **babble**, **system voices** or **AI voices**; the game picks each voice from facts it owns (gender, age, mood).
  - **Babble (first):** Animal Crossing-style syllables per word, pitched and paced per character (deeper and slower for an old ajusshi, quicker when nervous), from a few CC0 sounds. No AI, runs anywhere.
  - **System voices:** Godot's built-in text-to-speech with Windows' voices: robotic, but no setup; a quick test of whether speech adds anything, and a fallback.
  - **AI voices:** a local text-to-speech service beside Ollama, on the CPU so it doesn't fight the LLM: **Kokoro** (82M, Apache-2.0, good quality) or **Piper** (fast, GPL-3.0 engine, voices with their own licences). Check first how they say Korean names and words.

### Technical

- **Optimise: only when noticed:** you'd think 10 local LLM calls with big prompts would take ages... but I'm not noticing delays yet - optimize when we need to!
  - **Watching AI quality over time:** autoplay writes the batch review we do by hand (rejections by kind, give-ups, facts and threads that went wrong, lines misusing what they were told) and compares it with the last batch; a small model reading transcripts could flag what the checks can't see (19 Nov: "that husband… he's a good kid").
  - **Prompt length:** every feature adds context (who you know, facts, threads, notes), and with an 8B model length costs speed and obedience. Measure prompt size and reply time per call in the stats, set a budget, and try a newer or Korean-fluent local model then: a better model may fix more than any single check.
  - **Speed and waiting:** each visit is 10+ AI calls:
    - **Warm the model up at the title screen:** Ollama unloads the model after 30 idle minutes (`keep_alive`), and the first reply then takes up to a minute (the loading screen looks stuck): a tiny request as the title opens.
    - **A second voice:** the owner's AI voice is busy about 98% of the night (first drinks took 11–19 minutes; chats got 8–21% of lines) because one request runs at a time. Customer chats on a second voice, alongside (`OLLAMA_NUM_PARALLEL`), each slower on one GPU:
      1. **Measure first:** a button in the pipeline test (`scenes/pipeline_test.tscn`) timing one request, then two at once, on the desktop and the laptop. Go on only if two take much less than twice as long.
      2. **Then build it:** a second AI object for chats that never wait for the owner, bubbles and transcript coping with two at once, and each voice's share in the stats.
- **Older saves kept up to date:** upgrade by the save's `version` rather than by what's missing (`scripts/save/save_upgrades.gd`), filling in whatever a new feature needs (a bar from before the cat still has none).

### Pretending to release it

- **Packaging, first-run setup and releasing:** a big part of the point is learning to ship a Godot game.
  - **Exporting:** export templates, a Windows preset, an icon, the name and version in the build, and a check that it runs on a clean machine (saves and logs in the user folder).
  - **Can we include the local AI models as part of the install?**  or we have to explain it in docs with fallback modes
- **A store page, as if for real:**
  - **The overview:** a one-line pitch ("Coffee Talk with soju: a Korean tent bar where every customer is invented by an AI, and every night is an episode"), short and long descriptions, features as bullets (AI customers with memories, regulars who come back, Korean TV captions, the owner's diary, Hangul names, offline mode), tags.
  - **Screenshots:** five or six moments at full resolution: a full house in the rain, a TV caption mid-pop, a reaction ("충격!"), the 3am diary, the "Previously on…" card, the title screen; perhaps a screenshot mode with the panels hidden.
  - **A promo video:** a 30–60 second K-drama-teaser cut: the tarp going up, customers ducking in, captions popping, a big moment, the diary, the title card; Arirang (or another of our arrangements) under it, and the game's stings.
  - **The rest:** a cover and a banner (from the title and loading art), a GIF or two, system requirements (an NVIDIA GPU with about 10GB, or offline mode), what the AI does and doesn't do (it runs on your machine; nothing's sent anywhere), credits, licences, a press kit.
  - **Being open about the AI:** the page says plainly that a local AI model writes the characters and the game was built with AI help.
