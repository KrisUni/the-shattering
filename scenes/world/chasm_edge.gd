@tool
extends Node2D
## The edge of a chasm made of Drops: where the floor gives way, a crumbling earth lip, then the
## face of the earth falling away below it, fading through the root's dark into the deep root the
## chasm is filled with, with a few root ends hanging into it. Along a side where the floor runs
## beside the chasm, a thin rim fades into it. Drawn in code on the art pixel grid, from the Drops'
## footprints on the 32-unit tile grid, so it follows any shape they make. Only a look.

## The node whose children are the Drops (Footprints) of the chasm.
@export var drops_path := NodePath("../Drops")

const TILE := 32.0
const PIXEL := 2.0
# The lip and the face, top to bottom, one art pixel each: the floor's rim catching the light, the
# earth face, and the dark it falls into.
const FACE := [
	Color("a5938a"),
	Color("6f6066"),
	Color("5c4f57"),
	Color("4a3f4a"),
	Color("3a3245"),
	Color("2b2639"),
	Color("1b1a2b"),
	Color("14131f"),
]
const RIM := [Color("6f6066"), Color("4a3f4a"), Color("2b2639"), Color("1b1a2b")]
const ROOT := Color("343459")
const ROOT_TIP := Color("494d7e")

var _cells := {}


func _ready() -> void:
	z_index = -1
	_collect()
	queue_redraw()


## Whether this tile (in the Room's tile grid) is in the chasm.
func in_chasm(cell: Vector2i) -> bool:
	return _cells.has(cell)


func _collect() -> void:
	_cells.clear()
	var drops := get_node_or_null(drops_path)
	if drops == null:
		return
	for drop in drops.get_children():
		var footprint := drop as Footprint
		if footprint == null:
			continue
		var rect := Rect2(footprint.position - footprint.size / 2.0, footprint.size)
		for x in range(roundi(rect.position.x / TILE), roundi(rect.end.x / TILE)):
			for y in range(roundi(rect.position.y / TILE), ceili(rect.end.y / TILE)):
				_cells[Vector2i(x, y)] = true


func _draw() -> void:
	var px := int(TILE / PIXEL)
	for cell: Vector2i in _cells:
		var origin := Vector2(cell) * TILE
		var floor_above := not in_chasm(cell + Vector2i.UP)
		var floor_left := not in_chasm(cell + Vector2i.LEFT) and cell.x > 0
		var floor_right := not in_chasm(cell + Vector2i.RIGHT) and cell.x < 35
		if floor_left:
			_rim(origin, 1, px)
		if floor_right:
			_rim(origin + Vector2(TILE - PIXEL, 0.0), -1, px)
		if floor_above:
			_face(cell, origin, px)


# The face below a floor edge: its rows, with the lip's edge broken here and there, and a root end or
# two hanging from it.
func _face(cell: Vector2i, origin: Vector2, px: int) -> void:
	for column in px:
		var seed := _hash(cell.x * 16 + column, cell.y)
		# The lip crumbles: some columns lose its top pixel, some reach a pixel further.
		var start := 1 if seed % 7 == 0 else 0
		var extra := 1 if seed % 5 == 0 else 0
		for row in range(start, FACE.size() + extra):
			var colour: Color = FACE[mini(row, FACE.size() - 1)]
			# The bottom rows dither into the deep root.
			if row >= FACE.size() - 2 and (column + row) % 2 == 1:
				continue
			_pixel(origin + Vector2(column, row) * PIXEL, colour)
		# A root end hangs down now and then.
		if seed % 11 == 3:
			var length := 3 + seed % 5
			for row in range(FACE.size() - 2, FACE.size() - 2 + length):
				_pixel(origin + Vector2(column, row) * PIXEL, ROOT_TIP if row == FACE.size() - 3 + length else ROOT)


# A thin rim down a side where the floor runs beside the chasm, fading inward.
func _rim(origin: Vector2, inward: int, px: int) -> void:
	for row in px:
		for step in RIM.size():
			if step >= 2 and (row + step) % 2 == 1:
				continue
			_pixel(origin + Vector2(step * inward, row) * PIXEL, RIM[step])


func _hash(a: int, b: int) -> int:
	return absi((a * 73856093) ^ (b * 19349663)) % 1009


func _pixel(at: Vector2, colour: Color) -> void:
	draw_rect(Rect2(at, Vector2(PIXEL, PIXEL)), colour)
