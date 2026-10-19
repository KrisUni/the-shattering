extends GutTest
## Almos's Flasks, tested directly through their public interface: how many Health Flask charges
## there are, what a Sip spends, what restores Health and when, and when the charge is wasted. The
## numbers are those of the shipped tuning; every expected value is plain arithmetic on them.

const TUNING_PATH := "res://data/flasks.tres"
const TOLERANCE := 0.0001
# In Health points.
const HEALTH_MAXIMUM := 100.0
# In seconds. One physics frame.
const FRAME := 1.0 / 60.0

var _tuning: FlaskTuning
var _health: Health
var _flasks: AlmosFlasks
var _changes := 0


func before_each() -> void:
	_tuning = load(TUNING_PATH) as FlaskTuning
	_health = Health.new()
	_health.maximum = HEALTH_MAXIMUM
	add_child_autofree(_health)
	_flasks = AlmosFlasks.new()
	_flasks.tuning = _tuning
	_flasks.health = _health
	add_child_autofree(_flasks)
	_changes = 0
	_flasks.changed.connect(func() -> void: _changes += 1)


func test_it_starts_with_the_charges_of_the_tuning() -> void:
	assert_eq(_flasks.health_charges, _tuning.health_charges)
	assert_eq(_flasks.health_charges_maximum, _tuning.health_charges)


func test_a_sip_spends_one_charge_at_once() -> void:
	_flasks.sip()

	assert_eq(_flasks.health_charges, _tuning.health_charges - 1)


func test_a_sip_is_under_way_until_its_duration_has_gone() -> void:
	_flasks.sip()
	_run(_tuning.sip_duration - 3.0 * FRAME)

	assert_true(_flasks.sipping)


func test_a_sip_restores_the_tuned_share_of_the_maximum_at_its_end() -> void:
	_health.take_damage(HEALTH_MAXIMUM * 0.8)
	var before := _health.current
	_flasks.sip()
	_run(_tuning.sip_duration + 2.0 * FRAME)

	assert_almost_eq(_health.current, before + HEALTH_MAXIMUM * _tuning.health_restore_share, TOLERANCE)
	assert_false(_flasks.sipping)


func test_a_sip_restores_nothing_before_its_end() -> void:
	_health.take_damage(HEALTH_MAXIMUM * 0.8)
	var before := _health.current
	_flasks.sip()
	_run(_tuning.sip_duration - 3.0 * FRAME)

	assert_almost_eq(_health.current, before, TOLERANCE)


func test_a_sip_never_takes_health_past_the_maximum() -> void:
	_health.take_damage(HEALTH_MAXIMUM * 0.1)
	_flasks.sip()
	_run(_tuning.sip_duration + 2.0 * FRAME)

	assert_almost_eq(_health.current, HEALTH_MAXIMUM, TOLERANCE)


func test_a_hit_during_a_sip_wastes_the_charge_and_restores_nothing() -> void:
	_health.take_damage(HEALTH_MAXIMUM * 0.5)
	_flasks.sip()
	_run(_tuning.sip_duration / 2.0)
	_health.take_damage(5.0)
	var after_the_hit := _health.current
	_run(_tuning.sip_duration)

	assert_almost_eq(_health.current, after_the_hit, TOLERANCE)
	assert_false(_flasks.sipping)
	assert_eq(_flasks.health_charges, _tuning.health_charges - 1)


func test_a_sip_with_no_charges_left_does_nothing() -> void:
	for i in _tuning.health_charges:
		_flasks.sip()
		_run(_tuning.sip_duration + 2.0 * FRAME)
	_changes = 0

	var began := _flasks.sip()

	assert_false(began)
	assert_false(_flasks.sipping)
	assert_eq(_flasks.health_charges, 0)
	assert_eq(_changes, 0, "nothing should have changed")


func test_a_sip_while_one_is_under_way_spends_nothing_more() -> void:
	_flasks.sip()
	_flasks.sip()

	assert_eq(_flasks.health_charges, _tuning.health_charges - 1)


func test_refilling_gives_back_every_charge() -> void:
	_flasks.sip()
	_run(_tuning.sip_duration + 2.0 * FRAME)

	_flasks.refill()

	assert_eq(_flasks.health_charges, _tuning.health_charges)


func test_resetting_ends_a_sip_with_the_charge_gone_and_nothing_restored() -> void:
	_health.take_damage(HEALTH_MAXIMUM * 0.5)
	var before := _health.current
	_flasks.sip()
	_flasks.reset()
	_run(_tuning.sip_duration + 2.0 * FRAME)

	assert_false(_flasks.sipping)
	assert_almost_eq(_health.current, before, TOLERANCE)
	assert_eq(_flasks.health_charges, _tuning.health_charges - 1)


func test_changed_is_emitted_when_the_charges_do() -> void:
	_flasks.sip()
	assert_eq(_changes, 1, "a sip")

	_flasks.refill()

	assert_eq(_changes, 2, "a refill")


# Lets this many seconds go by, a physics frame at a time.
func _run(seconds: float) -> void:
	var frames := int(round(seconds / FRAME))
	for i in frames:
		_flasks.advance(FRAME)
