extends GutTest
## The timeline of an attack, tested directly through AttackData's public interface. Every
## number comes from the data files of the sword and of the training enemy (or a copy a test
## changes) and plain arithmetic, never from how the code works them out.
##
## Frames are counted from 0, the first frame of the attack. Startup, active and recovery
## follow one another with no gap and no overlap, and before frame 0 and from the frame after
## the last one there is no attack.

const WEAPON_PATH := "res://data/sword.tres"
const ENEMY_TUNING_PATH := "res://data/training_enemy.tres"


func test_the_attack_lasts_its_startup_active_and_recovery_frames_together() -> void:
	for attack in _attacks():
		assert_eq(attack.total_frames(), attack.startup_frames + attack.active_frames + attack.recovery_frames)


func test_each_frame_of_the_attack_is_in_exactly_one_part_and_the_parts_last_as_long_as_the_data_says() -> void:
	for attack in _attacks():
		var counts := {"startup": 0, "active": 0, "recovery": 0}
		for frame in attack.total_frames():
			var parts := 0
			if attack.is_winding_up(frame):
				counts.startup += 1
				parts += 1
			if attack.is_active(frame):
				counts.active += 1
				parts += 1
			if attack.is_recovering(frame):
				counts.recovery += 1
				parts += 1
			assert_eq(parts, 1, "frame %d of an attack of %d frames should be in exactly one part" % [frame, attack.total_frames()])
		assert_eq(counts.startup, attack.startup_frames, "frames of startup")
		assert_eq(counts.active, attack.active_frames, "frames of active")
		assert_eq(counts.recovery, attack.recovery_frames, "frames of recovery")


func test_the_parts_follow_one_another_in_order_with_their_edges_where_the_data_puts_them() -> void:
	for attack in _attacks():
		var first_active: int = attack.startup_frames
		var first_recovery: int = attack.startup_frames + attack.active_frames
		var last: int = attack.total_frames() - 1
		# The Jump attack has no startup at all: its first frame is an active one.
		if attack.startup_frames > 0:
			assert_true(attack.is_winding_up(0), "frame 0 should be the first frame of startup")
			assert_true(attack.is_winding_up(first_active - 1), "the frame before the first active one should be the last of startup")
		assert_false(attack.is_winding_up(first_active), "the first active frame should not be startup")
		assert_true(attack.is_active(first_active), "the first active frame")
		assert_false(attack.is_active(first_active - 1), "the last frame of startup should not be active")
		assert_true(attack.is_active(first_recovery - 1), "the last active frame")
		assert_false(attack.is_active(first_recovery), "the first frame of recovery should not be active")
		assert_true(attack.is_recovering(first_recovery), "the first frame of recovery")
		assert_false(attack.is_recovering(first_recovery - 1), "the last active frame should not be recovery")
		assert_true(attack.is_recovering(last), "the last frame of the attack should be recovery")


func test_before_the_first_frame_and_after_the_last_there_is_no_attack() -> void:
	for attack in _attacks():
		for frame in [-2, -1, attack.total_frames(), attack.total_frames() + 1]:
			assert_false(attack.is_winding_up(frame), "frame %d should not be startup" % frame)
			assert_false(attack.is_active(frame), "frame %d should not be active" % frame)
			assert_false(attack.is_recovering(frame), "frame %d should not be recovery" % frame)


func test_an_attack_with_no_recovery_ends_with_its_active_frames() -> void:
	var attack := _attacks()[0].duplicate() as AttackData
	attack.recovery_frames = 0

	assert_eq(attack.total_frames(), attack.startup_frames + attack.active_frames)
	assert_true(attack.is_active(attack.total_frames() - 1), "the last frame should be active")
	for frame in range(-1, attack.total_frames() + 2):
		assert_false(attack.is_recovering(frame), "frame %d should not be recovery" % frame)


func test_an_attack_with_no_startup_is_active_from_its_first_frame() -> void:
	var attack := _attacks()[0].duplicate() as AttackData
	attack.startup_frames = 0

	assert_eq(attack.total_frames(), attack.active_frames + attack.recovery_frames)
	assert_true(attack.is_active(0), "frame 0 should be active")
	for frame in range(-1, attack.total_frames() + 2):
		assert_false(attack.is_winding_up(frame), "frame %d should not be startup" % frame)


func test_the_jump_attack_has_no_startup_so_that_it_strikes_on_the_frame_he_lands() -> void:
	var weapon := load(WEAPON_PATH) as WeaponData
	assert_not_null(weapon, "the sword data file should load")

	assert_eq(weapon.jump_attack.startup_frames, 0, "its startup frames count from the landing, so a number above 0 would delay the strike")


# Every attack in the data files: the sword's Light swings, Heavy attack, Jump attack and
# Critical hit, and the training enemy's Strike, Low attack and Unblockable attack.
func _attacks() -> Array[AttackData]:
	var weapon := load(WEAPON_PATH) as WeaponData
	assert_not_null(weapon, "the sword data file should load")
	var tuning := load(ENEMY_TUNING_PATH) as EnemyTuning
	assert_not_null(tuning, "the training enemy tuning data file should load")
	var attacks: Array[AttackData] = []
	attacks.append_array(weapon.light_attacks)
	attacks.append(weapon.heavy_attack)
	attacks.append(weapon.jump_attack)
	attacks.append(weapon.critical_attack)
	attacks.append(tuning.attack)
	attacks.append(tuning.low_attack)
	attacks.append(tuning.unblockable_attack)
	return attacks
