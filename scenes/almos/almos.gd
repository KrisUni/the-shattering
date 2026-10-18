class_name Almos
extends CharacterBody2D

# Almos's sprites show eight facings, so his facing is always one of eight directions.
const FACING_STEP := TAU / 8.0

# Frame lengths added up one by one can land a hair short of a whole number of seconds
# (twelve of them at 60 frames a second add up to 0.19999999999999998). A summed time is
# compared with a tuned time through this slack, so that a tuned time which is a whole
# number of frames counts as reached on that frame, not the next. Without it a Roll would
# run one more frame with nothing left to move, the untouchable window would be a frame
# too long and the hold threshold a frame too late. The Guard break in AlmosBlock is timed
# with it as well.
const TIME_SLACK := 0.000001

enum State { WALKING, SPRINTING, ROLLING }

## Where Almos last moved, snapped to the nearest of eight directions, as a unit
## vector. A Roll with no input goes this way, and so does an attack. Under Lock-on it is
## the direction to the target instead (snapped the same way), and it stays as it was when
## the lock lets go.
var facing := Vector2.DOWN

## Whether a Roll is under way.
var rolling: bool:
	get:
		return _state == State.ROLLING

## Whether Almos is sprinting.
var sprinting: bool:
	get:
		return _state == State.SPRINTING

## Whether a Light or Heavy attack or the Critical hit is under way: its startup, active and
## recovery frames.
var attacking: bool:
	get:
		return _attacks.attacking

## Whether the Critical hit is under way: his swing at a broken enemy, made by a Light attack
## press in its range in place of a Light swing. Alongside attacking, the Light swing is 0.
var critical: bool:
	get:
		return _attacks.critical

## Whether a Heavy attack is being charged: he holds the button and has not swung yet.
var charging: bool:
	get:
		return _attacks.charging

## Which swing of the Light attack combo is under way, from 1, or 0 when none is. A Heavy
## attack, or none at all, is 0.
var light_swing: int:
	get:
		return _attacks.light_swing

## Whether Lock-on holds: he has locked on to an enemy and not let go of it yet.
var locked_on: bool:
	get:
		return _lock_on.locked

## The enemy he has locked on to, or null when he has not.
var lock_on_target: Node2D:
	get:
		return _lock_on.target

## Whether he is blocking: the Block button is held and he is free, which he is not in a
## Roll, in an attack, charging a Heavy attack, sprinting or in a Guard break. Holding the
## Roll button while blocking does not start a Sprint.
var blocking: bool:
	get:
		return _block.blocking

## Whether a Guard break is on him: a blocked hit took the last of his Stamina, and for
## guard_break_duration he is left open. He stands still, and can neither Sprint, Roll, attack
## nor block; his Lock-on works as usual. He is free again from the frame after the last of it.
var guard_broken: bool:
	get:
		return _block.guard_broken

## Whether a Parry is under way: its window or its recovery. He stands still, and can neither
## Roll, attack, Block nor Parry again; his Lock-on works as usual. He is free again from the
## frame after the last recovery frame, or after a hit was parried.
var parrying: bool:
	get:
		return _parry.parrying

## Whether the window of a Parry is open: a hit from the front is parried.
var parry_window_open: bool:
	get:
		return _parry.window_open

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
@onready var _lock_on: AlmosLockOn = $LockOn
@onready var _block: AlmosBlock = $Block
@onready var _parry: AlmosParry = $Parry
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
	# Handing over the weapon or the tuning changes nothing else, so they need no check first.
	($Attacks as AlmosAttacks).weapon = weapon
	($LockOn as AlmosLockOn).tuning = tuning
	($Block as AlmosBlock).tuning = tuning
	($Parry as AlmosParry).tuning = tuning


func _ready() -> void:
	# The Critical hit turns him to the enemy it is made at.
	_attacks.critical_began.connect(_face)
	_hurtbox.is_untouchable = func() -> bool: return untouchable
	_hurtbox.is_parried = func(from: Vector2) -> bool:
		return _parry.catches(from, global_position, facing)
	_hurtbox.parry_stagger = tuning.parry_stagger
	_hurtbox.damage_through = func(damage: float, from: Vector2) -> float:
		return _block.receive_hit(damage, from, global_position, facing)


