extends Node
## Persistent settings, autoloaded as `Settings`. Stored locally only: the app collects no data.

signal changed

const PATH := "user://settings.cfg"

# Themes are the worlds the child picks on Home: background, blend style and sound set.
const THEME_NAMES := ["Simple", "Watercolour", "Disco", "Anime", "Space"]
# Touch effects, modelled on reactive RGB keyboard modes.
const EFFECT_NAMES := ["Ripple", "Cross lines", "Glow"]
# Background animation that runs without touches (keyboard "breathing", "wave", "spectrum").
const AMBIENT_NAMES := ["Off", "Breathing", "Wave", "Spectrum"]

# Colour schemes as 2-5 stops, blended in a loop. "Dynamic" and "Sports Fusion" are the first two
# keyboard palettes on colorany.com; their near-black and grey stops are left out because they
# are invisible as light.
const PALETTE_NAMES := ["Rainbow", "Dynamic", "Sports Fusion", "Pastel", "Ocean", "Nebula", "Bedtime"]
const PALETTES := [
	["#ff3b30", "#ffcc00", "#34c759", "#0a84ff", "#bf5af2"],
	["#ff5733", "#c70039", "#900c3f", "#f0f0f0"],
	["#c8102e", "#ffc700", "#0072b8", "#ffffff"],
	["#ffb3ba", "#ffdfba", "#baffc9", "#bae1ff", "#e3c6ff"],
	["#00b4d8", "#0077b6", "#48cae4", "#90e0ef", "#023e8a"],
	["#7b2ff7", "#f107a3", "#00d2ff", "#5c3dff"],
	["#ff9e5e", "#e0603a", "#b8463a", "#7a3b5e"],
]

# Per theme, indexed like THEME_NAMES.
const THEME_DEFAULT_PALETTE := [0, 3, 2, 3, 5]
const THEME_DEFAULT_AMBIENT := [0, 0, 2, 0, 0]
# Fraction of the previous frame kept each frame (trails). Capped at 0.85: higher values leave
# permanent faint ghosts in an 8-bit render target because the fade rounds back to the same value.
const THEME_PERSISTENCE := [0.5, 0.85, 0.4, 0.0, 0.7]

const TIMER_CHOICES := [0, 5, 10, 15, 20, 30]

var mode := "simple"
var theme := 0
var palette := 0
var effect := 0
var ambient := 0
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
	theme = clampi(cfg.get_value("play", "theme", theme), 0, THEME_NAMES.size() - 1)
	palette = clampi(cfg.get_value("play", "palette", palette), 0, PALETTES.size() - 1)
	effect = clampi(cfg.get_value("play", "effect", effect), 0, EFFECT_NAMES.size() - 1)
	ambient = clampi(cfg.get_value("play", "ambient", ambient), 0, AMBIENT_NAMES.size() - 1)
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
	cfg.set_value("play", "theme", theme)
	cfg.set_value("play", "palette", palette)
	cfg.set_value("play", "effect", effect)
	cfg.set_value("play", "ambient", ambient)
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


## Simple mode is a fixed calm preset per theme; Custom uses the Grown-ups choices.
func active_effect() -> int:
	return 0 if mode == "simple" else effect


func active_palette() -> int:
	return THEME_DEFAULT_PALETTE[theme] if mode == "simple" else palette


func active_ambient() -> int:
	return THEME_DEFAULT_AMBIENT[theme] if mode == "simple" else ambient


## Palette stops as vec3 colours for the shader, padded to the shader's 5 slots.
func palette_stops(index: int) -> PackedVector3Array:
	var stops := PackedVector3Array()
	for hex in PALETTES[index]:
		var c := Color(hex)
		stops.append(Vector3(c.r, c.g, c.b))
	while stops.size() < 5:
		stops.append(stops[0])
	return stops


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
