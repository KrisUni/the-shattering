class_name MainEntrance
extends StaticBody2D
## The Main entrance: a locked door that is the Dungeons' way out. While shut it is a solid body that
## blocks Almos. A tap of Interact beside it while Almos has the Jailer's key opens it: it stops
## blocking and is drawn open. The opening is not recorded anywhere, so each time the room is built
## the door stands shut again, and with the key a tap opens it once more. It is in the group
## "main_entrances", which is where Almos looks for one.

## What the key that opens it is called in WorldState: the Jailer's key.
@export var key: StringName

var _open := false

## Whether it is open: nothing blocks.
var open: bool:
	get:
		return _open

@onready var _body_shape: CollisionShape2D = $CollisionShape2D
@onready var _look: Node2D = $Look

# The tint of its look when the door stands open, a dim shade of its shut one.
const OPEN_TINT := Color(1.0, 1.0, 1.0, 0.25)


## Opens it if Almos has the key, and says whether it is open now. A door that is open stays open.
func open_with_key() -> bool:
	if not _open and WorldState.is_taken(key):
		_open = true
		set_deferred(&"collision_layer", 0)
		_look.modulate = OPEN_TINT
	return _open


## How far, in pixels, the point (in global coordinates) is from the door's body: zero on or inside
## it. It is measured to the body's edge, not its middle, since the door is wide.
func distance_to(point: Vector2) -> float:
	var half := (_body_shape.shape as RectangleShape2D).size / 2.0
	var local := to_local(point)
	var outside := Vector2(maxf(absf(local.x) - half.x, 0.0), maxf(absf(local.y) - half.y, 0.0))
	return outside.length()
