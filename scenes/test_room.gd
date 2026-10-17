extends Node2D
## The test room: a floor, walls, Almos and the HUD. Until Death arrives, it starts over
## when Almos's Health reaches zero.

## Emitted when the room is to start over, which is when Almos's Health reaches zero.
signal restart_requested

@onready var _almos: Node2D = $Almos


func _ready() -> void:
	_almos.health.depleted.connect(_on_almos_depleted)


func _on_almos_depleted() -> void:
	restart_requested.emit()
	# Only the room that is the running scene reloads itself. One placed inside something
	# else, such as a test, only announces the restart: reloading the scene would replace
	# the whole tree it sits in.
	if get_tree().current_scene == self:
		get_tree().reload_current_scene()