func _physics_process(delta: float) -> void:
	# A Guard break that runs out in this frame is still spent open, though the block clears it
	# before the frame is over. So it is read once, here, for everything below.
	var left_open := _block.guard_broken
	# Likewise a Parry whose last recovery frame this is is still spent standing open.
	var left_parrying := _parry.parrying
	# get_vector applies the deadzone to the stick as a whole, not axis by axis, and
	# never returns more than length 1, so diagonals are no faster.
	var direction := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	# Lock-on goes first, because everything below aims or moves by it: a target that died or
	# got away since the last frame is let go of here, and a press of its button is read. It is
	# told the direction every frame, even one spent in a Roll or a swing, so that it can tell
	# a direction held from one let go of.
	_lock_on.advance(direction)
	# The order matters: a tap has to be read before the timer is reset by the end of the
	# press, and the timer has to be advanced before _move_freely reads it.
	var tapped := _roll_button_was_tapped()
	_advance_roll_button_timer(delta)
	# A finished Roll is ended at the start of the next frame, so that a queued Roll can
	# start in that same frame and follow it without a gap.
	if rolling and _roll_time >= tuning.roll_duration - TIME_SLACK:
		_end_roll(direction)
	_attacks.advance(_aim(), not rolling and not left_open and not left_parrying)
	# An attack commits him and a Guard break or a Parry leaves him open, so a tap in any of
	# them is lost, not kept for after it.
	if tapped and not _attacks.committed and not left_open and not left_parrying:
		_on_roll_tapped(direction)
	# A Parry can be begun from a Sprint or while blocking, but not in a Roll, an attack or a
	# Guard break, nor in a Parry. The attack and the Roll have begun by now if they were going
	# to this frame, and so win against a Parry press made in the same frame.
	_parry.advance(not rolling and not _attacks.committed and not left_open and not left_parrying)
	var parry_on := left_parrying or parrying
	# He is free to block unless he is in a Roll, an attack or a Parry, which have begun by now
	# if they were going to this frame, or sprinting, which is as the last frame left it.
	_block.advance(not rolling and not _attacks.committed and not parry_on and not sprinting, delta)
	# Set every frame, ahead of Stamina's own processing in this frame, so that it never lags.
	stamina.refill_factor = tuning.block_stamina_refill_factor if blocking else 1.0
	if rolling:
		_roll(delta)
	elif _attacks.committed or left_open or parry_on:
		_stand_still()
	else:
		_move_freely(direction, delta)
	# Under Lock-on he ends every frame facing the target, whatever he did in it. This comes
	# after the move, so that it is where he has got to that he faces, and not where he was.
	_face_the_target()
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
	var speed := tuning.walk_speed
	if sprint:
		speed = tuning.sprint_speed
	elif blocking:
		speed = tuning.block_walk_speed
	if _lock_on.locked:
		# He circles the target instead of walking where the stick points, and faces it
		# whichever way he goes (see _face_the_target).
		velocity = _lock_on.circling_velocity(direction, speed, delta)
	else:
		if direction != Vector2.ZERO:
			_face(direction)
		velocity = direction * speed
	move_and_slide()


# An attack commits him: he neither walks nor sprints from the moment he begins charging a
# Heavy attack or swinging until the recovery is over. A Guard break leaves him standing
# the same way, and so does a Parry.
func _stand_still() -> void:
	_state = State.WALKING
	velocity = Vector2.ZERO


# Whether he is trying to Sprint: pushing a direction with the Roll button held to the
# threshold, and not already out of breath. While blocking he cannot Sprint, so the hold is
# passed over. A Sprint he was in when he pressed Block is not ended by it: he does not block
# while he sprints. It only asks; paying for the Sprint is up to the caller.
func _wants_to_sprint(direction: Vector2) -> bool:
	return direction != Vector2.ZERO and _held_to_the_threshold() and not _out_of_breath and not blocking


func _face(direction: Vector2) -> void:
	facing = Vector2.from_angle(snappedf(direction.angle(), FACING_STEP))


# Under Lock-on, turns him to the target, whichever way he is going and whatever he is doing.
# Without Lock-on, or standing on the target, there is nothing to turn to and he keeps his
# facing.
func _face_the_target() -> void:
	# The Critical hit keeps him facing the broken enemy it was made at, to the end of its
	# swing; the lock itself holds, and turns him back to its target after.
	if _attacks.critical:
		return
	var to_target := _lock_on.direction_to_target()
	if to_target != Vector2.ZERO:
		_face(to_target)


# Which way an attack that begins now is aimed: exactly at the target under Lock-on, not at
# the nearest of the eight facings, and along his facing otherwise.
func _aim() -> Vector2:
	var to_target := _lock_on.direction_to_target()
	return to_target if to_target != Vector2.ZERO else facing


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
	_roll_direction = direction.normalized() if direction != Vector2.ZERO else _neutral_roll_direction()
	# Under Lock-on he keeps facing the target through the Roll, wherever it takes him.
	if not _lock_on.locked:
		_face(_roll_direction)
	_roll_time = 0.0
	_state = State.ROLLING


# Where a Roll with no direction pushed goes: the way he faces, or under Lock-on directly
# away from the target, since facing it he would otherwise Roll into it.
func _neutral_roll_direction() -> Vector2:
	var to_target := _lock_on.direction_to_target()
	return -to_target if to_target != Vector2.ZERO else facing


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
