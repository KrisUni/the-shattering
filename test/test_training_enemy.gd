extends GutTest
## The training enemy, seen only through its scene. A target for it to go after is a plain
## Node2D with a Health and a Hurtbox of its own, placed by the test; a Hitbox made here
## stands in for whatever hurts the enemy. Every physics frame a sample of the enemy and
## the target is taken, so what happened can be read back frame by frame. Expected numbers
## come from the tuning data file the scene uses (or a copy a test changes) and plain
## arithmetic, never from how the code works them out.

const EnemyRig := preload("res://test/helpers/enemy_rig.gd")
const StrikeGeometry := preload("res://test/helpers/strike_geometry.gd")

# In Health points.
const TOLERANCE := 0.0001
# In Health points. A hit small enough that it takes several to kill the enemy.
const HIT_DAMAGE := 12.0
# In pixels.
const POSITION_TOLERANCE := 0.01
# A direction is a unit vector, so it needs a much tighter tolerance than pixels.
const DIRECTION_TOLERANCE := Vector2(0.0001, 0.0001)
# How many physics frames it walks for when the target is a good way off and it must still
# be walking at the end.
const APPROACH_FRAMES := 10
# How many physics frames it is watched for when it should not move at all.
const IDLE_FRAMES := 20
# How many physics frames it is given to be standing still before it is checked to be.
const SETTLE_FRAMES := 5
# In pixels. How far beyond a range the target stands when it is to be out of that range.
const OUT_OF_RANGE_MARGIN := 10.0
# How different, as the sum of the differences in red, green and blue, its look must be while
# it winds up for the player to see it.
const VISIBLE_DIFFERENCE := 0.5
# In pixels. How far a test moves the strike's reach from the one in the data file, to see the
# strike follow it.
const REACH_LONGER_BY := 20.0
const REACH_SHORTER_BY := 10.0
# In pixels. How far inside or beyond the strike's far edge a target's Hurtbox is put, when the
# strike is to catch it or just miss it.
const REACH_MARGIN := 1.0

# Where the target stands from the enemy when it is to be hit: to either side, above and on
# a slant.
var direction_params = ParameterFactory.named_parameters(
	["direction"],
	[[Vector2.LEFT], [Vector2.UP], [Vector2(0.6, 0.8)]],
)

# How the strike's reach is retuned from the one in the data file, how far beyond its far edge
# the nearest edge of the target's Hurtbox is put (a negative number is inside it), and whether
# the target is then hit.
var reach_params = ParameterFactory.named_parameters(
	["retune", "beyond_far_edge", "hits"],
	[
		[REACH_LONGER_BY, -REACH_MARGIN, true],
		[REACH_LONGER_BY, REACH_MARGIN, false],
		[-REACH_SHORTER_BY, -REACH_MARGIN, true],
		[-REACH_SHORTER_BY, REACH_MARGIN, false],
	],
)

var _rig: EnemyRig


func before_each() -> void:
	_rig = EnemyRig.new(self)


func after_each() -> void:
	_rig.stop_sampling()


func test_it_starts_with_the_health_maximum_in_the_tuning_data() -> void:
	var tuning := _rig.tuning_with()
	assert_gt(tuning.health_maximum, 0.0, "health_maximum in the data file should be positive")

	var enemy = _rig.spawn_enemy()

	assert_almost_eq(enemy.health.maximum, tuning.health_maximum, TOLERANCE)
	assert_almost_eq(enemy.health.current, tuning.health_maximum, TOLERANCE)


func test_it_takes_its_health_maximum_from_the_tuning_it_is_given() -> void:
	var tuning := _rig.tuning_with({"health_maximum": _rig.tuning_with().health_maximum / 2.0})

	var enemy = _rig.spawn_enemy(tuning)

	assert_almost_eq(enemy.health.maximum, tuning.health_maximum, TOLERANCE)
	assert_almost_eq(enemy.health.current, tuning.health_maximum, TOLERANCE)


func test_it_stays_put_without_a_target() -> void:
	_rig.spawn_enemy()

	await _rig.wait_frames(IDLE_FRAMES)

	assert_gt(_rig.samples.size(), 1, "some frames should have been sampled")
	assert_eq(_rig.samples[-1].position, _rig.samples[0].position)


