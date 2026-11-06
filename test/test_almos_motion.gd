extends GutTest
## Almos moves with some life: he runs with a longer, pitched stride when he Sprints, crouches to
## spring, tucks in the air and crouches to land from a Jump, flinches when a hit costs him Health,
## raises his forearms while he Blocks, and fidgets now and then as he stands still. Dust kicks up
## from his feet as he Sprints and as he lands, and landing dips his figure a pixel or two. All of it
## is only a look, drawn on his Art by AlmosLook.

const AlmosInput := preload("res://test/helpers/almos_input.gd")

var _almos_input: AlmosInput


func before_each() -> void:
	await get_tree().process_frame
	_almos_input = AlmosInput.new(self)


func after_each() -> void:
	_almos_input.release_everything()


func _art(almos: Node) -> AnimatedSprite2D:
	return almos.get_node("Look/Art") as AnimatedSprite2D


func _puffs(almos: Node) -> Array:
	return almos.get_parent().get_children().filter(func(node: Node) -> bool: return node is DustPuff)


func test_he_has_every_new_pose_for_every_side() -> void:
	var almos = _almos_input.spawn_almos()
	var frames := _art(almos).sprite_frames
	var counts := {&"sprint": 6, &"jump": 3, &"hurt": 2, &"block": 1, &"fidget": 8}
	for pose: StringName in counts:
		for side in ["down", "up", "side"]:
			var animation_name := StringName("%s_%s" % [pose, side])
			assert_true(frames.has_animation(animation_name), "he has %s" % animation_name)
			if frames.has_animation(animation_name):
				assert_eq(frames.get_frame_count(animation_name), counts[pose], "%s has its frames" % animation_name)
				assert_eq(frames.get_frame_texture(animation_name, 0).get_size(), Vector2(32, 48), "%s is 32 by 48" % animation_name)


func test_sprinting_he_runs_and_kicks_up_dust() -> void:
	var almos = _almos_input.spawn_almos()
	await wait_physics_frames(2)
	_almos_input.press_action(&"move_right")
	_almos_input.press_action(&"roll")
	var sprinted := false
	var dust := false
	for i in 60:
		await wait_physics_frames(1)
		if almos.sprinting and _art(almos).animation == &"sprint_side":
			sprinted = true
		if not _puffs(almos).is_empty():
			dust = true
	assert_true(sprinted, "sprinting right, he runs side on")
	assert_true(dust, "and dust kicks up from his feet")


func test_walking_he_kicks_up_no_dust() -> void:
	var almos = _almos_input.spawn_almos()
	await wait_physics_frames(2)
	_almos_input.press_action(&"move_right")
	await wait_physics_frames(40)
	assert_eq(_art(almos).animation, &"walk_side", "he walks")
	assert_true(_puffs(almos).is_empty(), "quietly")


func test_a_jump_springs_tucks_and_lands_with_dust_and_a_dip() -> void:
	var almos = _almos_input.spawn_almos()
	await wait_physics_frames(2)
	_almos_input.press_action(&"jump")
	var seen := {}
	var dipped := false
	var dust := false
	for i in 60:
		await wait_physics_frames(1)
		var art: AnimatedSprite2D = _art(almos)
		if art.animation == &"jump_down":
			seen[art.frame] = true
		if art.position.y > 0.0:
			dipped = true
		if not _puffs(almos).is_empty():
			dust = true
	_almos_input.release_everything()
	assert_eq(seen.keys().size(), 3, "the spring, the tuck and the landing crouch all show")
	assert_true(dipped, "landing dips his figure")
	assert_true(dust, "dust kicks up as he springs and lands")
	await wait_physics_frames(10)
	assert_eq(_art(almos).position, Vector2.ZERO, "and he comes back up")


func test_a_hit_that_costs_health_makes_him_flinch() -> void:
	var almos = _almos_input.spawn_almos()
	await wait_physics_frames(2)
	(almos.get_node("Health") as Health).take_damage(5.0)
	await wait_physics_frames(2)
	assert_eq(_art(almos).animation, &"hurt_down", "he flinches")
	await wait_physics_frames(30)
	assert_eq(_art(almos).animation, &"idle_down", "and gathers himself")


func test_blocking_he_raises_his_forearms() -> void:
	var almos = _almos_input.spawn_almos()
	await wait_physics_frames(2)
	_almos_input.press_action(&"block")
	await wait_physics_frames(6)
	assert_true(almos.blocking, "control: he blocks")
	assert_eq(_art(almos).animation, &"block_down", "his guard is up")


func test_standing_still_a_while_he_fidgets_once_then_idles() -> void:
	var almos = _almos_input.spawn_almos()
	var look: Node = almos.get_node("Look/AlmosLook")
	look.set(&"_fidget_after", 0.2)
	await wait_physics_frames(30)
	assert_eq(_art(almos).animation, &"fidget_down", "he fidgets")
	await wait_seconds(2.0)
	assert_eq(_art(almos).animation, &"idle_down", "then stands idle again")


func test_he_has_the_remaining_poses_for_every_side() -> void:
	var almos = _almos_input.spawn_almos()
	var frames := _art(almos).sprite_frames
	var counts := {&"parry": 2, &"sip": 3, &"hold": 6, &"winded": 4, &"death": 3, &"attack_greatsword": 5}
	for pose: StringName in counts:
		for side in ["down", "up", "side"]:
			var animation_name := StringName("%s_%s" % [pose, side])
			assert_true(frames.has_animation(animation_name), "he has %s" % animation_name)
			if frames.has_animation(animation_name):
				assert_eq(frames.get_frame_count(animation_name), counts[pose], "%s has its frames" % animation_name)
	assert_eq((load("res://data/greatsword.tres") as WeaponData).look, &"greatsword", "the greatsword names its own swing")


func test_parrying_he_sweeps_his_forearm_across() -> void:
	var almos = _almos_input.spawn_almos()
	await wait_physics_frames(2)
	_almos_input.press_action(&"parry")
	var parried := false
	for i in 12:
		await wait_physics_frames(1)
		if _art(almos).animation == &"parry_down":
			parried = true
	assert_true(parried, "he parries")


func test_sipping_he_drinks_from_the_flask() -> void:
	var almos = _almos_input.spawn_almos()
	await wait_physics_frames(2)
	_almos_input.press_action(&"sip_health")
	var drank := false
	for i in 20:
		await wait_physics_frames(1)
		if almos.sipping and _art(almos).animation == &"sip_down":
			drank = true
	assert_true(drank, "he drinks")


func test_dying_he_slumps_to_the_floor() -> void:
	var almos = _almos_input.spawn_almos()
	await wait_physics_frames(2)
	(almos.get_node("Health") as Health).take_damage(100000.0)
	await wait_physics_frames(3)
	assert_true(almos.dead, "control: he is dead")
	assert_eq(_art(almos).animation, &"death_down", "he slumps")
