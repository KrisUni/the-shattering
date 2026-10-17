extends CharacterBody2D

# Almos's sprites show eight facings, so his facing is always one of eight directions.
const FACING_STEP := TAU / 8.0

# Frame lengths added up one by one can land a hair short of a whole number of seconds
# (twelve of them at 60 frames a second add up to 0.19999999999999998). A summed time is
# compared with a tuned time through this slack, so that a tuned time which is a whole
# number of frames counts as reached on that frame, not the next. Without it a Roll would
# run one more frame with nothing left to move, the untouchable window would be a frame
# too long and the hold threshold a frame too late.
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

## Whether a Light or Heavy attack is under way: its startup, active and recovery frames.
var attacking: bool:
	get:
		return _attacks.attacking

## Whether a Heavy attack is being charged: he holds the button and has not swung yet.
var charging: bool:
	get:
		return _attacks.charging

## Which swing of the Light attack combo is under way, from 1, or 0 when none is. A Heavy
## attack, or none at all, is 0.
var light_swing: int:
	get:
		return _attacks.light_swing

## Whether Almos cannot be hurt at this moment: during part of a Roll.
var untouchable: bool:
	get:
		var window_start := tuning.roll_untouchable_start - TIME_SLACK
		var window_end := tuning.roll_untouchable_start + tuning.roll_untouchable_duration - TIME_SLACK
		return rolling and _roll_time >= window_start and _roll_time < window_end

@export var tuning: PlayerTuning

## The Weapon he carries: the attacks he can make. It is given to his attacks, so this is
## the only one to set.
@export var weapon: WeaponData

## What Roll and Sprint spend, and what the Stamina bar shows. It is given Almos's tuning,
## so his tuning is the only one to set.
@onready var stamina: Stamina = $Stamina

## What hits take off, and what the Health bar shows. It is given its maximum from Almos's
## tuning, so his tuning is the only one to set.
@onready var health: Health = $Health
@onready var _hurtbox: Hurtbox = $Hurtbox
@onready var _attacks: AlmosAttacks = $Attacks
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


func _enter_tree() -> void:
	# Done here, not in _ready, so that every node's _ready finds Stamina and Health already
	# filled in whatever order the nodes are in: the bars read them in their _ready. Giving
	# either its numbers refills it, so each is only given a different one.
	var own_stamina := $Stamina as Stamina
	if own_stamina.tuning != tuning:
		own_stamina.tuning = tuning
	var own_health := $Health as Health
	if own_health.maximum != tuning.health_maximum:
		own_health.maximum = tuning.health_maximum
	# Handing over the weapon changes nothing else, so it needs no check first.
	($Attacks as AlmosAttacks).weapon = weapon


func _ready() -> void:
	_hurtbox.is_untouchable = func() -> bool: return untouchable


func _physics_process(delta: float) -> void:
	# get_vector applies the deadzone to the stick as a whole, not axis by axis, and
	# never returns more than length 1, so diagonals are no faster.
	var direction := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	# The order matters: a tap has to be read before the timer is reset by the end of the
	# press, and the timer has to be advanced before _move_freely reads it.
	var tapped := _roll_button_was_tapped()
	_advance_roll_button_timer(delta)
	# A finished Roll is ended at the start of the next frame, so that a queued Roll can
	# start in that same frame and follow it without a gap.
	if rolling and _roll_time >= tuning.roll_duration - TIME_SLACK:
		_end_roll(direction)
	_attacks.advance(facing, not rolling)
	# An attack commits him, so a tap in it is lost, not kept for after it.
	if tapped and not _attacks.committed:
		_on_roll_tapped(direction)
	if rolling:
		_roll(delta)
	elif _attacks.committed:
		_stand_still()
	else:
		_move_freely(direction, delta)
	# Turning the placeholder shape stands in for the eight facing sprites.
	_placeholder.rotation = facing.angle()


func _move_freely(direction: Vector2, delta: float) -> void:
	var sprint := false
	if _wants_to_sprint(direction):
		# The only place a Sprint is paid for. When spend() fails Stamina is gone, which
		# drops him back to walking until the button is let go and held again.
		sprint = stamina.spend(tuning.sprint_stamina_per_second * delta)
		_out_of_breath = not sprint
	_state = State.SPRINTING if sprint else State.WALKING
	if direction != Vector2.ZERO:
		_face(direction)
	velocity = direction * (tuning.sprint_speed if sprint else tuning.walk_speed)
	move_and_slide()


# An attack commits him: he neither walks nor sprints from the moment he begins charging a
# Heavy attack or swinging until the recovery is over.
func _stand_still() -> void:
	_state = State.WALKING
	velocity = Vector2.ZERO


# Whether he is trying to Sprint: pushing a direction with the Roll button held to the
# threshold, and not already out of breath. It only asks; paying for the Sprint is up to
# the caller.
func _wants_to_sprint(direction: Vector2) -> bool:
	return direction != Vector2.ZERO and _held_to_the_threshold() and not _out_of_breath


func _face(direction: Vector2) -> void:
	facing = Vector2.from_angle(snappedf(direction.angle(), FACING_STEP))


# The button is polled every frame, rather than listening for its events, so that it
# reads the same whether it was pressed by a key, a pad or an action press. A press let
# go before the hold threshold is a tap. A longer one was a hold (a Sprint, if he was
# moving), so letting go of it does not Roll. A press and release that both land before
# the same frame never show the button down, so the just-pressed and just-released
# checks catch them.
#
# Whether the press ended this frame as a tap. It only asks, and must be called before
# _advance_roll_button_timer, which forgets the press once it has ended.
func _roll_button_was_tapped() -> bool:
	if _roll_press_ended():
		return not _held_to_the_threshold()
	# Pressed and let go again before this frame, so it was never seen down.
	return Input.is_action_just_pressed(&"roll") and not Input.is_action_pressed(&"roll")


# Times how long the button has been held, and forgets the press once it has ended.
func _advance_roll_button_timer(delta: float) -> void:
	if _roll_press_ended():
		_roll_button_held_for = 0.0
		_out_of_breath = false
	if Input.is_action_pressed(&"roll"):
		_roll_button_held_for += delta


# Whether the press being timed is over: the button was let go, even if it went down
# again in the same frame.
func _roll_press_ended() -> bool:
	return _roll_button_held_for > 0.0 \
			and (not Input.is_action_pressed(&"roll") or Input.is_action_just_released(&"roll"))


# Whether the press being timed has lasted as long as the hold threshold: from then on it
# is a hold, and letting go of it is not a tap.
func _held_to_the_threshold() -> bool:
	return _roll_button_held_for >= tuning.roll_hold_threshold - TIME_SLACK


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
