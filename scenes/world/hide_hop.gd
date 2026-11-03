class_name HideHop
extends Node2D
## How Almos is seen getting into a Hiding spot: only a look. He is in the spot at once as far as the
## game goes (hidden, and where it stands), and this draws a copy of him, as he was drawn the moment
## he got in, hopping there. Into a spot open at the top, a barrel, he crouches, springs up in an arc
## and drops in feet first, sinking below its rim; into a closed one, a wardrobe, he hops to its doors
## and squeezes in between them. Either way the spot jiggles as he lands in it, and then the copy is
## gone. Getting out (pop_out) is drawn on Almos's own look: he springs out of the spot and lands on
## his feet in front of it.

## In seconds: the crouch before the spring, the flight, and the sink into the spot. Looks.
const CROUCH_TIME := 0.07
const FLIGHT_TIME := 0.3
const SINK_TIME := 0.12
## In pixels: how high the arc goes above the spot's rim.
const ARC_HEIGHT := 26.0
## In seconds: the spring out of a spot. A look.
const POP_TIME := 0.26
const POP_HEIGHT := 22.0
## One art pixel in world units.
const PIXEL := 2.0

var _sprite: Sprite2D
var _texture: Texture2D
var _from := Vector2.ZERO
var _to := Vector2.ZERO
var _rim := 0.0
var _from_top := true
var _spot: HidingSpot
var _art_position := Vector2.ZERO


## Draws Almos (his sprite `art`, as it is drawn now) hopping from where he stood, `from`, into the
## spot. It is added to the spot's parent, so it is drawn among the things of the Room.
static func into(spot: HidingSpot, from: Vector2, art: AnimatedSprite2D) -> HideHop:
	if spot == null or art == null or art.sprite_frames == null or not spot.is_inside_tree():
		return null
	var hop := HideHop.new()
	hop._spot = spot
	hop._texture = art.sprite_frames.get_frame_texture(art.animation, art.frame)
	if hop._texture == null:
		return null
	hop._from = from
	hop._to = spot.global_position
	hop._rim = spot.rim_height()
	hop._from_top = spot.open_top
	spot.get_parent().add_child(hop)
	hop.global_position = from
	hop._begin(art)
	return hop


## Draws Almos springing out of the spot onto the place he steps out to: his look starts at the spot's
## rim, small, and arcs down to his feet. His look is his own again at the end.
static func pop_out(look: Node2D, spot: HidingSpot) -> Tween:
	var holder := look.get_parent() as Node2D if look != null else null
	if holder == null or spot == null:
		return null
	var start := spot.global_position + Vector2(0.0, -spot.rim_height()) - holder.global_position
	var tween := look.create_tween()
	tween.tween_method(func(t: float) -> void:
		var arc := -4.0 * POP_HEIGHT * t * (1.0 - t)
		look.position = (start.lerp(Vector2.ZERO, t) + Vector2(0.0, arc)).snappedf(PIXEL)
		# Stretched as he springs, squashed a little as he lands.
		var stretch := 1.0 + 0.25 * sin(t * PI) - 0.15 * smoothstep(0.85, 1.0, t)
		look.scale = Vector2(1.0 / stretch, stretch) * lerpf(0.7, 1.0, smoothstep(0.0, 0.5, t)), 0.0, 1.0, POP_TIME)
	tween.tween_property(look, ^"scale", Vector2.ONE, 0.06)
	tween.parallel().tween_property(look, ^"position", Vector2.ZERO, 0.06)
	spot.jiggle()
	return tween


func _begin(art: AnimatedSprite2D) -> void:
	_sprite = Sprite2D.new()
	_sprite.texture = _texture
	_sprite.flip_h = art.flip_h
	_sprite.centered = art.centered
	_sprite.offset = art.offset
	_sprite.scale = art.scale
	_sprite.position = art.position
	_art_position = art.position
	add_child(_sprite)
	# Drawn over the spot: what sinks below its rim is cut away, not hidden behind it.
	z_index = 3
	var tween := create_tween()
	tween.tween_method(_crouch, 0.0, 1.0, CROUCH_TIME)
	tween.tween_method(_fly, 0.0, 1.0, FLIGHT_TIME)
	tween.tween_callback(_spot.jiggle)
	tween.tween_method(_sink, 0.0, 1.0, SINK_TIME)
	tween.tween_callback(queue_free)


# He crouches, gathering himself for the spring.
func _crouch(t: float) -> void:
	_sprite.scale = Vector2(PIXEL * (1.0 + 0.15 * t), PIXEL * (1.0 - 0.2 * t))


# Up in an arc over to the spot's rim: stretched as he leaves the ground, tucked at the top.
func _fly(t: float) -> void:
	var land := _to + Vector2(0.0, -_rim) if _from_top else _to + Vector2(0.0, -2.0)
	var height := ARC_HEIGHT + (_rim if _from_top else 0.0) * 0.5
	var at := _from.lerp(land, t) + Vector2(0.0, -4.0 * height * t * (1.0 - t))
	global_position = at.snappedf(PIXEL)
	var stretch := 1.0 + 0.2 * (1.0 - t) * (1.0 - t) - 0.1 * sin(t * PI)
	_sprite.scale = Vector2(PIXEL / stretch, PIXEL * stretch)
	_sprite.rotation = 0.0 if _from_top else 0.12 * sin(t * PI)


# Into the spot: feet first below the rim, cut away row by row, or squeezed in between the doors.
func _sink(t: float) -> void:
	if _texture == null:
		return
	if not _from_top:
		_sprite.scale = Vector2(PIXEL * (1.0 - t), PIXEL * (1.0 + 0.1 * t))
		return
	var size := _texture.get_size()
	# How many of his art rows are below the rim now: they are cut away, and the rows left go down
	# with him, so that his cut edge stays on the rim.
	var sunk := clampi(roundi(t * size.y), 0, int(size.y))
	_sprite.scale = Vector2(PIXEL, PIXEL)
	_sprite.rotation = 0.0
	_sprite.region_enabled = true
	_sprite.region_rect = Rect2(0.0, 0.0, size.x, size.y - sunk)
	_sprite.position = _art_position + Vector2(0.0, sunk)
