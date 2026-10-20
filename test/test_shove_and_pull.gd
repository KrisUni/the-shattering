extends GutTest
## Shove and Pull on an enemy, in the test room with the real Almos, the real training enemy and the
## shipped numbers, driven through the switch_spell, cast_spell and lock_on actions. The enemy has no
## target, so it stands where it is put and never goes after him. Every distance, cost and Weight is
## worked from the Spells' cost files, the tunings and the room's own nodes, so nothing here pins a
## number in them. The one exception is the Weight limit rule, worked by hand from numbers this
## test gives.

const AlmosInput := preload("res://test/helpers/almos_input.gd")
const EnemyRig := preload("res://test/helpers/enemy_rig.gd")

const TEST_ROOM_PATH := "res://scenes/test_room.tscn"
const PULL_PATH := "res://data/pull.tres"
const SHOVE_PATH := "res://data/shove.tres"
const SOUND_HUNTER_PATH := "res://data/sound_hunter.tres"
const TOLERANCE := 0.0001
# In pixels. How far a slide may be off by the step of a frame.
const DISTANCE_TOLERANCE := 0.5
# In physics frames. How long a button is held for a tap.
const TAP_FRAMES := 2
# In physics frames. Slack added to a computed wait.
const MARGIN_FRAMES := 8
# In pixels. How far inside or outside a range a thing is put to try it.
const EDGE_MARGIN := 1.0
# In pixels. Where the enemy stands from him when the distance does not matter: nearer than any range.
const NEAR := 60.0
# In degrees. How far inside or outside the cone's edge an enemy is put.
const ANGLE_MARGIN := 5.0
# In pixels. Where Almos stands for a test in open floor of the room.
const OPEN_FLOOR := Vector2(576.0, 324.0)
# In pixels. How far the room's Gap is from its middle row.
const LOCK_ON_DISTANCE := 100.0
# A Weight limit rule worked by hand: 7 + 3 * 4 = 19.
const WORKED_BASE := 7.0
const WORKED_PER_STRENGTH := 3.0
const WORKED_STRENGTH := 4
const WORKED_LIMIT := 19.0

var _almos_input: AlmosInput
var _pull: SpellCost
var _shove: SpellCost
var _room: Node
var _almos: Almos
var _enemy
var _shuddered := 0
var _died := 0
var _jitter_seen := false


func before_each() -> void:
	await get_tree().process_frame
	_almos_input = AlmosInput.new(self)
	_shuddered = 0
	_died = 0
	_jitter_seen = false
	_pull = load(PULL_PATH) as SpellCost
	_shove = load(SHOVE_PATH) as SpellCost
	assert_not_null(_pull, "Pull's cost file should load")
	assert_not_null(_shove, "Shove's cost file should load")


func after_each() -> void:
	if get_tree().physics_frame.is_connected(_watch_the_look):
		get_tree().physics_frame.disconnect(_watch_the_look)
	_almos_input.release_everything()


# --- the Weight limit rule ---


func test_the_greatest_weight_is_the_base_plus_each_point_of_strength() -> void:
	var tuning := PlayerTuning.new()
	tuning.weight_limit_base = WORKED_BASE
	tuning.weight_limit_per_strength = WORKED_PER_STRENGTH
	tuning.strength = WORKED_STRENGTH

	assert_almost_eq(tuning.greatest_weight(), WORKED_LIMIT, TOLERANCE)


func test_the_training_enemy_is_within_the_shipped_limit_and_the_sound_hunter_is_over_it() -> void:
	var limit := (load(AlmosInput.TUNING_PATH) as PlayerTuning).greatest_weight()
	var training := load(EnemyRig.TUNING_PATH) as EnemyTuning
	var hunter := load(SOUND_HUNTER_PATH) as EnemyTuning

	assert_lte(training.weight, limit, "the training enemy")
	assert_gt(hunter.weight, limit, "the Sound hunter")


# --- Shove ---


func test_shove_slides_the_enemy_straight_away_by_the_shove_distance() -> void:
	_set_up_room(OPEN_FLOOR, OPEN_FLOOR + Vector2(NEAR, 0.0))
	var start: Vector2 = _enemy.global_position
	await _select(AlmosSpell.Spell.SHOVE)

	await _cast()
	await _wait_for_the_slide(_shove)

	assert_almost_eq(_enemy.global_position.x, start.x + _shove.distance, DISTANCE_TOLERANCE, "x")
	assert_almost_eq(_enemy.global_position.y, start.y, DISTANCE_TOLERANCE, "y")


