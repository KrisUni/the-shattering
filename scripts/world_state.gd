extends Node
## The world state that outlasts resting and Death: the ids of the path blockers that have burnt.
## It is an autoload, so it lives as long as the game does. A path blocker records itself when it
## catches Fire, and starts open when the room is built if its id is recorded.

var _burnt: Dictionary = {}


## Notes that the path blocker with this id has burnt, for good.
func record_burnt(id: StringName) -> void:
	_burnt[id] = true


## Whether the path blocker with this id has burnt.
func is_burnt(id: StringName) -> bool:
	return _burnt.has(id)


## Forgets every burnt path blocker. The game never does this; tests do, between tests.
func reset() -> void:
	_burnt.clear()
