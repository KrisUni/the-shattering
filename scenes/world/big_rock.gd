class_name BigRock
extends StaticBody2D
## A big rock: a solid body on the walls layer that blocks Almos and the enemies. It is far too heavy
## to move: a Pull or a Shove only makes it budge, leaning toward him or away and rocking back. But a
## Shove with a wall right behind it (within break_reach of its far side, the way he shoves) crushes
## it against the wall: it breaks into pieces_min to pieces_max small rocks scattered where it stood,
## which Pull lifts two at a time and Shove throws. It is in the group "budgeables", where Almos's
## Spell looks for things to budge. A Room made again has it whole.

const SMALL_ROCK_SCENE := preload("res://scenes/world/small_rock.tscn")
const BREAK_SCRIPT := preload("res://scenes/world/prop_break.gd")
const SMALL_ROCK_ART := [
	preload("res://assets/dungeons/rocks/rock_small_0.png"),
	preload("res://assets/dungeons/rocks/rock_small_1.png"),
	preload("res://assets/dungeons/rocks/rock_small_2.png"),
]
const WALLS := 1
# The inside of a Gap or a Drop: no piece is left there.
const GAP_AREA := 1 << 5
## How a budge looks: frames, and how far it leans. A look.
const BUDGE_FRAMES := 16
const BUDGE_LEAN := 4.0

## Emitted when a Pull or Shove makes it budge.
signal budged
## Emitted when it breaks into small rocks, with them.
signal shattered(pieces: Array)

## How many small rocks it breaks into, at least and at most.
@export var pieces_min := 4
@export var pieces_max := 6
## In pixels: how close behind its far side a wall must be for a Shove to crush it.
@export var break_reach := 24.0
## In pixels: its half-size, for where the wall is looked for and where the pieces fall.
@export var half_size := Vector2(24.0, 14.0)

var _budge_left := 0
var _budge_way := Vector2.ZERO
var _broken := false


func _ready() -> void:
	add_to_group(&"budgeables")


## What Pull and Shove aim at and measure to: the rock itself.
func prop() -> Node2D:
	return self


## Whether a Pull or Shove can act on it: while it is whole.
func can_be_moved() -> bool:
	return not _broken


## The RIDs of its solid parts, which a line to it must not count as a wall.
func body_rids() -> Array[RID]:
	return [get_rid()]


## Whether it is budging now.
func budging() -> bool:
	return _budge_left > 0


## A Pull or a Shove on it, the way given (toward him for a Pull, away for a Shove): it budges, and a
## Shove with a wall right behind it crushes it into small rocks.
func budge(way: Vector2, pushing: bool) -> void:
	if _broken:
		return
	_budge_way = way.normalized() if not way.is_zero_approx() else Vector2.ZERO
	_budge_left = BUDGE_FRAMES
	budged.emit()
	if pushing and wall_behind(_budge_way):
		shatter()


## Whether a wall stands right behind it, the way given.
func wall_behind(way: Vector2) -> bool:
	if way.is_zero_approx():
		return false
	var reach := absf(way.x) * half_size.x + absf(way.y) * half_size.y + break_reach
	var query := PhysicsRayQueryParameters2D.create(global_position + Vector2(0, -half_size.y), global_position + Vector2(0, -half_size.y) + way * reach, WALLS)
	query.exclude = [get_rid()]
	return not get_world_2d().direct_space_state.intersect_ray(query).is_empty()


## It breaks: a burst of its own art, and small rocks scattered where it stood. It is gone.
func shatter() -> void:
	if _broken:
		return
	_broken = true
	var art := get_node_or_null("Look/Art") as Sprite2D
	if art != null and art.texture != null:
		var burst: Node2D = BREAK_SCRIPT.new()
		get_parent().add_child(burst)
		burst.global_position = global_position
		burst.call(&"shatter", art.texture, art.position, art.scale, _budge_way)
	var pieces: Array = []
	var count := pieces_min + int(absi(int(global_position.x * 7.0 + global_position.y * 13.0)) % (pieces_max - pieces_min + 1))
	for i in count:
		var angle := TAU * i / count + 0.4
		var at := global_position + Vector2(cos(angle) * half_size.x * 1.1, sin(angle) * half_size.y * 1.1 + 4.0)
		at = at.snappedf(OpenMapCamera.ART_PIXEL)
		if _over_a_drop(at):
			continue
		var piece: Node2D = SMALL_ROCK_SCENE.instantiate()
		piece.position = get_parent().to_local(at) if get_parent() is Node2D else at
		(piece.get_node("Look/Art") as Sprite2D).texture = SMALL_ROCK_ART[i % SMALL_ROCK_ART.size()]
		get_parent().add_child(piece)
		pieces.append(piece)
	collision_layer = 0
	visible = false
	remove_from_group(&"budgeables")
	shattered.emit(pieces)
	queue_free()


func _physics_process(_delta: float) -> void:
	if _budge_left <= 0:
		return
	_budge_left -= 1
	var look := get_node_or_null("Look") as Node2D
	if look == null:
		return
	var strain := _budge_way * BUDGE_LEAN * (float(_budge_left) / BUDGE_FRAMES)
	var jolt := 2.0 if _budge_left % 4 < 2 else -2.0
	look.position = (strain + Vector2(jolt, 0.0)).snappedf(OpenMapCamera.ART_PIXEL) if _budge_left > 0 else Vector2.ZERO


func _over_a_drop(point: Vector2) -> bool:
	var query := PhysicsPointQueryParameters2D.new()
	query.position = point
	query.collision_mask = GAP_AREA
	query.collide_with_areas = true
	query.collide_with_bodies = false
	return not get_world_2d().direct_space_state.intersect_point(query, 1).is_empty()