func test_it_stays_put_while_its_target_is_beyond_its_notice_range() -> void:
	var tuning := _rig.tuning_with()
	_rig.spawn_enemy()
	_rig.place_target(Vector2.RIGHT * (tuning.notice_range + OUT_OF_RANGE_MARGIN))

	await _rig.wait_frames(IDLE_FRAMES)

	assert_gt(_rig.samples.size(), 1, "some frames should have been sampled")
	assert_eq(_rig.samples[-1].position, _rig.samples[0].position)


func test_it_approaches_its_target_at_the_move_speed_within_its_notice_range() -> void:
	var tuning := _rig.tuning_with()
	var direction := Vector2(0.8, 0.6)
	var distance := (tuning.attack_range + tuning.notice_range) / 2.0
	_rig.spawn_enemy()
	_rig.place_target(direction * distance)

	await _rig.wait_frames(APPROACH_FRAMES)

	var frames := _rig.samples.size() - 1
	var travelled: Vector2 = _rig.samples[-1].position - _rig.samples[0].position
	assert_gt(frames, 0, "some frames should have been sampled")
	assert_almost_eq(travelled.length(), tuning.move_speed * frames * _frame_time(), POSITION_TOLERANCE)
	assert_almost_eq(travelled.normalized(), direction, DIRECTION_TOLERANCE)


func test_it_stops_at_its_attack_range_from_its_target() -> void:
	var tuning := _rig.tuning_with()
	var step := tuning.move_speed * _frame_time()
	_rig.spawn_enemy()
	_rig.place_target(Vector2.RIGHT * (tuning.attack_range + APPROACH_FRAMES * step))

	await _rig.wait_frames(2 * APPROACH_FRAMES + SETTLE_FRAMES)

	var distance := _rig.target.position.distance_to(_rig.samples[-1].position)
	assert_lte(distance, tuning.attack_range, "it should have walked up to its attack range")
	assert_gt(distance, tuning.attack_range - step, "it should have stopped at once, not walked on")
	assert_eq(_rig.samples[-1].position, _rig.samples[-SETTLE_FRAMES].position, "it should be standing still")


func test_it_winds_up_for_the_startup_frames_before_its_hitbox_is_on() -> void:
	var tuning := _rig.tuning_with()
	var attack := tuning.attack
	_rig.spawn_enemy()
	_rig.place_target(Vector2.RIGHT * tuning.attack_range / 2.0)

	await _rig.wait_frames(attack.startup_frames + attack.active_frames + SETTLE_FRAMES)

	var winding_up := _rig.span("winding_up")
	assert_ne(winding_up.x, -1, "it should have wound up")
	assert_eq(winding_up.y - winding_up.x, attack.startup_frames, "frames it winds up for")
	assert_eq(_rig.first_sample_where("striking"), winding_up.y, "its hitbox should go on as the wind-up ends")


func test_it_looks_different_for_as_long_as_it_winds_up() -> void:
	var tuning := _rig.tuning_with()
	var attack := tuning.attack
	_rig.spawn_enemy()
	_rig.place_target(Vector2.RIGHT * tuning.attack_range)

	await _rig.wait_frames(attack.startup_frames + attack.active_frames + SETTLE_FRAMES)

	var at_rest: Color = _rig.samples[0].look
	var winding_up := _rig.span("winding_up")
	assert_ne(winding_up.x, -1, "it should have wound up")
	var unclear := []
	for i in range(winding_up.x, winding_up.y):
		if _difference(_rig.samples[i].look, at_rest) < VISIBLE_DIFFERENCE:
			unclear.append(i)
	assert_eq(unclear, [], "samples in which its look hardly differs from how it looks at rest")
	assert_eq(_rig.samples[winding_up.y].look, at_rest, "its look should go back as the wind-up ends")


