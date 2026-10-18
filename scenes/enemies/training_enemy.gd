extends CharacterBody2D

# What the placeholder is tinted while it winds up, so that the player can see the attack
# coming. It is a look, not a tuning number.
const WIND_UP_TINT := Color(1.0, 0.35, 0.35)

## Emitted once, at the end of the physics frame in which its Health reached zero.
signal died

@export var tuning: EnemyTuning

## What it goes after.
@export var target: Node2D

## The way it faces, a unit vector. While it is free it turns to face its target exactly; in an
## attack it keeps the direction it committed the swing to. Its front is centred on it, and a
## hit from outside the front builds extra Stagger.
var facing: Vector2:
	get:
		return _facing

## Whether it is winding up: the attack's startup frames, before its Hitbox is on.
var winding_up: bool:
	get:
		return tuning.attack.is_winding_up(_frame)

## Whether its Hitbox is on: the attack's active frames.
var striking: bool:
	get:
		return _hitbox.active

## Whether an attack is under way: its startup, active and recovery frames.
var attacking: bool:
	get:
		return _frame >= 0

## Whether its Health has reached zero. It is gone by the end of that physics frame.
var dead: bool:
	get:
		return _dead

@onready var health: Health = $Health
@onready var stagger: Stagger = $Stagger
@onready var _hitbox: Hitbox = $Hitbox
@onready var _hurtbox: Hurtbox = $Hurtbox
@onready var _nose: Node2D = $Nose
@onready var _stagger_bar: Node2D = $StaggerBar

# The frame of the attack it is processing, counted as AttackData counts them, from 0 for its
# first frame. -1 when there is no attack.
var _frame := -1
var _dead := false
var _facing := Vector2.DOWN


func _enter_tree() -> void:
	# Done here, not in _ready, so that every node's _ready finds Health already filled in.
	# Giving it a maximum refills it, so it is only given a different one.
	var own_health := $Health as Health
	if own_health.maximum != tuning.health_maximum:
		own_health.maximum = tuning.health_maximum
	var own_stagger := $Stagger as Stagger
	own_stagger.capacity = tuning.stagger_capacity
	own_stagger.drain_rate = tuning.stagger_drain_rate
	own_stagger.drain_pause = tuning.stagger_drain_pause


func _ready() -> void:
	health.depleted.connect(_on_depleted)
	_hitbox.set_reach(tuning.attack_reach)
	_hitbox.stagger = tuning.attack.stagger
	_hitbox.parried.connect(_on_parried)
	_hurtbox.landed.connect(_on_hit_landed)
	stagger.changed.connect(_show_stagger)
	if is_instance_valid(target) and not _to_target().is_zero_approx():
		_facing = _to_target().normalized()
	_show_stagger()
	_nose.rotation = _facing.angle()


func _physics_process(_delta: float) -> void:
	if not is_instance_valid(target):
		return
	if attacking:
		_frame += 1
		if _frame >= tuning.attack.total_frames():
			_frame = -1
	# One that has died in this frame starts nothing new, but the frame is played out all the
	# same: whichever of Almos's blow and its own strike is processed first, the one that
	# lands in the frame of its death still lands.
	if not attacking and not _dead:
		_act_freely()
	_set_strike(tuning.attack.is_active(_frame))
	modulate = WIND_UP_TINT if winding_up else Color.WHITE
	_nose.rotation = _facing.angle()


func _to_target() -> Vector2:
	return target.global_position - global_position


# Between attacks: attack if the target is close enough, walk towards it if it is noticed.
func _act_freely() -> void:
	var to_target := _to_target()
	if not to_target.is_zero_approx():
		_facing = to_target.normalized()
	if to_target.length() <= tuning.attack_range:
		_frame = 0
		_hitbox.damage = tuning.attack.damage
		# It commits to the swing: it goes where the target was now, wherever it moves to, and
		# keeps facing that way until the swing is over.
		_hitbox.rotation = _facing.angle()
	elif to_target.length() <= tuning.notice_range:
		velocity = to_target.normalized() * tuning.move_speed
		move_and_slide()


# Switches the strike on or off: its Hitbox, and its placeholder look, which shows while the
# Hitbox can hurt.
func _set_strike(on: bool) -> void:
	_hitbox.active = on
	_hitbox.visible = on


# A hit of its own Hurtbox landed: its Stagger builds what the attack builds, and more if the
# hit came from behind.
func _on_hit_landed(hit_stagger: float, from: Vector2) -> void:
	var built := hit_stagger
	if not FrontArc.covers(from, global_position, _facing, tuning.front_arc_degrees):
		built += tuning.behind_stagger
	stagger.add(built)


# One of its attacks was parried: its Stagger builds what that Parry builds.
func _on_parried(parrier: Hurtbox) -> void:
	stagger.add(parrier.parry_stagger)


# The bar over it shows how full its Stagger is, and is hidden while it is empty.
func _show_stagger() -> void:
	var fraction := stagger.current / stagger.capacity
	_stagger_bar.visible = fraction > 0.0
	_stagger_bar.scale.x = fraction


func _on_depleted() -> void:
	_dead = true
	# The rest of its death waits for the end of the physics frame. Almos's blow can land
	# before its own turn in a frame, and switching the Hitbox off or leaving the tree now
	# would cost it a strike that is due in that same frame.
	_finish_dying.call_deferred()


# Called at the end of the physics frame its Health reached zero in, when whatever was to
# land in that frame has landed. Its Hitbox is off by the time it announces its death.
func _finish_dying() -> void:
	_set_strike(false)
	died.emit()
	queue_free()
