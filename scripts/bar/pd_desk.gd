extends RefCounted
## The PD's desk: what the player has to work with, beside the transcript. Tonight's hand of
## plant cards (dealt from their own dice, aimed at whoever the camera's on), the box a
## write-in card is typed in (on the desk, never a pop-up), the edit (a big moment's spins,
## for two seconds), and the camera's "● REC" in the stage's corner with the viewfinder round
## whoever it's on. Nothing here pauses the night.
## The tent's scene decides what a card does to the night (the weather, an arrival, a round:
## given here as happens) and who's here; this keeps the hand, shows it, and takes the
## player's clicks and typing. (Part 12 of splitting visit.gd: see DEVLOG.md, 17 November 2026.)

const Plants = preload("res://scripts/rules/plants.gd")
const Captions = preload("res://scripts/rules/captions.gd")
const Talk = preload("res://scripts/rules/talk.gd")
const Text = preload("res://scripts/rules/text.gd")
const Glossary = preload("res://scripts/rules/glossary.gd")
const Ktv = preload("res://scripts/ui/ktv_style.gd")
const Draw = preload("res://scripts/bar/draw.gd")
const Night = preload("res://scripts/bar/night.gd")
const PdCamera = preload("res://scripts/bar/camera.gd")

const CAMERA_RED := Color("ff4f6d")  # the camera's REC (the shock caption's red)
const KIND_COLOURS := {"event": Ktv.MINT, "write": Ktv.PINK, "sponsor": Ktv.YELLOW}  # (the cards' stripes and tags)
const MAX_PINS := 3  # lines kept for the episode a night ("Previously on…" is three things): a fourth drops the oldest
const STAY_LEFT := 20.0  # game minutes someone needs left for a card picked for them (a pair: both)
## What a PD is, on the desk's title's hover.
const PD_MEANS := "PD: the producer-director, who makes a Korean TV show: picks whose story the camera follows, and sets things up to see what happens. That's you: the tent runs itself, and nothing you do here pauses it."

## The desk while the crew run it (an autoplay batch): its clicks are theirs, not the player's.
const CREW_HAS_IT := "The crew are at the desk (Let the crew run it): stop them from the menu to play it yourself."

var night: Night  # tonight (its stats)
var crew_running := false  # the crew have the desk (autoplay): a click does nothing; the crew play it in code (play, air_edit)
var camera: PdCamera  # who the show's following (a new one each night)

# Tonight's hand.
var hand: Array = []  # tonight's plant cards (Plants.CARDS ids), dealt as the night opens
var played: Array = []  # ... and the ones played
var picked := {}  # card -> the Guest the game picked for it (with nobody on camera), until it's played
var card_what := {}  # card -> what it is tonight (its variant), picked as it's dealt, so a write-in says it before you type
var dice := RandomNumberGenerator.new()  # the cards' own (dealing them never shifts anything else's rolls)
var writing_card := ""  # the write-in card being typed ("": none)
var edit := {}  # the edit up on the desk: {"spins", "reply", "lines", "names", "roll"} ({}: none)
var recut := ""  # "Step in: re-cut episode 28": while the PD still can (early in the night), a link on the desk
var pins: Array = []  # lines the PD's kept for the episode, oldest first: {"id", "speaker", "text", "at"}

# What the tent tells the desk, and does for it.
var now: Callable  # () -> what the cards need to know right now (Plants.why_not)
var guests: Callable  # () -> everyone at the counter (Guests)
var pair_partner: Callable  # (guest) -> who a pair's card would pair them with, or null
var cat: Callable  # () -> the tent's cat ({} if there isn't one)
var owner_called: Callable  # () -> the owner as the desk names them ("Kim Soon-ok (Ajumma)")
var happens: Callable  # (card, text, aimed, what): a card's played, and the tent makes it happen
var airs: Callable  # (k, spins, reply, lines, names, roll): the edit's spin k goes out
var link: Callable  # (meta): a link clicked on the desk (a pinned line's "pin:N": let it go)

# On screen.
var panel: PanelContainer  # the desk itself
var scroll: ScrollContainer  # ...which scrolls, so it never grows past the screen
var text: RichTextLabel  # its heading and the camera
var cards: VBoxContainer  # tonight's cards
var writing_box: VBoxContainer
var writing_label: Label
var writing_text: LineEdit
var writing_problem: Label
var edit_box: VBoxContainer
var edit_buttons: VBoxContainer
var edit_bar: ProgressBar
var edit_tween: Tween
var rec: Label  # "● REC" and who, in the stage's top corner


