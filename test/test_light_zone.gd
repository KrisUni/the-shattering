extends GutTest
## The gameplay light a LightZone gives: 1 outside every zone, the zone's own value inside it,
## and the darkest of the zones a point is in. Expected numbers are worked by hand.

const LIGHT_ZONE_PATH := "res://scenes/world/light_zone.tscn"
const TORCH_PATH := "res://scenes/world/torch.tscn"
const TOLERANCE := 0.0001
# In pixels. How far inside or outside a torch's radius a point is put to try it.
const EDGE_MARGIN := 1.0


func before_each() -> void:
	await get_tree().process_frame


func test_the_light_is_full_where_there_is_no_zone() -> void:
	assert_almost_eq(LightZone.light_at([], Vector2(30.0, 40.0)), 1.0, TOLERANCE)


func test_the_light_is_full_outside_a_zone() -> void:
	var zone := _zone(Vector2(100.0, 100.0), Vector2(60.0, 40.0), 0.25)

	assert_almost_eq(LightZone.light_at([zone], Vector2(100.0, 130.0)), 1.0, TOLERANCE, "below the zone")
	assert_almost_eq(LightZone.light_at([zone], Vector2(140.0, 100.0)), 1.0, TOLERANCE, "right of the zone")


func test_the_light_inside_a_zone_is_its_value() -> void:
	var zone := _zone(Vector2(100.0, 100.0), Vector2(60.0, 40.0), 0.25)

	assert_almost_eq(LightZone.light_at([zone], Vector2(100.0, 100.0)), 0.25, TOLERANCE, "at the centre")
	assert_almost_eq(LightZone.light_at([zone], Vector2(129.0, 119.0)), 0.25, TOLERANCE, "near a corner")


func test_where_zones_overlap_the_darkest_wins_whichever_comes_first() -> void:
	var dim := _zone(Vector2(0.0, 0.0), Vector2(100.0, 100.0), 0.6)
	var dark := _zone(Vector2(20.0, 0.0), Vector2(100.0, 100.0), 0.1)

	assert_almost_eq(LightZone.light_at([dim, dark], Vector2(10.0, 0.0)), 0.1, TOLERANCE, "dim first")
	assert_almost_eq(LightZone.light_at([dark, dim], Vector2(10.0, 0.0)), 0.1, TOLERANCE, "dark first")
	assert_almost_eq(LightZone.light_at([dim, dark], Vector2(-40.0, 0.0)), 0.6, TOLERANCE, "only in the dim one")


func test_a_zone_in_the_tree_is_found_through_the_group_enemies_read() -> void:
	var zone := _zone(Vector2.ZERO, Vector2(50.0, 50.0), 0.0)

	assert_true(zone in get_tree().get_nodes_in_group("light_zones"))


# A zone in the test's tree, put in place before it enters it. The test frees it.
func _zone(at: Vector2, size: Vector2, light: float) -> LightZone:
	var zone := (load(LIGHT_ZONE_PATH) as PackedScene).instantiate() as LightZone
	zone.position = at
	zone.size = size
	zone.light = light
	add_child_autofree(zone)
	return zone


func test_a_lit_torch_lifts_the_light_within_its_radius_over_a_dark_zone() -> void:
	var zone := _zone(Vector2(100.0, 100.0), Vector2(400.0, 400.0), 0.0)
	var torch := _torch(Vector2(100.0, 100.0))

	assert_almost_eq(LightZone.light_at([zone], Vector2(100.0, 100.0), [torch]), torch.light, TOLERANCE, "at the torch")
	assert_almost_eq(LightZone.light_at([zone], Vector2(100.0 + torch.radius, 100.0), [torch]), torch.light, TOLERANCE, "at the radius edge")


func test_beyond_the_radius_of_a_lit_torch_the_zone_still_rules() -> void:
	var zone := _zone(Vector2(100.0, 100.0), Vector2(400.0, 400.0), 0.0)
	var torch := _torch(Vector2(100.0, 100.0))

	assert_almost_eq(LightZone.light_at([zone], Vector2(100.0 + torch.radius + EDGE_MARGIN, 100.0), [torch]), 0.0, TOLERANCE)


func test_an_unlit_torch_leaves_the_zone_dark() -> void:
	var zone := _zone(Vector2(100.0, 100.0), Vector2(400.0, 400.0), 0.0)
	var torch := _torch(Vector2(100.0, 100.0))
	torch.draw()

	assert_almost_eq(LightZone.light_at([zone], Vector2(100.0, 100.0), [torch]), 0.0, TOLERANCE)


func test_a_torch_dimmer_than_the_zone_does_not_darken_it() -> void:
	var torch := _torch(Vector2(100.0, 100.0))
	var zone := _zone(Vector2(100.0, 100.0), Vector2(400.0, 400.0), minf(torch.light + 0.1, 1.0))

	assert_almost_eq(LightZone.light_at([zone], Vector2(100.0, 100.0), [torch]), maxf(torch.light, zone.light), TOLERANCE)


func test_a_lit_torch_outside_every_zone_leaves_the_light_full() -> void:
	var torch := _torch(Vector2(100.0, 100.0))

	assert_almost_eq(LightZone.light_at([], Vector2(100.0, 100.0), [torch]), 1.0, TOLERANCE)


func test_a_torch_lifts_only_the_points_it_reaches_in_a_zone() -> void:
	var zone := _zone(Vector2(100.0, 100.0), Vector2(400.0, 400.0), 0.0)
	var torch := _torch(Vector2(0.0, 100.0))

	assert_almost_eq(LightZone.light_at([zone], Vector2(0.0, 100.0), [torch]), torch.light, TOLERANCE, "near the torch")
	assert_almost_eq(LightZone.light_at([zone], Vector2(200.0, 100.0), [torch]), 0.0, TOLERANCE, "far from it, in the zone")


# A torch in the test's tree at this place. The test frees it.
func _torch(at: Vector2) -> Torch:
	var torch := (load(TORCH_PATH) as PackedScene).instantiate() as Torch
	torch.position = at
	add_child_autofree(torch)
	return torch
