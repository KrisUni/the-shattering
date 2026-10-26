class_name AlmosJump
extends Node
## Almos's Jump: a press of the Jump button carries him on a straight line, at the velocity he
## had on the frame he took off, for jump_duration. He cannot steer it, and it gives no
## invulnerability: Almos decides when he is free to begin one, and what else he cannot do
## while it lasts. It spends jump_stamina_cost when it begins, which may be nothing.
##
## Height. The game has two height levels, 0 for the ground and 1 for a low ledge. On the
## ground the sides of gaps and ledges block him like walls; in the air only real walls do, so
## a Jump passes over gaps, over ledge sides and over enemies. Where he comes down sets his
## level: inside a ledge puts him on it, at level 1, where the ledge's own edges keep him in;
## anywhere else is the ground, level 0. Coming down inside a gap is a Deadly fall in a later
## Task; for now it puts him back where the Jump began, at the level he took off from.
##
## He is counted down in summed frame lengths compared with jump_duration through Almos's
## TIME_SLACK, as the Roll is, and the last frame is cut short if the Jump does not end on a
## frame boundary, so a Jump always covers exactly its speed times jump_duration. The frame of
## the press is the first frame of the Jump, and the frame he comes down in is still spent in
## the air.

## The physics layers of the world, as the bits that set them in a collision mask. They are the
## layers project.godot names: walls, gap_edge, ledge_edge, gap_area, ledge_area, enemy_body and
## player_body.
const WALLS := 1 << 0
const GAP_EDGE := 1 << 3
const LEDGE_EDGE := 1 << 4
const GAP_AREA := 1 << 5
const LEDGE_AREA := 1 << 6
const ENEMY_BODY := 1 << 7
const PLAYER_BODY := 1 << 8

## What blocks him on the ground, by height level, and in the air: the masks of his body.
const GROUND_MASK := WALLS | GAP_EDGE | LEDGE_EDGE | ENEMY_BODY
const LEDGE_MASK := WALLS | LEDGE_EDGE | ENEMY_BODY
const AIR_MASK := WALLS

## Emitted in the frame he comes down, once he has been put where he lands: back where the Jump
## began if he came down in a gap, with in_a_gap set.
signal landed(in_a_gap: bool)

## What the numbers of Jump come from. Almos gives his own tuning.
@export var tuning: PlayerTuning

## Almos himself, whom the Jump moves.
@export var body: CharacterBody2D

## What rises along the arc to jump_height and back: the look of Almos himself. Optional.
@export var look: Node2D

## What stays at his feet while he is in the air. Optional.
@export var shadow: CanvasItem

## Whether he is in the air: from the frame of the press to the frame he comes down in.
var airborne: bool:
	get:
		return _airborne

## Which height level he is on: 0 for the ground, 1 for a low ledge. In the air it is the
## level he took off from, until he comes down.
var height_level: int:
	get:
		return _level

var _airborne := false
var _level := 0
var _time := 0.0
var _velocity := Vector2.ZERO
var _takeoff_position := Vector2.ZERO


func _ready() -> void:
	_apply_height()
	_show()


## He takes off now, at this velocity, which he keeps to the end of the Jump. Almos has
## checked that he is free to, and paid for it.
func begin(at_velocity: Vector2) -> void:
	_airborne = true
	_time = 0.0
	_velocity = at_velocity
	_takeoff_position = body.global_position
	_apply_height()
	_show()


## He is on the ground level, not in the air, at once, where he stands, and his body, his shadow
## and his look are as on the ground. No landing is announced. Called when Almos falls or
## is returned.
func reset() -> void:
	_airborne = false
	_level = 0
	_time = 0.0
	_apply_height()
	_show()


## Lets one physics frame of this length, in seconds, go by in the air: he moves, and comes
## down if the Jump is over.
func advance(delta: float) -> void:
	# The last frame is cut short if the Jump does not end on a frame boundary.
	var step := minf(delta, tuning.jump_duration - _time)
	_time += step
	body.velocity = _velocity * step / delta
	body.move_and_slide()
	if _time >= tuning.jump_duration - Almos.TIME_SLACK:
		_land()
	_show()


# He comes down where he is. A ledge puts him on it, a gap puts him back, and anything else is
# the ground.
func _land() -> void:
	_airborne = false
	var terrain := _terrain_at(body.global_position)
	var in_a_gap := false
	if terrain & LEDGE_AREA:
		_level = 1
	elif terrain & GAP_AREA:
		body.global_position = _takeoff_position
		in_a_gap = true
	else:
		_level = 0
	_apply_height()
	landed.emit(in_a_gap)


# Which of the ledge and gap areas this point is in, as their layer bits.
func _terrain_at(point: Vector2) -> int:
	var query := PhysicsPointQueryParameters2D.new()
	query.position = point
	query.collision_mask = GAP_AREA | LEDGE_AREA
	query.collide_with_areas = true
	query.collide_with_bodies = false
	var found := 0
	for hit in body.get_world_2d().direct_space_state.intersect_point(query):
		found |= (hit["collider"] as CollisionObject2D).collision_layer
	return found


# What his body blocks and is blocked by: in the air he is blocked by real walls only and no
# enemy meets him; on the ground, by what his level says.
func _apply_height() -> void:
	if _airborne:
		body.collision_layer = 0
		body.collision_mask = AIR_MASK
		return
	body.collision_layer = PLAYER_BODY
	body.collision_mask = LEDGE_MASK if _level == 1 else GROUND_MASK


# The look follows the state in the moment it changes: the shadow stays at his feet while he
# is in the air, and his look rises along an arc that peaks at jump_height half way.
func _show() -> void:
	if shadow != null:
		shadow.visible = _airborne
	if look != null:
		var fraction := clampf(_time / tuning.jump_duration, 0.0, 1.0) if _airborne else 0.0
		look.position = Vector2(0.0, -tuning.jump_height * 4.0 * fraction * (1.0 - fraction))