func _init(tonight: Night) -> void:
	night = tonight


# --- Building it -------------------------------------------------------------------------

## The desk's insides, in its panel (scrolling, so it never grows past the screen and over
## the panels beside it): the edit (on top, where your eye is when it pops up), the heading,
## camera and pins, the cards, and the writing box.
func build(desk: PanelContainer) -> void:
	panel = desk
	scroll = ScrollContainer.new()
	scroll.name = "PdDeskScroll"
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	panel.add_child(scroll)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(box)
	text = RichTextLabel.new()
	text.name = "PdDeskText"
	text.bbcode_enabled = true
	text.fit_content = true
	text.meta_underlined = false
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.add_theme_font_size_override("normal_font_size", 17)
	text.add_theme_font_size_override("bold_font_size", 17)
	text.meta_clicked.connect(_on_link)
	box.add_child(text)
	edit_box = VBoxContainer.new()
	edit_box.name = "PdEdit"
	edit_box.visible = false
	var edit_label := Label.new()
	edit_label.text = "THE EDIT: pick its spin (1, 2, 3)"
	edit_label.add_theme_color_override("font_color", CAMERA_RED)
	edit_box.add_child(edit_label)
	edit_bar = ProgressBar.new()
	edit_bar.name = "PdEditBar"
	edit_bar.show_percentage = false
	edit_bar.custom_minimum_size = Vector2(0, 6)
	var fill := StyleBoxFlat.new()  # (the time left, in the camera's red)
	fill.bg_color = CAMERA_RED
	edit_bar.add_theme_stylebox_override("fill", fill)
	edit_box.add_child(edit_bar)
	edit_buttons = VBoxContainer.new()
	edit_buttons.name = "PdEditSpins"
	edit_box.add_child(edit_buttons)
	box.add_child(edit_box)
	box.move_child(edit_box, 0)  # (on top: where your eye is when it pops up)
	cards = VBoxContainer.new()
	cards.name = "PlantCards"
	cards.add_theme_constant_override("separation", 8)
	box.add_child(cards)
	writing_box = VBoxContainer.new()
	writing_box.name = "PlantWriting"
	writing_box.visible = false
	box.add_child(writing_box)
	writing_label = Label.new()
	writing_label.name = "PlantWritingLabel"
	writing_label.add_theme_color_override("font_color", Ktv.ORANGE)
	writing_box.add_child(writing_label)
	writing_text = LineEdit.new()
	writing_text.name = "PlantWritingText"
	writing_text.text_submitted.connect(written)
	writing_text.gui_input.connect(writing_key)
	writing_box.add_child(writing_text)
	writing_problem = Label.new()
	writing_problem.name = "PlantWritingProblem"
	writing_problem.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	writing_box.add_child(writing_problem)


## A link clicked on the desk: the tent handles it (a pinned line's: let it go).
func _on_link(meta: Variant) -> void:
	if link.is_valid() and not crew_running:
		link.call(meta)


## "● REC" in the stage's top corner (never hidden: over the bubbles and captions).
func build_rec(stage: Control) -> void:
	rec = Ktv.label("", 20, CAMERA_RED, 6)
	rec.name = "CameraRec"
	rec.position = Vector2(28, 16)
	rec.z_index = 6
	rec.mouse_filter = Control.MOUSE_FILTER_PASS
	rec.visible = false
	stage.add_child(rec)


# --- Tonight's hand --------------------------------------------------------------------------

## A new night's hand, from the cards' own dice (seed: the bar and the night), not last night's
## cards again; each card's variant picked as it's dealt. Anything left up from last night goes.
func deal(seed_text: String, tonight: Dictionary, last: Array) -> Array:
	if not edit.is_empty():
		air_edit(0)
	close_writing()
	dice.seed = hash(seed_text)
	hand = Plants.deal(dice, tonight, last)
	played = []
	picked = {}
	card_what = {}
	pins = []
	for card in hand:
		what_for(str(card))
	return hand


## What a card is tonight (its variant, picked once: "" for a card without them).
func what_for(card: String) -> String:
	if not card_what.has(card):
		card_what[card] = Plants.variant(card, dice)
	return str(card_what[card])