func test_shove_pays_its_health_and_stamina_cost() -> void:
	_set_up_room(OPEN_FLOOR, OPEN_FLOOR + Vector2(NEAR, 0.0))
	await _select(AlmosSpell.Spell.SHOVE)

	await _cast()

	assert_almost_eq(_almos.health.current, _almos.health.maximum - _shove.health_cost, TOLERANCE, "Health")
	assert_almost_eq(_almos.stamina.current, _almos.stamina.maximum - _shove.stamina_cost, 0.5, "Stamina")


func test_shove_moves_an_enemy_in_the_cone_aimed_down_the_cone_edge() -> void:
	_set_up_room(OPEN_FLOOR, OPEN_FLOOR + _in_the_cone_at(_shove.cone_half_angle_degrees - ANGLE_MARGIN, NEAR))
	var start: Vector2 = _enemy.global_position
	await _select(AlmosSpell.Spell.SHOVE)

	await _cast()
	await _wait_for_the_slide(_shove)

	var away := (start - _almos.global_position).normalized()
	assert_almost_eq((_enemy.global_position - start).dot(away), _shove.distance, DISTANCE_TOLERANCE, "slid along the line away from him")


func test_shove_leaves_an_enemy_outside_the_cone_and_spends_nothing() -> void:
	_set_up_room(OPEN_FLOOR, OPEN_FLOOR + _in_the_cone_at(_shove.cone_half_angle_degrees + ANGLE_MARGIN, NEAR))
	var start: Vector2 = _enemy.global_position
	await _select(AlmosSpell.Spell.SHOVE)

	await _cast()
	await _wait_for_the_slide(_shove)

	assert_eq(_enemy.global_position, start, "enemy")
	_assert_nothing_was_spent()


func test_shove_leaves_an_enemy_out_of_range_and_spends_nothing() -> void:
	_set_up_room(OPEN_FLOOR, OPEN_FLOOR + Vector2(_shove.target_range + EDGE_MARGIN, 0.0))
	var start: Vector2 = _enemy.global_position
	await _select(AlmosSpell.Spell.SHOVE)

	await _cast()
	await _wait_for_the_slide(_shove)

	assert_eq(_enemy.global_position, start, "enemy")
	_assert_nothing_was_spent()


func test_shove_moves_an_enemy_just_inside_the_range() -> void:
	_set_up_room(OPEN_FLOOR, OPEN_FLOOR + Vector2(_shove.target_range - EDGE_MARGIN, 0.0))
	var start: Vector2 = _enemy.global_position
	await _select(AlmosSpell.Spell.SHOVE)

	await _cast()
	await _wait_for_the_slide(_shove)

	assert_gt(_enemy.global_position.x, start.x + _shove.distance - DISTANCE_TOLERANCE)


func test_shove_picks_the_nearer_of_two_enemies_in_the_cone() -> void:
	# The room's enemy comes first in the group and is the nearer: the nearer is not simply the last.
	_set_up_room(OPEN_FLOOR, OPEN_FLOOR + Vector2(NEAR, 0.0))
	var far_one = _add_another_enemy(OPEN_FLOOR + Vector2(NEAR * 2.0, 0.0))
	var near_one = _enemy
	var far_start: Vector2 = far_one.global_position
	var near_start: Vector2 = near_one.global_position
	await _select(AlmosSpell.Spell.SHOVE)

	await _cast()
	await _wait_for_the_slide(_shove)

	assert_almost_eq(near_one.global_position.x, near_start.x + _shove.distance, DISTANCE_TOLERANCE, "the nearer one moved")
	assert_eq(far_one.global_position, far_start, "the farther one did not")


func test_shove_aims_at_the_lock_on_target_and_not_along_his_facing() -> void:
	# Up and to the right of him, far outside the cone of his facing (to the right).
	var offset := Vector2(1.0, -1.0).normalized() * LOCK_ON_DISTANCE
	_set_up_room(OPEN_FLOOR, OPEN_FLOOR + offset)
	var start: Vector2 = _enemy.global_position
	await _select(AlmosSpell.Spell.SHOVE)
	await _tap(&"lock_on")
	await wait_physics_frames(AlmosInput.SETTLE_FRAMES)
	assert_true(_almos.locked_on, "he should have locked on")

	await _cast()
	await _wait_for_the_slide(_shove)

	assert_almost_eq((_enemy.global_position - start).dot(offset.normalized()), _shove.distance, DISTANCE_TOLERANCE)


