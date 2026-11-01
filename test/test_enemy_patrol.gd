extends GutTest
## Patrols: an enemy given a patrol route walks it until it notices Almos, from point to point at
## the tuning's patrol_speed, facing the way it walks, stopping at each point for the patrol_pause,
## and going round again. It notices him as any enemy does, by its Sight, and having lost him it
## goes back to its round. An enemy with no route stands at its post as before. Distances and times
## are worked from the jailer's data file.

const JAILER_SCENE := preload("res://scenes/enemies/nar_jailer.tscn")
const JAILER_PATH := "res://data/nar_jailer.tres"

var _tuning: EnemyTuning


func before_each() -> void:
	_tuning = load(JAILER_PATH) as EnemyTuning


# A world with a stand-in for Almos far away, behind the patrol, and a jailer patrolling it.
func _patrolling(route: PackedVector2Array, start: Vector2, target_at := Vector2(-5000, -5000)) -> Array:
	var world := Node2D.new()
	add_child_autofree(world)
	var target := CharacterBody2D.new()
	world.add_child(target)
	target.global_position = target_at
	var jailer := JAILER_SCENE.instantiate()
	jailer.patrol = route
	world.add_child(jailer)
	jailer.global_position = start
	jailer.target = target
	return [world, jailer, target]


func _seconds_to_walk(distance: float) -> float:
	return distance / _tuning.patrol_speed


func test_the_jailer_patrols_slower_than_it_chases() -> void:
	assert_gt(_tuning.patrol_speed, 0.0, "it has a patrol speed")
	assert_lt(_tuning.patrol_speed, _tuning.move_speed, "its round is slower than its chase")
	assert_gt(_tuning.patrol_pause, 0.0, "it stops at each point")


func test_it_walks_to_its_first_point_at_patrol_speed_facing_the_way_it_walks() -> void:
	var made := _patrolling(PackedVector2Array([Vector2(300, 100), Vector2(100, 100)]), Vector2(100, 100))
	var jailer = made[1]
	await wait_physics_frames(10)
	assert_almost_eq(jailer.velocity.length(), _tuning.patrol_speed, 0.5, "it walks at patrol speed")
	assert_almost_eq(jailer.facing, Vector2.RIGHT, Vector2.ONE * 0.01, "it faces the way it walks")
	assert_false(jailer.in_pursuit, "it has not noticed anyone")


func test_it_stops_at_each_point_then_walks_on_and_goes_round_again() -> void:
	var made := _patrolling(PackedVector2Array([Vector2(160, 100), Vector2(100, 100)]), Vector2(100, 100))
	var jailer = made[1]
	await wait_seconds(_seconds_to_walk(60.0) + 0.2)
	assert_almost_eq(jailer.global_position, Vector2(160, 100), Vector2.ONE * 1.0, "it reached the first point")
	assert_almost_eq(jailer.velocity.length(), 0.0, 0.01, "it stops there")
	await wait_seconds(_tuning.patrol_pause + 0.3)
	assert_almost_eq(jailer.facing, Vector2.LEFT, Vector2.ONE * 0.01, "then it walks back to the next point")
	await wait_seconds(_seconds_to_walk(60.0) + _tuning.patrol_pause)
	assert_almost_eq(jailer.facing, Vector2.RIGHT, Vector2.ONE * 0.01, "and from the last point round to the first again")


func test_it_notices_him_ahead_on_its_round_and_gives_chase() -> void:
	# He stands ahead on its route, within its Sight.
	var made := _patrolling(PackedVector2Array([Vector2(600, 100), Vector2(100, 100)]), Vector2(100, 100), Vector2(100 + _tuning.sight_length_full - 20.0, 100))
	var jailer = made[1]
	await wait_physics_frames(3)
	assert_true(jailer.in_pursuit, "he was in its Sight ahead of it")


func test_it_does_not_notice_him_behind_it() -> void:
	var made := _patrolling(PackedVector2Array([Vector2(600, 100), Vector2(100, 100)]), Vector2(200, 100), Vector2(150, 100))
	var jailer = made[1]
	await wait_physics_frames(10)
	assert_false(jailer.in_pursuit, "he was behind it, out of its Sight")


func test_having_lost_him_it_goes_back_to_its_round() -> void:
	var made := _patrolling(PackedVector2Array([Vector2(600, 100), Vector2(100, 100)]), Vector2(100, 100), Vector2(250, 100))
	var jailer = made[1]
	var target = made[2]
	await wait_physics_frames(3)
	assert_true(jailer.in_pursuit, "control: it saw him")
	# He is gone far away; it loses him after the lose-time and walks back to its route.
	target.global_position = Vector2(-5000, -5000)
	await wait_physics_frames(_tuning.lose_sight_frames + 5)
	assert_false(jailer.in_pursuit, "it lost him")
	await wait_seconds(1.0)
	assert_almost_eq(jailer.velocity.length(), _tuning.patrol_speed, 0.5, "it walks back at its patrol speed")
	assert_almost_eq(jailer.facing, Vector2.RIGHT, Vector2.ONE * 0.01, "to the point it was walking to")
	await wait_seconds(_seconds_to_walk(600.0 - jailer.global_position.x) + 0.3)
	assert_almost_eq(jailer.global_position, Vector2(600, 100), Vector2.ONE * 1.0, "it is back on its route, at that point")
	await wait_seconds(_tuning.patrol_pause + 0.3)
	assert_almost_eq(jailer.facing, Vector2.LEFT, Vector2.ONE * 0.01, "and goes on with its round")


func test_without_a_route_it_stands_at_its_post() -> void:
	var made := _patrolling(PackedVector2Array(), Vector2(100, 100))
	var jailer = made[1]
	await wait_physics_frames(30)
	assert_almost_eq(jailer.global_position, Vector2(100, 100), Vector2.ONE * 0.01, "it stays at its post")
	assert_almost_eq(jailer.velocity.length(), 0.0, 0.01, "standing still")
