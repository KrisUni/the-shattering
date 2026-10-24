class_name AreaHost
extends Node
## Holds the space Almos is in, loads the next when he goes through a Doorway, and fades the
## screen over the load. There is one space in it at a time, and one Almos, who is carried from
## space to space.

## Tells that a space has been put in the host, with that space: the first one, and each one
## loaded through a Doorway. The live Almos is in it and in place.
signal space_entered(space: Space)
## Tells that a space is about to be taken out and freed, with that space.
signal space_left(space: Space)

## The scene of the space Almos starts in.
@export_file("*.tscn") var start: String
## How the load fades.
@export var tuning: AreaLoadTuning

## The space Almos is in.
var current_space: Space
## The one Almos, whichever space he is in.
var almos: Almos
## Whether a space is being loaded: from Almos going through a Doorway until the screen is back.
var loading := false

var _fade: ColorRect


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
	space_entered.emit(first)


func _instantiate(path: String) -> Space:
	var scene := load(path) as PackedScene if ResourceLoader.exists(path) else null
	if scene == null:
		push_warning("no space to load at '%s'" % path)
		return null
	return scene.instantiate() as Space


func _put_in(space: Space) -> void:
	current_space = space
	add_child(space)
	for doorway: Doorway in space.find_children("*", "Doorway", true, false):
		doorway.used.connect(_on_doorway_used)


func _on_doorway_used(doorway: Doorway) -> void:
	# Moving a body is not allowed in the middle of the physics step the doorway was entered in.
	_load.call_deferred(doorway)


func _load(doorway: Doorway) -> void:
	if loading:
		return
	var next := _instantiate(doorway.destination)
	if next == null:
		return
	var arrival := next.doorway(doorway.destination_entrance)
	if arrival == null:
		push_warning("%s has no doorway '%s' to arrive at" % [doorway.destination, doorway.destination_entrance])
		next.free()
		return
	loading = true
	# He stands still while the screen goes dark.
	almos.process_mode = Node.PROCESS_MODE_DISABLED
	await _fade_to(1.0)
	var left := current_space
	space_left.emit(left)
	left.almos.get_parent().remove_child(left.almos)
	remove_child(left)
	left.queue_free()
	next.adopt_almos(almos)
	_put_in(next)
	next.arrive_at(arrival)
	space_entered.emit(next)
	almos.process_mode = Node.PROCESS_MODE_INHERIT
	await _fade_to(0.0)
	loading = false


func _fade_to(alpha: float) -> void:
	if tuning == null or tuning.fade_seconds <= 0.0:
		_fade.modulate.a = alpha
		return
	var tween := create_tween()
	tween.tween_property(_fade, "modulate:a", alpha, tuning.fade_seconds)
	await tween.finished
