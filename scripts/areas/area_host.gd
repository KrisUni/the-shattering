class_name AreaHost
extends Node
## Holds the space Almos is in, loads the next when he goes through a Doorway, and fades the
## screen over the load. There is one space in it at a time, and one Almos, who is carried from
## space to space.
##
## It also sees to what Almos's rests and Deaths do to the world. A space is made new whenever it is
## loaded, so its ordinary enemies are back, and it takes the world it finds in WorldState: its burnt
## path blockers open, its defeated named enemies gone, its Remains where they lay. Resting at a
## Checkpoint saves the changes made to the world and makes the space Almos is in new on the spot,
## and the Checkpoint is where he returns to. His Death takes his Experience as Remains where he
## fell, undoes the changes made since the last rest, and loads the space of his return point.

## Tells that a space has been put in the host, with that space: the first one, and each one
## loaded through a Doorway. The live Almos is in it and in place.
signal space_entered(space: Space)
## Tells that a space is about to be taken out and freed, with that space.
signal space_left(space: Space)

## The scene of the space Almos starts in.
@export_file("*.tscn") var start: String
## How the load fades.
@export var tuning: AreaLoadTuning

const REMAINS_SCENE := preload("res://scenes/world/remains.tscn")

## The space Almos is in.
var current_space: Space
## The one Almos, whichever space he is in.
var almos: Almos
## Whether a space is being loaded: from Almos going through a Doorway until the screen is back.
var loading := false

var _fade: ColorRect
# Where Almos goes back to: the scene of the space, and the place in it. The start until he first
# rests, then the Checkpoint he last rested at.
var _return_scene := ""
var _return_point := Vector2.ZERO
# Where Almos's Health last reached zero, and the area of the space he was in then, which is where
# the Remains of that Death are left.
var _fall_place := Vector2.ZERO
var _fall_area := &""


func _ready() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 100
	_fade = ColorRect.new()
	_fade.color = Color.BLACK
	_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade.modulate.a = 0.0
	layer.add_child(_fade)
	add_child(layer)
	var first := _instantiate(start)
	if first == null:
		return
	# The space's own Almos is the live one to begin with.
	_put_in(first)
	almos = first.almos
	_return_scene = start
	_return_point = almos.global_position
	almos.rested.connect(_on_almos_rested)
	almos.died.connect(_on_almos_fell)
	almos.death_pause_over.connect(_on_almos_death_pause_over)
	_leave_remains_in(first)
	space_entered.emit(first)


func _instantiate(path: String) -> Space:
	var scene := load(path) as PackedScene if ResourceLoader.exists(path) else null
	if scene == null:
		push_warning("no space to load at '%s'" % path)
		return null
	return scene.instantiate() as Space


# The space becomes the one Almos is in, and the area WorldState is asked about. A named enemy it
# has that was defeated is taken out before it is built.
func _put_in(space: Space) -> void:
	current_space = space
	WorldState.current_area = space.area_id
	var defeated := space.find_children("*", "", true, false).filter(func(node: Node) -> bool:
		return node.is_in_group(&"enemies") and node.get(&"named") and WorldState.is_defeated(node.get(&"id")))
	for enemy: Node in defeated:
		enemy.get_parent().remove_child(enemy)
		enemy.free()
	add_child(space)
	for doorway: Doorway in space.find_children("*", "Doorway", true, false):
		doorway.used.connect(_on_doorway_used)


func _on_doorway_used(doorway: Doorway) -> void:
	# Moving a body is not allowed in the middle of the physics step the doorway was entered in.
	_load.call_deferred(doorway)


func _load(doorway: Doorway) -> void:
	# A Doorway entered in the frame of his Death leads nowhere: he is on his way back.
	if loading or almos.dead:
		return
	var next := _instantiate(doorway.destination)
	if next == null:
		return
	var arrival := next.doorway(doorway.destination_entrance)
	if arrival == null:
		push_warning("%s has no doorway '%s' to arrive at" % [doorway.destination, doorway.destination_entrance])
		next.free()
		return
	await _change_space(next, next.arrive_at.bind(arrival))


# The space Almos is in is taken out and the new one put in its place, with Almos carried over. Once
# he is in the new space put_almos is called, to put him where he is to be. The screen fades out and
# in over it unless fade is false.
func _change_space(next: Space, put_almos: Callable, fade := true) -> void:
	loading = true
	# He stands still while the screen goes dark.
	almos.process_mode = Node.PROCESS_MODE_DISABLED
	if fade:
		await _fade_to(1.0)
	var left := current_space
	space_left.emit(left)
	left.almos.get_parent().remove_child(left.almos)
	remove_child(left)
	left.queue_free()
	next.adopt_almos(almos)
	_put_in(next)
	put_almos.call()
	_leave_remains_in(next)
	space_entered.emit(next)
	almos.process_mode = Node.PROCESS_MODE_INHERIT
	if fade:
		await _fade_to(0.0)
	loading = false


# Almos rested: the Checkpoint is his return point, what has changed in the world is saved, and the
# space he is in is made new where he stands, which brings back its ordinary enemies. That waits for
# the end of the frame, since he is in the middle of acting.
func _on_almos_rested(checkpoint: Checkpoint) -> void:
	_return_scene = current_space.scene_file_path
	_return_point = checkpoint.global_position
	WorldState.commit()
	_make_the_space_new.call_deferred()


func _make_the_space_new() -> void:
	if loading:
		return
	var next := _instantiate(current_space.scene_file_path)
	if next == null:
		return
	var place := almos.global_position
	await _change_space(next, next.put_almos_at.bind(place), false)


# Almos fell: the Remains are to be left here, once he is returned. The space he is in may be
# another by then, if he fell during a load.
func _on_almos_fell(place: Vector2) -> void:
	_fall_place = place
	_fall_area = current_space.area_id


# The pause of Almos's Death is over. The Experience he carries is the Remains' now, at the place and
# in the area he fell, in place of any there were; what has changed in the world since the last rest
# is undone; and he is sent back to the return point, in a space made new. The Remains are made after
# he is back, and notice him from the next frame, so that a return point close enough to them has him
# recover them at once.
func _on_almos_death_pause_over() -> void:
	while loading:
		await get_tree().physics_frame
	var lost := almos.experience.take_all()
	WorldState.set_remains(_fall_area, lost, _fall_place)
	WorldState.roll_back()
	var next := _instantiate(_return_scene)
	if next == null:
		return
	await _change_space(next, _send_almos_back.bind(next))


func _send_almos_back(space: Space) -> void:
	space.put_almos_at(_return_point)
	almos.return_to(_return_point)


# If WorldState has Remains in this space's area, they are put back where they lay. Almos recovering
# them takes them out of WorldState.
func _leave_remains_in(space: Space) -> void:
	var remains := WorldState.remains()
	if remains.is_empty() or remains["area_id"] != space.area_id:
		return
	var node := REMAINS_SCENE.instantiate() as Remains
	node.amount = remains["amount"]
	space.add_child(node)
	node.global_position = remains["place"]
	node.recovered.connect(_on_remains_recovered)


func _on_remains_recovered(_amount: int) -> void:
	WorldState.set_remains(&"", 0, Vector2.ZERO)


func _fade_to(alpha: float) -> void:
	if tuning == null or tuning.fade_seconds <= 0.0:
		_fade.modulate.a = alpha
		return
	var tween := create_tween()
	tween.tween_property(_fade, "modulate:a", alpha, tuning.fade_seconds)
	await tween.finished
