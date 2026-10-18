extends GutTest
## The Checkpoint, tested as a node of its own: where it can be found, and its placeholder flash
## when it is rested at. Resting itself, which Almos does, is tested in test_resting.gd.

const CHECKPOINT_PATH := "res://scenes/world/checkpoint.tscn"
const GROUP := &"checkpoints"
# In seconds. A flash length of the test's own: the Checkpoint is told how long to flash.
const FLASH := 0.25
# In physics frames, at 60 a second.
const FLASH_FRAMES := 15


func before_each() -> void:
	await get_tree().process_frame


func test_it_is_found_in_the_checkpoints_group() -> void:
	var checkpoint := _spawn_checkpoint()

	assert_true(checkpoint.is_in_group(GROUP), "a Checkpoint should be in the group Almos looks in")


func test_it_does_not_flash_until_it_is_rested_at() -> void:
	var checkpoint := _spawn_checkpoint()

	await wait_physics_frames(3)

	assert_false(checkpoint.flashing, "it should be still")


func test_resting_makes_it_flash() -> void:
	var checkpoint := _spawn_checkpoint()

	checkpoint.rest(FLASH)

	assert_true(checkpoint.flashing, "it should flash from the moment it is rested at")


func test_the_flash_is_still_going_before_its_length_is_up() -> void:
	var checkpoint := _spawn_checkpoint()

	checkpoint.rest(FLASH)
	await wait_physics_frames(FLASH_FRAMES - 3)

	assert_true(checkpoint.flashing, "it should still be flashing a little before the end")


func test_the_flash_is_over_once_its_length_is_up() -> void:
	var checkpoint := _spawn_checkpoint()

	checkpoint.rest(FLASH)
	await wait_physics_frames(FLASH_FRAMES + 3)

	assert_false(checkpoint.flashing, "it should be still again after the flash")


func test_resting_again_during_a_flash_starts_it_over() -> void:
	var checkpoint := _spawn_checkpoint()
	checkpoint.rest(FLASH)
	await wait_physics_frames(FLASH_FRAMES - 3)

	checkpoint.rest(FLASH)
	await wait_physics_frames(FLASH_FRAMES - 3)

	assert_true(checkpoint.flashing, "the second rest should have started the flash over")


func test_the_flash_makes_it_brighter_than_it_is_at_rest() -> void:
	var checkpoint := _spawn_checkpoint()
	var resting_look: Color = checkpoint.modulate

	checkpoint.rest(FLASH)

	assert_gt(checkpoint.modulate.v, resting_look.v, "the flash should be a brightening")


func test_it_goes_back_to_its_resting_look_after_the_flash() -> void:
	var checkpoint := _spawn_checkpoint()
	var resting_look: Color = checkpoint.modulate
	checkpoint.rest(FLASH)

	await wait_physics_frames(FLASH_FRAMES + 3)

	assert_eq(checkpoint.modulate, resting_look)


# A Checkpoint in the tree. The test frees it.
func _spawn_checkpoint() -> Checkpoint:
	var scene := load(CHECKPOINT_PATH) as PackedScene
	assert_not_null(scene, "the Checkpoint scene should load")
	var checkpoint := scene.instantiate() as Checkpoint
	add_child_autofree(checkpoint)
	return checkpoint
