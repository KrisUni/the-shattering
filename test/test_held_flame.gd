extends GutTest
## The held flame of Flame draw, in the test room with the real Almos, the real training enemy and
## the shipped numbers, driven through the cast_spell action and the other actions: a tap draws the
## flame and Almos holds it, with nothing thrown however long he waits; a second tap throws it at
## once for nothing; while he holds it he can move, Sprint, Roll and Jump but not attack, Block,
## Parry, Interact or Switch; it lights the way; any loss of Health, a Fire tick included, puts it
## out with the cost still spent; and a Death, a fall and a return put it out; he cannot rest or hide while he holds it. Every wait
## and distance is worked from the data files.

const AlmosInput := preload("res://test/helpers/almos_input.gd")

const TEST_ROOM_PATH := "res://scenes/test_room.tscn"
const FLAME_DRAW_PATH := "res://data/flame_draw.tres"
const TORCH_PATH := "res://data/torch.tres"
const UNLIT_TORCH_PATH := "res://data/torch_unlit.tres"
const SPEAR_PATH := "res://data/spear.tres"
const TORCH_LIGHT_PATH := "res://data/torch_light.tres"
const TOLERANCE := 0.0001
# In physics frames.
const TAP_FRAMES := 2
const MARGIN_FRAMES := 6
const FRAME_LIMIT := 600
# In physics frames. A wait that is long beside any wind-up or flight.
const LONG_WAIT_FRAMES := 300
# In pixels.
const EDGE_MARGIN := 1.0
const ENEMY_AT_RANGE_FRACTION := 0.5
const ALMOS_AT_DRAW_FRACTION := 0.5
const BESIDE_THE_CHECKPOINT := 10.0
# In pixels per second. Slack on a speed measured over frames.
const SPEED_SLACK := 1.0

var _almos_input: AlmosInput
var _spell: SpellData
var _room: Node
var _almos: Almos
var _torch: Torch
var _enemy
var _thrown := 0
var _health_at_throw := -1.0
var _stamina_at_throw := -1.0


func before_each() -> void:
	await get_tree().process_frame
	_almos_input = AlmosInput.new(self)
	_thrown = 0
	_health_at_throw = -1.0
	_stamina_at_throw = -1.0
	_spell = load(FLAME_DRAW_PATH) as SpellData
	assert_not_null(_spell, "Flame draw's data file should load")


func after_each() -> void:
	_almos_input.release_everything()


# --- the draw ---


func test_a_tap_draws_the_flame_he_holds_it_and_nothing_is_thrown_however_long_he_waits() -> void:
	_set_up_room()

	await _draw()
	await wait_physics_frames(LONG_WAIT_FRAMES)

	assert_true(_almos.spell.holding, "holding")
	assert_false(_torch.lit, "the torch is out")
	assert_almost_eq(_almos.health.current, _almos.health.maximum - _spell.health_cost, TOLERANCE, "Health spent")
	assert_almost_eq(_almos.stamina.current, _almos.stamina.maximum, TOLERANCE, "Stamina refilled by now")
	assert_eq(_thrown, 0, "thrown")
	assert_eq(get_tree().get_nodes_in_group("fireballs").size(), 0, "fireballs")


func test_the_draw_spends_the_stamina_cost_when_the_wind_up_ends() -> void:
	_set_up_room()
	_almos_input.press_action(&"cast_spell")
	await wait_physics_frames(TAP_FRAMES)
	_almos_input.release_action(&"cast_spell")
	await _until(func() -> bool: return _almos.spell.holding)

	# Stamina is refilling by now, so only the instant after the draw shows the whole cost.
	assert_lte(_almos.stamina.current, _almos.stamina.maximum - _spell.stamina_cost + TOLERANCE)


func test_he_is_not_holding_during_the_wind_up() -> void:
	_set_up_room()
	_almos_input.press_action(&"cast_spell")
	await _until(func() -> bool: return _almos.spell.winding_up)

	assert_false(_almos.spell.holding)
	assert_true(_torch.lit, "the torch still burns")


func test_a_tap_that_cannot_draw_spends_nothing_and_holds_nothing() -> void:
	_set_up_room()
	_almos.global_position = _torch.global_position + Vector2(0.0, _spell.draw_range + EDGE_MARGIN)

	await _draw()

	assert_false(_almos.spell.holding, "holding")
	assert_true(_torch.lit, "the torch")
	assert_almost_eq(_almos.health.current, _almos.health.maximum, TOLERANCE, "Health")
	assert_almost_eq(_almos.stamina.current, _almos.stamina.maximum, TOLERANCE, "Stamina")


# --- the throw ---


