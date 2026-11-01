class_name AlmosLook
extends Node
## Makes Almos's sprite show what he is doing. It looks for an AnimatedSprite2D named Art in his
## Look; with none it does nothing. With one, it plays `walk_<side>` while he moves and
## `idle_<side>` while he stands, where the side is `down`, `up` or `side` from the way he faces
## (a name the sprite lacks is skipped). Facing left plays the side animations flipped, so they
## are drawn facing right. It only reads Almos: no gameplay depends on it.

# Below this speed, in units a second, he counts as standing. A look, not tuning.
const WALK_SPEED := 5.0

var _almos: Node
var _art: AnimatedSprite2D


func _ready() -> void:
	_almos = get_parent().get_parent()


func _physics_process(_delta: float) -> void:
	update_look()


## Shows what Almos is doing on his sprite. Called every physics frame.
func update_look() -> void:
	if _almos == null:
		return
	if _art == null or not is_instance_valid(_art):
		_art = get_parent().get_node_or_null("Art") as AnimatedSprite2D
		if _art == null:
			return
	var side := side_for(_almos.facing)
	# Only the side animations flip; up and down are drawn for themselves.
	_art.flip_h = side == &"side" and (_almos.facing as Vector2).x < 0.0
	var moving: bool = not _almos.dead and (_almos as CharacterBody2D).velocity.length() > WALK_SPEED
	_play(StringName(("walk_" if moving else "idle_") + side))


## Which drawn side shows a facing: `side` when it is more across than up or down (a diagonal
## shows the side), `up` or `down` otherwise.
static func side_for(facing: Vector2) -> StringName:
	if absf(facing.x) >= absf(facing.y) and not is_zero_approx(facing.x):
		return &"side"
	return &"up" if facing.y < 0.0 else &"down"


func _play(animation_name: StringName) -> void:
	if _art.sprite_frames == null or not _art.sprite_frames.has_animation(animation_name):
		return
	if _art.animation != animation_name or not _art.is_playing():
		_art.play(animation_name)