func test_shove_without_lock_on_does_not_reach_an_enemy_outside_his_facing_cone() -> void:
	var offset := Vector2(1.0, -1.0).normalized() * LOCK_ON_DISTANCE
	_set_up_room(OPEN_FLOOR, OPEN_FLOOR + offset)
	var start: Vector2 = _enemy.global_position
	await _select(AlmosSpell.Spell.SHOVE)

	await _cast()
	await _wait_for_the_slide(_shove)

	assert_eq(_enemy.global_position, start)


func test_a_shoved_enemy_does_not_attack_while_it_slides_and_an_attack_under_way_is_interrupted() -> void:
	_set_up_room(OPEN_FLOOR, OPEN_FLOOR + Vector2(NEAR, 0.0))
	_enemy.target = _almos
	_enemy.post_facing = Vector2.LEFT
	await _select(AlmosSpell.Spell.SHOVE)
	var attacking := await _wait_until(func() -> bool: return _enemy.attacking)
	assert_true(attacking, "it should start an attack")

	await _cast()

	assert_true(_enemy.sliding, "sliding")
	assert_false(_enemy.attacking, "attacking")
	assert_false(_enemy.striking, "striking")


# --- walls ---


func test_a_wall_builds_wall_stagger_and_breaks_a_fresh_enemy_with_no_damage() -> void:
	_set_up_by_the_right_wall()
	var health_before: float = _enemy.health.current
	await _select(AlmosSpell.Spell.SHOVE)

	await _cast()
	await _wait_for_the_slide(_shove)

	assert_true(_enemy.broken, "broken")
	assert_almost_eq(_enemy.health.current, health_before, TOLERANCE, "Health")


func test_a_wall_builds_exactly_wall_stagger_of_stagger() -> void:
	_set_up_by_the_right_wall()
	var tuning := (_enemy.tuning as EnemyTuning).duplicate() as EnemyTuning
	tuning.wall_stagger = tuning.stagger_capacity / 4.0
	_enemy.tuning = tuning
	await _select(AlmosSpell.Spell.SHOVE)

	await _cast()
	await _wait_for_the_slide(_shove)

	assert_false(_enemy.broken, "broken")
	assert_almost_eq(_enemy.stagger.current, tuning.wall_stagger, TOLERANCE)


func test_a_wall_stops_the_enemy_against_it() -> void:
	_set_up_by_the_right_wall()
	await _select(AlmosSpell.Spell.SHOVE)

	await _cast()
	await _wait_for_the_slide(_shove)

	var face := _right_wall_face()
	assert_almost_eq(_enemy.global_position.x, face - _body_radius(), DISTANCE_TOLERANCE)
	assert_false(_enemy.sliding, "sliding")


# --- Gaps and Ledges ---


func test_shoved_into_the_gap_from_its_east_side_the_enemy_dies_with_its_experience() -> void:
	_set_up_east_of_the_gap()
	_enemy.died.connect(func() -> void: _died += 1)
	var experience_before: int = _almos.experience.total
	await _select(AlmosSpell.Spell.SHOVE)

	await _cast()
	await _wait_for_the_slide(_shove)

	assert_eq(_died, 1, "died")
	assert_eq(_almos.experience.total, experience_before + (load(EnemyRig.TUNING_PATH) as EnemyTuning).experience, "Experience")


func test_a_ledge_side_blocks_a_sliding_enemy() -> void:
	_set_up_room(OPEN_FLOOR, OPEN_FLOOR)
	var ledge = _room_node("Ledge")
	var east_face: float = ledge.global_position.x + ledge.size.x / 2.0
	_enemy.global_position = Vector2(east_face + _shove.distance / 2.0, ledge.global_position.y)
	_almos.global_position = _enemy.global_position + Vector2(NEAR, 0.0)
	_almos.facing = Vector2.LEFT
	await _select(AlmosSpell.Spell.SHOVE)

	await _cast()
	await _wait_for_the_slide(_shove)

	assert_almost_eq(_enemy.global_position.x, east_face + _body_radius(), DISTANCE_TOLERANCE, "stopped at the Ledge's side")
	assert_false(_enemy.dead, "dead")


