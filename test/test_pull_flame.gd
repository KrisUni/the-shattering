extends GutTest
## Pulling the flame off a Fire, in the test room with the real Almos and the shipped numbers, driven
## through the switch_spell and cast_spell actions. The Curtain is set alight and Pull takes its flame
## when its nearest edge is within the Pull's flame_range, measured from the edge and not the centre.
## Every distance, cost and time is worked from Pull's cost file, Flame draw's data file and the room's
## own nodes, so nothing here pins a number in them.

const AlmosInput := preload("res://test/helpers/almos_input.gd")

const TEST_ROOM_PATH := "res://scenes/test_room.tscn"
const FLAME_DRAW_PATH := "res://data/flame_draw.tres"
const PULL_PATH := "res://data/pull.tres"
const SHOVE_PATH := "res://data/shove.tres"
const TOLERANCE := 0.0001
const DISTANCE_TOLERANCE := 0.5
const TAP_FRAMES := 2
const MARGIN_FRAMES := 8
# In pixels.
const EDGE_MARGIN := 1.0
const FAR := 100.0

var _almos_input: AlmosInput
var _spell: SpellData
var _pull: SpellCost
var _shove: SpellCost
var _room: Node
var _almos: Almos
var _curtain: Flammable
var _enemy
var _thrown := 0


func before_each() -> void:
	await get_tree().process_frame
	_almos_input = AlmosInput.new(self)
	_thrown = 0
	_spell = load(FLAME_DRAW_PATH) as SpellData
	_pull = load(PULL_PATH) as SpellCost
	_shove = load(SHOVE_PATH) as SpellCost


func after_each() -> void:
	_almos_input.release_everything()


func test_pull_within_flame_range_of_the_edge_takes_the_flame_and_leaves_the_curtain_unburnt() -> void:
	_set_up_room()
	_stand_below_the_curtain(_pull.flame_range - EDGE_MARGIN)
	assert_gt(_almos.global_position.distance_to(_curtain.global_position), _pull.flame_range, "past range measured from its centre")

	await _pull_the_flame()

	assert_false(_curtain.burning, "burning")
	assert_false(_curtain.burnt_out, "burnt out")
	assert_true(_curtain.look.visible, "its look")
	assert_true(_curtain.get_parent().is_in_group(&"hiding_spots"), "a Hiding spot again")
	assert_true(_almos.spell.holding, "holding")
	assert_eq(_almos.spell.selected, AlmosSpell.Spell.SHOVE, "Shove selected")
	assert_almost_eq(_almos.health.current, _almos.health.maximum - _pull.health_cost, TOLERANCE, "Health")


func test_pull_pays_the_pull_stamina_cost_when_the_wind_up_ends() -> void:
	_set_up_room()
	_stand_below_the_curtain(_pull.flame_range - EDGE_MARGIN)
	_almos_input.press_action(&"cast_spell")
	await wait_physics_frames(TAP_FRAMES)
	_almos_input.release_action(&"cast_spell")
	for i in 600:
		if _almos.spell.holding:
			break
		await wait_physics_frames(1)

	assert_lte(_almos.stamina.current, _almos.stamina.maximum - _pull.stamina_cost + TOLERANCE)


func test_the_curtain_is_not_taken_until_the_wind_up_is_over() -> void:
	_set_up_room()
	_stand_below_the_curtain(_pull.flame_range - EDGE_MARGIN)
	_almos_input.press_action(&"cast_spell")
	for i in 600:
		if _almos.spell.winding_up:
			break
		await wait_physics_frames(1)

	assert_true(_curtain.burning, "still burning")
	assert_false(_almos.spell.holding, "not yet holding")
	assert_almost_eq(_almos.health.current, _almos.health.maximum, TOLERANCE, "nothing spent")


