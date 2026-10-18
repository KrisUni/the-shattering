extends GutTest
## Almos carrying, switching and dropping Weapons, at the real Almos in the shipped test room,
## driven through Input actions: a tap of Interact picks up a Weapon in reach (or rests, if a
## Checkpoint is), a hold of it drops the Weapon in hand, and the Switch button cycles through
## those carried. Numbers come from the player tuning and the Weapons' data files, as shipped.
## The room's Weapons are the spear, greatsword, torch and metal bar lying on the floor, and
## Almos starts with the sword.

const AlmosInput := preload("res://test/helpers/almos_input.gd")
const AlmosHits := preload("res://test/helpers/almos_hits.gd")
const AttackRig := preload("res://test/helpers/attack_rig.gd")
const StrikeGeometry := preload("res://test/helpers/strike_geometry.gd")

const TEST_ROOM_PATH := "res://scenes/test_room.tscn"
const TUNING_PATH := "res://data/player_tuning.tres"
const SWORD_PATH := "res://data/sword.tres"
const SPEAR_PATH := "res://data/spear.tres"
const GREATSWORD_PATH := "res://data/greatsword.tres"
const TORCH_PATH := "res://data/torch.tres"

const PICKUPS_GROUP := &"weapon_pickups"

# In physics frames. A press held this long is a tap, far shorter than the hold that drops, and
# the same time is waited after it for it to take effect.
const TAP_FRAMES := 3
# In physics frames. How far short of the hold, or past it, a press is held to see which side of
# the threshold it falls on.
const HOLD_MARGIN := 4
# In physics frames. The most a test waits for an attack or a Death to be over.
const WAIT_FRAME_LIMIT := 400
# In pixels. How far from a pickup Almos is put to be clear of its reach, and the margin inside or
# outside the edge of his reach he is put to try it.
const AWAY := 150.0
const REACH_MARGIN := 1.0
# In pixels. How far from the Checkpoint's centre a pickup is moved, to lie beside it.
const BESIDE := 5.0
# In pixels. A place in the test room clear of the Gap, the Ledge, the pickups and the Checkpoint.
const OPEN_SPOT := Vector2(600.0, 420.0)
# In pixels.
const POSITION_TOLERANCE := 0.01
const TOLERANCE := 0.0001
# In physics frames. How long a hurtful hit is held on to break a guard.
const HURT_FRACTION := 0.6

var _almos_input: AlmosInput
var _rig: AttackRig


func before_each() -> void:
	# Start between two physics frames, as real input arrives, so what the test spawns is first
	# processed after the first sample and what it presses is seen from the next frame.
	await get_tree().process_frame
	_almos_input = AlmosInput.new(self)
	_rig = AttackRig.new(self)


func after_each() -> void:
	_rig.stop_sampling()
	_almos_input.release_everything()


# --- the Switch action ---

func test_the_switch_action_is_tab_on_the_keyboard_and_y_on_the_pad() -> void:
	assert_true(InputMap.has_action(&"switch_weapon"), "the switch_weapon action should exist")
	var keys: Array[int] = []
	var buttons: Array[int] = []
	for event in InputMap.action_get_events(&"switch_weapon"):
		if event is InputEventKey:
			keys.append((event as InputEventKey).physical_keycode)
		elif event is InputEventJoypadButton:
			buttons.append((event as InputEventJoypadButton).button_index)

	assert_eq(keys, [KEY_TAB], "keys by position")
	assert_eq(buttons, [JOY_BUTTON_Y], "pad buttons")


# --- picking up ---

func test_he_starts_with_the_sword_in_hand_and_carries_only_it() -> void:
	var almos := _almos(_spawn_room())

	assert_eq(_paths(almos.weapons.carried), [SWORD_PATH])
	assert_eq(almos.weapons.in_hand.resource_path, SWORD_PATH)


func test_picking_up_two_weapons_makes_three_carried_in_pickup_order() -> void:
	var room := _spawn_room()
	var almos := _almos(room)

	await _pick_up(room, almos, "SpearPickup")
	await _pick_up(room, almos, "GreatswordPickup")

	assert_eq(_paths(almos.weapons.carried), [SWORD_PATH, SPEAR_PATH, GREATSWORD_PATH])


func test_a_weapon_picked_up_does_not_replace_the_one_in_hand() -> void:
	var room := _spawn_room()
	var almos := _almos(room)

	await _pick_up(room, almos, "SpearPickup")

	assert_eq(almos.weapons.in_hand.resource_path, SWORD_PATH)


func test_a_pickup_taken_is_gone_from_the_room() -> void:
	var room := _spawn_room()
	var almos := _almos(room)
	var pickup := room.find_child("SpearPickup", true, false)

	await _pick_up(room, almos, "SpearPickup")
	await wait_physics_frames(TAP_FRAMES)

	assert_false(is_instance_valid(pickup), "the pickup should be freed")


func test_the_others_lie_where_they_were_when_one_is_taken() -> void:
	var room := _spawn_room()
	var almos := _almos(room)
	var greatsword: Node2D = room.find_child("GreatswordPickup", true, false)
	var place := greatsword.global_position

	await _pick_up(room, almos, "SpearPickup")

	assert_true(is_instance_valid(greatsword), "the other pickup should still be there")
	assert_eq(greatsword.global_position, place)


