class_name InspectSpot
extends Node2D
## Something Almos can look at closely, such as remains or a carving on a wall: with a tap of
## Interact within pickup_reach of it, a short thought of his shows low on the screen and fades by
## itself a few seconds after (it takes no press, so it never holds him up). He can look again as
## often as he likes. It is in the group "inspect_spots", which is where Almos looks for one, and has
## no body, so nothing about it is in his way. Only one such thought shows at a time: a new one
## takes the place of the last.

const ThoughtText := preload("res://scenes/hud/thought_text.gd")

## What he thinks when he looks at it.
@export var lines: PackedStringArray = []
## In seconds: how long the thought stays once it is out.
@export var stay := 4.5

# The thought showing now, from any spot, and its layer.
static var _showing: CanvasLayer


func _ready() -> void:
	add_to_group(&"inspect_spots")


## Shows his thought about it, in place of any such thought showing now.
func inspect() -> void:
	if is_instance_valid(_showing):
		_showing.queue_free()
	var layer := CanvasLayer.new()
	layer.layer = 40
	layer.scale = Vector2.ONE * ThoughtText.PixelText.UI_SCALE
	add_child(layer)
	var text := ThoughtText.new()
	text.lines = lines
	text.auto_hide_after = stay
	layer.add_child(text)
	text.dismissed.connect(layer.queue_free)
	_showing = layer


## The thought showing now, from any spot, or null.
static func showing() -> Node:
	if not is_instance_valid(_showing):
		return null
	for child in _showing.get_children():
		if child is ThoughtText:
			return child
	return null
