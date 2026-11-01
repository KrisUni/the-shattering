class_name Liftable
extends Node
## Lets Pull lift the prop it is part of (its parent, such as a wardrobe, a barrel or a crate stack)
## and Shove throw it. It is in the group "liftables", where Almos's Spell looks for one.
##
## Pull grips it for the wind-up (it shudders), then lifts it: it floats up over the one who lifted
## it and is held there, bobbing, following him. Shove throws it from there the way he aims; a Shove
## at one standing on the floor knocks it away from him. Flying, it hurts the first enemy it meets
## for its tuning's damage (damage only, as a fireball's hit) and knocks it back, and stops; a wall
## stops it too; otherwise it comes down after its range. Where it stops it bursts in dust and
## splinters and comes to rest, a prop again: a hiding spot can be got into, a crate stack blocks.
## Lifted or flying, it is none of that: it neither blocks nor can be hidden in. Its solid parts (the
## prop itself if it is a body, and a child StaticBody2D named Body) are switched off meanwhile.

const BURST_SCENE := preload("res://scenes/world/impact_burst.tscn")
const DUST_SCRIPT := preload("res://scenes/world/throw_dust.gd")

## What it is stopped by in flight, as collision mask bits: walls and enemy hurtboxes.
const WALLS := 1 << 0
const ENEMY_HURTBOX := 1 << 2
## In pixels: how far short of what it hits it comes to rest.
const REST_SHORT := 10.0
## How a grip looks: its look shudders this many pixels side to side. A look.
const GRIP_SHAKE := 2.0
## How a refusal looks, when it is too heavy to move: its look jolts side to side, harder, for this
## many physics frames. A look.
const SHUDDER_SHAKE := 3.0
const SHUDDER_FRAMES := 14

enum State { RESTING, GRIPPED, LIFTING, HELD, FLYING }

## Emitted each time a Pull or a Shove is too much for its Weight and it shudders instead.
signal shuddered

## Emitted when it comes to rest after a flight.
signal landed
## Emitted when it hits an enemy in flight, with the Hurtbox it hit.
signal struck(hurtbox: Hurtbox)

## Its weight, damage and knockback.
@export var tuning: Resource
## How lifting and throwing go.
@export var throw_tuning: Resource = preload("res://data/throw.tres")

## How heavy it is.
var weight: float:
	get:
		return tuning.weight

## What it is doing now.
var state: State:
	get:
		return _state

var _state := State.RESTING
var _prop: Node2D
var _holder: Node2D
var _time := 0.0
var _from := Vector2.ZERO
var _direction := Vector2.ZERO
var _left := 0.0
# In flight: where it is over the ground, which is what meets enemies and walls, and how high above
# that it flies, falling to the ground over the flight.
var _ground := Vector2.ZERO
var _height := 0.0
var _range := 0.0
# The prop's solid parts and the layers they block on at rest.
var _bodies: Array[CollisionObject2D] = []
var _home_layers: Array[int] = []
var _home_z := 0
var _dust: Node2D
var _shudder_left := 0


func _ready() -> void:
	_prop = get_parent() as Node2D
	add_to_group(&"liftables")
	if _prop is CollisionObject2D:
		_bodies.append(_prop as CollisionObject2D)
	var body := _prop.get_node_or_null("Body") as CollisionObject2D
	if body != null:
		_bodies.append(body)
	for solid in _bodies:
		_home_layers.append(solid.collision_layer)
	_home_z = _prop.z_index


## The RIDs of its solid parts, which a line to it or its own flight must not count as a wall.
func body_rids() -> Array[RID]:
	var rids: Array[RID] = []
	for solid in _bodies:
		rids.append(solid.get_rid())
	return rids


## The prop it moves.
func prop() -> Node2D:
	return _prop


## Whether it can be lifted or knocked now: at rest, not burning, and nobody hiding in it.
func can_be_moved() -> bool:
	if _state != State.RESTING:
		return false
	var flammable := _prop.get(&"flammable") as Flammable
	if flammable != null and (flammable.burning or flammable.burnt_out):
		return false
	if _prop.has_method(&"occupied") and _prop.occupied():
		return false
	return true


## The Pull's wind-up has it in its grip: it shudders where it stands.
func grip() -> void:
	if _state == State.RESTING:
		_state = State.GRIPPED


## The wind-up ended without a lift: it settles where it stands.
func release_grip() -> void:
	if _state == State.GRIPPED:
		_state = State.RESTING
		_set_look_offset(Vector2.ZERO)


## Too heavy for the Pull or Shove: it jolts where it stands and stays there.
func shudder() -> void:
	if _state == State.RESTING:
		_shudder_left = SHUDDER_FRAMES
		shuddered.emit()


## Whether it is shuddering now.
func shuddering() -> bool:
	return _shudder_left > 0


## Lifted by this one: it floats up over him and is held there.
func lift(holder: Node2D) -> void:
	_holder = holder
	_from = _prop.global_position
	_time = 0.0
	_state = State.LIFTING
	_set_look_offset(Vector2.ZERO)
	_take_up()


## Whether he holds it now, risen over him or still rising.
func held() -> bool:
	return _state == State.LIFTING or _state == State.HELD


## Put down at this place, at rest, as when the one who held it is hurt.
func drop_at(point: Vector2) -> void:
	if _state == State.RESTING or _state == State.GRIPPED:
		release_grip()
		return
	_prop.global_position = point
	_come_to_rest()


