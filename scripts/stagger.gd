class_name Stagger
extends Node
## An enemy's Stagger: the meter that hits build and that drains again once they stop. It
## takes no tuning of its own; whoever owns it gives it a capacity and the drain, so the same
## Stagger serves any enemy. It is separate from Health and never touches it. What a full
## meter does is not its business: it stays at the capacity.

## Emitted whenever current changes.
signal changed

## The most there can be. A full meter is this much.
@export var capacity: float

## How much drains each second once the pause is over.
@export var drain_rate: float

## How long, in seconds, nothing has to be added before it starts to drain.
@export var drain_pause: float

## How much there is, from 0 up to the capacity. Change it with add() and advance(), not by
## assigning.
var current: float:
	get:
		return _current

## Whether it is at the capacity.
var full: bool:
	get:
		return _current >= capacity

var _current := 0.0
var _pause_left := 0.0


## Puts this much on, up to the capacity but never beyond, and starts the pause again. Adding
## nothing still starts it again: any hit counts as pressing the enemy.
func add(amount: float) -> void:
	_pause_left = drain_pause
	var added := minf(_current + amount, capacity)
	if added != _current:
		_current = added
		changed.emit()


## Empties the meter, as a Break does when it begins. The pause is left as it is.
func reset() -> void:
	if _current != 0.0:
		_current = 0.0
		changed.emit()


## Lets this much time, in seconds, go by: the pause counts down, then it drains.
func advance(delta: float) -> void:
	var paused_for := minf(delta, _pause_left)
	_pause_left -= paused_for
	var drained := maxf(_current - drain_rate * (delta - paused_for), 0.0)
	if drained != _current:
		_current = drained
		changed.emit()


func _physics_process(delta: float) -> void:
	advance(delta)
