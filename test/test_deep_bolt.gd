extends GutTest
## Deep bolt, in the test room with the real Almos, the real training enemy and the shipped numbers,
## driven through the switch_spell, cast_spell and lock_on actions: it is the third Spell of the
## cycle, its bolt flies the way he aims and damages the first enemy it hits for damage that scales
## with Channelling, with no Stagger, and it costs Health before his Mana bar and Mana after. Every
## amount is worked from data/deep_bolt.tres and the shipped tuning.

const AlmosInput := preload("res://test/helpers/almos_input.gd")

const TEST_ROOM_PATH := "res://scenes/test_room.tscn"
const DEEP_BOLT_PATH := "res://data/deep_bolt.tres"
const TOLERANCE := 0.0001
# In physics frames. How long a button is held for a tap.
const TAP_FRAMES := 2
# In pixels. Where Almos stands in open floor, and how far to the right the enemy stands.
const OPEN_FLOOR := Vector2(576.0, 324.0)
const NEAR := 120.0
# In pixels. Where the Curtain stands and how far each side of it Almos and the enemy are put.
const CURTAIN_ROW := Vector2(790.0, 280.0)
const BEYOND_CURTAIN := Vector2(1110.0, 280.0)
# A Channelling worked by hand: 15 + 3 * 11 = 48 is checked against the data file's numbers.
const RETUNED_CHANNELLING := 11
# In pixels. Wall thickness.
const WALL_THICKNESS := 16.0

var _almos_input: AlmosInput
var _bolt: DeepBoltData
var _room: Node
var _almos: Almos
var _enemy


func before_each() -> void:
	await get_tree().process_frame
	_almos_input = AlmosInput.new(self)
	_bolt = load(DEEP_BOLT_PATH) as DeepBoltData
	assert_not_null(_bolt, "Deep bolt's data file should load")


func after_each() -> void:
	_almos_input.release_everything()


func test_the_data_file_asks_for_health_mana_and_stamina() -> void:
	assert_gt(_bolt.health_cost, 0.0, "Health")
	assert_gt(_bolt.mana_cost, 0.0, "Mana")
	assert_gt(_bolt.stamina_cost, 0.0, "Stamina")


func test_damage_is_the_base_plus_each_point_of_channelling() -> void:
	var worked := DeepBoltData.new()
	worked.base_damage = 6.0
	worked.damage_per_channelling = 2.5

	assert_almost_eq(worked.damage_for(4), 16.0, TOLERANCE)


# --- the cycle ---


func test_the_cycle_goes_pull_shove_deep_bolt_and_round_again() -> void:
	_set_up_room()
	var seen: Array[AlmosSpell.Spell] = [_almos.spell.selected]

	for i in 3:
		await _tap(&"switch_spell")
		await wait_physics_frames(1)
		seen.append(_almos.spell.selected)

	assert_eq(seen, [AlmosSpell.Spell.PULL, AlmosSpell.Spell.SHOVE, AlmosSpell.Spell.DEEP_BOLT, AlmosSpell.Spell.PULL])


func test_the_label_names_deep_bolt() -> void:
	_set_up_room()

	await _select(AlmosSpell.Spell.DEEP_BOLT)

	assert_eq((_room.get_node("Hud/SpellLabel") as Label).text, "Deep bolt")


# --- the bolt ---


func test_the_bolt_damages_the_enemy_it_hits_for_its_damage() -> void:
	_set_up_room()
	await _select(AlmosSpell.Spell.DEEP_BOLT)
	var before: float = _enemy.health.current

	await _cast()
	await _wait_for_the_flight(NEAR)

	assert_almost_eq(before - _enemy.health.current, _bolt.damage_for(_almos.tuning.channelling), TOLERANCE)


func test_the_bolt_builds_no_stagger() -> void:
	_set_up_room()
	await _select(AlmosSpell.Spell.DEEP_BOLT)

	await _cast()
	await _wait_for_the_flight(NEAR)

	assert_almost_eq(_enemy.stagger.current, 0.0, TOLERANCE)


func test_more_channelling_hurts_more() -> void:
	var tuning := (load(AlmosInput.TUNING_PATH) as PlayerTuning).duplicate() as PlayerTuning
	tuning.channelling = RETUNED_CHANNELLING
	_set_up_room(tuning)
	await _select(AlmosSpell.Spell.DEEP_BOLT)
	var before: float = _enemy.health.current

	await _cast()
	await _wait_for_the_flight(NEAR)

	assert_almost_eq(before - _enemy.health.current, _bolt.base_damage + _bolt.damage_per_channelling * RETUNED_CHANNELLING, TOLERANCE)


func test_the_bolt_flies_along_his_facing() -> void:
	_set_up_room()
	_enemy.global_position = OPEN_FLOOR + Vector2.UP * NEAR
	_almos.facing = Vector2.UP
	await _select(AlmosSpell.Spell.DEEP_BOLT)
	var before: float = _enemy.health.current

	await _cast()
	await _wait_for_the_flight(NEAR)

	assert_lt(_enemy.health.current, before)


