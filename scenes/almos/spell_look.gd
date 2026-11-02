class_name SpellLook
extends Node2D
## How Almos's Pull looks, all in fire and smoke, no magic glow. While he winds up a Pull on a torch
## or a Fire, the flame is torn from it toward his hand as a tapering tongue of fire, shedding
## embers. It keeps flowing a moment after the release, the torch it came from is left smoking, and
## the flame lands in his hand with a splash of embers. While he holds it, a small flame burns in
## his hand, on the side he faces, with an ember rising now and then. Everything is drawn on the art
## pixel grid, in palette colours.
##
## It only reads AlmosSpell and Almos's facing; no gameplay depends on it. It draws in world space
## (top_level), so it is not turned or tinted with his Look. The held flame's own sprite is hidden in
## the Almos scene, since this draws the flame in his hand instead.

const AMBER := Color("f29a2e")
const SAND := Color("f2d3ab")
const CREAM := Color("fbf5ef")
const ROSE := Color("c69fa5")
const SLATE := Color("494d7e")

# In units. One art pixel.
const PIXEL := 2.0
# In seconds. How long the stream keeps flowing after the release, how long the landing splash lasts,
# and how long the torch smokes.
const AFTERFLOW := 0.2
const SPLASH := 0.22
const SMOKE := 0.7
# In units, from a torch. Where its flame burns.
const TORCH_FLAME := Vector2(0, -22)

## The AlmosSpell whose Pull it shows.
@export var spell: AlmosSpell

var _time := 0.0
# Where the stream comes from, kept after the release so the afterflow and the smoke know.
var _source := Vector2.ZERO
var _streaming_for := -1.0
var _since_release := -1.0
var _was_winding_up := false


func _ready() -> void:
	top_level = true
	z_index = 2


func _process(delta: float) -> void:
	_time += delta
	if spell == null:
		return
	var from := spell.drawing_from
	if from != null:
		_source = _flame_point(from)
		if not _was_winding_up:
			_streaming_for = 0.0
		_streaming_for += delta
		_was_winding_up = true
	elif _was_winding_up:
		_was_winding_up = false
		_since_release = 0.0 if spell.holding_flame else -1.0
		if not spell.holding_flame:
			_streaming_for = -1.0
	if _since_release >= 0.0:
		_since_release += delta
		if _since_release > SMOKE:
			_since_release = -1.0
			_streaming_for = -1.0
	queue_redraw()


## Whether the stream is showing now: during a wind-up and the afterflow after its release.
func streaming() -> bool:
	return _streaming_for >= 0.0 and (_since_release < 0.0 or _since_release <= AFTERFLOW)


## Whether the landing splash is showing now.
func flashing() -> bool:
	return _since_release >= 0.0 and _since_release <= SPLASH


## Where his hand is, in the world, for the side he faces.
func hand_point() -> Vector2:
	var almos := spell.body
	var facing: Vector2 = almos.get("facing") if almos.get("facing") != null else Vector2.DOWN
	# The same sides his sprite shows: across when more across than up or down.
	if absf(facing.x) >= absf(facing.y) and not is_zero_approx(facing.x):
		return almos.global_position + Vector2(12.0 * signf(facing.x), -16)
	if facing.y < 0.0:
		return almos.global_position + Vector2(-10, -18)
	return almos.global_position + Vector2(10, -14)


func _draw() -> void:
	if spell == null or spell.body == null:
		return
	var hand := hand_point()
	if streaming():
		_draw_tongue(_source, hand)
	if _since_release >= 0.0:
		_draw_smoke(_source, _since_release / SMOKE)
	if flashing():
		_draw_splash(hand, _since_release / SPLASH)
	if spell.holding_flame:
		_draw_hand_flame(hand)


