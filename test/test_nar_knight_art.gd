extends GutTest
## The knight in Radio/Officers is nar_knight.tscn: the training enemy with the knight's tuning and
## an Art sprite of his own, driven by EnemyLook, with every animation it plays and a sleep pose.
## Seated asleep at his post he is drawn asleep with a zzz over him; once he wakes the zzz is gone.

const KNIGHT_PATH := "res://scenes/enemies/nar_knight.tscn"
const RADIO_OFFICERS_PATH := "res://scenes/areas/dungeons/radio_officers.tscn"
const ART_DIR := "res://assets/characters/nar_knight/"
const ANIMATIONS := [&"idle", &"walk", &"strike", &"low", &"unblockable", &"break", &"death", &"sleep"]
const FRAME_SIZE := Vector2i(64, 64)


func test_the_knight_has_a_sprite_with_every_animation_the_driver_plays() -> void:
	var knight := (load(KNIGHT_PATH) as PackedScene).instantiate()
	add_child_autofree(knight)
	var art := knight.get_node_or_null("Look/Art") as AnimatedSprite2D
	assert_not_null(art, "the knight has an Art sprite")
	assert_eq(art.scale, Vector2(1, 1), "one art px is 1 unit")
	for animation_name in ANIMATIONS:
		assert_true(art.sprite_frames.has_animation(animation_name), "the knight has %s" % animation_name)
		for i in art.sprite_frames.get_frame_count(animation_name):
			var texture := art.sprite_frames.get_frame_texture(animation_name, i)
			assert_eq(texture.get_size(), Vector2(FRAME_SIZE), "%s %d is 64x64" % [animation_name, i])
			assert_true(texture.resource_path.begins_with(ART_DIR), "%s %d is the knight's own" % [animation_name, i])
	assert_not_null(knight.get_node_or_null("Look/EnemyLook"), "EnemyLook drives the sprite")
	assert_eq(knight.tuning, load("res://data/nar_knight.tres"), "it carries the knight's tuning")


func test_the_knights_placeholder_shapes_are_hidden_not_deleted() -> void:
	var knight := (load(KNIGHT_PATH) as PackedScene).instantiate()
	add_child_autofree(knight)
	for shape_name in ["Shape", "Nose"]:
		var shape := knight.get_node_or_null("Look/" + shape_name) as CanvasItem
		assert_not_null(shape, "%s stays for the code and tests that use it" % shape_name)
		assert_false(shape.visible, "%s is hidden under the sprite" % shape_name)


func test_the_knight_in_radio_officers_is_a_nar_knight_asleep_at_his_desk() -> void:
	var room := (load(RADIO_OFFICERS_PATH) as PackedScene).instantiate()
	add_child_autofree(room)
	var knight := room.get_node("Knight")
	assert_eq(knight.scene_file_path, KNIGHT_PATH, "he is a Nar knight")
	assert_true(knight.named, "he is the named enemy")
	assert_true(knight.seated and knight.asleep, "he sits asleep")
	assert_not_null(room.get_node_or_null("Desk/Art"), "his desk is drawn")


func test_asleep_at_his_post_he_is_drawn_asleep_with_a_zzz() -> void:
	var knight := _knight_watching_nobody()
	await wait_physics_frames(3)
	await wait_process_frames(2)

	assert_eq((knight.get_node("Look/Art") as AnimatedSprite2D).animation, &"sleep", "drawn asleep")
	assert_true((knight.get_node("Look/Zzz") as SleepZzz).showing(), "the zzz shows")


func test_once_he_is_awake_the_zzz_is_gone() -> void:
	var knight := _knight_watching_nobody()
	await wait_physics_frames(3)
	await wait_process_frames(2)

	knight.slide(Vector2.LEFT, 4.0, 200.0)
	await wait_physics_frames(3)
	await wait_process_frames(2)

	assert_false(knight.sleeping(), "control: he is awake")
	assert_ne((knight.get_node("Look/Art") as AnimatedSprite2D).animation, &"sleep", "not drawn asleep")
	assert_false((knight.get_node("Look/Zzz") as SleepZzz).showing(), "the zzz is gone")


func test_a_seated_enemy_that_is_not_asleep_is_drawn_sitting_with_no_zzz() -> void:
	var knight := (load(KNIGHT_PATH) as PackedScene).instantiate()
	knight.seated = true
	knight.target = _far_target()
	add_child_autofree(knight)
	assert_true(knight.sitting(), "control: it sits")
	assert_false(knight.sleeping(), "it is not asleep")


# A knight seated asleep, with a target far behind him that he cannot see.
func _knight_watching_nobody() -> Node2D:
	var knight := (load(KNIGHT_PATH) as PackedScene).instantiate() as Node2D
	knight.seated = true
	knight.asleep = true
	knight.post_facing = Vector2.RIGHT
	knight.target = _far_target()
	add_child_autofree(knight)
	return knight


func _far_target() -> Node2D:
	var target := Node2D.new()
	target.position = Vector2(-2000, 0)
	add_child_autofree(target)
	return target
