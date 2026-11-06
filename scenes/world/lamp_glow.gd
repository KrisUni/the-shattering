extends Sprite2D
## The warm pool of light a burning torch or lamp throws: a dithered amber disc, added onto what is
## under it, that flickers with the flame. It hangs under the torch's Flame, so it shows only while
## the flame burns. Only a look: the gameplay light is the torch's own.

const AMBER := Color(0.95, 0.6, 0.25)
# In art pixels: the texture's radius, drawn at scale 2.
const RADIUS := 36

## How bright the pool is at its heart, before the flicker.
@export var strength := 0.34
## How far it flickers, as a share of its brightness.
@export var flicker := 0.18

const MOTES := preload("res://scenes/world/lamp_motes.gd")

static var _shared: Texture2D

var _time := 0.0
var _seed := 0.0


func _ready() -> void:
	if _shared == null:
		_shared = _make_texture()
	texture = _shared
	scale = Vector2(2.0, 2.0)
	z_index = -1
	var add := CanvasItemMaterial.new()
	add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	material = add
	_seed = fposmod(global_position.x * 0.37 + global_position.y * 0.11, 10.0)
	# Motes of dust drift in its light and catch it.
	var motes := Node2D.new()
	motes.name = "Motes"
	motes.set_script(MOTES)
	add_child(motes)


func _process(delta: float) -> void:
	_time += delta
	# Two slow waves and a quick one, so no two lamps flicker alike.
	var t := _time + _seed
	var wave := 0.5 * sin(t * 2.3) + 0.3 * sin(t * 5.1 + 1.7) + 0.2 * sin(t * 13.0)
	var a := strength * (1.0 + flicker * wave)
	self_modulate = Color(1.0, 1.0, 1.0, clampf(a, 0.0, 1.0))
	var breathe := 1.0 + 0.03 * sin(t * 3.0)
	scale = Vector2(2.0, 2.0) * breathe


# A disc that fades from its heart to its rim in dithered steps, on the art pixel grid.
static func _make_texture() -> Texture2D:
	var size := RADIUS * 2
	var image := Image.create(size, size, false, Image.FORMAT_RGBA8)
	for y in size:
		for x in size:
			var d := Vector2(x - RADIUS + 0.5, y - RADIUS + 0.5).length() / RADIUS
			if d >= 1.0:
				continue
			var level := 1.0 - d
			# Four bands, dithered at their edges.
			var band := floorf(level * 4.0 + (0.5 if (x + y) % 2 == 0 else 0.0)) / 4.0
			if band <= 0.0:
				continue
			image.set_pixel(x, y, Color(AMBER, band * band))
	return ImageTexture.create_from_image(image)