## Who a card happens to: [] for the tent's and nobody's; [someone] (whoever the camera's on,
## or someone the game picks and keeps to); a pair: [them, who they're chatting with].
func target(card: String) -> Array:
	var kind := str(Plants.CARDS[card]["for"])
	var here: Array = guests.call()
	if kind != "someone" and kind != "pair" or here.is_empty():
		return []
	var fits := func(g): return here.has(g) and g.stay_left >= STAY_LEFT and (kind == "someone" or pair_partner.call(g) != null)  # (not someone about to go)
	var who: Variant = camera.subject() if camera != null else null
	if who == null or not fits.call(who):
		who = picked.get(card)
		if who == null or not fits.call(who):
			var choices: Array = here.filter(func(g): return fits.call(g))
			if choices.is_empty():
				return []
			who = choices[dice.randi_range(0, choices.size() - 1)]
			picked[card] = who
	return [who] if kind == "someone" else [who, pair_partner.call(who)]


## What a write-in's PD is told before typing: "a text from her landlord" ("" if nothing).
func write_from(card: String, guest: Variant) -> String:
	var from := str(Plants.CARDS[card].get("write", {}).get("from", ""))
	if from == "":
		return ""
	return Plants.gendered(from.replace("{what}", what_for(card)), str(guest.customer.get("gender", "")) if guest != null else "")


## A card clicked: a write-in opens the box first (see written); any other's played. Not while
## the crew have the desk.
func press(card: String) -> void:
	if crew_running:
		return
	if Plants.is_write(card):
		open_writing(card)
		return
	play(card)


## Whether a card can be played now: in the hand, not played yet, possible tonight, and (if
## it's for someone, or a pair) somebody here with time left for it.
func can_play(card: String) -> bool:
	if played.has(card) or not hand.has(card) or Plants.why_not(card, now.call()) != "":
		return false
	return not ["someone", "pair"].has(str(Plants.CARDS[card]["for"])) or not target(card).is_empty()


## Plays a card (text: what the PD wrote, for a write-in): the tent makes it happen, to
## whoever it's for. Not one already played, or one that can't be, now.
func play(card: String, typed: String = "") -> void:
	if not can_play(card):
		return
	var aimed := target(card)
	played.append(card)
	picked.erase(card)
	happens.call(card, typed, aimed, what_for(card))
	refresh()


# --- Pinning lines -----------------------------------------------------------------------------

## A line clicked in the transcript (line: {"id", "speaker", "text", "at"}): kept for the
## episode, or let go if it already was. A fourth pin drops the oldest. Returns what happened:
## {"pinned": the line} (and "dropped": the oldest, if one went), or {"unpinned": the line}.
func pin(line: Dictionary) -> Dictionary:
	for kept in pins:
		if int(kept["id"]) == int(line["id"]):
			pins.erase(kept)
			_count_pins()
			refresh()
			return {"unpinned": kept}
	pins.append(line.duplicate())
	var happened := {"pinned": line}
	night.stats.pins_made += 1
	if pins.size() > MAX_PINS:
		happened["dropped"] = pins.pop_front()
		night.stats.pins_dropped += 1
	_count_pins()
	refresh()
	return happened


func _count_pins() -> void:
	night.stats.pinned = pins.map(func(p): return {"speaker": str(p["speaker"]), "text": str(p["text"])})


# --- On the desk -----------------------------------------------------------------------------

