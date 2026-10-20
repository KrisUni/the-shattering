extends GutTest
## Movable objects, the Crate and the Boulder. Alone, a Movable is tested through its scene: its
## Weight from its data file, its slide and its shudder. In the test room, with the real Almos and
## the shipped numbers, driven through the switch_spell and cast_spell actions, Shove and Pull move the
## Crate, a Pull fetches it across the Gap, a wall stops it whole, the Gap takes it, and the Boulder
## only shudders. Every distance, cost and Weight is worked from the data files and the room's own
## nodes, so nothing here pins a number in them.

const AlmosInput := preload("res://test/helpers/almos_input.gd")

const TEST_ROOM_PATH := "res://scenes/test_room.tscn"
const MOVABLE_PATH := "res://scenes/world/movable.tscn"
const CRATE_PATH := "res://data/crate.tres"
const BOULDER_PATH := "res://data/boulder.tres"
const PULL_PATH := "res://data/pull.tres"
const SHOVE_PATH := "res://data/shove.tres"
const TOLERANCE := 0.0001
const DISTANCE_TOLERANCE := 0.5
# In physics frames.
const TAP_FRAMES := 2
const MARGIN_FRAMES := 8
# In pixels.
const NEAR := 60.0
const OPEN_FLOOR := Vector2(576.0, 324.0)
# In pixels per second, and pixels. A slide for the unit tests, worked by hand: 300 / 60 = 5 a frame.
const UNIT_SPEED := 300.0
const UNIT_DISTANCE := 50.0

var _almos_input: AlmosInput
var _pull: SpellCost
var _shove: SpellCost
var _room: Node
var _almos: Almos
var _crate
var _boulder
var _enemy
var _shuddered := 0
var _fell := 0
var _jitter_seen := false


func before_each() -> void:
	await get_tree().process_frame
	_almos_input = AlmosInput.new(self)
	_shuddered = 0
	_fell = 0
	_jitter_seen = false
	_pull = load(PULL_PATH) as SpellCost
	_shove = load(SHOVE_PATH) as SpellCost


func after_each() -> void:
	if get_tree().physics_frame.is_connected(_watch_the_look):
		get_tree().physics_frame.disconnect(_watch_the_look)
	_almos_input.release_everything()


# --- a Movable alone ---


func test_a_movables_weight_comes_from_its_data_file() -> void:
	var movable = _alone(CRATE_PATH)

	assert_almost_eq(movable.weight, (load(CRATE_PATH) as MovableTuning).weight, TOLERANCE)


func test_the_crate_is_within_the_shipped_limit_and_the_boulder_is_over_it() -> void:
	var limit := (load(AlmosInput.TUNING_PATH) as PlayerTuning).greatest_weight()

	assert_lte((load(CRATE_PATH) as MovableTuning).weight, limit, "Crate")
	assert_gt((load(BOULDER_PATH) as MovableTuning).weight, limit, "Boulder")


func test_a_movable_slides_the_distance_it_is_given_at_the_speed_it_is_given() -> void:
	var movable = _alone(CRATE_PATH)

	movable.slide(Vector2.RIGHT, UNIT_DISTANCE, UNIT_SPEED)
	await wait_physics_frames(3)

	assert_almost_eq(movable.position.x, 3.0 * UNIT_SPEED / Engine.physics_ticks_per_second, DISTANCE_TOLERANCE, "after 3 frames")
	await wait_physics_frames(int(UNIT_DISTANCE / UNIT_SPEED * Engine.physics_ticks_per_second) + MARGIN_FRAMES)
	assert_almost_eq(movable.position.x, UNIT_DISTANCE, DISTANCE_TOLERANCE, "at the end")
	assert_false(movable.sliding, "sliding")


func test_a_movable_shudders_without_moving() -> void:
	var movable = _alone(BOULDER_PATH)
	movable.shuddered.connect(func() -> void: _shuddered += 1)

	movable.shudder()
	await wait_physics_frames(2)

	assert_eq(_shuddered, 1, "shuddered")
	assert_ne((movable.get_node("Placeholder") as Node2D).position.x, 0.0, "its look jittered")
	assert_eq(movable.position, Vector2.ZERO, "position")


