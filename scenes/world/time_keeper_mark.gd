class_name TimeKeeperMark
extends Area2D
## The Time Keeper's mark in a room, drawn as a placeholder pale-blue circle. Almos gains his Mana bar
## by walking into it, once and for good: the mark is gone then, noted in WorldState under its id,
## so it is not there when the room is built again after a rest or a Death.

## What it is called in WorldState, stable across builds of the room. Each mark needs its own.
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
	WorldState.record_kept(id)
	almos.grant_mana_bar()
	queue_free()
