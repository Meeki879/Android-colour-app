extends Control
## Grown-ups area: parental gate, then Custom settings, play timer, support link and help.
## The gate asks a multiplication in words, answered on a number pad. No personal data is asked.

signal back_requested
signal play_requested

const UiKit := preload("res://ui/ui_kit.gd")
const NUMBER_WORDS := ["zero", "one", "two", "three", "four", "five", "six", "seven", "eight", "nine"]
const LOCK_HELP := (
	"Keep your child inside the app\n\n"
	+ "Android: Settings > Security (or Security & privacy) > App pinning. Turn it on, open this "
	+ "app, open Recent apps, tap the app icon and choose Pin. To unpin, hold Back and Overview "
	+ "(or swipe up and hold), then enter your PIN.\n\n"
	+ "iPhone/iPad: Settings > Accessibility > Guided Access. Turn it on, open this app and "
	+ "triple-click the side or Home button.")

var _answer := 0
var _entry := ""
var _question: Label
var _entry_label: Label
var _gate: Control


func _ready() -> void:
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = Color("#14202b")
	bg.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	add_child(bg)
	_build_gate()


func _build_gate() -> void:
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 20)
	_question = UiKit.label("", 36)
	_question.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(_question)
	_entry_label = UiKit.label("", 56)
	_entry_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(_entry_label)

	var pad := GridContainer.new()
	pad.columns = 3
	pad.add_theme_constant_override("h_separation", 16)
	pad.add_theme_constant_override("v_separation", 16)
	var keys := ["1", "2", "3", "4", "5", "6", "7", "8", "9", "Clear", "0", "OK"]
	for key in keys:
		var b := UiKit.tile(key, Color("#34495e"), Vector2(120, 110), 36)
		b.pressed.connect(_on_key.bind(key))
		pad.add_child(b)
	column.add_child(pad)

	var back := UiKit.tile("Back", Color("#555555"), Vector2(200, 100), 32)
	back.pressed.connect(back_requested.emit)
	column.add_child(back)

	_gate = UiKit.margin(column, 40)
	_gate.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	add_child(_gate)
	_new_question()


func _new_question() -> void:
	var a := randi_range(3, 9)
	var b := randi_range(3, 9)
	_answer = a * b
	_question.text = "Grown-ups only\nWhat is %s times %s?" % [NUMBER_WORDS[a], NUMBER_WORDS[b]]
	_entry = ""
	_entry_label.text = "_"


func _on_key(key: String) -> void:
	match key:
		"Clear":
			_entry = ""
		"OK":
			if _entry.is_valid_int() and int(_entry) == _answer:
				_gate.queue_free()
				_build_settings()
			else:
				_new_question()
			return
		_:
			if _entry.length() < 3:
				_entry += key
	_entry_label.text = _entry if not _entry.is_empty() else "_"