func test_what_is_drawn_of_it_changes_colour_for_as_long_as_it_winds_up() -> void:
	var tuning := _rig.tuning_with()
	var attack := tuning.attack
	var enemy = _rig.spawn_enemy()
	var placeholder := enemy.get_node_or_null("Placeholder") as Polygon2D
	assert_not_null(placeholder, "it should have a Placeholder to draw")
	if placeholder == null:
		return
	assert_true(placeholder.is_visible_in_tree(), "its Placeholder should be shown")
	_rig.sample_also("drawn", func() -> Color: return _drawn_colour(placeholder))
	_rig.place_target(Vector2.RIGHT * tuning.attack_range)

	await _rig.wait_frames(attack.startup_frames + attack.active_frames + SETTLE_FRAMES)

	var at_rest: Color = _rig.samples[0].drawn
	var winding_up := _rig.span("winding_up")
	assert_ne(winding_up.x, -1, "it should have wound up")
	var unclear := []
	for i in range(winding_up.x, winding_up.y):
		if _difference(_rig.samples[i].drawn, at_rest) < VISIBLE_DIFFERENCE:
			unclear.append(i)
	assert_eq(unclear, [], "samples in which what is drawn of it hardly differs from how it is drawn at rest")
	assert_eq(_rig.samples[winding_up.y].drawn, at_rest, "it should be drawn as at rest as the wind-up ends")


func test_its_strike_shows_for_as_long_as_its_hitbox_is_on() -> void:
	var tuning := _rig.tuning_with()
	var attack := tuning.attack
	var enemy = _rig.spawn_enemy()
	var strike := enemy.get_node_or_null("Hitbox/Placeholder") as Polygon2D
	assert_not_null(strike, "its Hitbox should have a Placeholder to show the strike")
	if strike == null:
		return
	_rig.sample_also("strike_shown", func() -> bool: return strike.is_visible_in_tree())
	_rig.place_target(Vector2.RIGHT * tuning.attack_range)

	await _rig.wait_frames(attack.startup_frames + attack.active_frames + SETTLE_FRAMES)

	var striking := _rig.span("striking")
	assert_ne(striking.x, -1, "its hitbox should have gone on")
	assert_eq(striking.y - striking.x, attack.active_frames, "frames its hitbox is on for")
	var out_of_step := []
	for i in _rig.samples.size():
		if _rig.samples[i].strike_shown != _rig.samples[i].striking:
			out_of_step.append(i)
	assert_eq(out_of_step, [], "samples in which the strike is shown and its hitbox is on do not agree")


func test_its_strike_reaches_as_far_as_the_attack_reach_in_the_tuning(params = use_parameters(reach_params)) -> void:
	var reach: float = _rig.tuning_with().attack_reach + params.retune
	# Where the target stands: the nearest edge of its Hurtbox is this far beyond the strike's
	# far edge. It is in range to swing at, so that nothing but the reach decides the hit.
	var distance: float = reach + EnemyRig.TARGET_RADIUS + params.beyond_far_edge
	var tuning := _rig.tuning_with({"attack_reach": reach, "attack_range": distance})
	_rig.spawn_enemy(tuning)
	_rig.place_target(Vector2.RIGHT * distance)

	await _rig.wait_frames(_attack_frames(tuning))

	assert_eq(_rig.hits().size() == 1, params.hits, "whether the target was hit")


func test_what_is_drawn_of_its_strike_covers_the_box_that_hurts_wherever_the_reach_is_tuned_to() -> void:
	var reach := _rig.tuning_with().attack_reach + REACH_LONGER_BY
	var enemy = _rig.spawn_enemy(_rig.tuning_with({"attack_reach": reach}))
	var hitbox := enemy.get_node("Hitbox") as Hitbox
	var box_in_scene := StrikeGeometry.box_size_in_scene(EnemyRig.ENEMY_SCENE_PATH, "Hitbox")

	var real := StrikeGeometry.real_box(hitbox)
	var drawn := StrikeGeometry.drawn_box(hitbox)

	assert_almost_eq(real.end.x, reach, POSITION_TOLERANCE, "how far out the box that hurts ends")
	assert_almost_eq(real.size, box_in_scene, Vector2.ONE * POSITION_TOLERANCE, "the width and height of the box that hurts should be the scene's")
	assert_almost_eq(drawn.position, real.position, Vector2.ONE * POSITION_TOLERANCE, "where the drawn strike starts, against the box that hurts")
	assert_almost_eq(drawn.size, real.size, Vector2.ONE * POSITION_TOLERANCE, "the size of the drawn strike, against the box that hurts")