func test_a_movable_blocks_like_a_wall() -> void:
	var movable = _alone(CRATE_PATH)

	assert_true(movable.is_in_group(&"movables"), "group")
	assert_ne(movable.collision_layer & _layer_bit("walls"), 0, "on the walls layer")


# --- the Crate in the test room ---


func test_the_test_rooms_crate_is_west_of_the_gap_and_the_boulder_is_over_the_limit() -> void:
	_set_up_room()
	var gap = _room.get_node("Gap")

	assert_lt(_crate.global_position.x, gap.global_position.x - gap.size.x / 2.0, "the Crate is west of the Gap")
	assert_gt(_boulder.weight, _almos.tuning.greatest_weight(), "the Boulder")


func test_a_pull_fetches_the_crate_across_the_gap() -> void:
	_set_up_room()
	var gap = _room.get_node("Gap")
	var east_edge: float = gap.global_position.x + gap.size.x / 2.0
	_almos.global_position = Vector2(east_edge + (_pull.target_range - 20.0) / 2.0 + 20.0, _crate.global_position.y)
	_almos.global_position.x = minf(_almos.global_position.x, _crate.global_position.x + _pull.target_range - 1.0)
	_almos.facing = Vector2.LEFT
	assert_lte(_almos.global_position.distance_to(_crate.global_position), _pull.target_range, "in range")

	await _cast()
	await _wait_for_the_slide(_pull)

	assert_almost_eq(_crate.global_position.distance_to(_almos.global_position), _pull.distance, DISTANCE_TOLERANCE, "stops at the Pull distance")
	assert_gt(_crate.global_position.x, east_edge, "east of the Gap")
	assert_false(_crate.dead, "whole")


func test_a_shove_slides_the_crate_by_the_shove_distance() -> void:
	_set_up_room()
	_place_crate_in_front_of_almos(OPEN_FLOOR, NEAR)
	var start: Vector2 = _crate.global_position
	await _select(AlmosSpell.Spell.SHOVE)

	await _cast()
	await _wait_for_the_slide(_shove)

	assert_almost_eq(_crate.global_position.x, start.x + _shove.distance, DISTANCE_TOLERANCE)
	assert_almost_eq(_almos.health.current, _almos.health.maximum - _shove.health_cost, TOLERANCE, "Health")


func test_a_crate_shoved_into_a_wall_stops_against_it_whole() -> void:
	_set_up_room()
	var wall := _room.get_node("Walls/WallRight") as StaticBody2D
	var face := wall.global_position.x - ((wall.get_node("CollisionShape2D") as CollisionShape2D).shape as RectangleShape2D).size.x / 2.0
	_place_crate_in_front_of_almos(Vector2(face - _shove.distance / 2.0 - NEAR, OPEN_FLOOR.y + 80.0), NEAR)
	await _select(AlmosSpell.Spell.SHOVE)

	await _cast()
	await _wait_for_the_slide(_shove)

	assert_almost_eq(_crate.global_position.x, face - (load(CRATE_PATH) as MovableTuning).size / 2.0, DISTANCE_TOLERANCE, "against the wall")
	assert_false(_crate.dead, "whole")
	assert_false(_crate.sliding, "sliding")


func test_a_crate_shoved_into_the_gap_from_its_east_side_falls_and_is_gone() -> void:
	_set_up_room()
	var gap = _room.get_node("Gap")
	var east_edge: float = gap.global_position.x + gap.size.x / 2.0
	assert_lt(_shove.distance / 2.0, gap.size.x, "ends inside the Gap")
	var crate_at := Vector2(east_edge + _shove.distance / 2.0, gap.global_position.y)
	_crate.global_position = crate_at
	_almos.global_position = crate_at + Vector2(NEAR, 0.0)
	_almos.facing = Vector2.LEFT
	_crate.fell.connect(func() -> void: _fell += 1)
	await _select(AlmosSpell.Spell.SHOVE)

	await _cast()
	await _wait_for_the_slide(_shove)

	assert_eq(_fell, 1, "fell")
	assert_false(is_instance_valid(_crate), "freed")


