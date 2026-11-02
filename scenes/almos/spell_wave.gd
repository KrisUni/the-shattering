extends Node2D
## The look of a Pull or a Shove on ordinary things (not a flame): a wave of energy, so that every
## press shows, whether it moves anything or not.
## - Pull: a ring half as wide as Pull's reach closes in on Almos, a second following it, drawing motes
##   in with it.
## - Shove: an arc bursts out from him along his aim, to half Shove's reach, in bands, thinning as it goes.
## Where the Spell lands on something, an enemy or a prop, a small ripple shows on it. Only a look:
## it reads nothing back, and frees itself when done. Drawn on the art pixel grid.

const CREAM := Color("fbf5ef")
const SAND := Color("f2d3ab")
const ROSE := Color("c69fa5")
const VIOLET := Color("8b6d9c")
const SLATE := Color("494d7e")

# In units. One art pixel.
const PIXEL := 2.0
# In seconds.
const DURATION := 0.38
const RIPPLE_TIME := 0.3
# Pull's second ring follows the first this much later, in shares of the duration.
const SECOND_RING := 0.22
# How much wider, either side, Shove's arc is drawn than its cone, in degrees, so that it reads.
const ARC_SPREAD := 10.0
const MOTES := 10
# How big the wave is drawn, as a share of the Spell's reach: smaller than the reach itself, so it
# reads as a burst around him rather than filling the Room.
const SIZE := 0.5

## Whether it is a Pull (closing in) or a Shove (bursting out).
var pulling := true

var _time := 0.0
var _aim := Vector2.DOWN
var _reach := 200.0
var _half_angle := 20.0
var _follow: Node2D
var _target: WeakRef
var _target_at := Vector2.ZERO


func _ready() -> void:
	z_index = 2


## Starts the wave: a Pull or a Shove, along this aim, as far as this reach, Shove's arc this many
## degrees either side of the aim. follow is who it stays on (Almos, for a Pull); target is what the
## Spell lands on, or null.
func start(is_pull: bool, aim: Vector2, reach: float, half_angle_degrees: float, follow: Node2D, target: Node2D) -> void:
	pulling = is_pull
	_aim = aim.normalized() if not aim.is_zero_approx() else Vector2.DOWN
	_reach = reach * SIZE
	_half_angle = half_angle_degrees
	_follow = follow if is_pull else null
	_target = weakref(target) if target != null else null
	if target != null:
		_target_at = target.global_position


## Whether it has run its course.
func done() -> bool:
	return _time >= DURATION + RIPPLE_TIME


func _process(delta: float) -> void:
	_time += delta
	if done():
		queue_free()
		return
	if _follow != null and is_instance_valid(_follow):
		global_position = _follow.global_position.snapped(Vector2(PIXEL, PIXEL))
	if _target != null:
		var target := _target.get_ref() as Node2D
		if target != null:
			_target_at = target.global_position
	queue_redraw()


func _draw() -> void:
	var t := _time / DURATION
	if t < 1.0:
		if pulling:
			_draw_pull(t)
		else:
			_draw_shove(t)
	_draw_ripple()


# A ring closes in from the reach to his feet, gathering speed; a second follows. Motes stream in.
func _draw_pull(t: float) -> void:
	for ring in 2:
		var local := (t - ring * SECOND_RING) / (1.0 - SECOND_RING)
		if local <= 0.0 or local >= 1.0:
			continue
		var eased := local * local
		var radius := lerpf(_reach, 6.0, eased)
		# Faint where it starts, bright as it closes in.
		var strength := clampf(local * 2.5, 0.0, 1.0) * (1.0 - maxf(local - 0.85, 0.0) / 0.15)
		var colour := CREAM if ring == 0 else ROSE
		_ring(radius, Color(colour, strength), 2 if ring == 0 else 1)
		_ring(radius + PIXEL * 2.0, Color(VIOLET, strength * 0.6), 1)
	for i in MOTES:
		var angle := TAU * i / MOTES + 0.37 * sin(i * 1.3)
		var start := fposmod(i * 0.071, 0.3)
		var local := (t - start) / (1.0 - start)
		if local <= 0.0 or local >= 1.0:
			continue
		var radius := lerpf(_reach * (0.6 + 0.4 * absf(sin(i * 2.1))), 4.0, local * local)
		var at := Vector2.from_angle(angle + local * 0.6) * radius
		_pixel(at, Color(SAND if i % 2 else CREAM, 1.0 - local * 0.5))
		_pixel(at * 1.08, Color(VIOLET, 0.6 * (1.0 - local)))


