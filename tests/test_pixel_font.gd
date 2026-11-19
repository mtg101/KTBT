extends GdUnitTestSuite
## Tests for scripts/ui/pixel_font.gd: the words on the stage in the pixel Korean font
## (Galmuri, fonts/galmuri), crisp at whole multiples of each size's own pixel height.

const PixelFont = preload("res://scripts/ui/pixel_font.gd")


func test_every_size_is_there_set_up_for_pixels() -> void:
	for size_name in PixelFont.SIZES:
		var font := PixelFont.font(size_name)
		assert_object(font).override_failure_message("no %s" % size_name).is_not_null()
		assert_int(font.antialiasing).is_equal(TextServer.FONT_ANTIALIASING_NONE)  # never smoothed
		assert_int(font.subpixel_positioning).is_equal(TextServer.SUBPIXEL_POSITIONING_DISABLED)
		assert_array(font.fallbacks).contains([ThemeDB.fallback_font])  # (a symbol it hasn't got: the ordinary font)
		for word in ["포장마차", "노래방", "마감", "메뉴", "CLOSED", "Han Jeong-hee"]:  # Hangul and Latin
			for k in word.length():
				assert_bool(font.has_char(word.unicode_at(k))).override_failure_message("%s hasn't got %s" % [size_name, word[k]]).is_true()
	assert_object(PixelFont.font("no_such_size")).is_null()
	assert_object(PixelFont.font("galmuri11")).is_same(PixelFont.font("galmuri11"))  # (read once)


func test_each_use_is_a_whole_multiple_of_its_pixels() -> void:
	for use in PixelFont.USES:
		var spec: Array = PixelFont.USES[use]
		assert_bool(PixelFont.SIZES.has(spec[0])).is_true()
		assert_int(PixelFont.size_for(use) % int(PixelFont.SIZES[spec[0]]["pixels"])).is_equal(0)
	assert_int(PixelFont.size_for("sign_hangul")).is_equal(30)  # (on the art's grid: 10 pixels, 3 each)
	assert_int(PixelFont.size_for("closed_english")).is_equal(16)
	for use in ["name_tag", "bubble", "heading", "button", "title", "badge"]:  # (the ordinary font: only the bar's art is in pixels)
		assert_bool(PixelFont.USES.has(use)).is_false()


func test_a_label_and_rich_text_take_it() -> void:
	var holder: Control = auto_free(Control.new())
	var label := Label.new()
	holder.add_child(label)
	PixelFont.apply(label, "neon")
	assert_object(label.get_theme_font("font")).is_same(PixelFont.font("galmuri7"))
	assert_int(label.get_theme_font_size("font_size")).is_equal(24)
	var rich := RichTextLabel.new()
	holder.add_child(rich)
	PixelFont.apply(rich, "sign_english")
	assert_object(rich.get_theme_font("normal_font")).is_same(PixelFont.font("galmuri7"))
	assert_object(rich.get_theme_font("bold_font")).is_same(PixelFont.font("galmuri7"))
	holder.add_child(Label.new())  # (the ordinary font: not counted)
	assert_int(PixelFont.count_in(holder)).is_equal(2)