func test_a_second_tap_throws_the_fireball_at_the_enemy_in_his_aim() -> void:
	_set_up_room()
	var before: float = _enemy.health.current
	await _draw()

	await _throw()

	assert_eq(_thrown, 1, "thrown")
	assert_almost_eq(before - _enemy.health.current, _spell.damage_for(_almos.tuning.channelling), TOLERANCE)
	assert_false(_almos.spell.holding, "no longer holding")


func test_the_throw_costs_nothing() -> void:
	_set_up_room()
	await _draw()
	var health := _almos.health.current
	var stamina := _almos.stamina.current

	await _throw()

	assert_almost_eq(_health_at_throw, health, TOLERANCE, "Health")
	assert_gte(_stamina_at_throw, stamina, "Stamina")
	assert_almost_eq(_almos.health.current, health, TOLERANCE, "Health after")


func test_a_tap_after_the_throw_with_no_lit_torch_in_range_draws_and_throws_nothing() -> void:
	_set_up_room()
	await _draw()
	await _throw()

	await _draw()

	assert_eq(_thrown, 1, "no second fireball from a tap with no torch lit in range")
	assert_false(_almos.spell.holding)


func test_the_throw_flies_at_the_lock_on_target() -> void:
	_set_up_room()
	(_room.get_node("Bed") as Node2D).global_position = Vector2.ZERO
	_enemy.global_position = _almos.global_position + Vector2(_spell.fireball_range * 0.45, _spell.fireball_range * 0.16)
	_almos_input.press_action(&"lock_on")
	await wait_physics_frames(TAP_FRAMES)
	_almos_input.release_action(&"lock_on")
	assert_true(_almos.locked_on, "he locked on")
	var before: float = _enemy.health.current
	await _draw()

	await _throw()

	assert_lt(_enemy.health.current, before)


func test_a_throw_tap_made_in_a_roll_is_lost() -> void:
	_set_up_room()
	await _draw()
	_almos_input.press_action(&"move_down")
	await _tap(&"roll")
	assert_true(_almos.rolling, "control: rolling")

	_almos_input.press_action(&"cast_spell")
	await wait_physics_frames(1)
	_almos_input.release_action(&"cast_spell")

	assert_true(_almos.spell.holding, "still holding")
	assert_eq(_thrown, 0, "thrown")


func test_a_throw_tap_made_in_the_air_is_lost() -> void:
	_set_up_room()
	await _draw()
	await _tap(&"jump")
	assert_true(_almos.airborne, "control: in the air")

	_almos_input.press_action(&"cast_spell")
	await wait_physics_frames(1)
	_almos_input.release_action(&"cast_spell")

	assert_true(_almos.spell.holding, "still holding")
	assert_eq(_thrown, 0, "thrown")


# --- what he can and cannot do while holding ---


func test_he_walks_while_holding() -> void:
	_set_up_room()
	await _draw()
	var start := _almos.global_position

	_almos_input.press_action(&"move_down")
	await wait_physics_frames(MARGIN_FRAMES)

	assert_gt(_almos.global_position.y, start.y)
	assert_true(_almos.spell.holding, "still holding")


func test_he_sprints_while_holding_faster_than_he_walks() -> void:
	_set_up_room()
	await _draw()
	_almos_input.press_action(&"move_down")
	await wait_physics_frames(MARGIN_FRAMES)
	var walked := _speed_over(MARGIN_FRAMES)
	var walk_distance: float = await walked.call()

	_almos_input.press_action(&"roll")
	await wait_physics_frames(MARGIN_FRAMES * 4)
	var sprint_distance: float = await _speed_over(MARGIN_FRAMES).call()

	assert_true(_almos.sprinting, "sprinting")
	assert_gt(sprint_distance, walk_distance)
	assert_true(_almos.spell.holding, "still holding")


func test_he_rolls_while_holding() -> void:
	_set_up_room()
	await _draw()

	_almos_input.press_action(&"move_down")
	await _tap(&"roll")

	assert_true(_almos.rolling, "rolling")
	assert_true(_almos.spell.holding, "still holding")


func test_he_jumps_while_holding() -> void:
	_set_up_room()
	await _draw()

	_almos_input.press_action(&"jump")
	await wait_physics_frames(TAP_FRAMES)
	_almos_input.release_action(&"jump")

	assert_true(_almos.airborne, "in the air")
	assert_true(_almos.spell.holding, "still holding")


func test_he_cannot_attack_while_holding() -> void:
	_set_up_room()
	await _draw()

	await _tap(&"attack_light")
	await _tap(&"attack_heavy")

	assert_false(_almos.attacking, "attacking")
	assert_true(_almos.spell.holding, "still holding")


func test_a_heavy_attack_pressed_in_the_air_while_holding_is_not_a_jump_attack() -> void:
	_set_up_room()
	await _draw()
	await _tap(&"jump")
	assert_true(_almos.airborne, "control: in the air")

	_almos_input.press_action(&"attack_heavy")
	await wait_physics_frames(TAP_FRAMES)
	_almos_input.release_action(&"attack_heavy")

	assert_false(_almos.jump_attacking, "jump attacking")


