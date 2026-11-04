class_name MetalGate
extends PathBlocker
## A metal gate across a cell's doorway: a path blocker of iron bars. It opens two ways, and stays
## open by the path blocker's rules (saved at a rest, undone by a Death):
## - melted: a fireball sets it alight (Fire only reaches it from a thrown flame, never by touching
##   something burning); the bars glow and melt away from the top down as it burns, a hot molten edge
##   eating down them and dripping, and when its burn time is over it is gone;
## - crashed: a thrown rock that hits it breaks it open at once, in a spray of its bars.
## A Pull or a Shove only makes it budge: it rattles and leans, and stays shut. It is in the group
## "budgeables", where Almos's Spell looks for things to budge.

const BREAK_SCRIPT := preload("res://scenes/world/prop_break.gd")
## How it glows as it melts, at the end of its burn time. A look.
const MELT_GLOW := Color(1.0, 0.62, 0.38)
## The molten edge where the bars are melting, and the drips that fall from it. A look.
const MOLTEN := Color(1.0, 0.78, 0.42)
const MOLTEN_DEEP := Color(0.92, 0.36, 0.16)
## In art pixels: how much of the bars is left standing at the end of the burn time, as a stub.
const MELT_STUB := 4
## One art pixel in world units.
const PIXEL := 1.0
const BUDGE_FRAMES := 16
const BUDGE_LEAN := 3.0

## Emitted when a Pull or Shove makes it budge.
signal budged
## Emitted when a thrown rock crashes it open.
signal crashed

var _budge_left := 0
var _budge_way := Vector2.ZERO
# In art pixels: how much of the bars has melted away from the top, and where the art first stood.
var _melted := 0
var _art_home := Vector2.ZERO
var _melt_time := 0.0
var _bars: Image
var _molten: Node2D


func _ready() -> void:
	super()
	add_to_group(&"budgeables")
	flammable.catches_by_contact = false
	flammable.restored.connect(_reset_look)
	var art := get_node_or_null("Look/Art") as Sprite2D
	if art != null:
		_art_home = art.position
		if art.texture != null:
			_bars = art.texture.get_image()
		# Drawn over the bars, and moved with them when they budge.
		_molten = Node2D.new()
		_molten.name = "Molten"
		art.get_parent().add_child(_molten)
		_molten.draw.connect(_draw_molten)


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


## In art pixels: how much of the bars has melted away, from the top down.
func melted() -> int:
	return _melted


func _process(delta: float) -> void:
	var art := get_node_or_null("Look/Art") as Sprite2D
	if art == null or art.texture == null:
		return
	if flammable.burning:
		# It melts from the top down: the bars glow hotter and are eaten away row by row, their feet
		# last, while the molten edge drips.
		_melt_time += delta
		var t := clampf(flammable.burned_for / flammable.tuning.burn_time, 0.0, 1.0)
		art.modulate = Color.WHITE.lerp(MELT_GLOW, t)
		var height := int(art.texture.get_height())
		var melted_now := floori(t * (height - MELT_STUB))
		if melted_now != _melted:
			_melted = melted_now
			_cut(art)
		if _molten != null:
			_molten.queue_redraw()


# Shows only the bars below the melted part, their feet where they always stand.
func _cut(art: Sprite2D) -> void:
	var size := art.texture.get_size()
	art.region_enabled = true
	art.region_rect = Rect2(0.0, _melted, size.x, size.y - _melted)
	art.position = _art_home + Vector2(0.0, _melted * art.scale.y / 2.0)


# The molten edge along the top of what is left, and drips running down from it.
func _draw_molten() -> void:
	if not flammable.burning or _melted <= 0 or _bars == null:
		return
	var size := Vector2(_bars.get_size())
	var top := _art_home + Vector2(-size.x * PIXEL / 2.0, -size.y * PIXEL / 2.0 + _melted * PIXEL)
	var flicker := int(_melt_time * 12.0)
	for column in int(size.x):
		# The bars only: where the art has a pixel in the row being eaten.
		var row := mini(_melted, int(size.y) - 1)
		if _bars.get_pixel(column, row).a < 0.5:
			continue
		var at := top + Vector2(column * PIXEL, 0.0)
		_molten.draw_rect(Rect2(at - Vector2(0.0, PIXEL), Vector2(PIXEL, PIXEL)), MOLTEN)
		_molten.draw_rect(Rect2(at, Vector2(PIXEL, PIXEL)), MOLTEN_DEEP)
		# Now and then a drip runs down the bar.
		var seed := (column * 7 + flicker) % 23
		if seed < 2:
			var length := 1 + (column + flicker) % 4
			for step in length:
				_molten.draw_rect(Rect2(at + Vector2(0.0, (step + 1) * PIXEL * 2.0), Vector2(PIXEL, PIXEL)), MOLTEN_DEEP if step < length - 1 else MOLTEN)


func _physics_process(_delta: float) -> void:
	if _budge_left <= 0:
		return
	_budge_left -= 1
	var look := get_node_or_null("Look") as Node2D
	if look == null:
		return
	var strain := _budge_way * BUDGE_LEAN * (float(_budge_left) / BUDGE_FRAMES)
	var jolt := 2.0 if _budge_left % 2 == 0 else -2.0
	look.position = (strain + Vector2(jolt, 0.0)).snappedf(OpenMapCamera.ART_PIXEL) if _budge_left > 0 else Vector2.ZERO


func _reset_look() -> void:
	_melted = 0
	if _molten != null:
		_molten.queue_redraw()
	var art := get_node_or_null("Look/Art") as Sprite2D
	if art != null:
		art.modulate = Color.WHITE
		art.scale = Vector2.ONE
		art.region_enabled = false
		art.position = _art_home
