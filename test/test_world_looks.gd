extends GutTest
## How the world's pieces are drawn, seen through their scenes: each hangs its drawing on a Look,
## so that art can later be added under the Look with no change to the code or the tests. None of
## them has a node named Placeholder any more.

const PIECES := [
	"res://scenes/world/flask_upgrade.tscn",
	"res://scenes/world/time_keeper_mark.tscn",
	"res://scenes/world/hiding_spot.tscn",
	"res://scenes/world/fungus.tscn",
	"res://scenes/world/gap.tscn",
	"res://scenes/world/ledge.tscn",
	"res://scenes/world/path_blocker.tscn",
	"res://scenes/world/main_entrance.tscn",
	"res://scenes/world/movable.tscn",
	"res://scenes/world/placeholder_door.tscn",
]

# [scene, the node the Doorway or piece sits at]
const DOORWAYS := [
	["res://scenes/areas/upper_tree_placeholder.tscn", "Doorways/ToDungeons"],
	["res://scenes/areas/test_open_map.tscn", "Doorways/ToMap2"],
	["res://scenes/areas/test_open_map.tscn", "Doorways/ToBuilding"],
	["res://scenes/areas/test_open_map_2.tscn", "Doorways/ToMap1"],
	["res://scenes/areas/test_building.tscn", "RoomA/Doorways/ToMap1"],
	["res://scenes/areas/dungeons/lobby.tscn", "Doorways/ToUpperTree"],
	["res://scenes/areas/dungeons/cell_3.tscn", "Roots"],
	["res://scenes/areas/dungeons/corridor_1.tscn", "BackEntranceSeal"],
]


func test_every_world_piece_has_a_look_and_no_placeholder() -> void:
	for path in PIECES:
		var piece: Node = autofree((load(path) as PackedScene).instantiate())

		assert_true(piece.get_node_or_null("Look") is Node2D, "%s should have a Look" % path)
		assert_null(piece.get_node_or_null("Placeholder"), "%s should have no Placeholder" % path)


func test_every_doorway_and_placed_piece_has_a_look_and_no_placeholder() -> void:
	for entry in DOORWAYS:
		var area: Node = autofree((load(entry[0]) as PackedScene).instantiate())
		var node := area.get_node_or_null(entry[1] as String)

		assert_not_null(node, "%s should have %s" % entry)
		if node != null:
			assert_true(node.get_node_or_null("Look") is Node2D, "%s should have a Look" % entry[1])
			assert_null(node.get_node_or_null("Placeholder"), "%s should have no Placeholder" % entry[1])


func test_the_flammable_pieces_burn_out_their_look() -> void:
	for path in ["fungus", "hiding_spot", "path_blocker"]:
		var piece: Node = autofree(load("res://scenes/world/%s.tscn" % path).instantiate())

		assert_eq(piece.get_node("Flammable").look, piece.get_node("Look"), "%s's look" % path)


func test_a_footprint_fits_its_shape_to_its_size() -> void:
	var gap: Footprint = add_child_autofree(load("res://scenes/world/gap.tscn").instantiate())
	gap.size = Vector2(96.0, 48.0)

	var corners := (gap.get_node("Look/Shape") as Polygon2D).polygon
	assert_eq(corners, PackedVector2Array([
		Vector2(-48, -24), Vector2(48, -24), Vector2(48, 24), Vector2(-48, 24),
	]))


func test_the_roots_and_the_seal_keep_their_colours() -> void:
	var cell: Node = autofree(load("res://scenes/areas/dungeons/cell_3.tscn").instantiate())
	var corridor: Node = autofree(load("res://scenes/areas/dungeons/corridor_1.tscn").instantiate())

	assert_eq((cell.get_node("Roots/Look/Shape") as Polygon2D).color, Color(0.22, 0.3, 0.12, 1))
	assert_eq((corridor.get_node("BackEntranceSeal/Look/Shape") as Polygon2D).color, Color(0.38, 0.32, 0.36, 1))


# [scene, the polygons that hang under its Look]
const DRAWN_PIECES := [
	["res://scenes/world/torch.tscn", ["Bracket"]],
	["res://scenes/world/checkpoint.tscn", ["Glow", "Trunk", "LeafLeft", "LeafRight", "LeafTop"]],
	["res://scenes/world/armour_pickup.tscn", ["Plate"]],
	["res://scenes/world/weapon_pickup.tscn", ["Bar"]],
	["res://scenes/world/jailers_key.tscn", ["Bar"]],
	["res://scenes/world/remains.tscn", ["Glow", "Marker"]],
	["res://scenes/almos/fireball.tscn", ["Shape"]],
]


func test_torches_checkpoints_pickups_and_the_fireball_hang_their_polygons_on_a_look() -> void:
	for entry in DRAWN_PIECES:
		var piece: Node = autofree((load(entry[0] as String) as PackedScene).instantiate())
		var look := piece.get_node_or_null("Look")

		assert_true(look is Node2D, "%s should have a Look" % entry[0])
		assert_null(piece.get_node_or_null("Placeholder"), "%s should have no Placeholder" % entry[0])
		if look != null:
			for polygon_name in entry[1]:
				assert_true(look.get_node_or_null(polygon_name as String) is Polygon2D,
					"%s's Look should hold %s" % [entry[0], polygon_name])


func test_a_torch_keeps_its_flame_beside_its_look() -> void:
	var torch: Node = autofree(load("res://scenes/world/torch.tscn").instantiate())

	assert_true(torch.get_node_or_null("Flame") is Polygon2D, "the Flame stays a direct child")
