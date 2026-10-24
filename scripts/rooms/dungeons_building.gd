class_name DungeonsBuilding
extends Building
## The Dungeons, built from its Room graph: each Room of the graph is its scene, put in a grid with
## a gap between, and each exit leads to the exit the graph lists for it. Almos starts in the
## graph's start Room, at the middle of it. It is built as the scene is instanced, so that the host
## sees the Rooms before the space is in the tree.

## Which Rooms there are and how their exits join them.
@export var graph: RoomGraph

# In pixels. The empty space left between neighbouring Rooms of the grid, so that no two Rooms overlap.
const GAP := 100.0
# How many Rooms there are in a row of the grid.
const COLUMNS := 5


func _notification(what: int) -> void:
	if what == NOTIFICATION_SCENE_INSTANTIATED:
		_build()


## The Room with this id in the graph, or null if there is none.
func room(id: StringName) -> Room:
	return get_node_or_null(NodePath(String(id))) as Room


func _build() -> void:
	if graph == null:
		push_warning("%s has no Room graph to build from" % name)
		return
	var index := 0
	for id in graph.rooms:
		var scene := load(graph.rooms[id]) as PackedScene
		if scene == null:
			push_warning("no Room scene at '%s'" % graph.rooms[id])
			continue
		var new_room := scene.instantiate() as Room
		new_room.name = id
		add_child(new_room)
		# Before Almos, the camera and the HUD, so that the Room's floor is drawn under them.
		move_child(new_room, index)
		new_room.position = Vector2(index % COLUMNS, index / COLUMNS) * (new_room.size + Vector2(GAP, GAP))
		index += 1
	for id in graph.rooms:
		var built := room(id)
		if built == null:
			continue
		for exit_name in graph.exits_of(id):
			var room_exit := built.get_node_or_null("Exits/%s" % exit_name) as RoomExit
			var destination := graph.destination_of(id, exit_name)
			if room_exit == null:
				push_warning("'%s' has no exit '%s'" % [id, exit_name])
				continue
			room_exit.target = _exit_at(destination)
	start_room = room(graph.start_room)
	if start_room != null and almos != null:
		almos.global_position = start_room.get_view_center()


# The exit named "<room>/<exit>", or null if the Dungeons has none.
func _exit_at(exit_id: String) -> RoomExit:
	var built := room(RoomGraph.room_of_exit(exit_id))
	if built == null:
		return null
	return built.get_node_or_null("Exits/%s" % RoomGraph.exit_name_of(exit_id)) as RoomExit