func test_a_press_of_interact_picks_up_nothing_until_it_is_let_go_of() -> void:
	var room := _spawn_room()
	var almos := _almos(room)
	_stand_at(room, almos, "SpearPickup")

	_almos_input.press_action(&"interact")
	await wait_physics_frames(TAP_FRAMES)

	assert_eq(almos.weapons.carried.size(), 1, "nothing is picked up while the button is down")
	_almos_input.release_action(&"interact")
	await wait_physics_frames(TAP_FRAMES)
	assert_eq(almos.weapons.carried.size(), 2, "picked up as it is let go of")


func test_a_tap_just_inside_his_reach_picks_up_and_just_outside_does_not() -> void:
	var tuning := _tuning()
	var room := _spawn_room()
	var almos := _almos(room)
	_stand_from(room, almos, "SpearPickup", tuning.pickup_reach + REACH_MARGIN)
	await _tap(&"interact")
	assert_eq(almos.weapons.carried.size(), 1, "just outside his reach")

	_stand_from(room, almos, "SpearPickup", tuning.pickup_reach - REACH_MARGIN)
	await _tap(&"interact")

	assert_eq(almos.weapons.carried.size(), 2, "just inside his reach")


func test_the_nearest_pickup_in_reach_is_the_one_taken() -> void:
	var room := _spawn_room()
	var almos := _almos(room)
	var spear: Node2D = room.find_child("SpearPickup", true, false)
	var greatsword: Node2D = room.find_child("GreatswordPickup", true, false)
	almos.global_position = OPEN_SPOT
	greatsword.global_position = almos.global_position + Vector2(10.0, 0.0)
	spear.global_position = almos.global_position + Vector2(-20.0, 0.0)

	await _tap(&"interact")

	assert_eq(_paths(almos.weapons.carried), [SWORD_PATH, GREATSWORD_PATH])
	assert_true(is_instance_valid(spear), "the farther pickup should still lie there")


func test_one_tap_takes_only_one_pickup() -> void:
	var room := _spawn_room()
	var almos := _almos(room)
	var spear: Node2D = room.find_child("SpearPickup", true, false)
	var greatsword: Node2D = room.find_child("GreatswordPickup", true, false)
	almos.global_position = OPEN_SPOT
	spear.global_position = almos.global_position
	greatsword.global_position = almos.global_position

	await _tap(&"interact")

	assert_eq(almos.weapons.carried.size(), 2)


func test_a_tap_with_a_checkpoint_and_a_pickup_both_in_reach_rests_and_leaves_the_pickup() -> void:
	var room := _spawn_room()
	var almos := _almos(room)
	var checkpoint: Node2D = room.find_child("Checkpoint", true, false)
	var spear: Node2D = room.find_child("SpearPickup", true, false)
	spear.global_position = checkpoint.global_position + Vector2(BESIDE, 0.0)
	almos.global_position = checkpoint.global_position
	var hurt := _hurt(almos)
	watch_signals(almos)

	await _tap(&"interact")

	assert_signal_emitted(almos, "rested")
	assert_gt(almos.health.current, hurt, "the rest should refill his Health")
	assert_true(is_instance_valid(spear), "the pickup should lie where it was")
	assert_eq(almos.weapons.carried.size(), 1, "nothing should have been picked up")


func test_a_tap_beside_a_pickup_and_no_checkpoint_does_not_rest() -> void:
	var room := _spawn_room()
	var almos := _almos(room)
	_stand_at(room, almos, "SpearPickup")
	var hurt := _hurt(almos)

	await _tap(&"interact")

	assert_almost_eq(almos.health.current, hurt, TOLERANCE)


func test_a_weapon_picked_up_with_empty_hands_comes_to_hand() -> void:
	var room := _spawn_room()
	var almos := _almos(room)
	await _hold_interact_to_drop()
	assert_null(almos.weapons.in_hand, "his hands should be empty")
	await _walk_clear_of_pickups(almos)
	await _pick_up(room, almos, "TorchPickup")

	assert_eq(almos.weapons.in_hand.resource_path, TORCH_PATH)


func test_a_tap_made_in_a_roll_picks_up_nothing() -> void:
	var room := _spawn_room()
	var almos := _almos(room)
	_stand_at(room, almos, "SpearPickup")
	_almos_input.press_action(&"roll")
	await wait_physics_frames(TAP_FRAMES)
	_almos_input.release_action(&"roll")
	await wait_physics_frames(TAP_FRAMES)
	assert_true(almos.rolling, "he should be in a Roll")
	var stood := almos.global_position

	_almos_input.press_action(&"interact")
	await wait_physics_frames(2)
	_almos_input.release_action(&"interact")
	await wait_physics_frames(2)

	assert_eq(almos.weapons.carried.size(), 1)
	assert_ne(almos.global_position, stood, "he should have moved on in the Roll")


func test_a_tap_made_while_blocking_picks_up_nothing() -> void:
	var room := _spawn_room()
	var almos := _almos(room)
	_stand_at(room, almos, "SpearPickup")
	_almos_input.press_action(&"block")
	await wait_physics_frames(TAP_FRAMES)
	assert_true(almos.blocking, "he should be blocking")

	await _tap(&"interact")

	assert_eq(almos.weapons.carried.size(), 1)


