extends GutTest
## Almos's two Spells, Pull and Shove, in the test room with the real Almos and the shipped
## numbers, driven through the switch_spell and cast_spell actions: a tap of switch_spell cycles
## Pull and Shove when he is free to act and not winding up or holding; Pull on a lit torch takes
## its flame and selects Shove, locked; Shove throws it, and each costs Health and Stamina from the
## cost files; the selection returns after the throw or when the flame goes out; a throw he cannot
## pay for leaves the flame held. Every amount is read from the data files.

const AlmosInput := preload("res://test/helpers/almos_input.gd")

const TEST_ROOM_PATH := "res://scenes/test_room.tscn"
const FLAME_DRAW_PATH := "res://data/flame_draw.tres"
const PULL_PATH := "res://data/pull.tres"
const SHOVE_PATH := "res://data/shove.tres"
const TOLERANCE := 0.0001
# In physics frames.
const TAP_FRAMES := 2
const MARGIN_FRAMES := 6
# In pixels.
const EDGE_MARGIN := 1.0
const ALMOS_AT_DRAW_FRACTION := 0.5

# Each way to press the Switch Spell button other than as the action itself.
var switch_binding_params = ParameterFactory.named_parameters(
	["name", "press"],
	[
		["the V key", func(input: AlmosInput): input.press_key(KEY_V)],
		["the D-pad up of a pad", func(input: AlmosInput): input.press_joypad_button(JOY_BUTTON_DPAD_UP)],
	],
)

var _almos_input: AlmosInput
var _spell: SpellData
var _pull: SpellCost
var _shove: SpellCost
var _room: Node
var _almos: Almos
var _torch: Torch
var _enemy
var _thrown := 0
var _thrown_from: Torch
var _health_at_throw := -1.0
var _stamina_at_throw := -1.0
var _changes := 0


func before_each() -> void:
	await get_tree().process_frame
	_almos_input = AlmosInput.new(self)
	_thrown = 0
	_thrown_from = null
	_health_at_throw = -1.0
	_stamina_at_throw = -1.0
	_changes = 0
	_spell = load(FLAME_DRAW_PATH) as SpellData
	_pull = load(PULL_PATH) as SpellCost
	_shove = load(SHOVE_PATH) as SpellCost
	assert_not_null(_spell, "Flame draw's data file should load")
	assert_not_null(_pull, "Pull's cost file should load")
	assert_not_null(_shove, "Shove's cost file should load")


func after_each() -> void:
	_almos_input.release_everything()


# --- the costs' data ---


func test_each_spell_costs_health_and_stamina() -> void:
	for cost in [_pull, _shove]:
		assert_gt(cost.health_cost, 0.0, "Health cost")
		assert_gt(cost.stamina_cost, 0.0, "Stamina cost")


# --- switching ---


func test_he_starts_with_pull_selected() -> void:
	_set_up_room()

	assert_eq(_almos.spell.selected, AlmosSpell.Spell.PULL)


func test_a_tap_of_switch_spell_cycles_pull_and_shove() -> void:
	_set_up_room()

	await _tap(&"switch_spell")
	assert_eq(_almos.spell.selected, AlmosSpell.Spell.SHOVE, "first tap")
	await _tap(&"switch_spell")
	assert_eq(_almos.spell.selected, AlmosSpell.Spell.PULL, "second tap")


func test_the_switch_buttons_other_than_the_action_switch_too(params = use_parameters(switch_binding_params)) -> void:
	_set_up_room()

	params.press.call(_almos_input)
	await wait_physics_frames(TAP_FRAMES)
	_almos_input.release_everything()

	assert_eq(_almos.spell.selected, AlmosSpell.Spell.SHOVE, params.name)


func test_a_switch_says_so_once() -> void:
	_set_up_room()

	await _tap(&"switch_spell")

	assert_eq(_changes, 1)


func test_a_switch_tap_made_in_a_roll_is_lost() -> void:
	_set_up_room()
	_almos_input.press_action(&"move_down")
	await _tap(&"roll")
	assert_true(_almos.rolling, "control: rolling")

	_almos_input.press_action(&"switch_spell")
	await wait_physics_frames(1)
	_almos_input.release_action(&"switch_spell")
	await wait_physics_frames(MARGIN_FRAMES)

	assert_eq(_almos.spell.selected, AlmosSpell.Spell.PULL)


