class_name BladeSmear
extends Node2D
## The arc of an enemy's sword through its strike, as Almos's swing has: while a blow is live, a
## crescent of cream and sand sweeps through the air before it, thinning as it goes. Drawn in code
## on the art pixel grid; it hangs on the enemy's Look and turns with the way it faces. Only a look.

const EDGE := [Color("fbf5ef"), Color("f0e0c4"), Color("dbbe98")]

## How far the arc reaches from the enemy's middle, in art pixels, and how thick it is at its thickest.
@export var radius := 22.0
@export var thickness := 5.0

## How far through the arc the blow is, from 0 to 1; below 0 nothing shows.
var progress := -1.0
## Which way the enemy faces, a unit vector.
var facing := Vector2.RIGHT


func _ready() -> void:
	z_index = 1


func show_at(fraction: float, toward: Vector2) -> void:
	progress = fraction
	facing = toward
	queue_redraw()


func clear() -> void:
	if progress >= 0.0:
		progress = -1.0
		queue_redraw()


func _draw() -> void:
	if progress < 0.0:
		return
	# From over the shoulder, down and across in front: a third of a turn, led by the blow.
	var flip := -1.0 if facing.x < 0.0 else 1.0
	var start := -1.25
	var sweep := 2.3
	var lead := start + sweep * clampf(progress, 0.0, 1.0)
	var tail := start + sweep * maxf(0.0, progress - 0.55)
	var steps := 18
	for k in steps + 1:
		var a := lerpf(tail, lead, float(k) / float(steps))
		var along := float(k) / float(steps)
		var thick := thickness * along * (1.0 - 0.4 * progress)
		var colour: Color = EDGE[mini(int((1.0 - along) * EDGE.size()), EDGE.size() - 1)]
		for j in int(thick) + 1:
			var r := radius - float(j)
			var at := Vector2(cos(a) * r * flip, sin(a) * r - 14.0).round()
			draw_rect(Rect2(at, Vector2.ONE), colour)