func test_a_tap_made_in_a_jump_picks_up_nothing() -> void:
	var room := _spawn_room()
	var almos := _almos(room)
	_stand_at(room, almos, "SpearPickup")
	_almos_input.press_action(&"jump")
	await wait_physics_frames(TAP_FRAMES)
	_almos_input.release_action(&"jump")
	assert_true(almos.airborne, "he should be in the air")
	almos.global_position = room.find_child("SpearPickup", true, false).global_position

	_almos_input.press_action(&"interact")
	await wait_physics_frames(2)
	_almos_input.release_action(&"interact")
	await wait_physics_frames(2)

	assert_eq(almos.weapons.carried.size(), 1)


func test_a_tap_made_in_a_swing_picks_up_nothing() -> void:
	var room := _spawn_room()
	var almos := _almos(room)
	_stand_at(room, almos, "SpearPickup")
	_almos_input.press_action(&"attack_light")
	await wait_physics_frames(TAP_FRAMES)
	_almos_input.release_action(&"attack_light")
	assert_true(almos.attacking, "he should be in a swing")

	_almos_input.press_action(&"interact")
	await wait_physics_frames(2)
	_almos_input.release_action(&"interact")
	await wait_physics_frames(2)

	assert_eq(almos.weapons.carried.size(), 1)


func test_a_press_lost_while_not_free_is_not_kept_for_when_he_is_free_again() -> void:
	var room := _spawn_room()
	var almos := _almos(room)
	_stand_at(room, almos, "SpearPickup")
	_almos_input.press_action(&"block")
	await wait_physics_frames(TAP_FRAMES)
	_almos_input.press_action(&"interact")
	await wait_physics_frames(TAP_FRAMES)
	_almos_input.release_action(&"block")
	await wait_physics_frames(TAP_FRAMES)
	_almos_input.release_action(&"interact")

	await wait_physics_frames(TAP_FRAMES)

	assert_eq(almos.weapons.carried.size(), 1)


# --- switching ---

func test_switching_cycles_the_weapons_in_pickup_order_and_wraps() -> void:
	var room := _spawn_room()
	var almos := _almos(room)
	await _pick_up(room, almos, "SpearPickup")
	await _pick_up(room, almos, "GreatswordPickup")

	var in_hand: Array[String] = []
	for i in 4:
		await _tap(&"switch_weapon")
		in_hand.append(almos.weapons.in_hand.resource_path)

	assert_eq(in_hand, [SPEAR_PATH, GREATSWORD_PATH, SWORD_PATH, SPEAR_PATH])


func test_switching_with_one_weapon_carried_changes_nothing() -> void:
	var almos := _almos(_spawn_room())

	await _tap(&"switch_weapon")

	assert_eq(almos.weapons.in_hand.resource_path, SWORD_PATH)


func test_the_weapon_switched_to_is_the_one_his_sword_reaches_with() -> void:
	var room := _spawn_room()
	var almos := _almos(room)
	await _pick_up(room, almos, "SpearPickup")
	var spear := load(SPEAR_PATH) as WeaponData

	await _tap(&"switch_weapon")

	var sword := almos.get_node("Sword") as Hitbox
	assert_almost_eq(StrikeGeometry.real_box(sword).end.x, spear.reach, POSITION_TOLERANCE)


func test_a_switch_is_made_in_a_roll() -> void:
	var room := _spawn_room()
	var almos := _almos(room)
	await _pick_up(room, almos, "SpearPickup")
	await _press(&"roll", TAP_FRAMES)
	await wait_physics_frames(2)
	assert_true(almos.rolling, "he should be in a Roll")

	await _press(&"switch_weapon", 2)

	assert_true(almos.rolling, "he should still be in the Roll")
	assert_eq(almos.weapons.in_hand.resource_path, SPEAR_PATH)


func test_a_switch_is_made_while_blocking() -> void:
	var room := _spawn_room()
	var almos := _almos(room)
	await _pick_up(room, almos, "SpearPickup")
	_almos_input.press_action(&"block")
	await wait_physics_frames(TAP_FRAMES)
	assert_true(almos.blocking, "he should be blocking")

	await _press(&"switch_weapon", 2)

	assert_true(almos.blocking, "he should still be blocking")
	assert_eq(almos.weapons.in_hand.resource_path, SPEAR_PATH)


func test_a_switch_is_made_in_a_jump() -> void:
	var room := _spawn_room()
	var almos := _almos(room)
	await _pick_up(room, almos, "SpearPickup")
	await _press(&"jump", TAP_FRAMES)
	assert_true(almos.airborne, "he should be in the air")

	await _press(&"switch_weapon", 2)

	assert_true(almos.airborne, "he should still be in the air")
	assert_eq(almos.weapons.in_hand.resource_path, SPEAR_PATH)


func test_a_switch_pressed_mid_swing_is_made_as_the_swing_ends() -> void:
	var room := _spawn_room()
	var almos := _almos(room)
	await _pick_up(room, almos, "SpearPickup")
	await _press(&"attack_light", 1)
	await wait_physics_frames(TAP_FRAMES)
	assert_true(almos.attacking, "he should be in a swing")

	await _press(&"switch_weapon", 2)

	assert_true(almos.attacking, "the swing should still be on")
	assert_eq(almos.weapons.in_hand.resource_path, SWORD_PATH, "not swapped in the middle of a swing")
	await _wait_until_not_in_an_attack(almos, SWORD_PATH)
	assert_eq(almos.weapons.in_hand.resource_path, SPEAR_PATH, "made as the swing ends")


