class_name Darkness
extends Node2D
## The dark of a Room that is not seen all at once: everything in it is black but a circle around
## Almos, and within it nothing behind a wall of the Room that is marked to hide what is behind it
## (its `hides_beyond` metadata set true), though the wall's own face shows. Only walls tall enough to
## read as cutting off the view are marked, such as the one between Corridor 2's two roads: a low
## block or a door's jamb casting long shadows would look wrong in the three-quarter view. Torches
## and Fires show no light through it: only he sees. The circle's edge fades softly
## and wide, in fine dithered steps on the art pixel grid. Only a look: what enemies see
## by is the gameplay light (LightZone.light_at), not this.
##
## It covers the Room it is in, drawn over everything in the world (the HUD and thoughts are on
## their own layers, above it). The Building gives it Almos to follow; with none it shows nothing
## through, so a Room on its own is simply dark.

## Drawn over every other thing in the world.
const Z := 4000

## In pixels: how far Almos sees around himself in the dark.
@export var sight_radius := 340.0
## In pixels: where his sight starts to fade, from the outer edge inward.
@export var sight_fade := 220.0
## How dark the dark is.
@export var shade := Color(0.02, 0.02, 0.035, 1.0)
## The extent it covers, from the Room's top left corner; by default the Room's own size.
@export var size := Vector2.ZERO

## Who sees: his circle is cut out of the dark.
var target: Node2D

# Where his eyes are, above his feet.
const EYE_OFFSET := Vector2(0.0, -12.0)

const SHADER := """
shader_type canvas_item;

uniform vec2 eye;
uniform float eye_radius;
uniform float eye_fade;
uniform vec4 shade : source_color;
// The Room's walls, as rectangles (x, y, width, height) in world units, and how many there are.
uniform vec4 walls[MOST_WALLS];
uniform int wall_count;

varying vec2 world;

void vertex() {
	world = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

// How much of a circle sees this point: 1 inside its core, falling to 0 at its edge.
float seen(vec2 p, vec2 centre, float radius, float fade) {
	float d = length(p - centre);
	return clamp((radius - d) / max(fade, 1.0), 0.0, 1.0);
}

// Whether the line from a to b passes through this rectangle (x, y, width, height) on its way:
// a rectangle holding either end does not hide it, so a wall's own face shows.
bool blocks(vec2 a, vec2 b, vec4 r) {
	vec2 low = r.xy;
	vec2 high = r.xy + r.zw;
	if (all(greaterThanEqual(b, low)) && all(lessThanEqual(b, high))) {
		return false;
	}
	if (all(greaterThanEqual(a, low)) && all(lessThanEqual(a, high))) {
		return false;
	}
	vec2 d = b - a;
	float t0 = 0.0;
	float t1 = 1.0;
	for (int i = 0; i < 2; i++) {
		if (abs(d[i]) < 0.0001) {
			if (a[i] < low[i] || a[i] > high[i]) {
				return false;
			}
		} else {
			float ta = (low[i] - a[i]) / d[i];
			float tb = (high[i] - a[i]) / d[i];
			t0 = max(t0, min(ta, tb));
			t1 = min(t1, max(ta, tb));
		}
	}
	return t0 < t1;
}

void fragment() {
	// On the art pixel grid: one value for every 2x2 block.
	vec2 cell = floor(world / 2.0);
	vec2 p = cell * 2.0 + 1.0;
	// Eased, so the light thins out gently into the dark with no ring at either end of the fade.
	float see = smoothstep(0.0, 1.0, seen(p, eye, eye_radius, eye_fade));
	for (int i = 0; i < MOST_WALLS; i++) {
		if (i >= wall_count || see <= 0.0) {
			break;
		}
		if (blocks(eye, p, walls[i])) {
			see = 0.0;
		}
	}
	// Many fine steps, spread by a 4x4 ordered dither so that no step reads as an edge.
	int bx = int(mod(cell.x, 4.0));
	int by = int(mod(cell.y, 4.0));
	int bayer[16] = int[16](0, 8, 2, 10, 12, 4, 14, 6, 3, 11, 1, 9, 15, 7, 13, 5);
	float dither = (float(bayer[by * 4 + bx]) + 0.5) / 16.0;
	float band = clamp(floor(see * 8.0 + dither) / 8.0, 0.0, 1.0);
	COLOR = vec4(shade.rgb, shade.a * (1.0 - band));
}
"""

