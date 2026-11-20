extends Node
## The street's finish (ART.md, "The street"), drawn in code on the street's pixel grid
## (street_art.gd, each pixel 3 on screen): the sodium lamps hung under the overpass's deck and
## the power cables strung across the street; the stars and the moon, where the sky shows
## (more stars as the night gets darker, none through cloud, rain, snow or fog; the moon in
## its phase for tonight's date, crossing the sky through the night); and on a wet night the
## road reflecting what's bright (the tent's glow, the lamps, the neon), broken into ripples
## that never sit still. The lamps and the neon light what's round them (pixel_light.gd
## set_lamps). The bar's own dice (its id) place the stars, so a bar's sky is its own.

const PixelLight = preload("res://scripts/ui/pixel_light.gd")
const DebugLog = preload("res://scripts/debug_log.gd")
const PeopleArt = preload("res://scripts/ui/people_art.gd")
const StreetArt = preload("res://scripts/bar/street_art.gd")

const DECK := 38  # the overpass deck's underside, on the street's grid (both overpasses')
const LAMP_XS := [24, 128, 232, 336, 440, 544, 604]  # the lamps along it (most behind the tarp: their light still shows)
const SODIUM := Color("ffb347")
const HOUSING := Color("2a2833")
const LAMP_STEPS := 0.9  # a lamp's light on the street, in steps, at the lamp
const LAMP_REACH := 300.0  # stage pixels
const NEON_STEPS := 0.6
const NEON_REACH := 170.0
const NEON_AT := Vector2(-24, 165)  # the neon's middle, from the stage's right edge (scenery.gd's board)
const CABLE := Color("17151f")
const CABLES := [[44.0, 7.0], [50.0, 5.0]]  # each strung across the street: where it's fixed (grid row) and how far it sags
const STARS_MOST := 40  # on the clearest, darkest night (a city sky: not many)
const SKY_ROWS := 64  # where stars can be (behind everything: they show where the sky does)
const CLOUDY := ["drizzle", "rain", "snow", "fog"]  # no stars or moon through these
const NEW_MOON_DAY := 17  # a day of the year with a new moon (18 January)
const LUNAR_MONTH := 29.53
const MOON_SIZE := 9
const MOON_ROW := 4  # its top, on the grid (it shows where the sky does above the deck)
const ROAD := Vector2(0, 372)  # the wet road on the stage: its top (the layer goes here), two rows of the grid
const ROAD_ROWS := 2
const RIPPLE_SECONDS := 0.22

var stage_width := 1872.0
var weather := ""
var stars_shown := 0  # (for the tests and the stats)
var moon_phase := 0.0  # 0 new, 0.5 full
var moon_shown := false
var reflecting := false
var lamps: Array = []  # the lamps drawn (TextureRects on the grid)
var _star_spots: Array = []  # [x, y, how soon it comes out (0..1), twinkles]
var _stars: TextureRect
var _moon: TextureRect
var _cables: TextureRect
var _reflections: TextureRect
var _minutes := 18.0 * 60
var _ripple := 0.0
var _twinkle := 0.0
var _dice := RandomNumberGenerator.new()  # (the scenery's own: the game's rolls never shift)


## The moon's phase on a day of the year: 0 (new) to 1, a full moon at 0.5.
static func phase(day_of_year: int) -> float:
	return fposmod((day_of_year - NEW_MOON_DAY) / LUNAR_MONTH, 1.0)


## The phase in words (for the log and the stats).
static func phase_name(moon: float) -> String:
	var names := ["new", "waxing crescent", "first quarter", "waxing gibbous", "full", "waning gibbous", "last quarter", "waning crescent"]
	return names[int(fposmod(moon * 8.0 + 0.5, 8.0))]


## How many of the stars are out: fewer at dusk, all of them once it's dark; none through cloud.
static func stars_out(minutes: float, weather_kind: String) -> float:
	if weather_kind in CLOUDY:
		return 0.0
	var dark := clampf((minutes - 18.0 * 60) / 150.0, 0.15, 1.0)
	return dark * (0.6 if weather_kind == "muggy" else (1.0 if weather_kind == "cold" else 0.85))


