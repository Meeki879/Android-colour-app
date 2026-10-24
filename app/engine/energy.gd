extends RefCounted
## Tap-tempo "energy" (0..1). Each tap adds, and it decays exponentially.
## Drives effect speed and colour. Gain shrinks as energy rises, so whole-hand slapping
## approaches 1.0 smoothly instead of spiking.

const TAP_GAIN := 0.15
const DECAY_S := 1.2

var value := 0.0


func register_tap() -> void:
	value = minf(value + TAP_GAIN * (1.0 - value), 1.0)


func update(delta: float) -> void:
	value *= exp(-delta / DECAY_S)
