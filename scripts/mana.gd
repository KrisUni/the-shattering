class_name Mana
extends Node
## Almos's Mana: the bar a Spell is paid from once he has it. He has no bar at first; grant() gives
## it, once and for good, at the size it is given, and it starts full. It never refills by itself:
## only refill() and restore() bring it back.

## Emitted whenever the bar or its amount changes, including when it is granted.
signal changed

## Whether he has the bar. Until he does, the maximum and the amount are both zero.
var granted: bool:
	get:
		return _granted

## The most there can be: zero until the bar is granted.
var maximum: float:
	get:
		return _maximum

## How much is left. Change it with spend(), restore() and refill(), not by assigning.
var current: float:
	get:
		return _current

var _granted := false
var _maximum := 0.0
var _current := 0.0


## Gives him the bar at this size, full. Done once: a bar he already has is left as it is.
func grant(bar_maximum: float) -> void:
	if _granted:
		return
	_granted = true
	_maximum = bar_maximum
	_current = bar_maximum
	changed.emit()


## Takes this much off, down to zero but never below.
func spend(amount: float) -> void:
	if not _granted:
		return
	_current = maxf(_current - amount, 0.0)
	changed.emit()


## Puts this much back, up to the maximum but never above it.
func restore(amount: float) -> void:
	if not _granted:
		return
	_current = minf(_current + amount, _maximum)
	changed.emit()


## Fills it back up to its maximum, from wherever it was. Resting at a Checkpoint and the return
## after a Death do this. Without the bar there is nothing to fill.
func refill() -> void:
	if not _granted:
		return
	_current = _maximum
	changed.emit()
