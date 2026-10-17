class_name AlmosBlock
extends Node
## Almos's Block: whether he is blocking, and what a hit that lands on him does while he is.
##
## He is blocking while the Block button is held and Almos is free, which Almos says every
## frame: he is not in a Roll, not tied up in an attack (swinging, or charging a Heavy
## attack) and not sprinting. Holding the button costs nothing. Holding it with no Stamina
## left still counts as blocking, but protects nothing.
##
## A hit that lands is blocked when he is blocking, Stamina has any left, and the hit comes
## from the front that Block covers: block_arc_degrees wide, centred on the way Almos faces. A
## blocked hit spends block_stamina_cost and deals only the part of its damage that
## block_damage_reduction does not take off. Any other hit deals all of its damage and
## spends nothing.

## What the numbers of Block come from. Almos gives his own tuning.
@export var tuning: PlayerTuning

## What each blocked hit spends.
@export var stamina: Stamina

## What is drawn while he is blocking. Optional.
@export var placeholder: CanvasItem

## Whether he is blocking.
var blocking: bool:
	get:
		return _blocking

var _blocking := false


## Lets one physics frame go by. Called once per frame by Almos, who says whether he is free
## to block. It reads the Block button itself, and only its held state: pressing it while he
## is not free does nothing until he is, if it is still held then.
func advance(free: bool) -> void:
	_blocking = free and Input.is_action_pressed(&"block")
	if placeholder != null:
		placeholder.visible = _blocking


## A hit lands on Almos, for this much damage, coming from this point in the world, while he
## stands at centre and faces this way (a unit vector). Returns how much of the damage gets
## through. Called by his Hurtbox for every hit that lands, and spends the Stamina of a hit
## it blocks, so it is to be called once for each.
func receive_hit(damage: float, from: Vector2, centre: Vector2, facing: Vector2) -> float:
	if not _blocking or not _covers(from, centre, facing) or not stamina.spend(tuning.block_stamina_cost):
		return damage
	return damage * (1.0 - tuning.block_damage_reduction)


# Whether a hit that comes from this point is in the front that Block covers, for someone
# standing at centre and facing this way.
func _covers(from: Vector2, centre: Vector2, facing: Vector2) -> bool:
	var to_hit := from - centre
	# A hit from his own centre has no direction, and counts as from the front.
	if to_hit.is_zero_approx():
		return true
	return absf(facing.angle_to(to_hit)) <= deg_to_rad(tuning.block_arc_degrees) / 2.0