func test_the_bolt_flies_at_the_lock_on_target_and_not_along_his_facing() -> void:
	_set_up_room()
	_enemy.global_position = OPEN_FLOOR + Vector2(1.0, 1.0).normalized() * NEAR
	await _select(AlmosSpell.Spell.DEEP_BOLT)
	await _tap(&"lock_on")
	await wait_physics_frames(AlmosInput.SETTLE_FRAMES)
	assert_true(_almos.locked_on, "he should have locked on")
	var before: float = _enemy.health.current

	await _cast()
	await _wait_for_the_flight(NEAR)

	assert_lt(_enemy.health.current, before)


func test_the_bolt_does_not_turn_to_an_enemy_off_his_facing_without_lock_on() -> void:
	_set_up_room()
	_enemy.global_position = OPEN_FLOOR + Vector2(1.0, 1.0).normalized() * NEAR
	await _select(AlmosSpell.Spell.DEEP_BOLT)
	var before: float = _enemy.health.current

	await _cast()
	await _wait_for_the_flight(NEAR)

	assert_almost_eq(_enemy.health.current, before, TOLERANCE)


func test_a_wall_stops_the_bolt() -> void:
	_set_up_room()
	_add_wall(NEAR / 2.0)
	await _select(AlmosSpell.Spell.DEEP_BOLT)
	var before: float = _enemy.health.current

	await _cast()
	await _wait_for_the_flight(NEAR)

	assert_almost_eq(_enemy.health.current, before, TOLERANCE)


func test_the_bolt_passes_the_curtain_unlit_and_hurts_the_enemy_beyond() -> void:
	_set_up_room()
	_almos.global_position = CURTAIN_ROW
	_enemy.global_position = BEYOND_CURTAIN
	var curtain := _room.get_node("Curtain/Flammable") as Flammable
	await _select(AlmosSpell.Spell.DEEP_BOLT)
	var before: float = _enemy.health.current

	await _cast()
	await _wait_for_the_flight(BEYOND_CURTAIN.x - CURTAIN_ROW.x)

	assert_false(curtain.burning, "the curtain should not burn")
	assert_lt(_enemy.health.current, before, "the enemy beyond it should be hurt")


func test_the_bolt_does_not_reach_beyond_its_range() -> void:
	_set_up_room()
	_enemy.global_position = OPEN_FLOOR + Vector2(_bolt.bolt_range + 40.0, 0.0)
	await _select(AlmosSpell.Spell.DEEP_BOLT)
	var before: float = _enemy.health.current

	await _cast()
	await _wait_for_the_flight(_bolt.bolt_range + 40.0)

	assert_almost_eq(_enemy.health.current, before, TOLERANCE)


func test_it_does_not_hurt_almos() -> void:
	_set_up_room()
	await _select(AlmosSpell.Spell.DEEP_BOLT)

	await _cast()
	await _wait_for_the_flight(NEAR)

	assert_almost_eq(_almos.health.current, _almos.health.maximum - _bolt.health_cost, TOLERANCE)


# --- costs ---


func test_before_the_bar_it_costs_health_and_stamina() -> void:
	_set_up_room()
	await _select(AlmosSpell.Spell.DEEP_BOLT)

	await _cast()

	assert_almost_eq(_almos.health.current, _almos.health.maximum - _bolt.health_cost, TOLERANCE, "Health")
	assert_almost_eq(_almos.stamina.current, _almos.stamina.maximum - _bolt.stamina_cost, 0.5, "Stamina")


func test_after_the_bar_it_costs_mana_and_stamina_not_health() -> void:
	_set_up_room()
	_almos.grant_mana_bar()
	await _select(AlmosSpell.Spell.DEEP_BOLT)

	await _cast()

	assert_almost_eq(_almos.mana.current, _almos.mana.maximum - _bolt.mana_cost, TOLERANCE, "Mana")
	assert_almost_eq(_almos.stamina.current, _almos.stamina.maximum - _bolt.stamina_cost, 0.5, "Stamina")
	assert_almost_eq(_almos.health.current, _almos.health.maximum, TOLERANCE, "Health")


func test_nothing_is_spent_until_the_wind_up_ends() -> void:
	_set_up_room()
	await _select(AlmosSpell.Spell.DEEP_BOLT)

	await _tap(&"cast_spell")

	assert_almost_eq(_almos.health.current, _almos.health.maximum, TOLERANCE)


func test_with_too_little_health_before_the_bar_nothing_is_spent_and_no_bolt_flies() -> void:
	_set_up_room()
	_almos.health.take_damage(_almos.health.current - _bolt.health_cost)
	var health := _almos.health.current
	await _select(AlmosSpell.Spell.DEEP_BOLT)

	await _cast()
	await wait_physics_frames(_bolt.wind_up_frames)

	assert_almost_eq(_almos.health.current, health, TOLERANCE, "Health")
	assert_almost_eq(_almos.stamina.current, _almos.stamina.maximum, TOLERANCE, "Stamina")
	assert_eq(get_tree().get_nodes_in_group(&"deep_bolts").size(), 0, "no bolt")