## Builds it all on the street's grid (its sky: street_art.gd), and the reflections on the
## road (a layer on the stage, where the road is), for this bar (its id).
func build(street: StreetArt, road: Control, bar_id: String) -> void:
	var grid_sky: Control = street.sky
	var overpass: Control = null
	for piece in street.pieces:
		if str(piece.name).contains("overpass"):
			overpass = piece
	for node in [_stars, _moon, _cables, _reflections]:
		if is_instance_valid(node):
			node.queue_free()
	for lamp in lamps:
		lamp.queue_free()
	lamps = []
	var bar_dice := RandomNumberGenerator.new()
	bar_dice.seed = hash("stars " + bar_id)
	_star_spots = []
	for k in STARS_MOST:
		_star_spots.append([bar_dice.randi_range(2, 621), bar_dice.randi_range(0, SKY_ROWS), bar_dice.randf(), bar_dice.randf() < 0.3])
	var pixels: Vector2i = StreetArt.PIXELS
	_stars = _sprite(Image.create(pixels.x, SKY_ROWS + 1, false, Image.FORMAT_RGBA8), "Stars")
	grid_sky.add_child(_stars)
	grid_sky.move_child(_stars, 0)  # (behind every building)
	_moon = _sprite(_moon_image(0.5), "Moon")
	grid_sky.add_child(_moon)
	grid_sky.move_child(_moon, 1)
	# The lamps, just in front of the overpass they hang from (behind the buildings nearer us).
	for x in LAMP_XS:
		var lamp := _sprite(_lamp_image(), "Lamp")
		lamp.position = Vector2(x - 2, DECK)
		grid_sky.add_child(lamp, true)
		if overpass != null:
			grid_sky.move_child(lamp, overpass.get_index() + 1)
		lamps.append(lamp)
	_cables = _sprite(_cables_image(pixels.x), "Cables")
	grid_sky.add_child(_cables)  # (in front of everything on the street)
	_reflections = TextureRect.new()
	_reflections.name = "Reflections"
	_reflections.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_reflections.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_reflections.stretch_mode = TextureRect.STRETCH_SCALE
	_reflections.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage_width = road.size.x if road.size.x > 0.0 else stage_width
	_reflections.position = Vector2.ZERO
	_reflections.size = Vector2(stage_width, ROAD_ROWS * PixelLight.GRID)
	road.add_child(_reflections)
	var street_lamps: Array = LAMP_XS.map(func(x): return Vector4(x * 3.0, (DECK + 3) * 3.0 - 81.0, LAMP_STEPS, LAMP_REACH))
	street_lamps.append(Vector4(stage_width + NEON_AT.x, NEON_AT.y, NEON_STEPS, NEON_REACH))
	PixelLight.set_lamps(street_lamps)


## Tonight: its date (the moon's phase) and weather.
func tonight(day_of_year: int, weather_kind: String) -> void:
	weather = weather_kind
	moon_phase = phase(day_of_year)
	if is_instance_valid(_moon):
		_moon.texture = ImageTexture.create_from_image(_moon_image(moon_phase))
	reflecting = weather_kind in ["drizzle", "rain"]
	_draw_stars(true)
	set_minutes(_minutes)
	DebugLog.say("Street", "%d lamps · stars %d · the moon %s%s · the road %s" % [lamps.size(), stars_shown, phase_name(moon_phase),
		"" if moon_shown else " (hidden)", "wet, reflecting" if reflecting else "dry"])


## Tonight's street, for the night's stats.
func summary() -> Dictionary:
	return {"lamps": lamps.size(), "stars": stars_shown, "moon": phase_name(moon_phase) if moon_shown else "hidden", "road": "wet" if reflecting else "dry"}


## The hour: the stars come out, the moon crosses the sky (east to west, right to left).
func set_minutes(minutes: float) -> void:
	_minutes = minutes
	if not is_instance_valid(_moon):
		return
	var t := clampf((minutes - 18.0 * 60) / (9.0 * 60), 0.0, 1.0)
	_moon.position = Vector2(roundf(lerpf(560.0, 60.0, t)), MOON_ROW)
	moon_shown = not (weather in CLOUDY) and moon_phase > 0.04 and moon_phase < 0.96
	_moon.visible = moon_shown


func _process(delta: float) -> void:
	_twinkle += delta
	if _twinkle >= 0.7:
		_twinkle = 0.0
		_draw_stars(false)
	if not is_instance_valid(_reflections):
		return
	_reflections.visible = reflecting
	if reflecting:
		_ripple += delta
		if _ripple >= RIPPLE_SECONDS or _reflections.texture == null:
			_ripple = 0.0
			_reflections.texture = ImageTexture.create_from_image(_road_image())


