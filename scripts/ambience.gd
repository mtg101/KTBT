class_name Ambience
extends Node
## The tent's background sound. For now every sound is made in code (placeholders until
## real recordings): a loop for each layer (the city's hum, drizzle, rain, wind, the odeng
## pot, sizzling, the murmur at the counter, cicadas), faded up and down to match the scene,
## and one-off sounds for what happens (cars and trucks on the overpass, a delivery scooter,
## the subway, glasses, a pour, stools, the cash tin, the cat). The game says what's going
## on (set_scene, play); this only decides how it sounds.

const Rules = preload("res://scripts/rules.gd")

## Test hooks: false makes no sound at all (nothing is made or played); and where the
## Sound on/off setting is kept.
static var make_sound := true
static var settings_path := "user://settings.cfg"

const RATE := 22050
const LOOP_SECONDS := 6.0
const CROSSFADE_SECONDS := 0.3
const BUS := "Ambience"
## Each loop's loudness when fully up, and each one-off's (dB).
const LOOPS := {"hum": -20.0, "drizzle": -16.0, "rain": -11.0, "wind": -17.0, "simmer": -32.0,
	"sizzle": -21.0, "murmur": -23.0, "cicadas": -27.0}
const SOUNDS := {"car": -17.0, "truck": -15.0, "scooter": -19.0, "subway": -19.0, "clink": -15.0,
	"pour": -22.0, "scrape": -19.0, "cash": -17.0, "meow": -17.0}
const FADE_PER_SECOND := 0.5  # how fast a loop moves to its new level
const LAST_TRAIN := 24 * 60 + 60  # no subway rumbling under the street after 1am

static var _made: Dictionary = {}  # name -> AudioStreamWAV, made once per run

var enabled := true  # the Sound toggle
var volume := 0.8  # the Sound volume slider, 0 to 1
var _built := false
var _loops: Dictionary = {}  # layer -> AudioStreamPlayer
var _level: Dictionary = {}  # layer -> how far up it is now (0 to 1)
var _target: Dictionary = {}  # layer -> how far up it should be
var _busy := 0.5  # how busy the street is (0 to 1)
var _minutes := 18 * 60
var _next := {"car": 3.0, "scooter": 20.0, "subway": 40.0}  # real seconds until each comes by


func _ready() -> void:
	enabled = load_enabled()
	volume = load_volume()
	if not make_sound:
		return
	AudioServer.set_bus_mute(_bus(), not enabled)
	AudioServer.set_bus_volume_db(_bus(), linear_to_db(maxf(volume, 0.001)))
	_build()


## The Sound toggle: on or off, remembered for next time.
func set_enabled(on: bool) -> void:
	enabled = on
	if make_sound:
		AudioServer.set_bus_mute(_bus(), not on)
	save_enabled(on)


## The volume slider (0 to 1), remembered for next time.
func set_volume(level: float) -> void:
	volume = clampf(level, 0.0, 1.0)
	if make_sound:
		AudioServer.set_bus_volume_db(_bus(), linear_to_db(maxf(volume, 0.001)))
	var settings := ConfigFile.new()
	settings.load(settings_path)
	settings.set_value("sound", "volume", volume)
	settings.save(settings_path)


static func load_volume() -> float:
	var settings := ConfigFile.new()
	if settings.load(settings_path) != OK:
		return 0.8
	return clampf(float(settings.get_value("sound", "volume", 0.8)), 0.0, 1.0)


static func load_enabled() -> bool:
	var settings := ConfigFile.new()
	if settings.load(settings_path) != OK:
		return true  # on by default
	return bool(settings.get_value("sound", "on", true))


static func save_enabled(on: bool) -> void:
	var settings := ConfigFile.new()
	settings.load(settings_path)  # keep anything else in there
	settings.set_value("sound", "on", on)
	settings.save(settings_path)


## What's going on in the scene: "weather" (a Rules.weather_kind), "people" at the counter,
## "cooking" (something's on the stove), "open" (the night's running) and "minutes" (the clock).
func set_scene(scene: Dictionary) -> void:
	_target = mix(scene)
	_minutes = int(scene.get("minutes", _minutes))
	_busy = clampf(Rules.arrivals_per_hour(_minutes) / 4.0, 0.0, 1.0)
	if make_sound:
		AudioServer.set_bus_effect_enabled(_bus(), 0, muffled(str(scene.get("weather", ""))))