# A tongue of fire torn from the source toward the hand: thick at the source, thinning to a thread,
# wavering, with embers shed along it.
func _draw_tongue(from: Vector2, to: Vector2) -> void:
	var along := to - from
	if along.length() < 1.0:
		return
	var across := along.orthogonal().normalized()
	# While winding up it stretches out as the wind-up goes on; in the afterflow it is drawn into the
	# hand from its tail.
	var head := 1.0 if _since_release >= 0.0 else clampf(0.2 + spell.wind_up_progress * 1.1, 0.2, 1.0)
	var tail := 0.0 if _since_release < 0.0 else clampf(_since_release / AFTERFLOW, 0.0, 1.0)
	var steps := int(along.length() / PIXEL)
	for i in steps + 1:
		var t := float(i) / maxf(steps, 1.0)
		if t > head or t < tail:
			continue
		var waver := sin(t * 9.0 - _time * 22.0) * 4.0 * sin(t * PI)
		var point := from + along * t + across * waver
		var radius := lerpf(3.0, 0.6, t)
		_disc(point, radius, AMBER)
		if radius > 1.4:
			_disc(point, radius - 1.2, SAND)
		if radius > 2.4:
			_pixel(point, PIXEL, CREAM)
	# Embers flung off the tongue.
	for i in 6:
		var t := fposmod(_time * 1.8 + i / 6.0, 1.0)
		if t > head or t < tail:
			continue
		var drift := across * (sin(i * 2.3) * 10.0) + Vector2(0, -fposmod(_time * 30.0 + i * 7.0, 14.0))
		_pixel(from + along * t + drift, PIXEL, CREAM if i % 3 == 0 else AMBER)


# A wisp of smoke rising where the flame was torn from.
func _draw_smoke(at: Vector2, progress: float) -> void:
	for i in 4:
		var rise := progress * 22.0 + i * 5.0
		var sway := sin(progress * 6.0 + i * 1.7) * 3.0
		if (i + int(_time * 16.0)) % 3 == 0:
			continue
		_pixel(at + Vector2(sway, -rise), PIXEL * (2.0 if progress < 0.5 else 1.0), ROSE if progress < 0.5 else SLATE)


# A splash of embers as the flame lands in his hand.
func _draw_splash(at: Vector2, progress: float) -> void:
	for i in 8:
		var angle := TAU * i / 8.0 + 0.4
		var travel := lerpf(2.0, 12.0, progress) * (0.7 + 0.3 * absf(sin(i * 1.9)))
		var point := at + Vector2.from_angle(angle) * travel + Vector2(0, progress * progress * 6.0)
		_pixel(point, PIXEL, CREAM if progress < 0.4 else AMBER)
	if progress < 0.3:
		_disc(at, 2.0, SAND)


# A small flame burning in his hand, flickering, with an ember rising now and then.
func _draw_hand_flame(at: Vector2) -> void:
	var flicker := int(_time * 12.0) % 3
	var lean: float = [0.0, PIXEL, -PIXEL][flicker]
	# The body of the flame: a teardrop, widest at the hand.
	_disc(at, 2.0, AMBER)
	_disc(at + Vector2(lean * 0.5, -PIXEL * 2.0), 1.5, AMBER)
	_pixel(at + Vector2(lean, -PIXEL * 4.0), PIXEL, AMBER)
	_disc(at + Vector2(0, -PIXEL), 1.0, SAND)
	_pixel(at, PIXEL, CREAM)
	var ember_t := fposmod(_time * 1.3, 1.0)
	if ember_t < 0.6:
		_pixel(at + Vector2(sin(_time * 5.0) * 3.0, -PIXEL * 5.0 - ember_t * 16.0), PIXEL, AMBER if ember_t < 0.3 else ROSE)


# Where the flame of a torch, a lamp or a Fire burns: the middle of its flame sprite when it has
# one, so the tongue leaves a torch's tall flame and a lamp's glass alike.
func _flame_point(from: Node2D) -> Vector2:
	var art := from.get_node_or_null("Flame/Art") as AnimatedSprite2D
	if art != null and art.sprite_frames != null and art.sprite_frames.has_animation(art.animation):
		var texture := art.sprite_frames.get_frame_texture(art.animation, 0)
		if texture != null:
			var size := texture.get_size() * art.scale
			return art.global_position + (size / 2.0 if not art.centered else Vector2.ZERO)
	if from is Torch:
		return from.global_position + TORCH_FLAME
	return from.global_position


# A round blob of art pixels, this many art pixels in radius.
func _disc(at: Vector2, radius: float, colour: Color) -> void:
	var reach := ceili(radius)
	for y in range(-reach, reach + 1):
		for x in range(-reach, reach + 1):
			if x * x + y * y <= radius * radius + 0.5:
				_pixel(at + Vector2(x, y) * PIXEL, PIXEL, colour)


# A square of the given size, snapped to the art pixel grid.
func _pixel(at: Vector2, size: float, colour: Color) -> void:
	var snapped := (at - global_position).snapped(Vector2(PIXEL, PIXEL))
	draw_rect(Rect2(snapped - Vector2(size, size) / 2.0, Vector2(size, size)), colour)
