extends Control
## Full-screen touch canvas. Turns touches into effect slots for render/canvas_fx.gdshader.
## Exit: hold the top-left corner for EXIT_HOLD_S seconds.

signal exit_requested

const Energy := preload("res://engine/energy.gd")
const Intensity := preload("res://engine/intensity.gd")
const FX_SHADER := preload("res://render/canvas_fx.gdshader")

enum Kind { RIPPLE, BURST, GLOW }

const MAX_EFFECTS := 64  # must match the uniform array size in the shader
const LIFETIME := {Kind.RIPPLE: 3.0, Kind.BURST: 1.2}  # must match the shader
const GLOW_FADE := 0.8
const BASE_SPEED_CM := 6.0
const TRAIL_SPACING_CM := 0.8
const HOLD_RELEASE_S := 0.35  # holds longer than this release a charged ripple
const EXIT_HOLD_S := 3.0
const CORNER_CM := 1.5
const WIND_DOWN_S := 60.0
const IDLE_AFTER_S := 3.0
const TIME_REBASE_S := 600.0  # keeps shader time small; low-end GPUs lose precision on big floats

var _energy := Energy.new()
var _material := ShaderMaterial.new()
var _viewport: SubViewport
var _overlay: CornerOverlay
var _effects: Array = []
var _pointers := {}  # touch index -> {pos, start, glow, last_trail}
var _t := 0.0
var _idle_for := 0.0
var _units_per_cm := 60.0
var _speed_mult := 1.0
var _hue_base := 0.0
var _corner_index := -1
var _corner_start := 0.0
var _rest_marked := false


func _ready() -> void:
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)

	var container := SubViewportContainer.new()
	container.stretch = true
	container.mouse_filter = MOUSE_FILTER_IGNORE
	container.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	add_child(container)

	_viewport = SubViewport.new()
	_viewport.disable_3d = true
	_viewport.gui_disable_input = true
	# Cleared once, then never: each frame blends over the last, which produces trails.
	_viewport.render_target_clear_mode = SubViewport.CLEAR_MODE_ONCE
	container.add_child(_viewport)

	var rect := ColorRect.new()
	rect.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	rect.mouse_filter = MOUSE_FILTER_IGNORE
	_material.shader = FX_SHADER
	rect.material = _material
	_viewport.add_child(rect)

	_overlay = CornerOverlay.new()
	_overlay.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	_overlay.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(_overlay)

	resized.connect(_on_resized)
	_on_resized()
	_apply_settings()
	Settings.start_session_if_needed()
	_begin_stats()


func _exit_tree() -> void:
	Sfx.fade = 1.0
	PlayStats.end("left")


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED:
		PlayStats.end("app_left")
	elif what == NOTIFICATION_APPLICATION_RESUMED:
		_begin_stats()


func _begin_stats() -> void:
	PlayStats.begin(Settings.style, Settings.mode, Settings.active_effect(), Settings.low_stimulation)


func _apply_settings() -> void:
	var simple := Settings.mode == "simple"
	_speed_mult = (0.75 if simple else 1.0) * (0.6 if Settings.low_stimulation else 1.0)
	var pal: Array = Settings.PALETTES[Settings.active_palette()]
	_material.set_shader_parameter("pal_a", pal[0])
	_material.set_shader_parameter("pal_b", pal[1])
	_material.set_shader_parameter("pal_c", pal[2])
	_material.set_shader_parameter("pal_d", pal[3])
	_material.set_shader_parameter("style", Settings.style)
	_material.set_shader_parameter("persistence", Settings.STYLE_PERSISTENCE[Settings.style])
	var saturation := 0.6 if Settings.low_stimulation else (0.9 if simple else 1.0)
	_material.set_shader_parameter("saturation", saturation)


func _on_resized() -> void:
	var dpi := DisplayServer.screen_get_dpi()
	if dpi <= 0:
		dpi = 160
	var window := Vector2(DisplayServer.window_get_size())
	var view := get_viewport().get_visible_rect().size
	_units_per_cm = dpi / 2.54 * view.x / maxf(window.x, 1.0)


func _process(delta: float) -> void:
	_t += delta
	_energy.update(delta)
	for p in _pointers.values():
		var glow: Dictionary = p["glow"]
		glow["end"] = _t
	_effects = _effects.filter(func(e): return not _is_dead(e))
	_update_corner()
	var master := _wind_down_level()
	Sfx.fade = master
	PlayStats.tick(delta, _energy.value)
	if master <= 0.0 and not _rest_marked:
		_rest_marked = true
		PlayStats.mark_rest()
	_upload(master)
	_update_idle(delta, master)


func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed:
			_on_down(event.index, event.position)
		else:
			_on_up(event.index, event.position)
	elif event is InputEventScreenDrag:
		_on_drag(event.index, event.position, event.velocity)


func _on_down(index: int, pos: Vector2) -> void:
	if _corner_index < 0 and _in_corner(pos):
		_corner_index = index
		_corner_start = _t
	if Settings.is_rest_time():
		return
	_energy.register_tap()
	_hue_base += 0.07
	var intensity := Intensity.for_tap(_energy.value)
	var kind := Settings.active_effect()
	if kind != Kind.GLOW:
		_spawn(kind, pos, intensity)
	var glow := _spawn(Kind.GLOW, pos, 0.5 + 0.3 * intensity)
	glow["held"] = true
	_pointers[index] = {"pos": pos, "start": _t, "glow": glow, "last_trail": pos}
	PlayStats.touch(_pointers.size())
	_feedback(pos, intensity)