## How far up each loop should be (0 to 1) for this scene.
static func mix(scene: Dictionary) -> Dictionary:
	var weather := str(scene.get("weather", ""))
	var people := int(scene.get("people", 0))
	var levels := {}
	for layer in LOOPS:
		levels[layer] = 0.0
	levels["hum"] = 0.6 if muffled(weather) else 1.0
	levels["simmer"] = 1.0 if bool(scene.get("open", false)) else 0.0
	levels["sizzle"] = 1.0 if bool(scene.get("cooking", false)) else 0.0
	levels["murmur"] = clampf((people - 1) / 4.0, 0.0, 1.0)  # one person just talks to the owner
	match weather:
		"drizzle":
			levels["drizzle"] = 1.0
		"rain":
			levels["rain"] = 1.0
			levels["drizzle"] = 0.5
		"breeze":
			levels["wind"] = 1.0
		"cold":
			levels["wind"] = 0.4
		"snow":
			levels["wind"] = 0.25
		"muggy":
			levels["cicadas"] = 1.0
	return levels


## Snow and fog hush everything.
static func muffled(weather: String) -> bool:
	return weather in ["snow", "fog"]


## Real seconds until the next car over the overpass: a few seconds when the street's busy
## (busy near 1), half a minute when it's quiet, from a roll between 0 and 1.
static func traffic_gap(busy: float, roll: float) -> float:
	return lerpf(30.0, 6.0, clampf(busy, 0.0, 1.0)) * (0.5 + clampf(roll, 0.0, 1.0))


## A one-off sound, a little different each time. delay: real seconds from now.
func play(sound: String, pitch: float = 1.0, delay: float = 0.0) -> void:
	if not _built or not enabled or not _made.has(sound):
		return
	if delay > 0.0:
		await get_tree().create_timer(delay).timeout
		if not is_inside_tree():
			return
	var player := AudioStreamPlayer.new()
	player.stream = _made[sound]
	player.bus = BUS
	player.volume_db = float(SOUNDS[sound]) + randf_range(-2.0, 1.0)
	player.pitch_scale = pitch * randf_range(0.92, 1.08)
	add_child(player)
	player.finished.connect(player.queue_free)
	player.play()


func _process(delta: float) -> void:
	if not _built:
		return
	for layer in LOOPS:
		var now: float = move_toward(float(_level[layer]), float(_target.get(layer, 0.0)), delta * FADE_PER_SECOND)
		_level[layer] = now
		(_loops[layer] as AudioStreamPlayer).volume_db = float(LOOPS[layer]) + linear_to_db(maxf(now, 0.001))
	for sound in _next:
		_next[sound] = float(_next[sound]) - delta
		if float(_next[sound]) > 0.0:
			continue
		match sound:
			"car":
				play("truck" if randf() < 0.2 else "car")
				_next[sound] = traffic_gap(_busy, randf())
			"scooter":
				play("scooter")
				_next[sound] = traffic_gap(_busy, randf()) * 5.0
			"subway":
				if _minutes < LAST_TRAIN:
					play("subway")
				_next[sound] = randf_range(70.0, 140.0)


## The Ambience bus: everything plays through it, so the toggle mutes it, and its low-pass
## filter (off unless it's snowing or foggy) muffles it.
static func _bus() -> int:
	var index := AudioServer.get_bus_index(BUS)
	if index == -1:
		AudioServer.add_bus()
		index = AudioServer.bus_count - 1
		AudioServer.set_bus_name(index, BUS)
		AudioServer.set_bus_send(index, "Master")
		var muffle := AudioEffectLowPassFilter.new()
		muffle.cutoff_hz = 1100.0
		AudioServer.add_bus_effect(index, muffle)
		AudioServer.set_bus_effect_enabled(index, 0, false)
	return index


## Makes the sounds (a frame apart, so the loading screen keeps moving), then starts the loops.
func _build() -> void:
	for sound in LOOPS.keys() + SOUNDS.keys():
		if not _made.has(sound):
			_made[sound] = make(sound)
			if not is_inside_tree():
				return
			await get_tree().process_frame
	if not is_inside_tree():
		return
	for layer in LOOPS:
		var player := AudioStreamPlayer.new()
		player.name = "Loop_" + str(layer)
		player.stream = _made[layer]
		player.bus = BUS
		player.volume_db = -80.0
		add_child(player)
		player.play(randf() * LOOP_SECONDS * 0.8)  # so layers don't all start at the same spot
		_loops[layer] = player
		_level[layer] = 0.0
	_built = true


# --- Making the sounds ------------------------------------------------------------------

