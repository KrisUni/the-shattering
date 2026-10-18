class_name Health
extends Node
## Something's Health: what it has left before it is done for. It takes no tuning of its
## own; whoever owns it gives it a maximum, so the same Health serves Almos and enemies.

## Emitted whenever current changes.
signal changed

## Emitted once, when current reaches zero.
signal depleted

## The most there can be. Giving it a maximum fills Health to it, so it is only given a
## different one.
@export var maximum: float:
	set(value):
		maximum = value
		_current = value

## How much is left. Change it with take_damage(), not by assigning.
var current: float:
	get:
		return _current

var _current: float


## Takes this much off, down to zero but never below. Nothing happens at zero.
func take_damage(amount: float) -> void:
	if _current <= 0.0:
		return
	_current = maxf(_current - amount, 0.0)
	changed.emit()
	if _current <= 0.0:
		depleted.emit()


## Fills it back up to its maximum, from wherever it was, even from zero. Resting at a
## Checkpoint does this.
func refill() -> void:
	_current = maximum
	changed.emit()