func _on_up(index: int, pos: Vector2) -> void:
	if index == _corner_index:
		_corner_index = -1
	if not _pointers.has(index):
		return
	var p: Dictionary = _pointers[index]
	_pointers.erase(index)
	var glow: Dictionary = p["glow"]
	glow["held"] = false
	glow["end"] = _t
	var held: float = _t - p["start"]
	if held >= HOLD_RELEASE_S:
		var intensity := Intensity.for_hold(held)
		_spawn(Kind.RIPPLE, pos, intensity)
		_feedback(pos, intensity)


func _on_drag(index: int, pos: Vector2, velocity: Vector2) -> void:
	if index == _corner_index and not _in_corner(pos):
		_corner_index = -1
	if not _pointers.has(index):
		return
	var p: Dictionary = _pointers[index]
	p["pos"] = pos
	var glow: Dictionary = p["glow"]
	glow["pos"] = pos
	if pos.distance_to(p["last_trail"]) >= TRAIL_SPACING_CM * _units_per_cm:
		p["last_trail"] = pos
		_spawn(Kind.BURST, pos, Intensity.for_drag(velocity.length() / _units_per_cm))


func _spawn(kind: int, pos: Vector2, intensity: float) -> Dictionary:
	var e := {
		"kind": kind,
		"pos": pos,
		"start": _t,
		"end": _t,
		"intensity": clampf(intensity, 0.05, 1.0),
		"hue": fposmod(_hue_base, 1.0),
		"speed": BASE_SPEED_CM * _speed_mult * (1.0 + 1.5 * _energy.value),
		"held": false,
	}
	if _effects.size() >= MAX_EFFECTS:
		_effects.pop_front()
	_effects.append(e)
	_idle_for = 0.0
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	return e


func _feedback(pos: Vector2, intensity: float) -> void:
	Sfx.play_touch(pos.x / maxf(size.x, 1.0), intensity)
	Haptics.pulse(intensity)


func _is_dead(e: Dictionary) -> bool:
	if e["kind"] == Kind.GLOW:
		return not e["held"] and _t - e["end"] > GLOW_FADE
	return _t - e["start"] > LIFETIME[e["kind"]]


func _upload(master: float) -> void:
	var a := PackedColorArray()
	var b := PackedColorArray()
	a.resize(MAX_EFFECTS)
	b.resize(MAX_EFFECTS)
	for i in _effects.size():
		var e: Dictionary = _effects[i]
		var pos: Vector2 = e["pos"]
		a[i] = Color(pos.x, pos.y, e["start"], e["intensity"])
		b[i] = Color(float(e["kind"]), e["hue"], e["speed"], e["end"])
	_material.set_shader_parameter("fx_a", a)
	_material.set_shader_parameter("fx_b", b)
	_material.set_shader_parameter("fx_count", _effects.size())
	_material.set_shader_parameter("time_now", _t)
	_material.set_shader_parameter("rect_size", Vector2(_viewport.size))
	_material.set_shader_parameter("units_per_cm", _units_per_cm)
	_material.set_shader_parameter("energy", _energy.value)
	_material.set_shader_parameter("master", master)


## Stops rendering when nothing moves, to save battery. Ambient animation (stars, sparkle)
## pauses too, which is acceptable for a still screen.
func _update_idle(delta: float, master: float) -> void:
	var fading := master > 0.0 and master < 1.0
	if not _effects.is_empty() or not _pointers.is_empty() or fading:
		_idle_for = 0.0
		return
	_idle_for += delta
	if _idle_for > IDLE_AFTER_S and _viewport.render_target_update_mode != SubViewport.UPDATE_DISABLED:
		_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
		if _t > TIME_REBASE_S:
			_t = 0.0


func _wind_down_level() -> float:
	return clampf(Settings.timer_remaining_s() / WIND_DOWN_S, 0.0, 1.0)


func _in_corner(pos: Vector2) -> bool:
	var zone := CORNER_CM * _units_per_cm
	return pos.x <= zone and pos.y <= zone


func _update_corner() -> void:
	var progress := 0.0
	if _corner_index >= 0:
		progress = (_t - _corner_start) / EXIT_HOLD_S
		if progress >= 1.0:
			_corner_index = -1
			PlayStats.end("corner")
			exit_requested.emit()
			return
	_overlay.set_progress(progress, CORNER_CM * _units_per_cm)


class CornerOverlay extends Control:
	var progress := 0.0
	var zone := 90.0

	func set_progress(p: float, zone_size: float) -> void:
		if is_equal_approx(p, progress) and is_equal_approx(zone_size, zone):
			return
		progress = p
		zone = zone_size
		queue_redraw()

	func _draw() -> void:
		# Brief taps in the corner show nothing, so toddlers do not learn the exit.
		if progress < 0.15:
			return
		var centre := Vector2(zone, zone) * 0.5
		draw_arc(centre, zone * 0.35, -PI / 2.0, -PI / 2.0 + TAU * progress, 48, Color(1, 1, 1, 0.9), 6.0, true)
