class_name Music
extends Node
## Background music: Arirang (the traditional Korean folk song, in the public domain), played
## now and then through the night on a gayageum-like plucked string over a soft drone, made
## in code like the other sounds (a placeholder until a real arrangement). It starts with the
## title screen and carries on from scene to scene (Game keeps it), playing, then leaving a
## quiet spell, so it isn't wall-to-wall music.

const BUS := "Music"
const RATE := 22050
const TEMPO := 66.0  # beats a minute, three to a bar
const DO := 392.0  # G4: "1" in the tune
const GAP := Vector2(20.0, 60.0)  # real seconds of quiet between plays

## Arirang in numbered notation: 1 2 3 5 6 are do re mi sol la, "l5" and "l6" the low sol
## and la; each note with its length in beats (3/4 time, four lines of four bars).
const ARIRANG := [
	["l5", 1.5], ["l6", 0.5], ["l5", 1.0], ["1", 1.5], ["2", 0.5], ["1", 1.0],
	["2", 1.0], ["3", 0.5], ["2", 0.5], ["1", 0.5], ["l6", 0.5], ["1", 1.5], ["l6", 0.5], ["l5", 1.0],
	["l5", 1.5], ["l6", 0.5], ["l5", 1.0], ["1", 1.5], ["2", 0.5], ["1", 0.5], ["2", 0.5],
	["3", 0.5], ["2", 0.5], ["1", 0.5], ["l6", 0.5], ["l5", 0.5], ["l6", 0.5], ["1", 3.0],
	["3", 1.5], ["3", 0.5], ["3", 1.0], ["3", 1.0], ["2", 1.0], ["1", 1.0],
	["2", 1.0], ["3", 0.5], ["2", 0.5], ["1", 0.5], ["l6", 0.5], ["1", 1.5], ["l6", 0.5], ["l5", 1.0],
	["l5", 1.5], ["l6", 0.5], ["l5", 1.0], ["1", 1.5], ["2", 0.5], ["1", 0.5], ["2", 0.5],
	["3", 0.5], ["2", 0.5], ["1", 0.5], ["l6", 0.5], ["l5", 0.5], ["l6", 0.5], ["1", 3.0],
]
const SEMITONES := {"l5": -5, "l6": -3, "1": 0, "2": 2, "3": 4, "5": 7, "6": 9}

static var _tune: AudioStreamWAV = null  # made once per run, on a worker thread
static var _task := -1

var volume := 0.5  # the Music slider, 0 to 1
var enabled := true  # the Music tick box
var _player: AudioStreamPlayer
var _wait := 0.0  # straight away the first time, as soon as it's made


func _ready() -> void:
	volume = load_volume()
	enabled = load_enabled()
	if not Ambience.make_sound:
		return
	_bus()
	_apply_volume()
	_player = AudioStreamPlayer.new()
	_player.bus = BUS
	add_child(_player)
	if _tune == null and _task == -1:
		_task = WorkerThreadPool.add_task(func(): _tune = make_tune())


## The Music slider (0 is off), remembered for next time.
func set_volume(level: float) -> void:
	volume = clampf(level, 0.0, 1.0)
	_apply_volume()
	var settings := ConfigFile.new()
	settings.load(Ambience.settings_path)
	settings.set_value("music", "volume", volume)
	settings.save(Ambience.settings_path)


## The Music tick box: on or off (the volume's kept for when it's back on), remembered.
func set_enabled(on: bool) -> void:
	enabled = on
	_apply_volume()
	var settings := ConfigFile.new()
	settings.load(Ambience.settings_path)
	settings.set_value("music", "on", on)
	settings.save(Ambience.settings_path)


static func load_enabled() -> bool:
	var settings := ConfigFile.new()
	if settings.load(Ambience.settings_path) != OK:
		return true  # on by default
	return bool(settings.get_value("music", "on", true))


static func load_volume() -> float:
	var settings := ConfigFile.new()
	if settings.load(Ambience.settings_path) != OK:
		return 0.5
	return clampf(float(settings.get_value("music", "volume", 0.5)), 0.0, 1.0)


