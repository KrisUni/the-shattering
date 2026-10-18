extends GutTest
## Hurtbox, tested through its public interface: hurt() is called here by hand with a Health
## of its own to take the damage, and the two hooks its owner can set are stood in for by
## small functions made here. The last test puts a real Hitbox over a Hurtbox, to see which
## point the Hitbox says its hit comes from. Every expected number comes from the damage a
## test gives the hit and the amount its hook lets through, never from how the code works
## them out.

# In Health points.
const TOLERANCE := 0.0001
# In Health points. More than any hit in these tests takes off.
const HEALTH_MAXIMUM := 100.0
# In Health points.
const HIT_DAMAGE := 30.0
# In Stagger points.
const HIT_STAGGER := 22.0
# In pixels. A strike this wide covers a Hurtbox from wherever the Hitbox is placed.
const HITBOX_RADIUS := 200.0
# In pixels.
const HURTBOX_RADIUS := 12.0
# Enough physics frames for a node put in the tree to be known to the physics server, and for
# a Hitbox switched on to have been through a frame.
const SETTLE_FRAMES := 2

var _health: Health
var _hurtbox: Hurtbox


func before_each() -> void:
	# Start between two physics frames, as real input arrives, so what the test spawns is first processed after the first sample
	# and what it presses is seen from the next frame. GUT alone would start it in the physics frame the last test ended in.
	await get_tree().process_frame
	_health = autofree(Health.new())
	_health.maximum = HEALTH_MAXIMUM
	_hurtbox = autofree(Hurtbox.new())
	_hurtbox.health = _health


func test_by_default_a_hit_lands_and_takes_all_its_damage_off_the_health() -> void:
	var outcome := _hurtbox.hurt(HIT_DAMAGE, Vector2.ZERO)

	assert_eq(outcome, Hurtbox.Outcome.LANDED, "a hit should land")
	assert_almost_eq(_health.current, HEALTH_MAXIMUM - HIT_DAMAGE, TOLERANCE)


func test_the_health_takes_the_damage_the_hook_lets_through_not_the_damage_of_the_hit() -> void:
	var let_through := HIT_DAMAGE / 3.0
	_hurtbox.damage_through = func(_damage: float, _from: Vector2) -> float: return let_through

	_hurtbox.hurt(HIT_DAMAGE, Vector2.ZERO)

	assert_almost_eq(_health.current, HEALTH_MAXIMUM - let_through, TOLERANCE)


func test_the_hook_is_asked_with_the_damage_of_the_hit_and_the_point_it_comes_from() -> void:
	var asked: Array[Dictionary] = []
	_hurtbox.damage_through = func(damage: float, from: Vector2) -> float:
		asked.append({"damage": damage, "from": from})
		return damage
	var from := Vector2(40.0, -25.0)

	_hurtbox.hurt(HIT_DAMAGE, from)

	assert_eq(asked.size(), 1, "the hook should be asked once")
	if asked.size() == 1:
		assert_almost_eq(asked[0].damage, HIT_DAMAGE, TOLERANCE)
		assert_almost_eq(asked[0].from, from, Vector2.ONE * TOLERANCE)


func test_the_hook_is_asked_again_for_every_hit_that_lands() -> void:
	var asked := [0]
	_hurtbox.damage_through = func(damage: float, _from: Vector2) -> float:
		asked[0] += 1
		return damage

	_hurtbox.hurt(HIT_DAMAGE, Vector2.ZERO)
	_hurtbox.hurt(HIT_DAMAGE, Vector2.ZERO)

	assert_eq(asked[0], 2)
	assert_almost_eq(_health.current, HEALTH_MAXIMUM - 2.0 * HIT_DAMAGE, TOLERANCE)


func test_a_hit_the_hook_lets_none_of_the_damage_through_still_lands() -> void:
	_hurtbox.damage_through = func(_damage: float, _from: Vector2) -> float: return 0.0

	var outcome := _hurtbox.hurt(HIT_DAMAGE, Vector2.ZERO)

	assert_eq(outcome, Hurtbox.Outcome.LANDED, "a hit that does no damage has still landed, so that its swing does not hit again")
	assert_almost_eq(_health.current, HEALTH_MAXIMUM, TOLERANCE)