func test_a_switch_pressed_while_charging_a_heavy_attack_is_made_as_the_swing_ends() -> void:
	var room := _spawn_room()
	var almos := _almos(room)
	await _pick_up(room, almos, "SpearPickup")
	_almos_input.press_action(&"attack_heavy")
	await wait_physics_frames(TAP_FRAMES)
	assert_true(almos.charging, "he should be charging")

	await _press(&"switch_weapon", 2)

	assert_eq(almos.weapons.in_hand.resource_path, SWORD_PATH, "not swapped in the middle of a charge")
	_almos_input.release_action(&"attack_heavy")
	await _wait_until_not_in_an_attack(almos, SWORD_PATH)
	assert_eq(almos.weapons.in_hand.resource_path, SPEAR_PATH, "made as the swing ends")


func test_a_switch_pressed_in_a_jump_attack_is_made_as_it_ends() -> void:
	var room := _spawn_room()
	var almos := _almos(room)
	await _pick_up(room, almos, "SpearPickup")
	await _press(&"jump", TAP_FRAMES)
	await _press(&"attack_heavy", 2)
	assert_true(almos.jump_attacking, "he should be in a Jump attack")

	await _press(&"switch_weapon", 2)

	assert_eq(almos.weapons.in_hand.resource_path, SWORD_PATH, "not swapped in the middle of a Jump attack")
	await _wait_until_not_in_an_attack(almos, SWORD_PATH)
	assert_eq(almos.weapons.in_hand.resource_path, SPEAR_PATH, "made as the Jump attack ends")


func test_a_light_press_in_the_buffer_window_after_a_waiting_switch_swings_with_the_new_weapon() -> void:
	var sword := load(SWORD_PATH) as WeaponData
	var spear := load(SPEAR_PATH) as WeaponData
	assert_ne(sword.light_attacks[0].damage, spear.light_attacks[0].damage, "the Weapons should hurt differently, so that the one swinging shows")
	assert_ne(sword.light_attacks[1].damage, spear.light_attacks[0].damage, "and the second swing of the sword is not the spear's first")
	var almos = _rig.spawn_almos(_almos_input)
	almos.weapons.pick_up(spear)
	await _rig.wait_frames(AlmosInput.SETTLE_FRAMES)

	await _tap_light()
	await _rig.wait_to_press_for_swing_frame(TAP_FRAMES + 2)
	await _tap_switch()
	await _rig.wait_to_press_for_swing_frame(_swing_frames(sword.light_attacks[0]) - sword.attack_buffer_frames)
	await _tap_light()
	await _wait_for_the_swing_to_end()

	var span := _rig.attack_span()
	var hits := _rig.hits()
	assert_eq(hits.size(), 2, "each swing should hit the target once")
	if hits.size() == 2:
		assert_almost_eq(hits[0].damage, sword.light_attacks[0].damage, TOLERANCE, "the first swing is the sword's")
		assert_almost_eq(hits[1].damage, spear.light_attacks[0].damage, TOLERANCE, "the buffered swing is the spear's first, the combo starting over")
		assert_eq(hits[1].sample - span.x, _swing_frames(sword.light_attacks[0]) + spear.light_attacks[0].startup_frames, "it follows the first swing without a gap")
	assert_eq(almos.weapons.in_hand.resource_path, SPEAR_PATH)


func test_a_heavy_press_in_the_buffer_window_after_a_waiting_switch_swings_with_the_new_weapon() -> void:
	var sword := load(SWORD_PATH) as WeaponData
	var spear := load(SPEAR_PATH) as WeaponData
	assert_ne(sword.heavy_attack.damage, spear.heavy_attack.damage, "the Weapons should hurt differently, so that the one swinging shows")
	var almos = _rig.spawn_almos(_almos_input)
	almos.weapons.pick_up(spear)
	await _rig.wait_frames(AlmosInput.SETTLE_FRAMES)

	await _tap_light()
	await _rig.wait_to_press_for_swing_frame(TAP_FRAMES + 2)
	await _tap_switch()
	await _rig.wait_to_press_for_swing_frame(_swing_frames(sword.light_attacks[0]) - sword.attack_buffer_frames)
	# Let go at once, so the charge is none.
	_almos_input.press_action(&"attack_heavy")
	await _rig.wait_frames(1)
	_almos_input.release_action(&"attack_heavy")
	await _wait_for_the_swing_to_end()

	var span := _rig.attack_span()
	var hits := _rig.hits()
	assert_eq(hits.size(), 2, "each swing should hit the target once")
	if hits.size() == 2:
		assert_almost_eq(hits[0].damage, sword.light_attacks[0].damage, TOLERANCE, "the first swing is the sword's")
		assert_almost_eq(hits[1].damage, spear.heavy_attack.damage, TOLERANCE, "the buffered Heavy attack is the spear's")
		assert_eq(hits[1].sample - span.x, _swing_frames(sword.light_attacks[0]) + spear.heavy_attack.startup_frames, "it follows the first swing without a gap")
	assert_eq(almos.weapons.in_hand.resource_path, SPEAR_PATH)


