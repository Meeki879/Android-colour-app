extends Control
## Child-safe home: Simple / Custom tiles, art style tiles, big Play button.
## Custom leads to the Grown-ups area, which sits behind the parental gate.

signal play_requested
signal grownups_requested

const UiKit := preload("res://ui/ui_kit.gd")
const BACKGROUND := Color("#1d1b2f")
const STYLE_COLOURS := [Color("#5b8fb9"), Color("#b0306a"), Color("#e07a5f"), Color("#3d3b8e")]

var _simple: Button
var _custom: Button
var _play: Button
var _grid: GridContainer
var _style_tiles: Array[Button] = []


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

	var modes := HBoxContainer.new()
	modes.add_theme_constant_override("separation", 24)
	_simple = UiKit.tile("Simple", Color("#2e86c1"))
	_simple.pressed.connect(_on_simple)
	_custom = UiKit.tile("Custom", Color("#7d3c98"))
	_custom.pressed.connect(grownups_requested.emit)
	modes.add_child(_simple)
	modes.add_child(_custom)
	column.add_child(modes)

	_grid = GridContainer.new()
	_grid.add_theme_constant_override("h_separation", 24)
	_grid.add_theme_constant_override("v_separation", 24)
	for i in Settings.STYLE_NAMES.size():
		var t := UiKit.tile(Settings.STYLE_NAMES[i], STYLE_COLOURS[i], Vector2(200, 200), 32)
		t.pressed.connect(_on_style.bind(i))
		_grid.add_child(t)
		_style_tiles.append(t)
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
	_grid.columns = 4 if size.x > 1000.0 else 2


func _refresh() -> void:
	UiKit.set_selected(_simple, Settings.mode == "simple")
	UiKit.set_selected(_custom, Settings.mode == "custom")
	for i in _style_tiles.size():
		UiKit.set_selected(_style_tiles[i], i == Settings.style)
	var resting := Settings.is_rest_time()
	_play.disabled = resting
	_play.text = "Rest time" if resting else "Play"


func _on_simple() -> void:
	Settings.mode = "simple"
	Settings.save_settings()
	_refresh()


func _on_style(index: int) -> void:
	Settings.style = index
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