func test_a_hit_on_an_untouchable_owner_does_not_land_and_the_damage_hook_is_not_asked() -> void:
	var asked := [0]
	_hurtbox.is_untouchable = func() -> bool: return true
	_hurtbox.damage_through = func(damage: float, _from: Vector2) -> float:
		asked[0] += 1
		return damage

	var outcome := _hurtbox.hurt(HIT_DAMAGE, Vector2.ZERO)

	assert_eq(outcome, Hurtbox.Outcome.MISSED, "a hit on someone untouchable should not land")
	assert_eq(asked[0], 0, "the hook is for hits that land")
	assert_almost_eq(_health.current, HEALTH_MAXIMUM, TOLERANCE)


func test_a_hit_the_owner_parries_is_negated_and_neither_asks_the_damage_hook_nor_lands() -> void:
	var asked := [0]
	_hurtbox.is_parried = func(_from: Vector2) -> bool: return true
	_hurtbox.damage_through = func(damage: float, _from: Vector2) -> float:
		asked[0] += 1
		return damage

	var outcome := _hurtbox.hurt(HIT_DAMAGE, Vector2.ZERO)

	assert_eq(outcome, Hurtbox.Outcome.PARRIED)
	assert_eq(asked[0], 0, "the damage hook is for hits that land")
	assert_almost_eq(_health.current, HEALTH_MAXIMUM, TOLERANCE)


func test_the_parry_hook_is_asked_once_with_the_point_the_hit_comes_from() -> void:
	var asked: Array[Vector2] = []
	_hurtbox.is_parried = func(from: Vector2) -> bool:
		asked.append(from)
		return false
	var from := Vector2(-15.0, 60.0)

	var outcome := _hurtbox.hurt(HIT_DAMAGE, from)

	assert_eq(asked, [from] as Array[Vector2], "the hook should be asked once")
	assert_eq(outcome, Hurtbox.Outcome.LANDED, "a hit the owner does not parry lands")


func test_a_hit_on_an_untouchable_owner_does_not_ask_the_parry_hook() -> void:
	var asked := [0]
	_hurtbox.is_untouchable = func() -> bool: return true
	_hurtbox.is_parried = func(_from: Vector2) -> bool:
		asked[0] += 1
		return true

	var outcome := _hurtbox.hurt(HIT_DAMAGE, Vector2.ZERO)

	assert_eq(outcome, Hurtbox.Outcome.MISSED)
	assert_eq(asked[0], 0)


func test_a_hitbox_emits_parried_once_for_a_parried_hit_and_does_not_hit_it_again_in_the_swing() -> void:
	var hitbox := await _hitbox_over_the_hurtbox()
	var asked := [0]
	var emitted: Array[Hurtbox] = []
	_hurtbox.is_parried = func(_from: Vector2) -> bool:
		asked[0] += 1
		return true
	hitbox.parried.connect(func(hurtbox: Hurtbox) -> void: emitted.append(hurtbox))

	hitbox.active = true
	await wait_physics_frames(SETTLE_FRAMES * 2)
	hitbox.active = false

	assert_eq(emitted, [_hurtbox] as Array[Hurtbox], "parried should be emitted once, with the Hurtbox")
	assert_eq(asked[0], 1, "a parried hit counts as hit, so the swing does not hit again")
	assert_almost_eq(_health.current, HEALTH_MAXIMUM, TOLERANCE)


func test_a_hitbox_does_not_emit_parried_for_a_hit_that_lands() -> void:
	var hitbox := await _hitbox_over_the_hurtbox()
	var emitted := [0]
	hitbox.parried.connect(func(_hurtbox: Hurtbox) -> void: emitted[0] += 1)

	hitbox.active = true
	await wait_physics_frames(SETTLE_FRAMES)
	hitbox.active = false

	assert_eq(emitted[0], 0)
	assert_almost_eq(_health.current, HEALTH_MAXIMUM - HIT_DAMAGE, TOLERANCE)


func test_a_hit_that_lands_announces_its_stagger_and_where_it_comes_from_once() -> void:
	var landed: Array[Dictionary] = []
	_hurtbox.landed.connect(func(stagger: float, from: Vector2, _critical: bool) -> void: landed.append({"stagger": stagger, "from": from}))
	var from := Vector2(12.0, -7.0)

	_hurtbox.hurt(HIT_DAMAGE, from, HIT_STAGGER)

	assert_eq(landed.size(), 1, "landed should be emitted once")
	if landed.size() == 1:
		assert_almost_eq(landed[0].stagger, HIT_STAGGER, TOLERANCE)
		assert_almost_eq(landed[0].from, from, Vector2.ONE * TOLERANCE)


