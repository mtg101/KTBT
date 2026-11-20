extends RefCounted
## The light by the hour, on the pixels themselves (ART.md, "Lighting by palette"): a small
## shader on every piece of pixel art (the street's, the tent's, the people's) moves each pixel
## up or down its own colour's light ramp (darker is bluer, lighter warmer: the palette's ramp()
## sums), smoothly: a blend between the whole steps either side of the light there. No dither
## (20 Nov: a dither fixed to the grid slid across people as they walked, their coats sparkling
## with the tarp's pattern behind them), so the light fades evenly and moves with whoever's in it.
## How far a pixel moves is the light where it is, in steps: the night's own (AMBIENT: dusk at
## 6pm, darkest after midnight, a little less towards dawn) plus the bulbs' (each lights what's
## round it, fading out with distance, and brightest in a pool close round it (the glow round a
## bulb on the tarp, the counter and whoever's under it: drawn into the tent's art until 20 Nov,
## now the light's, so the people and the tent are lit alike); the tarp holds their light in,
## so the street behind hardly feels them) plus the street's own lamps' (the sodium lamps under the overpass, the
## neon: they light whatever's round them, the street, the tent's outside, people out front).
## Under the bulbs the tent looks as drawn; out by its ends and in the street it's the night's.
## What glows by itself (a lit window, the neon, a bulb that's on) keeps its own light; the
## tarp doesn't (the bulb does the work and the tarp glows dim: ART.md, the lighting rules),
## so its glow fades with the night. Lights are data: tent_view.gd sets the night and the
## bulbs each frame, from the hour, the weather and which bulbs are on; street_lights.gd the
## lamps, once a night.
## Every piece shares one material for each KIND (its own way into the stage's coordinates),
## so a frame's light is set once, on a few materials.

const GRID := 3.0  # screen pixels to a pixel of the art
## The night's own light, in steps of the ramp below the art as drawn: [game minutes, steps].
const AMBIENT := [[18 * 60, -0.4], [19 * 60 + 30, -0.9], [21 * 60, -1.4], [24 * 60, -1.7], [26 * 60, -1.9], [27 * 60, -1.6]]
const WEATHER := {"fog": 0.2, "rain": -0.2, "drizzle": -0.1, "snow": 0.2}  # (fog and snow throw the light about)
const BULB_STEPS := 1.25  # a bulb that's on, at the bulb (falling off to nothing at BULB_REACH)
const BULB_REACH := 1000.0  # stage pixels
const POOL_STEPS := 0.8  # ...and brighter close round it: this much more at the bulb,
const POOL_REACH := 450.0  # falling off (squared) to nothing this far away
const BRIGHTEST := 0.25  # nothing lit more than this above how it's drawn
const MAX_BULBS := 4
## Each kind of art: how much the bulbs light it (the tarp keeps their light off the street; the
## cover itself catches some of it, glowing dim).
const KINDS := {"street": 0.15, "tent": 1.0, "people": 1.0, "tarp": 0.45}
const NOT_SELF_LIT := ["tarp"]  # kinds whose bright colours don't keep their own light (a lit tarp's orange is the bulbs')
const MAX_LAMPS := 8
## A step of the ramp, as in tools/art/palette.py ramp(): down, darker by this and bluer;
## up, lighter by this (of what's left) and warmer.
const DOWN_VALUE := 0.72
const UP_VALUE := 0.35
const BLUE_HUE := 0.64
const WARM_HUE := 0.11