func test_he_cannot_block_while_holding() -> void:
	_set_up_room()
	await _draw()

	_almos_input.press_action(&"block")
	await wait_physics_frames(MARGIN_FRAMES)

	assert_false(_almos.blocking)


func test_he_cannot_parry_while_holding() -> void:
	_set_up_room()
	await _draw()

	await _tap(&"parry")

	assert_false(_almos.parrying)


func test_he_cannot_switch_while_holding() -> void:
	_set_up_room()
	_almos.weapons.pick_up(load(SPEAR_PATH))
	var in_hand := _almos.weapons.in_hand
	await _draw()

	await _tap(&"switch_weapon")
	await wait_physics_frames(MARGIN_FRAMES)

	assert_same(_almos.weapons.in_hand, in_hand)


func test_he_cannot_interact_while_holding_so_he_cannot_rest_hide_or_pick_up() -> void:
	_set_up_room()
	var rests := [0]
	_almos.rested.connect(func(_checkpoint: Checkpoint) -> void: rests[0] += 1)
	await _draw()
	_almos.global_position = _room.get_node("Checkpoint").global_position + Vector2.RIGHT * BESIDE_THE_CHECKPOINT

	await _tap(&"interact")

	assert_eq(rests[0], 0, "rested")
	assert_true(_almos.spell.holding, "still holding")


func test_he_cannot_hide_while_holding() -> void:
	_set_up_room()
	await _draw()
	_almos.global_position = _room.get_node("Barrel").global_position

	await _tap(&"interact")

	assert_false(_almos.hiding, "hiding")
	assert_true(_almos.spell.holding, "still holding")


func test_a_switch_pressed_in_the_wind_up_is_lost_once_he_holds_the_flame() -> void:
	_set_up_room()
	_almos.weapons.pick_up(load(SPEAR_PATH))
	var in_hand := _almos.weapons.in_hand
	_almos_input.press_action(&"cast_spell")
	await wait_physics_frames(TAP_FRAMES)
	_almos_input.release_action(&"cast_spell")
	assert_true(_almos.spell.winding_up, "control: winding up")

	await _tap(&"switch_weapon")
	await wait_physics_frames(_spell.wind_up_frames + MARGIN_FRAMES)

	assert_true(_almos.spell.holding, "holding")
	assert_same(_almos.weapons.in_hand, in_hand, "no switch")


func test_a_sip_pressed_while_holding_does_nothing_and_costs_nothing() -> void:
	_set_up_room()
	await _draw()
	var charges := _almos.flasks.health_charges

	await _tap(&"sip_health")
	await _tap(&"sip_mana")

	assert_false(_almos.flasks.sipping, "sipping")
	assert_eq(_almos.flasks.health_charges, charges, "charges")
	assert_true(_almos.spell.holding, "still holding")


# --- light ---


func test_the_held_flame_lights_the_way_at_almos_where_the_drawn_torch_gave_none() -> void:
	_set_up_room()
	var stand := _room.get_node("StandTorch") as Torch
	var zone := _room.get_node("DarkZone") as LightZone
	var torch_light := load(TORCH_LIGHT_PATH) as TorchTuning
	_torch = stand
	_almos.global_position = stand.global_position + Vector2(-_spell.draw_range * ALMOS_AT_DRAW_FRACTION, 0.0)
	assert_gt(torch_light.light, zone.light, "control: the torch is brighter than the dark")

	await _draw()

	assert_false(stand.lit, "the stand torch is out")
	assert_almost_eq(_light_at_almos(), torch_light.light, TOLERANCE, "while holding")

	await _throw()

	assert_almost_eq(_light_at_almos(), zone.light, TOLERANCE, "after the throw")


func test_the_held_flame_goes_with_him() -> void:
	_set_up_room()
	var stand := _room.get_node("StandTorch") as Torch
	var zone := _room.get_node("DarkZone") as LightZone
	var torch_light := load(TORCH_LIGHT_PATH) as TorchTuning
	_almos.global_position = stand.global_position + Vector2(-_spell.draw_range * ALMOS_AT_DRAW_FRACTION, 0.0)
	_torch = stand
	await _draw()

	_almos.global_position = zone.global_position
	await wait_physics_frames(1)

	assert_false(stand.lights(_almos.global_position), "the stand torch no longer reaches him")
	assert_almost_eq(_light_at_almos(), torch_light.light, TOLERANCE)


# --- the carried torch ---


