extends RefCounted
## The edit's clipart (PLAN.md, "Variety-show clipart"): the little drawings Korean TV sticks to
## people on screen when a caption pops: a crow flapping past an awkward silence, a rain cloud
## over someone sad, hearts floating up. The face on the caption says who; the clipart stuck to
## them on stage says what's happening to them. Drawn in code (tools/art/clipart.py draws what's
## listed here, a few frames each); the sticker on stage is ui/clipart_sticker.gd.
## (Part of the game's rules: pure functions and the tables they use, with any dice rolls
## passed in, so they can be tested on their own. See ARCHITECTURE.md.)

## Each clipart: how many frames it loops through, how fast (frames a second), where it goes on
## the person, and the Hangul it carries, if any (explained on hover: Hangul.MEANINGS).
## "label": the Hangul written beside it; false where the drawing is the words (ㅋㅋㅋ).
## Where (on the person, standing or seated):
##   "over": above their head; "face": beside their face; "beside": by their head, to one side;
##   "chest": through the chest; "behind": behind their head and shoulders (drawn behind them);
##   "feet": at their feet.
## "drift": how it moves for the caption's beat, if at all: "across" (flying or rolling past them,
## left to right) or "up" (floating up and away).
const CLIPS := {
	# Awkward
	"crow": {"frames": 4, "fps": 8, "place": "over", "drift": "across", "hangul": "까악 까악"},
	"sweat": {"frames": 3, "fps": 5, "place": "face"},
	"tumbleweed": {"frames": 4, "fps": 10, "place": "feet", "drift": "across", "hangul": "휘잉~"},
	# Sad
	"rain_cloud": {"frames": 3, "fps": 8, "place": "over"},
	"tears": {"frames": 3, "fps": 8, "place": "face"},
	# Sweet
	"hearts": {"frames": 4, "fps": 5, "place": "over", "drift": "up"},
	"blush": {"frames": 2, "fps": 3, "place": "face"},
	"flowers": {"frames": 2, "fps": 3, "place": "behind"},
	# Shock
	"lightning": {"frames": 2, "fps": 10, "place": "over"},
	"bang": {"frames": 2, "fps": 6, "place": "beside"},
	"mind_blown": {"frames": 4, "fps": 6, "place": "over", "hangul": "멘붕"},
	# Funny
	"haha": {"frames": 3, "fps": 6, "place": "beside", "hangul": "ㅋㅋㅋ", "label": false},
	"laugh_tears": {"frames": 3, "fps": 8, "place": "face"},
	# Warm
	"sunbeams": {"frames": 2, "fps": 3, "place": "behind"},
	"halo": {"frames": 3, "fps": 5, "place": "over"},
	# A roast
	"arrow": {"frames": 2, "fps": 6, "place": "chest", "hangul": "뼈 때림"},
	# The game's own captions
	"soul": {"frames": 4, "fps": 5, "place": "over", "drift": "up", "hangul": "영혼 가출"},
	"flames": {"frames": 3, "fps": 8, "place": "behind"},
	"stars": {"frames": 4, "fps": 8, "place": "over"},
	"siren": {"frames": 4, "fps": 8, "place": "over", "hangul": "비상!"},
}

## Each TV mood's clipart (one picked by the roll); "calm" (a plain portrait: a new face) has none.
const BY_MOOD := {
	"awkward": ["crow", "sweat", "tumbleweed"],
	"sad": ["rain_cloud", "tears"],
	"sweet": ["hearts", "blush", "flowers"],
	"shock": ["lightning", "bang", "mind_blown"],
	"funny": ["haha", "laugh_tears"],
	"warm": ["sunbeams", "halo"],
	"roast": ["arrow"],
}

## The game's captions with clipart of their own, whatever their face's mood: the soul leaving
## the body for a hoesik's escapees, flames behind a bill fight or a drinking game, stars for
## another round. An emergency caption (the red border) not here gets the siren.
const BY_KIND := {
	"hoesik_escape": ["soul"],
	"bill_fight": ["flames", "siren"],
	"another_round": ["stars"],
	"game_love_shot": ["flames"], "game_spoon_mic": ["flames"], "game_apartment": ["flames"],
	"game_nunchi": ["flames"], "game_titanic": ["flames"],
}


## The clipart for a caption (kind: "" for an AI reaction, which has only its mood), picked by
## roll (0..1): the kind's own, else the siren for an emergency, else the mood's; "" for none.
static func pick(kind: String, mood: String, emergency: bool, roll: float = 0.0) -> String:
	var choices: Array = BY_KIND.get(kind, ["siren"] if emergency else BY_MOOD.get(mood, []))
	if choices.is_empty():
		return ""
	return str(choices[clampi(int(roll * choices.size()), 0, choices.size() - 1)])


## The art's keys for a clipart's frames ("clipart/crow_0"...).
static func frame_keys(clip: String) -> Array:
	var keys: Array = []
	for frame in int(CLIPS.get(clip, {}).get("frames", 0)):
		keys.append("clipart/%s_%d" % [clip, frame])
	return keys


## Every frame's id, for the art (Art.ids("clipart")).
static func ids() -> Array:
	var out: Array = []
	for clip in CLIPS:
		for key in frame_keys(clip):
			out.append(str(key).trim_prefix("clipart/"))
	return out


## The Hangul it carries ("" for none), and whether it's written beside it.
static func hangul(clip: String) -> String:
	return str(CLIPS.get(clip, {}).get("hangul", ""))


static func labelled(clip: String) -> bool:
	return hangul(clip) != "" and bool(CLIPS.get(clip, {}).get("label", true))


## Where it goes on the person ("over"...), and how it moves ("" for staying put).
static func place(clip: String) -> String:
	return str(CLIPS.get(clip, {}).get("place", "over"))


static func drift(clip: String) -> String:
	return str(CLIPS.get(clip, {}).get("drift", ""))
