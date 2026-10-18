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
##
## A blocked hit that leaves no Stamina begins a Guard break, which lasts guard_break_duration.
## It begins as the hit lands, so he is not blocking from that moment, and it counts the
## physics frames Almos advances after it. The frame in which it runs out is still spent open;
## he is free from the next. A hit that is not blocked never starts one, nor does a hit in the
## middle of one, since he is not blocking in it. Almos decides what else he cannot do while
## it lasts. The placeholder of Almos is tinted for as long as it does.

## What his placeholder is tinted while a Guard break lasts, so that the player can see him
## left open. It is a look, not a tuning number.
const GUARD_BREAK_TINT := Color(1.0, 1.0, 0.1)

## What the numbers of Block come from. Almos gives his own tuning.
@export var tuning: PlayerTuning

## What each blocked hit spends.
@export var stamina: Stamina

## What is drawn while he is blocking. Optional.
@export var placeholder: CanvasItem

## What is tinted while a Guard break lasts: the placeholder of Almos himself. Optional.
@export var tinted_placeholder: CanvasItem

## Whether he is blocking.
var blocking: bool:
	get:
		return _blocking

## Whether a Guard break is on him.
var guard_broken: bool:
	get:
		return _broken

var _blocking := false
var _broken := false
var _broken_for := 0.0


## Lets one physics frame of this length, in seconds, go by. Called once per frame by Almos,
## who says whether he is free to block, which a Guard break rules out whatever he says. It
## reads the Block button itself, and only its held state: pressing it while he is not free
## does nothing until he is, if it is still held then. A Guard break is counted down here, in
## summed frame lengths compared with its duration through Almos's TIME_SLACK, as the Roll is.
func advance(free: bool, delta: float) -> void:
	_blocking = free and not _broken and Input.is_action_pressed(&"block")
	if placeholder != null:
		placeholder.visible = _blocking
	if _broken:
		_broken_for += delta
		if _broken_for >= tuning.guard_break_duration - Almos.TIME_SLACK:
			_end_guard_break()


## A hit lands on Almos, for this much damage, coming from this point in the world, while he
## stands at centre and faces this way (a unit vector). Returns how much of the damage gets
## through. Called by his Hurtbox for every hit that lands, and spends the Stamina of a hit
## it blocks, and begins a Guard break if that was the last of it, so it is to be called once
## for each.
func receive_hit(damage: float, from: Vector2, centre: Vector2, facing: Vector2) -> float:
	if not _blocks(from, centre, facing):
		return damage
	stamina.spend(tuning.block_stamina_cost)
	if stamina.current <= 0.0:
		_begin_guard_break()
	return damage * (1.0 - tuning.block_damage_reduction)


# Whether a hit that comes from this point is blocked: he is blocking, he has any Stamina left
# (which is exactly when Stamina.spend can spend), and the hit is in the front that Block
# covers. It only decides; spending the Stamina is for the caller.
func _blocks(from: Vector2, centre: Vector2, facing: Vector2) -> bool:
	return _blocking and stamina.current > 0.0 and _covers(from, centre, facing)


# Whether a hit that comes from this point is in the front that Block covers, for someone
# standing at centre and facing this way.
func _covers(from: Vector2, centre: Vector2, facing: Vector2) -> bool:
	var to_hit := from - centre
	# A hit from his own centre has no direction, and counts as from the front.
	if to_hit.is_zero_approx():
		return true
	return absf(facing.angle_to(to_hit)) <= deg_to_rad(tuning.block_arc_degrees) / 2.0


# A Guard break begins: he is not blocking from this moment, and the frames it lasts are
# counted by advance from the next one.
func _begin_guard_break() -> void:
	_broken = true
	_broken_for = 0.0
	_blocking = false
	if placeholder != null:
		placeholder.visible = false
	_tint(true)


func _end_guard_break() -> void:
	_broken = false
	_tint(false)


# The tint is set in the moment the Guard break begins or ends, not in Almos's next frame, so
# that what is drawn is never a frame behind it.
func _tint(on: bool) -> void:
	if tinted_placeholder != null:
		tinted_placeholder.modulate = GUARD_BREAK_TINT if on else Color.WHITE