func test_only_one_switch_waits_for_the_swing_to_end() -> void:
	var room := _spawn_room()
	var almos := _almos(room)
	await _pick_up(room, almos, "SpearPickup")
	await _pick_up(room, almos, "GreatswordPickup")
	await _press(&"attack_light", 1)
	await wait_physics_frames(TAP_FRAMES)
	assert_true(almos.attacking, "he should be in a swing")

	await _press(&"switch_weapon", 2)
	await _press(&"switch_weapon", 2)
	await _wait_until_not_in_an_attack(almos, SWORD_PATH)
	await wait_physics_frames(TAP_FRAMES)

	assert_eq(almos.weapons.in_hand.resource_path, SPEAR_PATH, "one step, not two")


func test_a_switch_pressed_in_a_guard_break_is_lost() -> void:
	var tuning := _tuning()
	var room := _spawn_room()
	var almos := _almos(room)
	await _pick_up(room, almos, "SpearPickup")
	almos.stamina.spend(tuning.stamina_maximum - tuning.block_stamina_cost / 3.0)
	var hits := AlmosHits.new(self)
	var hitbox := hits.hitbox_from(almos, almos.facing * AlmosHits.HIT_DISTANCE)
	_almos_input.press_action(&"block")
	await wait_physics_frames(TAP_FRAMES)
	await hits.swing(hitbox, 1)
	await wait_physics_frames(TAP_FRAMES)
	assert_true(almos.guard_broken, "the blocked hit should have broken his guard")

	await _press(&"switch_weapon", 2)
	_almos_input.release_action(&"block")
	await _wait_until(func() -> bool: return not almos.guard_broken)
	await wait_physics_frames(TAP_FRAMES)

	assert_eq(almos.weapons.in_hand.resource_path, SWORD_PATH, "the press is lost, not kept")


func test_a_switch_pressed_in_a_parry_is_lost() -> void:
	var room := _spawn_room()
	var almos := _almos(room)
	await _pick_up(room, almos, "SpearPickup")
	await _press(&"parry", 1)
	assert_true(almos.parrying, "he should be in a Parry")

	await _press(&"switch_weapon", 2)
	await _wait_until(func() -> bool: return not almos.parrying)
	await wait_physics_frames(TAP_FRAMES)

	assert_eq(almos.weapons.in_hand.resource_path, SWORD_PATH, "the press is lost, not kept")


func test_a_switch_pressed_while_limp_is_lost_then_and_after_his_return() -> void:
	var room := _spawn_room()
	var almos := _almos(room)
	await _pick_up(room, almos, "SpearPickup")
	almos.health.take_damage(almos.health.maximum)
	assert_true(almos.dead, "he should be limp")

	await _press(&"switch_weapon", 2)
	await _wait_until(func() -> bool: return not almos.dead)
	await wait_physics_frames(TAP_FRAMES)

	assert_eq(almos.weapons.in_hand.resource_path, SWORD_PATH)


func test_a_switch_waiting_for_a_swing_is_forgotten_if_he_falls() -> void:
	var room := _spawn_room()
	var almos := _almos(room)
	await _pick_up(room, almos, "SpearPickup")
	await _press(&"attack_light", 1)
	await wait_physics_frames(TAP_FRAMES)
	await _press(&"switch_weapon", 2)
	almos.health.take_damage(almos.health.maximum)

	await _wait_until(func() -> bool: return not almos.dead)
	await wait_physics_frames(TAP_FRAMES)

	assert_eq(almos.weapons.in_hand.resource_path, SWORD_PATH)


func test_what_he_carries_survives_a_death() -> void:
	var room := _spawn_room()
	var almos := _almos(room)
	await _pick_up(room, almos, "SpearPickup")
	await _tap(&"switch_weapon")
	almos.health.take_damage(almos.health.maximum)

	await _wait_until(func() -> bool: return not almos.dead)

	assert_eq(_paths(almos.weapons.carried), [SWORD_PATH, SPEAR_PATH])
	assert_eq(almos.weapons.in_hand.resource_path, SPEAR_PATH)


# --- dropping ---

func test_a_hold_drops_the_weapon_in_hand_as_a_pickup_where_he_stands() -> void:
	var room := _spawn_room()
	var almos := _almos(room)
	almos.global_position = OPEN_SPOT
	var before := _pickups_in(room)

	await _hold_interact_to_drop()

	var dropped := _new_pickups_in(room, before)
	assert_eq(dropped.size(), 1, "one pickup should lie on the ground")
	if dropped.size() == 1:
		assert_eq(dropped[0].weapon.resource_path, SWORD_PATH)
		assert_eq(dropped[0].global_position, almos.global_position)
		assert_same(dropped[0].get_parent(), almos.get_parent(), "added to his parent")


func test_a_hold_drops_the_weapon_in_hand_and_the_next_one_comes_to_hand() -> void:
	var room := _spawn_room()
	var almos := _almos(room)
	await _pick_up(room, almos, "SpearPickup")
	await _pick_up(room, almos, "GreatswordPickup")

	await _hold_interact_to_drop()

	assert_eq(_paths(almos.weapons.carried), [SPEAR_PATH, GREATSWORD_PATH])
	assert_eq(almos.weapons.in_hand.resource_path, SPEAR_PATH)