## The most walls a Room's dark takes into account.
const MOST_WALLS := 48

static var _shader: Shader

# The Room's walls, in the Room's own coordinates (its parent's), so they follow it wherever the
# Building puts it.
var _walls: Array[Rect2] = []

var _material: ShaderMaterial


func _ready() -> void:
	if size == Vector2.ZERO:
		var room := get_parent() as Room
		size = room.size if room != null else get_viewport_rect().size
	z_index = Z
	z_as_relative = false
	if _shader == null:
		_shader = Shader.new()
		_shader.code = SHADER.replace("MOST_WALLS", str(MOST_WALLS))
	_material = ShaderMaterial.new()
	_material.shader = _shader
	material = _material
	_collect_walls()
	_update()
	queue_redraw()


func _process(_delta: float) -> void:
	if visible:
		_update()


## Where Almos's eyes are, in global coordinates: the middle of his circle.
func eye() -> Vector2:
	if not is_instance_valid(target):
		return Vector2(INF, INF)
	return target.global_position + EYE_OFFSET


## Whether this point (global coordinates) is seen through the dark: in Almos's circle, the edge
## left out, and with none of the Room's walls between him and it.
func shows(point: Vector2) -> bool:
	if eye().distance_to(point) >= sight_radius:
		return false
	for wall in _global_walls():
		if _blocks(eye(), point, wall):
			return false
	return true


func _global_walls() -> Array[Rect2]:
	var origin := (get_parent() as Node2D).global_position if get_parent() is Node2D else Vector2.ZERO
	var rects: Array[Rect2] = []
	for wall in _walls:
		rects.append(Rect2(wall.position + origin, wall.size))
	return rects


# The Room's walls that hide what is behind them: each collision rectangle of a StaticBody2D under
# its Walls node with `hides_beyond` set.
func _collect_walls() -> void:
	_walls.clear()
	var walls := get_parent().get_node_or_null("Walls") if get_parent() != null else null
	if walls == null:
		return
	for body in walls.get_children():
		if not body is StaticBody2D or body.get_meta(&"hides_beyond", false) != true:
			continue
		for child in body.get_children():
			var shape := child as CollisionShape2D
			if shape != null and shape.shape is RectangleShape2D:
				var extent := (shape.shape as RectangleShape2D).size
				var centre: Vector2 = (body as Node2D).position + shape.position
				_walls.append(Rect2(centre - extent / 2.0, extent))
	if _walls.size() > MOST_WALLS:
		push_warning("%s has more walls than its dark takes into account" % get_parent().name)
		_walls.resize(MOST_WALLS)


# As the shader's blocks(): whether the line from a to b passes through the rectangle on its way.
static func _blocks(a: Vector2, b: Vector2, rect: Rect2) -> bool:
	var edge := rect.grow(0.01)
	if edge.has_point(b) or edge.has_point(a):
		return false
	var t0 := 0.0
	var t1 := 1.0
	var d := b - a
	for i in 2:
		if absf(d[i]) < 0.0001:
			if a[i] < rect.position[i] or a[i] > rect.end[i]:
				return false
		else:
			var ta := (rect.position[i] - a[i]) / d[i]
			var tb := (rect.end[i] - a[i]) / d[i]
			t0 = maxf(t0, minf(ta, tb))
			t1 = minf(t1, maxf(ta, tb))
	return t0 < t1


func _update() -> void:
	if _material == null:
		return
	_material.set_shader_parameter(&"eye", eye())
	_material.set_shader_parameter(&"eye_radius", sight_radius)
	_material.set_shader_parameter(&"eye_fade", sight_fade)
	_material.set_shader_parameter(&"shade", shade)
	var rects := PackedVector4Array()
	for wall in _global_walls():
		rects.append(Vector4(wall.position.x, wall.position.y, wall.size.x, wall.size.y))
	while rects.size() < MOST_WALLS:
		rects.append(Vector4.ZERO)
	_material.set_shader_parameter(&"walls", rects)
	_material.set_shader_parameter(&"wall_count", _walls.size())


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color.WHITE)
