class_name FlaskUpgrade
extends Area2D
## A Flask upgrade lying in a room, drawn as a placeholder flask. Almos takes it by walking over
## it: one charge is added to both his Flasks, and it is gone. It stays taken for good, noted in
## WorldState under its id, so it is not there when the room is built again after a rest or a Death.

## What it is called in WorldState, stable across builds of the room. Each upgrade needs its own.
@export var id: StringName


func _ready() -> void:
	if WorldState.is_taken(id):
		queue_free()
		return
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node2D) -> void:
	var almos := body as Almos
	if almos == null or WorldState.is_taken(id):
		return
	WorldState.record_taken(id)
	almos.flasks.add_charges(1)
	queue_free()
