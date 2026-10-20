extends GutTest
## Flame draw in the test room with the real Almos, the real training enemy and the shipped
## numbers, driven through the cast_spell action: a press with a lit torch in range throws a fireball
## that damages the first enemy it hits and puts the torch out, spending Health and Stamina; a
## press that cannot cast spends nothing. Every distance and wait is worked from Flame draw's data
## file and Almos's tuning, so nothing here pins a number in them. The one exception is the damage
## formula, which is worked by hand from numbers this test gives (see
## test_fireball_damage_is_the_base_plus_each_point_of_channelling).

const AlmosInput := preload("res://test/helpers/almos_input.gd")

const TEST_ROOM_PATH := "res://scenes/test_room.tscn"
const TORCH_PATH := "res://scenes/world/torch.tscn"
const FLAME_DRAW_PATH := "res://data/flame_draw.tres"
const PULL_PATH := "res://data/pull.tres"
const SHOVE_PATH := "res://data/shove.tres"
const TOLERANCE := 0.0001
# In physics frames. How long a button is held for a tap, and how long to carry on after.
const TAP_FRAMES := 2
# In physics frames. Slack added to a computed wait, so that it is the thing happening that is
# looked for, not the last frame of it.
const MARGIN_FRAMES := 6
# In physics frames. The most a wait for something to happen may take.
const FRAME_LIMIT := 600
# In pixels. How far inside or outside an edge of a range a thing is put to try it.
const EDGE_MARGIN := 1.0
# In pixels. How far the post of the enemy is to the right of Almos, as a fraction of the
# fireball's range: well within it.
const ENEMY_AT_RANGE_FRACTION := 0.5
# In pixels. How far below the wall torch Almos stands, as a fraction of the draw range.
const ALMOS_AT_DRAW_FRACTION := 0.5
# In pixels. How far from the wall torch the test room's torch may be from the training enemy for
# it to count as near it.
const NEAR_THE_ENEMY := 250.0
# In Health points. A damage the formula test gives, worked by hand: 7 + 3 * 4 = 19.
const BASE_DAMAGE := 7.0
const DAMAGE_PER_CHANNELLING := 3.0
const CHANNELLING := 4
const WORKED_DAMAGE := 19.0

