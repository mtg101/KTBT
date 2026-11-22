extends PanelContainer
## A customer's post on 달밤 (Dalbam, the game's own feed app: rules/socials.gd), as a card stuck
## round the 3am diary page and in the diary book (ui/social_feed.gd): their portrait and handle,
## the app and when, the picture in a phone photo's frame (the real snapshot of the stage, kept
## beside the bar's save; a selfie with their face in front of it), the words and the hashtags,
## Korean explained on hover. A picture that isn't there (no screen to take it from, or a file
## gone) is drawn instead: their portrait on a selfie, the dish on a food pic or the cat's; a
## text post has none. Never takes a click; its hovers still show.

const Ktv = preload("res://scripts/ui/ktv_style.gd")
const Glossary = preload("res://scripts/rules/glossary.gd")
const Text = preload("res://scripts/rules/text.gd")
const Socials = preload("res://scripts/rules/socials.gd")
const NightRules = preload("res://scripts/rules/night_rules.gd")
const Menu = preload("res://scripts/rules/menu.gd")
const DishArt = preload("res://scripts/rules/dish_art.gd")
const DishView = preload("res://scripts/ui/dish_view.gd")
const PeopleArt = preload("res://scripts/ui/people_art.gd")
const SaveStore = preload("res://scripts/save/save_store.gd")

const WIDTH := 340.0
const PICTURE := Vector2(300, 200)  # (a snapshot's size: bar/snapshots.gd SIZE)
const CARD := Color("fdfcf8")
const INK := Color("23203f")
const HANDLE_INK := Color("1d1b33")
const TAG_INK := "3b6fd6"
const WORD_INK := "a8326e"  # (Korean words with a hover, as on the diary page)
const PHONE := Color("15141f")  # the photo's frame
const NIGHT := Color("2a2650")  # behind a drawn picture

var poster := ""  # whose (their full name), for the tests and the log
var how := ""  # its picture: "snapshot", "drawn" or "words" (none)


## post: as Socials.pick makes it (and the entry keeps it); bar_id: whose pictures folder its
## snapshot's in; tilt: radians.
func setup(post: Dictionary, bar_id: String, tilt: float) -> void:
	name = "SocialPost"
	poster = str(post.get("poster", ""))
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(WIDTH, 0)
	var style := StyleBoxFlat.new()
	style.bg_color = CARD
	style.set_corner_radius_all(14)
	style.set_content_margin_all(16)
	style.shadow_color = Color(0, 0, 0, 0.45)
	style.shadow_offset = Vector2(5, 7)
	style.shadow_size = 4
	add_theme_stylebox_override("panel", style)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(column)
	column.add_child(_header(post))
	var shot := str(post.get("shot", "text"))
	if Socials.PICTURED.has(shot):
		column.add_child(_picture(post, bar_id))
	else:
		how = "words"
	column.add_child(_words(post))
	rotation = tilt
	resized.connect(func(): pivot_offset = size / 2.0)


## Their face and handle; the app's name and when it went up.
func _header(post: Dictionary) -> Control:
	var row := HBoxContainer.new()
	row.name = "Header"
	row.add_theme_constant_override("separation", 10)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var avatar := TextureRect.new()
	avatar.name = "Avatar"
	avatar.custom_minimum_size = Vector2(32, 40)
	avatar.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	avatar.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	avatar.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	avatar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	avatar.texture = _face(post, true)
	row.add_child(avatar)
	var names := VBoxContainer.new()
	names.add_theme_constant_override("separation", 0)
	names.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(names)
	var handle := Ktv.label(str(post.get("handle", "")), 17, HANDLE_INK)
	handle.name = "Handle"
	names.add_child(handle)
	var app := Ktv.label("%s %s · %s" % [Socials.APP, Socials.APP_ENGLISH, NightRules.clock_text(int(post.get("at", 0)))], 13, INK.lightened(0.45))
	app.name = "App"
	app.mouse_filter = Control.MOUSE_FILTER_STOP  # (Korean on screen explains itself)
	app.tooltip_text = Text.tip("%s %s: the app the customers post on. %s" % [Socials.APP, Socials.APP_ENGLISH, Glossary.hangul_tip(Socials.APP)])
	names.add_child(app)
	return row


