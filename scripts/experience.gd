class_name Experience
extends Node
## The Experience someone carries: what has been gained by killing enemies and not yet cashed
## in. It takes no tuning; what each kill is worth is the enemy's own.

## Emitted whenever total changes.
signal changed

## How much there is. Change it with gain() and take_all(), not by assigning.
var total: int:
	get:
		return _total

var _total: int


## Adds this much. Only a positive amount does anything.
func gain(amount: int) -> void:
	if amount <= 0:
		return
	_total += amount
	changed.emit()


## Takes all of it, returning how much that was and leaving none. Nothing changes when there
## is none.
func take_all() -> int:
	var taken := _total
	if taken > 0:
		_total = 0
		changed.emit()
	return taken
