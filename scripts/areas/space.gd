class_name Space
extends Node2D
## What the host loads: an Open map or a building of Rooms, with its own Almos and camera so that
## it also works on its own. Hosted, the host puts the live Almos in place of that one, and
## Doorways in it lead to other spaces.

## Names the space for good, so that what is known of it can be kept under that name. Never
## changes once it is given.
@export var area_id: StringName
## Almos, who is in the space.
@export var almos: Almos


## The Doorway in this space with this name, or null if there is none.
func doorway(doorway_name: StringName) -> Doorway:
	return find_child(String(doorway_name), true, false) as Doorway


## Puts this Almos in the space in place of its own, which is thrown away: the same node, with all
## his state, so that he is the same Almos in every space. The camera and the HUD bars are pointed
## at him. It is done before the space is in the tree, when nothing has started to follow its own
## Almos yet.
func adopt_almos(live: Almos) -> void:
	if live == almos:
		return
	var parent := almos.get_parent()
	var index := almos.get_index()
	parent.remove_child(almos)
	almos.queue_free()
	# At the same place among its siblings, so the camera still comes after him in the tree.
	parent.add_child(live)
	parent.move_child(live, index)
	almos = live
	for camera: OpenMapCamera in find_children("*", "OpenMapCamera", true, false):
		camera.target = live
	for bar: HealthBar in find_children("*", "HealthBar", true, false):
		bar.health = live.health
	for bar: StaminaBar in find_children("*", "StaminaBar", true, false):
		bar.stamina = live.stamina


## Puts Almos at the Entrance of this Doorway of the space, and the camera on him, as he is when he
## has come through it. The space is in the tree.
func arrive_at(arrival: Doorway) -> void:
	almos.global_position = arrival.entrance.global_position
	_on_arrived(arrival)


## Called when Almos has arrived at a Doorway, once he is in place: what the space does to show
## him there. An Open map's camera is put on him.
func _on_arrived(_arrival: Doorway) -> void:
	for camera: OpenMapCamera in find_children("*", "OpenMapCamera", true, false):
		camera.snap_to_target()
