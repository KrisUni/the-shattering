class_name Building
extends Space
## A building made of Rooms. The camera is fixed to the Room Almos is in; when he leaves it
## through a RoomExit he is put at the Entrance of the paired exit, in the next Room, and the
## camera moves there. Rooms are its children, side by side in world space and not overlapping.

## Tells that Almos has come into a Room, with the Room he is in now.
signal room_changed(room: Room)

## The Room Almos starts in.
@export var start_room: Room

## How long a pursuing enemy waits at an exit before it follows Almos through it.
@export var pursuit_tuning: RoomPursuitTuning

## The Room Almos is in.
var current_room: Room

# An enemy on its way through an exit after Almos: the exit it goes to, and the physics frames it
# still has to wait at it, which is -1 until it has got there.
class Follow:
	var enemy: Node2D
	var room_exit: RoomExit
	var frames_left := -1

var _follows: Array[Follow] = []

# The exit Almos last left each Room by, which an enemy that comes out in the Room after he has gone follows.
var _last_exit_from: Dictionary[Room, RoomExit] = {}

@onready var _camera: Camera2D = $Camera


func _ready() -> void:
	for child in get_children():
		for room_exit in child.find_children("*", "RoomExit", true, false):
			room_exit.used.connect(_on_exit_used)
	current_room = start_room
	_camera.global_position = current_room.get_view_center()
	for enemy: Node2D in get_tree().get_nodes_in_group(&"enemies"):
		if is_ancestor_of(enemy) and not is_instance_valid(enemy.get(&"target")):
			enemy.set(&"target", almos)


func _physics_process(_delta: float) -> void:
	for follow in _follows.duplicate():
		_advance(follow)


func _on_exit_used(room_exit: RoomExit) -> void:
	# Moving a body is not allowed in the middle of the physics step the exit was entered in.
	_travel.call_deferred(room_exit)


func _travel(room_exit: RoomExit) -> void:
	var target := room_exit.target
	if target == null:
		push_warning("%s has no exit to go to" % room_exit.name)
		return
	var left_room := room_exit.get_room()
	_last_exit_from[left_room] = room_exit
	almos.global_position = target.entrance.global_position
	current_room = target.get_room()
	_camera.global_position = current_room.get_view_center()
	_send_pursuers_after(room_exit, left_room)
	room_changed.emit(current_room)


# Every enemy in Pursuit in the Room Almos has just left goes to the exit he used.
func _send_pursuers_after(room_exit: RoomExit, left_room: Room) -> void:
	for enemy: Node2D in get_tree().get_nodes_in_group(&"enemies"):
		if left_room.is_ancestor_of(enemy) and enemy.get(&"in_pursuit") and not enemy.get(&"dead") and not _is_following(enemy):
			_start_following(enemy, room_exit)


func _is_following(enemy: Node2D) -> bool:
	for follow in _follows:
		if follow.enemy == enemy:
			return true
	return false


func _start_following(enemy: Node2D, room_exit: RoomExit) -> void:
	var follow := Follow.new()
	follow.enemy = enemy
	follow.room_exit = room_exit
	_follows.append(follow)
	enemy.call(&"begin_follow", room_exit.global_position)


# One physics frame of an enemy's way through an exit: it walks to it, waits the delay there, and
# comes out of the paired exit in the next Room.
func _advance(follow: Follow) -> void:
	if not is_instance_valid(follow.enemy) or follow.enemy.get(&"dead"):
		_follows.erase(follow)
		return
	if follow.frames_left < 0:
		if not follow.enemy.get(&"follow_arrived"):
			return
		follow.frames_left = ceili(pursuit_tuning.follow_delay_seconds * Engine.physics_ticks_per_second)
	else:
		follow.frames_left -= 1
	if follow.frames_left > 0:
		return
	_follows.erase(follow)
	_come_out(follow.enemy, follow.room_exit.target)


# The enemy itself is carried to the Entrance of this exit, in its Room, with all it has. If Almos
# is in that Room it goes on after him; if he has left it already, it goes to the exit he left by.
func _come_out(enemy: Node2D, entry: RoomExit) -> void:
	if entry == null:
		enemy.call(&"end_follow", enemy.global_position)
		return
	var room := entry.get_room()
	enemy.reparent(room)
	enemy.global_position = entry.entrance.global_position
	if room == current_room:
		enemy.call(&"end_follow", almos.global_position)
	elif _last_exit_from.has(room):
		_start_following(enemy, _last_exit_from[room])
	else:
		# Almos is elsewhere and left no trace here: it stands where it is and loses him in time.
		enemy.call(&"end_follow", enemy.global_position)


## Almos has come through a Doorway into the Room it is in, which the camera is then fixed to.
func _on_arrived(arrival: Doorway) -> void:
	var node := arrival.get_parent()
	while node != null and not node is Room:
		node = node.get_parent()
	if node == null:
		push_warning("%s is not in a Room" % arrival.name)
		return
	current_room = node as Room
	_camera.global_position = current_room.get_view_center()
	room_changed.emit(current_room)


## Almos has been put at a place: the Room that has it is the one he is in, which the camera is then
## fixed to. A place outside every Room leaves the Room he was in.
func _on_placed() -> void:
	for child in get_children():
		var room := child as Room
		if room != null and room.get_rect().has_point(almos.global_position):
			current_room = room
	_camera.global_position = current_room.get_view_center()
	room_changed.emit(current_room)