## The photo, in a phone's dark frame: the snapshot kept with the bar, or one drawn.
func _picture(post: Dictionary, bar_id: String) -> Control:
	var frame := PanelContainer.new()
	frame.name = "Photo"
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var phone := StyleBoxFlat.new()
	phone.bg_color = PHONE
	phone.set_corner_radius_all(10)
	phone.set_content_margin_all(4)
	frame.add_theme_stylebox_override("panel", phone)
	var view := Control.new()
	view.name = "View"
	view.custom_minimum_size = PICTURE
	view.clip_contents = true
	view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(view)
	var shot := str(post.get("shot", ""))
	var snapshot := SaveStore.load_picture(bar_id, str(post.get("picture", "")))
	if snapshot != null:
		how = "snapshot"
		view.add_child(_stretched(snapshot, Vector2.ZERO, PICTURE, "Snapshot"))
	else:
		how = "drawn"
		var night := ColorRect.new()
		night.color = NIGHT
		night.size = PICTURE
		night.mouse_filter = Control.MOUSE_FILTER_IGNORE
		view.add_child(night)
		if shot != "selfie":
			var dish := _dish(str(post.get("dish_id", "")))
			if dish != null:
				view.add_child(dish)
	if shot == "selfie":  # their face, close up in front (at arm's length)
		var face := _face(post, false)
		if face != null:
			var big := Vector2(face.get_size() * 2)
			view.add_child(_stretched(face, Vector2((PICTURE.x - big.x) / 2.0 if snapshot == null else 12.0, PICTURE.y - big.y + 20.0), big, "Selfie"))
	return frame


## The words, Korean and the game's words explained on hover, then the hashtags.
func _words(post: Dictionary) -> Control:
	var words := RichTextLabel.new()
	words.name = "Words"
	words.bbcode_enabled = true
	words.fit_content = true
	words.scroll_active = false
	words.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	words.custom_minimum_size = Vector2(WIDTH - 32.0, 0)
	words.mouse_filter = Control.MOUSE_FILTER_PASS  # (for the hovers; clicks go through)
	words.add_theme_font_size_override("normal_font_size", 17)
	words.add_theme_color_override("default_color", INK)
	var said := Glossary.explain(str(post.get("text", "")).replace("[", "[lb]"), [str(post.get("poster", ""))], WORD_INK)
	var tags := " ".join(PackedStringArray((post.get("tags", []) as Array).map(func(tag): return str(tag).replace("[", "[lb]"))))
	words.text = Glossary.explain_hangul("%s\n[color=#%s]%s[/color]" % [said, TAG_INK, tags])
	return words


## Their portrait (in the post's mood, or calm), or null if there's no face for them.
func _face(post: Dictionary, calm: bool) -> Texture2D:
	var face: Dictionary = post.get("face", {})
	if face.is_empty():
		return null
	var mood := "" if calm or str(face.get("mood", "calm")) == "calm" else str(face.get("mood", ""))
	var picture: Texture2D = PeopleArt.portrait(face.get("look", {}), str(face.get("key", "")), mood)
	if picture == null and mood != "":
		picture = PeopleArt.portrait(face.get("look", {}), str(face.get("key", "")))
	return picture


## A drawn food pic: the dish in its pixel art, big, in the middle.
static func _dish(dish_id: String) -> Control:
	var item := Menu.find(dish_id)
	if item.is_empty():
		return null
	var art: Dictionary = item.get("art", {"vessel": "bowl", "fill": str(item.get("color", "ffffff"))})
	var dish := DishView.new()
	dish.name = "Dish"
	dish.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dish.size = DishArt.size(art)
	dish.shapes = DishArt.shapes(art, Color(str(item.get("color", "ffffff"))), dish_id)
	dish.scale = Vector2(2, 2)
	dish.position = (PICTURE - dish.size * 2.0) / 2.0
	return dish


static func _stretched(picture: Texture2D, at: Vector2, picture_size: Vector2, node_name: String) -> TextureRect:
	var shown := TextureRect.new()
	shown.name = node_name
	shown.texture = picture
	shown.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	shown.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	shown.stretch_mode = TextureRect.STRETCH_SCALE
	shown.position = at
	shown.size = picture_size
	shown.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return shown