func _build_settings() -> void:
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	add_child(scroll)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 22)
	var framed := UiKit.margin(column)
	framed.size_flags_horizontal = SIZE_EXPAND_FILL
	scroll.add_child(framed)

	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 20)
	var back := UiKit.tile("Back", Color("#555555"), Vector2(150, 100), 32)
	back.pressed.connect(back_requested.emit)
	var play := UiKit.tile("Play Custom", Color("#27ae60"), Vector2(150, 100), 32)
	play.pressed.connect(_on_play)
	top.add_child(back)
	top.add_child(play)
	column.add_child(top)

	column.add_child(UiKit.label("Custom", 40))
	column.add_child(_option("Touch effect", Settings.EFFECT_NAMES, Settings.effect,
		func(i): Settings.effect = i))
	column.add_child(_option("Theme", Settings.THEME_NAMES, Settings.theme,
		func(i): Settings.theme = i))
	column.add_child(_option("Colours", Settings.PALETTE_NAMES, Settings.palette,
		func(i): Settings.palette = i))
	column.add_child(_option("Background animation", Settings.AMBIENT_NAMES, Settings.ambient,
		func(i): Settings.ambient = i))
	column.add_child(_toggle("Low stimulation (slower, softer)", Settings.low_stimulation,
		func(on): Settings.low_stimulation = on))

	column.add_child(UiKit.label("Sound and touch", 40))
	column.add_child(_toggle("Sound", Settings.sound_enabled, func(on): Settings.sound_enabled = on))
	column.add_child(_slider("Volume (capped for young ears)", Settings.volume,
		func(v): Settings.volume = v))
	column.add_child(_toggle("Vibration", Settings.haptics_enabled,
		func(on): Settings.haptics_enabled = on))

	column.add_child(UiKit.label("Play timer", 40))
	var timer_names: Array = []
	for m in Settings.TIMER_CHOICES:
		timer_names.append("Off" if m == 0 else "%d minutes" % m)
	column.add_child(_option("Fade out and rest after", timer_names,
		maxi(Settings.TIMER_CHOICES.find(Settings.timer_minutes), 0),
		func(i): Settings.timer_minutes = Settings.TIMER_CHOICES[i]))
	var restart := UiKit.tile("Restart play timer", Color("#2e86c1"), Vector2(300, 90), 28)
	restart.pressed.connect(Settings.reset_session)
	column.add_child(restart)

	column.add_child(UiKit.label("Play summary", 40))
	column.add_child(UiKit.label(
		"Recorded on this device only. Nothing is sent anywhere. Copy it to share with "
		+ "a therapist or teacher if you choose."))
	var summary := UiKit.label(PlayStats.summary_text(7))
	column.add_child(summary)
	var stats_row := HBoxContainer.new()
	stats_row.add_theme_constant_override("separation", 20)
	var copy := UiKit.tile("Copy summary", Color("#2e86c1"), Vector2(150, 90), 28)
	copy.pressed.connect(func():
		DisplayServer.clipboard_set(PlayStats.summary_text(7) + "\n\n" + PlayStats.summary_text(30))
		copy.text = "Copied")
	var wipe := UiKit.tile("Clear history", Color("#555555"), Vector2(150, 90), 28)
	wipe.pressed.connect(func():
		PlayStats.clear()
		summary.text = PlayStats.summary_text(7))
	stats_row.add_child(copy)
	stats_row.add_child(wipe)
	column.add_child(stats_row)

	column.add_child(UiKit.label("Support a charity", 40))
	column.add_child(UiKit.label(
		"This app is free. If you enjoy it, consider giving to a charity you choose. "
		+ "Add its donation page here (https only); it opens in your browser."))
	column.add_child(_text("Charity name", Settings.charity_name, func(t): Settings.charity_name = t))
	column.add_child(_text("https://", Settings.charity_url, func(t): Settings.charity_url = t.strip_edges()))
	var give := UiKit.tile("Open charity page", Color("#c0392b"), Vector2(300, 90), 28)
	give.pressed.connect(Settings.open_charity)
	column.add_child(give)

	column.add_child(UiKit.label(LOCK_HELP))


func _on_play() -> void:
	Settings.mode = "custom"
	Settings.save_settings()
	play_requested.emit()


func _option(title: String, items: Array, selected: int, apply: Callable) -> Control:
	var row := VBoxContainer.new()
	row.add_child(UiKit.label(title))
	var opt := OptionButton.new()
	opt.custom_minimum_size = Vector2(0, 80)
	for item in items:
		opt.add_item(item)
	opt.select(selected)
	opt.item_selected.connect(func(i):
		apply.call(i)
		Settings.save_settings())
	row.add_child(opt)
	return row


func _toggle(title: String, on: bool, apply: Callable) -> Control:
	var check := CheckButton.new()
	check.text = title
	check.button_pressed = on
	check.custom_minimum_size = Vector2(0, 80)
	check.toggled.connect(func(value):
		apply.call(value)
		Settings.save_settings())
	return check


func _slider(title: String, value: float, apply: Callable) -> Control:
	var row := VBoxContainer.new()
	row.add_child(UiKit.label(title))
	var slider := HSlider.new()
	slider.min_value = 0.0
	slider.max_value = 1.0
	slider.step = 0.05
	slider.value = value
	slider.custom_minimum_size = Vector2(0, 70)
	slider.value_changed.connect(func(v):
		apply.call(v)
		Settings.save_settings())
	row.add_child(slider)
	return row


func _text(placeholder: String, value: String, apply: Callable) -> Control:
	var edit := LineEdit.new()
	edit.placeholder_text = placeholder
	edit.text = value
	edit.custom_minimum_size = Vector2(0, 80)
	edit.text_changed.connect(func(t):
		apply.call(t)
		Settings.save_settings())
	return edit
