class_name UiMotion
extends RefCounted

const INSTANT_STEP: float = 1000000.0

static func settle(tween: Tween) -> Tween:
	if Preferences.reduce_motion() and tween != null and tween.is_valid():
		tween.custom_step(INSTANT_STEP)
	return tween
