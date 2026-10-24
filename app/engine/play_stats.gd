extends Node
## On-device play statistics, autoloaded as `PlayStats`.
## Nothing leaves the device. A grown-up can view the summary in the Grown-ups area and copy it
## to share by choice (e.g. with a therapist, or with the developer during family testing).

const PATH := "user://play_stats.json"
const KEEP_DAYS := 90
const MAX_SESSIONS := 1000
const MIN_SESSION_S := 2.0  # shorter visits are accidental opens, not play
const HIGH_ENERGY := 0.7  # sustained fast tapping; can signal excitement or agitation

var _sessions: Array = []
var _current: Dictionary = {}


func _ready() -> void:
	_load()


func begin(theme: int, mode: String, effect: int, low_stimulation: bool) -> void:
	end("interrupted")
	_current = {
		"start": int(Time.get_unix_time_from_system()),
		"seconds": 0.0,
		"touches": 0,
		"max_fingers": 0,
		"high_energy_s": 0.0,
		"theme": theme,
		"mode": mode,
		"effect": effect,
		"low_stim": low_stimulation,
		"rested": false,
		"end": "",
	}


func tick(delta: float, energy: float) -> void:
	if _current.is_empty():
		return
	_current["seconds"] += delta
	if energy >= HIGH_ENERGY:
		_current["high_energy_s"] += delta


func touch(fingers_down: int) -> void:
	if _current.is_empty():
		return
	_current["touches"] += 1
	_current["max_fingers"] = maxi(_current["max_fingers"], fingers_down)


func mark_rest() -> void:
	if not _current.is_empty():
		_current["rested"] = true


## reason: "corner" (grown-up or child exit), "app_left" (backgrounded), "left", "interrupted".
func end(reason: String) -> void:
	if _current.is_empty():
		return
	_current["end"] = reason
	if _current["seconds"] >= MIN_SESSION_S:
		_sessions.append(_current)
		_prune()
		_save()
	_current = {}


func clear() -> void:
	_sessions.clear()
	_save()


func summary(days: int) -> Dictionary:
	var since := int(Time.get_unix_time_from_system()) - days * 86400
	var bias_s := int(Time.get_time_zone_from_system().get("bias", 0)) * 60
	var result := {
		"sessions": 0, "seconds": 0.0, "touches": 0, "high_energy_s": 0.0,
		"rested": 0, "days_played": 0, "max_fingers": 0, "favourite_theme": -1,
	}
	var days_seen := {}
	var theme_seconds := {}
	for s in _sessions:
		if s["start"] < since:
			continue
		result["sessions"] += 1
		result["seconds"] += s["seconds"]
		result["touches"] += int(s["touches"])
		result["high_energy_s"] += s["high_energy_s"]
		result["max_fingers"] = maxi(result["max_fingers"], int(s["max_fingers"]))
		if s["rested"]:
			result["rested"] += 1
		days_seen[int((s["start"] + bias_s) / 86400)] = true
		var theme := int(s.get("theme", 0))
		theme_seconds[theme] = theme_seconds.get(theme, 0.0) + s["seconds"]
	result["days_played"] = days_seen.size()
	var best := -1.0
	for theme in theme_seconds:
		if theme_seconds[theme] > best:
			best = theme_seconds[theme]
			result["favourite_theme"] = theme
	return result


func summary_text(days: int) -> String:
	var s := summary(days)
	if s["sessions"] == 0:
		return "No play recorded in the last %d days." % days
	var minutes: float = s["seconds"] / 60.0
	var lines := PackedStringArray([
		"Last %d days" % days,
		"Days played: %d of %d" % [s["days_played"], days],
		"Sessions: %d (average %.1f min)" % [s["sessions"], minutes / s["sessions"]],
		"Total play: %.0f min" % minutes,
		"Touches per minute: %.0f" % (s["touches"] / maxf(minutes, 0.01)),
		"Fast-tapping time: %.0f%%" % (100.0 * s["high_energy_s"] / maxf(s["seconds"], 0.01)),
		"Most fingers at once: %d" % s["max_fingers"],
		"Sessions ended by play timer: %d" % s["rested"],
	])
	if s["favourite_theme"] >= 0:
		lines.append("Favourite theme: %s" % Settings.THEME_NAMES[s["favourite_theme"]])
	return "\n".join(lines)


func _prune() -> void:
	var cutoff := int(Time.get_unix_time_from_system()) - KEEP_DAYS * 86400
	_sessions = _sessions.filter(func(s): return s["start"] >= cutoff)
	if _sessions.size() > MAX_SESSIONS:
		_sessions = _sessions.slice(_sessions.size() - MAX_SESSIONS)


func _load() -> void:
	var file := FileAccess.open(PATH, FileAccess.READ)
	if file == null:
		return
	var data = JSON.parse_string(file.get_as_text())
	if data is Array:
		_sessions = data


func _save() -> void:
	var file := FileAccess.open(PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(_sessions))
