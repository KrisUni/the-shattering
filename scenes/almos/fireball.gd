class_name Fireball
extends Node2D
## A fireball flying in a straight line at a fixed speed. A wall stops it, and so does the first
## enemy Hurtbox it reaches, which it hurts for its damage and nothing more: no Stagger and no
## knockback. So does the first flammable thing, which it sets alight. It dies out after its range. It flies over gaps and ledges. It is freed when it
## stops.
##
## It looks ahead along each frame's step, so a thin wall or a small Hurtbox cannot be flown
## through however fast it goes.

## The physics layers it is stopped by, as the bits that set them in a collision mask: walls,
## enemy_hurtbox and flammable.
const WALLS := 1 << 0
const ENEMY_HURTBOX := 1 << 2
const FLAMMABLE := 1 << 9

## Emitted when it hits an enemy, with the Hurtbox it hurt.
signal hit(hurtbox: Hurtbox)

## How much Health it takes off the enemy it hits.
var damage := 0.0

var _direction := Vector2.RIGHT
var _speed := 0.0
var _range_left := 0.0
# Whether the flammable things its flight starts inside are found yet, and which they are.
var _started := false
var _starts_inside: Array[RID] = []


## Sets it going from this point in the world, along this unit direction, at this speed in pixels
## per second, for this many pixels, to hurt for this much.
func launch(from: Vector2, direction: Vector2, speed: float, flight_range: float, hurt_for: float) -> void:
	global_position = from
	_direction = direction.normalized()
	_speed = speed
	_range_left = flight_range
	damage = hurt_for
	rotation = _direction.angle()


func _physics_process(delta: float) -> void:
	if not _started:
		_started = true
		_find_what_it_starts_inside()
	var step := minf(_speed * delta, _range_left)
	var query := PhysicsRayQueryParameters2D.create(global_position, global_position + _direction * step, WALLS | ENEMY_HURTBOX | FLAMMABLE)
	query.collide_with_areas = true
	query.hit_from_inside = true
	query.exclude = _starts_inside
	var found := get_world_2d().direct_space_state.intersect_ray(query)
	if not found.is_empty():
		global_position = found["position"]
		var hurtbox := found["collider"] as Hurtbox
		if hurtbox != null:
			if hurtbox.hurt_damage_only(damage, global_position) != Hurtbox.Outcome.MISSED:
				hit.emit(hurtbox)
		var flammable := found["collider"] as Flammable
		if flammable != null:
			flammable.ignite()
		queue_free()
		return
	global_position += _direction * step
	_range_left -= step
	if _range_left <= 0.0:
		queue_free()


# The flammable things whose area holds the point it starts from: it does not hit them.
func _find_what_it_starts_inside() -> void:
	var query := PhysicsPointQueryParameters2D.new()
	query.position = global_position
	query.collision_mask = FLAMMABLE
	query.collide_with_areas = true
	query.collide_with_bodies = false
	for found in get_world_2d().direct_space_state.intersect_point(query):
		_starts_inside.append(found["rid"])
