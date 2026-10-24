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

# What a Sound hunter is tinted at rest, so that it can be told from the others. A look.
const SOUND_HUNTER_TINT := Color(0.6, 1.0, 0.6)

# The collision layers a slide is shaped by: the walls it slams into (the first), and the edge of a
# Gap (the fourth), which does not block it, and the area inside a Gap (the sixth), which kills it.
const WALL_LAYER := 1
const GAP_EDGE_LAYER := 8
const GAP_AREA_LAYER := 32

# How a shudder looks: for this many physics frames its look jumps this many pixels from side to
# side, each frame the other way. A look, not tuning.
const SHUDDER_FRAMES := 8
const SHUDDER_OFFSET := 3.0

# How close, in pixels, to the place it walks to counts as being there. A look of the walk, not tuning.
const ARRIVED_DISTANCE := 0.5

# The collision mask of the walls, which block its Sight: the "walls" layer, the first.
const WALL_MASK := 1

# Where it is: standing at its post, in Pursuit of its target, or walking back to its post.
enum State { POST, PURSUIT, RETURNING }

## Emitted once, at the end of the physics frame in which its Health reached zero.
signal died

## Emitted once each time a Shove or a Pull is too much for its Weight and it shudders instead of
## moving.
signal shuddered

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

## What a named enemy is called in WorldState, stable across builds of the area. It records itself
## as defeated under this name when it dies, and an area that is built with the name recorded has
## no such enemy. Each named enemy needs its own; an ordinary enemy has none.
@export var id: StringName

## The way it faces at its post, a unit vector, until it notices Almos. Its Sight points this way.
## It faces this way again once it is back at its post.
@export var post_facing := Vector2.DOWN:
	set(value):
		post_facing = value
		if _state == State.POST:
			_facing = value.normalized()
			if is_node_ready():
				_nose.rotation = _facing.angle()

## The way it faces, a unit vector. While it is free it turns to face its target exactly; in an
## attack it keeps the direction it committed the swing to. Its front is centred on it, and a
## hit from outside the front builds extra Stagger.
var facing: Vector2:
	get:
		return _facing

## Whether it is in Pursuit: it noticed its target, which came into its Sight (a Sound hunter:
## within the radius of his Noise) or hit it, and has not lost him yet.
var in_pursuit: bool:
	get:
		return _state == State.PURSUIT

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

## Whether it is on its way to a place it was sent to with begin_follow().
var following: bool:
	get:
		return _following

## Whether, on its way, it has got to the place it was sent to.
var follow_arrived: bool:
	get:
		return _follow_arrived

## Whether it is broken: its Stagger filled and the Break has neither run out nor been ended by
## a Critical hit. It stands still and starts nothing, and no Stagger builds.
var broken: bool:
	get:
		return _broken

## How heavy it is, from its tuning.
var weight: float:
	get:
		return tuning.weight

## Whether a Shove or a Pull is sliding it: it does not act until the slide is over.
var sliding: bool:
	get:
		return _sliding

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
@onready var _placeholder: Node2D = $Placeholder

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
# The slide a Shove or a Pull put it in: whether it is under way, the unit direction, how far is left
# of it, in pixels, and how fast, in pixels per second.
var _sliding := false
var _slide_direction := Vector2.ZERO
var _slide_left := 0.0
var _slide_speed := 0.0
# For how many more physics frames it shudders.
var _shudder_left := 0
var _state := State.POST
# Where it stands at its post: where it started. It returns here.
var _post := Vector2.ZERO
# The place its target was when it last had him in Sight, or was hit by him.
var _last_seen := Vector2.ZERO
# For how many physics frames in a row it has been in Pursuit without him in its Sight.
var _unseen_frames := 0
# Whether the target was in its Sight (a Sound hunter: earshot) when it looked this frame.
var _sees_target := false
# Whether it saw the target get into a Hiding spot and is going to drag him out of it, and where
# that spot is. It lasts until he is out of the spot, however that comes about.
var _dragging := false
var _drag_spot := Vector2.ZERO
# Whether the grab of the drag-out has started. Until it has, the lose-time runs on the drag.
var _grab_started := false
var _drag_start_frame := -1
# Whether it is walking to the place it was sent to, instead of acting on its target; the place;
# and whether it has got there.
var _following := false
var _follow_place := Vector2.ZERO
var _follow_arrived := false


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
	_hurtbox.landed_damage_only.connect(_notice_the_hit)
	stagger.changed.connect(_show_stagger)
	_facing = post_facing.normalized()
	_post = global_position
	_show_stagger()
	_nose.rotation = _facing.angle()


