class_name AlmosLook
extends Node
## Makes Almos's sprite show what he is doing. It looks for an AnimatedSprite2D named Art in his
## Look; with none it does nothing. With one, for the side he faces (`down`, `up` or `side`):
## - while he swings, `attack_<side>` follows the swing's own phases, whatever its length: wind-up
##   over its startup frames, the strike on its active frames, follow-through and recovery after.
##   While he charges a Heavy attack it holds the coiled wind-up;
## - while he winds up a Spell (drawing a flame, gripping a prop) it holds the coiled wind-up of
##   `attack_<side>`, and when he throws (a fireball, a prop) it shows the strike and follow-through
##   for a moment;
## - while he rolls, `roll_<side>` plays once from its first frame each time a roll starts;
## - otherwise `walk_<side>` while he moves and `idle_<side>` while he stands.
## A name the sprite lacks is skipped. Facing left plays the side animations flipped, so they
## are drawn facing right. It only reads Almos: no gameplay depends on it.

# Below this speed, in units a second, he counts as standing. A look, not tuning.
const WALK_SPEED := 5.0
# The frames of an attack animation: the wind-up, the coil before the strike, the strike, the
# follow-through, and the recovery.
const WIND_UP := 0
const COIL := 1
const STRIKE := 2
const FOLLOW_THROUGH := 3
const RECOVER := 4
# For how many physics frames a throw shows the strike, then the follow-through. A look.
const THROW_FRAMES := 12

var _almos: Node
var _attacks: Node
var _art: AnimatedSprite2D
var _was_rolling := false
var _spell: Node
var _throw_left := 0


func _ready() -> void:
	_almos = get_parent().get_parent()
	_attacks = _almos.get_node_or_null("Attacks")
	_spell = _almos.get_node_or_null("Spell")
	if _spell != null:
		if _spell.has_signal(&"fireball_thrown"):
			_spell.fireball_thrown.connect(func(_fireball, _torch) -> void: _throw_left = THROW_FRAMES)
		if _spell.has_signal(&"object_thrown"):
			_spell.object_thrown.connect(func(_prop) -> void: _throw_left = THROW_FRAMES)


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
	if _show_attack(side) or _show_casting(side):
		_was_rolling = false
		return
	if _almos.rolling:
		# A roll plays once from its first frame, each time one starts.
		var roll := StringName("roll_" + side)
		if not _was_rolling or _art.animation != roll:
			_play(roll, true)
		_was_rolling = true
		return
	_was_rolling = false
	var moving: bool = not _almos.dead and (_almos as CharacterBody2D).velocity.length() > WALK_SPEED
	_play(StringName(("walk_" if moving else "idle_") + side))


## Which drawn side shows a facing: `side` when it is more across than up or down (a diagonal
## shows the side), `up` or `down` otherwise.
static func side_for(facing: Vector2) -> StringName:
	if absf(facing.x) >= absf(facing.y) and not is_zero_approx(facing.x):
		return &"side"
	return &"up" if facing.y < 0.0 else &"down"


## Which frame of an attack animation shows this frame of a swing.
static func attack_frame_for(swing: AttackData, frame: int) -> int:
	if swing.is_winding_up(frame):
		return WIND_UP if frame * 2 < swing.startup_frames else COIL
	if swing.is_active(frame):
		return STRIKE
	var into_recovery := frame - swing.startup_frames - swing.active_frames
	return FOLLOW_THROUGH if into_recovery * 3 < swing.recovery_frames else RECOVER


# Shows a swing or a charge, if one is under way. Whether it did.
func _show_attack(side: StringName) -> bool:
	if _attacks == null:
		return false
	var attack := StringName("attack_" + side)
	if _art.sprite_frames == null or not _art.sprite_frames.has_animation(attack):
		return false
	var swing: AttackData = _attacks.swing
	var frame: int
	if swing != null:
		frame = attack_frame_for(swing, _attacks.swing_frame)
	elif _attacks.charging:
		frame = COIL
	else:
		return false
	if _art.animation != attack:
		_art.animation = attack
	_art.pause()
	_art.frame = frame
	return true


# Shows the wind-up of a Spell, or a throw just made. Whether it did.
func _show_casting(side: StringName) -> bool:
	var frame := -1
	if _throw_left > 0:
		_throw_left -= 1
		frame = STRIKE if _throw_left > THROW_FRAMES / 2 else FOLLOW_THROUGH
	elif _spell != null and _spell.get(&"winding_up") == true:
		frame = COIL
	if frame < 0:
		return false
	var attack := StringName("attack_" + side)
	if _art.sprite_frames == null or not _art.sprite_frames.has_animation(attack):
		return false
	if _art.animation != attack:
		_art.animation = attack
	_art.pause()
	_art.frame = frame
	return true


func _play(animation_name: StringName, from_start := false) -> void:
	if _art.sprite_frames == null or not _art.sprite_frames.has_animation(animation_name):
		return
	if from_start:
		_art.stop()
		_art.play(animation_name)
	elif _art.animation != animation_name or not _art.is_playing():
		_art.play(animation_name)