# An arc bursts out along the aim, three bands deep, thinning and fading as it reaches out.
func _draw_shove(t: float) -> void:
	var eased := 1.0 - pow(1.0 - t, 2.0)
	var half := deg_to_rad(_half_angle + ARC_SPREAD)
	var bands := [[0.0, CREAM, 2], [6.0, ROSE, 1], [12.0, SLATE, 1]]
	for band in bands:
		var radius: float = lerpf(10.0, _reach, eased) - band[0] * (0.4 + eased)
		if radius <= 4.0:
			continue
		var strength := 1.0 - t * t
		_arc(radius, half * (0.6 + 0.4 * eased), Color(band[1], strength), band[2])
	# A puff at his hands where it leaves.
	if t < 0.3:
		var puff := 1.0 - t / 0.3
		for i in 6:
			var angle := _aim.angle() + (i - 2.5) * 0.35
			_pixel(Vector2.from_angle(angle) * (6.0 + 6.0 * t / 0.3), Color(CREAM, puff))


# A small ring that swells and fades on what the Spell landed on, starting as the wave reaches it.
func _draw_ripple() -> void:
	if _target == null:
		return
	var distance := (_target_at - global_position).length()
	var arrives := DURATION * (1.0 - clampf(distance / maxf(_reach, 1.0), 0.0, 1.0)) if pulling else DURATION * clampf(distance / maxf(_reach, 1.0), 0.0, 1.0) * 0.6
	var local := (_time - arrives) / RIPPLE_TIME
	if local <= 0.0 or local >= 1.0:
		return
	var centre := to_local(_target_at) + Vector2(0.0, -14.0)
	var colour := Color(CREAM, 1.0 - local)
	var radius := lerpf(3.0, 12.0, local)
	var steps := maxi(12, int(radius))
	for i in steps:
		var angle := TAU * i / steps
		_pixel(centre + Vector2(cos(angle) * radius, sin(angle) * radius * 0.6), colour)
	_pixel(centre, Color(SAND, 1.0 - local))


func _ring(radius: float, colour: Color, thickness: int) -> void:
	# About one pixel per art pixel of the circumference, in a broken line, so it reads as energy.
	var steps := maxi(16, int(TAU * radius / PIXEL))
	for i in steps:
		if (i + int(_time * 30.0)) % 5 == 0:
			continue
		var angle := TAU * i / steps
		var at := Vector2.from_angle(angle) * radius
		_pixel(at, colour)
		if thickness > 1:
			_pixel(at * (1.0 - PIXEL / maxf(radius, PIXEL)), colour)


func _arc(radius: float, half: float, colour: Color, thickness: int) -> void:
	var steps := maxi(8, int(2.0 * half * radius / PIXEL))
	var centre := _aim.angle()
	for i in steps + 1:
		var angle := centre - half + 2.0 * half * i / steps
		# Thinner toward its tips.
		var edge := absf(angle - centre) / half
		if edge > 0.8 and (i % 2) == 0:
			continue
		var at := Vector2.from_angle(angle) * radius
		_pixel(at, colour)
		if thickness > 1 and edge < 0.6:
			_pixel(at - Vector2.from_angle(angle) * PIXEL, colour)


func _pixel(at: Vector2, colour: Color) -> void:
	var snapped := at.snapped(Vector2(PIXEL, PIXEL))
	draw_rect(Rect2(snapped - Vector2(PIXEL, PIXEL) / 2.0, Vector2(PIXEL, PIXEL)), colour)
