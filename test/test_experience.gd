extends GutTest
## Experience, tested directly through its public interface. Every expected number is plain
## arithmetic on the numbers the test gives it.


func test_it_starts_with_none() -> void:
	var experience := _new_experience()

	assert_eq(experience.total, 0)


func test_gaining_adds_that_amount_to_the_total() -> void:
	var experience := _new_experience()

	experience.gain(30)
	experience.gain(45)

	assert_eq(experience.total, 30 + 45)


func test_changed_is_emitted_each_time_it_gains() -> void:
	var experience := _new_experience()
	watch_signals(experience)

	experience.gain(30)
	experience.gain(45)

	assert_signal_emit_count(experience, "changed", 2)


func test_gaining_nothing_changes_nothing() -> void:
	var experience := _new_experience()
	experience.gain(30)
	watch_signals(experience)

	experience.gain(0)

	assert_eq(experience.total, 30)
	assert_signal_not_emitted(experience, "changed")


func test_gaining_a_negative_amount_changes_nothing() -> void:
	var experience := _new_experience()
	experience.gain(30)
	watch_signals(experience)

	experience.gain(-10)

	assert_eq(experience.total, 30)
	assert_signal_not_emitted(experience, "changed")


func test_taking_all_returns_the_whole_total_and_leaves_none() -> void:
	var experience := _new_experience()
	experience.gain(30)
	experience.gain(45)

	var taken := experience.take_all()

	assert_eq(taken, 30 + 45)
	assert_eq(experience.total, 0)


func test_changed_is_emitted_when_all_of_it_is_taken() -> void:
	var experience := _new_experience()
	experience.gain(30)
	watch_signals(experience)

	experience.take_all()

	assert_signal_emit_count(experience, "changed", 1)


func test_taking_all_of_none_returns_none_and_changes_nothing() -> void:
	var experience := _new_experience()
	watch_signals(experience)

	var taken := experience.take_all()

	assert_eq(taken, 0)
	assert_signal_not_emitted(experience, "changed")


func test_it_can_gain_again_after_all_is_taken() -> void:
	var experience := _new_experience()
	experience.gain(30)
	experience.take_all()

	experience.gain(45)

	assert_eq(experience.total, 45)


# A new Experience, which the test frees.
func _new_experience() -> Experience:
	var experience := Experience.new()
	autofree(experience)
	return experience