func test_drawing_the_torch_in_hand_leaves_the_unlit_club_and_he_holds_the_flame_until_he_throws() -> void:
	_set_up_room()
	_almos.weapons.pick_up(load(TORCH_PATH))
	await _tap(&"switch_weapon")
	assert_same(_almos.weapons.in_hand, load(TORCH_PATH), "control: the torch is in hand")
	_almos.global_position = Vector2(-5000.0, -5000.0)
	for node in get_tree().get_nodes_in_group("torches"):
		if node != _almos.carried_torch:
			assert_gt(node.global_position.distance_to(_almos.global_position), _spell.draw_range, "clear of the torch")

	await _draw()

	assert_same(_almos.weapons.in_hand, load(UNLIT_TORCH_PATH), "the unlit club")
	assert_true(_almos.spell.holding, "holding")
	assert_eq(_thrown, 0, "thrown")

	await _throw()

	assert_eq(_thrown, 1, "thrown")


# --- put out ---


func test_a_hit_puts_the_flame_out_and_the_cost_stays_spent() -> void:
	_set_up_room()
	await _draw()
	var spent := _almos.health.current

	(_almos.get_node("Hurtbox") as Hurtbox).hurt(1.0, _almos.global_position + Vector2.LEFT * 20.0)

	assert_false(_almos.spell.holding, "holding")
	assert_almost_eq(_almos.health.current, spent - 1.0, TOLERANCE, "the cost stays spent")
	assert_false(_torch.lit, "the torch stays out")
	await _tap(&"cast_spell")
	assert_eq(_thrown, 0, "nothing to throw")


func test_a_fire_tick_puts_the_flame_out() -> void:
	_set_up_room()
	await _draw()
	var curtain := _room.get_node("Curtain/Flammable") as Flammable
	_almos.global_position = _room.get_node("Curtain").global_position
	await wait_physics_frames(MARGIN_FRAMES)
	assert_true(_almos.spell.holding, "control: still holding before the fire")

	curtain.ignite()
	await _until(func() -> bool: return curtain.ticks >= 1)
	await wait_physics_frames(1)

	assert_false(_almos.spell.holding, "holding")


func test_healing_does_not_put_the_flame_out() -> void:
	_set_up_room()
	await _draw()

	_almos.health.heal(1.0)

	assert_true(_almos.spell.holding)


func test_a_death_puts_the_flame_out_and_the_return_leaves_it_out() -> void:
	_set_up_room()
	await _draw()

	_almos.health.take_damage(_almos.health.maximum)
	assert_false(_almos.spell.holding, "after the fall")
	await wait_physics_frames(ceili(_almos.tuning.death_pause * Engine.physics_ticks_per_second) + MARGIN_FRAMES)

	assert_false(_almos.spell.holding, "after the return")


func test_return_to_puts_the_flame_out() -> void:
	_set_up_room()
	await _draw()

	_almos.return_to(_almos.global_position)

	assert_false(_almos.spell.holding)


func test_the_light_goes_when_the_flame_does() -> void:
	_set_up_room()
	var stand := _room.get_node("StandTorch") as Torch
	var zone := _room.get_node("DarkZone") as LightZone
	_torch = stand
	_almos.global_position = stand.global_position + Vector2(-_spell.draw_range * ALMOS_AT_DRAW_FRACTION, 0.0)
	await _draw()

	_almos.health.take_damage(1.0)

	assert_almost_eq(_light_at_almos(), zone.light, TOLERANCE)


# --- set-up ---


# The test room as shipped, without the Sound hunter, with Almos standing below the wall torch in
# reach of it, facing the training enemy, which is put in front of him well within a fireball's
# range with its back to him. The test frees it.
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
	_torch = _room.get_node("WallTorch") as Torch
	_enemy = _room.get_node("TrainingEnemy")
	_almos.global_position = _torch.global_position + Vector2(0.0, _spell.draw_range * ALMOS_AT_DRAW_FRACTION)
	_almos.facing = Vector2.RIGHT
	_enemy.global_position = _almos.global_position + Vector2(_spell.fireball_range * ENEMY_AT_RANGE_FRACTION, 0.0)
	_enemy.post_facing = Vector2.RIGHT


func _light_at_almos() -> float:
	return LightZone.light_at(
		get_tree().get_nodes_in_group("light_zones"), _almos.global_position,
		get_tree().get_nodes_in_group("torches"),
	)


func _on_fireball_thrown(_fireball: Fireball, _from_torch: Torch) -> void:
	_thrown += 1
	_health_at_throw = _almos.health.current
	_stamina_at_throw = _almos.stamina.current


# --- driving ---


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


# A callable that waits this many frames and gives how far Almos went in them.
func _speed_over(frames: int) -> Callable:
	return func() -> float:
		var start := _almos.global_position
		await wait_physics_frames(frames)
		return start.distance_to(_almos.global_position)


func _until(condition: Callable) -> void:
	var waited := 0
	while not condition.call() and waited < FRAME_LIMIT:
		await get_tree().physics_frame
		waited += 1