# --- Pull ---


func test_pull_slides_the_enemy_towards_him_and_stops_at_the_pull_distance() -> void:
	_set_up_room(OPEN_FLOOR, OPEN_FLOOR + Vector2(_pull.target_range - EDGE_MARGIN, 0.0))

	await _cast()
	await _wait_for_the_slide(_pull)

	assert_almost_eq(_enemy.global_position.distance_to(_almos.global_position), _pull.distance, DISTANCE_TOLERANCE)
	assert_almost_eq(_enemy.global_position.y, OPEN_FLOOR.y, DISTANCE_TOLERANCE, "stays on the line")


func test_pull_pays_its_cost_and_stays_selected() -> void:
	_set_up_room(OPEN_FLOOR, OPEN_FLOOR + Vector2(NEAR * 2.0, 0.0))

	await _cast()

	assert_eq(_almos.spell.selected, AlmosSpell.Spell.PULL, "selection")
	assert_almost_eq(_almos.health.current, _almos.health.maximum - _pull.health_cost, TOLERANCE, "Health")
	assert_almost_eq(_almos.stamina.current, _almos.stamina.maximum - _pull.stamina_cost, 0.5, "Stamina")


func test_pull_never_ends_with_the_enemy_on_top_of_him() -> void:
	_set_up_room(OPEN_FLOOR, OPEN_FLOOR + Vector2(_pull.distance - EDGE_MARGIN, 0.0))
	var start: Vector2 = _enemy.global_position

	await _cast()
	await _wait_for_the_slide(_pull)

	assert_eq(_enemy.global_position, start, "an enemy already closer than the stop distance stays")
	assert_gte(_enemy.global_position.distance_to(_almos.global_position), 2.0 * _body_radius(), "not overlapping")


func test_pull_leaves_an_enemy_outside_the_range_and_spends_nothing() -> void:
	_set_up_room(OPEN_FLOOR, OPEN_FLOOR + Vector2(_pull.target_range + EDGE_MARGIN, 0.0))
	var start: Vector2 = _enemy.global_position

	await _cast()
	await _wait_for_the_slide(_pull)

	assert_eq(_enemy.global_position, start, "enemy")
	_assert_nothing_was_spent()


func test_pull_leaves_an_enemy_outside_the_cone_and_spends_nothing() -> void:
	_set_up_room(OPEN_FLOOR, OPEN_FLOOR + _in_the_cone_at(_pull.cone_half_angle_degrees + ANGLE_MARGIN, NEAR * 2.0))
	var start: Vector2 = _enemy.global_position

	await _cast()
	await _wait_for_the_slide(_pull)

	assert_eq(_enemy.global_position, start, "enemy")
	_assert_nothing_was_spent()


func test_pull_takes_a_lit_torch_in_range_first_and_leaves_the_enemy() -> void:
	_set_up_room(OPEN_FLOOR, OPEN_FLOOR + Vector2(NEAR * 2.0, 0.0))
	var torch := _room_node("WallTorch") as Torch
	_almos.global_position = torch.global_position + Vector2(0.0, 40.0)
	_almos.facing = Vector2.RIGHT
	_enemy.global_position = _almos.global_position + Vector2(NEAR * 2.0, 0.0)
	var start: Vector2 = _enemy.global_position

	await _cast()
	await wait_physics_frames(MARGIN_FRAMES * 4)

	assert_false(torch.lit, "the torch is drawn")
	assert_true(_almos.spell.holding, "he holds its flame")
	assert_eq(_enemy.global_position, start, "the enemy")


# --- too heavy, and unable to pay ---


func test_an_enemy_over_the_limit_shudders_stays_put_and_the_cost_is_paid() -> void:
	_set_up_room(OPEN_FLOOR, OPEN_FLOOR + Vector2(NEAR, 0.0))
	_make_it_too_heavy()
	var start: Vector2 = _enemy.global_position
	_enemy.shuddered.connect(func() -> void: _shuddered += 1)
	get_tree().physics_frame.connect(_watch_the_look)
	await _select(AlmosSpell.Spell.SHOVE)

	await _cast()
	# Read at once: Stamina starts to refill soon after.
	assert_almost_eq(_almos.health.current, _almos.health.maximum - _shove.health_cost, TOLERANCE, "Health")
	assert_almost_eq(_almos.stamina.current, _almos.stamina.maximum - _shove.stamina_cost, 0.5, "Stamina")
	await _wait_for_the_slide(_shove)

	assert_eq(_shuddered, 1, "shuddered")
	assert_true(_jitter_seen, "its look jittered sideways")
	assert_eq(_enemy.global_position, start, "enemy")


