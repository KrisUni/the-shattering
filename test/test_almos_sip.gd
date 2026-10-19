extends GutTest
## Sipping from the Health Flask, seen only through the scenes: the real Almos, driven by the Sip
## action, with the shipped tuning, and the test room for the Checkpoint, the Fire and the
## training enemy. Every number is worked from the data files and plain arithmetic.

const AlmosInput := preload("res://test/helpers/almos_input.gd")

const TEST_ROOM_PATH := "res://scenes/test_room.tscn"
const FLASK_TUNING_PATH := "res://data/flasks.tres"
const FIRE_PATH := "res://data/fire.tres"
const TORCH_SCENE_PATH := "res://scenes/world/torch.tscn"
const SPEAR_PATH := "res://data/spear.tres"
const TOLERANCE := 0.0001
# In physics frames. A press held this long is a tap.
const TAP_FRAMES := 3
# In physics frames. Slack added to a computed wait.
const MARGIN_FRAMES := 6
# In physics frames. The most a wait for something to happen may take.
const FRAME_LIMIT := 600
# In Health points. How much of his Health the tests take off him, as a fraction of the maximum.
const HURT_FRACTION := 0.8
# In pixels. How far from Almos the enemy stands to be within reach of its strike.
const ENEMY_STRIKE_DISTANCE := 30.0
# In pixels per second. How exactly a measured speed has to match.
const SPEED_TOLERANCE := 0.01
# In pixels. How far from the Checkpoint's centre Almos is put to rest.
const BESIDE_THE_CHECKPOINT := 10.0

# What a button does on a free Almos, and which of his states shows it.
var action_params = ParameterFactory.named_parameters(
	["action", "state"],
	[
		[&"roll", "rolling"],
		[&"attack_light", "attacking"],
		[&"attack_heavy", "charging"],
		[&"jump", "airborne"],
		[&"block", "blocking"],
		[&"parry", "parrying"],
	],
)

var _almos_input: AlmosInput
var _flasks: FlaskTuning
var _player: PlayerTuning
var _room: Node
var _almos: Almos


func before_each() -> void:
	# Start between two physics frames, as real input arrives.
	await get_tree().process_frame
	_almos_input = AlmosInput.new(self)
	_flasks = load(FLASK_TUNING_PATH) as FlaskTuning
	_player = load(AlmosInput.TUNING_PATH) as PlayerTuning


func after_each() -> void:
	_almos_input.release_everything()


func test_a_sip_restores_the_tuned_share_of_health_at_its_end() -> void:
	_spawn_almos()
	var before := _hurt()

	await _tap(&"sip_health")
	await wait_physics_frames(_sip_frames() + MARGIN_FRAMES)

	assert_almost_eq(_almos.health.current, before + _player.health_maximum * _flasks.health_restore_share, TOLERANCE)


func test_a_sip_restores_nothing_before_its_end() -> void:
	_spawn_almos()
	var before := _hurt()

	await _tap(&"sip_health")
	await wait_physics_frames(_sip_frames() - TAP_FRAMES - MARGIN_FRAMES)

	assert_true(_almos.sipping, "the Sip should still be under way")
	assert_almost_eq(_almos.health.current, before, TOLERANCE)


func test_a_sip_spends_one_charge() -> void:
	_spawn_almos()
	_hurt()

	await _tap(&"sip_health")

	assert_eq(_almos.flasks.health_charges, _flasks.health_charges - 1)


func test_a_sip_at_a_full_bar_plays_and_spends_the_charge() -> void:
	_spawn_almos()

	await _tap(&"sip_health")

	assert_true(_almos.sipping, "the Sip should play")
	assert_eq(_almos.flasks.health_charges, _flasks.health_charges - 1)
	await wait_physics_frames(_sip_frames() + MARGIN_FRAMES)
	assert_almost_eq(_almos.health.current, _player.health_maximum, TOLERANCE)


func test_he_walks_slowly_during_a_sip() -> void:
	_spawn_almos()
	_almos_input.press_action(&"move_right")
	await wait_physics_frames(TAP_FRAMES)

	await _tap(&"sip_health")
	var velocity: Vector2 = await _measured_velocity()

	assert_true(_almos.sipping, "the Sip should still be under way")
	assert_almost_eq(velocity, Vector2(_flasks.sip_walk_speed, 0.0), Vector2.ONE * SPEED_TOLERANCE)


func test_he_walks_at_his_usual_speed_once_the_sip_is_over() -> void:
	_spawn_almos()
	_almos_input.press_action(&"move_right")
	await _tap(&"sip_health")
	await wait_physics_frames(_sip_frames() + MARGIN_FRAMES)

	var velocity: Vector2 = await _measured_velocity()

	assert_almost_eq(velocity, Vector2(_player.walk_speed, 0.0), Vector2.ONE * SPEED_TOLERANCE)