## The stars out now (some twinkling: dimmer now and then).
func _draw_stars(_new_night: bool) -> void:
	if not is_instance_valid(_stars):
		return
	var out := stars_out(_minutes, weather)
	var image := Image.create(_stars.texture.get_width(), _stars.texture.get_height(), false, Image.FORMAT_RGBA8)
	stars_shown = 0
	for star in _star_spots:
		if float(star[2]) >= out:
			continue
		var dim: bool = bool(star[3]) and _dice.randf() < 0.4
		image.set_pixel(int(star[0]), int(star[1]), Color(0.92, 0.93, 1.0, 0.45 if dim else 0.9))
		stars_shown += 1
	_stars.texture = ImageTexture.create_from_image(image)


## A sodium lamp: a short stem, its housing, the orange glass underneath (glowing by itself).
func _lamp_image() -> Image:
	var image := Image.create(5, 4, false, Image.FORMAT_RGBA8)
	for y in 2:
		image.set_pixel(2, y, HOUSING)
	for x in 5:
		image.set_pixel(x, 2, HOUSING)
	for x in range(1, 4):
		image.set_pixel(x, 3, SODIUM)
	return image


## Power cables strung across the street, sagging between where they're fixed.
func _cables_image(width: int) -> Image:
	var image := Image.create(width, 64, false, Image.FORMAT_RGBA8)
	for cable in CABLES:
		var span := 156.0  # between poles
		for x in width:
			var t := fposmod(x, span) / span
			var y := int(roundf(float(cable[0]) + float(cable[1]) * 4.0 * t * (1.0 - t)))
			if y >= 0 and y < 64:
				image.set_pixel(x, y, CABLE)
	return image


## The moon in its phase: a disc lit on the right as it waxes, on the left as it wanes, on its
## light ramp (a darker edge), the dark part not drawn.
func _moon_image(moon: float) -> Image:
	var image := Image.create(MOON_SIZE, MOON_SIZE, false, Image.FORMAT_RGBA8)
	var ramp: Array = PeopleArt.ramp(Color("e8e4cf"))
	var r := MOON_SIZE / 2.0
	var lit := cos(moon * TAU)  # 1 new .. -1 full: where the terminator crosses
	for y in MOON_SIZE:
		for x in MOON_SIZE:
			var dx := (x + 0.5 - r) / r
			var dy := (y + 0.5 - r) / r
			if dx * dx + dy * dy > 1.0:
				continue
			var half := sqrt(maxf(0.0, 1.0 - dy * dy))
			var edge := lit * half  # the terminator's x on this row
			var on := dx > edge if moon < 0.5 else dx < -edge
			if not on:
				continue
			var rim := dx * dx + dy * dy > 0.6
			image.set_pixel(x, y, ramp[4 if rim else 5])
	return image


## The wet road: under each bright thing, its colour in broken dashes, moving every moment.
func _road_image() -> Image:
	var width := int(stage_width / PixelLight.GRID)
	var image := Image.create(width, ROAD_ROWS, false, Image.FORMAT_RGBA8)
	var sources: Array = [[40, width - 40, Color(0.95, 0.62, 0.3, 0.5)]]  # the tent's glow
	for x in LAMP_XS:
		sources.append([x - 4, x + 4, Color(1.0, 0.7, 0.3, 0.65)])
	sources.append([width - 12, width - 4, Color(1.0, 0.37, 0.64, 0.8)])  # the neon
	for source in sources:
		for y in ROAD_ROWS:
			var x := int(source[0])
			while x < int(source[1]):
				var dash := _dice.randi_range(1, 4)
				if _dice.randf() < 0.55:
					for k in dash:
						if x + k < width:
							var colour: Color = source[2]
							image.set_pixel(x + k, y, Color(colour, colour.a * (1.0 if y == 0 else 0.6)))
				x += dash + _dice.randi_range(1, 3)
	return image


func _sprite(image: Image, node_name: String) -> TextureRect:
	var sprite := TextureRect.new()
	sprite.name = node_name
	sprite.texture = ImageTexture.create_from_image(image)
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sprite.size = image.get_size()
	return sprite