func _physics_process(_delta: float) -> void:
	_show_shudder()
	if _sliding:
		# It does not act while it slides, with or without a target.
		_slide(get_physics_process_delta_time())
		_set_strike(false)
		_show_look()
		return
	if _following:
		_walk_to_follow_place()
		return
	if not is_instance_valid(target):
		return
	if not _dead:
		_update_pursuit()
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


## Sends it to walk to this place, such as a Room's exit that Almos went through, instead of acting
## on its target. An attack under way is broken off. While it walks it neither loses Pursuit nor
## recovers Health, and its Break runs out as usual. Its state is otherwise left as it is.
func begin_follow(place: Vector2) -> void:
	_following = true
	_follow_place = place
	_follow_arrived = false


## Ends the walk begun with begin_follow(), wherever it has got to, and it acts on its target
## again. The place its target was last seen at is this one, and the count of frames without him in
## its Sight starts again.
func end_follow(last_seen_at: Vector2) -> void:
	_following = false
	_follow_arrived = false
	_last_seen = last_seen_at
	_unseen_frames = 0


## A Shove or a Pull slides it this way, a unit vector, for this many pixels at this many pixels
## per second. It does not act while it slides, and an attack under way is interrupted. It stops
## short at a wall, which builds wall_stagger Stagger on it, or at anything else solid, but not at the
## edge of a Gap: one that has its centre inside a Gap takes a Deadly fall and dies.
func slide(direction: Vector2, distance: float, speed: float) -> void:
	if _dead or distance <= 0.0 or direction.is_zero_approx():
		return
	_sliding = true
	_slide_direction = direction.normalized()
	_slide_left = distance
	_slide_speed = speed
	_frame = -1
	_set_strike(false)
	velocity = Vector2.ZERO
	collision_mask &= ~GAP_EDGE_LAYER
	_notice_the_hit()


## A Shove or a Pull is more than its Weight allows: it shudders, a few frames of jitter, and
## stays where it is.
func shudder() -> void:
	_shudder_left = SHUDDER_FRAMES
	shuddered.emit()


# One physics frame of the slide.
func _slide(delta: float) -> void:
	var step := minf(_slide_speed * delta, _slide_left)
	var hit := move_and_collide(_slide_direction * step)
	_slide_left -= step
	if _in_a_gap():
		_end_slide()
		_fall_to_its_death()
		return
	if hit != null:
		var collider := hit.get_collider() as CollisionObject2D
		if collider != null and collider.collision_layer & WALL_LAYER:
			_build_stagger(tuning.wall_stagger)
		_end_slide()
	elif _slide_left <= 0.0:
		_end_slide()


func _end_slide() -> void:
	_sliding = false
	collision_mask |= GAP_EDGE_LAYER


# Whether its centre is inside a Gap.
func _in_a_gap() -> bool:
	var query := PhysicsPointQueryParameters2D.new()
	query.position = global_position
	query.collision_mask = GAP_AREA_LAYER
	query.collide_with_areas = true
	query.collide_with_bodies = false
	return not get_world_2d().direct_space_state.intersect_point(query, 1).is_empty()


# A Deadly fall: it dies as if killed.
func _fall_to_its_death() -> void:
	health.take_damage(health.current)


# Its look jumps from side to side while it shudders.
func _show_shudder() -> void:
	if _shudder_left > 0:
		_placeholder.position.x = SHUDDER_OFFSET if _shudder_left % 2 == 0 else -SHUDDER_OFFSET
		_shudder_left -= 1
	else:
		_placeholder.position.x = 0.0