func test_its_hit_takes_its_damage_off_the_target_once_per_attack() -> void:
	var tuning := _rig.tuning_with()
	var attack := tuning.attack
	_rig.spawn_enemy()
	_rig.place_target(Vector2.RIGHT * tuning.attack_range)

	await _rig.wait_frames(attack.startup_frames + attack.active_frames + attack.recovery_frames)

	var hits := _rig.hits()
	assert_eq(hits.size(), 1, "the target should have been hit once")
	if hits.is_empty():
		return
	assert_almost_eq(hits[0].damage, attack.damage, TOLERANCE)
	assert_eq(hits[0].sample, _rig.first_sample_where("striking"), "the hit should land as its hitbox goes on")


func test_it_swings_towards_where_its_target_stands(params = use_parameters(direction_params)) -> void:
	var tuning := _rig.tuning_with()
	_rig.spawn_enemy()
	_rig.place_target(params.direction * tuning.attack_range)

	await _rig.wait_frames(_attack_frames(tuning))

	assert_eq(_rig.hits().size(), 1, "the target should have been hit once")


func test_it_commits_to_where_its_target_stood_when_the_wind_up_began() -> void:
	var tuning := _rig.tuning_with()
	var enemy = _rig.spawn_enemy()
	_rig.place_target(Vector2.RIGHT * tuning.attack_range)
	await _rig.wait_frames(SETTLE_FRAMES)
	assert_true(enemy.winding_up, "it should have begun to wind up")

	# Still within its attack range, but on the other side of it.
	_rig.target.position = Vector2.LEFT * tuning.attack_range
	await _rig.wait_frames(_attack_frames(tuning) - SETTLE_FRAMES)

	assert_eq(_rig.hits().size(), 0, "the target should not have been hit")


func test_it_stands_still_from_wind_up_through_recovery_and_then_walks_on() -> void:
	var tuning := _rig.tuning_with()
	_rig.spawn_enemy()
	_rig.place_target(Vector2.RIGHT * tuning.attack_range)
	await _rig.wait_frames(SETTLE_FRAMES)

	# Out of its attack range but still noticed, so that nothing stops it walking on once
	# the attack is over.
	_rig.target.position = Vector2.RIGHT * (tuning.attack_range + OUT_OF_RANGE_MARGIN)
	await _rig.wait_frames(_attack_frames(tuning) + SETTLE_FRAMES)

	var attacking := _rig.span("attacking")
	assert_eq(attacking.y - attacking.x, _attack_frames(tuning), "frames the attack lasts")
	for i in range(attacking.x, attacking.y):
		assert_eq(_rig.samples[i].position, _rig.samples[attacking.x].position, "its position in sample %d" % i)
	assert_ne(_rig.samples[attacking.y].position, _rig.samples[attacking.y - 1].position, "it should walk on as the attack ends")


func test_it_attacks_again_after_recovery_while_its_target_is_still_in_range() -> void:
	var tuning := _rig.tuning_with()
	_rig.spawn_enemy()
	_rig.place_target(Vector2.RIGHT * tuning.attack_range)

	await _rig.wait_frames(2 * _attack_frames(tuning))

	var hits := _rig.hits()
	assert_eq(hits.size(), 2, "the target should have been hit twice")
	if hits.size() == 2:
		assert_eq(hits[1].sample - hits[0].sample, _attack_frames(tuning), "frames between its hits")


func test_a_hit_on_it_takes_its_damage_off_its_health() -> void:
	var enemy = _rig.spawn_enemy()
	var hitbox := _rig.hitbox_over(enemy, HIT_DAMAGE, "enemy_hurtbox")
	await _rig.wait_frames(SETTLE_FRAMES)

	await _rig.swing(hitbox, 1)

	assert_almost_eq(enemy.health.current, _rig.tuning_with().health_maximum - HIT_DAMAGE, TOLERANCE)