func test_a_hit_with_no_stagger_given_builds_none() -> void:
	var landed: Array[float] = []
	_hurtbox.landed.connect(func(stagger: float, _from: Vector2, _critical: bool) -> void: landed.append(stagger))

	_hurtbox.hurt(HIT_DAMAGE, Vector2.ZERO)

	assert_eq(landed, [0.0] as Array[float])


func test_a_hit_the_hook_lets_none_of_the_damage_through_still_announces_landing() -> void:
	var landed := [0]
	_hurtbox.landed.connect(func(_stagger: float, _from: Vector2, _critical: bool) -> void: landed[0] += 1)
	_hurtbox.damage_through = func(_damage: float, _from: Vector2) -> float: return 0.0

	_hurtbox.hurt(HIT_DAMAGE, Vector2.ZERO, HIT_STAGGER)

	assert_eq(landed[0], 1)


func test_a_missed_or_parried_hit_does_not_announce_landing() -> void:
	var landed := [0]
	_hurtbox.landed.connect(func(_stagger: float, _from: Vector2, _critical: bool) -> void: landed[0] += 1)

	_hurtbox.is_untouchable = func() -> bool: return true
	_hurtbox.hurt(HIT_DAMAGE, Vector2.ZERO, HIT_STAGGER)
	_hurtbox.is_untouchable = func() -> bool: return false
	_hurtbox.is_parried = func(_from: Vector2) -> bool: return true
	_hurtbox.hurt(HIT_DAMAGE, Vector2.ZERO, HIT_STAGGER)

	assert_eq(landed[0], 0)


func test_a_hurtbox_carries_no_parry_stagger_unless_its_owner_sets_it() -> void:
	assert_almost_eq(_hurtbox.parry_stagger, 0.0, TOLERANCE)


func test_a_hitbox_hands_its_stagger_to_the_hurtbox_with_the_hit_once_in_the_swing() -> void:
	var hitbox := await _hitbox_over_the_hurtbox()
	hitbox.stagger = HIT_STAGGER
	var landed: Array[float] = []
	_hurtbox.landed.connect(func(stagger: float, _from: Vector2, _critical: bool) -> void: landed.append(stagger))

	hitbox.active = true
	await wait_physics_frames(SETTLE_FRAMES * 2)
	hitbox.active = false

	assert_eq(landed, [HIT_STAGGER] as Array[float], "the stagger should arrive once with the hit")


func test_a_hit_announces_that_it_is_not_a_critical_hit_unless_it_is_told_so() -> void:
	var criticals: Array[bool] = []
	_hurtbox.landed.connect(func(_stagger: float, _from: Vector2, critical: bool) -> void: criticals.append(critical))

	_hurtbox.hurt(HIT_DAMAGE, Vector2.ZERO, HIT_STAGGER)
	_hurtbox.hurt(HIT_DAMAGE, Vector2.ZERO, HIT_STAGGER, true)

	assert_eq(criticals, [false, true] as Array[bool], "whether each landed hit was a Critical hit")


func test_a_critical_hit_that_misses_or_is_parried_does_not_announce_landing() -> void:
	var landed := [0]
	_hurtbox.landed.connect(func(_stagger: float, _from: Vector2, _critical: bool) -> void: landed[0] += 1)

	_hurtbox.is_untouchable = func() -> bool: return true
	_hurtbox.hurt(HIT_DAMAGE, Vector2.ZERO, 0.0, true)
	_hurtbox.is_untouchable = func() -> bool: return false
	_hurtbox.is_parried = func(_from: Vector2) -> bool: return true
	_hurtbox.hurt(HIT_DAMAGE, Vector2.ZERO, 0.0, true)

	assert_eq(landed[0], 0)


func test_a_hitbox_is_not_a_critical_hit_unless_it_is_set_to_be() -> void:
	assert_false(Hitbox.new().critical)


