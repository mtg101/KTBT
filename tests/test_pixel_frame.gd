extends GdUnitTestSuite
## Tests for scripts/ui/pixel_frame.gd: the panels and buttons under the stage in pixel art.

const PixelFrame = preload("res://scripts/ui/pixel_frame.gd")


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

