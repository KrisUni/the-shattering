extends GutTest
## What drives an enemy's sprite: which animation it plays and which palette colour is flashed on
## it, seen through the real enemy scene with a stand-in Art sprite in its Look. Every expected
## colour comes from the look bible (docs/art.md) and every expected length from the tuning data
## file, never from how the driver works them out.

const EnemyRig := preload("res://test/helpers/enemy_rig.gd")

const CREAM := Color("fbf5ef")
const DANGER_RED := Color("d62839")
const ANIMATIONS: Array[StringName] = [&"idle", &"walk", &"strike", &"low", &"unblockable", &"break", &"hurt", &"death"]

const STRIKE := EnemyTuning.AttackKind.STRIKE
const LOW := EnemyTuning.AttackKind.LOW
const UNBLOCKABLE := EnemyTuning.AttackKind.UNBLOCKABLE

# In Stagger points. Hits that take no Health.
const NO_DAMAGE := 0.0
const SETTLE_FRAMES := 10
# In physics frames. Slack for a wait that must not run on for ever.
const WAIT_FRAME_LIMIT := 600

var _rig: EnemyRig
var _tuning: EnemyTuning


func before_each() -> void:
	_rig = EnemyRig.new(self)
	_tuning = _rig.tuning_with()


func after_each() -> void:
	_rig.stop_sampling()


# A sprite named Art in the enemy's Look, with 1x1 frames for every animation name. Each
# animation has this many frames, run at 30 a second, and loops unless it is told not to.
func _give_art(enemy: Node, frame_count := 1, looping := true) -> AnimatedSprite2D:
	var frames := SpriteFrames.new()
	frames.remove_animation(&"default")
	for animation in ANIMATIONS:
		frames.add_animation(animation)
		frames.set_animation_loop(animation, looping)
		frames.set_animation_speed(animation, 30.0)
		var image := Image.create(1, 1, false, Image.FORMAT_RGBA8)
		image.fill(Color.WHITE)
		for i in frame_count:
			frames.add_frame(animation, ImageTexture.create_from_image(image))
	var art := AnimatedSprite2D.new()
	art.name = "Art"
	art.sprite_frames = frames
	enemy.get_node("Look").add_child(art)
	return art


func _watch(enemy: Node, art: AnimatedSprite2D) -> void:
	var driver = enemy.get_node("Look/EnemyLook")
	_rig.sample_also("animation", func() -> StringName: return art.animation)
	_rig.sample_also("flash", func() -> Color: return driver.flash_color)
	_rig.sample_also("amount", func() -> float: return driver.flash_amount)
	_rig.sample_also("modulate", func() -> Color: return enemy.modulate)
	_rig.sample_also("kind", func() -> int: return enemy.attack_kind)


# How many samples of the first stretch in which the enemy winds up an attack of this kind show
# this colour flashed, and the animation of its first sample.
func _first_wind_up_of(kind: int) -> Array[Dictionary]:
	var found: Array[Dictionary] = []
	for sample in _rig.samples:
		if sample.winding_up and sample.kind == kind:
			found.append(sample)
		elif not found.is_empty():
			break
	return found


func test_a_normal_wind_up_plays_its_pose_and_flashes_cream_at_its_start_only() -> void:
	var enemy = _rig.spawn_enemy()
	var art := _give_art(enemy)
	_watch(enemy, art)
	_rig.place_target(Vector2.RIGHT * _tuning.attack_range)
	await _rig.wait_frames(_tuning.attack.total_frames() + SETTLE_FRAMES)

	var wind_up := _first_wind_up_of(STRIKE)
	assert_eq(wind_up.size(), _tuning.attack.startup_frames, "samples of the wind-up")
	var cream := wind_up.filter(func(s: Dictionary) -> bool: return s.amount > 0.0)
	assert_gt(cream.size(), 0, "the wind-up flashes")
	assert_lt(cream.size(), wind_up.size(), "and the flash is only the start of it")
	for sample in cream:
		assert_eq(sample.flash, CREAM, "the flash is cream")
	assert_eq(wind_up[0].amount, 1.0, "it starts on the first frame of the wind-up")
	assert_eq(wind_up[-1].amount, 0.0, "and is over by the end of it")
	for sample in wind_up:
		assert_eq(sample.animation, &"strike", "it shows the strike pose")
		assert_eq(sample.modulate, Color.WHITE, "the whole node is not tinted")


func test_an_unblockable_wind_up_flashes_cream_then_holds_danger_red_to_its_end() -> void:
	var enemy = _rig.spawn_enemy()
	var art := _give_art(enemy)
	_watch(enemy, art)
	_rig.place_target(Vector2.RIGHT * _tuning.attack_range)
	var round_frames := 0
	for kind in _tuning.attack_pattern:
		round_frames += _tuning.attack_of(kind).total_frames()
	await _rig.wait_frames(round_frames + SETTLE_FRAMES)

	var wind_up := _first_wind_up_of(UNBLOCKABLE)
	assert_eq(wind_up.size(), _tuning.unblockable_attack.startup_frames, "samples of the wind-up")
	for i in wind_up.size():
		var sample: Dictionary = wind_up[i]
		var want := CREAM if i < _tuning.unblockable_flash_frames else DANGER_RED
		assert_eq(sample.flash, want, "colour flashed in wind-up frame %d" % i)
		assert_eq(sample.amount, 1.0, "flash amount in wind-up frame %d" % i)
		assert_eq(sample.animation, &"unblockable", "its pose in wind-up frame %d" % i)
		assert_eq(sample.modulate, Color.WHITE, "the whole node is not tinted")


