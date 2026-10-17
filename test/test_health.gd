extends GutTest
## Health, tested directly through its public interface. The maximum is given by each
## test, and every expected number is plain arithmetic on the numbers the test sets.

const TOLERANCE := 0.0001
const MAXIMUM := 80.0


func test_starts_at_its_maximum() -> void:
	var health := _new_health()

	assert_almost_eq(health.current, MAXIMUM, TOLERANCE)
	assert_almost_eq(health.maximum, MAXIMUM, TOLERANCE)


func test_damage_takes_that_amount_off() -> void:
	var health := _new_health()
	var damage := 30.0

	health.take_damage(damage)

	assert_almost_eq(health.current, MAXIMUM - damage, TOLERANCE)


func test_damage_beyond_what_is_left_stops_at_zero() -> void:
	var health := _new_health()

	health.take_damage(MAXIMUM + 25.0)

	assert_almost_eq(health.current, 0.0, TOLERANCE, "it should stop at zero, never go below")


func test_changed_is_emitted_when_it_takes_damage() -> void:
	var health := _new_health()
	watch_signals(health)

	health.take_damage(30.0)

	assert_signal_emit_count(health, "changed", 1)


func test_damage_at_zero_changes_nothing_and_emits_nothing() -> void:
	var health := _new_health()
	health.take_damage(MAXIMUM)
	watch_signals(health)

	health.take_damage(10.0)

	assert_almost_eq(health.current, 0.0, TOLERANCE)
	assert_signal_not_emitted(health, "changed")


func test_depleted_is_emitted_when_damage_takes_the_last_of_it() -> void:
	var health := _new_health()
	watch_signals(health)

	health.take_damage(MAXIMUM)

	assert_signal_emit_count(health, "depleted", 1)


func test_depleted_is_emitted_when_damage_goes_past_what_is_left() -> void:
	var health := _new_health()
	watch_signals(health)

	health.take_damage(MAXIMUM + 25.0)

	assert_signal_emit_count(health, "depleted", 1)


func test_depleted_is_not_emitted_while_some_is_left() -> void:
	var health := _new_health()
	watch_signals(health)

	health.take_damage(MAXIMUM - 1.0)

	assert_signal_not_emitted(health, "depleted")


func test_depleted_is_emitted_only_once_however_much_more_damage_follows() -> void:
	var health := _new_health()
	watch_signals(health)

	health.take_damage(MAXIMUM)
	health.take_damage(10.0)
	health.take_damage(MAXIMUM)

	assert_signal_emit_count(health, "depleted", 1)


func _new_health() -> Health:
	var health := Health.new()
	health.maximum = MAXIMUM
	return autofree(health)