func test_the_weapon_that_comes_to_hand_after_a_drop_is_the_one_his_sword_reaches_with() -> void:
	var room := _spawn_room()
	var almos := _almos(room)
	await _pick_up(room, almos, "SpearPickup")
	var spear := load(SPEAR_PATH) as WeaponData

	await _hold_interact_to_drop()

	var sword := almos.get_node("Sword") as Hitbox
	assert_almost_eq(StrikeGeometry.real_box(sword).end.x, spear.reach, POSITION_TOLERANCE)


func test_the_hold_drops_once_however_long_it_goes_on() -> void:
	var room := _spawn_room()
	var almos := _almos(room)
	await _pick_up(room, almos, "SpearPickup")
	await _pick_up(room, almos, "GreatswordPickup")

	_almos_input.press_action(&"interact")
	await wait_physics_frames(_drop_frames() * 3)
	_almos_input.release_action(&"interact")
	await wait_physics_frames(TAP_FRAMES)

	assert_eq(almos.weapons.carried.size(), 2)


func test_a_press_let_go_just_short_of_the_hold_is_a_tap_and_drops_nothing() -> void:
	var room := _spawn_room()
	var almos := _almos(room)
	_stand_at(room, almos, "SpearPickup")

	_almos_input.press_action(&"interact")
	await wait_physics_frames(_drop_frames() - HOLD_MARGIN)
	_almos_input.release_action(&"interact")
	await wait_physics_frames(TAP_FRAMES)

	assert_eq(_paths(almos.weapons.carried), [SWORD_PATH, SPEAR_PATH], "the tap picked the spear up")


func test_a_press_held_just_past_the_hold_drops_on_the_frame_it_gets_there() -> void:
	var room := _spawn_room()
	var almos := _almos(room)

	_almos_input.press_action(&"interact")
	await wait_physics_frames(_drop_frames() - HOLD_MARGIN)
	assert_not_null(almos.weapons.in_hand, "nothing is dropped before the hold is up")
	await wait_physics_frames(HOLD_MARGIN * 2)

	assert_null(almos.weapons.in_hand, "dropped by now, with the button still down")


func test_a_hold_that_drops_does_not_also_pick_up_the_weapon_it_leaves_or_one_beside_it() -> void:
	var room := _spawn_room()
	var almos := _almos(room)
	_stand_at(room, almos, "SpearPickup")

	await _hold_interact_to_drop()

	assert_eq(almos.weapons.carried.size(), 0, "nothing should have been picked up")
	assert_eq(_pickups_in(room).size(), 5, "the four on the floor and the sword dropped")


func test_a_hold_that_drops_does_not_also_rest() -> void:
	var room := _spawn_room()
	var almos := _almos(room)
	almos.global_position = room.find_child("Checkpoint", true, false).global_position
	var hurt := _hurt(almos)
	watch_signals(almos)

	await _hold_interact_to_drop()

	assert_signal_not_emitted(almos, "rested")
	assert_almost_eq(almos.health.current, hurt, TOLERANCE)
	assert_null(almos.weapons.in_hand, "it should have dropped the sword")


func test_a_dropped_weapon_can_be_picked_up_again() -> void:
	var room := _spawn_room()
	var almos := _almos(room)
	await _pick_up(room, almos, "SpearPickup")
	almos.global_position = OPEN_SPOT
	await _hold_interact_to_drop()
	assert_eq(_paths(almos.weapons.carried), [SPEAR_PATH])
	almos.global_position = OPEN_SPOT + Vector2.RIGHT * AWAY
	await wait_physics_frames(TAP_FRAMES)

	almos.global_position = OPEN_SPOT + Vector2.RIGHT * (_tuning().pickup_reach - REACH_MARGIN)
	await _tap(&"interact")

	assert_eq(_paths(almos.weapons.carried), [SPEAR_PATH, SWORD_PATH], "picked up after the spear")
	assert_eq(almos.weapons.in_hand.resource_path, SPEAR_PATH, "the one in hand stays")


func test_dropping_the_last_weapon_leaves_his_hands_empty() -> void:
	var almos := _almos(_spawn_room())

	await _hold_interact_to_drop()

	assert_null(almos.weapons.in_hand)
	assert_eq(almos.weapons.carried.size(), 0)


func test_an_attack_press_with_empty_hands_is_lost() -> void:
	var room := _spawn_room()
	var almos := _almos(room)
	await _hold_interact_to_drop()
	var sword := almos.get_node("Sword") as Hitbox

	_almos_input.press_action(&"attack_light")
	await wait_physics_frames(TAP_FRAMES)
	assert_false(almos.attacking, "no swing")
	assert_false(sword.active, "the sword should be off")
	_almos_input.release_action(&"attack_light")
	_almos_input.press_action(&"attack_heavy")
	await wait_physics_frames(TAP_FRAMES)

	assert_false(almos.charging, "no charge")
	assert_false(sword.active, "the sword should be off")