func test_a_hitbox_tells_the_hurtbox_its_hit_is_a_critical_hit_once_in_the_swing() -> void:
	var hitbox := await _hitbox_over_the_hurtbox()
	hitbox.critical = true
	var criticals: Array[bool] = []
	_hurtbox.landed.connect(func(_stagger: float, _from: Vector2, critical: bool) -> void: criticals.append(critical))

	hitbox.active = true
	await wait_physics_frames(SETTLE_FRAMES * 2)
	hitbox.active = false

	assert_eq(criticals, [true] as Array[bool])


func test_a_hitbox_that_is_not_critical_tells_the_hurtbox_so() -> void:
	var hitbox := await _hitbox_over_the_hurtbox()
	var criticals: Array[bool] = []
	_hurtbox.landed.connect(func(_stagger: float, _from: Vector2, critical: bool) -> void: criticals.append(critical))

	hitbox.active = true
	await wait_physics_frames(SETTLE_FRAMES * 2)
	hitbox.active = false

	assert_eq(criticals, [false] as Array[bool])


func test_a_low_hit_on_an_airborne_owner_does_not_land_and_neither_other_hook_is_asked() -> void:
	var asked := [0]
	_hurtbox.is_airborne = func() -> bool: return true
	_hurtbox.is_parried = func(_from: Vector2) -> bool:
		asked[0] += 1
		return true
	_hurtbox.damage_through = func(damage: float, _from: Vector2) -> float:
		asked[0] += 1
		return damage

	var outcome := _hurtbox.hurt(HIT_DAMAGE, Vector2.ZERO, 0.0, false, true)

	assert_eq(outcome, Hurtbox.Outcome.MISSED, "a low hit should pass under someone in the air")
	assert_eq(asked[0], 0, "the parry and damage hooks are for hits that do not miss")
	assert_almost_eq(_health.current, HEALTH_MAXIMUM, TOLERANCE)


func test_a_low_hit_on_an_owner_on_the_ground_lands() -> void:
	_hurtbox.is_airborne = func() -> bool: return false

	var outcome := _hurtbox.hurt(HIT_DAMAGE, Vector2.ZERO, 0.0, false, true)

	assert_eq(outcome, Hurtbox.Outcome.LANDED)
	assert_almost_eq(_health.current, HEALTH_MAXIMUM - HIT_DAMAGE, TOLERANCE)


func test_a_hit_that_is_not_low_lands_on_an_airborne_owner_and_does_not_ask_whether_he_is_airborne() -> void:
	var asked := [0]
	_hurtbox.is_airborne = func() -> bool:
		asked[0] += 1
		return true

	var outcome := _hurtbox.hurt(HIT_DAMAGE, Vector2.ZERO)

	assert_eq(outcome, Hurtbox.Outcome.LANDED, "only low hits pass under someone in the air")
	assert_eq(asked[0], 0, "airborne is asked only for low hits")
	assert_almost_eq(_health.current, HEALTH_MAXIMUM - HIT_DAMAGE, TOLERANCE)


func test_by_default_the_owner_is_not_airborne_so_a_low_hit_lands() -> void:
	var outcome := _hurtbox.hurt(HIT_DAMAGE, Vector2.ZERO, 0.0, false, true)

	assert_eq(outcome, Hurtbox.Outcome.LANDED)


func test_a_low_hit_on_an_untouchable_owner_does_not_ask_whether_he_is_airborne() -> void:
	var asked := [0]
	_hurtbox.is_untouchable = func() -> bool: return true
	_hurtbox.is_airborne = func() -> bool:
		asked[0] += 1
		return true

	var outcome := _hurtbox.hurt(HIT_DAMAGE, Vector2.ZERO, 0.0, false, true)

	assert_eq(outcome, Hurtbox.Outcome.MISSED)
	assert_eq(asked[0], 0, "untouchable is settled first")


func test_a_low_hit_the_owner_parries_while_on_the_ground_is_negated() -> void:
	_hurtbox.is_airborne = func() -> bool: return false
	_hurtbox.is_parried = func(_from: Vector2) -> bool: return true

	var outcome := _hurtbox.hurt(HIT_DAMAGE, Vector2.ZERO, 0.0, false, true)

	assert_eq(outcome, Hurtbox.Outcome.PARRIED, "a low hit can be parried like any other")
	assert_almost_eq(_health.current, HEALTH_MAXIMUM, TOLERANCE)