func test_a_switch_tap_made_in_the_wind_up_is_refused() -> void:
	_set_up_room()
	_almos_input.press_action(&"cast_spell")
	await _until(func() -> bool: return _almos.spell.winding_up)

	await _tap(&"switch_spell")

	assert_true(_almos.spell.winding_up, "control: still winding up")
	assert_eq(_almos.spell.selected, AlmosSpell.Spell.PULL)


# --- Pull ---


func test_pull_on_a_lit_torch_takes_its_flame_and_selects_shove() -> void:
	_set_up_room()

	await _draw()

	assert_true(_almos.spell.holding, "holding")
	assert_false(_torch.lit, "the torch is out")
	assert_eq(_almos.spell.selected, AlmosSpell.Spell.SHOVE)


func test_pull_costs_its_health_and_stamina_cost() -> void:
	_set_up_room()

	await _draw()

	assert_almost_eq(_almos.health.current, _almos.health.maximum - _pull.health_cost, TOLERANCE, "Health")
	assert_almost_eq(_almos.stamina.current, _almos.stamina.maximum - _pull.stamina_cost, TOLERANCE, "Stamina")


func test_the_selection_is_locked_while_he_holds_the_flame() -> void:
	_set_up_room()
	await _draw()

	await _tap(&"switch_spell")
	await wait_physics_frames(MARGIN_FRAMES)

	assert_true(_almos.spell.holding, "still holding")
	assert_eq(_almos.spell.selected, AlmosSpell.Spell.SHOVE)


func test_pull_with_no_lit_torch_in_range_does_nothing_and_spends_nothing() -> void:
	_set_up_room()
	_almos.global_position = _torch.global_position + Vector2(0.0, _spell.draw_range + EDGE_MARGIN)

	await _draw()

	assert_false(_almos.spell.holding, "holding")
	assert_eq(_almos.spell.selected, AlmosSpell.Spell.PULL, "selection")
	assert_true(_torch.lit, "the torch")
	assert_almost_eq(_almos.health.current, _almos.health.maximum, TOLERANCE, "Health")
	assert_almost_eq(_almos.stamina.current, _almos.stamina.maximum, TOLERANCE, "Stamina")


# --- Shove ---


func test_shove_with_no_flame_held_does_nothing_and_spends_nothing() -> void:
	_set_up_room()
	await _tap(&"switch_spell")

	await _draw()

	assert_false(_almos.spell.holding, "holding")
	assert_eq(_almos.spell.selected, AlmosSpell.Spell.SHOVE, "selection")
	assert_true(_torch.lit, "the torch is not drawn by Shove")
	assert_eq(_thrown, 0, "thrown")
	assert_almost_eq(_almos.health.current, _almos.health.maximum, TOLERANCE, "Health")
	assert_almost_eq(_almos.stamina.current, _almos.stamina.maximum, TOLERANCE, "Stamina")


func test_shove_throws_the_flame_and_costs_its_health_and_stamina_cost() -> void:
	_set_up_room()
	await _draw()
	var health := _almos.health.current
	var stamina := _almos.stamina.current

	await _throw()

	assert_eq(_thrown, 1, "thrown")
	assert_almost_eq(_health_at_throw, health - _shove.health_cost, TOLERANCE, "Health")
	assert_almost_eq(_stamina_at_throw, stamina - _shove.stamina_cost, TOLERANCE, "Stamina")


func test_the_throw_is_of_the_drawn_torchs_flame_though_it_paid_its_own_health() -> void:
	_set_up_room()
	await _draw()

	await _throw()

	assert_same(_thrown_from, _torch)


func test_the_selection_returns_to_pull_after_the_throw() -> void:
	_set_up_room()
	await _draw()

	await _throw()

	assert_false(_almos.spell.holding, "holding")
	assert_eq(_almos.spell.selected, AlmosSpell.Spell.PULL)


func test_the_selection_returns_when_a_loss_of_health_puts_the_flame_out() -> void:
	_set_up_room()
	await _draw()

	_almos.health.take_damage(1.0)

	assert_false(_almos.spell.holding, "holding")
	assert_eq(_almos.spell.selected, AlmosSpell.Spell.PULL)