## One sound, made from scratch.
static func make(sound: String) -> AudioStreamWAV:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(sound)
	var n := roundi((LOOP_SECONDS + CROSSFADE_SECONDS) * RATE)
	match sound:
		"hum":
			var hum := _low(_low(_brown(n, rng), 140.0), 140.0)
			for i in n:
				hum[i] *= 0.8 + 0.2 * sin(TAU * 2.0 * i / (LOOP_SECONDS * RATE))
			return _finish(hum, true)
		"drizzle":
			var drops := _drops(n, rng, 30.0 * LOOP_SECONDS, 80, 0.3)
			return _finish(_mix(_high(drops, 2500.0), 1.0, _high(_white(n, rng), 1500.0), 0.12), true)
		"rain":
			var thumps := _low(_drops(n, rng, 260.0 * LOOP_SECONDS, 220, 0.2), 1200.0)
			var wash := _mix(_low(_white(n, rng), 2500.0), 0.6, _high(_white(n, rng), 500.0), 0.3)
			return _finish(_mix(thumps, 1.0, wash, 0.35), true)
		"wind":
			var body := _low(_brown(n, rng), 500.0)
			var gusts := _band(_white(n, rng), 300.0, 1200.0)
			var p1 := rng.randf() * TAU
			var p2 := rng.randf() * TAU
			var p3 := rng.randf() * TAU
			for i in n:
				var t := TAU * i / (LOOP_SECONDS * RATE)
				var swell := 0.5 + 0.5 * (0.5 * sin(t + p1) + 0.3 * sin(2.0 * t + p2) + 0.2 * sin(3.0 * t + p3))
				body[i] = body[i] * (0.35 + 0.65 * swell) + gusts[i] * swell * swell * 0.3
			return _finish(body, true)
		"simmer":  # a gentle, steady bubbling: lots of small, soft bubbles rather than a few pops
			var pot := _scale(_low(_brown(n, rng), 300.0), 0.6)
			var bubbles := PackedFloat32Array()
			bubbles.resize(n)
			for _bubble in roundi(20.0 * LOOP_SECONDS):
				var start := rng.randi_range(0, n - 2000)
				var f0 := rng.randf_range(150.0, 400.0)
				var length := roundi(rng.randf_range(0.03, 0.08) * RATE)
				var amp := rng.randf_range(0.1, 0.35)
				var phase := 0.0
				for j in length:
					var u := float(j) / length
					phase += TAU * f0 / RATE  # a steady pitch: rising ones sounded like a pour
					bubbles[start + j] += sin(phase) * pow(sin(PI * u), 2.0) * amp
			return _finish(_mix(pot, 1.0, _low(bubbles, 800.0), 1.0), true)
		"sizzle":
			var hiss := _high(_white(n, rng), 3500.0)
			var flicker := _low(_abs(_white(n, rng)), 15.0)
			var crackle := PackedFloat32Array()
			crackle.resize(n)
			for _crack in roundi(60.0 * LOOP_SECONDS):
				crackle[rng.randi_range(0, n - 1)] = rng.randf_range(-1.0, 1.0)
			crackle = _high(crackle, 2000.0)
			for i in n:
				hiss[i] = hiss[i] * 0.35 * (0.4 + 2.0 * flicker[i]) + crackle[i] * 0.8
			return _finish(hiss, true)
		"murmur":
			var room := PackedFloat32Array()
			room.resize(n)
			for _voice in 3:
				var low_hz := rng.randf_range(160.0, 320.0)
				var carrier := _band(_white(n, rng), low_hz, low_hz * 4.0)
				var envelope := _syllables(n, rng)
				for i in n:
					room[i] += carrier[i] * envelope[i]
			return _finish(room, true)
		"cicadas":
			var song := PackedFloat32Array()
			song.resize(n)
			for cicada in 2:
				var f := rng.randf_range(4000.0, 4600.0)
				var pulse := rng.randf_range(45.0, 60.0)
				var p := rng.randf() * TAU
				var swells := 1.0 + cicada
				for i in n:
					var t := float(i) / RATE
					var beat := pow(maxf(0.0, sin(TAU * pulse * t)), 4.0)
					var swell := 0.5 + 0.5 * sin(TAU * swells * i / (LOOP_SECONDS * RATE) + p)
					song[i] += sin(TAU * f * t) * beat * swell * swell
			return _finish(song, true)
		"car", "truck":
			var truck := sound == "truck"
			var m := roundi((4.0 if truck else 2.8) * RATE)
			var rumble := _low(_brown(m, rng), 120.0 if truck else 220.0)
			var whoosh := _band(_white(m, rng), 400.0, 1500.0)
			var engine := 0.0
			for i in m:
				var u := float(i) / m
				var envelope := pow(sin(PI * u), 2.0)
				if truck:
					engine = 0.0
					for h in range(1, 5):
						engine += sin(TAU * 45.0 * h * i / RATE) / h
				rumble[i] = rumble[i] * envelope * 0.8 + whoosh[i] * pow(envelope, 3.0) * 0.5 + engine * envelope * 0.15
			return _finish(rumble, false)
		"scooter":
			var m := roundi(3.5 * RATE)
			var buzz := PackedFloat32Array()
			buzz.resize(m)
			var phase := 0.0
			for i in m:
				var u := float(i) / m
				var f := 105.0 * (1.0 - 0.07 * tanh((u - 0.5) * 6.0))  # higher coming, lower going
				phase += TAU * f / RATE
				var saw := 0.0
				for h in range(1, 11):
					saw += sin(phase * h) / h
				var throb := 0.8 + 0.2 * sin(TAU * 22.0 * i / RATE)
				buzz[i] = saw * throb * pow(sin(PI * u), 1.5)
			return _finish(_low(buzz, 1800.0), false)
		"subway":
			var m := roundi(5.0 * RATE)
			var deep := _low(_brown(m, rng), 90.0)
			var rattle := _band(_white(m, rng), 200.0, 800.0)
			for i in m:
				var envelope := pow(sin(PI * float(i) / m), 2.0)
				var clack := pow(0.5 + 0.5 * sin(TAU * 9.0 * i / RATE), 2.0)
				deep[i] = deep[i] * envelope + rattle[i] * envelope * clack * 0.3
			return _finish(deep, false)
		"clink":
			var m := roundi(0.6 * RATE)
			var glass := PackedFloat32Array()
			glass.resize(m)
			for hit in [[0.0, 1.0], [0.09, 0.4]]:  # glasses touch twice
				var start := roundi(float(hit[0]) * RATE)
				var partials := [[2950.0, 1.0], [4420.0, 0.6], [6280.0, 0.35], [8150.0, 0.2]]
				for k in partials.size():
					for i in range(start, m):
						var t := float(i - start) / RATE
						glass[i] += sin(TAU * float(partials[k][0]) * t) * float(partials[k][1]) * float(hit[1]) * exp(-t * (8.0 + k * 4.0))
			return _finish(glass, false)
		"pour":  # mostly the splash of liquid into a glass, with only a hint of glug
			var m := roundi(0.8 * RATE)
			var splash := _band(_white(m, rng), 700.0, 3000.0)
			var pour := PackedFloat32Array()
			pour.resize(m)
			for i in m:
				var u := float(i) / m
				var t := float(i) / RATE
				var glug := 0.7 + 0.3 * sin(TAU * 6.0 * t)
				var envelope := minf(1.0, u / 0.08) * minf(1.0, (1.0 - u) / 0.3)
				pour[i] = splash[i] * glug * envelope
			return _finish(pour, false)
		"scrape":
			var m := roundi(0.4 * RATE)
			var rub := _band(_white(m, rng), 400.0, 2500.0)
			var phase := 0.0
			for i in m:
				var u := float(i) / m
				phase += TAU * (70.0 + rng.randf_range(-15.0, 15.0)) / RATE
				var grip := pow(maxf(0.0, sin(phase)), 2.0)  # plastic legs sticking and slipping
				rub[i] = (rub[i] * (0.4 + grip) + sin(phase * 3.0) * grip * 0.3) * sin(PI * u)
			return _finish(rub, false)
		"cash":
			var m := roundi(0.7 * RATE)
			var tin := PackedFloat32Array()
			tin.resize(m)
			var level := 1.0
			for drop_at in [0.0, 0.06, 0.13, 0.21, 0.3]:  # coins dropping into the tin
				var start := roundi(float(drop_at) * RATE)
				for _coin in 3:
					var f := rng.randf_range(1500.0, 5000.0)
					for i in range(start, m):
						var t := float(i - start) / RATE
						tin[i] += sin(TAU * f * t) * exp(-t * 25.0) * level * 0.5
				for i in range(start, mini(start + 66, m)):
					tin[i] += rng.randf_range(-1.0, 1.0) * level * 0.4
				level *= 0.7
			return _finish(tin, false)
		"meow":
			var m := roundi(0.75 * RATE)
			var cry := PackedFloat32Array()
			cry.resize(m)
			var phase := 0.0
			for i in m:
				var u := float(i) / m
				var f := 480.0 + 380.0 * pow(sin(PI * u), 0.8) - 120.0 * u + 8.0 * sin(TAU * 6.0 * u)
				phase += TAU * f / RATE
				var openness := pow(sin(PI * u), 0.6)  # "m" closed, "eow" open
				var formant := 700.0 + 900.0 * openness
				var voice := 0.0
				for h in range(1, 11):
					var weight := exp(-pow((h * f - formant) / 600.0, 2.0)) + 0.3 / h
					voice += sin(phase * h) * weight
				cry[i] = voice * minf(1.0, u / 0.06) * pow(maxf(0.0, sin(PI * minf(1.0, u * 1.05))), 0.5)
			return _finish(cry, false)
	return _finish(PackedFloat32Array([0.0, 0.0]), false)


