extends GutTest
## The Mana Sip, seen through the real Almos driven by the sip_mana action with the shipped
## tuning: before his Mana bar it does nothing, and after it drinks a Mana Flask charge and restores
## a share of the Mana bar at the end, unless Health is lost before then. Expected numbers are
## worked from the shipped Flask tuning.

const AlmosInput := preload("res://test/helpers/almos_input.gd")

const FLASK_TUNING_PATH := "res://data/flasks.tres"
const TOLERANCE := 0.0001
const TAP_FRAMES := 3
# In seconds. Slack after a Sip's duration.
const SLACK := 0.2

var _almos_input: AlmosInput
var _flasks: FlaskTuning
var _almos: Almos


func before_each() -> void:
	await get_tree().process_frame
	_almos_input = AlmosInput.new(self)
	_flasks = load(FLASK_TUNING_PATH) as FlaskTuning
	_almos = _almos_input.spawn_almos()


func after_each() -> void:
	_almos_input.release_everything()


func test_the_mana_sip_restores_its_share_of_the_bar_at_the_end() -> void:
	_has_the_bar_with_full_flask()
	_almos.mana.spend(_almos.mana.maximum)

	await _tap(&"sip_mana")
	await wait_seconds(_flasks.sip_duration + SLACK)

	assert_almost_eq(_almos.mana.current, _almos.mana.maximum * _flasks.mana_restore_share, TOLERANCE)


func test_the_mana_sip_spends_one_mana_charge() -> void:
	_has_the_bar_with_full_flask()

	await _tap(&"sip_mana")

	assert_eq(_almos.flasks.mana_charges, _flasks.mana_charges - 1)


func test_the_mana_sip_leaves_the_health_flask_and_health_alone() -> void:
	_has_the_bar_with_full_flask()
	_almos.health.take_damage(40.0)
	var health := _almos.health.current

	await _tap(&"sip_mana")
	await wait_seconds(_flasks.sip_duration + SLACK)

	assert_eq(_almos.flasks.health_charges, _flasks.health_charges, "charges")
	assert_almost_eq(_almos.health.current, health, TOLERANCE, "Health")


func test_the_mana_sip_is_a_sip_that_slows_him() -> void:
	_has_the_bar_with_full_flask()

	await _tap(&"sip_mana")

	assert_true(_almos.sipping)


func test_the_mana_is_not_there_before_the_end_of_the_sip() -> void:
	_has_the_bar_with_full_flask()
	_almos.mana.spend(_almos.mana.maximum)

	await _tap(&"sip_mana")

	assert_almost_eq(_almos.mana.current, 0.0, TOLERANCE)


func test_a_loss_of_health_during_the_mana_sip_wastes_the_charge() -> void:
	_has_the_bar_with_full_flask()
	_almos.mana.spend(_almos.mana.maximum)

	await _tap(&"sip_mana")
	await wait_physics_frames(int(_flasks.sip_duration * Engine.physics_ticks_per_second / 2.0))
	_almos.health.take_damage(5.0)
	await wait_seconds(_flasks.sip_duration + SLACK)

	assert_eq(_almos.flasks.mana_charges, _flasks.mana_charges - 1, "the charge is spent")
	assert_almost_eq(_almos.mana.current, 0.0, TOLERANCE, "nothing restored")


func test_a_mana_sip_at_a_full_bar_spends_the_charge() -> void:
	_has_the_bar_with_full_flask()

	await _tap(&"sip_mana")
	await wait_seconds(_flasks.sip_duration + SLACK)

	assert_eq(_almos.flasks.mana_charges, _flasks.mana_charges - 1, "charge")
	assert_almost_eq(_almos.mana.current, _almos.mana.maximum, TOLERANCE, "Mana")


func test_with_no_mana_charge_left_a_mana_sip_does_nothing() -> void:
	_has_the_bar_with_full_flask()
	for i in _flasks.mana_charges:
		_almos.flasks.sip_mana()
		_almos.flasks.reset()
	_almos.mana.spend(_almos.mana.maximum)

	await _tap(&"sip_mana")
	await wait_seconds(_flasks.sip_duration + SLACK)

	assert_almost_eq(_almos.mana.current, 0.0, TOLERANCE)


func test_before_the_bar_a_mana_sip_still_does_nothing() -> void:
	await _tap(&"sip_mana")
	await wait_seconds(_flasks.sip_duration + SLACK)

	assert_false(_almos.sipping, "sipping")
	assert_eq(_almos.flasks.mana_charges, 0, "charges")


func test_a_health_sip_does_not_touch_the_mana_bar() -> void:
	_has_the_bar_with_full_flask()
	_almos.mana.spend(30.0)
	var mana := _almos.mana.current

	await _tap(&"sip_health")
	await wait_seconds(_flasks.sip_duration + SLACK)

	assert_almost_eq(_almos.mana.current, mana, TOLERANCE)


# Gives him the bar and fills the Mana Flask, as a rest after the grant does.
func _has_the_bar_with_full_flask() -> void:
	_almos.grant_mana_bar()
	_almos.flasks.refill()


func _tap(action: StringName) -> void:
	_almos_input.press_action(action)
	await wait_physics_frames(TAP_FRAMES)
	_almos_input.release_action(action)
