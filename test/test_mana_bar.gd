extends GutTest
## The HUD Mana bar: hidden until the Mana it is pointed at is granted, then shows its amount and
## follows it.

const BAR_PATH := "res://scenes/hud/mana_bar.gd"
const TOLERANCE := 0.0001
const MAXIMUM := 80.0

var _mana: Mana
var _bar: ProgressBar


func before_each() -> void:
	_mana = Mana.new()
	add_child_autofree(_mana)
	_bar = ProgressBar.new()
	_bar.set_script(load(BAR_PATH))
	_bar.mana = _mana
	add_child_autofree(_bar)


func test_it_is_hidden_before_the_bar_is_granted() -> void:
	assert_false(_bar.visible)


func test_it_appears_when_the_bar_is_granted() -> void:
	_mana.grant(MAXIMUM)

	assert_true(_bar.visible)


func test_it_shows_the_maximum_and_the_amount() -> void:
	_mana.grant(MAXIMUM)

	assert_almost_eq(_bar.max_value, MAXIMUM, TOLERANCE, "maximum")
	assert_almost_eq(_bar.value, MAXIMUM, TOLERANCE, "value")


func test_it_follows_the_amount() -> void:
	_mana.grant(MAXIMUM)

	_mana.spend(30.0)

	assert_almost_eq(_bar.value, MAXIMUM - 30.0, TOLERANCE)