## Thrown from where it is the way given, for its range: from his hold, or knocked from the floor.
func throw(direction: Vector2, knocked := false) -> void:
	if direction.is_zero_approx():
		return
	if knocked:
		_take_up()
	_direction = direction.normalized()
	_left = throw_tuning.knock_range if knocked else throw_tuning.throw_range
	_range = _left
	# Thrown from over his head, it flies from above his feet and comes down as it goes; knocked
	# from the floor, it skids along it.
	_height = 0.0 if knocked or _holder == null else throw_tuning.hold_height
	_ground = _holder.global_position if _height > 0.0 else _prop.global_position
	_state = State.FLYING
	_holder = null
	_dust = DUST_SCRIPT.new()
	_prop.get_parent().add_child(_dust)
	_dust.call(&"follow", _prop)


func _physics_process(delta: float) -> void:
	if _shudder_left > 0:
		_shudder_left -= 1
		var jolt := SHUDDER_SHAKE if _shudder_left % 4 < 2 else -SHUDDER_SHAKE
		_set_look_offset(Vector2(jolt, -2.0 if _shudder_left % 8 < 2 else 0.0) if _shudder_left > 0 else Vector2.ZERO)
	match _state:
		State.GRIPPED:
			_set_look_offset(Vector2(GRIP_SHAKE if Engine.get_physics_frames() % 2 == 0 else -GRIP_SHAKE, 0.0))
		State.LIFTING:
			_time += delta
			var t := clampf(_time / throw_tuning.lift_time, 0.0, 1.0)
			var eased := 1.0 - pow(1.0 - t, 3.0)
			# It rises in a little arc on its way up.
			_prop.global_position = _from.lerp(_hold_point(), eased) + Vector2(0.0, -sin(t * PI) * 10.0)
			if t >= 1.0:
				_state = State.HELD
		State.HELD:
			if _holder == null or not is_instance_valid(_holder):
				_come_to_rest()
				return
			_time += delta
			_prop.global_position = _hold_point() + Vector2(0.0, roundf(sin(_time * 4.0) * 1.5) * 2.0)
		State.FLYING:
			_fly(delta)


func _hold_point() -> Vector2:
	return _holder.global_position + Vector2(0.0, -throw_tuning.hold_height)


# One physics frame of flight: it looks ahead along its step over the ground for a wall or an
# enemy, and comes down a little.
func _fly(delta: float) -> void:
	var step := minf(throw_tuning.throw_speed * delta, _left)
	var from := _ground
	var query := PhysicsRayQueryParameters2D.create(from, from + _direction * step, WALLS | ENEMY_HURTBOX)
	query.collide_with_areas = true
	query.exclude = body_rids()
	var found := _prop.get_world_2d().direct_space_state.intersect_ray(query)
	if not found.is_empty():
		var at: Vector2 = found["position"]
		var hurtbox := found["collider"] as Hurtbox
		if hurtbox != null:
			hurtbox.hurt_damage_only(tuning.damage, at)
			var enemy := hurtbox.get_parent()
			if enemy != null and enemy.has_method(&"slide") and enemy.get(&"dead") != true:
				enemy.slide(_direction, tuning.knockback, throw_tuning.throw_speed)
			struck.emit(hurtbox)
		_prop.global_position = at - _direction * REST_SHORT
		_burst(at)
		_come_to_rest()
		return
	_ground = from + _direction * step
	_left -= step
	var start_height: float = throw_tuning.hold_height if _height > 0.0 else 0.0
	var fallen := 1.0 - _left / maxf(_range, 1.0)
	var height: float = start_height * (1.0 - fallen * fallen) if start_height > 0.0 else 0.0
	_prop.global_position = _ground + Vector2(0.0, -height)
	if _left <= 0.0:
		_prop.global_position = _ground
		_burst(_ground)
		_come_to_rest()


func _burst(at: Vector2) -> void:
	var burst: Node2D = BURST_SCENE.instantiate()
	_prop.get_parent().add_child(burst)
	burst.global_position = at


# Lifted off the floor: it neither blocks nor can be hidden in, and draws over those it passes.
func _take_up() -> void:
	for solid in _bodies:
		solid.collision_layer = 0
	if _prop.is_in_group(&"hiding_spots"):
		_prop.remove_from_group(&"hiding_spots")
	_prop.z_index = 3


# Back on the floor: a prop again.
func _come_to_rest() -> void:
	var was_flying := _state == State.FLYING
	_state = State.RESTING
	_holder = null
	_prop.global_position = _prop.global_position.snapped(Vector2(2.0, 2.0))
	for i in _bodies.size():
		_bodies[i].collision_layer = _home_layers[i]
	if _prop is HidingSpot:
		var flammable := (_prop as HidingSpot).flammable
		if flammable == null or not (flammable.burning or flammable.burnt_out):
			_prop.add_to_group(&"hiding_spots")
	_prop.z_index = _home_z
	_set_look_offset(Vector2.ZERO)
	if _dust != null and is_instance_valid(_dust):
		_dust.call(&"stop")
	_dust = null
	if was_flying:
		landed.emit()


func _set_look_offset(offset: Vector2) -> void:
	var look := _prop.get_node_or_null("Look") as Node2D
	if look != null:
		look.position = offset
