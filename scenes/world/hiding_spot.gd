class_name HidingSpot
extends Node2D
## A Hiding spot: a place Almos can get into with a tap of Interact within reach, such as a barrel,
## a bed or a curtain. It is drawn as a placeholder, is in the group "hiding_spots", which is where
## Almos looks for one, and has no body, so he walks through it. What it does to him and to the
## enemies is Almos's and the enemies' business; the spot only marks the place.
## Every one is flammable: it has a Flammable that sets it alight and burns it away.

## The part of it that catches Fire. Once it burns, and until it is whole again after a return, the
## spot is no longer one: it leaves the group, so he cannot get in. Optional.
@export var flammable: Flammable

## Where Almos steps out to when he leaves it, from the spot. A spot with a solid body (a wardrobe,
## a barrel) puts him in front of it, clear of the body; one without leaves him where it is.
@export var exit_offset := Vector2.ZERO

## Whether it is open at the top, as a barrel is: Almos is seen hopping in over its rim. One that is
## not, a wardrobe, he squeezes into between its doors. A look.
@export var open_top := false

## Who last got into it. It is occupied while that one is hiding, standing where it stands.
var occupant: Node2D

# How a rattle looks: every RATTLE_EVERY seconds or so (each spot on its own rhythm) its look hops and
# shudders for RATTLE_TIME seconds, RATTLE_OFFSET pixels from side to side. Looks, not tuning: no
# enemy hears it.
const RATTLE_EVERY := 3.0
const RATTLE_TIME := 0.3
const RATTLE_OFFSET := 2.0

var _jiggle: Tween
var _rattle_clock := 0.0
var _rattle_left := 0.0
# Whether the rattle last moved its look, so that only then is the look put back: otherwise the look
# is left alone, for whatever else moves it (a Pull or Shove making it shudder).
var _moved_look := false


## Whether someone is hiding in it now.
func occupied() -> bool:
	return occupant != null and is_instance_valid(occupant) and occupant.get(&"hiding") == true \
		and occupant.global_position.distance_to(global_position) < 1.0


## In pixels above the spot's place: where its top is drawn, which Almos hops in over (a little below
## the top of its art, inside its opening). A look.
func rim_height() -> float:
	var art := get_node_or_null("Look/Art") as Sprite2D
	if art == null or art.texture == null:
		return 24.0
	var top := art.position.y - art.texture.get_height() * art.scale.y / 2.0
	return -top - (6.0 if open_top else 0.0)


## Almos has landed in it, or sprung out of it: it squashes and wobbles back. A look.
func jiggle() -> void:
	var look := get_node_or_null("Look") as Node2D
	if look == null:
		return
	if _jiggle != null and _jiggle.is_valid():
		_jiggle.kill()
	_jiggle = look.create_tween()
	_jiggle.tween_property(look, ^"scale", Vector2(1.14, 0.84), 0.06).set_ease(Tween.EASE_OUT)
	_jiggle.tween_property(look, ^"scale", Vector2(0.94, 1.08), 0.08)
	_jiggle.tween_property(look, ^"scale", Vector2(1.03, 0.98), 0.07)
	_jiggle.tween_property(look, ^"scale", Vector2.ONE, 0.07)


## Whether it is rattling now.
func rattling() -> bool:
	return _rattle_left > 0.0


func _process(delta: float) -> void:
	var look := get_node_or_null("Look") as Node2D
	if look == null:
		return
	if not occupied():
		_rattle_clock = 0.0
		_rattle_left = 0.0
		if _moved_look:
			look.position = Vector2.ZERO
			_moved_look = false
		return
	_rattle_clock += delta
	# Each spot keeps its own rhythm, a little off the others', so a row of them does not rattle as one.
	var every := RATTLE_EVERY + fposmod(global_position.x * 0.013, 1.2)
	if _rattle_left <= 0.0 and _rattle_clock >= every:
		_rattle_clock = 0.0
		_rattle_left = RATTLE_TIME
	if _rattle_left > 0.0:
		_rattle_left -= delta
		var step := int(_rattle_left * 30.0)
		look.position = Vector2(RATTLE_OFFSET if step % 2 == 0 else -RATTLE_OFFSET, -RATTLE_OFFSET if step % 4 < 2 else 0.0)
		_moved_look = true
	elif _moved_look:
		look.position = Vector2.ZERO
		_moved_look = false


func _ready() -> void:
	if flammable != null:
		flammable.caught.connect(_on_caught)
		flammable.burned_out.connect(_on_burned_out)
		flammable.restored.connect(_on_restored)
		flammable.put_out.connect(_on_restored)


# It is burning: he cannot get into it.
func _on_caught() -> void:
	remove_from_group(&"hiding_spots")


func _on_burned_out() -> void:
	remove_from_group(&"hiding_spots")


# It is whole again after a return: Almos can get into it once more.
func _on_restored() -> void:
	add_to_group(&"hiding_spots")
