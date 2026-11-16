extends Control
## Korean variety-show captions popping up by themselves, a few seconds apart, somewhere in
## the given areas: for the title and loading screens (the bar's own captions come from what
## happens: see visit.gd _caption). Each line: [Hangul, English, icon, colour].

const CaptionPopup = preload("res://scripts/ui/caption.gd")

var lines: Array = []
var areas: Array = []  # Rect2s: where captions may pop up (their bottom middle)
var gap := Vector2(4.0, 7.0)  # real seconds between captions
var hold := 2.2
var most := 1  # on screen at once
var _next := 1.5
var _last := -1


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)


func _process(delta: float) -> void:
	if lines.is_empty() or areas.is_empty():
		return
	_next -= delta
	if _next > 0.0:
		return
	_next = randf_range(gap.x, gap.y)
	if get_children().filter(func(c): return not c.is_queued_for_deletion()).size() >= most:
		return
	var pick := randi() % lines.size()
	if pick == _last and lines.size() > 1:
		pick = (pick + 1) % lines.size()  # never the same one twice running
	_last = pick
	var line: Array = lines[pick]
	var area: Rect2 = areas.pick_random()
	var caption := CaptionPopup.new()
	caption.name = "ReelCaption"
	caption.stage_width = size.x if size.x > 0.0 else 1920.0
	caption.at = area.position + Vector2(randf() * area.size.x, randf() * area.size.y)
	caption.setup({"hangul": str(line[0]), "english": str(line[1])}, str(line[2]), Color(str(line[3])))
	add_child(caption)
	caption.pop(hold)