func _to_target() -> Vector2:
	return target.global_position - global_position


# It notices the target, or loses him, or recovers: once a frame, before it acts. Seeing him
# starts Pursuit (again) and resets the count of frames without him; Pursuit ends once the count
# reaches the tuning's lose_sight_frames. Health comes back whenever it is not in Pursuit.
func _update_pursuit() -> void:
	if _dragging:
		if _target_hidden():
			# It has eyes on the spot, not on him: the lose-time does not run on him. It runs on
			# the drag instead until the grab starts, so that an enemy something stops short of
			# the spot gives up, as for losing him.
			_sees_target = false
			_state = State.PURSUIT
			if not _grab_started and not attacking:
				# The count starts on the first frame it is free to head for the spot, after any
				# attack that was already under way.
				if _drag_start_frame < 0:
					_drag_start_frame = Engine.get_physics_frames()
				if Engine.get_physics_frames() - _drag_start_frame >= tuning.lose_sight_frames:
					_dragging = false
					end_pursuit()
			return
		_dragging = false
	_sees_target = _target_noticed()
	if _sees_target:
		_state = State.PURSUIT
		_last_seen = target.global_position
		_unseen_frames = 0
	elif _state == State.PURSUIT:
		_unseen_frames += 1
		if _unseen_frames >= tuning.lose_sight_frames:
			end_pursuit()
	if _state != State.PURSUIT:
		health.heal(tuning.health_recovery_rate * get_physics_process_delta_time())


## Ends Pursuit at once, as losing the target for the lose-time does: it walks back to its post
## and recovers Health there. An attack under way is finished first. Does nothing out of Pursuit.
## It notices the target again if he is in its Sight or hits it.
func end_pursuit() -> void:
	if _state == State.PURSUIT:
		_state = State.RETURNING
		_unseen_frames = 0


## Almos gets into a Hiding spot at this place, having made this much Noise in the frame before.
## An enemy that saw him get in (a Sound hunter: that he was within that Noise) goes to the spot
## and drags him out with an Unblockable attack, out of its attack pattern. Any other enemy ends its
## Pursuit at once, and does nothing if it is not in Pursuit.
func react_to_hiding(spot: Vector2, noise_before: float) -> void:
	if _dead or not is_instance_valid(target):
		return
	var saw := _to_target().length() <= noise_before if tuning.sound_hunter else _target_in_sight()
	if not saw:
		end_pursuit()
		return
	_dragging = true
	_drag_spot = spot
	_grab_started = false
	_drag_start_frame = -1
	_state = State.PURSUIT
	_last_seen = spot
	_unseen_frames = 0


# Whether the target is in a Hiding spot, where nothing can notice him.
func _target_hidden() -> bool:
	return target.get(&"hiding") == true


# Whether it notices the target now: a Sound hunter by the Noise he makes, any other enemy by Sight.
# Nobody notices him in a Hiding spot.
func _target_noticed() -> bool:
	if _target_hidden():
		return false
	if tuning.sound_hunter:
		return _target_in_earshot()
	return _target_in_sight()


# Whether the target makes Noise that reaches it now, through walls.
func _target_in_earshot() -> bool:
	var radius: Variant = target.get(&"noise_radius")
	return radius != null and float(radius) > 0.0 and _to_target().length() <= float(radius)


# Whether the target is in its Sight now: inside the cone, which points the way it faces, as long as the light at the target
# lets it reach, and with no wall in between.
func _target_in_sight() -> bool:
	var light := LightZone.light_at(
		get_tree().get_nodes_in_group("light_zones"), target.global_position,
		get_tree().get_nodes_in_group("torches") + get_tree().get_nodes_in_group("fires"),
	)
	return Sight.sees(
		get_world_2d().direct_space_state, global_position, _facing, target.global_position,
		tuning.sight_arc_degrees, tuning.sight_length_at(light), WALL_MASK,
	)


