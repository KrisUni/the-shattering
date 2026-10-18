extends CharacterBody2D

# What the placeholder is tinted while it winds up, so that the player can see the attack
# coming. It is a look, not a tuning number.
const WIND_UP_TINT := Color(1.0, 0.35, 0.35)

# What it is tinted while it winds up a Low attack, so that the player can tell it from the
# Strike's and knows to Jump. Also a look.
const LOW_WIND_UP_TINT := Color(1.0, 0.9, 0.2)

# What it is tinted for the first unblockable_flash_frames of the wind-up of an Unblockable
# attack: a white brighter than the placeholder's own colours, which a plain white tint would
# not be. No other attack flashes. Also a look.
const UNBLOCKABLE_FLASH_TINT := Color(3.0, 3.0, 3.0)

# What it is tinted for the rest of the wind-up of an Unblockable attack, so that the player can
# tell it from every other and knows to Roll or Jump. Also a look.
const UNBLOCKABLE_WIND_UP_TINT := Color(0.75, 0.3, 0.95)

# What it is tinted while it is broken, so that the player can see it is open. Also a look.
const BREAK_TINT := Color(0.4, 0.6, 1.0)

# The collision mask of the walls, which block its Sight: the "walls" layer, the first.
const WALL_MASK := 1

## Emitted once, at the end of the physics frame in which its Health reached zero.
signal died

## Emitted once each time the sound that warns of an Unblockable attack is played, as its wind-up
## begins. No other attack plays it.
signal unblockable_cue_played

@export var tuning: EnemyTuning

## What it goes after.
@export var target: Node2D

## Whether it is a named enemy. An enemy is ordinary unless the instance placed in a room is
## marked named. Resting at a Checkpoint, and Almos's Death, bring back every ordinary enemy as
## new, and a named enemy stays dead.
@export var named := false

## The way it faces at its post, a unit vector, until it notices Almos. Its Sight points this way.
@export var post_facing := Vector2.DOWN:
	set(value):
		post_facing = value
		if not _noticed:
			_facing = value.normalized()
			if is_node_ready():
				_nose.rotation = _facing.angle()

## The way it faces, a unit vector. While it is free it turns to face its target exactly; in an
## attack it keeps the direction it committed the swing to. Its front is centred on it, and a
## hit from outside the front builds extra Stagger.
var facing: Vector2:
	get:
		return _facing

## Whether it has noticed its target: the target came into its Sight, or it was hit. Once it has,
## it stays noticed, and goes after the target.
var noticed: bool:
	get:
		return _noticed

## The kind of attack under way, or of the last one it made. It makes the kinds in the order of
## the tuning's attack_pattern.
var attack_kind: EnemyTuning.AttackKind:
	get:
		return _kind

## The attack under way, or the last one it made: the tuning's AttackData for its attack_kind.
var current_attack: AttackData:
	get:
		return tuning.attack_of(_kind)

## Whether it is winding up: the attack's startup frames, before its Hitbox is on.
var winding_up: bool:
	get:
		return current_attack.is_winding_up(_frame)

## Whether its Hitbox is on: the attack's active frames.
var striking: bool:
	get:
		return _hitbox.active or _low_hitbox.active or _unblockable_hitbox.active

## Whether an attack is under way: its startup, active and recovery frames.
var attacking: bool:
	get:
		return _frame >= 0

## Whether it is broken: its Stagger filled and the Break has neither run out nor been ended by
## a Critical hit. It stands still and starts nothing, and no Stagger builds.
var broken: bool:
	get:
		return _broken

## Whether its Health has reached zero. It is gone by the end of that physics frame.
var dead: bool:
	get:
		return _dead

@onready var health: Health = $Health
@onready var stagger: Stagger = $Stagger
@onready var _hitbox: Hitbox = $Hitbox
@onready var _low_hitbox: Hitbox = $LowHitbox
@onready var _unblockable_hitbox: Hitbox = $UnblockableHitbox
@onready var _unblockable_cue: AudioStreamPlayer2D = $UnblockableCue
@onready var _hurtbox: Hurtbox = $Hurtbox
@onready var _nose: Node2D = $Nose
@onready var _stagger_bar: Node2D = $StaggerBar

# The kind of the attack under way, or of the last one made.
var _kind := EnemyTuning.AttackKind.STRIKE
# Where in the tuning's attack_pattern the next attack it makes is. It runs on past the end of
# the pattern, which is read round and round.
var _next_in_pattern := 0
# The frame of the attack it is processing, counted as AttackData counts them, from 0 for its
# first frame. -1 when there is no attack.
var _frame := -1
var _dead := false
var _broken := false
# The physics frame it is free again in, once broken. The frame the Break begins in counts as the
# first of its break_frames, whichever of Almos's blow and its own processing comes first in it.
var _break_end_frame := 0
var _facing := Vector2.DOWN
var _noticed := false


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
	assert(not tuning.attack_pattern.is_empty(), "attack_pattern in the tuning needs at least one attack")
	_hitbox.set_reach(tuning.reach_of(EnemyTuning.AttackKind.STRIKE))
	_low_hitbox.set_reach(tuning.reach_of(EnemyTuning.AttackKind.LOW))
	_unblockable_hitbox.set_reach(tuning.reach_of(EnemyTuning.AttackKind.UNBLOCKABLE))
	_hitbox.parried.connect(_on_parried)
	_low_hitbox.parried.connect(_on_parried)
	_unblockable_hitbox.parried.connect(_on_parried)
	_hurtbox.landed.connect(_on_hit_landed)
	stagger.changed.connect(_show_stagger)
	_facing = post_facing.normalized()
	_show_stagger()
	_nose.rotation = _facing.angle()


