class_name Footprint
extends StaticBody2D
## The footprint of a gap or a ledge: a rectangle, centred on this node and sized by `size`.
## Its edge is drawn as solid lines on the footprint's edge layer (gap_edge or ledge_edge),
## which block whoever the layer is in the mask of: lines, so that a body is blocked from the
## side it is on, whether it stands outside the footprint or inside. Its inside is an area on
## the footprint's area layer (gap_area or ledge_area), which Almos asks when a Jump comes
## down. The layers are set in the scene that inherits this, and the look is a Look node holding a placeholder shape.

## The width and height of the footprint, in pixels.
@export var size := Vector2(64.0, 64.0):
	set(value):
		size = value
		if is_node_ready():
			_fit()

@onready var _edge: CollisionShape2D = $Edge
@onready var _inside: CollisionShape2D = $Inside/CollisionShape2D
@onready var _shape: Polygon2D = $Look/Shape


func _ready() -> void:
	_fit()


# Fits the edge, the inside and the look's shape to the size.
func _fit() -> void:
	var half := size / 2.0
	var corners := PackedVector2Array([
		Vector2(-half.x, -half.y), Vector2(half.x, -half.y),
		Vector2(half.x, half.y), Vector2(-half.x, half.y),
	])
	var edge := ConcavePolygonShape2D.new()
	edge.segments = PackedVector2Array([
		corners[0], corners[1], corners[1], corners[2],
		corners[2], corners[3], corners[3], corners[0],
	])
	_edge.shape = edge
	var inside := RectangleShape2D.new()
	inside.size = size
	_inside.shape = inside
	_shape.polygon = corners
