extends GutTest
## Stagger, tested directly through its public interface. Time is passed in with advance(),
## never waited for, and every expected number comes from the numbers given to it here, not
## from the code under test.

const TOLERANCE := 0.0001
# In Health points.
const HEALTH_MAXIMUM := 50.0

var _stagger: Stagger


func before_each() -> void:
	_stagger = autofree(Stagger.new())
	_stagger.capacity = 100.0
	_stagger.drain_rate = 20.0
	_stagger.drain_pause = 2.0


func test_it_starts_empty() -> void:
	assert_almost_eq(_stagger.current, 0.0, TOLERANCE)
	assert_false(_stagger.full, "an empty meter should not be full")


func test_adding_puts_that_much_on() -> void:
	_stagger.add(30.0)
	_stagger.add(25.0)

	assert_almost_eq(_stagger.current, 55.0, TOLERANCE)


func test_adding_past_the_capacity_stays_at_the_capacity() -> void:
	_stagger.add(_stagger.capacity * 0.75)
	_stagger.add(_stagger.capacity * 0.75)

	assert_almost_eq(_stagger.current, _stagger.capacity, TOLERANCE)
	assert_true(_stagger.full, "a meter at its capacity should be full")


func test_it_announces_a_change_when_something_is_added_and_when_it_drains() -> void:
	watch_signals(_stagger)

	_stagger.add(10.0)
	assert_signal_emit_count(_stagger, "changed", 1)
	_stagger.advance(_stagger.drain_pause + 0.1)
	assert_signal_emit_count(_stagger, "changed", 2)


func test_it_does_not_drain_during_the_pause() -> void:
	_stagger.add(50.0)

	_stagger.advance(_stagger.drain_pause - 0.01)

	assert_almost_eq(_stagger.current, 50.0, TOLERANCE)


func test_after_the_pause_it_drains_at_the_rate() -> void:
	_stagger.add(50.0)
	var after := 1.5

	_stagger.advance(_stagger.drain_pause + after)

	assert_almost_eq(_stagger.current, 50.0 - _stagger.drain_rate * after, TOLERANCE)


func test_the_pause_can_be_spent_in_many_small_steps() -> void:
	_stagger.add(50.0)
	var steps := 200
	var step := (_stagger.drain_pause + 1.0) / steps

	for i in steps:
		_stagger.advance(step)

	assert_almost_eq(_stagger.current, 50.0 - _stagger.drain_rate * 1.0, TOLERANCE)


func test_it_drains_to_zero_and_no_further() -> void:
	_stagger.add(10.0)

	_stagger.advance(_stagger.drain_pause + 100.0)

	assert_almost_eq(_stagger.current, 0.0, TOLERANCE)


func test_adding_restarts_the_pause() -> void:
	_stagger.add(50.0)
	_stagger.advance(_stagger.drain_pause - 0.1)

	_stagger.add(10.0)
	_stagger.advance(_stagger.drain_pause - 0.1)

	assert_almost_eq(_stagger.current, 60.0, TOLERANCE, "the pause should have started over")


func test_adding_nothing_still_restarts_the_pause() -> void:
	_stagger.add(50.0)
	_stagger.advance(_stagger.drain_pause - 0.1)

	_stagger.add(0.0)
	_stagger.advance(_stagger.drain_pause - 0.1)

	assert_almost_eq(_stagger.current, 50.0, TOLERANCE, "adding nothing should still press the enemy")


func test_a_meter_at_the_capacity_drains_after_the_pause_too() -> void:
	_stagger.add(_stagger.capacity * 2.0)

	_stagger.advance(_stagger.drain_pause + 1.0)

	assert_almost_eq(_stagger.current, _stagger.capacity - _stagger.drain_rate, TOLERANCE)


func test_it_never_touches_a_health_beside_it() -> void:
	var health: Health = autofree(Health.new())
	health.maximum = HEALTH_MAXIMUM

	_stagger.add(_stagger.capacity * 2.0)
	_stagger.advance(_stagger.drain_pause + 100.0)

	assert_almost_eq(health.current, HEALTH_MAXIMUM, TOLERANCE)