func test_a_jump_attack_press_with_empty_hands_is_lost() -> void:
	var room := _spawn_room()
	var almos := _almos(room)
	await _hold_interact_to_drop()
	await _press(&"jump", TAP_FRAMES)
	assert_true(almos.airborne, "he should be in the air")

	await _press(&"attack_heavy", 2)

	assert_false(almos.jump_attacking, "no Jump attack")
	await _wait_until(func() -> bool: return not almos.airborne)
	assert_false(almos.attacking, "no strike on landing")


func test_a_switch_with_empty_hands_changes_nothing() -> void:
	var almos := _almos(_spawn_room())
	await _hold_interact_to_drop()

	await _tap(&"switch_weapon")

	assert_null(almos.weapons.in_hand)


func test_a_hold_with_empty_hands_drops_nothing() -> void:
	var room := _spawn_room()
	var almos := _almos(room)
	await _hold_interact_to_drop()
	var lying := _pickups_in(room).size()

	await _hold_interact_to_drop()

	assert_eq(_pickups_in(room).size(), lying)


func test_a_hold_begun_while_blocking_drops_nothing() -> void:
	var room := _spawn_room()
	var almos := _almos(room)
	_almos_input.press_action(&"block")
	await wait_physics_frames(TAP_FRAMES)
	assert_true(almos.blocking, "he should be blocking")

	await _hold_interact_to_drop()

	assert_eq(almos.weapons.carried.size(), 1)


func test_a_hold_begun_in_a_roll_drops_nothing_when_the_roll_is_over() -> void:
	var tuning := _tuning()
	var room := _spawn_room()
	var almos := _almos(room)
	await _press(&"roll", TAP_FRAMES)
	await wait_physics_frames(2)
	assert_true(almos.rolling, "he should be in a Roll")

	_almos_input.press_action(&"interact")
	await wait_physics_frames(_drop_frames() + int(ceil(tuning.roll_duration * 60.0)) + HOLD_MARGIN)
	_almos_input.release_action(&"interact")
	await wait_physics_frames(TAP_FRAMES)

	assert_false(almos.rolling, "the Roll should be over")
	assert_eq(almos.weapons.carried.size(), 1)


func test_a_hold_he_stops_being_free_in_the_middle_of_drops_nothing() -> void:
	var room := _spawn_room()
	var almos := _almos(room)
	_almos_input.press_action(&"interact")
	await wait_physics_frames(_drop_frames() / 2)
	_almos_input.press_action(&"block")
	await wait_physics_frames(TAP_FRAMES)
	assert_true(almos.blocking, "he should be blocking")
	_almos_input.release_action(&"block")

	await wait_physics_frames(_drop_frames() * 2)
	_almos_input.release_action(&"interact")
	await wait_physics_frames(TAP_FRAMES)

	assert_eq(almos.weapons.carried.size(), 1, "the press was lost when he started to block")


func test_a_hold_he_stops_being_free_in_the_middle_of_is_not_a_tap_when_let_go_of() -> void:
	var room := _spawn_room()
	var almos := _almos(room)
	_stand_at(room, almos, "SpearPickup")
	_almos_input.press_action(&"interact")
	await wait_physics_frames(TAP_FRAMES)
	_almos_input.press_action(&"block")
	await wait_physics_frames(TAP_FRAMES)
	_almos_input.release_action(&"block")
	await wait_physics_frames(TAP_FRAMES)

	_almos_input.release_action(&"interact")
	await wait_physics_frames(TAP_FRAMES)

	assert_eq(almos.weapons.carried.size(), 1, "the lost press picks nothing up")


func test_dropped_pickups_stay_where_they_are_through_a_rest() -> void:
	var room := _spawn_room()
	var almos := _almos(room)
	almos.global_position = OPEN_SPOT
	await _hold_interact_to_drop()
	var dropped := _dropped_sword(room)
	almos.global_position = room.find_child("Checkpoint", true, false).global_position

	await _tap(&"interact")

	assert_true(is_instance_valid(dropped), "the dropped Weapon should still lie there")
	assert_eq(dropped.global_position, OPEN_SPOT)


func test_dropped_pickups_stay_where_they_are_through_a_death() -> void:
	var room := _spawn_room()
	var almos := _almos(room)
	almos.global_position = OPEN_SPOT
	await _hold_interact_to_drop()
	var dropped := _dropped_sword(room)

	almos.health.take_damage(almos.health.maximum)
	await _wait_until(func() -> bool: return not almos.dead)

	assert_true(is_instance_valid(dropped), "the dropped Weapon should still lie there")
	assert_eq(dropped.global_position, OPEN_SPOT)


# --- helpers ---

func _tuning() -> PlayerTuning:
	var tuning := load(TUNING_PATH) as PlayerTuning
	assert_not_null(tuning, "the player tuning data file should load")
	assert_gt(tuning.drop_hold_time, 0.0, "drop_hold_time in the data file should be positive")
	assert_gt(tuning.pickup_reach, 0.0, "pickup_reach in the data file should be positive")
	return tuning


# The test room as shipped, with its enemy put far away so that it leaves Almos be. The test
# frees it.
func _spawn_room() -> Node:
	var scene := load(TEST_ROOM_PATH) as PackedScene
	assert_not_null(scene, "the test room scene should load")
	var room := scene.instantiate()
	add_child_autofree(room)
	(room.find_child("TrainingEnemy", true, false) as Node2D).global_position = Vector2(1100.0, 100.0)
	return room


