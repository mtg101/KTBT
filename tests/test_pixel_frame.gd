extends GdUnitTestSuite
## Tests for scripts/ui/pixel_frame.gd: the panels and buttons under the stage in pixel art.

const PixelFrame = preload("res://scripts/ui/pixel_frame.gd")
const PixelFont = preload("res://scripts/ui/pixel_font.gd")


func test_a_frame_in_whole_pixels_with_notched_corners() -> void:
	var image := PixelFrame.frame_texture(PixelFrame.PANEL).get_image()
	assert_vector(Vector2(image.get_size())).is_equal(Vector2.ONE * PixelFrame.CELLS * PixelFrame.GRID)
	assert_float(image.get_pixel(0, 0).a).is_equal(0.0)  # (a notched corner)
	assert_bool(image.get_pixel(PixelFrame.GRID, 0).is_equal_approx(PixelFrame.PANEL[1])).is_true()  # the edge...
	assert_bool(image.get_pixel(PixelFrame.GRID + 2, 2).is_equal_approx(PixelFrame.PANEL[1])).is_true()  # ...a whole pixel of the grid
	assert_bool(image.get_pixel(12, PixelFrame.GRID).is_equal_approx(PixelFrame.PANEL[2])).is_true()  # lit inside its top
	assert_bool(image.get_pixel(12, (PixelFrame.CELLS - 2) * PixelFrame.GRID).is_equal_approx(PixelFrame.PANEL[3])).is_true()  # shadow inside its bottom
	var style := PixelFrame.style(PixelFrame.PANEL)
	assert_float(style.texture_margin_left).is_equal(float(PixelFrame.EDGE * PixelFrame.GRID))  # (the edge kept whole, the middle stretched)
	assert_object(PixelFrame.style(PixelFrame.PANEL)).is_same(style)  # (made once)


func test_the_bar_screens_buttons_are_framed_and_in_the_pixel_font() -> void:
	var theme := PixelFrame.theme()
	assert_bool(theme.get_stylebox("normal", "Button") is StyleBoxTexture).is_true()
	assert_bool(theme.get_stylebox("hover", "Button") != theme.get_stylebox("normal", "Button")).is_true()  # lit up when you're over it
	assert_object(theme.get_font("font", "Button")).is_same(PixelFont.font("galmuri14"))
	assert_bool(theme.get_stylebox("normal", "CheckBox") is StyleBoxEmpty).is_true()  # (tick boxes as they are)
	var rich := RichTextLabel.new()
	PixelFont.apply_headings(rich)
	assert_object(rich.get_theme_font("bold_font")).is_same(PixelFont.font("galmuri14"))  # headings in pixels...
	assert_bool(rich.has_theme_font_override("normal_font")).is_false()  # ...the long text as it is
	rich.free()
