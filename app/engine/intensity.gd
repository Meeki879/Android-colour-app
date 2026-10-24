extends RefCounted
## Touch intensity (0..1) from signals every device reports reliably (spec section 6).
## Most phones report no real finger pressure, so pressure is not used.
## TODO: blend in stylus pressure when the input device reports it.


static func for_tap(energy: float) -> float:
	return clampf(0.45 + 0.55 * energy, 0.0, 1.0)


## Holding a finger down "charges" the ripple released when it lifts.
static func for_hold(seconds: float) -> float:
	return clampf(0.3 + seconds / 2.5, 0.3, 1.0)


static func for_drag(speed_cm_s: float) -> float:
	return clampf(speed_cm_s / 40.0, 0.1, 0.8)
