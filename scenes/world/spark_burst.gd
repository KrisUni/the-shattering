class_name SparkBurst
extends Node2D
## Sparks where iron meets iron: short bright streaks thrown out from the meeting point that cool
## from cream to steel and go out, more of them and longer for a Parry. Drawn in code on the art
## pixel grid. Only a look.

const HOT := [Color("fbf5ef"), Color("f2d3ab"), Color("a3a8b8"), Color("62667c")]

## How many sparks, how far they fly in art pixels, and how long they last in seconds.
@export var count := 6
@export var reach := 12.0
@export var lifetime := 0.28
## Which way they mostly fly, a unit vector; zero for all round.
@export var heading := Vector2.ZERO

var _age := 0.0
var _ways: Array[Vector2] = []


## A burst put in this parent at this global place.
static func strike(parent: Node, at: Vector2, way := Vector2.ZERO, sparks := 6, distance := 12.0) -> SparkBurst:
	var burst := SparkBurst.new()
	burst.count = sparks
	burst.reach = distance
	burst.heading = way.normalized() if way != Vector2.ZERO else Vector2.ZERO
	parent.add_child(burst)
	burst.global_position = at.round()
	return burst


func _ready() -> void:
	z_index = 3
	var seed := int(absf(global_position.x * 3.0 + global_position.y * 5.0))
	for i in count:
		var spread := TAU if heading == Vector2.ZERO else 2.2
		var base := 0.0 if heading == Vector2.ZERO else heading.angle()
		var angle := base + (float(i) / float(count) - 0.5) * spread + 0.3 * float((seed + i * 7) % 5 - 2) / 2.0
		_ways.append(Vector2(cos(angle), sin(angle)) * (0.6 + 0.4 * float((seed + i * 3) % 4) / 3.0))


func _process(delta: float) -> void:
	_age += delta
	if _age >= lifetime:
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	var t := _age / lifetime
	var colour: Color = HOT[mini(int(t * HOT.size()), HOT.size() - 1)]
	for way in _ways:
		var head := (way * reach * (1.0 - (1.0 - t) * (1.0 - t))).round()
		var tail := (way * reach * maxf(0.0, t - 0.25)).round()
		var steps := maxi(int(head.distance_to(tail)), 1)
		for k in steps + 1:
			draw_rect(Rect2(tail.lerp(head, float(k) / float(steps)).round(), Vector2.ONE), colour)
