class_name OpenMapCamera
extends Camera2D
## The camera of an Open map: it follows a target, which is Almos, so the view is centred on him,
## except near the edge of the map, where it stops so that the view never shows beyond it and he
## is off-centre. It is a script of its own so that a Room, whose camera is fixed to the Room,
## can use another one in its place without the rest of the area noticing.

## The node the view is centred on.
@export var target: Node2D
## The extent of the map, in global coordinates, which the view stays inside. It is expected to
## be at least as big as the view; the map it belongs to sets it.
@export var bounds := Rect2()


func _physics_process(_delta: float) -> void:
	# In the physics step, after Almos has moved (the camera comes after him in the tree), so the
	# view never lags a frame behind him.
	if target == null:
		return
	# What the view covers is the viewport as the zoom shows it, so the clamp holds at any zoom.
	var half_view := get_viewport_rect().size / zoom / 2.0
	var lowest := bounds.position + half_view
	var highest := bounds.end - half_view
	global_position = target.global_position.clamp(lowest, highest)
