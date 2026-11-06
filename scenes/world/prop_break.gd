extends Node2D
## The look of a thrown prop breaking apart, such as a barrel: its own art is cut into staves that
## burst outwards, spin, drop to the floor with a bounce and fade, with its hoops rolling off and a
## puff of dust. Only a look; it frees itself when done.

const DUST := Color("8a7f74")
const DUST_LIGHT := Color("b8ab9b")
const HOOP := Color("4a3b33")
const PIXEL := 2.0
const DURATION := 0.9
# When the pieces start to fade, as a share of the duration.
const FADE_FROM := 0.6
const GRAVITY := 520.0
# The width of a stave, in texture pixels.
const STAVE_WIDTH := 3

var _time := 0.0
var _pieces: Array[Dictionary] = []
var _hoops: Array[Dictionary] = []
# Where the floor is under the pieces, in local coordinates: they bounce off it once.
var _floor := 0.0


func _ready() -> void:
	z_index = 3


## Breaks this art (as drawn at this offset and scale, relative to this node) into pieces, flying
## mostly along the way given (the way it was thrown): staves and hoops for a barrel, or, with
## "shards", small broken pieces for something fired, as a clay pot.
func shatter(texture: Texture2D, offset: Vector2, art_scale: Vector2, along: Vector2, kind := &"staves") -> void:
	_floor = 4.0
	var size := texture.get_size()
	var image := texture.get_image()
	if kind == &"shards":
		_shards(texture, image, size, offset, art_scale, along)
		return
	var columns := ceili(size.x / STAVE_WIDTH)
	for i in columns:
		var x := i * STAVE_WIDTH
		var width := mini(STAVE_WIDTH, int(size.x) - x)
		# Each stave is cut in two, top and bottom, so they tumble separately.
		for half in 2:
			var y := 0 if half == 0 else int(size.y / 2.0)
			var height := int(size.y / 2.0) if half == 0 else int(size.y) - y
			var region := Rect2(x, y, width, height)
			if image != null and _empty(image, region):
				continue
			var sprite := Sprite2D.new()
			sprite.texture = texture
			sprite.region_enabled = true
			sprite.region_rect = region
			sprite.scale = art_scale
			sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			var centre := offset + (region.position + region.size / 2.0 - size / 2.0) * art_scale
			sprite.position = centre
			add_child(sprite)
			# Outwards from the middle, nudged along the throw, and up.
			var out := Vector2(centre.x - offset.x, (centre.y - offset.y) * 0.4).normalized()
			if out.is_zero_approx():
				out = Vector2.UP
			var seed := float(i * 2 + half)
			var speed := 70.0 + 50.0 * absf(sin(seed * 1.9))
			var velocity := out * speed + along * 60.0 + Vector2(0.0, -90.0 - 40.0 * absf(cos(seed * 2.7)))
			_pieces.append({
				"sprite": sprite,
				"velocity": velocity,
				"spin": (6.0 + 4.0 * absf(sin(seed))) * (1.0 if out.x >= 0.0 else -1.0),
				"bounced": false,
			})
	# Two hoops roll off, one each way.
	for side in [-1.0, 1.0]:
		_hoops.append({
			"at": offset + Vector2(0.0, side * 6.0),
			"velocity": Vector2(side * 55.0 + along.x * 30.0, -70.0),
			"bounced": false,
		})


# Cuts the art into small, uneven shards that scatter and spin, with no hoops.
func _shards(texture: Texture2D, image: Image, size: Vector2, offset: Vector2, art_scale: Vector2, along: Vector2) -> void:
	var y := 0
	var row := 0
	while y < int(size.y):
		var height := 3 + (row * 5) % 3
		var x := 0
		var column := 0
		while x < int(size.x):
			var width := 3 + (row * 3 + column * 7) % 3
			var region := Rect2(x, y, mini(width, int(size.x) - x), mini(height, int(size.y) - y))
			x += width
			column += 1
			if image != null and _empty(image, region):
				continue
			var sprite := Sprite2D.new()
			sprite.texture = texture
			sprite.region_enabled = true
			sprite.region_rect = region
			sprite.scale = art_scale
			sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			var centre := offset + (region.position + region.size / 2.0 - size / 2.0) * art_scale
			sprite.position = centre
			add_child(sprite)
			var out := Vector2(centre.x - offset.x, (centre.y - offset.y) * 0.5).normalized()
			if out.is_zero_approx():
				out = Vector2.UP
			var seed := float(row * 11 + column)
			var speed := 60.0 + 60.0 * absf(sin(seed * 2.3))
			_pieces.append({
				"sprite": sprite,
				"velocity": out * speed + along * 50.0 + Vector2(0.0, -70.0 - 50.0 * absf(cos(seed * 1.7))),
				"spin": (8.0 + 6.0 * absf(sin(seed))) * (1.0 if out.x >= 0.0 else -1.0),
				"bounced": false,
			})
		y += height
		row += 1