func _almos(room: Node) -> Almos:
	return room.find_child("Almos", true, false)


# The physics frames a hold lasts to reach drop_hold_time.
func _drop_frames() -> int:
	return ceili(_tuning().drop_hold_time * Engine.physics_ticks_per_second)


# Almos's Weapons, as their data files' paths.
func _paths(weapons: Array[WeaponData]) -> Array[String]:
	var paths: Array[String] = []
	for weapon in weapons:
		paths.append(weapon.resource_path)
	return paths


func _pickups_in(room: Node) -> Array[WeaponPickup]:
	var found: Array[WeaponPickup] = []
	for node in get_tree().get_nodes_in_group(PICKUPS_GROUP):
		var pickup := node as WeaponPickup
		if pickup != null and room.is_ancestor_of(pickup) and not pickup.is_queued_for_deletion():
			found.append(pickup)
	return found


func _new_pickups_in(room: Node, before: Array[WeaponPickup]) -> Array[WeaponPickup]:
	var now := _pickups_in(room)
	var added: Array[WeaponPickup] = []
	for pickup in now:
		if not before.has(pickup):
			added.append(pickup)
	return added


# The pickup lying in the room that holds the sword.
func _dropped_sword(room: Node) -> WeaponPickup:
	for pickup in _pickups_in(room):
		if pickup.weapon.resource_path == SWORD_PATH:
			return pickup
	fail_test("no sword is lying in the room")
	return null


func _stand_at(room: Node, almos: Almos, pickup_name: String) -> void:
	_stand_from(room, almos, pickup_name, 0.0)


# Puts Almos this far to the left of the pickup's centre.
func _stand_from(room: Node, almos: Almos, pickup_name: String, distance: float) -> void:
	var pickup: Node2D = room.find_child(pickup_name, true, false)
	assert_not_null(pickup, "the test room should have a %s" % pickup_name)
	almos.global_position = pickup.global_position + Vector2.LEFT * distance


# Takes some of Almos's Health off and returns how much he has left.
func _hurt(almos: Almos) -> float:
	almos.health.take_damage(almos.health.maximum * HURT_FRACTION)
	return almos.health.current


# Walks Almos to the pickup and taps Interact.
func _pick_up(room: Node, almos: Almos, pickup_name: String) -> void:
	_stand_at(room, almos, pickup_name)
	await _tap(&"interact")


# Presses the action for this many physics frames, lets go and does not wait after.
func _press(action: StringName, frames: int) -> void:
	_almos_input.press_action(action)
	await wait_physics_frames(frames)
	_almos_input.release_action(action)


# A tap: a press far short of any hold, and the same time after it for it to take effect, since a
# tap of Interact does its work as it is let go of.
func _tap(action: StringName) -> void:
	await _press(action, TAP_FRAMES)
	await wait_physics_frames(TAP_FRAMES)


# Holds Interact well past the time it takes to drop, lets go and waits for it to take effect.
func _hold_interact_to_drop() -> void:
	_almos_input.press_action(&"interact")
	await wait_physics_frames(_drop_frames() + HOLD_MARGIN)
	_almos_input.release_action(&"interact")
	await wait_physics_frames(TAP_FRAMES)


# Moves Almos away from every pickup in the room, the one he has just dropped included, so that
# nothing is within his reach.
func _walk_clear_of_pickups(almos: Almos) -> void:
	almos.global_position = OPEN_SPOT + Vector2.RIGHT * AWAY
	await wait_physics_frames(TAP_FRAMES)


# Waits, a frame at a time, until Almos is no longer in an attack (a swing, a Heavy attack charge
# or a Jump attack), asserting that the Weapon in hand is the one given for as long as he is in
# one.
func _wait_until_not_in_an_attack(almos: Almos, in_hand_during: String) -> void:
	for i in WAIT_FRAME_LIMIT:
		var in_an_attack := almos.attacking or almos.charging or almos.jump_attacking
		if not in_an_attack:
			return
		assert_eq(almos.weapons.in_hand.resource_path, in_hand_during, "swapped in the middle of an attack")
		await get_tree().physics_frame
	fail_test("the attack should have ended")


# Presses the Light attack button for a few frames, as the rig's frames go, and lets go.
func _tap_light() -> void:
	_almos_input.press_action(&"attack_light")
	await _rig.wait_frames(TAP_FRAMES)
	_almos_input.release_action(&"attack_light")


# Presses the Switch button for a couple of frames, as the rig's frames go, and lets go.
func _tap_switch() -> void:
	_almos_input.press_action(&"switch_weapon")
	await _rig.wait_frames(2)
	_almos_input.release_action(&"switch_weapon")


func _swing_frames(swing: AttackData) -> int:
	return swing.startup_frames + swing.active_frames + swing.recovery_frames


# Waits for the first stretch of swings to end.
func _wait_for_the_swing_to_end() -> void:
	var ended: bool = await wait_until(func(): return _rig.attack_span().y != -1, WAIT_FRAME_LIMIT, "the swing should end")
	assert_true(ended, "the swing should have begun and ended")


func _wait_until(done: Callable) -> void:
	for i in WAIT_FRAME_LIMIT:
		if done.call():
			return
		await get_tree().physics_frame
	fail_test("what the test waited for did not come")