func test_a_sprint_held_through_a_sip_is_only_a_slow_walk() -> void:
	_spawn_almos()
	_almos_input.press_action(&"move_right")
	await _tap(&"sip_health")
	_almos_input.press_action(&"roll")
	await wait_seconds(_player.roll_hold_threshold)

	var velocity: Vector2 = await _measured_velocity()

	assert_true(_almos.sipping, "the Sip should still be under way")
	assert_false(_almos.sprinting, "he should not sprint")
	assert_almost_eq(velocity, Vector2(_flasks.sip_walk_speed, 0.0), Vector2.ONE * SPEED_TOLERANCE)


func test_a_button_pressed_during_a_sip_does_nothing(params = use_parameters(action_params)) -> void:
	_spawn_almos()
	await _tap(&"sip_health")

	_almos_input.press_action(params.action)
	await wait_physics_frames(TAP_FRAMES)
	assert_false(_almos.get(params.state), "he should not be %s while it is held" % params.state)
	_almos_input.release_action(params.action)
	await wait_physics_frames(TAP_FRAMES)

	assert_true(_almos.sipping, "the Sip should still be under way")
	assert_false(_almos.get(params.state), "he should not be %s once it is let go of" % params.state)


func test_a_switch_pressed_during_a_sip_is_lost() -> void:
	_spawn_almos()
	_almos.weapons.pick_up(load(SPEAR_PATH) as WeaponData)
	var in_hand: WeaponData = _almos.weapons.in_hand
	await _tap(&"sip_health")

	await _tap(&"switch_weapon")
	await wait_physics_frames(_sip_frames() + MARGIN_FRAMES)

	assert_eq(_almos.weapons.in_hand, in_hand)


func test_a_spell_pressed_during_a_sip_is_not_cast() -> void:
	_spawn_almos()
	var torch := (load(TORCH_SCENE_PATH) as PackedScene).instantiate() as Torch
	torch.position = _almos.position
	add_child_autofree(torch)
	await _tap(&"sip_health")

	await _tap(&"cast_spell")

	assert_false(_almos.spell.winding_up, "no wind-up")
	assert_true(torch.lit, "the torch should still be lit")


func test_a_tap_of_interact_during_a_sip_does_not_rest() -> void:
	_set_up_room()
	_stand_beside_the_checkpoint()
	var before := _hurt()
	await _tap(&"sip_health")
	watch_signals(_almos)

	await _tap_interact()

	assert_signal_not_emitted(_almos, "rested")
	assert_almost_eq(_almos.health.current, before, TOLERANCE)


func test_a_press_with_no_charge_left_does_nothing() -> void:
	_spawn_almos()
	for i in _flasks.health_charges:
		await _tap(&"sip_health")
		await wait_physics_frames(_sip_frames() + MARGIN_FRAMES)
	_almos_input.press_action(&"move_right")

	await _tap(&"sip_health")
	var velocity: Vector2 = await _measured_velocity()

	assert_eq(_almos.flasks.health_charges, 0)
	assert_false(_almos.sipping, "there should be no Sip")
	assert_almost_eq(velocity, Vector2(_player.walk_speed, 0.0), Vector2.ONE * SPEED_TOLERANCE)


func test_a_press_while_not_free_to_act_is_lost() -> void:
	_spawn_almos()
	_almos_input.press_action(&"attack_light")
	await wait_physics_frames(TAP_FRAMES)
	_almos_input.release_action(&"attack_light")
	assert_true(_almos.attacking, "he should be in a swing")

	await _tap(&"sip_health")

	assert_false(_almos.sipping, "no Sip in a swing")
	assert_eq(_almos.flasks.health_charges, _flasks.health_charges)


func test_a_hit_during_a_sip_wastes_the_charge_and_restores_nothing() -> void:
	_set_up_room()
	var enemy := _room.get_node("TrainingEnemy")
	_almos.global_position = Vector2(576.0, 474.0)
	var before := _hurt()
	enemy.global_position = _almos.global_position + Vector2.DOWN * ENEMY_STRIKE_DISTANCE
	enemy.post_facing = Vector2.UP
	enemy.target = _almos
	for i in FRAME_LIMIT:
		if enemy.winding_up:
			break
		await get_tree().physics_frame
	assert_true(enemy.winding_up, "the enemy should begin a swing")
	var swing: AttackData = enemy.current_attack

	await _tap(&"sip_health")
	await wait_physics_frames(_sip_frames() + MARGIN_FRAMES)

	assert_almost_eq(_almos.health.current, before - swing.damage, TOLERANCE, "hurt and not restored")
	assert_false(_almos.sipping, "the Sip should be over")
	assert_eq(_almos.flasks.health_charges, _flasks.health_charges - 1, "the charge is gone")