## The desk: who the camera's on, how to use it, and tonight's cards.
func refresh() -> void:
	if text == null:
		return
	var muted := Ktv.MUTED.to_html(false)
	var red := CAMERA_RED.to_html(false)
	var t := "[color=#%s][b]%s[/b][/color]\n\n" % [Ktv.ORANGE.to_html(false), Text.hint(PD_MEANS, "PD CONTROLS")]
	if recut != "":
		t += "[url=edit][color=#%s][b]%s[/b][/color][/url]\n\n" % [red, _esc(recut)]
	t += "[b]%s[/b]  " % Text.hint("Click someone at the counter, the cat or the owner to follow them: their story gets the airtime. Click again to stop.", "Camera")
	if camera != null and camera.on_cat:
		var with: Variant = camera.subject()
		t += "[color=#%s]● REC[/color] %s, the cat%s\n" % [red, _esc(cat.call().get("name", "")),
			(", with %s" % _esc(with.customer["name"])) if with != null else ", on its own"]
	elif camera != null and camera.on_owner:
		t += "[color=#%s]● REC[/color] %s, the owner\n" % [red, _esc(owner_called.call() if owner_called.is_valid() else "the owner")]
	elif camera != null and camera.following != null:
		t += "[color=#%s]● REC[/color] %s\n" % [red, _esc(camera.following.customer["name"])]
	else:
		t += "[color=#%s]not on anyone: click someone to follow them[/color]\n" % muted
	t += "\n[b]%s[/b] %d/%d" % [Text.hint("Click a line's 📌 in the transcript to keep it for the episode: three a night, for \"Previously on…\" (a fourth drops the oldest). Click a pinned line here to let it go.", "Pinned"), pins.size(), MAX_PINS]
	t += ("  [color=#%s]click a line's 📌 in the transcript[/color]\n" % muted) if pins.is_empty() else "\n"
	for kept in pins:
		t += "[url=pin:%d][color=#%s]📌[/color] %s: [i]%s[/i]  [color=#%s]✕[/color][/url]\n" % [int(kept["id"]), red, _esc(kept["speaker"]), _esc(Text.shorten(str(kept["text"]), 48)), muted]
	t += "\n[b]Plants[/b]  [color=#%s]tonight's cards: play one, and see what comes of it[/color]" % muted
	text.text = Glossary.explain_hangul(t)
	_refresh_cards()


## Tonight's cards: one button each, greyed out once played or while they can't be, the hover
## saying what it does, who it's for, and why not.
func _refresh_cards() -> void:
	if cards == null:
		return
	var names := ",".join(PackedStringArray(hand))
	if str(cards.get_meta("hand", "")) != names:
		cards.set_meta("hand", names)
		for old in cards.get_children():
			cards.remove_child(old)
			old.queue_free()
		for card in hand:
			var button := Button.new()
			button.name = "Plant_" + str(card)
			button.focus_mode = Control.FOCUS_NONE
			button.alignment = HORIZONTAL_ALIGNMENT_LEFT
			button.add_theme_font_size_override("font_size", 17)
			button.pressed.connect(press.bind(str(card)))
			style_card(button, Plants.kind_of(str(card)))
			cards.add_child(button)
	var right_now: Dictionary = now.call()
	for button in cards.get_children():
		var card := str(button.name).trim_prefix("Plant_")
		var done := played.has(card)
		var why := Plants.why_not(card, right_now)
		if why == "" and ["someone", "pair"].has(str(Plants.CARDS[card]["for"])) and target(card).is_empty():
			why = "Nobody at the counter with time left for it."
		button.text = "%s%s" % [Plants.CARDS[card]["title"], "  (played)" if done else ""]  # (its tag says what kind)
		button.disabled = done or why != "" or crew_running
		var tip := str(Plants.KINDS[Plants.kind_of(card)]["about"]) + "\n" + str(Plants.CARDS[card]["about"])
		var tag := button.get_node_or_null("Kind") as Label
		if tag != null:
			tag.modulate.a = 0.45 if button.disabled else 1.0
		if done:
			tip += "\nPlayed tonight."
		elif why != "":
			tip += "\n" + why
		else:
			tip += aim_text(card)
			var aimed := target(card)
			var from := write_from(card, aimed[0] if not aimed.is_empty() else null)
			if from != "":
				tip += "\n(" + from + ")"
		if crew_running and not done:
			tip += "\n" + CREW_HAS_IT
		button.tooltip_text = Text.tip(tip)


## A card's look on the desk, by its kind: a stripe down its side and a tag (EVENT, WRITE-IN,
## SPONSOR), in the kind's colour.
static func style_card(button: Button, kind: String) -> void:
	var colour: Color = KIND_COLOURS[kind]
	for state in ["normal", "hover", "pressed", "disabled"]:
		var box := StyleBoxFlat.new()
		box.bg_color = Ktv.PANEL.lightened(0.12 if state == "hover" else (0.02 if state == "disabled" else 0.06))
		box.border_color = colour if state != "disabled" else colour.darkened(0.5)
		box.border_width_left = 6
		box.set_corner_radius_all(4)
		box.content_margin_left = 14
		box.content_margin_right = 118
		box.content_margin_top = 6
		box.content_margin_bottom = 6
		button.add_theme_stylebox_override(state, box)
	var tag := Ktv.label(str(Plants.KINDS[kind]["tag"]), 12, Ktv.INK)
	tag.name = "Kind"
	tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tag.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	var badge := StyleBoxFlat.new()
	badge.bg_color = colour
	badge.set_corner_radius_all(6)
	badge.set_content_margin_all(6)
	tag.add_theme_stylebox_override("normal", badge)
	tag.anchor_left = 1.0
	tag.anchor_right = 1.0
	tag.anchor_top = 0.5
	tag.anchor_bottom = 0.5
	tag.offset_left = -106
	tag.offset_right = -8
	tag.offset_top = -13
	tag.offset_bottom = 13
	button.add_child(tag)