func test_an_enemy_at_exactly_the_limit_moves() -> void:
	_set_up_room(OPEN_FLOOR, OPEN_FLOOR + Vector2(NEAR, 0.0))
	var tuning := (_enemy.tuning as EnemyTuning).duplicate() as EnemyTuning
	tuning.weight = _almos.tuning.greatest_weight()
	_enemy.tuning = tuning
	var start: Vector2 = _enemy.global_position
	await _select(AlmosSpell.Spell.SHOVE)

	await _cast()
	await _wait_for_the_slide(_shove)

	assert_almost_eq(_enemy.global_position.x, start.x + _shove.distance, DISTANCE_TOLERANCE)


func test_an_enemy_over_the_limit_does_not_move_for_pull_either() -> void:
	_set_up_room(OPEN_FLOOR, OPEN_FLOOR + Vector2(NEAR * 2.0, 0.0))
	_make_it_too_heavy()
	var start: Vector2 = _enemy.global_position
	_enemy.shuddered.connect(func() -> void: _shuddered += 1)

	await _cast()
	await _wait_for_the_slide(_pull)

	assert_eq(_shuddered, 1, "shuddered")
	assert_eq(_enemy.global_position, start, "enemy")


func test_a_raised_strength_lets_him_move_what_was_too_heavy() -> void:
	_set_up_room(OPEN_FLOOR, OPEN_FLOOR + Vector2(NEAR, 0.0))
	_make_it_too_heavy()
	var tuning := _almos.tuning.duplicate() as PlayerTuning
	tuning.strength += int(ceil(1.0 / tuning.weight_limit_per_strength))
	_almos.tuning = tuning
	_almos.spell.tuning = tuning
	var start: Vector2 = _enemy.global_position
	await _select(AlmosSpell.Spell.SHOVE)

	await _cast()
	await _wait_for_the_slide(_shove)

	assert_almost_eq(_enemy.global_position.x, start.x + _shove.distance, DISTANCE_TOLERANCE)


func test_shove_with_too_little_stamina_does_nothing() -> void:
	_set_up_room(OPEN_FLOOR, OPEN_FLOOR + Vector2(NEAR, 0.0))
	var start: Vector2 = _enemy.global_position
	await _select(AlmosSpell.Spell.SHOVE)
	_almos.stamina.spend(_almos.stamina.current - _shove.stamina_cost + 1.0)
	var stamina_before: float = _almos.stamina.current

	await _cast()
	await _wait_for_the_slide(_shove)

	assert_eq(_enemy.global_position, start, "enemy")
	assert_almost_eq(_almos.health.current, _almos.health.maximum, TOLERANCE, "Health")
	assert_gte(_almos.stamina.current, stamina_before - TOLERANCE, "Stamina")


func test_pull_with_too_little_health_does_nothing() -> void:
	_set_up_room(OPEN_FLOOR, OPEN_FLOOR + Vector2(NEAR * 2.0, 0.0))
	var start: Vector2 = _enemy.global_position
	_almos.health.take_damage(_almos.health.current - _pull.health_cost)
	var health_before: float = _almos.health.current

	await _cast()
	await _wait_for_the_slide(_pull)

	assert_eq(_enemy.global_position, start, "enemy")
	assert_almost_eq(_almos.health.current, health_before, TOLERANCE, "Health")


# --- set-up ---


# The test room as shipped, without the Sound hunter, with Almos here facing right and the room's
# training enemy there with no target, standing where it is put.
func _set_up_room(almos_at: Vector2, enemy_at: Vector2) -> void:
	var scene := load(TEST_ROOM_PATH) as PackedScene
	assert_not_null(scene, "the test room scene should load")
	_room = scene.instantiate()
	var hunter := _room.get_node("SoundHunter")
	_room.remove_child(hunter)
	hunter.free()
	add_child_autofree(_room)
	_almos = _room.get_node("Almos") as Almos
	_enemy = _room.get_node("TrainingEnemy")
	_enemy.target = null
	_place(almos_at, enemy_at)


