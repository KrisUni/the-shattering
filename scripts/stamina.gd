class_name Stamina
extends Node
## Almos's Stamina: spent on actions, refilled by itself after a pause in spending.
## The numbers come from the PlayerTuning it is given.

## Emitted whenever current changes.
signal changed

@export var tuning: PlayerTuning:
	set(value):
		tuning = value
		_current = value.stamina_maximum

## How much is left. Change it with spend() and advance(), not by assigning.
var current: float:
	get:
		return _current

## The most there can be, from the tuning.
var maximum: float:
	get:
		return tuning.stamina_maximum

var _current: float
var _pause_left := 0.0


## Takes this much off, down to zero but never below. Returns whether it could be
## spent: always while there is any left, never at zero.
func spend(amount: float) -> bool:
	if _current <= 0.0:
		return false
	_current = maxf(_current - amount, 0.0)
	_pause_left = tuning.stamina_refill_pause
	changed.emit()
	return true


## Lets this much time, in seconds, go by: the pause counts down, then it refills.
func advance(delta: float) -> void:
	var paused_for := minf(delta, _pause_left)
	_pause_left -= paused_for
	var refilled := minf(_current + tuning.stamina_refill_rate * (delta - paused_for), maximum)
	if refilled != _current:
		_current = refilled
		changed.emit()


func _physics_process(delta: float) -> void:
	advance(delta)
