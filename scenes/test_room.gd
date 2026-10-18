extends Node2D
## The test room: a floor, walls, Almos, a Checkpoint and the HUD. Killing an enemy gives Almos
## its Experience. Resting at the Checkpoint makes it his return point and brings back every
## ordinary enemy the room started with as new; a named enemy stays dead. Until Death arrives,
## it starts over when Almos's Health reaches zero.

## Emitted when the room is to start over, which is when Almos's Health reaches zero.
signal restart_requested

## Where Almos goes back to, in global coordinates: the Checkpoint he last rested at, or where he
## started in the room until he first rests. Read only.
var return_point: Vector2:
	get:
		return _return_point

@onready var _almos: Almos = $Almos

var _return_point := Vector2.ZERO
# The ordinary enemies the room started with, each as the place and the numbers it was made
# with, and the enemy that is alive in its place now.
var _ordinary_enemies: Array[OrdinaryEnemy] = []


# An ordinary enemy as the room first had it, to make it again as new.
class OrdinaryEnemy:
	var scene: PackedScene
	var parent: Node
	var node_name: StringName
	var position: Vector2
	var tuning: EnemyTuning
	var target: Node2D
	# The enemy that stands in this place now. It is gone once killed, until a rest brings it back.
	var current: Node


func _ready() -> void:
	_return_point = _almos.global_position
	_almos.health.depleted.connect(_on_almos_depleted)
	_almos.rested.connect(_on_almos_rested)
	for enemy in get_tree().get_nodes_in_group("enemies"):
		_watch_enemy(enemy)
		if not enemy.named:
			_remember(enemy)


## Has the enemy give Almos its Experience when it dies. Called for each enemy the room starts
## with, and again for any it brings back.
func _watch_enemy(enemy: Node) -> void:
	enemy.died.connect(_on_enemy_died.bind(enemy))


# Notes where an ordinary enemy starts and what it is made with, so that a rest can make it again.
func _remember(enemy: Node) -> void:
	var start := OrdinaryEnemy.new()
	start.scene = load(enemy.scene_file_path)
	start.parent = enemy.get_parent()
	start.node_name = enemy.name
	start.position = enemy.position
	start.tuning = enemy.tuning
	start.target = enemy.target
	start.current = enemy
	_ordinary_enemies.append(start)


# Almos rested: the Checkpoint is his return point, and every ordinary enemy comes back as new.
# One still alive is taken out of the tree at once, so that it leaves the "enemies" group in this
# frame, and a fresh one is made at its starting place. A named enemy is not in the list, so it is
# left as it is. A fresh enemy is added last, so that it comes after Almos in the tree: he is
# processed before enemies, and the frame guarantees of his Parry rely on it.
func _on_almos_rested(checkpoint: Checkpoint) -> void:
	_return_point = checkpoint.global_position
	for start in _ordinary_enemies:
		if is_instance_valid(start.current):
			start.current.get_parent().remove_child(start.current)
			start.current.queue_free()
		var fresh = start.scene.instantiate()
		fresh.name = start.node_name
		fresh.position = start.position
		fresh.tuning = start.tuning
		fresh.target = start.target
		start.parent.add_child(fresh)
		_watch_enemy(fresh)
		start.current = fresh


func _on_enemy_died(enemy: Node) -> void:
	_almos.experience.gain(enemy.tuning.experience)


func _on_almos_depleted() -> void:
	restart_requested.emit()
	# Only the room that is the running scene reloads itself. One placed inside something
	# else, such as a test, only announces the restart: reloading the scene would replace
	# the whole tree it sits in.
	if get_tree().current_scene == self:
		get_tree().reload_current_scene()
