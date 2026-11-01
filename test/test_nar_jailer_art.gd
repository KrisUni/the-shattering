extends GutTest
## The Dungeons' guards are drawn as skeletons: nar_jailer.tscn is the training enemy with the Nar
## jailer's tuning and a skeleton Art sprite, driven by EnemyLook. The key jailer in Radio/Officers
## is one, with its own tuning. The test room's enemies stay placeholder.

const JAILER_PATH := "res://scenes/enemies/nar_jailer.tscn"
const RADIO_OFFICERS_PATH := "res://scenes/areas/dungeons/radio_officers.tscn"
const TEST_ROOM_PATH := "res://scenes/test_room.tscn"
const ART_DIR := "res://assets/characters/nar_jailer/"
const ANIMATIONS := [&"idle", &"walk", &"strike", &"low", &"unblockable", &"break", &"death"]


func test_the_jailer_has_a_skeleton_sprite_with_every_animation_the_driver_plays() -> void:
	var jailer := (load(JAILER_PATH) as PackedScene).instantiate()
	add_child_autofree(jailer)
	var art := jailer.get_node_or_null("Look/Art") as AnimatedSprite2D
	assert_not_null(art, "the jailer has an Art sprite")
	assert_eq(art.scale, Vector2(2, 2), "one art px is 2 units")
	for animation_name in ANIMATIONS:
		assert_true(art.sprite_frames.has_animation(animation_name), "the jailer has %s" % animation_name)
	assert_not_null(jailer.get_node_or_null("Look/EnemyLook"), "EnemyLook drives the sprite")
	assert_eq(jailer.tuning, load("res://data/nar_jailer.tres"), "it carries the Nar jailer's tuning")


func test_the_jailers_placeholder_shapes_are_hidden_not_deleted() -> void:
	var jailer := (load(JAILER_PATH) as PackedScene).instantiate()
	add_child_autofree(jailer)
	for shape_name in ["Shape", "Nose"]:
		var shape := jailer.get_node_or_null("Look/" + shape_name) as CanvasItem
		assert_not_null(shape, "%s stays for the code and tests that use it" % shape_name)
		assert_false(shape.visible, "%s is hidden under the sprite" % shape_name)


func test_the_key_jailer_is_a_skeleton_with_its_own_tuning() -> void:
	var room := (load(RADIO_OFFICERS_PATH) as PackedScene).instantiate()
	add_child_autofree(room)
	var key_jailer := room.get_node("KeyJailer")
	assert_eq(key_jailer.scene_file_path, JAILER_PATH, "the key jailer is a skeleton jailer")
	assert_eq(key_jailer.tuning, load("res://data/nar_key_jailer.tres"), "it keeps the key jailer's tuning")
	assert_true(key_jailer.named, "it is still the named enemy")


func test_the_test_room_stays_placeholder() -> void:
	var room := (load(TEST_ROOM_PATH) as PackedScene).instantiate()
	add_child_autofree(room)
	for enemy in get_tree().get_nodes_in_group(&"enemies"):
		if room.is_ancestor_of(enemy):
			assert_ne(enemy.scene_file_path, JAILER_PATH, "%s in the test room is not a skeleton" % enemy.name)
