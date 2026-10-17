extends GutTest
## Stamina, tested directly through its public interface. Time is passed in with
## advance(), never waited for, and every expected number comes from the tuning
## resource built here, not from the code under test.

const TOLERANCE := 0.0001

var _tuning: PlayerTuning


func before_each() -> void:
	_tuning = PlayerTuning.new()
	_tuning.stamina_maximum = 80.0
	_tuning.stamina_refill_rate = 20.0
	_tuning.stamina_refill_pause = 1.5


func test_starts_full_at_the_tuned_maximum() -> void:
	var stamina := _new_stamina()

	assert_almost_eq(stamina.current, _tuning.stamina_maximum, TOLERANCE)
	assert_almost_eq(stamina.maximum, _tuning.stamina_maximum, TOLERANCE)


func test_spending_takes_that_amount_off_and_returns_true() -> void:
	var stamina := _new_stamina()
	var cost := 30.0

	var spent := stamina.spend(cost)

	assert_true(spent, "spending from a full bar should succeed")
	assert_almost_eq(stamina.current, _tuning.stamina_maximum - cost, TOLERANCE)


func test_spending_more_than_is_left_empties_it_to_zero_and_returns_true() -> void:
	var stamina := _new_stamina()
	stamina.spend(_tuning.stamina_maximum - 10.0)

	var spent := stamina.spend(25.0)

	assert_true(spent, "spending while above zero should always succeed")
	assert_almost_eq(stamina.current, 0.0, TOLERANCE, "it should stop at zero, never go below")


func test_spending_at_zero_returns_false_and_changes_nothing() -> void:
	var stamina := _new_stamina()
	stamina.spend(_tuning.stamina_maximum)

	var spent := stamina.spend(10.0)

	assert_false(spent, "spending at zero should fail")
	assert_almost_eq(stamina.current, 0.0, TOLERANCE)


func test_does_not_refill_before_the_pause_has_passed() -> void:
	var stamina := _new_stamina()
	stamina.spend(30.0)

	stamina.advance(_tuning.stamina_refill_pause - 0.1)

	assert_almost_eq(stamina.current, _tuning.stamina_maximum - 30.0, TOLERANCE)


func test_refills_at_the_tuned_rate_per_second_once_the_pause_is_over() -> void:
	var stamina := _new_stamina()
	stamina.spend(50.0)
	stamina.advance(_tuning.stamina_refill_pause)

	stamina.advance(1.0)

	assert_almost_eq(stamina.current, _tuning.stamina_maximum - 50.0 + _tuning.stamina_refill_rate, TOLERANCE)


func test_time_beyond_the_pause_counts_even_within_a_single_advance() -> void:
	var stamina := _new_stamina()
	stamina.spend(50.0)

	stamina.advance(_tuning.stamina_refill_pause + 0.5)

	assert_almost_eq(stamina.current, _tuning.stamina_maximum - 50.0 + _tuning.stamina_refill_rate * 0.5, TOLERANCE)


func test_never_refills_above_the_maximum() -> void:
	var stamina := _new_stamina()
	stamina.spend(10.0)

	stamina.advance(_tuning.stamina_refill_pause + 100.0)

	assert_almost_eq(stamina.current, _tuning.stamina_maximum, TOLERANCE)


func test_spending_again_during_a_refill_restarts_the_pause() -> void:
	var stamina := _new_stamina()
	stamina.spend(50.0)
	stamina.advance(_tuning.stamina_refill_pause + 0.5)
	stamina.spend(10.0)
	var after_second_spend := stamina.current

	stamina.advance(_tuning.stamina_refill_pause - 0.1)

	assert_almost_eq(stamina.current, after_second_spend, TOLERANCE, "it should wait out the whole pause again")


func test_a_failed_spend_does_not_restart_the_pause() -> void:
	var stamina := _new_stamina()
	stamina.spend(_tuning.stamina_maximum)
	stamina.advance(_tuning.stamina_refill_pause - 0.5)
	stamina.spend(10.0)

	stamina.advance(0.5 + 1.0)

	assert_almost_eq(stamina.current, _tuning.stamina_refill_rate * 1.0, TOLERANCE, "the pause should end when it was going to")


func test_changed_is_emitted_when_spending() -> void:
	var stamina := _new_stamina()
	watch_signals(stamina)

	stamina.spend(30.0)

	assert_signal_emit_count(stamina, "changed", 1)


func test_changed_is_emitted_when_it_refills() -> void:
	var stamina := _new_stamina()
	stamina.spend(30.0)
	watch_signals(stamina)

	stamina.advance(_tuning.stamina_refill_pause + 0.5)

	assert_signal_emit_count(stamina, "changed", 1)


func test_changed_is_not_emitted_while_the_bar_is_full() -> void:
	var stamina := _new_stamina()
	watch_signals(stamina)

	stamina.advance(10.0)

	assert_signal_not_emitted(stamina, "changed")


func test_changed_is_not_emitted_during_the_pause() -> void:
	var stamina := _new_stamina()
	stamina.spend(30.0)
	watch_signals(stamina)

	stamina.advance(_tuning.stamina_refill_pause - 0.1)

	assert_signal_not_emitted(stamina, "changed")


func test_changed_is_not_emitted_when_a_spend_fails() -> void:
	var stamina := _new_stamina()
	stamina.spend(_tuning.stamina_maximum)
	watch_signals(stamina)

	stamina.spend(10.0)

	assert_signal_not_emitted(stamina, "changed")


func test_in_the_scene_tree_it_advances_by_itself_as_physics_time_passes() -> void:
	_tuning.stamina_refill_pause = 0.0
	var stamina := Stamina.new()
	stamina.tuning = _tuning
	add_child_autofree(stamina)
	stamina.spend(50.0)

	await wait_physics_frames(3)

	assert_gt(stamina.current, _tuning.stamina_maximum - 50.0, "it should have started to refill")


func _new_stamina() -> Stamina:
	var stamina := Stamina.new()
	stamina.tuning = _tuning
	return autofree(stamina)