# Each way to press the Spell button other than as the action itself.
var spell_binding_params = ParameterFactory.named_parameters(
	["name", "press"],
	[
		["the C key", func(input: AlmosInput): input.press_key(KEY_C)],
		["the left stick of a pad pressed in", func(input: AlmosInput): input.press_joypad_button(JOY_BUTTON_LEFT_STICK)],
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
# Health and Stamina at the moment the fireball leaves, or -1 before.
var _health_at_throw := -1.0
var _stamina_at_throw := -1.0
# Whether he was winding up at the start of each physics frame sampled.
var _winding_samples := []
# How many times a fireball has said it hit an enemy.
var _fireball_hits := 0


func before_each() -> void:
	await get_tree().process_frame
	_almos_input = AlmosInput.new(self)
	_health_at_throw = -1.0
	_stamina_at_throw = -1.0
	_winding_samples = []
	_fireball_hits = 0
	_spell = load(FLAME_DRAW_PATH) as SpellData
	assert_not_null(_spell, "Flame draw's data file should load")
	_pull = load(PULL_PATH) as SpellCost
	_shove = load(SHOVE_PATH) as SpellCost
	assert_not_null(_pull, "Pull's cost file should load")
	assert_not_null(_shove, "Shove's cost file should load")


func after_each() -> void:
	if get_tree().physics_frame.is_connected(_sample_winding_up):
		get_tree().physics_frame.disconnect(_sample_winding_up)
	_almos_input.release_everything()


func test_the_test_room_has_a_lit_wall_torch_near_the_enemy_and_outside_the_dark() -> void:
	_set_up_room()
	var dark_zone := _room.get_node("DarkZone") as LightZone

	assert_true(_torch.lit, "lit at the start")
	assert_lte(_torch.global_position.distance_to(_enemy.global_position), NEAR_THE_ENEMY, "near the training enemy")
	assert_false(dark_zone.covers(_torch.global_position), "outside the DarkZone")


func test_casting_near_a_lit_torch_damages_the_enemy_by_the_formula() -> void:
	_set_up_room()
	var tuning := _almos.tuning
	var before: float = _enemy.health.current

	await _cast_and_wait_for_the_fireball()

	assert_almost_eq(before - _enemy.health.current, _spell.base_damage + _spell.damage_per_channelling * tuning.channelling, TOLERANCE)


func test_fireball_damage_is_the_base_plus_each_point_of_channelling() -> void:
	var spell := _spell.duplicate() as SpellData
	spell.base_damage = BASE_DAMAGE
	spell.damage_per_channelling = DAMAGE_PER_CHANNELLING
	var tuning := load(AlmosInput.TUNING_PATH).duplicate() as PlayerTuning
	tuning.channelling = CHANNELLING
	_set_up_room(tuning, spell)
	var before: float = _enemy.health.current

	await _cast_and_wait_for_the_fireball()

	assert_almost_eq(before - _enemy.health.current, WORKED_DAMAGE, TOLERANCE)


func test_casting_puts_the_torch_out() -> void:
	_set_up_room()

	await _cast_and_wait_for_the_fireball()

	assert_false(_torch.lit)


func test_casting_spends_the_pull_and_shove_health_costs() -> void:
	_set_up_room()

	await _cast_and_wait_for_the_fireball()

	assert_almost_eq(_health_at_throw, _almos.health.maximum - _pull.health_cost - _shove.health_cost, TOLERANCE)


func test_casting_spends_the_pull_and_shove_stamina_costs() -> void:
	_set_up_room()

	await _cast_and_wait_for_the_fireball()

	# Stamina refills between the draw and the throw, so the exact amounts are worked in test_spell_switching; here
	# the draw and the throw together cannot have left more than the throw alone leaves.
	assert_lte(_stamina_at_throw, _almos.stamina.maximum - _shove.stamina_cost + TOLERANCE)


func test_nothing_is_spent_and_no_fireball_flies_until_the_wind_up_is_over() -> void:
	_set_up_room()

	_almos_input.press_action(&"cast_spell")
	await _wait_until(func() -> bool: return _almos.spell.winding_up)

	assert_almost_eq(_almos.health.current, _almos.health.maximum, TOLERANCE, "Health")
	assert_almost_eq(_almos.stamina.current, _almos.stamina.maximum, TOLERANCE, "Stamina")
	assert_true(_torch.lit, "the torch")
	assert_eq(get_tree().get_nodes_in_group("fireballs").size(), 0, "fireballs")


func test_the_wind_up_commits_him_for_wind_up_frames_counting_the_press() -> void:
	_set_up_room()
	get_tree().physics_frame.connect(_sample_winding_up)

	await _cast_and_wait_for_the_fireball()
	get_tree().physics_frame.disconnect(_sample_winding_up)

	# Sampled at the start of each frame, the press frame shows him not yet winding up, and the
	# frame the fireball leaves in shows him still winding up.
	assert_eq(_winding_samples.count(true), _spell.wind_up_frames - 1, "frames sampled winding up")


func test_he_stands_still_while_winding_up() -> void:
	_set_up_room()
	_almos_input.press_action(&"move_down")
	_almos_input.press_action(&"cast_spell")
	await _wait_until(func() -> bool: return _almos.spell.winding_up)
	var start := _almos.global_position

	await _wait_until(func() -> bool: return not _almos.spell.winding_up)

	assert_almost_eq(_almos.global_position.y, start.y, 1.0)


func test_a_roll_tapped_while_winding_up_is_lost() -> void:
	_set_up_room()
	_almos_input.press_action(&"cast_spell")
	await _wait_until(func() -> bool: return _almos.spell.winding_up)

	_almos_input.press_action(&"roll")
	await wait_physics_frames(1)

	assert_false(_almos.rolling)


func test_a_press_with_no_torch_in_range_does_nothing_and_spends_nothing() -> void:
	_set_up_room()
	_place_almos_from_the_torch(_spell.draw_range + EDGE_MARGIN)

	await _cast_and_wait_for_the_fireball()

	_assert_nothing_was_cast()


func test_a_torch_just_inside_the_draw_range_is_drawn() -> void:
	_set_up_room()
	_place_almos_from_the_torch(_spell.draw_range - EDGE_MARGIN)

	await _cast_and_wait_for_the_fireball()

	assert_false(_torch.lit)


func test_a_press_when_last_on_health_does_nothing_and_spends_nothing() -> void:
	_set_up_room()
	_almos.health.take_damage(_almos.health.maximum - _pull.health_cost)

	await _cast_and_wait_for_the_fireball()

	assert_true(_torch.lit, "the torch")
	assert_almost_eq(_almos.health.current, _pull.health_cost, TOLERANCE, "Health")
	assert_almost_eq(_almos.stamina.current, _almos.stamina.maximum, TOLERANCE, "Stamina")
	assert_eq(get_tree().get_nodes_in_group("fireballs").size(), 0, "fireballs")


func test_he_can_cast_with_a_sliver_of_health_to_spare() -> void:
	_set_up_room()
	_almos.health.take_damage(_almos.health.maximum - _pull.health_cost - _shove.health_cost - EDGE_MARGIN)

	await _cast_and_wait_for_the_fireball()

	assert_almost_eq(_health_at_throw, EDGE_MARGIN, TOLERANCE)


func test_a_press_with_too_little_stamina_does_nothing_and_spends_nothing() -> void:
	_set_up_room()
	_almos.stamina.spend(_almos.stamina.maximum - _pull.stamina_cost + EDGE_MARGIN)
	var stamina_before: float = _almos.stamina.current

	await _cast_and_wait_for_the_fireball()

	assert_true(_torch.lit, "the torch")
	assert_almost_eq(_almos.health.current, _almos.health.maximum, TOLERANCE, "Health")
	assert_gte(_almos.stamina.current, stamina_before, "Stamina")


func test_he_can_cast_with_exactly_the_stamina_the_costs_ask() -> void:
	_set_up_room()
	_almos.stamina.spend(_almos.stamina.maximum - _pull.stamina_cost - _shove.stamina_cost)

	await _cast_and_wait_for_the_fireball()

	assert_false(_torch.lit)


func test_a_press_made_in_a_swing_is_lost() -> void:
	_set_up_room()
	var health_before: float = _almos.health.current
	_almos_input.press_action(&"attack_light")
	await wait_physics_frames(1)
	_almos_input.release_action(&"attack_light")
	assert_true(_almos.attacking, "control: he is in the swing")

	_almos_input.press_action(&"cast_spell")
	await wait_physics_frames(1)
	_almos_input.release_action(&"cast_spell")

	assert_false(_almos.spell.winding_up, "no wind-up begun")
	assert_true(_torch.lit, "the torch")
	assert_almost_eq(_almos.health.current, health_before, TOLERANCE, "Health")


func test_a_press_made_in_the_air_is_lost() -> void:
	_set_up_room()
	_almos_input.press_action(&"jump")
	await wait_physics_frames(1)
	_almos_input.release_action(&"jump")
	assert_true(_almos.airborne, "he is in the air")

	_almos_input.press_action(&"cast_spell")
	await wait_physics_frames(1)
	_almos_input.release_action(&"cast_spell")
	await wait_physics_frames(1)

	assert_false(_almos.spell.winding_up, "no wind-up begun")
	assert_true(_torch.lit, "the torch")


func test_the_nearest_of_two_lit_torches_is_drawn_when_it_comes_last() -> void:
	_set_up_room()
	var nearer := _add_torch(_almos.global_position + Vector2(_spell.draw_range * 0.2, 0.0))

	await _cast_and_wait_for_the_fireball()

	assert_false(nearer.lit, "the nearer torch")
	assert_true(_torch.lit, "the farther torch")


func test_the_nearest_of_two_lit_torches_is_drawn_when_it_comes_first() -> void:
	_set_up_room()
	_place_almos_from_the_torch(_spell.draw_range * 0.2)
	var farther := _add_torch(_almos.global_position + Vector2(_spell.draw_range * 0.6, 0.0))

	await _cast_and_wait_for_the_fireball()

	assert_false(_torch.lit, "the nearer torch")
	assert_true(farther.lit, "the farther torch")


func test_a_torch_that_is_out_is_not_drawn_even_if_it_is_the_nearest() -> void:
	_set_up_room()
	var out := _add_torch(_almos.global_position + Vector2(_spell.draw_range * 0.2, 0.0))
	out.draw()

	await _cast_and_wait_for_the_fireball()

	assert_false(_torch.lit, "the farther, lit torch is drawn")


func test_a_fireball_stops_at_a_wall_and_the_enemy_behind_it_is_unhurt() -> void:
	_set_up_room()
	var before: float = _enemy.health.current
	_add_wall_between_almos_and_the_enemy()

	await _cast_and_wait_for_the_fireball()

	assert_almost_eq(_enemy.health.current, before, TOLERANCE, "the enemy")
	assert_false(_torch.lit, "the torch is still put out")
	assert_eq(get_tree().get_nodes_in_group("fireballs").size(), 0, "the fireball is gone")


func test_a_fireball_dies_out_after_its_range() -> void:
	_set_up_room()
	var before: float = _enemy.health.current
	_enemy.global_position = _almos.global_position + Vector2(_spell.fireball_range + EDGE_MARGIN * 20.0, 0.0)

	await _cast_and_wait_for_the_fireball()

	assert_almost_eq(_enemy.health.current, before, TOLERANCE, "the enemy")
	assert_eq(get_tree().get_nodes_in_group("fireballs").size(), 0, "the fireball is gone")


func test_a_fireball_flies_at_the_lock_on_target_not_the_nearest_facing() -> void:
	_set_up_room()
	# The bed is flammable, so a fireball stops at it: it is moved off the line to the enemy.
	(_room.get_node("Bed") as Node2D).global_position = Vector2.ZERO
	# Off the eight facings, so only an exact aim at the target reaches it.
	_enemy.global_position = _almos.global_position + Vector2(_spell.fireball_range * 0.45, _spell.fireball_range * 0.16)
	_almos_input.press_action(&"lock_on")
	await wait_physics_frames(TAP_FRAMES)
	_almos_input.release_action(&"lock_on")
	assert_true(_almos.locked_on, "he locked on")
	var before: float = _enemy.health.current

	await _cast_and_wait_for_the_fireball()

	assert_lt(_enemy.health.current, before)


func test_a_fireball_says_it_hit_an_enemy_it_hurt() -> void:
	_set_up_room()

	await _cast_and_wait_for_the_fireball()

	assert_eq(_fireball_hits, 1)


func test_a_fireball_that_misses_an_untouchable_enemy_does_not_say_it_hit() -> void:
	_set_up_room()
	(_enemy.get_node("Hurtbox") as Hurtbox).is_untouchable = func() -> bool: return true

	await _cast_and_wait_for_the_fireball()

	assert_eq(_fireball_hits, 0)


func test_a_fireball_hit_makes_the_enemy_notice_him() -> void:
	_set_up_room()
	assert_false(_enemy.in_pursuit, "it has not noticed him yet")

	await _cast_and_wait_for_the_fireball()

	assert_true(_enemy.in_pursuit)


func test_a_fireball_hit_from_the_front_builds_no_stagger() -> void:
	_set_up_room()
	_enemy.post_facing = Vector2.LEFT

	await _cast_and_wait_for_the_fireball()

	assert_almost_eq(_enemy.stagger.current, 0.0, TOLERANCE)


func test_a_fireball_hit_from_behind_builds_no_stagger() -> void:
	_set_up_room()
	# Its back is to Almos, so the hit lands from behind.
	_enemy.post_facing = Vector2.RIGHT
	assert_gt(_enemy.tuning.behind_stagger, 0.0, "a hit from behind would build Stagger")

	await _cast_and_wait_for_the_fireball()

	assert_almost_eq(_enemy.stagger.current, 0.0, TOLERANCE)


func test_a_fireball_hit_from_the_side_builds_no_stagger() -> void:
	_set_up_room()
	_enemy.post_facing = Vector2.UP

	await _cast_and_wait_for_the_fireball()

	assert_almost_eq(_enemy.stagger.current, 0.0, TOLERANCE)


func test_the_spell_button_is_pressed_by_the_c_key_and_the_left_stick_of_a_pad(params = use_parameters(spell_binding_params)) -> void:
	_set_up_room()
	params.press.call(_almos_input)

	await wait_physics_frames(_spell.wind_up_frames + MARGIN_FRAMES)

	assert_false(_torch.lit, params.name)


# --- set-up ---


# The test room as shipped, without the Sound hunter, with Almos standing below the wall torch
# in reach of it, facing the training enemy, which is put in front of him well within a fireball's
# range with its back to him. The test frees it. Almos is given this tuning and this Spell if there
# are any.
func _set_up_room(tuning: PlayerTuning = null, spell: SpellData = null) -> void:
	var scene := load(TEST_ROOM_PATH) as PackedScene
	assert_not_null(scene, "the test room scene should load")
	_room = scene.instantiate()
	var hunter := _room.get_node("SoundHunter")
	_room.remove_child(hunter)
	hunter.free()
	if tuning != null:
		_room.get_node("Almos").tuning = tuning
	add_child_autofree(_room)
	_almos = _room.get_node("Almos") as Almos
	if spell != null:
		_almos.spell.spell_data = spell
	_almos.spell.fireball_thrown.connect(_on_fireball_thrown)
	_torch = _room.get_node("WallTorch") as Torch
	_enemy = _room.get_node("TrainingEnemy")
	_place_almos_from_the_torch(_spell.draw_range * ALMOS_AT_DRAW_FRACTION)
	_enemy.global_position = _almos.global_position + Vector2(_spell.fireball_range * ENEMY_AT_RANGE_FRACTION, 0.0)
	_enemy.post_facing = Vector2.RIGHT


# Almos this far below the wall torch, facing right.
func _place_almos_from_the_torch(distance: float) -> void:
	_almos.global_position = _torch.global_position + Vector2(0.0, distance)
	_almos.facing = Vector2.RIGHT
	if _enemy != null:
		_enemy.global_position = _almos.global_position + Vector2(_spell.fireball_range * ENEMY_AT_RANGE_FRACTION, 0.0)


func _add_torch(at: Vector2) -> Torch:
	var torch := (load(TORCH_PATH) as PackedScene).instantiate() as Torch
	torch.position = at
	_room.add_child(torch)
	return torch


# A wall across the fireball's way, half way to the enemy.
func _add_wall_between_almos_and_the_enemy() -> void:
	var wall := StaticBody2D.new()
	wall.collision_layer = 1
	var shape := CollisionShape2D.new()
	var rectangle := RectangleShape2D.new()
	rectangle.size = Vector2(16.0, 200.0)
	shape.shape = rectangle
	wall.add_child(shape)
	wall.global_position = _almos.global_position + Vector2(_spell.fireball_range * ENEMY_AT_RANGE_FRACTION * 0.5, 0.0)
	_room.add_child(wall)


# --- driving ---


# Not a lambda: the room, and Almos with it, can be freed within the emission that disconnects this.
func _sample_winding_up() -> void:
	if is_instance_valid(_almos):
		_winding_samples.append(_almos.spell.winding_up)


func _on_fireball_thrown(fireball: Fireball, _from_torch: Torch) -> void:
	fireball.hit.connect(func(_hurtbox: Hurtbox) -> void: _fireball_hits += 1)
	_health_at_throw = _almos.health.current
	_stamina_at_throw = _almos.stamina.current


# Taps the Spell button to draw, waits for the wind-up, taps again to throw, then waits for a
# fireball to fly its whole range, and a little more.
func _cast_and_wait_for_the_fireball() -> void:
	await _draw_the_flame()
	_almos_input.press_action(&"cast_spell")
	await wait_physics_frames(TAP_FRAMES)
	_almos_input.release_action(&"cast_spell")
	var flight_frames := ceili(_spell.fireball_range / (_spell.fireball_speed / 60.0))
	await wait_physics_frames(flight_frames + MARGIN_FRAMES)


# Taps the Spell button and waits for the wind-up to end.
func _draw_the_flame() -> void:
	_almos_input.press_action(&"cast_spell")
	await wait_physics_frames(TAP_FRAMES)
	_almos_input.release_action(&"cast_spell")
	await wait_physics_frames(_spell.wind_up_frames + MARGIN_FRAMES)


func _wait_until(condition: Callable) -> void:
	var waited := 0
	while not condition.call() and waited < FRAME_LIMIT:
		await get_tree().physics_frame
		waited += 1


func _assert_nothing_was_cast() -> void:
	assert_true(_torch.lit, "the torch")
	assert_almost_eq(_almos.health.current, _almos.health.maximum, TOLERANCE, "Health")
	assert_almost_eq(_almos.stamina.current, _almos.stamina.maximum, TOLERANCE, "Stamina")
	assert_eq(get_tree().get_nodes_in_group("fireballs").size(), 0, "fireballs")