func test_pull_just_outside_flame_range_takes_nothing() -> void:
	_set_up_room()
	_stand_below_the_curtain(_pull.flame_range + EDGE_MARGIN)

	await _pull_the_flame()

	assert_true(_curtain.burning, "burning")
	assert_false(_almos.spell.holding, "holding")
	assert_almost_eq(_almos.health.current, _almos.health.maximum, TOLERANCE, "Health")
	assert_almost_eq(_almos.stamina.current, _almos.stamina.maximum, TOLERANCE, "Stamina")


func test_pull_just_outside_flame_range_acts_on_an_enemy_in_the_cone_as_before() -> void:
	_set_up_room()
	_stand_below_the_curtain(_pull.flame_range + EDGE_MARGIN)
	_almos.facing = Vector2.LEFT
	_enemy.global_position = _almos.global_position + Vector2(-FAR, 0.0)

	await _pull_the_flame()

	assert_almost_eq(_enemy.global_position.distance_to(_almos.global_position), _pull.distance, DISTANCE_TOLERANCE)
	assert_true(_curtain.burning, "burning")


func test_a_flame_taken_from_a_fire_goes_out_after_the_hold_time_and_the_selection_returns() -> void:
	_set_up_room()
	_stand_below_the_curtain(_pull.flame_range - EDGE_MARGIN)
	await _pull_the_flame()
	var health := _almos.health.current

	await wait_physics_frames(_frames(_pull.fire_flame_hold_time / 2.0))
	assert_true(_almos.spell.holding, "still holding half way")
	await wait_physics_frames(_frames(_pull.fire_flame_hold_time / 2.0) + MARGIN_FRAMES)

	assert_false(_almos.spell.holding, "holding")
	assert_eq(_almos.spell.selected, AlmosSpell.Spell.PULL, "selection back")
	assert_eq(_thrown, 0, "nothing thrown")
	assert_almost_eq(_almos.health.current, health, TOLERANCE, "the cost stays spent, and nothing is refunded")
	assert_false(_curtain.burning, "the Curtain is not relit")


func test_the_held_flame_does_not_hurt_almos() -> void:
	_set_up_room()
	_stand_below_the_curtain(_pull.flame_range - EDGE_MARGIN)
	await _pull_the_flame()
	var health := _almos.health.current

	await wait_physics_frames(_frames(_pull.fire_flame_hold_time / 2.0))

	assert_true(_almos.spell.holding, "holding")
	assert_almost_eq(_almos.health.current, health, TOLERANCE)


func test_losing_health_puts_the_held_flame_out() -> void:
	_set_up_room()
	_stand_below_the_curtain(_pull.flame_range - EDGE_MARGIN)
	await _pull_the_flame()

	_almos.health.take_damage(1.0)
	await wait_physics_frames(2)

	assert_false(_almos.spell.holding, "holding")
	assert_eq(_almos.spell.selected, AlmosSpell.Spell.PULL, "selection back")


func test_the_curtain_can_be_lit_again_after_its_flame_was_taken() -> void:
	_set_up_room()
	_stand_below_the_curtain(_pull.flame_range - EDGE_MARGIN)
	await _pull_the_flame()

	assert_true(_curtain.ignite(), "catches again")
	assert_true(_curtain.burning, "burning")


func test_a_second_tap_throws_a_flame_taken_from_a_fire_at_the_shove_cost() -> void:
	_set_up_room()
	_stand_below_the_curtain(_pull.flame_range - EDGE_MARGIN)
	_almos.spell.fireball_thrown.connect(func(_fireball: Fireball, _torch: Torch) -> void: _thrown += 1)
	await _pull_the_flame()
	var health := _almos.health.current

	await _tap(&"cast_spell")
	await wait_physics_frames(1)

	assert_eq(_thrown, 1, "thrown")
	assert_false(_almos.spell.holding, "holding")
	assert_almost_eq(_almos.health.current, health - _shove.health_cost, TOLERANCE, "Health")


