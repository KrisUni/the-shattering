extends GutTest
## The Root crawler's art: an AnimatedSprite2D named Art in its Look with every pose the driver
## plays, drawn at whole art pixels (scale 2), the placeholder polygons hidden but not deleted, and
## the sprite following the crawler's state through EnemyLook. Whether it looks right is for the
## owner to judge in the editor; these only check it is wired and moves with the crawler.

const EnemyRig := preload("res://test/helpers/enemy_rig.gd")

const SCENE_PATH := "res://scenes/enemies/root_crawler.tscn"
const POSES: Array[StringName] = [&"idle", &"walk", &"strike", &"low", &"unblockable", &"break", &"death"]
# Only these two repeat; every other pose plays once and holds its last frame.
const LOOPING: Array[StringName] = [&"idle", &"walk"]
# In art pixels: every frame is drawn on one canvas, so the feet stay put from frame to frame.
const CANVAS := Vector2i(32, 28)
# In Stagger points. A hit that takes no Health.
const NO_DAMAGE := 0.0
const SETTLE_FRAMES := 10

var _rig: EnemyRig
var _tuning: EnemyTuning


func before_each() -> void:
	_rig = EnemyRig.new(self)
	_tuning = load("res://data/root_crawler.tres") as EnemyTuning


func after_each() -> void:
	_rig.stop_sampling()


func _crawler() -> Node:
	var crawler: Node = (load(SCENE_PATH) as PackedScene).instantiate()
	# A crawler hunts by Noise, which a test with no Almos does not make: it sees instead, so the
	# look can be watched through a wind-up. Nothing else of the shipped tuning changes.
	var tuning := _tuning.duplicate(true) as EnemyTuning
	tuning.sound_hunter = false
	crawler.tuning = tuning
	add_child_autofree(crawler)
	_rig.enemy = crawler
	return crawler


func test_the_root_crawler_has_an_art_sprite_with_all_its_poses_at_scale_two() -> void:
	var crawler := _crawler()
	var art := crawler.get_node_or_null("Look/Art") as AnimatedSprite2D

	assert_not_null(art, "the Look should hold an AnimatedSprite2D named Art")
	if art == null:
		return
	assert_eq(art.scale, Vector2(2, 2), "one art pixel is two world units")
	for pose in POSES:
		assert_true(art.sprite_frames.has_animation(pose), "pose %s" % pose)
		assert_gt(art.sprite_frames.get_frame_count(pose), 0, "pose %s has frames" % pose)
		assert_eq(art.sprite_frames.get_animation_loop(pose), LOOPING.has(pose), "pose %s loops" % pose)
		for i in art.sprite_frames.get_frame_count(pose):
			var texture := art.sprite_frames.get_frame_texture(pose, i)
			assert_eq(Vector2i(texture.get_size()), CANVAS, "pose %s frame %d is on the common canvas" % [pose, i])


func test_the_placeholder_polygons_are_hidden_not_deleted() -> void:
	var crawler := _crawler()

	assert_false((crawler.get_node("Look/Shape") as Polygon2D).visible, "the Shape is hidden")
	assert_false((crawler.get_node("Look/Nose") as Polygon2D).visible, "the Nose is hidden")


func test_the_burning_flame_stands_on_the_crawlers_feet() -> void:
	var crawler := _crawler()
	var flame_art := crawler.get_node("Flammable/Flame/Art") as AnimatedSprite2D
	var feet := (crawler.get_node("CollisionShape2D") as CollisionShape2D).position.y \
			+ ((crawler.get_node("CollisionShape2D") as CollisionShape2D).shape as CircleShape2D).radius
	var texture := flame_art.sprite_frames.get_frame_texture(flame_art.animation, 0)
	var bottom := flame_art.position.y + texture.get_height() * flame_art.scale.y

	assert_eq(bottom, feet, "the flame's base is on the 12-unit body's foot")


func test_the_sprite_shows_a_strike_in_its_wind_up() -> void:
	var crawler := _crawler()
	var art := crawler.get_node("Look/Art") as AnimatedSprite2D
	_rig.place_target(Vector2.RIGHT * _tuning.attack_range)
	var seen_in_wind_up := {}
	for i in _tuning.attack.startup_frames + SETTLE_FRAMES:
		await _rig.wait_frames(1)
		if crawler.winding_up:
			seen_in_wind_up[art.animation] = true
	assert_true(seen_in_wind_up.has(&"strike"), "a spawned crawler winding up shows strike")


func test_the_sprite_shows_a_break_when_the_crawler_is_broken() -> void:
	var crawler := _crawler()
	var art := crawler.get_node("Look/Art") as AnimatedSprite2D
	_rig.place_target(Vector2.RIGHT * _tuning.sight_length_full * 4.0)
	await _rig.wait_frames(SETTLE_FRAMES)
	var breaker := _rig.hitbox_over(crawler, NO_DAMAGE, "enemy_hurtbox")
	breaker.stagger = _tuning.stagger_capacity
	await _rig.swing(breaker, 3)
	await _rig.wait_frames(SETTLE_FRAMES)
	assert_true(crawler.broken)
	assert_eq(art.animation, &"break", "a broken crawler shows break")
