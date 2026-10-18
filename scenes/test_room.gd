extends Node2D
## The test room: a floor, walls, Almos and the HUD. Killing an enemy gives Almos its
## Experience. Until Death arrives, it starts over when Almos's Health reaches zero.

## Emitted when the room is to start over, which is when Almos's Health reaches zero.
signal restart_requested

@onready var _almos: Almos = $Almos


func _ready() -> void:
	_almos.health.depleted.connect(_on_almos_depleted)
	for enemy in get_tree().get_nodes_in_group("enemies"):
		_watch_enemy(enemy)


## Has the enemy give Almos its Experience when it dies. Called for each enemy the room starts
## with, and again for any it brings back.
func _watch_enemy(enemy: Node) -> void:
	enemy.died.connect(_on_enemy_died.bind(enemy))


func _on_enemy_died(enemy: Node) -> void:
	_almos.experience.gain(enemy.tuning.experience)


func _on_almos_depleted() -> void:
	restart_requested.emit()
	# Only the room that is the running scene reloads itself. One placed inside something
	# else, such as a test, only announces the restart: reloading the scene would replace
	# the whole tree it sits in.
	if get_tree().current_scene == self:
		get_tree().reload_current_scene()