func test_a_low_wind_up_plays_its_own_pose() -> void:
	var enemy = _rig.spawn_enemy()
	var art := _give_art(enemy)
	_watch(enemy, art)
	_rig.place_target(Vector2.RIGHT * _tuning.attack_range)
	await _rig.wait_frames(_tuning.attack.total_frames() + _tuning.low_attack.total_frames() + SETTLE_FRAMES)

	var wind_up := _first_wind_up_of(LOW)
	assert_eq(wind_up.size(), _tuning.low_attack.startup_frames, "samples of the wind-up")
	for sample in wind_up:
		assert_eq(sample.animation, &"low")
	assert_eq(wind_up[0].flash, CREAM, "it starts with a cream flash")


func test_a_break_plays_its_pose_with_a_cream_flash_at_its_start() -> void:
	var enemy = _rig.spawn_enemy()
	var art := _give_art(enemy)
	_watch(enemy, art)
	_rig.place_target(Vector2.RIGHT * _tuning.attack_range * 4.0)
	var breaker := _rig.hitbox_over(enemy, NO_DAMAGE, "enemy_hurtbox")
	breaker.stagger = _tuning.stagger_capacity
	await _rig.wait_frames(SETTLE_FRAMES)
	await _rig.swing(breaker, 1)
	await _rig.wait_frames(_tuning.break_frames / 2)

	assert_true(enemy.broken)
	var broken := _rig.samples.filter(func(s: Dictionary) -> bool: return s.animation == &"break")
	assert_gt(broken.size(), _tuning.break_frames / 2 - 3, "it shows the pose while broken")
	assert_eq(broken[0].flash, CREAM)
	assert_eq(broken[0].amount, 1.0, "it starts with a flash")
	assert_eq(broken[-1].amount, 0.0, "which is over soon")
	assert_eq(broken[-1].modulate, Color.WHITE)


func test_a_dead_enemy_plays_its_death() -> void:
	var enemy = _rig.spawn_enemy()
	var art := _give_art(enemy)
	_watch(enemy, art)
	var driver = enemy.get_node("Look/EnemyLook")
	_rig.place_target(Vector2.RIGHT * _tuning.attack_range * 4.0)
	await _rig.wait_frames(SETTLE_FRAMES)
	enemy.health.take_damage(enemy.health.current)
	# Only the physics step in which it is dead, before it is freed at the end of that frame.
	driver.update_look()
	assert_eq(art.animation, &"death")
	assert_eq(driver.flash_amount, 0.0)


func test_a_resting_enemy_idles_and_a_walking_one_walks() -> void:
	var enemy = _rig.spawn_enemy()
	var art := _give_art(enemy)
	_watch(enemy, art)
	await _rig.wait_frames(SETTLE_FRAMES)
	assert_eq(art.animation, &"idle")
	assert_eq(enemy.modulate, Color.WHITE, "no tint on a resting enemy with a sprite")
	enemy.velocity = Vector2.RIGHT * 10.0
	enemy.get_node("Look/EnemyLook").update_look()
	assert_eq(art.animation, &"walk")


func test_a_missing_animation_is_skipped_silently() -> void:
	var enemy = _rig.spawn_enemy()
	var art := _give_art(enemy)
	art.sprite_frames.remove_animation(&"idle")
	await _rig.wait_frames(SETTLE_FRAMES)
	assert_false(art.is_playing(), "nothing is played that is not there")


func test_with_no_sprite_the_old_tints_stay() -> void:
	var enemy = _rig.spawn_enemy()
	_rig.place_target(Vector2.RIGHT * _tuning.attack_range)
	var first_wind_up := Color.WHITE
	for i in WAIT_FRAME_LIMIT:
		await _rig.wait_frames(1)
		if enemy.winding_up:
			first_wind_up = enemy.modulate
			break
	assert_eq(first_wind_up, enemy.WIND_UP_TINT)


func test_the_sprite_turns_left_with_an_enemy_that_faces_left_and_right_with_one_that_faces_right() -> void:
	var enemy = _rig.spawn_enemy()
	var art := _give_art(enemy)
	enemy.post_facing = Vector2.LEFT
	await _rig.wait_frames(2)
	assert_true(art.flip_h, "faces left, so the sprite is flipped")

	enemy.post_facing = Vector2.RIGHT
	await _rig.wait_frames(2)
	assert_false(art.flip_h, "faces right, so it is not")


