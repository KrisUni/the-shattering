class_name LightZone
extends Node2D
## A patch of the room with its own gameplay light, which enemies read at Almos's position to
## tell how far they see. It is kept apart from how the room is drawn: the placeholder look
## below only shows the player where it is. It is in the group "light_zones", and has no body.

## The gameplay light inside the zone, from 0 (dark) to 1 (full light).
@export_range(0.0, 1.0) var light := 0.0

## The zone's width and height, in pixels, centred on the node.
@export var size := Vector2(200.0, 200.0):
	set(value):
		size = value
		queue_redraw()


func _enter_tree() -> void:
	add_to_group("light_zones")


## The gameplay light at this point (global coordinates), given the zones and the torches to read:
## 1 outside every zone, and the darkest light of the zones the point is in. Within the radius of a
## lit torch the light is at least that torch's light, whatever the zones say; an unlit torch gives
## none.
static func light_at(zones: Array, point: Vector2, torches: Array = []) -> float:
	var lowest := 1.0
	for zone in zones:
		if zone.covers(point):
			lowest = minf(lowest, zone.light)
	for torch in torches:
		if torch.lights(point):
			lowest = maxf(lowest, torch.light)
	return lowest


## Whether the point (global coordinates) is inside the zone.
func covers(point: Vector2) -> bool:
	var local := to_local(point)
	return absf(local.x) <= size.x / 2.0 and absf(local.y) <= size.y / 2.0


func _draw() -> void:
	draw_rect(Rect2(-size / 2.0, size), Color(0.0, 0.0, 0.05, 0.55 * (1.0 - light)))