## Who a card would happen to, for its hover: "→ Kim Ji-ho (the camera's on them)".
func aim_text(card: String) -> String:
	var aimed := target(card)
	if aimed.is_empty():
		return ""
	var named := " and ".join(PackedStringArray(aimed.map(func(g): return str(g.customer["name"]))))
	var subject: Variant = camera.subject() if camera != null else null
	var on_camera: bool = subject == aimed[0]
	var leaving: bool = not on_camera and subject != null and guests.call().has(subject)
	return "\n→ %s (%s)" % [named, "the camera's on them" if on_camera else ("picked: whoever the camera's on is about to go" if leaving else "picked: follow someone with the camera to choose")]


# --- Writing a card ----------------------------------------------------------------------------

## A write-in card: the box on the desk opens (the night carries on while the PD types).
func open_writing(card: String) -> void:
	if writing_box == null or played.has(card) or not hand.has(card) or Plants.why_not(card, now.call()) != "":
		return
	writing_card = card
	var write: Dictionary = Plants.CARDS[card]["write"]
	var aimed := target(card)
	var who: Variant = aimed[0] if not aimed.is_empty() else null
	var from := write_from(card, who)  # (who it's from, said before you type it)
	var for_who := ("for %s" % who.customer["name"]) if who != null else ""
	writing_label.text = "%s  (%s)" % [write["label"], ", ".join(PackedStringArray([from, for_who].filter(func(part): return part != "")))]
	writing_text.max_length = int(write["max"])
	writing_text.placeholder_text = "e.g. %s" % write["hint"]
	writing_text.text = ""
	writing_problem.text = "Enter to play it, Esc to put it back."
	writing_problem.add_theme_color_override("font_color", Ktv.MUTED)
	writing_box.visible = true
	writing_text.grab_focus()
	if scroll != null:
		scroll.ensure_control_visible.call_deferred(writing_text)


func close_writing() -> void:
	writing_card = ""
	if writing_box != null:
		writing_box.visible = false
		writing_text.release_focus()


## Enter in the box: checked, then played (or why not, and the card stays in the hand).
func written(typed: String) -> void:
	if writing_card == "":
		return
	var checked := Plants.check_written(writing_card, typed)
	var problem := str(checked["problem"])
	if problem == "" and Talk.real_brand(str(checked["text"])) != "":
		problem = "No real brands on the show (the sponsor's the only one we plug)."
	if problem == "" and Plants.why_not(writing_card, now.call()) != "":
		problem = Plants.why_not(writing_card, now.call())
	if problem == "" and target(writing_card).is_empty():
		problem = "Nobody at the counter with time left for it."
	if problem != "":
		writing_problem.text = problem
		writing_problem.add_theme_color_override("font_color", CAMERA_RED)
		night.stats.written_refused += 1
		return
	var card := writing_card
	close_writing()
	play(card, str(checked["text"]))


