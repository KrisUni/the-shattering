extends CharacterBody2D

# Almos's sprites show eight facings, so his facing is always one of eight directions.
const FACING_STEP := TAU / 8.0

# Frame lengths added up one by one can land a hair short of a whole number of seconds;
# without this slack a Roll would run one more frame, with nothing left to move.
const TIME_SLACK := 0.000001

enum State { WALKING, SPRINTING, ROLLING }

## Where Almos last moved, snapped to the nearest of eight directions, as a unit
## vector. A Roll with no input goes this way.
var facing := Vector2.DOWN

## Whether a Roll is under way.
var rolling: bool:
	get:
		return _state == State.ROLLING

## Whether Almos is sprinting.
var sprinting: bool:
	get:
		return _state == State.SPRINTING

## Whether Almos cannot be hurt at this moment: during part of a Roll.
var untouchable: bool:
	get:
		var window_start := tuning.roll_untouchable_start
		return rolling and _roll_time >= window_start and _roll_time < window_start + tuning.roll_untouchable_duration

@export var tuning: PlayerTuning

## What Roll and Sprint spend, and what the Stamina bar shows. In almos.tscn it is
## given the same tuning data file as Almos.
@onready var stamina: Stamina = $Stamina
@onready var _placeholder: Polygon2D = $Placeholder

var _state := State.WALKING
var _roll_direction := Vector2.ZERO
var _roll_time := 0.0
var _roll_queued := false
var _roll_button_held_for := 0.0
# Set when a Sprint was tried and there was no Stamina to pay for it, until the Roll
# button is let go. Without it, the sliver of Stamina that comes back when the refill
# pause ends would pay for one frame of Sprint, which would start the pause again.
var _out_of_breath := false


func _physics_process(delta: float) -> void:
	# get_vector applies the deadzone to the stick as a whole, not axis by axis, and
	# never returns more than length 1, so diagonals are no faster.
	var direction := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	var tapped := _roll_button_tapped(delta)
	# A finished Roll is ended at the start of the next frame, so that a queued Roll can
	# start in that same frame and follow it without a gap.
	if rolling and _roll_time >= tuning.roll_duration - TIME_SLACK:
		_end_roll(direction)
	if tapped:
		_on_roll_tapped(direction)
	if rolling:
		_roll(delta)
	else:
		_move_freely(direction, delta)
	# Turning the placeholder shape stands in for the eight facing sprites.
	_placeholder.rotation = facing.angle()


func _move_freely(direction: Vector2, delta: float) -> void:
	# Stamina is only spent while he is trying to sprint. When spend() fails it is gone,
	# which drops him back to walking until the button is let go and held again.
	var sprint := false
	if direction != Vector2.ZERO \
			and _roll_button_held_for >= tuning.roll_hold_threshold \
			and not _out_of_breath:
		sprint = stamina.spend(tuning.sprint_stamina_per_second * delta)
		_out_of_breath = not sprint
	_state = State.SPRINTING if sprint else State.WALKING
	if direction != Vector2.ZERO:
		_face(direction)
	velocity = direction * (tuning.sprint_speed if sprint else tuning.walk_speed)
	move_and_slide()


func _face(direction: Vector2) -> void:
	facing = Vector2.from_angle(snappedf(direction.angle(), FACING_STEP))


# The button is polled every frame, rather than listening for its events, so that it
# reads the same whether it was pressed by a key, a pad or an action press. A press let
# go before the hold threshold is a tap. A longer one was a hold (a Sprint, if he was
# moving), so letting go of it does not Roll.
func _roll_button_tapped(delta: float) -> bool:
	if Input.is_action_pressed(&"roll"):
		_roll_button_held_for += delta
		return false
	var tapped := _roll_button_held_for > 0.0 and _roll_button_held_for < tuning.roll_hold_threshold
	_roll_button_held_for = 0.0
	_out_of_breath = false
	return tapped


func _start_roll(direction: Vector2) -> void:
	if not stamina.spend(tuning.roll_stamina_cost):
		return
	_roll_direction = direction.normalized() if direction != Vector2.ZERO else facing
	_face(_roll_direction)
	_roll_time = 0.0
	_state = State.ROLLING


func _on_roll_tapped(direction: Vector2) -> void:
	if not rolling:
		_start_roll(direction)
	elif tuning.roll_duration - _roll_time <= tuning.roll_buffer_window:
		_roll_queued = true


func _end_roll(direction: Vector2) -> void:
	_state = State.WALKING
	if _roll_queued:
		_roll_queued = false
		_start_roll(direction)


func _roll(delta: float) -> void:
	# The last frame is cut short if the Roll does not end on a frame boundary, so the
	# Roll always covers exactly roll_distance.
	var step := minf(delta, tuning.roll_duration - _roll_time)
	_roll_time += step
	velocity = _roll_direction * tuning.roll_distance / tuning.roll_duration * step / delta
	move_and_slide()
