extends Control
## Child-safe home: one row of theme tiles (one selected at a time), a Custom door to the
## Grown-ups area behind the parental gate, and a big Play button.

signal play_requested
signal grownups_requested

const UiKit := preload("res://ui/ui_kit.gd")
const BACKGROUND := Color("#1d1b2f")
# Tile colours hint at each theme's world. Indexed like Settings.THEME_NAMES.
const THEME_COLOURS := [Color("#8d7b68"), Color("#5b8fb9"), Color("#b0306a"), Color("#e07a5f"), Color("#3d3b8e")]
const CUSTOM_COLOUR := Color("#4a4a5a")

var _play: Button
var _custom: Button
var _grid: GridContainer
var _theme_tiles: Array[Button] = []


func _ready() -> void:
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = BACKGROUND
	bg.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	add_child(bg)

	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	add_child(scroll)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 28)
	var framed := UiKit.margin(column)
	framed.size_flags_horizontal = SIZE_EXPAND_FILL
	scroll.add_child(framed)

	_grid = GridContainer.new()
	_grid.add_theme_constant_override("h_separation", 24)
	_grid.add_theme_constant_override("v_separation", 24)
	for i in Settings.THEME_NAMES.size():
		var t := UiKit.tile(Settings.THEME_NAMES[i], THEME_COLOURS[i], Vector2(200, 200), 34)
		t.pressed.connect(_on_theme.bind(i))
		_grid.add_child(t)
		_theme_tiles.append(t)
	_custom = UiKit.tile("Custom", CUSTOM_COLOUR, Vector2(200, 200), 34)
	_custom.pressed.connect(grownups_requested.emit)
	_grid.add_child(_custom)
	column.add_child(_grid)

	_play = UiKit.tile("Play", Color("#27ae60"), Vector2(300, 220), 56)
	_play.pressed.connect(_on_play)
	column.add_child(_play)

	resized.connect(_layout)
	_layout()
	_refresh()
	if not Settings.safety_notice_seen:
		_show_safety_notice()


func _layout() -> void:
	_grid.columns = 3 if size.x > 1000.0 else 2


## Exactly one outline: the chosen theme in Simple mode, or the Custom door in Custom mode.
func _refresh() -> void:
	var custom := Settings.mode == "custom"
	for i in _theme_tiles.size():
		UiKit.set_selected(_theme_tiles[i], not custom and i == Settings.theme)
	UiKit.set_selected(_custom, custom)
	_custom.text = "Custom\n(%s)" % Settings.THEME_NAMES[Settings.theme] if custom else "Custom"
	var resting := Settings.is_rest_time()
	_play.disabled = resting
	_play.text = "Rest time" if resting else "Play"


func _on_theme(index: int) -> void:
	Settings.theme = index
	Settings.mode = "simple"
	Settings.save_settings()
	_refresh()


func _on_play() -> void:
	if not Settings.is_rest_time():
		play_requested.emit()


func _show_safety_notice() -> void:
	var shade := ColorRect.new()
	shade.color = Color(0, 0, 0, 0.85)
	shade.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	add_child(shade)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 24)
	box.add_child(UiKit.label("For grown-ups", 40))
	box.add_child(UiKit.label(
		"This app shows moving colour and light. The app itself never strobes: its own "
		+ "pulses stay at one per second or slower. Very fast tapping can still make quick "
		+ "changes of light. If your child has photosensitive epilepsy, check with a doctor first."))
	box.add_child(UiKit.label(
		"To keep a young child inside the app, turn on App pinning (Android) or "
		+ "Guided Access (iPhone/iPad). The Grown-ups area explains how. "
		+ "To leave the play screen, hold the top-left corner for 3 seconds."))
	var ok := UiKit.tile("I understand", Color("#27ae60"), Vector2(300, 120), 36)
	ok.pressed.connect(func():
		Settings.safety_notice_seen = true
		Settings.save_settings()
		shade.queue_free())
	box.add_child(ok)

	var framed := UiKit.margin(box, 48)
	framed.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	shade.add_child(framed)