const SHADER := """
shader_type canvas_item;
// The light by the hour on a piece of pixel art: scripts/ui/pixel_light.gd says how.
uniform vec2 to_stage_scale = vec2(1.0);
uniform vec2 to_stage_offset = vec2(0.0);
uniform float ambient = 0.0;
uniform float lit_by_bulbs = 1.0;
uniform float self_lit = 1.0;  // whether what's bright and coloured keeps its own light
uniform vec4 bulbs[4];  // x, y (on the stage), strength in steps, reach
uniform vec4 lamps[8];  // the street's: the same, lighting every kind
uniform float brightest = 0.25;
uniform float bulb_steps = 1.25;  // a bulb that's on: its pool is in proportion
uniform float pool_steps = 0.8;
uniform float pool_reach = 450.0;
uniform float down_value = 0.72;
uniform float up_value = 0.35;
uniform float blue_hue = 0.64;
uniform float warm_hue = 0.11;
varying vec2 stage_at;


void vertex() {
	stage_at = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy * to_stage_scale + to_stage_offset;
}

vec3 to_hsv(vec3 c) {
	vec4 K = vec4(0.0, -1.0 / 3.0, 2.0 / 3.0, -1.0);
	vec4 p = mix(vec4(c.bg, K.wz), vec4(c.gb, K.xy), step(c.b, c.g));
	vec4 q = mix(vec4(p.xyw, c.r), vec4(c.r, p.yzx), step(p.x, c.r));
	float d = q.x - min(q.w, q.y);
	return vec3(abs(q.z + (q.w - q.y) / (6.0 * d + 1e-10)), d / (q.x + 1e-10), q.x);
}

vec3 to_rgb(vec3 c) {
	vec3 p = abs(fract(c.xxx + vec3(1.0, 2.0 / 3.0, 1.0 / 3.0)) * 6.0 - 3.0);
	return c.z * mix(vec3(1.0), clamp(p - 1.0, 0.0, 1.0), c.y);
}

float towards(float hue, float to, float share) {
	return fract(hue + (fract(to - hue + 0.5) - 0.5) * share);
}

// One step along a colour's ramp: down darker and bluer, up lighter and warmer.
vec3 one_step(vec3 from, float dir) {
	vec3 hsv = from;
	if (dir < 0.0) {
		hsv.z = hsv.z * down_value;
		hsv.x = towards(hsv.x, blue_hue, 0.06);
		hsv.y = min(1.0, hsv.y * 1.04);
	} else {
		hsv.z = hsv.z + (1.0 - hsv.z) * up_value;
		hsv.x = towards(hsv.x, warm_hue, 0.05);
		hsv.y = hsv.y * 0.94;
	}
	return hsv;
}

// A colour n whole steps along its ramp, from how it's drawn.
vec3 walk(vec3 from, int n) {
	vec3 hsv = from;
	for (int i = 0; i < 4; i++) {
		if (i < -n) {
			hsv = one_step(hsv, -1.0);
		} else if (i < n) {
			hsv = one_step(hsv, 1.0);
		}
	}
	return hsv;
}

void fragment() {
	vec4 c = texture(TEXTURE, UV) * COLOR;
	vec3 hsv = to_hsv(c.rgb);
	float light = 0.0;
	for (int i = 0; i < 4; i++) {
		vec4 b = bulbs[i];
		if (b.z > 0.0 && b.w > 0.0) {
			float d = distance(stage_at, b.xy);
			float pool = clamp(1.0 - d / pool_reach, 0.0, 1.0);
			light += b.z * clamp(1.0 - d / b.w, 0.0, 1.0) + b.z / bulb_steps * pool_steps * pool * pool;
		}
	}
	float lamp_light = 0.0;
	for (int i = 0; i < 8; i++) {
		vec4 l = lamps[i];
		if (l.z > 0.0 && l.w > 0.0) {
			lamp_light += l.z * clamp(1.0 - distance(stage_at, l.xy) / l.w, 0.0, 1.0);
		}
	}
	float steps = min(ambient + lit_by_bulbs * light + lamp_light, brightest);
	// What glows by itself (bright and coloured: a lit window, the neon) keeps its light.
	steps *= 1.0 - self_lit * smoothstep(0.78, 0.92, hsv.z) * smoothstep(0.3, 0.55, hsv.y);
	// Blended between the whole steps either side (each from how it's drawn, so a whole step
	// is the ramp's own and there's no jump as the light crosses one): smooth, no dither.
	float whole = floor(steps);
	vec3 below = to_rgb(walk(hsv, int(whole)));
	vec3 above = to_rgb(walk(hsv, int(whole) + 1));
	COLOR = vec4(mix(below, above, steps - whole), c.a);
}
"""

