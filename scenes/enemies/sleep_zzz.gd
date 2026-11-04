class_name SleepZzz
extends Node2D
## The zzz over a sleeping enemy: small Z letters, drawn in code on the art pixel grid, that rise
## from over its head, drift aside, grow and fade, one after another, looping for as long as the
## enemy sleeps (its sleeping()). The moment it wakes they are gone. Only a look: nothing reads it.
## It sits in the enemy's Look, so the enemy is its parent's parent.

# The Z letters, as rows of pixels: a small one (4x4) and a bigger one (5x5).
const SMALL := ["####", "..#.", ".#..", "####"]
const BIG := ["#####", "...#.", "..#..", ".#...", "#####"]
# A pale cream, the letters' colour, and the dark under them so they read on any floor. Looks.
const INK := Color("e9e2d0")
const SHADE := Color("272744")
# How many letters are in the air at once, and how long each takes to rise and fade, in seconds.
const COUNT := 3
const LIFE := 2.4
# In art pixels. How far a letter rises and drifts aside over its life.
const RISE := 24.0
const DRIFT := 12.0

## In art pixels, from the enemy's feet. Where the letters start, just over its head as it sleeps,
## for a sprite facing right; for one flipped to face left it is mirrored.
@export var over_head := Vector2(8, -26)

var _enemy: Node
var _time := 0.0


func _ready() -> void:
	_enemy = get_parent().get_parent()


func _process(delta: float) -> void:
	var asleep: bool = is_instance_valid(_enemy) and _enemy.has_method(&"sleeping") and _enemy.sleeping()
	if asleep:
		_time += delta
	else:
		_time = 0.0
	if visible != asleep:
		visible = asleep
	queue_redraw()


## Whether it shows now: while the enemy sleeps.
func showing() -> bool:
	return visible


func _draw() -> void:
	# The sprite flips with the enemy; the letters always drift up and to the right of its head,
	# so they follow its head's side.
	var side := -1.0 if _flipped() else 1.0
	for i in COUNT:
		var t := fposmod(_time / LIFE + float(i) / COUNT, 1.0)
		var glyph: Array = SMALL if t < 0.45 else BIG
		var at := Vector2(side * over_head.x, over_head.y) \
			+ Vector2(roundf(side * (DRIFT * t + sin(t * TAU))), roundf(-RISE * t))
		if side < 0.0:
			at.x -= glyph[0].length()
		var alpha := clampf(minf(t / 0.15, (1.0 - t) / 0.35), 0.0, 1.0)
		_glyph(glyph, at + Vector2(1, 1), Color(SHADE, alpha * 0.8))
		_glyph(glyph, at, Color(INK, alpha))


func _glyph(glyph: Array, at: Vector2, colour: Color) -> void:
	for y in glyph.size():
		var row: String = glyph[y]
		for x in row.length():
			if row[x] == "#":
				draw_rect(Rect2(at + Vector2(x, y), Vector2.ONE), colour)


func _flipped() -> bool:
	var art := get_parent().get_node_or_null("Art") as AnimatedSprite2D
	return art != null and art.flip_h
