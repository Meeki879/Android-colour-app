extends RefCounted
## Helpers for building large, child-friendly controls in code.

const RADIUS := 28


static func tile(text: String, color: Color, min_size := Vector2(300, 200), font_size := 40) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = min_size
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.add_theme_font_size_override("font_size", font_size)
	b.add_theme_color_override("font_color", Color.WHITE)
	b.add_theme_color_override("font_hover_color", Color.WHITE)
	b.add_theme_color_override("font_pressed_color", Color.WHITE)
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	b.set_meta("tile_color", color)
	set_selected(b, false)
	return b


static func set_selected(b: Button, selected: bool) -> void:
	var color: Color = b.get_meta("tile_color")
	b.add_theme_stylebox_override("normal", _box(color, selected))
	b.add_theme_stylebox_override("hover", _box(color.lightened(0.08), selected))
	b.add_theme_stylebox_override("pressed", _box(color.darkened(0.15), selected))
	b.add_theme_stylebox_override("disabled", _box(color.darkened(0.5), false))


static func label(text: String, font_size := 28) -> Label:
	var l := Label.new()
	l.text = text
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_font_size_override("font_size", font_size)
	return l


static func margin(child: Control, px := 32) -> MarginContainer:
	var m := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		m.add_theme_constant_override("margin_" + side, px)
	m.add_child(child)
	return m


static func _box(color: Color, selected: bool) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = color
	s.set_corner_radius_all(RADIUS)
	s.set_content_margin_all(16)
	if selected:
		s.set_border_width_all(10)
		s.border_color = Color.WHITE
	return s