func test_a_fire_that_goes_out_during_the_wind_up_fizzles_with_nothing_spent() -> void:
	_set_up_room()
	_stand_below_the_curtain(_pull.flame_range - EDGE_MARGIN)
	_almos_input.press_action(&"cast_spell")
	for i in 600:
		if _almos.spell.winding_up:
			break
		await wait_physics_frames(1)
	_curtain.extinguish()
	_almos_input.release_action(&"cast_spell")

	await wait_physics_frames(_spell.wind_up_frames + MARGIN_FRAMES)

	assert_false(_almos.spell.holding, "holding")
	assert_almost_eq(_almos.health.current, _almos.health.maximum, TOLERANCE, "Health")


func test_pull_with_too_little_stamina_leaves_the_fire_burning() -> void:
	_set_up_room()
	_stand_below_the_curtain(_pull.flame_range - EDGE_MARGIN)
	_almos.stamina.spend(_almos.stamina.current - _pull.stamina_cost + 1.0)

	await _pull_the_flame()

	assert_true(_curtain.burning, "burning")
	assert_false(_almos.spell.holding, "holding")


func test_a_lit_torch_in_range_is_drawn_before_a_fire() -> void:
	_set_up_room()
	var torch := _room.get_node("WallTorch") as Torch
	_almos.global_position = torch.global_position + Vector2(0.0, _spell.draw_range / 2.0)
	var barrel := (load("res://scenes/world/flammable.tscn") as PackedScene).instantiate() as Flammable
	barrel.position = _almos.global_position + Vector2(_pull.flame_range / 2.0, 0.0)
	_room.add_child(barrel)
	barrel.ignite()
	assert_lte(barrel.distance_to_edge(_almos.global_position), _pull.flame_range, "the fire is in range too")
	_almos.facing = Vector2.LEFT

	await _pull_the_flame()

	assert_false(torch.lit, "the torch is drawn")
	assert_true(barrel.burning, "the fire is left")
	assert_true(_almos.spell.holding, "holding")


func test_a_fire_is_taken_before_an_enemy_in_the_cone() -> void:
	_set_up_room()
	_stand_below_the_curtain(_pull.flame_range - EDGE_MARGIN)
	_almos.facing = Vector2.UP
	_enemy.global_position = _almos.global_position + Vector2(0.0, -FAR / 2.0)
	var start: Vector2 = _enemy.global_position

	await _pull_the_flame()

	assert_false(_curtain.burning, "taken")
	assert_eq(_enemy.global_position, start, "the enemy")


# --- set-up ---


# The test room as shipped, without the Sound hunter, the training enemy given no target and put
# well out of the way, and the Curtain alight.
func _set_up_room() -> void:
	var scene := load(TEST_ROOM_PATH) as PackedScene
	_room = scene.instantiate()
	var hunter := _room.get_node("SoundHunter")
	_room.remove_child(hunter)
	hunter.free()
	add_child_autofree(_room)
	_almos = _room.get_node("Almos") as Almos
	_curtain = _room.get_node("Curtain/Flammable") as Flammable
	_enemy = _room.get_node("TrainingEnemy")
	_enemy.target = null
	_enemy.global_position = Vector2(300.0, 560.0)
	_curtain.ignite()


# Almos below the Curtain, facing it, this far from its lower edge.
func _stand_below_the_curtain(from_edge: float) -> void:
	var bottom := _curtain.global_position.y + (((_curtain.get_node("CollisionShape2D") as CollisionShape2D).shape as RectangleShape2D).size.y / 2.0)
	_almos.global_position = Vector2(_curtain.global_position.x, bottom + from_edge)
	_almos.facing = Vector2.UP


# --- driving ---


func _frames(seconds: float) -> int:
	return ceili(seconds * Engine.physics_ticks_per_second)


func _tap(action: StringName) -> void:
	_almos_input.press_action(action)
	await wait_physics_frames(TAP_FRAMES)
	_almos_input.release_action(action)


# Taps the Spell button and waits the wind-up out.
func _pull_the_flame() -> void:
	await _tap(&"cast_spell")
	await wait_physics_frames(_spell.wind_up_frames + MARGIN_FRAMES)
