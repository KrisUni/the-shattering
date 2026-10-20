extends GutTest
## Mana, tested directly through its public interface. The bar's size is given by each test when
## the bar is granted, and every expected number is plain arithmetic on the numbers the test sets.

const TOLERANCE := 0.0001
const MAXIMUM := 80.0

var _mana: Mana
var _changes := 0


func before_each() -> void:
	_mana = Mana.new()
	add_child_autofree(_mana)
	_changes = 0
	_mana.changed.connect(func() -> void: _changes += 1)


func test_there_is_no_bar_until_it_is_granted() -> void:
	assert_false(_mana.granted)
	assert_almost_eq(_mana.maximum, 0.0, TOLERANCE)
	assert_almost_eq(_mana.current, 0.0, TOLERANCE)


func test_granting_the_bar_gives_it_the_maximum_and_fills_it() -> void:
	_mana.grant(MAXIMUM)

	assert_true(_mana.granted)
	assert_almost_eq(_mana.maximum, MAXIMUM, TOLERANCE)
	assert_almost_eq(_mana.current, MAXIMUM, TOLERANCE)


func test_granting_the_bar_says_so() -> void:
	_mana.grant(MAXIMUM)

	assert_eq(_changes, 1)


func test_granting_again_changes_nothing() -> void:
	_mana.grant(MAXIMUM)
	_mana.spend(30.0)

	_mana.grant(MAXIMUM * 2.0)

	assert_almost_eq(_mana.maximum, MAXIMUM, TOLERANCE)
	assert_almost_eq(_mana.current, MAXIMUM - 30.0, TOLERANCE)


func test_spending_takes_that_amount_off() -> void:
	_mana.grant(MAXIMUM)

	_mana.spend(30.0)

	assert_almost_eq(_mana.current, MAXIMUM - 30.0, TOLERANCE)


func test_spending_beyond_what_is_left_stops_at_zero() -> void:
	_mana.grant(MAXIMUM)

	_mana.spend(MAXIMUM + 25.0)

	assert_almost_eq(_mana.current, 0.0, TOLERANCE)


func test_spending_says_so() -> void:
	_mana.grant(MAXIMUM)
	_changes = 0

	_mana.spend(30.0)

	assert_eq(_changes, 1)


func test_restoring_puts_that_amount_back() -> void:
	_mana.grant(MAXIMUM)
	_mana.spend(50.0)

	_mana.restore(20.0)

	assert_almost_eq(_mana.current, MAXIMUM - 30.0, TOLERANCE)


func test_restoring_stops_at_the_maximum() -> void:
	_mana.grant(MAXIMUM)
	_mana.spend(10.0)

	_mana.restore(50.0)

	assert_almost_eq(_mana.current, MAXIMUM, TOLERANCE)


func test_refilling_fills_it_from_wherever_it_was() -> void:
	_mana.grant(MAXIMUM)
	_mana.spend(MAXIMUM)

	_mana.refill()

	assert_almost_eq(_mana.current, MAXIMUM, TOLERANCE)


func test_refilling_without_the_bar_leaves_it_empty() -> void:
	_mana.refill()

	assert_almost_eq(_mana.current, 0.0, TOLERANCE)
	assert_eq(_changes, 0)


func test_it_does_not_refill_by_itself() -> void:
	_mana.grant(MAXIMUM)
	_mana.spend(40.0)

	await wait_physics_frames(60)

	assert_almost_eq(_mana.current, MAXIMUM - 40.0, TOLERANCE)