static func _white(n: int, rng: RandomNumberGenerator) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(n)
	for i in n:
		out[i] = rng.randf_range(-1.0, 1.0)
	return out


## Deep, rumbly noise.
static func _brown(n: int, rng: RandomNumberGenerator) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(n)
	var y := 0.0
	for i in n:
		y = y * 0.995 + rng.randf_range(-1.0, 1.0) * 0.05
		out[i] = y
	return out


static func _low(x: PackedFloat32Array, hz: float) -> PackedFloat32Array:
	var a := exp(-TAU * hz / RATE)
	var out := PackedFloat32Array()
	out.resize(x.size())
	var y := 0.0
	for i in x.size():
		y = (1.0 - a) * x[i] + a * y
		out[i] = y
	return out


static func _high(x: PackedFloat32Array, hz: float) -> PackedFloat32Array:
	var low := _low(x, hz)
	for i in x.size():
		low[i] = x[i] - low[i]
	return low


static func _band(x: PackedFloat32Array, low_hz: float, high_hz: float) -> PackedFloat32Array:
	return _low(_high(x, low_hz), high_hz)


static func _abs(x: PackedFloat32Array) -> PackedFloat32Array:
	for i in x.size():
		x[i] = absf(x[i])
	return x


static func _scale(x: PackedFloat32Array, by: float) -> PackedFloat32Array:
	for i in x.size():
		x[i] *= by
	return x


