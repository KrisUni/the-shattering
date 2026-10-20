extends GutTest
## What a Spell costs before and after Almos has his Mana bar, in the test room with the real Almos
## and the real training enemy, driven through the switch_spell and cast_spell actions. Before the
## bar a Spell costs Health and Stamina; after, Mana and Stamina. Every expected number is worked
## from the Spells' cost files and the shipped tuning.

const AlmosInput := preload("res://test/helpers/almos_input.gd")

const TEST_ROOM_PATH := "res://scenes/test_room.tscn"
const PULL_PATH := "res://data/pull.tres"
const SHOVE_PATH := "res://data/shove.tres"
const TOLERANCE := 0.0001
# In physics frames. How long a button is held for a tap.
const TAP_FRAMES := 2
# In pixels. Where Almos stands in open floor of the room, and how far the enemy is from him.
const OPEN_FLOOR := Vector2(576.0, 324.0)
const NEAR := 60.0

var _almos_input: AlmosInput
var _pull: SpellCost
var _shove: SpellCost
var _room: Node
var _almos: Almos


func before_each() -> void:
	await get_tree().process_frame
	_almos_input = AlmosInput.new(self)
	_pull = load(PULL_PATH) as SpellCost
	_shove = load(SHOVE_PATH) as SpellCost


func after_each() -> void:
	_almos_input.release_everything()


func test_before_the_bar_shove_costs_health_not_mana() -> void:
	_set_up_room()
	await _select(AlmosSpell.Spell.SHOVE)

	await _cast()

	assert_almost_eq(_almos.health.current, _almos.health.maximum - _shove.health_cost, TOLERANCE, "Health")
	assert_almost_eq(_almos.mana.current, 0.0, TOLERANCE, "Mana")


func test_after_the_bar_shove_costs_mana_and_stamina_not_health() -> void:
	_set_up_room()
	_almos.grant_mana_bar()
	await _select(AlmosSpell.Spell.SHOVE)

	await _cast()

	assert_almost_eq(_almos.mana.current, _almos.mana.maximum - _shove.mana_cost, TOLERANCE, "Mana")
	assert_almost_eq(_almos.stamina.current, _almos.stamina.maximum - _shove.stamina_cost, 0.5, "Stamina")
	assert_almost_eq(_almos.health.current, _almos.health.maximum, TOLERANCE, "Health")


func test_after_the_bar_pull_costs_mana_and_stamina_not_health() -> void:
	_set_up_room()
	_almos.grant_mana_bar()

	await _cast()

	assert_almost_eq(_almos.mana.current, _almos.mana.maximum - _pull.mana_cost, TOLERANCE, "Mana")
	assert_almost_eq(_almos.stamina.current, _almos.stamina.maximum - _pull.stamina_cost, 0.5, "Stamina")
	assert_almost_eq(_almos.health.current, _almos.health.maximum, TOLERANCE, "Health")


func test_a_spell_with_exactly_the_mana_it_costs_is_paid() -> void:
	_set_up_room()
	_almos.grant_mana_bar()
	_almos.mana.spend(_almos.mana.current - _pull.mana_cost)

	await _cast()

	assert_almost_eq(_almos.mana.current, 0.0, TOLERANCE)


func test_a_spell_with_too_little_mana_does_nothing_and_spends_nothing() -> void:
	_set_up_room()
	_almos.grant_mana_bar()
	_almos.mana.spend(_almos.mana.current - _pull.mana_cost + 1.0)
	var mana := _almos.mana.current
	var start: Vector2 = _room.get_node("TrainingEnemy").global_position

	await _cast()
	await wait_physics_frames(30)

	assert_almost_eq(_almos.mana.current, mana, TOLERANCE, "Mana")
	assert_almost_eq(_almos.stamina.current, _almos.stamina.maximum, TOLERANCE, "Stamina")
	assert_almost_eq(_almos.health.current, _almos.health.maximum, TOLERANCE, "Health")
	assert_eq(_room.get_node("TrainingEnemy").global_position, start, "the enemy should not have moved")


func test_with_the_bar_plenty_of_health_does_not_pay_for_a_spell_without_mana() -> void:
	_set_up_room()
	_almos.grant_mana_bar()
	_almos.mana.spend(_almos.mana.maximum)

	await _cast()

	assert_almost_eq(_almos.health.current, _almos.health.maximum, TOLERANCE)


func test_a_spell_with_too_little_stamina_spends_no_mana() -> void:
	_set_up_room()
	_almos.grant_mana_bar()
	_almos.stamina.spend(_almos.stamina.maximum - _pull.stamina_cost + 1.0)
	var stamina := _almos.stamina.current

	await _cast()

	assert_almost_eq(_almos.mana.current, _almos.mana.maximum, TOLERANCE, "Mana")
	assert_almost_eq(_almos.stamina.current, stamina, 0.5, "Stamina")


func test_before_the_bar_too_little_health_does_nothing_and_spends_nothing() -> void:
	_set_up_room()
	_almos.health.take_damage(_almos.health.current - _pull.health_cost)
	var health := _almos.health.current

	await _cast()

	assert_almost_eq(_almos.health.current, health, TOLERANCE, "Health")
	assert_almost_eq(_almos.stamina.current, _almos.stamina.maximum, TOLERANCE, "Stamina")


func _set_up_room() -> void:
	var scene := load(TEST_ROOM_PATH) as PackedScene
	_room = scene.instantiate()
	add_child_autofree(_room)
	_almos = _room.get_node("Almos") as Almos
	_room.get_node("TrainingEnemy").target = null
	_room.get_node("SoundHunter").target = null
	_almos.global_position = OPEN_FLOOR
	_almos.facing = Vector2.RIGHT
	var enemy := _room.get_node("TrainingEnemy") as Node2D
	enemy.global_position = OPEN_FLOOR + Vector2(NEAR, 0.0)
	enemy.post_facing = Vector2.LEFT


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
