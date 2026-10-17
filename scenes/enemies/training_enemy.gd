extends CharacterBody2D

# What the placeholder is tinted while it winds up, so that the player can see the attack
# coming. It is a look, not a tuning number.
const WIND_UP_TINT := Color(1.0, 0.35, 0.35)

## Emitted once, at the end of the physics frame in which its Health reached zero.
signal died

@export var tuning: EnemyTuning

## What it goes after.
@export var target: Node2D

## Whether it is winding up: the attack's startup frames, before its Hitbox is on.
var winding_up: bool:
	get:
		return attacking and _frame < tuning.attack.startup_frames

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
@onready var _hitbox: Hitbox = $Hitbox

# The attack frame it last processed, which is 0 for the first frame of the attack. -1 when
# there is no attack.
var _frame := -1
var _dead := false


func _enter_tree() -> void:
	# Done here, not in _ready, so that every node's _ready finds Health already filled in.
	# Giving it a maximum refills it, so it is only given a different one.
	var own_health := $Health as Health
	if own_health.maximum != tuning.health_maximum:
		own_health.maximum = tuning.health_maximum


func _ready() -> void:
	health.depleted.connect(_on_depleted)


func _physics_process(_delta: float) -> void:
	if not is_instance_valid(target):
		return
	if attacking:
		_frame += 1
		if _frame >= _attack_frames():
			_frame = -1
	# One that has died in this frame starts nothing new, but the frame is played out all the
	# same: whichever of Almos's blow and its own strike is processed first, the one that
	# lands in the frame of its death still lands.
	if not attacking and not _dead:
		_act_freely()
	_set_strike(_in_active_frames())
	modulate = WIND_UP_TINT if winding_up else Color.WHITE


# Between attacks: attack if the target is close enough, walk towards it if it is noticed.
func _act_freely() -> void:
	var to_target := target.global_position - global_position
	if to_target.length() <= tuning.attack_range:
		_frame = 0
		_hitbox.damage = tuning.attack.damage
		# It commits to the swing: it goes where the target was now, wherever it moves to.
		_hitbox.rotation = to_target.angle()
	elif to_target.length() <= tuning.notice_range:
		velocity = to_target.normalized() * tuning.move_speed
		move_and_slide()


# Whether the attack under way is in its active frames, when its Hitbox is to be on.
func _in_active_frames() -> bool:
	var attack := tuning.attack
	return attacking and _frame >= attack.startup_frames and _frame < attack.startup_frames + attack.active_frames


# Switches the strike on or off: its Hitbox, and its placeholder look, which shows while the
# Hitbox can hurt.
func _set_strike(on: bool) -> void:
	_hitbox.active = on
	_hitbox.visible = on


func _attack_frames() -> int:
	var attack := tuning.attack
	return attack.startup_frames + attack.active_frames + attack.recovery_frames


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
