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
##
## A prop whose tuning says it breaks (a barrel) does not come to rest where a throw ends: it bursts
## apart in staves and hoops and is gone, as a burnt-out thing is, until enemies return, when it is
## whole again where it first stood. A knock from the floor breaks it only if it hits something.
## Gone, by breaking or by burning out, it blocks nothing.

const BURST_SCENE := preload("res://scenes/world/impact_burst.tscn")
const DUST_SCRIPT := preload("res://scenes/world/throw_dust.gd")
const BREAK_SCRIPT := preload("res://scenes/world/prop_break.gd")

## What it is stopped by in flight, as collision mask bits: walls and enemy hurtboxes.
const WALLS := 1 << 0
const ENEMY_HURTBOX := 1 << 2
## The inside of a Gap or a Drop, where a prop that comes down falls in.
const GAP_AREA := 1 << 5
## In pixels: how far short of what it hits it comes to rest.
const REST_SHORT := 10.0
## How a grip looks: its look shudders this many pixels side to side. A look.
const GRIP_SHAKE := 2.0
## How a refusal looks, when it is too heavy to move: its look jolts side to side, harder, for this
## many physics frames. A look.
const SHUDDER_SHAKE := 3.0
const SHUDDER_FRAMES := 18
## In pixels: how far it leans the way it is drawn or pushed at the start of a shudder. A look.
const SHUDDER_LEAN := 6.0

enum State { RESTING, GRIPPED, LIFTING, HELD, FLYING, BROKEN }

## Emitted each time a Pull or a Shove is too much for its Weight and it shudders instead.
signal shuddered

## Emitted when it comes to rest after a flight.
signal landed
## Emitted when it breaks apart where its flight ends, instead of coming to rest.
signal broke
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
var _shudder_way := Vector2.ZERO
# Whether this flight is a knock from the floor rather than a throw from his hold.
var _knocked := false

## Where it is held and thrown from, beside the one who lifts it: two small rocks are held side by side.
var hold_offset := Vector2.ZERO
# Where it first stood, where it is whole again after it broke.
var _home_position := Vector2.ZERO


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
	_home_position = _prop.global_position
	var flammable := _flammable()
	if flammable != null:
		flammable.burned_out.connect(_on_gone)
		flammable.restored.connect(_on_whole_again)


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


## Too heavy for the Pull or Shove: it jolts where it stands and stays there, rocking the way given
## (toward the one who Pulls, away from the one who Shoves) as it strains.
func shudder(way := Vector2.ZERO) -> void:
	if _state == State.RESTING:
		_shudder_left = SHUDDER_FRAMES
		_shudder_way = way.normalized() if not way.is_zero_approx() else Vector2.ZERO
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
	_knocked = knocked
	_direction = direction.normalized()
	_left = throw_tuning.knock_range if knocked else throw_tuning.throw_range
	_range = _left
	# Thrown from over his head, it flies from above his feet and comes down as it goes; knocked
	# from the floor, it skids along it.
	_height = 0.0 if knocked or _holder == null else throw_tuning.hold_height
	_ground = _holder.global_position + hold_offset if _height > 0.0 else _prop.global_position
	_state = State.FLYING
	_holder = null
	_dust = DUST_SCRIPT.new()
	_prop.get_parent().add_child(_dust)
	_dust.call(&"follow", _prop)


func _physics_process(delta: float) -> void:
	if _shudder_left > 0:
		_shudder_left -= 1
		var jolt := SHUDDER_SHAKE if _shudder_left % 4 < 2 else -SHUDDER_SHAKE
		# It strains the way it is drawn or pushed, most at the start, and rocks back as it gives up.
		var strain := _shudder_way * SHUDDER_LEAN * (float(_shudder_left) / SHUDDER_FRAMES)
		var offset := Vector2(jolt, -2.0 if _shudder_left % 8 < 2 else 0.0) + strain
		_set_look_offset(offset.snapped(Vector2(2.0, 2.0)) if _shudder_left > 0 else Vector2.ZERO)
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
	return _holder.global_position + hold_offset + Vector2(0.0, -throw_tuning.hold_height)


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
		_smash_what_it_hit(found["collider"])
		if hurtbox != null:
			hurtbox.hurt_damage_only(tuning.damage, at)
			var enemy := hurtbox.get_parent()
			if enemy != null and enemy.has_method(&"slide") and enemy.get(&"dead") != true:
				enemy.slide(_direction, tuning.knockback, throw_tuning.throw_speed)
			struck.emit(hurtbox)
		_prop.global_position = at - _direction * REST_SHORT
		if tuning.get(&"breaks") == true:
			_break_apart(at)
			return
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
		if tuning.get(&"breaks") == true and not _knocked:
			_break_apart(_ground)
			return
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


