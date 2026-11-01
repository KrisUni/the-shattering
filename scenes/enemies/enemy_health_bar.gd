class_name EnemyHealthBar
extends Node2D
## A small Health bar over an enemy's head, drawn pixel-exact like the HUD's bars: a dark frame, a
## blood-red fill lit along its top, and a pale trail where a loss took it from, which holds a moment
## and drains. It shows once the enemy is hurt or in Pursuit, and hides while it is whole and at
## rest, and once it is dead. It only reads the enemy; no gameplay depends on it.

const FRAME := Color("0c0b14")
const BACK := Color("1b1a2b")
const FILL := Color("9b3a46")
const FILL_LIGHT := Color("c25a63")
const TRAIL := Color("e8dccb")
# In units: one art pixel, and the bar's size, 16 by 3 art pixels.
const PIXEL := 2.0
const WIDTH := 32.0
const HEIGHT := 6.0
# In seconds: how long the trail holds, and how fast it drains, in shares of the bar a second.
const TRAIL_HOLD := 0.45
const TRAIL_SPEED := 0.8

var _enemy: Node
var _health: Health
var _shown := 1.0
var _trail := 1.0
var _trail_hold := 0.0


func _ready() -> void:
	_enemy = get_parent()
	_health = _enemy.get_node_or_null("Health") as Health
	z_index = 3
	if _health != null:
		_shown = _share()
		_trail = _shown
		_health.changed.connect(_on_changed)
	_update_visibility()


## Whether the bar shows now.
func showing() -> bool:
	return visible


## Where the trail ends, as a share of the bar.
func trail_share() -> float:
	return _trail


func _share() -> float:
	return clampf(_health.current / _health.maximum, 0.0, 1.0) if _health.maximum > 0.0 else 0.0


func _on_changed() -> void:
	var now := _share()
	if now < _shown:
		_trail = maxf(_trail, _shown)
		_trail_hold = TRAIL_HOLD
	_shown = now
	_trail = maxf(_trail, _shown)
	queue_redraw()


func _process(delta: float) -> void:
	_update_visibility()
	if _trail > _shown:
		if _trail_hold > 0.0:
			_trail_hold -= delta
		else:
			_trail = maxf(_shown, _trail - TRAIL_SPEED * delta)
		queue_redraw()


func _update_visibility() -> void:
	if _health == null:
		visible = false
		return
	var hurt := _health.current < _health.maximum
	var chasing: bool = _enemy.get(&"in_pursuit") == true
	visible = (hurt or chasing) and _enemy.get(&"dead") != true


func _draw() -> void:
	var origin := Vector2(-WIDTH / 2.0, 0.0)
	draw_rect(Rect2(origin, Vector2(WIDTH, HEIGHT)), FRAME)
	var inner := Rect2(origin + Vector2(PIXEL, PIXEL), Vector2(WIDTH - 2.0 * PIXEL, HEIGHT - 2.0 * PIXEL))
	draw_rect(inner, BACK)
	var fill_w := floorf(inner.size.x * _shown / PIXEL) * PIXEL
	var trail_w := floorf(inner.size.x * _trail / PIXEL) * PIXEL
	if trail_w > fill_w:
		draw_rect(Rect2(inner.position.x + fill_w, inner.position.y, trail_w - fill_w, inner.size.y), TRAIL)
	if fill_w > 0.0:
		draw_rect(Rect2(inner.position, Vector2(fill_w, inner.size.y)), FILL)
		draw_rect(Rect2(inner.position, Vector2(fill_w, PIXEL)), FILL_LIGHT)