## Whether it has run its course.
func done() -> bool:
	return _time >= DURATION


func _process(delta: float) -> void:
	_time += delta
	if _time >= DURATION:
		queue_free()
		return
	var fade := clampf((_time / DURATION - FADE_FROM) / (1.0 - FADE_FROM), 0.0, 1.0)
	for piece in _pieces:
		var sprite: Sprite2D = piece["sprite"]
		var velocity: Vector2 = piece["velocity"]
		velocity.y += GRAVITY * delta
		var at := sprite.position + velocity * delta
		if at.y > _floor and velocity.y > 0.0:
			at.y = _floor
			if piece["bounced"]:
				velocity = Vector2(velocity.x * 0.6, 0.0)
				piece["spin"] = 0.0
			else:
				velocity = Vector2(velocity.x * 0.5, -velocity.y * 0.35)
				piece["spin"] = piece["spin"] * 0.5
				piece["bounced"] = true
		piece["velocity"] = velocity
		sprite.position = at
		sprite.rotation += piece["spin"] * delta
		# At rest on the floor it lies square, so its pixels stay crisp.
		if piece["spin"] == 0.0:
			sprite.rotation = snappedf(sprite.rotation, PI / 2.0)
		sprite.modulate.a = 1.0 - fade
	for hoop in _hoops:
		var velocity: Vector2 = hoop["velocity"]
		velocity.y += GRAVITY * delta
		var at: Vector2 = hoop["at"] + velocity * delta
		if at.y > _floor and velocity.y > 0.0:
			at.y = _floor
			velocity = Vector2(velocity.x * 0.8, -velocity.y * 0.3 if not hoop["bounced"] else 0.0)
			hoop["bounced"] = true
		hoop["velocity"] = velocity
		hoop["at"] = at
	modulate.a = 1.0
	queue_redraw()


func _draw() -> void:
	var t := _time / DURATION
	var fade := clampf((t - FADE_FROM) / (1.0 - FADE_FROM), 0.0, 1.0)
	# Dust: puffs that swell, rise a little and thin out, over the first half.
	if t < 0.55:
		var d := t / 0.55
		for i in 8:
			if (i + int(_time * 24.0)) % 3 == 0 and d > 0.5:
				continue
			var angle := TAU * i / 8.0 + 0.4
			var reach := lerpf(6.0, 24.0, d) * (0.7 + 0.3 * absf(sin(i * 1.7)))
			var at := Vector2(cos(angle) * reach, sin(angle) * reach * 0.5) + Vector2(0, -d * 8.0)
			_disc(at, lerpf(2.5, 1.0, d), DUST_LIGHT if i % 2 == 0 else DUST)
	# Hoops: thin rings seen edge-on, as short dark bars that wobble as they roll.
	var hoop_colour := Color(HOOP, 1.0 - fade)
	for hoop in _hoops:
		var at: Vector2 = hoop["at"]
		var wobble := int(_time * 20.0) % 2
		for x in range(-3, 4):
			_pixel(at + Vector2(x * PIXEL, (wobble if absf(x) == 3 else 0) * PIXEL), hoop_colour)


func _empty(image: Image, region: Rect2) -> bool:
	for y in range(int(region.position.y), int(region.end.y)):
		for x in range(int(region.position.x), int(region.end.x)):
			if image.get_pixel(x, y).a > 0.0:
				return false
	return true


func _disc(at: Vector2, radius: float, colour: Color) -> void:
	var reach := ceili(radius)
	for y in range(-reach, reach + 1):
		for x in range(-reach, reach + 1):
			if x * x + y * y <= radius * radius + 0.5:
				_pixel(at + Vector2(x, y) * PIXEL, colour)


func _pixel(at: Vector2, colour: Color) -> void:
	var snapped := at.snapped(Vector2(PIXEL, PIXEL))
	draw_rect(Rect2(snapped - Vector2(PIXEL, PIXEL) / 2.0, Vector2(PIXEL, PIXEL)), colour)
