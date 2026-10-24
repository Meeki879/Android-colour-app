extends Node
## Intensity-scaled vibration, autoloaded as `Haptics`.
## Android export needs the VIBRATE permission enabled in the export preset.

const MIN_GAP_MS := 60  # fast tapping must not turn into one continuous buzz

var _last_ms := -MIN_GAP_MS


func pulse(intensity: float) -> void:
	if not Settings.haptics_enabled or not OS.has_feature("mobile"):
		return
	var now := Time.get_ticks_msec()
	if now - _last_ms < MIN_GAP_MS:
		return
	_last_ms = now
	var k := clampf(intensity, 0.0, 1.0)
	Input.vibrate_handheld(int(8.0 + 30.0 * k), 0.2 + 0.8 * k)
