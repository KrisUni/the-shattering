class_name Remains
extends Area2D
## The Remains: a placeholder marker left where Almos died, holding the Experience he lost. He
## recovers it by touching them, with no button: it goes back to him and the Remains are gone.
## They are in the group "remains". They have no body, so he walks through them, and they notice
## his body only: not an enemy's, and not Almos while he lies limp or is in the air.

## Emitted once, when Almos reaches them, with how much Experience he got back.
signal recovered(amount: int)

## How much Experience they hold. Whoever places them sets it, before they enter the scene.
@export var amount := 0

## The shape that Almos has to touch, a CollisionShape2D under the Remains.
@export var touch_shape: CollisionShape2D


func _physics_process(_delta: float) -> void:
	var almos := _almos_touching()
	if almos != null:
		_recover(almos)


# The Almos on his feet whose body touches the shape, or null. The physics space is asked now,
# not the Area's list of what overlaps it: that list is made from the pairs found when a body
# moves or the Area enters the scene, and for a frame or two after Almos is sent somewhere else in
# the very frame the Remains are made it still holds him at the place he left.
func _almos_touching() -> Almos:
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = touch_shape.shape
	query.transform = touch_shape.global_transform
	query.collision_mask = collision_mask
	for hit in get_world_2d().direct_space_state.intersect_shape(query):
		var almos := hit["collider"] as Almos
		if almos != null and not almos.dead:
			return almos
	return null


# The Experience goes back to Almos, and they are gone: out of the scene at once, so that they
# leave the group in this frame.
func _recover(almos: Almos) -> void:
	almos.experience.gain(amount)
	recovered.emit(amount)
	get_parent().remove_child(self)
	queue_free()