func test_a_ledge_side_does_not_stop_a_lifted_crate() -> void:
	_set_up_room()
	var ledge = _room.get_node("Ledge")
	var east_face: float = ledge.global_position.x + ledge.size.x / 2.0
	var crate_at := Vector2(east_face + _shove.distance / 2.0, ledge.global_position.y)
	_crate.global_position = crate_at
	_almos.global_position = crate_at + Vector2(NEAR, 0.0)
	_almos.facing = Vector2.LEFT
	await _select(AlmosSpell.Spell.SHOVE)

	await _cast()
	await _wait_for_the_slide(_shove)

	assert_almost_eq(_crate.global_position.x, crate_at.x - _shove.distance, DISTANCE_TOLERANCE)
	assert_false(_crate.dead, "whole")


# --- the Boulder ---


func test_a_boulder_shudders_stays_put_and_the_cost_is_paid() -> void:
	_set_up_room()
	_boulder.shuddered.connect(func() -> void: _shuddered += 1)
	get_tree().physics_frame.connect(_watch_the_look)
	_almos.global_position = _boulder.global_position + Vector2(-NEAR - 20.0, 0.0)
	_almos.facing = Vector2.RIGHT
	var start: Vector2 = _boulder.global_position
	await _select(AlmosSpell.Spell.SHOVE)

	await _cast()
	# Read at once: Stamina starts to refill soon after.
	assert_almost_eq(_almos.health.current, _almos.health.maximum - _shove.health_cost, TOLERANCE, "Health")
	assert_almost_eq(_almos.stamina.current, _almos.stamina.maximum - _shove.stamina_cost, 0.5, "Stamina")
	await _wait_for_the_slide(_shove)

	assert_eq(_shuddered, 1, "shuddered")
	assert_true(_jitter_seen, "its look jittered")
	assert_eq(_boulder.global_position, start, "position")


func test_a_boulder_does_not_move_for_pull_either() -> void:
	_set_up_room()
	_boulder.shuddered.connect(func() -> void: _shuddered += 1)
	_almos.global_position = _boulder.global_position + Vector2(-NEAR - 20.0, 0.0)
	_almos.facing = Vector2.RIGHT
	var start: Vector2 = _boulder.global_position

	await _cast()
	await _wait_for_the_slide(_pull)

	assert_eq(_shuddered, 1, "shuddered")
	assert_eq(_boulder.global_position, start, "position")


# --- the nearest of an enemy and a crate ---


func test_the_nearer_crate_is_moved_and_the_farther_enemy_is_not() -> void:
	_set_up_room()
	_place_crate_in_front_of_almos(OPEN_FLOOR, NEAR)
	_enemy.global_position = OPEN_FLOOR + _farther_in_the_cone()
	var enemy_start: Vector2 = _enemy.global_position
	var crate_start: Vector2 = _crate.global_position
	await _select(AlmosSpell.Spell.SHOVE)

	await _cast()
	await _wait_for_the_slide(_shove)

	assert_gt(_crate.global_position.x, crate_start.x + _shove.distance - DISTANCE_TOLERANCE, "the Crate moved")
	assert_eq(_enemy.global_position, enemy_start, "the enemy did not")


func test_the_nearer_enemy_is_moved_and_the_farther_crate_is_not() -> void:
	_set_up_room()
	_place_crate_in_front_of_almos(OPEN_FLOOR, NEAR)
	_crate.global_position = OPEN_FLOOR + _farther_in_the_cone()
	_enemy.global_position = OPEN_FLOOR + Vector2(NEAR, 0.0)
	var enemy_start: Vector2 = _enemy.global_position
	var crate_start: Vector2 = _crate.global_position
	await _select(AlmosSpell.Spell.SHOVE)

	await _cast()
	await _wait_for_the_slide(_shove)

	assert_almost_eq(_enemy.global_position.x, enemy_start.x + _shove.distance, DISTANCE_TOLERANCE, "the enemy moved")
	assert_eq(_crate.global_position, crate_start, "the Crate did not")