func test_a_low_hit_on_the_ground_is_reduced_by_the_damage_hook() -> void:
	_hurtbox.damage_through = func(damage: float, _from: Vector2) -> float: return damage / 2.0

	_hurtbox.hurt(HIT_DAMAGE, Vector2.ZERO, 0.0, false, true)

	assert_almost_eq(_health.current, HEALTH_MAXIMUM - HIT_DAMAGE / 2.0, TOLERANCE, "a low hit can be blocked like any other")


func test_a_hitbox_is_not_low_unless_it_is_set_to_be() -> void:
	assert_false(Hitbox.new().low)


func test_a_low_hitbox_does_not_hit_an_airborne_owner_and_hits_him_once_he_is_on_the_ground_in_the_same_swing() -> void:
	var hitbox := await _hitbox_over_the_hurtbox()
	hitbox.low = true
	var airborne := [true]
	_hurtbox.is_airborne = func() -> bool: return airborne[0]

	hitbox.active = true
	await wait_physics_frames(SETTLE_FRAMES)
	var health_in_the_air := _health.current
	airborne[0] = false
	await wait_physics_frames(SETTLE_FRAMES)
	hitbox.active = false

	assert_almost_eq(health_in_the_air, HEALTH_MAXIMUM, TOLERANCE, "nothing should land while he is in the air")
	assert_almost_eq(_health.current, HEALTH_MAXIMUM - HIT_DAMAGE, TOLERANCE, "the swing that is still on should catch him once he lands")


func test_a_hitbox_that_is_not_low_hits_an_airborne_owner() -> void:
	var hitbox := await _hitbox_over_the_hurtbox()
	_hurtbox.is_airborne = func() -> bool: return true

	hitbox.active = true
	await wait_physics_frames(SETTLE_FRAMES)
	hitbox.active = false

	assert_almost_eq(_health.current, HEALTH_MAXIMUM - HIT_DAMAGE, TOLERANCE)


# A Hitbox, switched off, covering the Hurtbox, which is in the tree.
func _hitbox_over_the_hurtbox() -> Hitbox:
	_hurtbox.collision_layer = 1
	_hurtbox.collision_mask = 0
	_hurtbox.monitoring = false
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = HURTBOX_RADIUS
	shape.shape = circle
	_hurtbox.add_child(shape)
	add_child(_hurtbox)
	var hitbox := Hitbox.new()
	hitbox.damage = HIT_DAMAGE
	hitbox.collision_mask = 1
	var strike := CollisionShape2D.new()
	var wide := CircleShape2D.new()
	wide.radius = HITBOX_RADIUS
	strike.shape = wide
	hitbox.add_child(strike)
	add_child_autofree(hitbox)
	await wait_physics_frames(SETTLE_FRAMES)
	return hitbox


func test_a_hitbox_says_its_hit_comes_from_where_it_sits_in_the_world() -> void:
	var from_hook: Array[Vector2] = []
	_hurtbox.collision_layer = 1
	_hurtbox.collision_mask = 0
	_hurtbox.monitoring = false
	_hurtbox.damage_through = func(damage: float, from: Vector2) -> float:
		from_hook.append(from)
		return damage
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = HURTBOX_RADIUS
	shape.shape = circle
	_hurtbox.add_child(shape)
	add_child(_hurtbox)
	# Under a parent that is not at the origin, so that where it sits in the world is not
	# where it sits under the parent.
	var holder := Node2D.new()
	holder.position = Vector2(100.0, 0.0)
	var hitbox := Hitbox.new()
	hitbox.damage = HIT_DAMAGE
	hitbox.collision_mask = 1
	hitbox.position = Vector2(30.0, 40.0)
	var strike := CollisionShape2D.new()
	var wide := CircleShape2D.new()
	wide.radius = HITBOX_RADIUS
	strike.shape = wide
	hitbox.add_child(strike)
	holder.add_child(hitbox)
	add_child_autofree(holder)
	await wait_physics_frames(SETTLE_FRAMES)

	hitbox.active = true
	await wait_physics_frames(SETTLE_FRAMES)
	hitbox.active = false

	assert_eq(from_hook.size(), 1, "the hit should have landed once")
	if from_hook.size() == 1:
		assert_almost_eq(from_hook[0], Vector2(130.0, 40.0), Vector2.ONE * TOLERANCE)
