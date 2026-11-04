extends GutTest
## Almos is drawn as a capped adventurer with the dark Seal at his neck: an AnimatedSprite2D Art on
## his Look, driven by AlmosLook, with idle and walk drawn facing down, up and to the side. It walks
## while he moves and stands while he stands, shows the side he faces, and flips for the left. The torches
## that hang on him (the carried torch and the held flame) show only their flame, never a bracket.

const AlmosInput := preload("res://test/helpers/almos_input.gd")
const ART_DIR := "res://assets/characters/almos/"

var _almos_input: AlmosInput


func before_each() -> void:
	_almos_input = AlmosInput.new(self)


func after_each() -> void:
	_almos_input.release_everything()


func _art(almos: Node) -> AnimatedSprite2D:
	return almos.get_node("Look/Art") as AnimatedSprite2D


func test_he_has_a_sprite_with_idle_and_walk_at_scale_1() -> void:
	var almos = _almos_input.spawn_almos()
	var art := _art(almos)
	assert_not_null(art, "Almos has an Art sprite on his Look")
	assert_eq(art.scale, Vector2(1, 1), "one art px is 1 unit")
	for animation_name in [&"idle_down", &"walk_down", &"idle_up", &"walk_up", &"idle_side", &"walk_side"]:
		assert_true(art.sprite_frames.has_animation(animation_name), "he has %s" % animation_name)
	var size := art.sprite_frames.get_frame_texture(&"idle_down", 0).get_size()
	assert_eq(size, Vector2(32, 48), "he is 32 by 48 art px")


func test_his_placeholder_arrow_is_hidden_not_deleted() -> void:
	var almos = _almos_input.spawn_almos()
	var shape := almos.get_node("Look/Facing/Shape") as Polygon2D
	assert_not_null(shape, "the arrow stays for the code and tests that use it")
	assert_false(shape.visible, "the arrow is hidden under the sprite")


func test_the_torches_on_him_draw_no_bracket() -> void:
	var almos = _almos_input.spawn_almos()
	for torch_name in ["CarriedTorch", "HeldFlame"]:
		var bracket := almos.get_node("%s/Look/Art" % torch_name) as CanvasItem
		assert_false(bracket.visible, "%s shows no bracket on Almos" % torch_name)


func test_a_wall_torch_still_draws_its_bracket() -> void:
	var torch := (load("res://scenes/world/torch.tscn") as PackedScene).instantiate()
	add_child_autofree(torch)
	assert_true((torch.get_node("Look/Art") as CanvasItem).visible, "a wall torch keeps its bracket")


func test_he_walks_while_moving_and_stands_while_still() -> void:
	var almos = _almos_input.spawn_almos()
	await wait_physics_frames(2)
	assert_eq(_art(almos).animation, &"idle_down", "standing, facing down, he is idle")

	_almos_input.press_action(&"move_right")
	await wait_physics_frames(4)
	assert_eq(_art(almos).animation, &"walk_side", "moving right, he walks side on")

	_almos_input.release_everything()
	await wait_physics_frames(30)
	assert_eq(_art(almos).animation, &"idle_side", "still again, he is idle side on")


func test_he_shows_the_side_he_walks_toward_in_every_direction() -> void:
	var almos = _almos_input.spawn_almos()
	var art := _art(almos)
	var expected := {
		&"move_down": [&"walk_down", false],
		&"move_up": [&"walk_up", false],
		&"move_right": [&"walk_side", false],
		&"move_left": [&"walk_side", true],
	}
	for action: StringName in expected:
		_almos_input.press_action(action)
		await wait_physics_frames(4)
		assert_eq(art.animation, expected[action][0], "%s plays %s" % [action, expected[action][0]])
		assert_eq(art.flip_h, expected[action][1], "%s flips: %s" % [action, expected[action][1]])
		_almos_input.release_everything()
		await wait_physics_frames(30)
	assert_almost_eq(art.global_rotation, 0.0, 0.0001, "the sprite never turns, only flips")


func test_a_diagonal_shows_the_side_and_up_or_down_shows_itself() -> void:
	assert_eq(AlmosLook.side_for(Vector2.RIGHT), &"side")
	assert_eq(AlmosLook.side_for(Vector2.LEFT), &"side")
	assert_eq(AlmosLook.side_for(Vector2(1, 1).normalized()), &"side")
	assert_eq(AlmosLook.side_for(Vector2.UP), &"up")
	assert_eq(AlmosLook.side_for(Vector2.DOWN), &"down")
	assert_eq(AlmosLook.side_for(Vector2(0.3, -0.9).normalized()), &"up")


func test_he_has_a_six_frame_roll_for_every_side_that_plays_once() -> void:
	var almos = _almos_input.spawn_almos()
	var frames := _art(almos).sprite_frames
	for side in ["down", "up", "side"]:
		var roll := StringName("roll_" + side)
		assert_true(frames.has_animation(roll), "he has %s" % roll)
		assert_eq(frames.get_frame_count(roll), 6, "%s has six frames" % roll)
		assert_false(frames.get_animation_loop(roll), "%s plays once" % roll)


