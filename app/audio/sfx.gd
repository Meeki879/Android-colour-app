extends Node
## Placeholder sound engine, autoloaded as `Sfx`.
## Each theme gets its own generated instrument and five-note scale, so any tapping sounds musical.
## Notes rise from left to right across the screen.
## TODO: replace generated tones with recorded sample packs (original or CC0 only). API stays.

const MAX_VOICES := 8
const VOLUME_CAP := 0.6  # hard ceiling relative to device volume (spec 7.3)
const MIX_RATE := 22050

# Indexed like Settings.THEME_NAMES.
const THEME_SOUNDS := [
	{"timbre": "marimba", "base_hz": 261.63, "scale": [0, 2, 4, 7, 9]},  # Simple: C major pentatonic
	{"timbre": "piano", "base_hz": 196.0, "scale": [0, 2, 4, 7, 9]},  # Watercolour: G major pentatonic
	{"timbre": "pluck", "base_hz": 220.0, "scale": [0, 3, 5, 7, 10]},  # Disco: A minor pentatonic
	{"timbre": "bell", "base_hz": 293.66, "scale": [0, 2, 5, 7, 9]},  # Anime: Japanese yo scale on D
	{"timbre": "pad", "base_hz": 130.81, "scale": [0, 3, 5, 7, 10]},  # Space: C minor pentatonic, low
]

var fade := 1.0  # wind-down level, set by the canvas

var _players: Array[AudioStreamPlayer] = []
var _next := 0
var _scale: Array = THEME_SOUNDS[0]["scale"]
var _tones := {}  # timbre -> AudioStreamWAV, generated on first use


func _ready() -> void:
	for i in MAX_VOICES:
		var player := AudioStreamPlayer.new()
		add_child(player)
		_players.append(player)
	set_theme(0)


func set_theme(theme: int) -> void:
	var sound: Dictionary = THEME_SOUNDS[clampi(theme, 0, THEME_SOUNDS.size() - 1)]
	var timbre: String = sound["timbre"]
	if not _tones.has(timbre):
		_tones[timbre] = _make_tone(timbre, sound["base_hz"])
	_scale = sound["scale"]
	for player in _players:
		player.stop()
		player.stream = _tones[timbre]


## x_norm: horizontal position 0..1 (left = low, right = high). intensity: 0..1.
func play_touch(x_norm: float, intensity: float) -> void:
	if not Settings.sound_enabled or fade <= 0.0:
		return
	var step := clampi(int(x_norm * 10.0), 0, 9)
	var semitone: int = _scale[step % 5] + 12 * int(step / 5.0)
	var player := _take_voice()
	player.pitch_scale = pow(2.0, semitone / 12.0)
	var gain := Settings.volume * VOLUME_CAP * (0.35 + 0.65 * clampf(intensity, 0.0, 1.0)) * fade
	player.volume_db = linear_to_db(maxf(gain, 0.0001))
	player.play()


## Placeholder: sound when effects meet (e.g. ripples crossing).
func play_interaction(_x_norm: float, _strength: float) -> void:
	pass


## Free voice first; otherwise steal the oldest, so fast tapping never stacks into noise.
func _take_voice() -> AudioStreamPlayer:
	for player in _players:
		if not player.playing:
			return player
	var stolen := _players[_next]
	_next = (_next + 1) % MAX_VOICES
	return stolen


func _make_tone(timbre: String, freq: float) -> AudioStreamWAV:
	var seconds := 0.9
	var attack_s := 0.015  # soft onset, no click (spec 7.3)
	match timbre:
		"bell":
			seconds = 1.4
		"pad":
			seconds = 1.6
			attack_s = 0.08
	var n := int(MIX_RATE * seconds)
	var samples := PackedFloat32Array()
	samples.resize(n)
	var peak := 0.0001
	for i in n:
		var t := float(i) / MIX_RATE
		var w := TAU * freq * t
		var s := 0.0
		match timbre:
			"marimba":
				s = (sin(w) + 0.25 * sin(4.0 * w) * exp(-t * 20.0)) * exp(-t * 6.0)
			"piano":
				s = (sin(w) + 0.5 * sin(2.0 * w) * exp(-t * 2.0) + 0.25 * sin(3.0 * w) * exp(-t * 4.0)) * exp(-t * 3.0)
			"pluck":
				s = (sin(w) + sin(3.0 * w) * exp(-t * 9.0) / 3.0 + sin(5.0 * w) * exp(-t * 15.0) / 5.0) * exp(-t * 7.0)
			"bell":
				s = (sin(w) + 0.6 * sin(2.76 * w) * exp(-t * 3.0) + 0.3 * sin(5.4 * w) * exp(-t * 6.0)) * exp(-t * 2.5)
			"pad":
				s = (sin(w) + 0.8 * sin(w * 1.005) + 0.3 * sin(2.0 * w)) * exp(-t * 1.5)
		var attack := minf(t / attack_s, 1.0)
		var release := clampf((seconds - t) / 0.05, 0.0, 1.0)
		s *= attack * release
		samples[i] = s
		peak = maxf(peak, absf(s))
	var data := PackedByteArray()
	data.resize(n * 2)
	for i in n:
		data.encode_s16(i * 2, int(samples[i] / peak * 0.8 * 32767.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = MIX_RATE
	wav.stereo = false
	wav.data = data
	return wav
