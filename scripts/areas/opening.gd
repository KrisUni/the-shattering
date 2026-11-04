extends Node
## The opening of a played game: Almos wakes on the bed in his cell and gets up, then a thought of
## his shows on screen until any key, click or pad button takes it away, and only then is he free to
## move. It runs once, the first time its host puts a space in, and only if that space has the Room
## and bed it names; otherwise it does nothing and he starts as usual. It is a child of the AreaHost
## of the played scene (scenes/areas/play_dungeons.tscn), not of the Dungeons, so the tests, which
## host the Dungeons themselves, start with him free as before.
##
## While it runs Almos is held still: his physics frame and his Look are stopped, and his sprite is
## laid on the bed, turned on its side, then raised as he sits up and steps off it. A press during the
## waking skips to him standing.

const ThoughtText := preload("res://scenes/hud/thought_text.gd")

## Emitted once he is free to move.
signal finished

## The Room he wakes in, and the bed in it, by path from the Room: its WakeSpot marker is where he
## lies, its GetUpSpot where he stands when he is up.
@export var room_id := &"cell_3"
@export var bed_path := NodePath("Bed")

## What he thinks as he wakes.
@export var thought: PackedStringArray = [
	"WHERE AM I?",
]

## In seconds: how long he lies asleep, stirs, and takes to get up.
@export var sleep_time := 1.6
@export var stir_time := 0.5
@export var get_up_time := 0.5

enum Stage { WAITING, ASLEEP, STIRRING, GETTING_UP, THINKING, DONE }

var stage: Stage:
	get:
		return _stage

var _stage := Stage.WAITING
var _time := 0.0
var _almos: Node2D
var _art: Node2D
var _look_node: Node
var _shadow: CanvasItem
var _lie_at := Vector2.ZERO
var _stand_at := Vector2.ZERO
var _art_position := Vector2.ZERO
var _thought: Control


func _ready() -> void:
	var host := get_parent()
	if host != null and host.has_signal(&"space_entered"):
		host.space_entered.connect(_on_space_entered, CONNECT_ONE_SHOT)


func _on_space_entered(space: Node) -> void:
	var building := space as DungeonsBuilding
	if building == null or building.almos == null:
		return
	var room := building.room(room_id)
	var bed := room.get_node_or_null(bed_path) as Node2D if room != null else null
	if bed == null:
		return
	var lie := bed.get_node_or_null("WakeSpot") as Node2D
	var stand := bed.get_node_or_null("GetUpSpot") as Node2D
	if lie == null or stand == null:
		return
	_almos = building.almos
	_lie_at = lie.global_position
	_stand_at = stand.global_position
	_art = _almos.get_node_or_null("Look/Art") as Node2D
	_look_node = _almos.get_node_or_null("Look/AlmosLook")
	_shadow = _almos.get_node_or_null("Shadow") as CanvasItem
	if _art != null:
		_art_position = _art.position
	_hold(true)
	_almos.global_position = _lie_at
	_almos.set(&"facing", Vector2.DOWN)
	_lie_down()
	_stage = Stage.ASLEEP
	_time = 0.0


func _process(delta: float) -> void:
	if _stage == Stage.WAITING or _stage == Stage.DONE or _stage == Stage.THINKING:
		return
	_time += delta
	match _stage:
		Stage.ASLEEP:
			# Breathing: the sprite rises a pixel and settles, slowly.
			if _art != null:
				_art.position = _art_position + Vector2(0.0, -2.0 if fmod(_time, 1.0) < 0.5 else 0.0)
			if _time >= sleep_time:
				_next(Stage.STIRRING)
		Stage.STIRRING:
			# He stirs: a few small jerks as he comes to.
			if _art != null:
				var jerk := int(_time * 16.0) % 4
				_art.rotation = -PI / 2.0 + (0.12 if jerk == 0 else (-0.08 if jerk == 2 else 0.0))
			if _time >= stir_time:
				_next(Stage.GETTING_UP)
		Stage.GETTING_UP:
			var t := clampf(_time / get_up_time, 0.0, 1.0)
			var eased := t * t * (3.0 - 2.0 * t)
			if _art != null:
				# Sits up, then swings his feet off the bed and stands, with a little hop.
				_art.rotation = lerpf(-PI / 2.0, 0.0, clampf(t * 1.6, 0.0, 1.0))
				_art.position = _art_position
			_almos.global_position = (_lie_at.lerp(_stand_at, eased) + Vector2(0.0, -sin(t * PI) * 10.0)).snappedf(OpenMapCamera.ART_PIXEL)
			if t >= 1.0:
				_stand_up()
				_think()


func _input(event: InputEvent) -> void:
	if _stage != Stage.ASLEEP and _stage != Stage.STIRRING and _stage != Stage.GETTING_UP:
		return
	if ThoughtText._is_a_press(event):
		get_viewport().set_input_as_handled()
		_stand_up()
		_think()


func _next(next: Stage) -> void:
	_stage = next
	_time = 0.0


# He lies on his side on the bed: his sprite turned a quarter, head toward the pillow, no shadow.
func _lie_down() -> void:
	if _art != null:
		_art.rotation = -PI / 2.0
		if _art is AnimatedSprite2D:
			var sprite := _art as AnimatedSprite2D
			sprite.flip_h = false
			if sprite.sprite_frames != null and sprite.sprite_frames.has_animation(&"idle_side"):
				sprite.play(&"idle_side")
				sprite.pause()
	if _shadow != null:
		_shadow.visible = false


# He is on his feet in front of the bed, his sprite as it always is.
func _stand_up() -> void:
	_almos.global_position = _stand_at
	if _art != null:
		_art.rotation = 0.0
		_art.position = _art_position
	if _shadow != null:
		_shadow.visible = true
	# His Look shows him standing while the thought is up; he is still held.
	if _look_node != null:
		_look_node.set_physics_process(true)


# The thought shows; when it is taken away he is let go.
func _think() -> void:
	_stage = Stage.THINKING
	var layer := CanvasLayer.new()
	layer.layer = 50
	layer.scale = Vector2.ONE * ThoughtText.PixelText.UI_SCALE
	add_child(layer)
	var text := ThoughtText.new()
	text.lines = thought
	layer.add_child(text)
	_thought = text
	text.dismissed.connect(_on_thought_dismissed.bind(layer))


func _on_thought_dismissed(layer: CanvasLayer) -> void:
	layer.queue_free()
	# He is let go two physics frames later, so the press that took the thought away is not read by
	# him as a press of his own (a cast, a Roll).
	await get_tree().physics_frame
	await get_tree().physics_frame
	_hold(false)
	_stage = Stage.DONE
	finished.emit()


# Holds Almos still, or lets him go: his own physics frame, and his Look.
func _hold(held: bool) -> void:
	if _almos == null:
		return
	_almos.set_physics_process(not held)
	if _almos is CharacterBody2D:
		(_almos as CharacterBody2D).velocity = Vector2.ZERO
	if _look_node != null:
		_look_node.set_physics_process(not held)
