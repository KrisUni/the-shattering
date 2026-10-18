class_name FrontArc
extends RefCounted
## The front of someone, judged the one way for everybody: Block and Parry on Almos, and
## the enemies that tell a hit from the front from one from behind.


## Whether a hit that comes from this point is in the front of someone standing at centre and
## facing this way (a unit vector), which is arc_degrees wide, half of it either side.
static func covers(from: Vector2, centre: Vector2, facing: Vector2, arc_degrees: float) -> bool:
	var to_hit := from - centre
	# A hit from the centre itself has no direction, and counts as from the front.
	if to_hit.is_zero_approx():
		return true
	return absf(facing.angle_to(to_hit)) <= deg_to_rad(arc_degrees) / 2.0
