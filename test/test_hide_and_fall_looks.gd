extends GutTest
## How hiding and a fall down a Drop look (looks only; what they do is tested elsewhere):
## - getting into a barrel, a copy of Almos is seen hopping in over its rim and sinking below it, the
##   barrel squashes and wobbles back, and the copy is gone;
## - getting out, he springs out of the spot and ends on his feet at full size;
## - a fall down a Drop carries his look down the screen, faster and faster, smaller and smaller.

const AlmosInput := preload("res://test/helpers/almos_input.gd")
const BARREL_SCENE := preload("res://scenes/world/barrel.tscn")
const TAP_FRAMES := 2

var _almos_input: AlmosInput


func before_each() -> void:
	_almos_input = AlmosInput.new(self)


func after_each() -> void:
	_almos_input.release_everything()


# A tap of the button, and the frames it takes to be read (a tap is read when it is let go).
func _tap(action: StringName) -> void:
	_almos_input.press_action(action)
	await wait_physics_frames(TAP_FRAMES)
	_almos_input.release_action(action)
	await wait_physics_frames(2)


func _barrel_by(almos: Node2D) -> HidingSpot:
	var barrel := BARREL_SCENE.instantiate() as HidingSpot
	barrel.position = almos.global_position + Vector2(0, -24)
	almos.get_parent().add_child(barrel)
	autofree(barrel)
	return barrel


func _hops(barrel: HidingSpot) -> Array:
	return barrel.get_parent().get_children().filter(func(node: Node) -> bool: return node is HideHop)


func test_he_is_seen_hopping_into_a_barrel_over_its_rim() -> void:
	var almos = _almos_input.spawn_almos()
	var barrel := _barrel_by(almos)
	assert_true(barrel.open_top, "a barrel is open at the top")
	await wait_physics_frames(2)
	await _tap(&"interact")
	assert_true(almos.hiding, "control: he is in it at once")
	assert_eq(_hops(barrel).size(), 1, "a copy of him hops in")
	var hop := _hops(barrel)[0] as HideHop
	var highest := hop.global_position.y
	for i in 30:
		await wait_process_frames(1)
		if not is_instance_valid(hop):
			break
		highest = minf(highest, hop.global_position.y)
	assert_lt(highest, barrel.global_position.y - barrel.rim_height(), "up in an arc, over the rim")
	await wait_seconds(0.3)
	assert_eq(_hops(barrel).size(), 0, "and then the copy is gone")
	assert_almost_eq((barrel.get_node("Look") as Node2D).scale, Vector2.ONE, Vector2(0.01, 0.01), "the barrel wobbles back")


func test_he_springs_out_and_ends_on_his_feet() -> void:
	var almos = _almos_input.spawn_almos()
	var barrel := _barrel_by(almos)
	await wait_physics_frames(2)
	await _tap(&"interact")
	await wait_seconds(0.6)
	await _tap(&"interact")
	assert_false(almos.hiding, "control: he is out")
	var look := almos.get_node("Look") as Node2D
	assert_ne(look.position, Vector2.ZERO, "springing out, his look is up at the rim")
	await wait_seconds(0.5)
	assert_eq(look.position, Vector2.ZERO, "on his feet")
	assert_almost_eq(look.scale, Vector2.ONE, Vector2(0.001, 0.001), "at full size")


func test_a_fall_carries_him_down_the_screen_smaller_and_smaller() -> void:
	var almos = _almos_input.spawn_almos()
	var drop := (load("res://scenes/world/drop.tscn") as PackedScene).instantiate() as Footprint
	drop.size = Vector2(256, 256)
	drop.position = almos.global_position + Vector2(0, 160)
	almos.get_parent().add_child(drop)
	autofree(drop)
	await wait_physics_frames(2)
	_almos_input.press_action(&"move_down")
	for i in 90:
		await wait_physics_frames(1)
		if almos.dead:
			break
	_almos_input.release_action(&"move_down")
	assert_true(almos.dead, "control: he walked off the edge")
	var look := almos.get_node("Look") as Node2D
	var samples: Array[Vector2] = []
	var sizes: Array[float] = []
	for i in 4:
		await wait_seconds(0.2)
		samples.append(look.position)
		sizes.append(look.scale.x)
	for i in range(1, samples.size()):
		assert_gte(samples[i].y, samples[i - 1].y, "he keeps going down")
		assert_lte(sizes[i], sizes[i - 1], "and gets smaller")
	assert_gt(samples[2].y - samples[1].y, samples[1].y - samples[0].y, "faster and faster")
	assert_lt(sizes[-1], 0.5, "until he is small")
