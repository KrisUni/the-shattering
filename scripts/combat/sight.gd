class_name Sight
extends RefCounted
## The cone in front of an enemy within which it can notice someone. Walls block it.


## Whether a point is in the Sight of someone at `from`, facing this way (a unit vector): inside
## the cone, which is arc_degrees wide with half of it either side and reaches `length` pixels,
## and with no wall between. `wall_mask` is the collision mask of the walls.
static func sees(space: PhysicsDirectSpaceState2D, from: Vector2, facing: Vector2, point: Vector2, arc_degrees: float, length: float, wall_mask: int) -> bool:
	if from.distance_to(point) > length:
		return false
	if not FrontArc.covers(point, from, facing, arc_degrees):
		return false
	var query := PhysicsRayQueryParameters2D.create(from, point, wall_mask)
	return space.intersect_ray(query).is_empty()