# Between attacks. At its post it stands facing the way it was set. Walking back it goes to its
# post and then faces the way it was set. In Pursuit with the target in its Sight it attacks if
# he is close enough and walks towards him if not; without him in its Sight it walks to the place
# it last saw him and waits there.
func _act_freely() -> void:
	match _state:
		State.RETURNING:
			if _walk_to(_post):
				_state = State.POST
				_facing = post_facing.normalized()
			return
		State.POST:
			return
	if not _sees_target and not _dragging:
		_walk_to(_last_seen)
		return
	# Dragging, it goes for the Hiding spot, not for where he is.
	var to_target := _drag_spot - global_position if _dragging else _to_target()
	if not to_target.is_zero_approx():
		_facing = to_target.normalized()
	if to_target.length() <= tuning.attack_range:
		# It makes the next attack in its order, whatever came of the one before.
		if _dragging:
			_kind = EnemyTuning.AttackKind.UNBLOCKABLE
		else:
			_kind = tuning.attack_pattern[_next_in_pattern % tuning.attack_pattern.size()]
			_next_in_pattern += 1
		_frame = 0
		var box := _hitbox_of(_kind)
		box.damage = current_attack.damage
		# It commits to the swing: it goes where the target was now, wherever it moves to, and
		# keeps facing that way until the swing is over.
		box.rotation = _facing.angle()
		_unblockable_hitbox.grab = _dragging
		_grab_started = _grab_started or (_dragging and _kind == EnemyTuning.AttackKind.UNBLOCKABLE)
		if _kind == EnemyTuning.AttackKind.UNBLOCKABLE:
			_unblockable_cue.play()
			unblockable_cue_played.emit()
	else:
		velocity = to_target.normalized() * tuning.move_speed
		move_and_slide()


# One physics frame of the walk to the place it was sent to.
func _walk_to_follow_place() -> void:
	_frame = -1
	_set_strike(false)
	if _broken and Engine.get_physics_frames() >= _break_end_frame:
		_broken = false
	if _broken:
		velocity = Vector2.ZERO
	else:
		_follow_arrived = _walk_to(_follow_place)
	_show_look()
	_nose.rotation = _facing.angle()


# Walks towards this place, facing the way it goes and stopping on it. Returns whether it is there.
func _walk_to(place: Vector2) -> bool:
	var to_place := place - global_position
	if to_place.length() <= ARRIVED_DISTANCE:
		velocity = Vector2.ZERO
		return true
	_facing = to_place.normalized()
	# Never faster than it takes to land on the place, so that it does not overshoot it.
	velocity = _facing * minf(tuning.move_speed, to_place.length() / get_physics_process_delta_time())
	move_and_slide()
	return false


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
		modulate = SOUND_HUNTER_TINT if tuning.sound_hunter else Color.WHITE


# The tint of the wind-up of the attack it is making: an Unblockable attack's flashes white
# first and then keeps a tint of its own, a Low attack's and the Strike's have one each.
func _wind_up_tint() -> Color:
	match _kind:
		EnemyTuning.AttackKind.LOW:
			return LOW_WIND_UP_TINT
		EnemyTuning.AttackKind.UNBLOCKABLE:
			return UNBLOCKABLE_FLASH_TINT if _frame < tuning.unblockable_flash_frames else UNBLOCKABLE_WIND_UP_TINT
	return WIND_UP_TINT


# A hit of any kind makes it notice the target, whatever its Sight shows.
func _notice_the_hit(_from := Vector2.ZERO) -> void:
	_state = State.PURSUIT
	_last_seen = target.global_position if is_instance_valid(target) else global_position
	_unseen_frames = 0


# A hit of its own Hurtbox landed. A Critical hit ends a Break and builds no Stagger. Any other
# builds what the attack builds, and more if the hit came from behind, unless it is broken.
func _on_hit_landed(hit_stagger: float, from: Vector2, critical: bool) -> void:
	_notice_the_hit()
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
	if named and id != &"":
		WorldState.record_defeated(id)
	died.emit()
	queue_free()