func test_a_crate_outside_the_cone_is_left_alone_and_nothing_is_spent() -> void:
	_set_up_room()
	_crate.global_position = OPEN_FLOOR + Vector2.RIGHT.rotated(deg_to_rad(_shove.cone_half_angle_degrees + 5.0)) * NEAR
	_almos.global_position = OPEN_FLOOR
	_almos.facing = Vector2.RIGHT
	_enemy.global_position = OPEN_FLOOR + Vector2(0.0, -_shove.target_range - 1.0)
	var start: Vector2 = _crate.global_position
	await _select(AlmosSpell.Spell.SHOVE)

	await _cast()
	await _wait_for_the_slide(_shove)

	assert_eq(_crate.global_position, start, "Crate")
	assert_almost_eq(_almos.health.current, _almos.health.maximum, TOLERANCE, "Health")


# --- set-up ---


func _alone(tuning_path: String):
	var movable = (load(MOVABLE_PATH) as PackedScene).instantiate()
	movable.tuning = load(tuning_path)
	movable.position = Vector2.ZERO
	add_child_autofree(movable)
	return movable


# The test room as shipped, without the Sound hunter, with the training enemy given no target.
func _set_up_room() -> void:
	var scene := load(TEST_ROOM_PATH) as PackedScene
	_room = scene.instantiate()
	var hunter := _room.get_node("SoundHunter")
	_room.remove_child(hunter)
	hunter.free()
	add_child_autofree(_room)
	_almos = _room.get_node("Almos") as Almos
	_crate = _room.get_node("Crate")
	_boulder = _room.get_node("Boulder")
	_enemy = _room.get_node("TrainingEnemy")
	_enemy.target = null
	_enemy.global_position = Vector2(OPEN_FLOOR.x, OPEN_FLOOR.y + _shove.target_range * 2.0)


# Where the farther of two things in the cone stands from him: inside its edge, so that the nearer one,
# straight ahead, slides past it.
func _farther_in_the_cone() -> Vector2:
	return Vector2.RIGHT.rotated(-deg_to_rad(_shove.cone_half_angle_degrees - 5.0)) * NEAR * 2.0


# Almos here facing right, the Crate this far in front of him.
func _place_crate_in_front_of_almos(almos_at: Vector2, distance: float) -> void:
	_almos.global_position = almos_at
	_almos.facing = Vector2.RIGHT
	_crate.global_position = almos_at + Vector2(distance, 0.0)


func _layer_bit(layer_name: String) -> int:
	for layer in range(1, 33):
		if ProjectSettings.get_setting("layer_names/2d_physics/layer_%d" % layer, "") == layer_name:
			return 1 << (layer - 1)
	fail_test("the project should name a 2D physics layer %s" % layer_name)
	return 0


# --- driving ---


func _tap(action: StringName) -> void:
	_almos_input.press_action(action)
	await wait_physics_frames(TAP_FRAMES)
	_almos_input.release_action(action)


func _select(spell: AlmosSpell.Spell) -> void:
	if _almos.spell.selected != spell:
		await _tap(&"switch_spell")
		await wait_physics_frames(1)
	assert_eq(_almos.spell.selected, spell, "the Spell should be selected")


func _cast() -> void:
	await _tap(&"cast_spell")
	await wait_physics_frames(1)


func _wait_for_the_slide(cost: SpellCost) -> void:
	var frames := ceili(cost.target_range / cost.move_speed * Engine.physics_ticks_per_second)
	await wait_physics_frames(frames + MARGIN_FRAMES)


func _watch_the_look() -> void:
	if is_instance_valid(_boulder) and absf((_boulder.get_node("Placeholder") as Node2D).position.x) > 0.0:
		_jitter_seen = true