func test_an_enemy_facing_up_or_down_keeps_the_side_its_sprite_had() -> void:
	var enemy = _rig.spawn_enemy()
	var art := _give_art(enemy)
	enemy.post_facing = Vector2.LEFT
	await _rig.wait_frames(2)
	for vertical in [Vector2.UP, Vector2.DOWN]:
		enemy.post_facing = vertical
		await _rig.wait_frames(2)
		assert_true(art.flip_h, "still left after facing %s" % vertical)

	enemy.post_facing = Vector2.RIGHT
	await _rig.wait_frames(2)
	for vertical in [Vector2.UP, Vector2.DOWN]:
		enemy.post_facing = vertical
		await _rig.wait_frames(2)
		assert_false(art.flip_h, "still right after facing %s" % vertical)


func test_an_enemy_without_an_art_sprite_is_left_alone_when_it_turns() -> void:
	var enemy = _rig.spawn_enemy()
	enemy.post_facing = Vector2.LEFT
	await _rig.wait_frames(2)
	assert_eq(enemy.get_node("Look").get_node_or_null("Art"), null, "no sprite was made")
	assert_eq(enemy.modulate, Color.WHITE)


# A finished pose is held on its last frame while the enemy stays in that state.
func test_a_held_unblockable_pose_stays_on_its_last_frame_after_the_animation_ends() -> void:
	var enemy = _rig.spawn_enemy()
	var art := _give_art(enemy, 3, false)
	_watch(enemy, art)
	_rig.sample_also("frame", func() -> int: return art.frame)
	_rig.sample_also("attack_frame", func() -> int: return enemy.attack_frame)
	_rig.place_target(Vector2.RIGHT * _tuning.attack_range)
	var round_frames := 0
	for kind in _tuning.attack_pattern:
		round_frames += _tuning.attack_of(kind).total_frames()
	await _rig.wait_frames(round_frames + SETTLE_FRAMES)

	var attack := _tuning.unblockable_attack
	var held := _rig.samples.filter(func(s: Dictionary) -> bool:
		return s.kind == UNBLOCKABLE and s.attack_frame >= 20 and s.attack_frame < attack.total_frames() - 5)
	assert_gt(held.size(), attack.startup_frames / 2, "the unblockable outlasts its three frame animation")
	for sample in held:
		assert_eq(sample.animation, &"unblockable")
		assert_eq(sample.frame, 2, "held on the last frame at attack frame %d" % sample.attack_frame)


func test_a_held_break_pose_stays_on_its_last_frame_after_the_animation_ends() -> void:
	var enemy = _rig.spawn_enemy()
	var art := _give_art(enemy, 3, false)
	_watch(enemy, art)
	_rig.place_target(Vector2.RIGHT * _tuning.attack_range * 4.0)
	var breaker := _rig.hitbox_over(enemy, NO_DAMAGE, "enemy_hurtbox")
	breaker.stagger = _tuning.stagger_capacity
	await _rig.wait_frames(SETTLE_FRAMES)
	await _rig.swing(breaker, 1)
	await _rig.wait_frames(_tuning.break_frames / 2)

	assert_true(enemy.broken)
	assert_eq(art.animation, &"break")
	assert_eq(art.frame, 2, "held on the last frame")
	assert_false(art.is_playing(), "and not started over")


# A club combo is swing after swing with no walk between, all of them the `strike` animation, so
# only a new swing tells the driver to start it again, and the flash at its start comes with it.
func test_a_second_swing_of_a_combo_restarts_the_animation_and_flashes_cream() -> void:
	var swing := AttackData.new()
	swing.startup_frames = 12
	swing.active_frames = 2
	swing.recovery_frames = 8
	swing.damage = 1.0
	var tuning := _rig.tuning_with({
		"attack_pattern": Array([EnemyTuning.AttackKind.COMBO], TYPE_INT, "", null),
		"combo": Array([swing, swing], TYPE_OBJECT, "Resource", AttackData),
	})
	var enemy = _rig.spawn_enemy(tuning)
	var art := _give_art(enemy, 2, false)
	_watch(enemy, art)
	_rig.sample_also("frame", func() -> int: return art.frame)
	_rig.sample_also("attack_frame", func() -> int: return enemy.attack_frame)
	_rig.place_target(Vector2.RIGHT * tuning.attack_range)
	await _rig.wait_frames(2 * swing.total_frames() + SETTLE_FRAMES)

	var starts: Array[int] = []
	for i in _rig.samples.size():
		if _rig.samples[i].attack_frame == 1 and _rig.samples[i].kind == EnemyTuning.AttackKind.COMBO:
			starts.append(i)
	assert_gte(starts.size(), 2, "two swings were made")
	var before_second: Dictionary = _rig.samples[starts[1] - 2]
	var second: Dictionary = _rig.samples[starts[1]]
	assert_eq(before_second.animation, &"strike", "no walk between the swings")
	assert_eq(before_second.frame, 1, "the first swing's animation had finished")
	assert_eq(second.frame, 0, "the second swing starts it over")
	assert_eq(second.amount, 1.0, "with its cream flash")
	assert_eq(second.flash, CREAM)