# Almos here facing right, and the enemy there facing left.
func _place(almos_at: Vector2, enemy_at: Vector2) -> void:
	_almos.global_position = almos_at
	_almos.facing = Vector2.RIGHT
	_enemy.global_position = enemy_at
	_enemy.post_facing = Vector2.LEFT


func _room_node(node_name: String):
	return _room.get_node(node_name)


# Another training enemy in the room, with no target, standing here.
func _add_another_enemy(at: Vector2):
	var scene := load(EnemyRig.ENEMY_SCENE_PATH) as PackedScene
	var another = scene.instantiate()
	another.position = at
	_room.add_child(another)
	return another


# Almos and the enemy by the room's right wall, the enemy between him and the wall, near enough
# to it that a Shove carries it into the wall.
func _set_up_by_the_right_wall() -> void:
	_set_up_room(OPEN_FLOOR, OPEN_FLOOR)
	var face := _right_wall_face()
	var enemy_at := Vector2(face - _shove.distance / 2.0, OPEN_FLOOR.y + 80.0)
	_place(enemy_at - Vector2(NEAR, 0.0), enemy_at)


# The x of the face of the right wall the enemy meets.
func _right_wall_face() -> float:
	var wall := _room_node("Walls/WallRight") as StaticBody2D
	var shape := (wall.get_node("CollisionShape2D") as CollisionShape2D).shape as RectangleShape2D
	return wall.global_position.x - shape.size.x / 2.0


# Almos east of the Gap with the enemy between him and the Gap, so that a Shove to the west carries it
# past the Gap's east edge and into it. Returns the Gap.
func _set_up_east_of_the_gap():
	_set_up_room(OPEN_FLOOR, OPEN_FLOOR)
	var gap = _room_node("Gap")
	var right_edge: float = gap.global_position.x + gap.size.x / 2.0
	assert_lt(_shove.distance / 2.0, gap.size.x, "a Shove from half a distance east of the edge ends inside")
	var enemy_at := Vector2(right_edge + _shove.distance / 2.0, gap.global_position.y)
	_place(enemy_at + Vector2(NEAR, 0.0), enemy_at)
	_almos.facing = Vector2.LEFT
	return gap


# The radius of the enemy's body, in pixels.
func _body_radius() -> float:
	return ((_enemy.get_node("CollisionShape2D") as CollisionShape2D).shape as CircleShape2D).radius


# The enemy now weighs one more than the most he can move.
func _make_it_too_heavy() -> void:
	var tuning := (_enemy.tuning as EnemyTuning).duplicate() as EnemyTuning
	tuning.weight = _almos.tuning.greatest_weight() + 1.0
	_enemy.tuning = tuning


# An offset this long from him, this many degrees clockwise of his facing (to the right).
func _in_the_cone_at(degrees: float, length: float) -> Vector2:
	return Vector2.RIGHT.rotated(deg_to_rad(degrees)) * length


func _assert_nothing_was_spent() -> void:
	assert_almost_eq(_almos.health.current, _almos.health.maximum, TOLERANCE, "Health")
	assert_almost_eq(_almos.stamina.current, _almos.stamina.maximum, TOLERANCE, "Stamina")


# --- driving ---


# Taps an action.
func _tap(action: StringName) -> void:
	_almos_input.press_action(action)
	await wait_physics_frames(TAP_FRAMES)
	_almos_input.release_action(action)


# Taps switch_spell if this Spell is not the one selected.
func _select(spell: AlmosSpell.Spell) -> void:
	if _almos.spell.selected != spell:
		await _tap(&"switch_spell")
		await wait_physics_frames(1)
	assert_eq(_almos.spell.selected, spell, "the Spell should be selected")


# Taps the Spell button.
func _cast() -> void:
	await _tap(&"cast_spell")
	await wait_physics_frames(1)


# Waits as long as this Spell's slide can take, and then a margin.
func _wait_for_the_slide(cost: SpellCost) -> void:
	var frames := ceili(cost.target_range / cost.move_speed * Engine.physics_ticks_per_second)
	await wait_physics_frames(frames + MARGIN_FRAMES)


# Waits until this holds, up to a limit, and says whether it did.
func _wait_until(condition: Callable) -> bool:
	for i in 600:
		if condition.call():
			return true
		await wait_physics_frames(1)
	return false


func _watch_the_look() -> void:
	if is_instance_valid(_enemy) and absf((_enemy.get_node("Placeholder") as Node2D).position.x) > 0.0:
		_jitter_seen = true
