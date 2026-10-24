extends Node
## Placeholder sound engine, autoloaded as `Sfx`.
## One generated soft tone, pitched to a pentatonic scale so any tapping sounds musical.
## TODO: per-style sample packs (original or CC0 only). The public API stays the same.

const MAX_VOICES := 8
const VOLUME_CAP := 0.6  # hard ceiling relative to device volume (spec 7.3)
const PENTATONIC := [0, 2, 4, 7, 9]
const BASE_HZ := 261.63  # C4

var fade := 1.0  # wind-down level, set by the canvas

var _players: Array[AudioStreamPlayer] = []
var _next := 0


func _ready() -> void:
	var tone := _make_tone(BASE_HZ, 0.9)
	for i in MAX_VOICES:
		var player := AudioStreamPlayer.new()
		player.stream = tone
		add_child(player)
		_players.append(player)


## x_norm: horizontal position 0..1 (left = low, right = high). intensity: 0..1.
func play_touch(x_norm: float, intensity: float) -> void:
	if not Settings.sound_enabled or fade <= 0.0:
		return
	var step := clampi(int(x_norm * 10.0), 0, 9)
	var semitone: int = PENTATONIC[step % 5] + 12 * int(step / 5.0)
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


func _make_tone(freq: float, seconds: float) -> AudioStreamWAV:
	var rate := 44100
	var n := int(rate * seconds)
	var data := PackedByteArray()
	data.resize(n * 2)
	for i in n:
		var t := float(i) / rate
		var attack := minf(t / 0.02, 1.0)  # soft onset, no click (spec 7.3)
		var release := clampf((seconds - t) / 0.05, 0.0, 1.0)
		var env := attack * release * exp(-t * 4.0)
		var s := (sin(TAU * freq * t) + 0.3 * sin(TAU * freq * 2.0 * t)) / 1.3
		data.encode_s16(i * 2, int(s * env * 0.8 * 32767.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = rate
	wav.stereo = false
	wav.data = data
	return wav
