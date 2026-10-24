extends Node
## Persistent settings, autoloaded as `Settings`. Stored locally only: the app collects no data.

signal changed

const PATH := "user://settings.cfg"

const STYLE_NAMES := ["Watercolour", "Disco", "Anime", "Space"]
const EFFECT_NAMES := ["Ripple", "Burst", "Glow"]
const PALETTE_NAMES := ["Rainbow", "Pastel", "Neon", "Ocean", "Nebula", "Bedtime"]

# Cosine palettes: colour(t) = a + b * cos(TAU * (c * t + d)). Order matches PALETTE_NAMES.
const PALETTES := [
	[Vector3(0.5, 0.5, 0.5), Vector3(0.5, 0.5, 0.5), Vector3(1.0, 1.0, 1.0), Vector3(0.0, 0.33, 0.67)],
	[Vector3(0.75, 0.7, 0.8), Vector3(0.25, 0.25, 0.2), Vector3(1.0, 1.0, 1.0), Vector3(0.0, 0.33, 0.67)],
	[Vector3(0.5, 0.5, 0.5), Vector3(0.5, 0.5, 0.5), Vector3(1.0, 1.0, 0.5), Vector3(0.8, 0.9, 0.3)],
	[Vector3(0.2, 0.5, 0.6), Vector3(0.2, 0.3, 0.35), Vector3(1.0, 1.0, 1.0), Vector3(0.0, 0.1, 0.2)],
	[Vector3(0.5, 0.35, 0.65), Vector3(0.5, 0.35, 0.35), Vector3(1.0, 1.0, 1.0), Vector3(0.6, 0.8, 0.2)],
	[Vector3(0.55, 0.3, 0.15), Vector3(0.3, 0.2, 0.1), Vector3(1.0, 1.0, 1.0), Vector3(0.0, 0.1, 0.2)],
]

# Per style, indexed like STYLE_NAMES.
const STYLE_DEFAULT_PALETTE := [1, 2, 0, 4]
# Fraction of the previous frame kept each frame (trails). Capped at 0.85: higher values leave
# permanent faint ghosts in an 8-bit render target because the fade rounds back to the same value.
const STYLE_PERSISTENCE := [0.85, 0.4, 0.0, 0.7]

const TIMER_CHOICES := [0, 5, 10, 15, 20, 30]

var mode := "simple"
var style := 3
var palette := 0
var effect := 0
var sound_enabled := true
var volume := 0.7
var haptics_enabled := true
var low_stimulation := false
var timer_minutes := 0
var charity_name := ""
var charity_url := ""
var safety_notice_seen := false

# Play session clock for the wind-down timer. Not persisted: survives leaving the canvas,
# resets on app restart or from the Grown-ups area.
var _session_start_ms := -1


func _ready() -> void:
	load_settings()


func load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(PATH) != OK:
		return
	mode = cfg.get_value("play", "mode", mode)
	style = clampi(cfg.get_value("play", "style", style), 0, STYLE_NAMES.size() - 1)
	palette = clampi(cfg.get_value("play", "palette", palette), 0, PALETTES.size() - 1)
	effect = clampi(cfg.get_value("play", "effect", effect), 0, EFFECT_NAMES.size() - 1)
	low_stimulation = cfg.get_value("play", "low_stimulation", low_stimulation)
	sound_enabled = cfg.get_value("sound", "enabled", sound_enabled)
	volume = clampf(cfg.get_value("sound", "volume", volume), 0.0, 1.0)
	haptics_enabled = cfg.get_value("haptics", "enabled", haptics_enabled)
	timer_minutes = cfg.get_value("timer", "minutes", timer_minutes)
	charity_name = cfg.get_value("support", "charity_name", charity_name)
	charity_url = cfg.get_value("support", "charity_url", charity_url)
	safety_notice_seen = cfg.get_value("app", "safety_notice_seen", safety_notice_seen)


func save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("play", "mode", mode)
	cfg.set_value("play", "style", style)
	cfg.set_value("play", "palette", palette)
	cfg.set_value("play", "effect", effect)
	cfg.set_value("play", "low_stimulation", low_stimulation)
	cfg.set_value("sound", "enabled", sound_enabled)
	cfg.set_value("sound", "volume", volume)
	cfg.set_value("haptics", "enabled", haptics_enabled)
	cfg.set_value("timer", "minutes", timer_minutes)
	cfg.set_value("support", "charity_name", charity_name)
	cfg.set_value("support", "charity_url", charity_url)
	cfg.set_value("app", "safety_notice_seen", safety_notice_seen)
	cfg.save(PATH)
	changed.emit()


## Simple mode is a fixed calm preset; only the art style is chosen (by the child on Home).
func active_effect() -> int:
	return 0 if mode == "simple" else effect


func active_palette() -> int:
	return STYLE_DEFAULT_PALETTE[style] if mode == "simple" else palette


func start_session_if_needed() -> void:
	if _session_start_ms < 0:
		_session_start_ms = Time.get_ticks_msec()


func reset_session() -> void:
	_session_start_ms = -1


## Seconds of play left, or INF when the timer is off.
func timer_remaining_s() -> float:
	if timer_minutes <= 0:
		return INF
	var total := timer_minutes * 60.0
	if _session_start_ms < 0:
		return total
	return maxf(total - (Time.get_ticks_msec() - _session_start_ms) / 1000.0, 0.0)


func is_rest_time() -> bool:
	return timer_remaining_s() <= 0.0


## Only https links are opened, in the system browser. Called from behind the parental gate.
func open_charity() -> bool:
	if not charity_url.begins_with("https://"):
		return false
	return OS.shell_open(charity_url) == OK
