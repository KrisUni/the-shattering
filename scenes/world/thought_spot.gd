class_name ThoughtSpot
extends Area2D
## A place where Almos thinks something, once: the first time he walks into it, a short thought of
## his shows low on the screen and fades by itself a few seconds after (it takes no press, so it never
## holds him up). Used to teach his powers where the hall asks for them. Each spot speaks once per
## game, by its id.

const ThoughtText := preload("res://scenes/hud/thought_text.gd")

## What it is called, so that it speaks only once per game.
@export var id: StringName
## What he thinks.
@export var lines: PackedStringArray = []
## In seconds: how long the thought stays once it is out.
@export var stay := 4.0

static var _spoken := {}

var _layer: CanvasLayer


func _ready() -> void:
	collision_layer = 0
	collision_mask = 256
	monitorable = false
	body_entered.connect(_on_body_entered)


## Whether this spot has spoken in this game.
func spoken() -> bool:
	return _spoken.has(id)


## Forgets every spot that has spoken (a new game).
static func forget_all() -> void:
	_spoken.clear()


func _on_body_entered(body: Node2D) -> void:
	if spoken() or not body is Almos:
		return
	_spoken[id] = true
	_layer = CanvasLayer.new()
	_layer.layer = 40
	_layer.scale = Vector2.ONE * ThoughtText.PixelText.UI_SCALE
	add_child(_layer)
	var text := ThoughtText.new()
	text.lines = lines
	text.auto_hide_after = stay
	_layer.add_child(text)
	text.dismissed.connect(_layer.queue_free)