func _apply_volume() -> void:
	if not Ambience.make_sound:
		return
	AudioServer.set_bus_mute(_bus(), not enabled or volume <= 0.0)
	AudioServer.set_bus_volume_db(_bus(), linear_to_db(maxf(volume, 0.001)) - 12.0)


func _process(delta: float) -> void:
	if _task != -1 and _tune != null:  # (the tune's made: tidy its task up, once, whichever player sees it first)
		var task := _task
		_task = -1
		WorkerThreadPool.wait_for_task_completion(task)
	if _player == null or _tune == null or _player.playing:
		return
	_wait -= delta
	if _wait <= 0.0:
		_player.stream = _tune
		_player.pitch_scale = [1.0, 1.0, 0.944].pick_random()  # now and then a little lower and slower
		_player.play()
		_wait = randf_range(GAP.x, GAP.y)


## The tune as one sound: the melody twice, plucked, with a low string on each bar's first
## beat and a soft drone underneath (coming in on the second time through).
static func make_tune() -> AudioStreamWAV:
	var beat := 60.0 / TEMPO
	var beats := 0.0
	for note in ARIRANG:
		beats += float(note[1])
	var n := roundi((beats * 2.0 * beat + 4.0) * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	var at := 0.0
	for _time_through in 2:
		var bar_beat := 0.0
		for note in ARIRANG:
			var f := DO * pow(2.0, float(SEMITONES[note[0]]) / 12.0)
			_pluck(out, roundi(at * beat * RATE), f, 0.5, 2.2)
			if is_zero_approx(fmod(bar_beat, 3.0)):  # the first beat of a bar
				_pluck(out, roundi(at * beat * RATE), DO / 4.0, 0.22, 2.6)
			at += float(note[1])
			bar_beat += float(note[1])
	var drone_from := roundi(beats * beat * RATE)
	for i in range(drone_from - RATE, n):  # the drone, fading in just before the second time
		var t := float(i) / RATE
		var level := clampf(float(i - drone_from + RATE) / (3.0 * RATE), 0.0, 1.0) * clampf(float(n - i) / (3.0 * RATE), 0.0, 1.0)
		var swell := 0.75 + 0.25 * sin(TAU * 0.15 * t)
		out[i] += (sin(TAU * DO / 4.0 * t) + 0.6 * sin(TAU * DO * 0.375 * t)) * 0.06 * level * swell
	var peak := 0.0001
	for v in out:
		peak = maxf(peak, absf(v))
	var data := PackedByteArray()
	data.resize(n * 2)
	for i in n:
		data.encode_s16(i * 2, clampi(roundi(out[i] / peak * 0.8 * 32767.0), -32768, 32767))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = RATE
	stream.stereo = false
	stream.data = data
	return stream


## A plucked string, a bit like a gayageum: a bright attack that mellows, and a slow vibrato
## that deepens as the note rings (the player pressing the string behind the bridge).
static func _pluck(out: PackedFloat32Array, start: int, f: float, amp: float, ring: float) -> void:
	var length := mini(roundi(ring * RATE), out.size() - start)
	var phase := 0.0
	# Each harmonic dies away at its own rate: multiplied down a little every sample.
	var d1 := exp(-2.2 / RATE)
	var d2 := exp(-4.0 / RATE)
	var d3 := exp(-7.0 / RATE)
	var e1 := amp
	var e2 := amp * 0.5
	var e3 := amp * 0.25
	var step := TAU * f / RATE
	for j in length:
		var bend := 1.0 + 0.006 * sin(TAU * 5.0 * j / RATE) * minf(1.0, j / (0.6 * RATE))
		phase += step * bend
		out[start + j] += (sin(phase) * e1 + sin(phase * 2.0) * e2 + sin(phase * 3.0) * e3) * minf(1.0, j / 40.0)
		e1 *= d1
		e2 *= d2
		e3 *= d3


static func _bus() -> int:
	var index := AudioServer.get_bus_index(BUS)
	if index == -1:
		AudioServer.add_bus()
		index = AudioServer.bus_count - 1
		AudioServer.set_bus_name(index, BUS)
		AudioServer.set_bus_send(index, "Master")
		var room := AudioEffectReverb.new()  # a little room around it, as if from a radio across the street
		room.room_size = 0.5
		room.wet = 0.25
		AudioServer.add_bus_effect(index, room)
	return index