## Hit by something thrown: a prop that breaks (a barrel) breaks apart where it stands, the way it
## was hit. Anything else is left as it is.
func smash(direction: Vector2) -> void:
	if tuning.get(&"breaks") != true or _state != State.RESTING:
		return
	_direction = direction.normalized() if not direction.is_zero_approx() else Vector2.DOWN
	_take_up()
	_break_apart(_prop.global_position)


## Whether, thrown, it crashes through a metal gate.
func crushes() -> bool:
	return tuning.get(&"crushes") == true


# What its flight ran into: a barrel breaks, and a gate a rock crashes into gives way.
func _smash_what_it_hit(collider: Object) -> void:
	var node := collider as Node
	if node == null:
		return
	var other := _liftable_of(node)
	if other != null and other != self:
		other.smash(_direction)
	elif node.has_method(&"smash_by"):
		node.call(&"smash_by", self, _direction)


func _liftable_of(node: Node) -> Node:
	var prop_node := node.get_parent() if node.name == &"Body" else node
	if prop_node == null:
		return null
	for child in prop_node.get_children():
		if child.get_script() == get_script():
			return child
	return null


# Where its flight ends it breaks apart: its art bursts into pieces and the prop is gone, nothing to
# block, hide in or lift, until enemies return.
func _break_apart(at: Vector2) -> void:
	var art := _prop.get_node_or_null("Look/Art") as Sprite2D
	if art != null and art.texture != null:
		var pieces: Node2D = BREAK_SCRIPT.new()
		_prop.get_parent().add_child(pieces)
		pieces.global_position = at
		pieces.call(&"shatter", art.texture, art.position + (_prop.global_position - at), art.scale, _direction)
	else:
		_burst(at)
	_prop.global_position = at.snapped(Vector2(2.0, 2.0))
	_go()


# Its flight ended over a Gap or a Drop: it falls in and is gone, as a broken one is.
func _fall_in() -> void:
	_go()


# Gone, broken or fallen: nothing to block, hide in or lift, until enemies return.
func _go() -> void:
	_state = State.BROKEN
	if _dust != null and is_instance_valid(_dust):
		_dust.call(&"stop")
	_dust = null
	_prop.z_index = _home_z
	_set_look_offset(Vector2.ZERO)
	var flammable := _flammable()
	if flammable != null:
		flammable.burn_out_now()
	else:
		_prop.visible = false
	broke.emit()


# Burnt out or broken: it is gone, and blocks nothing.
func _on_gone() -> void:
	for solid in _bodies:
		solid.collision_layer = 0


# Whole again after a return. One that broke stands where it first stood.
func _on_whole_again() -> void:
	if _state == State.BROKEN:
		_state = State.RESTING
		_prop.global_position = _home_position
		_prop.visible = true
	if _state == State.RESTING:
		for i in _bodies.size():
			_bodies[i].collision_layer = _home_layers[i]


# Whether it is over the inside of a Gap or a Drop (layer gap_area).
func _over_a_drop() -> bool:
	var query := PhysicsPointQueryParameters2D.new()
	query.position = _prop.global_position
	query.collision_mask = GAP_AREA
	query.collide_with_areas = true
	query.collide_with_bodies = false
	return not _prop.get_world_2d().direct_space_state.intersect_point(query, 1).is_empty()


func _flammable() -> Flammable:
	return _prop.get(&"flammable") as Flammable


# Back on the floor: a prop again. One whose flight ends over a Gap or a Drop falls in and is gone,
# until enemies return.
func _come_to_rest() -> void:
	var was_flying := _state == State.FLYING
	if was_flying and _over_a_drop():
		_fall_in()
		return
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
