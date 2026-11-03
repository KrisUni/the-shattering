class_name Darkness
extends Node2D
## The dark of a Room that is not seen all at once: everything in it is black but a small circle
## around Almos, and the pools of light that lit torches and Fires throw. The edge of each circle
## fades in dithered steps on the art pixel grid, as the lamps' own glow does. Only a look: what
## enemies see by is the gameplay light (LightZone.light_at), not this.
##
## It covers the Room it is in, drawn over everything in the world (the HUD and thoughts are on
## their own layers, above it). The Building gives it Almos to follow; with none it shows nothing
## through, so a Room on its own is simply dark.

## How many pools of light it shows besides Almos's own circle: the nearest to him.
const MAX_LIGHTS := 16
## Drawn over every other thing in the world.
const Z := 4000

## In pixels: how far Almos sees around himself in the dark.
@export var sight_radius := 96.0
## In pixels: where his sight starts to fade, from the outer edge inward.
@export var sight_fade := 40.0
## How far a torch's or a Fire's pool of light shows, as a share of its gameplay light radius.
@export var light_reach := 1.0
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
uniform int light_count;
uniform vec4 lights[16];
uniform vec4 shade : source_color;

varying vec2 world;

void vertex() {
	world = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

// How much of a circle sees this point: 1 inside its core, falling to 0 at its edge.
float seen(vec2 p, vec2 centre, float radius, float fade) {
	float d = length(p - centre);
	return clamp((radius - d) / max(fade, 1.0), 0.0, 1.0);
}

void fragment() {
	// On the art pixel grid: one value for every 2x2 block.
	vec2 cell = floor(world / 2.0);
	vec2 p = cell * 2.0 + 1.0;
	float see = seen(p, eye, eye_radius, eye_fade);
	for (int i = 0; i < light_count; i++) {
		vec4 light = lights[i];
		see = max(see, seen(p, light.xy, light.z, light.z * 0.5));
	}
	// Four bands, dithered at their edges.
	float dither = mod(cell.x + cell.y, 2.0) * 0.5;
	float band = clamp(floor(see * 4.0 + dither) / 4.0, 0.0, 1.0);
	COLOR = vec4(shade.rgb, shade.a * (1.0 - band));
}
"""

static var _shader: Shader

var _material: ShaderMaterial


func _ready() -> void:
	if size == Vector2.ZERO:
		var room := get_parent() as Room
		size = room.size if room != null else get_viewport_rect().size
	z_index = Z
	z_as_relative = false
	if _shader == null:
		_shader = Shader.new()
		_shader.code = SHADER
	_material = ShaderMaterial.new()
	_material.shader = _shader
	material = _material
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


## The pools of light it shows now, nearest to Almos first, as [centre, radius] in global coordinates:
## every lit torch (his own and a held flame among them) and every Fire, inside what it covers.
func pools() -> Array:
	var found := []
	var area := Rect2(global_position, size)
	for torch in get_tree().get_nodes_in_group(&"torches"):
		if not torch.get(&"lit"):
			continue
		var radius: float = torch.get(&"radius")
		_add_pool(found, area, (torch as Node2D).global_position, radius * light_reach)
	for fire in get_tree().get_nodes_in_group(&"fires"):
		if not fire.get(&"burning"):
			continue
		var tuning = fire.get(&"tuning")
		var radius: float = tuning.get(&"light_radius") if tuning != null else 0.0
		_add_pool(found, area, (fire as Node2D).global_position, radius * light_reach)
	var from := eye()
	found.sort_custom(func(a: Array, b: Array) -> bool:
		return (a[0] as Vector2).distance_squared_to(from) < (b[0] as Vector2).distance_squared_to(from))
	return found.slice(0, MAX_LIGHTS)


## Whether this point (global coordinates) is seen through the dark: in Almos's circle or in a pool
## of light, the edge left out.
func shows(point: Vector2) -> bool:
	if eye().distance_to(point) < sight_radius:
		return true
	for pool in pools():
		if (pool[0] as Vector2).distance_to(point) < pool[1]:
			return true
	return false


func _add_pool(found: Array, area: Rect2, centre: Vector2, radius: float) -> void:
	if radius <= 0.0 or not area.grow(radius).has_point(centre):
		return
	found.append([centre, radius])


func _update() -> void:
	if _material == null:
		return
	var lit := PackedVector4Array()
	for pool in pools():
		var centre: Vector2 = pool[0]
		lit.append(Vector4(centre.x, centre.y, pool[1], 0.0))
	var count := lit.size()
	lit.resize(MAX_LIGHTS)
	_material.set_shader_parameter(&"eye", eye())
	_material.set_shader_parameter(&"eye_radius", sight_radius)
	_material.set_shader_parameter(&"eye_fade", sight_fade)
	_material.set_shader_parameter(&"light_count", count)
	_material.set_shader_parameter(&"lights", lit)
	_material.set_shader_parameter(&"shade", shade)


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color.WHITE)