static var _shader: Shader
static var _materials := {}  # kind -> ShaderMaterial
static var ambient_steps := 0.0  # tonight's, now (for the tests and the log)
static var bulbs: Array = []  # Vector4s: x, y on the stage, strength in steps, reach
static var lamps: Array = []  # the street's lamps: the same


## The material for a kind of art ("street", "tent" or "people"), shared by all of that kind.
static func material(kind: String) -> ShaderMaterial:
	if not _materials.has(kind):
		if _shader == null:
			_shader = Shader.new()
			_shader.code = SHADER
		var made := ShaderMaterial.new()
		made.shader = _shader
		made.set_shader_parameter("lit_by_bulbs", float(KINDS.get(kind, 1.0)))
		made.set_shader_parameter("self_lit", 0.0 if kind in NOT_SELF_LIT else 1.0)
		made.set_shader_parameter("lamps", _packed(lamps, MAX_LAMPS))
		for name in ["brightest", "down_value", "up_value", "blue_hue", "warm_hue", "pool_steps", "pool_reach", "bulb_steps"]:
			made.set_shader_parameter(name, float({"brightest": BRIGHTEST, "down_value": DOWN_VALUE, "up_value": UP_VALUE,
				"blue_hue": BLUE_HUE, "warm_hue": WARM_HUE, "pool_steps": POOL_STEPS, "pool_reach": POOL_REACH, "bulb_steps": BULB_STEPS}[name]))
		_materials[kind] = made
	return _materials[kind]


## A piece of art, lit by the hour.
static func light(item: CanvasItem, kind: String) -> void:
	item.material = material(kind)


## How many pieces under this node are lit by the hour (for the night's stats).
static func count_lit(node: Node) -> int:
	var count := 1 if node is CanvasItem and (node as CanvasItem).material in _materials.values() else 0
	for child in node.get_children(true):
		count += count_lit(child)
	return count


## How a kind's pieces map onto the stage: stage = where they're drawn x scale + offset.
static func place_kind(kind: String, scale: float, offset: Vector2) -> void:
	material(kind).set_shader_parameter("to_stage_scale", Vector2(scale, scale))
	material(kind).set_shader_parameter("to_stage_offset", offset)


## The night's light now: its own (by the hour and the weather) and the bulbs' (on the stage,
## each its strength in steps: BULB_STEPS on, 0 off).
static func set_night(minutes: float, weather_kind: String, bulb_spots: Array, bulb_strengths: Array) -> void:
	ambient_steps = ambient(minutes, weather_kind)
	bulbs = []
	for i in mini(bulb_spots.size(), MAX_BULBS):
		var spot: Vector2 = bulb_spots[i]
		bulbs.append(Vector4(spot.x, spot.y, float(bulb_strengths[i]) if i < bulb_strengths.size() else BULB_STEPS, BULB_REACH))
	var packed: Array = bulbs.duplicate()
	while packed.size() < MAX_BULBS:
		packed.append(Vector4.ZERO)
	for kind in KINDS:
		material(kind).set_shader_parameter("ambient", ambient_steps)
		material(kind).set_shader_parameter("bulbs", packed)


## The street's lamps (each a Vector4: x, y on the stage, strength in steps, reach), lighting
## every kind of art round them: street_lights.gd, once a night.
static func set_lamps(street_lamps: Array) -> void:
	lamps = street_lamps.slice(0, MAX_LAMPS)
	for kind in KINDS:
		material(kind).set_shader_parameter("lamps", _packed(lamps, MAX_LAMPS))