static func _mix(a: PackedFloat32Array, a_level: float, b: PackedFloat32Array, b_level: float) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(a.size())
	for i in a.size():
		out[i] = a[i] * a_level + b[i] * b_level
	return out


## Little bursts of noise at random (raindrops): count of them, each length samples long.
static func _drops(n: int, rng: RandomNumberGenerator, count: float, length: int, quiet: float) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(n)
	for _drop in roundi(count):
		var start := rng.randi_range(0, n - length - 1)
		var amp := rng.randf_range(quiet, 1.0)
		for j in length:
			out[start + j] += rng.randf_range(-1.0, 1.0) * amp * exp(-4.0 * j / length)
	return out


## A talking voice's loudness over time: syllables, little gaps, and pauses between phrases.
static func _syllables(n: int, rng: RandomNumberGenerator) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(n)
	var at := rng.randi_range(0, roundi(RATE * 0.5))
	while at < n:
		if rng.randf() < 0.15:
			at += roundi(rng.randf_range(0.4, 1.2) * RATE)  # a pause
			continue
		var length := roundi(rng.randf_range(0.08, 0.25) * RATE)
		var amp := rng.randf_range(0.5, 1.0)
		for j in length:
			if at + j < n:
				out[at + j] = amp * pow(sin(PI * j / length), 2.0)
		at += length + roundi(rng.randf_range(0.02, 0.08) * RATE)
	return out


## Into a playable sound: loops get their end faded into their start so they join up
## without a click, and everything's brought to the same peak.
static func _finish(x: PackedFloat32Array, loop: bool) -> AudioStreamWAV:
	if loop:
		var fade := roundi(CROSSFADE_SECONDS * RATE)
		var length := x.size() - fade
		for i in fade:
			var t := float(i) / fade
			x[i] = x[i] * t + x[length + i] * (1.0 - t)
		x.resize(length)
	var peak := 0.0001
	for v in x:
		peak = maxf(peak, absf(v))
	var data := PackedByteArray()
	data.resize(x.size() * 2)
	for i in x.size():
		data.encode_s16(i * 2, clampi(roundi(x[i] / peak * 0.9 * 32767.0), -32768, 32767))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = RATE
	stream.stereo = false
	stream.data = data
	if loop:
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		stream.loop_begin = 0
		stream.loop_end = x.size()
	return stream