func _physics_process(_delta: float) -> void:
	if not is_instance_valid(target):
		return
	if not _noticed and not _dead and _target_in_sight():
		_noticed = true
	# The Break runs for break_frames physics frames; it is free in the frame after the last.
	if _broken and Engine.get_physics_frames() >= _break_end_frame:
		_broken = false
	if attacking:
		_frame += 1
		if _frame >= current_attack.total_frames():
			_frame = -1
	if _broken:
		velocity = Vector2.ZERO
	# One that has died in this frame starts nothing new, but the frame is played out all the
	# same: whichever of Almos's blow and its own strike is processed first, the one that
	# lands in the frame of its death still lands.
	elif not attacking and not _dead:
		_act_freely()
	_set_strike(current_attack.is_active(_frame))
	_show_look()
	_nose.rotation = _facing.angle()


func _to_target() -> Vector2:
	return target.global_position - global_position


# Whether the target is in its Sight now: inside the cone, as long as the light at the target
# lets it reach, and with no wall in between.
func _target_in_sight() -> bool:
	var light := LightZone.light_at(get_tree().get_nodes_in_group("light_zones"), target.global_position)
	return Sight.sees(
		get_world_2d().direct_space_state, global_position, post_facing.normalized(), target.global_position,
		tuning.sight_arc_degrees, tuning.sight_length_at(light), WALL_MASK,
	)


# Between attacks: attack if the target is close enough, walk towards it. Until the target is
# noticed it stands at its post facing the way it was set.
func _act_freely() -> void:
	if not _noticed:
		return
	var to_target := _to_target()
	if not to_target.is_zero_approx():
		_facing = to_target.normalized()
	if to_target.length() <= tuning.attack_range:
		# It makes the next attack in its order, whatever came of the one before.
		_kind = tuning.attack_pattern[_next_in_pattern % tuning.attack_pattern.size()]
		_next_in_pattern += 1
		_frame = 0
		var box := _hitbox_of(_kind)
		box.damage = current_attack.damage
		# It commits to the swing: it goes where the target was now, wherever it moves to, and
		# keeps facing that way until the swing is over.
		box.rotation = _facing.angle()
		if _kind == EnemyTuning.AttackKind.UNBLOCKABLE:
			_unblockable_cue.play()
			unblockable_cue_played.emit()
	else:
		velocity = to_target.normalized() * tuning.move_speed
		move_and_slide()


# The Hitbox the attack of this kind hurts with.
func _hitbox_of(kind: EnemyTuning.AttackKind) -> Hitbox:
	match kind:
		EnemyTuning.AttackKind.LOW:
			return _low_hitbox
		EnemyTuning.AttackKind.UNBLOCKABLE:
			return _unblockable_hitbox
	return _hitbox


# Switches the strike of the attack under way on or off: its Hitbox, and its placeholder look,
# which shows while the Hitbox can hurt. The Hitbox of any other kind of attack is off.
func _set_strike(on: bool) -> void:
	var current := _hitbox_of(_kind)
	for box in [_hitbox, _low_hitbox, _unblockable_hitbox]:
		var lit: bool = on and box == current
		box.active = lit
		box.visible = lit


# Its tint: the Break's, or the wind-up's of the attack it is making, or none.
func _show_look() -> void:
	if _broken:
		modulate = BREAK_TINT
	elif winding_up:
		modulate = _wind_up_tint()
	else:
		modulate = Color.WHITE


# The tint of the wind-up of the attack it is making: an Unblockable attack's flashes white
# first and then keeps a tint of its own, a Low attack's and the Strike's have one each.
func _wind_up_tint() -> Color:
	match _kind:
		EnemyTuning.AttackKind.LOW:
			return LOW_WIND_UP_TINT
		EnemyTuning.AttackKind.UNBLOCKABLE:
			return UNBLOCKABLE_FLASH_TINT if _frame < tuning.unblockable_flash_frames else UNBLOCKABLE_WIND_UP_TINT
	return WIND_UP_TINT


# A hit of its own Hurtbox landed. A Critical hit ends a Break and builds no Stagger. Any other
# builds what the attack builds, and more if the hit came from behind, unless it is broken.
func _on_hit_landed(hit_stagger: float, from: Vector2, critical: bool) -> void:
	_noticed = true
	if critical:
		_broken = false
		_show_look()
		return
	var built := hit_stagger
	if not FrontArc.covers(from, global_position, _facing, tuning.front_arc_degrees):
		built += tuning.behind_stagger
	_build_stagger(built)


# One of its attacks was parried: its Stagger builds what that Parry builds.
func _on_parried(parrier: Hurtbox) -> void:
	_build_stagger(parrier.parry_stagger)


# Builds this much Stagger, which a Break does not allow, and breaks it if that fills the meter.
func _build_stagger(amount: float) -> void:
	if _broken:
		return
	stagger.add(amount)
	if stagger.full:
		_begin_break()


# The Break begins at once: the attack under way is over with its Hitbox off, so that a strike
# due later in this frame does not land, and the meter is emptied.
func _begin_break() -> void:
	_broken = true
	_break_end_frame = Engine.get_physics_frames() + tuning.break_frames
	_frame = -1
	_set_strike(false)
	stagger.reset()
	_show_look()


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
