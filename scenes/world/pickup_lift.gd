class_name PickupLift
extends Node2D
## A thing picked up rises off the floor as it is taken: a copy of how it looked lifts a little and
## fades away where it lay, while the thing itself is gone at once, as ever. Only a look.

## How far it rises, in art pixels, and how long it takes, in seconds.
const RISE := 12.0
const LASTING := 0.45


## Leaves a copy of this thing's look rising where it lies, in its own parent.
static func lift(thing: Node2D) -> PickupLift:
	var look := thing.get_node_or_null(^"Look") as Node2D
	var parent := thing.get_parent()
	if look == null or parent == null:
		return null
	var copy := PickupLift.new()
	parent.add_child(copy)
	copy.global_position = thing.global_position
	copy.z_index = thing.z_index + 1
	for part in look.get_children():
		var drawn := part as CanvasItem
		if drawn == null or not drawn.visible or drawn is Glint:
			continue
		# A plain copy: no scripts, signals or groups come with it.
		copy.add_child(part.duplicate(0))
	var rise := copy.create_tween()
	rise.set_parallel(true)
	rise.tween_property(copy, ^"position:y", copy.position.y - RISE, LASTING).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	rise.tween_property(copy, ^"modulate:a", 0.0, LASTING).set_ease(Tween.EASE_IN)
	rise.chain().tween_callback(copy.queue_free)
	return copy
