class_name EnemyLook
extends Node
## Makes an enemy's sprite show what the enemy is doing. It looks for an AnimatedSprite2D named
## Art in the enemy's Look; with none it does nothing, and the enemy tints its whole look as it
## always did. With one, it plays the animation for the enemy's state (idle, walk, strike, low,
## unblockable, break, hurt, death; a name the sprite lacks is skipped) and draws the wind-up
## flashes on the sprite itself, in palette colours, with a shader that leaves its alpha alone.
## It only reads the enemy and the sprite: no gameplay depends on it.

# The palette's lightest colour (the white flash) and its Danger red. Looks, not tuning.
const CREAM := Color("fbf5ef")
const DANGER_RED := Color("d62839")

# For this many physics frames from the start of a normal wind-up, or of a Break, it flashes
# cream. An Unblockable attack flashes cream for the tuning's unblockable_flash_frames. A look.
const FLASH_FRAMES := 6

const FLASH_SHADER := preload("res://assets/shared/flash/flash.gdshader")

## The colour flashed on the sprite now, and how far toward it the sprite is mixed: 1 all the way,
## 0 not at all.
var flash_color := CREAM
var flash_amount := 0.0

var _enemy: Node
var _art: AnimatedSprite2D
var _material: ShaderMaterial
var _broken_frames := 0
var _shown_attack_frame := -1


func _ready() -> void:
	_enemy = get_parent().get_parent()


func _physics_process(_delta: float) -> void:
	update_look()


## Shows the enemy's state on its sprite. Called every physics frame, after the enemy has moved
## on, since the enemy is this node's parent's parent and is processed first.
func update_look() -> void:
	if _enemy == null:
		return
	if _art == null or not is_instance_valid(_art):
		_art = get_parent().get_node_or_null("Art") as AnimatedSprite2D
		if _art == null:
			return
		_material = ShaderMaterial.new()
		_material.shader = FLASH_SHADER
		_art.material = _material
	_turn_with_enemy()
	_broken_frames = _broken_frames + 1 if _enemy.broken else 0
	_show_flash()
	_play(_animation_name())


# The sprite faces left or right with the enemy, and only flips: the enemy itself is not turned.
# Facing straight up or down keeps the side it had.
func _turn_with_enemy() -> void:
	var facing: Vector2 = _enemy.facing
	if not is_zero_approx(facing.x):
		_art.flip_h = facing.x < 0.0


# The animation for what the enemy is doing now.
func _animation_name() -> StringName:
	if _enemy.dead:
		return &"death"
	if _enemy.broken:
		return &"break"
	if _enemy.attacking:
		match _enemy.attack_kind:
			EnemyTuning.AttackKind.LOW:
				return &"low"
			EnemyTuning.AttackKind.UNBLOCKABLE:
				return &"unblockable"
		return &"strike"
	if not (_enemy as CharacterBody2D).velocity.is_zero_approx():
		return &"walk"
	return &"idle"


# Plays this animation, if the sprite has it. It starts over when it changes and at the first
# frame of every attack, such as each swing of a combo.
func _play(animation: StringName) -> void:
	var frames := _art.sprite_frames
	if frames == null or not frames.has_animation(animation):
		return
	var attack_frame: int = _enemy.attack_frame
	var new_swing: bool = attack_frame == 0 and _shown_attack_frame != 0
	_shown_attack_frame = attack_frame
	if _art.animation != animation or new_swing or not _art.is_playing():
		_art.play(animation)


# The flash: cream at the start of a wind-up or a Break, and for an Unblockable attack Danger
# red from the end of the cream to the end of the wind-up.
func _show_flash() -> void:
	var amount := 0.0
	var colour := CREAM
	if _enemy.dead:
		amount = 0.0
	elif _enemy.broken:
		amount = 1.0 if _broken_frames <= FLASH_FRAMES else 0.0
	elif _enemy.winding_up:
		var frame: int = _enemy.attack_frame
		if _enemy.attack_kind == EnemyTuning.AttackKind.UNBLOCKABLE:
			if frame >= _enemy.tuning.unblockable_flash_frames:
				colour = DANGER_RED
			amount = 1.0
		else:
			amount = 1.0 if frame < FLASH_FRAMES else 0.0
	flash_color = colour
	flash_amount = amount
	_material.set_shader_parameter(&"flash_color", colour)
	_material.set_shader_parameter(&"flash_amount", amount)