func test_with_too_little_mana_after_the_bar_nothing_is_spent_and_no_bolt_flies() -> void:
	_set_up_room()
	_almos.grant_mana_bar()
	_almos.mana.spend(_almos.mana.current - _bolt.mana_cost + 1.0)
	var mana := _almos.mana.current
	await _select(AlmosSpell.Spell.DEEP_BOLT)

	await _cast()
	await wait_physics_frames(_bolt.wind_up_frames)

	assert_almost_eq(_almos.mana.current, mana, TOLERANCE, "Mana")
	assert_almost_eq(_almos.stamina.current, _almos.stamina.maximum, TOLERANCE, "Stamina")
	assert_almost_eq(_almos.health.current, _almos.health.maximum, TOLERANCE, "Health")
	assert_eq(get_tree().get_nodes_in_group(&"deep_bolts").size(), 0, "no bolt")


func test_a_press_he_cannot_pay_for_does_not_begin_a_wind_up() -> void:
	_set_up_room()
	_almos.stamina.spend(_almos.stamina.maximum)
	await _select(AlmosSpell.Spell.DEEP_BOLT)

	await _tap(&"cast_spell")

	assert_false(_almos.spell.winding_up)


func test_with_too_little_stamina_nothing_is_spent_and_no_bolt_flies() -> void:
	_set_up_room()
	_almos.stamina.spend(_almos.stamina.maximum - _bolt.stamina_cost + 1.0)
	var stamina := _almos.stamina.current
	await _select(AlmosSpell.Spell.DEEP_BOLT)

	await _cast()

	assert_almost_eq(_almos.health.current, _almos.health.maximum, TOLERANCE, "Health")
	assert_almost_eq(_almos.stamina.current, stamina, 0.5, "Stamina")
	assert_eq(get_tree().get_nodes_in_group(&"deep_bolts").size(), 0, "no bolt")


func test_a_wind_up_he_can_no_longer_pay_for_fizzles_and_spends_nothing() -> void:
	_set_up_room()
	await _select(AlmosSpell.Spell.DEEP_BOLT)
	var before: float = _enemy.health.current

	_almos_input.press_action(&"cast_spell")
	await wait_physics_frames(TAP_FRAMES)
	_almos_input.release_action(&"cast_spell")
	_almos.stamina.spend(_almos.stamina.maximum)
	await _wait_for_the_flight(NEAR)

	assert_almost_eq(_almos.health.current, _almos.health.maximum, TOLERANCE, "Health")
	assert_almost_eq(_enemy.health.current, before, TOLERANCE, "the enemy")


func _set_up_room(tuning: PlayerTuning = null) -> void:
	var scene := load(TEST_ROOM_PATH) as PackedScene
	_room = scene.instantiate()
	var hunter := _room.get_node("SoundHunter")
	_room.remove_child(hunter)
	hunter.free()
	if tuning != null:
		(_room.get_node("Almos") as Almos).tuning = tuning
	add_child_autofree(_room)
	_almos = _room.get_node("Almos") as Almos
	_enemy = _room.get_node("TrainingEnemy")
	_enemy.target = null
	_almos.global_position = OPEN_FLOOR
	_almos.facing = Vector2.RIGHT
	_enemy.global_position = OPEN_FLOOR + Vector2(NEAR, 0.0)
	_enemy.post_facing = Vector2.LEFT


# A wall across the line of fire, this far to the right of Almos, tall enough to catch the bolt.
func _add_wall(x_from_almos: float) -> void:
	var wall := StaticBody2D.new()
	wall.collision_layer = 1
	var shape := CollisionShape2D.new()
	var rectangle := RectangleShape2D.new()
	rectangle.size = Vector2(WALL_THICKNESS, 400.0)
	shape.shape = rectangle
	wall.add_child(shape)
	_room.add_child(wall)
	wall.global_position = _almos.global_position + Vector2(x_from_almos, 0.0)


func _tap(action: StringName) -> void:
	_almos_input.press_action(action)
	await wait_physics_frames(TAP_FRAMES)
	_almos_input.release_action(action)


func _select(spell: AlmosSpell.Spell) -> void:
	for i in 3:
		if _almos.spell.selected == spell:
			break
		await _tap(&"switch_spell")
		await wait_physics_frames(1)
	assert_eq(_almos.spell.selected, spell, "the Spell should be selected")


# Taps the Spell button and lets the wind-up run out.
func _cast() -> void:
	await _tap(&"cast_spell")
	await wait_physics_frames(_bolt.wind_up_frames)


# Waits as long as the bolt takes to fly this far, and then a margin.
func _wait_for_the_flight(distance: float) -> void:
	var frames := ceili(distance / _bolt.bolt_speed * Engine.physics_ticks_per_second)
	await wait_physics_frames(frames + 8)
