class_name KeyCrate
extends StaticBody2D
## A single crate that holds the Jailer's key. It is solid, as a crate stack is, and stays where it
## stands (it is not liftable). The key inside it (its child Key) is taken with a tap of Interact
## beside the crate. Once the key is gone, now or in an earlier visit, the crate stands open and
## empty, its lid up against its back.

const CLOSED := preload("res://assets/dungeons/furniture/key_crate.png")
const OPEN := preload("res://assets/dungeons/furniture/key_crate_open.png")

@onready var _art: Sprite2D = $Look/Art


func _ready() -> void:
	var key := get_node_or_null("Key") as JailersKey
	if key == null or key.is_queued_for_deletion():
		_show_open()
	else:
		_art.texture = CLOSED
		key.tree_exiting.connect(_show_open)


## Whether it stands open: the key is no longer in it.
func is_open() -> bool:
	return _art.texture == OPEN


func _show_open() -> void:
	_art.texture = OPEN
