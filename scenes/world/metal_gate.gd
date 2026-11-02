class_name MetalGate
extends PathBlocker
## A metal gate across a cell's doorway: a path blocker of iron bars. It opens two ways, and stays
## open by the path blocker's rules (saved at a rest, undone by a Death):
## - melted: a fireball sets it alight (Fire only reaches it from a thrown flame, never by touching
##   something burning); the bars glow and sag as it burns, and when its burn time is over it is gone;
## - crashed: a thrown rock that hits it breaks it open at once, in a spray of its bars.
## A Pull or a Shove only makes it budge: it rattles and leans, and stays shut. It is in the group
## "budgeables", where Almos's Spell looks for things to budge.

const BREAK_SCRIPT := preload("res://scenes/world/prop_break.gd")
## How it glows as it melts, at the end of its burn time. A look.
const MELT_GLOW := Color(1.0, 0.62, 0.38)
const BUDGE_FRAMES := 16
const BUDGE_LEAN := 3.0

## Emitted when a Pull or Shove makes it budge.
signal budged
## Emitted when a thrown rock crashes it open.
signal crashed

var _budge_left := 0
var _budge_way := Vector2.ZERO


func _ready() -> void:
	super()
	add_to_group(&"budgeables")
	flammable.catches_by_contact = false
	flammable.restored.connect(_reset_look)


## What Pull and Shove aim at and measure to: the gate itself.
func prop() -> Node2D:
	return self


## Whether a Pull or Shove can act on it: while it is shut.
func can_be_moved() -> bool:
	return not open


func body_rids() -> Array[RID]:
	return [get_rid()]


## Whether it is budging now.
func budging() -> bool:
	return _budge_left > 0


## A Pull or a Shove on it: it rattles and leans the way given, and stays shut.
func budge(way: Vector2, _pushing: bool) -> void:
	if open:
		return
	_budge_way = way.normalized() if not way.is_zero_approx() else Vector2.ZERO
	_budge_left = BUDGE_FRAMES
	budged.emit()


## Hit by something thrown: a rock crashes it open, in a spray of its bars; anything else bounces off.
func smash_by(thrown: Node, direction: Vector2) -> void:
	if open or thrown == null or not thrown.has_method(&"crushes") or not thrown.crushes():
		return
	var art := get_node_or_null("Look/Art") as Sprite2D
	if art != null and art.texture != null:
		var burst: Node2D = BREAK_SCRIPT.new()
		get_parent().add_child(burst)
		burst.global_position = global_position
		burst.call(&"shatter", art.texture, art.position, art.scale, direction)
	WorldState.record_burnt(id)
	flammable.burn_out_now()
	crashed.emit()


func _process(_delta: float) -> void:
	var art := get_node_or_null("Look/Art") as Sprite2D
	if art == null:
		return
	if flammable.burning:
		# It melts: glowing hotter and sagging as it burns.
		var t := clampf(flammable.burned_for / flammable.tuning.burn_time, 0.0, 1.0)
		art.modulate = Color.WHITE.lerp(MELT_GLOW, t)
		art.scale.y = 2.0 * (1.0 - 0.35 * t)


func _physics_process(_delta: float) -> void:
	if _budge_left <= 0:
		return
	_budge_left -= 1
	var look := get_node_or_null("Look") as Node2D
	if look == null:
		return
	var strain := _budge_way * BUDGE_LEAN * (float(_budge_left) / BUDGE_FRAMES)
	var jolt := 2.0 if _budge_left % 2 == 0 else -2.0
	look.position = (strain + Vector2(jolt, 0.0)).snapped(Vector2(2.0, 2.0)) if _budge_left > 0 else Vector2.ZERO


func _reset_look() -> void:
	var art := get_node_or_null("Look/Art") as Sprite2D
	if art != null:
		art.modulate = Color.WHITE
		art.scale = Vector2(2.0, 2.0)