func test_the_selection_returns_when_the_flame_is_reset() -> void:
	_set_up_room()
	await _draw()

	_almos.spell.reset()

	assert_eq(_almos.spell.selected, AlmosSpell.Spell.PULL)


func test_the_selection_changing_back_says_so() -> void:
	_set_up_room()
	await _draw()
	var before := _changes

	await _throw()

	assert_eq(_changes, before + 1)


func test_a_throw_with_too_little_stamina_does_nothing_and_the_flame_stays_held() -> void:
	_set_up_room()
	await _draw()
	_almos.stamina.spend(_almos.stamina.current - _shove.stamina_cost + EDGE_MARGIN)
	var health := _almos.health.current
	var stamina := _almos.stamina.current

	await _throw()

	assert_eq(_thrown, 0, "thrown")
	assert_true(_almos.spell.holding, "still holding")
	assert_eq(_almos.spell.selected, AlmosSpell.Spell.SHOVE, "selection")
	assert_almost_eq(_almos.health.current, health, TOLERANCE, "Health")
	assert_gte(_almos.stamina.current, stamina, "Stamina")


func test_a_throw_with_health_that_would_not_stay_above_the_cost_does_nothing() -> void:
	_set_up_room()
	_almos.health.take_damage(_almos.health.maximum - _pull.health_cost - _shove.health_cost)
	await _draw()
	var stamina := _almos.stamina.current

	await _throw()

	assert_eq(_thrown, 0, "thrown")
	assert_true(_almos.spell.holding, "still holding")
	assert_gte(_almos.stamina.current, stamina, "Stamina")


func test_he_can_throw_with_exactly_the_stamina_the_cost_asks() -> void:
	_set_up_room()
	await _draw()
	_almos.stamina.spend(_almos.stamina.current - _shove.stamina_cost)

	await _throw()

	assert_eq(_thrown, 1, "thrown")


# --- helpers ---


func _set_up_room() -> void:
	var scene := load(TEST_ROOM_PATH) as PackedScene
	assert_not_null(scene, "the test room scene should load")
	_room = scene.instantiate()
	var hunter := _room.get_node("SoundHunter")
	_room.remove_child(hunter)
	hunter.free()
	add_child_autofree(_room)
	_almos = _room.get_node("Almos") as Almos
	_almos.spell.fireball_thrown.connect(_on_fireball_thrown)
	_almos.spell.selection_changed.connect(func() -> void: _changes += 1)
	_torch = _room.get_node("WallTorch") as Torch
	_enemy = _room.get_node("TrainingEnemy")
	_almos.global_position = _torch.global_position + Vector2(0.0, _spell.draw_range * ALMOS_AT_DRAW_FRACTION)
	_almos.facing = Vector2.RIGHT
	_enemy.global_position = _almos.global_position + Vector2(_spell.fireball_range * 0.5, 0.0)
	_enemy.post_facing = Vector2.RIGHT


func _on_fireball_thrown(_fireball: Fireball, from_torch: Torch) -> void:
	_thrown += 1
	_thrown_from = from_torch
	_health_at_throw = _almos.health.current
	_stamina_at_throw = _almos.stamina.current


# Taps the Spell button and waits for the wind-up to end.
func _draw() -> void:
	await _tap(&"cast_spell")
	await wait_physics_frames(_spell.wind_up_frames + MARGIN_FRAMES)


# Taps the Spell button and waits for the fireball to fly its whole range, and a little more.
func _throw() -> void:
	await _tap(&"cast_spell")
	var flight_frames := ceili(_spell.fireball_range / (_spell.fireball_speed / 60.0))
	await wait_physics_frames(flight_frames + MARGIN_FRAMES)


func _tap(action: StringName) -> void:
	_almos_input.press_action(action)
	await wait_physics_frames(TAP_FRAMES)
	_almos_input.release_action(action)
	await wait_physics_frames(1)


func _until(condition: Callable) -> void:
	var waited := 0
	while not condition.call() and waited < 600:
		await get_tree().physics_frame
		waited += 1
