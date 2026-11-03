class_name Darkness
extends Node2D
## The dark of a Room that is not seen all at once: everything in it is black but a circle around
## Almos. Torches and Fires show no light through it: only he sees. The circle's edge fades in
## dithered steps on the art pixel grid, as the lamps' own glow does. Only a look: what enemies see
## by is the gameplay light (LightZone.light_at), not this.
##
## It covers the Room it is in, drawn over everything in the world (the HUD and thoughts are on
## their own layers, above it). The Building gives it Almos to follow; with none it shows nothing
## through, so a Room on its own is simply dark.

## Drawn over every other thing in the world.
const Z := 4000

## In pixels: how far Almos sees around himself in the dark.
@export var sight_radius := 240.0
## In pixels: where his sight starts to fade, from the outer edge inward.
@export var sight_fade := 96.0
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


## Whether this point (global coordinates) is seen through the dark: in Almos's circle, the edge
## left out.
func shows(point: Vector2) -> bool:
	return eye().distance_to(point) < sight_radius


func _update() -> void:
	if _material == null:
		return
	_material.set_shader_parameter(&"eye", eye())
	_material.set_shader_parameter(&"eye_radius", sight_radius)
	_material.set_shader_parameter(&"eye_fade", sight_fade)
	_material.set_shader_parameter(&"shade", shade)


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color.WHITE)