func test_it_dies_when_its_health_reaches_zero() -> void:
	var tuning := _rig.tuning_with()
	var enemy = _rig.spawn_enemy()
	var deaths := _rig.record_deaths()
	var hitbox := _rig.hitbox_over(enemy, tuning.health_maximum, "enemy_hurtbox")
	await _rig.wait_frames(SETTLE_FRAMES)

	await _rig.swing(hitbox, 1)
	await _rig.wait_frames(SETTLE_FRAMES)

	assert_eq(deaths.size(), 1, "it should have died once")
	if deaths.size() == 1:
		assert_true(deaths[0].dead, "it should be dead by the time it announces its death")


func test_it_does_not_die_while_it_has_health_left() -> void:
	var enemy = _rig.spawn_enemy()
	var deaths := _rig.record_deaths()
	var hitbox := _rig.hitbox_over(enemy, _rig.tuning_with().health_maximum - 1.0, "enemy_hurtbox")
	await _rig.wait_frames(SETTLE_FRAMES)

	await _rig.swing(hitbox, 1)
	await _rig.wait_frames(SETTLE_FRAMES)

	assert_eq(deaths.size(), 0, "it should not have died")
	assert_false(enemy.dead, "it should not be dead")


func test_a_dead_enemy_does_not_finish_its_attack() -> void:
	var tuning := _rig.tuning_with()
	var enemy = _rig.spawn_enemy()
	_rig.place_target(Vector2.RIGHT * tuning.attack_range)
	var hitbox := _rig.hitbox_over(enemy, tuning.health_maximum, "enemy_hurtbox")
	await _rig.wait_frames(SETTLE_FRAMES)
	assert_true(enemy.winding_up, "it should have begun to wind up")

	await _rig.swing(hitbox, 1)
	await _rig.wait_frames(_attack_frames(tuning))

	assert_eq(_rig.hits().size(), 0, "the target should not have been hit")


func test_it_removes_itself_from_the_room_when_it_dies() -> void:
	var enemy = _rig.spawn_enemy()
	var hitbox := _rig.hitbox_over(enemy, _rig.tuning_with().health_maximum, "enemy_hurtbox")
	await _rig.wait_frames(SETTLE_FRAMES)

	await _rig.swing(hitbox, 1)
	await _rig.wait_frames(SETTLE_FRAMES)
	await get_tree().process_frame

	assert_false(is_instance_valid(enemy), "it should be gone")


func test_its_hitbox_is_off_when_it_dies_in_the_middle_of_a_swing() -> void:
	var tuning := _rig.tuning_with()
	var enemy = _rig.spawn_enemy()
	_rig.place_target(Vector2.RIGHT * tuning.attack_range)
	var deaths := _rig.record_deaths()
	var hitbox := _rig.hitbox_over(enemy, tuning.health_maximum, "enemy_hurtbox")
	await _rig.wait_frames(tuning.attack.startup_frames + SETTLE_FRAMES)
	assert_true(enemy.striking, "its hitbox should be on")

	await _rig.swing(hitbox, 1)

	assert_eq(deaths.size(), 1, "it should have died once")
	if deaths.size() == 1:
		assert_false(deaths[0].striking, "its hitbox should be off by the time it announces its death")


# How long one physics frame lasts, in seconds.
func _frame_time() -> float:
	return 1.0 / Engine.physics_ticks_per_second


# How many physics frames one whole attack lasts: wind-up, active frames and recovery.
func _attack_frames(tuning: EnemyTuning) -> int:
	return tuning.attack.startup_frames + tuning.attack.active_frames + tuning.attack.recovery_frames


# The colour a placeholder is drawn in: its own colour, tinted by the modulate of every node
# it hangs on, as far up as the nodes pass their modulate down.
func _drawn_colour(placeholder: Polygon2D) -> Color:
	var drawn := placeholder.color * placeholder.self_modulate
	var node: Node = placeholder
	while node is CanvasItem:
		var item := node as CanvasItem
		drawn *= item.modulate
		if item.top_level:
			break
		node = item.get_parent()
	return drawn


# How different two colours are: the differences in red, green and blue added up.
func _difference(a: Color, b: Color) -> float:
	return absf(a.r - b.r) + absf(a.g - b.g) + absf(a.b - b.b)