func test_a_roll_plays_the_roll_for_the_side_he_rolls_toward_from_its_first_frame() -> void:
	var almos = _almos_input.spawn_almos()
	var art := _art(almos)
	_almos_input.press_action(&"move_down")
	_almos_input.press_action(&"roll")
	await wait_physics_frames(2)
	_almos_input.release_action(&"roll")
	var seen_rolling := false
	for i in 10:
		await wait_physics_frames(1)
		if almos.rolling:
			seen_rolling = true
			break
	assert_true(seen_rolling, "a tap of roll with a direction starts a roll")
	assert_eq(art.animation, &"roll_down", "rolling down plays roll_down")
	assert_lte(art.frame, 1, "the roll starts from its first frames")
	_almos_input.release_everything()
	for i in 60:
		await wait_physics_frames(1)
		if not almos.rolling:
			break
	await wait_physics_frames(2)
	assert_ne(art.animation, &"roll_down", "after the roll he walks or stands again")


func test_he_has_an_attack_for_every_side_with_room_for_the_swing() -> void:
	var almos = _almos_input.spawn_almos()
	var frames := _art(almos).sprite_frames
	for side in ["down", "up", "side"]:
		var attack := StringName("attack_" + side)
		assert_true(frames.has_animation(attack), "he has %s" % attack)
		assert_eq(frames.get_frame_count(attack), 5, "%s has five frames" % attack)
		assert_eq(frames.get_frame_texture(attack, 0).get_size(), Vector2(64, 64), "%s has room for the smear" % attack)


func test_an_attack_frame_follows_the_swings_phases_whatever_its_length() -> void:
	for timing in [[8, 4, 14], [14, 4, 36], [0, 6, 20]]:
		var swing := AttackData.new()
		swing.startup_frames = timing[0]
		swing.active_frames = timing[1]
		swing.recovery_frames = timing[2]
		var shown: Array[int] = []
		for frame in swing.total_frames():
			shown.append(AlmosLook.attack_frame_for(swing, frame))
		for frame in swing.total_frames():
			if swing.is_active(frame):
				assert_eq(shown[frame], AlmosLook.STRIKE, "%s: the strike shows on active frame %d" % [timing, frame])
			elif swing.is_winding_up(frame):
				assert_lt(shown[frame], AlmosLook.STRIKE, "%s: a wind-up shows before the strike at %d" % [timing, frame])
			else:
				assert_gt(shown[frame], AlmosLook.STRIKE, "%s: recovery shows after the strike at %d" % [timing, frame])
		assert_eq(shown[-1], AlmosLook.RECOVER, "%s: it ends recovered" % [timing])
		var sorted := shown.duplicate()
		sorted.sort()
		assert_eq(shown, sorted, "%s: the frames only move forward" % [timing])


func test_a_light_attack_plays_the_attack_for_his_side_and_strikes_on_the_active_frames() -> void:
	var almos = _almos_input.spawn_almos()
	var art := _art(almos)
	var attacks: AlmosAttacks = almos.get_node("Attacks")
	_almos_input.press_action(&"move_up")
	await wait_physics_frames(3)
	_almos_input.release_everything()
	_almos_input.press_action(&"attack_light")
	await wait_physics_frames(2)
	_almos_input.release_action(&"attack_light")
	var seen_strike := false
	for i in 60:
		await wait_physics_frames(1)
		if attacks.swing == null:
			break
		assert_eq(art.animation, &"attack_sword_up", "facing up with the sword he starts with, he swings it upward")
		if attacks.swing.is_active(attacks.swing_frame - 1) or attacks.swing.is_active(attacks.swing_frame):
			seen_strike = seen_strike or art.frame == AlmosLook.STRIKE
	assert_true(seen_strike, "the strike frame shows during the swing's active frames")
	await wait_physics_frames(2)
	assert_ne(art.animation, &"attack_sword_up", "after the swing he stands again")


func test_the_old_strike_box_draws_nothing_now_the_sprite_shows_the_swing() -> void:
	var almos = _almos_input.spawn_almos()
	var shape := almos.get_node("Sword/Look/Shape") as Polygon2D
	assert_not_null(shape, "the strike box shape stays for the code and tests that measure it")
	assert_eq(shape.color.a, 0.0, "it is transparent, so only the smear shows the swing")


func test_he_has_a_sword_swing_for_every_side_with_room_for_the_swing() -> void:
	var almos = _almos_input.spawn_almos()
	var art := _art(almos)
	for side in ["down", "up", "side"]:
		var animation_name := StringName("attack_sword_" + side)
		assert_true(art.sprite_frames.has_animation(animation_name), "he has %s" % animation_name)
		if not art.sprite_frames.has_animation(animation_name):
			continue
		assert_eq(art.sprite_frames.get_frame_count(animation_name), 5, "%s has the swing's five frames" % animation_name)
		assert_eq(art.sprite_frames.get_frame_texture(animation_name, 0).get_size(), Vector2(64, 64), "%s is 64 by 64" % animation_name)


func test_with_the_sword_in_hand_he_swings_the_sword_and_without_a_weapon_the_plain_swing() -> void:
	var almos = _almos_input.spawn_almos()
	var art := _art(almos)
	var sword := load("res://data/sword.tres") as WeaponData
	assert_eq(sword.look, &"sword", "control: the sword's swing goes by sword")
	while almos.weapons.in_hand != null:
		almos.weapons.drop()
	_almos_input.press_action(&"move_right")
	await wait_physics_frames(3)
	_almos_input.release_everything()

	assert_eq(await _animation_of_a_light_attack(art), &"attack_side", "unarmed, the plain swing")
	await wait_physics_frames(40)
	almos.weapons.pick_up(sword)
	assert_eq(await _animation_of_a_light_attack(art), &"attack_sword_side", "with the sword, the sword swing")


func _animation_of_a_light_attack(art: AnimatedSprite2D) -> StringName:
	_almos_input.press_action(&"attack_light")
	await wait_physics_frames(3)
	_almos_input.release_action(&"attack_light")
	return art.animation