## Esc in the box puts the card back (and doesn't open Options).
func writing_key(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key != null and key.pressed and key.keycode == KEY_ESCAPE:
		close_writing()
		writing_text.accept_event()


# --- The edit ------------------------------------------------------------------------------------

## The edit, on the desk: a big moment's spins as buttons (1, 2, 3), a bar running down, and
## whichever's picked (or the AI's, when time's up) goes out.
func offer_edit(spins: Array, reply: Dictionary, lines: Array, names: Array, roll: float) -> void:
	if not edit.is_empty():
		air_edit(0)  # (an earlier one still up: the AI's goes out, and this one takes its place)
	edit = {"spins": spins, "reply": reply, "lines": lines, "names": names, "roll": roll}
	night.stats.edits_offered += 1
	night.stats.edit_log.append({"spins": spins.duplicate(true), "aired": 0})
	for old in edit_buttons.get_children():
		edit_buttons.remove_child(old)
		old.queue_free()
	for k in spins.size():
		var spin: Dictionary = spins[k]
		var data: Dictionary = Captions.REACTIONS[str(spin["mood"])]
		var button := Button.new()
		button.name = "Edit_%d" % (k + 1)
		button.focus_mode = Control.FOCUS_NONE
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.text = "%d  %s  %s" % [k + 1, str(spin["mood"]).to_upper(), spin["caption"]]
		button.add_theme_font_size_override("font_size", 15)
		button.add_theme_color_override("font_color", Color(str(data["colour"])))
		button.tooltip_text = Text.tip("%s%s: %s" % ["The AI's pick, " if k == 0 else "", str(spin["mood"]), data["means"]])
		button.pressed.connect(func():
			if not crew_running:
				air_edit(k))
		button.disabled = crew_running
		edit_buttons.add_child(button)
	edit_box.visible = true
	if scroll != null:
		scroll.scroll_vertical = 0  # (it's on top: bring it into view)
	edit_bar.value = 100.0
	var seconds := Draw.scaled(Captions.EDIT_SECONDS)
	edit_tween = edit_bar.create_tween()
	edit_tween.tween_property(edit_bar, "value", 0.0, seconds)
	var token: Dictionary = edit
	var timer := Timer.new()
	timer.one_shot = true
	timer.wait_time = maxf(seconds, 0.001)
	timer.timeout.connect(timer.queue_free)
	timer.timeout.connect(func():
		if edit == token:
			air_edit(0))  # (time's up: the AI's own)
	panel.add_child(timer)
	timer.start()


## Whether the edit's up (so 1, 2 and 3 pick its spin).
func edit_up() -> bool:
	return not edit.is_empty()


## The PD picked spin k (0: the AI's own, or time ran out): it goes out.
func air_edit(k: int) -> void:
	if edit.is_empty():
		return
	var pending := edit
	edit = {}
	edit_box.visible = false
	if edit_tween != null:
		edit_tween.kill()
	var spins: Array = pending["spins"]
	k = clampi(k, 0, spins.size() - 1)
	if not night.stats.edit_log.is_empty():
		night.stats.edit_log[-1]["aired"] = k
	if k > 0:
		var change := "%s→%s" % [spins[0]["mood"], spins[k]["mood"]]
		night.stats.edits_made[change] = int(night.stats.edits_made.get(change, 0)) + 1
	airs.call(k, spins, pending["reply"], pending["lines"], pending["names"], float(pending["roll"]))


# --- The camera on screen ------------------------------------------------------------------------

## The corner's "● REC" and who ("" hides it), with its hover.
func show_rec(who: String, tip: String) -> void:
	if rec == null:
		return
	rec.text = "● REC  %s" % who
	rec.visible = who != ""
	if tip != "":
		rec.tooltip_text = tip


## The camera's viewfinder: corner marks round whoever it's on (round their body, clear of the
## speech bubbles over their heads).
static func viewfinder(node: Control, frame: Rect2) -> void:
	if not is_instance_valid(node) or node.get_node_or_null("CameraBadge") != null:
		return
	var marks := Control.new()
	marks.name = "CameraBadge"
	marks.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var arm := 14.0
	var thick := 3.0
	for corner in [frame.position, Vector2(frame.end.x, frame.position.y), Vector2(frame.position.x, frame.end.y), frame.end]:
		var right: bool = corner.x > frame.position.x
		var down: bool = corner.y > frame.position.y
		var across := ColorRect.new()
		across.color = CAMERA_RED
		across.mouse_filter = Control.MOUSE_FILTER_IGNORE
		across.size = Vector2(arm, thick)
		across.position = Vector2(corner.x - (arm if right else 0.0), corner.y - (thick if down else 0.0))
		marks.add_child(across)
		var upright := ColorRect.new()
		upright.color = CAMERA_RED
		upright.mouse_filter = Control.MOUSE_FILTER_IGNORE
		upright.size = Vector2(thick, arm)
		upright.position = Vector2(corner.x - (thick if right else 0.0), corner.y - (arm if down else 0.0))
		marks.add_child(upright)
	node.add_child(marks)


## Takes the viewfinder off a node.
static func viewfinder_off(node: Variant) -> void:
	if not is_instance_valid(node):
		return
	var marks: Node = node.get_node_or_null("CameraBadge")
	if marks != null:
		marks.queue_free()


static func _esc(value: Variant) -> String:
	return str(value).replace("[", "[lb]")
