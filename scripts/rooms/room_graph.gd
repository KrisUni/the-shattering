class_name RoomGraph
extends Resource
## Which Rooms a place is made of and how their exits join them, as data. An exit is named
## "<room>/<exit>", and each one lists the exit it leads to, which is where Almos arrives:
## at that exit's Entrance. Both directions of a way between two Rooms are listed.

## The Room Almos starts in.
@export var start_room: StringName

## The scene of each Room, by the Room's id.
@export var rooms: Dictionary[StringName, String] = {}

## The exit each exit leads to, both named "<room>/<exit>".
@export var exits: Dictionary[String, String] = {}


## The names of the exits of a Room, in the order the graph lists them.
func exits_of(room: StringName) -> Array[StringName]:
	var names: Array[StringName] = []
	for exit_id in exits:
		if room_of_exit(exit_id) == room:
			names.append(exit_name_of(exit_id))
	return names


## The exit, named "<room>/<exit>", that an exit of a Room leads to, or "" if the Room has no
## such exit.
func destination_of(room: StringName, exit_name: StringName) -> String:
	return exits.get("%s/%s" % [room, exit_name], "")


## Every exit whose destination is missing, is in or leads to a Room the graph does not have, or does not
## lead back to it, in the order they are listed.
func unmatched_exits() -> Array[String]:
	var unmatched: Array[String] = []
	for exit_id in exits:
		var destination: String = exits[exit_id]
		var known := rooms.has(room_of_exit(exit_id)) and rooms.has(room_of_exit(destination))
		if not known or exits.get(destination, "") != exit_id:
			unmatched.append(exit_id)
	return unmatched


## Every Room that cannot be got to from the start room by going through exits, in the order
## the graph lists the Rooms.
func unreachable_rooms() -> Array[StringName]:
	var reached: Dictionary[StringName, bool] = {start_room: true}
	var to_visit: Array[StringName] = [start_room]
	while not to_visit.is_empty():
		var room: StringName = to_visit.pop_back()
		for exit_name in exits_of(room):
			var next := room_of_exit(destination_of(room, exit_name))
			if not reached.has(next):
				reached[next] = true
				to_visit.append(next)
	var unreachable: Array[StringName] = []
	for room in rooms:
		if not reached.has(room):
			unreachable.append(room)
	return unreachable


## The Room an exit named "<room>/<exit>" is in.
static func room_of_exit(exit_id: String) -> StringName:
	return StringName(exit_id.get_slice("/", 0))


## The name an exit named "<room>/<exit>" has in its Room.
static func exit_name_of(exit_id: String) -> StringName:
	return StringName(exit_id.get_slice("/", 1))
