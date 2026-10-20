extends GutTest
## The bolt node of Deep bolt on its own, in a bare tree: it flies straight at its speed, dies out at
## the end of its range, and hurts only the first enemy it reaches.

const EnemyRig := preload("res://test/helpers/enemy_rig.gd")

const BOLT_PATH := "res://scenes/almos/deep_bolt.tscn"
const TOLERANCE := 0.0001
# A flight worked by hand: 300 pixels per second for 60 frames is 300 pixels.
const SPEED := 300.0
const RANGE := 500.0
const DAMAGE := 17.0
const FRAMES_PER_SECOND := 60

var _rig: EnemyRig
var _second_rig: EnemyRig


func before_each() -> void:
	await get_tree().process_frame
	_rig = EnemyRig.new(self)
	_second_rig = EnemyRig.new(self)


func after_each() -> void:
	_rig.stop_sampling()
	_second_rig.stop_sampling()


func test_it_flies_straight_at_its_speed() -> void:
	var bolt := _launch(Vector2(10.0, 20.0), Vector2.DOWN, RANGE)

	await wait_physics_frames(FRAMES_PER_SECOND)

	assert_almost_eq(bolt.global_position, Vector2(10.0, 20.0 + SPEED), Vector2.ONE * 0.5)


func test_it_dies_out_at_the_end_of_its_range() -> void:
	var bolt := _launch(Vector2.ZERO, Vector2.RIGHT, SPEED / 2.0)

	await wait_physics_frames(FRAMES_PER_SECOND)

	assert_false(is_instance_valid(bolt) and not bolt.is_queued_for_deletion(), "it should be gone")


func test_it_hurts_the_first_enemy_it_reaches_and_not_the_one_behind() -> void:
	var first = _rig.spawn_enemy(null, Vector2(100.0, 0.0))
	var second = _second_rig.spawn_enemy(null, Vector2(160.0, 0.0))
	var first_before: float = first.health.current
	var second_before: float = second.health.current
	_launch(Vector2.ZERO, Vector2.RIGHT, RANGE)

	await wait_physics_frames(FRAMES_PER_SECOND)

	assert_almost_eq(first_before - first.health.current, DAMAGE, TOLERANCE, "the first")
	assert_almost_eq(second.health.current, second_before, TOLERANCE, "the second")


func test_it_hurts_an_enemy_once() -> void:
	var enemy = _rig.spawn_enemy(null, Vector2(100.0, 0.0))
	var before: float = enemy.health.current
	_launch(Vector2.ZERO, Vector2.RIGHT, RANGE)

	await wait_physics_frames(FRAMES_PER_SECOND * 2)

	assert_almost_eq(before - enemy.health.current, DAMAGE, TOLERANCE)


func _launch(from: Vector2, direction: Vector2, flight_range: float) -> Fireball:
	var bolt := (load(BOLT_PATH) as PackedScene).instantiate() as Fireball
	add_child_autofree(bolt)
	bolt.launch(from, direction, SPEED, flight_range, DAMAGE)
	return bolt
