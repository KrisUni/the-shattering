extends GutTest
## How the game feels apart from its rules. It runs at GameFeel.SPEED of real time, slowing its tick
## rate and its clock together so that a physics frame stays 1/60 of a second of game time. A blow
## that lands freezes the game for a moment, a hit-stop, longer for a Critical hit, a Break and a
## Parry; Fire's ticks and fireballs do not. A freeze does not eat into an enemy's Break. Under the
## test runner the pace and the hit-stop are off, so a test switches the hit-stop on to watch it.

const AlmosInput := preload("res://test/helpers/almos_input.gd")
const JAILER_SCENE := preload("res://scenes/enemies/nar_jailer.tscn")

var _almos_input: AlmosInput


func before_each() -> void:
	await get_tree().process_frame
	_almos_input = AlmosInput.new(self)
	GameFeel.hit_stop = true


func after_each() -> void:
	_almos_input.release_everything()
	GameFeel.hit_stop = false
	get_tree().paused = false


func test_the_pace_keeps_a_physics_frame_at_a_sixtieth_of_game_time() -> void:
	var ticks := roundi(GameFeel.BASE_TICKS * GameFeel.SPEED)
	assert_almost_eq(GameFeel.SPEED / float(ticks), 1.0 / GameFeel.BASE_TICKS, 0.0005, "time scale over tick rate is a sixtieth")
	assert_lt(GameFeel.SPEED, 1.0, "the game runs slower than real time")


func test_a_blow_freezes_the_game_a_moment_then_it_goes_on() -> void:
	GameFeel.blow_landed(false)
	assert_true(get_tree().paused, "frozen")
	assert_true(GameFeel.stopped(), "in a hit-stop")
	var start := Time.get_ticks_msec()
	while get_tree().paused and Time.get_ticks_msec() - start < 1000:
		await get_tree().process_frame
	var lasted := (Time.get_ticks_msec() - start) / 1000.0
	assert_false(get_tree().paused, "and it goes on")
	assert_between(lasted, GameFeel.STOP_HIT * 0.5, GameFeel.STOP_HIT + 0.1, "after a moment")


func test_heavier_moments_freeze_longer() -> void:
	assert_gt(GameFeel.STOP_CRITICAL, GameFeel.STOP_HIT, "a Critical hit freezes longer than a blow")
	assert_gt(GameFeel.STOP_BREAK, GameFeel.STOP_HIT, "and so does a Break")
	assert_gt(GameFeel.STOP_PARRY, GameFeel.STOP_HIT, "and a Parry")


func test_a_shorter_freeze_does_not_cut_a_longer_one_short() -> void:
	GameFeel.freeze(0.2)
	GameFeel.freeze(0.01)
	await wait_process_frames(1)
	var start := Time.get_ticks_msec()
	while get_tree().paused and Time.get_ticks_msec() - start < 1000:
		await get_tree().process_frame
	assert_gt(Time.get_ticks_msec() - start, 100, "the longer freeze holds")


func test_a_blow_on_an_enemy_freezes_the_game_and_fire_does_not() -> void:
	var jailer := JAILER_SCENE.instantiate()
	add_child_autofree(jailer)
	await wait_physics_frames(2)
	var hurtbox := jailer.get_node("Hurtbox") as Hurtbox
	hurtbox.hurt_damage_only(1.0, jailer.global_position + Vector2(20, 0), true)
	assert_false(get_tree().paused, "a Fire tick does not freeze it")
	hurtbox.hurt(1.0, jailer.global_position + Vector2(-20, 0), 0.0)
	assert_true(get_tree().paused, "a blow does")


func test_switched_off_nothing_freezes() -> void:
	GameFeel.hit_stop = false
	GameFeel.blow_landed(true)
	assert_false(get_tree().paused, "no hit-stop")


func test_a_freeze_does_not_eat_into_an_enemys_timings() -> void:
	var jailer := JAILER_SCENE.instantiate()
	add_child_autofree(jailer)
	await wait_physics_frames(2)
	var before: int = jailer.get(&"_ticks")
	get_tree().paused = true
	await wait_physics_frames(5)
	assert_eq(jailer.get(&"_ticks"), before, "frozen, its own count of frames stands still")
	get_tree().paused = false
	await wait_physics_frames(3)
	assert_between(jailer.get(&"_ticks") - before, 3, 4, "and goes on with the game")