func test_a_hit_during_a_sip_keeps_its_outcome() -> void:
	_spawn_almos()
	var hurtbox := _almos.get_node("Hurtbox") as Hurtbox
	await _tap(&"sip_health")

	var outcome := hurtbox.hurt(5.0, _almos.global_position + Vector2.RIGHT * 50.0, 0.0)

	assert_eq(outcome, Hurtbox.Outcome.LANDED)
	assert_false(_almos.sipping, "the Sip is wasted")


func test_a_tick_of_fire_during_a_sip_wastes_it() -> void:
	_set_up_room()
	var fire := load(FIRE_PATH) as FireTuning
	var curtain := _room.get_node("Curtain/Flammable") as Flammable
	_almos.global_position = _room.get_node("Curtain").global_position
	var before := _hurt()
	await wait_physics_frames(MARGIN_FRAMES)

	curtain.ignite()
	await _tap(&"sip_health")
	for i in FRAME_LIMIT:
		if curtain.ticks >= 1:
			break
		await get_tree().physics_frame
	assert_gte(curtain.ticks, 1, "the Fire should tick")
	assert_false(_almos.sipping, "the tick should have wasted the Sip")
	await wait_physics_frames(_sip_frames() + MARGIN_FRAMES)

	assert_almost_eq(_almos.health.current, before - curtain.ticks * fire.damage_per_tick, TOLERANCE)


func test_resting_at_a_checkpoint_refills_the_charges() -> void:
	_set_up_room()
	_stand_beside_the_checkpoint()
	await _tap(&"sip_health")
	await wait_physics_frames(_sip_frames() + MARGIN_FRAMES)
	assert_eq(_almos.flasks.health_charges, _flasks.health_charges - 1)

	await _tap_interact()

	assert_eq(_almos.flasks.health_charges, _flasks.health_charges)


func test_the_return_after_a_death_refills_the_charges_and_ends_the_sip() -> void:
	_set_up_room()
	await _tap(&"sip_health")
	assert_eq(_almos.flasks.health_charges, _flasks.health_charges - 1)

	_almos.health.take_damage(_almos.health.maximum)
	await wait_seconds(_player.death_pause + 0.5)

	assert_false(_almos.dead, "he should be back")
	assert_false(_almos.sipping, "the Sip should be over")
	assert_eq(_almos.flasks.health_charges, _flasks.health_charges)
	assert_almost_eq(_almos.health.current, _player.health_maximum, TOLERANCE)


func test_the_hud_label_follows_the_charges() -> void:
	_set_up_room()
	var label := _room.get_node("Hud/FlaskLabel") as Label
	var charges := _flasks.health_charges
	assert_eq(label.text, "Health Flask %d/%d" % [charges, charges], "at the start")
	_stand_beside_the_checkpoint()

	await _tap(&"sip_health")
	assert_eq(label.text, "Health Flask %d/%d" % [charges - 1, charges], "after a Sip")
	await wait_physics_frames(_sip_frames() + MARGIN_FRAMES)
	await _tap_interact()

	assert_eq(label.text, "Health Flask %d/%d" % [charges, charges], "after a rest")


func _spawn_almos() -> void:
	_almos = _almos_input.spawn_almos()


func _set_up_room() -> void:
	var scene := load(TEST_ROOM_PATH) as PackedScene
	assert_not_null(scene, "the test room scene should load")
	_room = scene.instantiate()
	add_child_autofree(_room)
	_almos = _room.get_node("Almos") as Almos
	_almos.facing = Vector2.RIGHT
	_room.get_node("TrainingEnemy").target = null
	_room.get_node("SoundHunter").target = null


func _stand_beside_the_checkpoint() -> void:
	var checkpoint := _room.find_child("Checkpoint", true, false) as Node2D
	_almos.global_position = checkpoint.global_position + Vector2.RIGHT * BESIDE_THE_CHECKPOINT


# Takes most of his Health off and returns how much he has left.
func _hurt() -> float:
	_almos.health.take_damage(_almos.health.maximum * HURT_FRACTION)
	return _almos.health.current


# How many physics frames a Sip lasts.
func _sip_frames() -> int:
	return int(round(_flasks.sip_duration * Engine.physics_ticks_per_second))


# Taps an action and lets the tap take effect.
func _tap(action: StringName) -> void:
	_almos_input.press_action(action)
	await wait_physics_frames(TAP_FRAMES)
	_almos_input.release_action(action)


# Taps Interact, which does its work as it is let go of, and lets that take effect.
func _tap_interact() -> void:
	await _tap(&"interact")
	await wait_physics_frames(TAP_FRAMES)


# His average velocity over a few physics frames, worked out from where he ends up.
func _measured_velocity() -> Vector2:
	var start := _almos.position
	var start_frame := Engine.get_physics_frames()
	await wait_physics_frames(AlmosInput.MEASURED_FRAMES)
	var seconds := float(Engine.get_physics_frames() - start_frame) / Engine.physics_ticks_per_second
	return (_almos.position - start) / seconds