static func _packed(lights: Array, size: int) -> Array:
	var packed: Array = lights.duplicate()
	while packed.size() < size:
		packed.append(Vector4.ZERO)
	return packed


## Every bulb off for now (the lights going out: tent_view.gd lights_out), the night's own light
## as it was.
static func bulbs_off() -> void:
	var packed: Array = []
	for bulb: Vector4 in bulbs:
		packed.append(Vector4(bulb.x, bulb.y, 0.0, bulb.w))
	bulbs = packed.duplicate()
	while packed.size() < MAX_BULBS:
		packed.append(Vector4.ZERO)
	for kind in KINDS:
		material(kind).set_shader_parameter("bulbs", packed)


## The night's own light at this time (and in this weather), in steps.
static func ambient(minutes: float, weather_kind: String = "") -> float:
	var steps: float = AMBIENT.back()[1]
	if minutes <= AMBIENT[0][0]:
		steps = AMBIENT[0][1]
	else:
		for i in range(1, AMBIENT.size()):
			if minutes <= AMBIENT[i][0]:
				var t: float = (minutes - AMBIENT[i - 1][0]) / float(AMBIENT[i][0] - AMBIENT[i - 1][0])
				steps = lerpf(AMBIENT[i - 1][1], AMBIENT[i][1], t)
				break
	return steps + float(WEATHER.get(weather_kind, 0.0))


## The light at a spot on the stage, in steps from how it's drawn (as the shader works it out):
## for the tests and the log.
static func light_at(spot: Vector2, kind: String = "tent") -> float:
	var from_bulbs := 0.0
	for bulb: Vector4 in bulbs:
		if bulb.z > 0.0 and bulb.w > 0.0:
			from_bulbs += bulb_light(bulb, spot)
	var from_lamps := 0.0
	for lamp: Vector4 in lamps:
		if lamp.z > 0.0 and lamp.w > 0.0:
			from_lamps += lamp.z * clampf(1.0 - spot.distance_to(Vector2(lamp.x, lamp.y)) / lamp.w, 0.0, 1.0)
	return minf(ambient_steps + float(KINDS.get(kind, 1.0)) * from_bulbs + from_lamps, BRIGHTEST)


## One bulb's light at a spot, in steps (as the shader works it out): its long reach, fading out
## with distance, and its pool close round it (in proportion to how bright it is: none when off).
static func bulb_light(bulb: Vector4, spot: Vector2) -> float:
	var d := spot.distance_to(Vector2(bulb.x, bulb.y))
	var pool := clampf(1.0 - d / POOL_REACH, 0.0, 1.0)
	return bulb.z * clampf(1.0 - d / bulb.w, 0.0, 1.0) + bulb.z / BULB_STEPS * POOL_STEPS * pool * pool


## A colour moved along its ramp as the shader does: a blend between the whole steps either
## side, each from how it's drawn (smooth: no dither, and no jump at a whole step). For the tests.
static func lit(colour: Color, steps: float) -> Color:
	var whole := floorf(steps)
	return shifted(colour, int(whole)).lerp(shifted(colour, int(whole) + 1), steps - whole)


## A colour moved whole steps along its ramp (as the shader does): for the tests.
static func shifted(colour: Color, steps: int) -> Color:
	var h := colour.h
	var s := colour.s
	var v := colour.v
	for i in absi(steps):
		if steps < 0:
			v *= DOWN_VALUE
			h = fposmod(h + (fposmod(BLUE_HUE - h + 0.5, 1.0) - 0.5) * 0.06, 1.0)
			s = minf(1.0, s * 1.04)
		else:
			v += (1.0 - v) * UP_VALUE
			h = fposmod(h + (fposmod(WARM_HUE - h + 0.5, 1.0) - 0.5) * 0.05, 1.0)
			s *= 0.94
	return Color.from_hsv(h, s, v, colour.a)

