extends GutTest
## The Store cupboard, the small Room through the door at the top of Corridor 2's first flight of
## stairs: smaller inside than a cell, a cramped store of barrels and sacks, one barrel a Hiding
## spot, and a greatsword left lying among them, a Weapon Almos takes up with a tap of Interact.

const CUPBOARD_PATH := "res://scenes/areas/dungeons/store_cupboard.tscn"
const CELL_PATH := "res://scenes/areas/dungeons/cell_3.tscn"
const GREATSWORD_PATH := "res://data/greatsword.tres"

var _room: Node2D


func before_each() -> void:
	_room = (load(CUPBOARD_PATH) as PackedScene).instantiate() as Node2D
	add_child_autofree(_room)


# The floor inside the small room: the inner walls' box, less the walls themselves.
func _inside(room: Node2D, left: String, right: String, top: String, bottom: String) -> Rect2:
	var rect := func(name: String) -> Rect2:
		var wall := room.get_node("Walls/" + name) as Node2D
		var size := ((wall.get_node("CollisionShape2D") as CollisionShape2D).shape as RectangleShape2D).size
		return Rect2(wall.position - size / 2.0, size)
	var x0: float = rect.call(left).end.x
	var x1: float = rect.call(right).position.x
	var y0: float = rect.call(top).end.y
	var y1: float = rect.call(bottom).position.y
	return Rect2(x0, y0, x1 - x0, y1 - y0)


func test_it_is_smaller_inside_than_a_cell() -> void:
	var cell := (load(CELL_PATH) as PackedScene).instantiate() as Node2D
	add_child_autofree(cell)
	var cupboard := _inside(_room, "CellWallLeft", "CellWallRightNorth", "CellWallTop", "CellWallBottom")
	var inside_cell := _inside(cell, "CellWallLeft", "CellWallRight", "CellWallTop", "WallBottom1")
	assert_lt(cupboard.size.x, inside_cell.size.x, "narrower than Cell 3")
	assert_lt(cupboard.size.y, inside_cell.size.y, "and shorter")
	var door := _room.get_node("Exits/door") as Node2D
	assert_true(cupboard.grow(32.0).has_point(door.position), "its door is in its own wall")
	assert_gt(door.position.x, cupboard.end.x - 1.0, "on its east side, the way Corridor 2 lies")


func test_it_holds_a_greatsword() -> void:
	var pickups := _room.find_children("*", "WeaponPickup", true, false)
	assert_eq(pickups.size(), 1, "one Weapon lies there")
	var greatsword := pickups[0] as WeaponPickup
	assert_eq(greatsword.weapon, load(GREATSWORD_PATH), "the greatsword")
	assert_eq(greatsword.id, &"dungeons/store_cupboard/greatsword", "with an id of its own, so taking it is kept")
	assert_not_null(greatsword.art, "drawn lying on the floor")
	var inside := _inside(_room, "CellWallLeft", "CellWallRightNorth", "CellWallTop", "CellWallBottom")
	assert_true(inside.has_point(greatsword.position), "inside the cupboard")


func test_a_barrel_there_is_a_hiding_spot() -> void:
	var spots := _room.get_node("Furniture").get_children().filter(func(node: Node) -> bool: return node is HidingSpot)
	assert_gt(spots.size(), 0, "a barrel there can be hidden in")
