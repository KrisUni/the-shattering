extends Node
## The world state that outlasts a visit to an area: the ids of the path blockers that have burnt and
## of the pickups that have been taken, kept per area (the Space's area id; scenes that are not Spaces
## are in the area with the empty name).
## It is an autoload, so it lives as long as the game does. A change to the world is first pending:
## it is saved only when Almos rests at a Checkpoint (commit), and a Death undoes every change made
## since (roll_back). What is asked about the current area is answered from what is saved and what is
## pending. A path blocker records itself when it catches Fire, and starts open when the room is built
## if its id is recorded.
## Two things are saved at once and never rolled back: the one set of Remains, wherever it lies, and
## the named enemies that have been defeated.

## The area that is asked about and recorded into: the area id of the Space Almos is in.
var current_area: StringName = &""

# Per area id: a dictionary of ids, for what is saved and for what is pending.
var _saved_burnt: Dictionary = {}
var _saved_taken: Dictionary = {}
var _pending_burnt: Dictionary = {}
var _pending_taken: Dictionary = {}
# The one set of Remains: the area id, the amount and the place. Empty when there are none.
var _remains: Dictionary = {}
# The ids of the named enemies that have been defeated.
var _defeated: Dictionary = {}


## Notes that the path blocker with this id has burnt, in the current area. It is pending until the
## next commit.
func record_burnt(id: StringName) -> void:
	_ids(_pending_burnt)[id] = true


## Whether the path blocker with this id has burnt, saved or pending, in the current area.
func is_burnt(id: StringName) -> bool:
	return _ids(_saved_burnt).has(id) or _ids(_pending_burnt).has(id)


## Notes that the pickup with this id has been taken, in the current area. It is pending until the
## next commit, so a Death puts it back.
func record_taken(id: StringName) -> void:
	_ids(_pending_taken)[id] = true


## Notes that the pickup with this id has been taken, in the current area, and saves it at once: a
## Death does not put it back. For what Almos keeps through a Death, such as a Flask upgrade.
func record_kept(id: StringName) -> void:
	_ids(_saved_taken)[id] = true


## Whether the pickup with this id has been taken, saved or pending, in the current area.
func is_taken(id: StringName) -> bool:
	return _ids(_saved_taken).has(id) or _ids(_pending_taken).has(id)


## Leaves Remains holding this much Experience at this place (in global coordinates) in this area, in
## place of any set, wherever it lay. No Experience leaves none. It is saved at once.
func set_remains(area_id: StringName, amount: int, place: Vector2) -> void:
	if amount <= 0:
		_remains = {}
		return
	_remains = {"area_id": area_id, "amount": amount, "place": place}


## The Remains there are, as a dictionary of "area_id", "amount" and "place", or an empty one if
## there are none.
func remains() -> Dictionary:
	return _remains.duplicate()


## Notes that the named enemy with this id has been defeated. It is saved at once: a Death does not
## bring it back.
func record_defeated(id: StringName) -> void:
	_defeated[id] = true


## Whether the named enemy with this id has been defeated.
func is_defeated(id: StringName) -> bool:
	return _defeated.has(id)


## Saves every pending change, in every area. Almos has rested at a Checkpoint.
func commit() -> void:
	for area in _pending_burnt:
		_saved_burnt.get_or_add(area, {}).merge(_pending_burnt[area])
	for area in _pending_taken:
		_saved_taken.get_or_add(area, {}).merge(_pending_taken[area])
	_pending_burnt.clear()
	_pending_taken.clear()


## Undoes every pending change, in every area; what is saved stays. Almos has died.
func roll_back() -> void:
	_pending_burnt.clear()
	_pending_taken.clear()


## Forgets everything, in every area, and the current area. The game never does this; tests do,
## between tests.
func reset() -> void:
	_saved_burnt.clear()
	_saved_taken.clear()
	_pending_burnt.clear()
	_pending_taken.clear()
	_remains = {}
	_defeated.clear()
	current_area = &""


# The ids of the current area in this store, made when there are none yet.
func _ids(store: Dictionary) -> Dictionary:
	return store.get_or_add(current_area, {})
