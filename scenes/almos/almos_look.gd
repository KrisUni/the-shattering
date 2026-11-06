class_name AlmosLook
extends Node
## Makes Almos's sprite show what he is doing. It looks for an AnimatedSprite2D named Art in his
## Look; with none it does nothing. With one, for the side he faces (`down`, `up` or `side`):
## - while he swings, `attack_<side>` follows the swing's own phases, whatever its length: wind-up
##   over its startup frames, the strike on its active frames, follow-through and recovery after.
##   While he charges a Heavy attack it holds the coiled wind-up. With a Weapon in hand whose look
##   names a swing of its own (the sword's is `sword`), it plays `attack_<look>_<side>` instead;
## - while he winds up a Spell (drawing a flame, gripping a prop) it holds the coiled wind-up of
##   `attack_<side>`, and when he throws (a fireball, a prop) it shows the strike and follow-through
##   for a moment;
## - for a moment after he casts Pull or Shove on an enemy or a thing (or at nothing), `pull_<side>`
##   or `shove_<side>` shows a small gesture of the hands: Shove gathers them and pushes the palms
##   out, Pull reaches out, closes on it and draws them in;
## - while he rolls, `walk_<side>` plays from its first frame each time a roll starts: a Roll is a
##   vanishing dash, made upright, not tumbling: he fades out and back in (Almos's dash_visibility), and leaves a
##   trail of dark, shadowy copies of himself along its path, each fading away;
## - for a moment after he loses Health, `hurt_<side>`: he flinches back from the hit and gathers
##   himself;
## - in the air, `jump_<side>`: a crouch to spring from, tucked with the arms up, a crouch to land;
## - while he Blocks, `block_<side>`: weight down, both forearms up before him;
## - while he Parries, `parry_<side>`: the forearm swept out across the blow while the window is
##   open, then drawn back;
## - while he Sips, `sip_<side>`, once: the Flask to his mouth, the head tipped back to drink;
## - while he holds a prop over his head, `hold_<side>`, walking with it or standing (a held flame
##   burns at his own place, so with one he walks and stands as ever);
## - when he dies, `death_<side>`, once: he buckles, drops to his knees and falls on his side (not
##   in a fall down a Drop, which shows itself);
## - out of breath and standing, `winded_<side>`: bent over, hands on his knees, his back heaving;
## - otherwise `sprint_<side>` while he Sprints, `walk_<side>` while he walks, and `idle_<side>` while
##   he stands; after he has stood still a while he fidgets, once, with `fidget_<side>`.
## Dust kicks up from his feet as he Sprints, sets off or pulls up from a Sprint, and as he takes off
## and lands from a Jump, and landing dips his figure a pixel or two into the crouch.
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
# For how many physics frames a Pull or Shove gesture shows, and from which of them its second and
# third frames show. A look.
const GESTURE_FRAMES := 18
const GESTURE_KEY := 4
const GESTURE_EASE := 12
# The shadow trail a dash leaves: a copy every this many physics frames, how long each takes to
# fade, in seconds, how much of it shows at first, and its tint, a deep violet shadow. A look.
const SHADOW_EVERY := 2
const SHADOW_FADE := 0.45
const SHADOW_ALPHA := 0.7
const SHADOW_TINT := Color(0.16, 0.1, 0.28)
# For how many physics frames a flinch shows, and from which its second frame shows. A look.
const HURT_FRAMES := 16
const HURT_KEY := 6
# How long he stands still before he fidgets, in seconds, and how much longer each wait can be. A look.
const FIDGET_AFTER := 5.0
const FIDGET_SPREAD := 3.0
# The fraction of a Jump that shows the spring, and from which the landing crouch shows. A look.
const JUMP_SPRING := 0.18
const JUMP_LAND := 0.82
# The frames of a Sprint's stride where a foot strikes the ground and kicks up dust. A look.
const STRIDE_STRIKES := [0, 3]
# How long the landing's dip lasts, in physics frames, and how deep it goes at first, in art pixels.
const DIP_FRAMES := 6
const DIP_DEPTH := 2.0

var _almos: Node
var _attacks: Node
var _art: AnimatedSprite2D
var _was_rolling := false
# Physics frames since the dash began, for spacing its shadows.
var _dash_frame := 0
var _spell: Node
var _throw_left := 0
# The gesture of the last Pull or Shove, and how many physics frames it has shown for, or -1.
var _gesture := &""
var _gesture_frame := -1
var _jump: Node
var _health: Node
var _last_health := -1.0
# Physics frames of the flinch from a hit still to show, or 0.
var _hurt_left := 0
# Seconds he has stood still, toward a fidget, and how long this wait is.
var _still_for := 0.0
var _fidget_after := FIDGET_AFTER
var _fidgeting := false
var _was_moving := false
var _was_sprinting := false
var _was_airborne := false
var _last_stride_frame := -1
# Physics frames of the landing's dip still to show, or 0.
var _dip_left := 0


func _ready() -> void:
	_almos = get_parent().get_parent()
	_attacks = _almos.get_node_or_null("Attacks")
	_spell = _almos.get_node_or_null("Spell")
	if _spell != null:
		if _spell.has_signal(&"fireball_thrown"):
			_spell.fireball_thrown.connect(func(_fireball, _torch) -> void: _throw_left = THROW_FRAMES)
		if _spell.has_signal(&"object_thrown"):
			_spell.object_thrown.connect(func(_prop) -> void: _throw_left = THROW_FRAMES)
		if _spell.has_signal(&"wave_sent"):
			_spell.wave_sent.connect(_begin_gesture)
	_jump = _almos.get_node_or_null("Jump")
	if _jump != null and _jump.has_signal(&"landed"):
		_jump.landed.connect(_on_landed)
	_health = _almos.get_node_or_null("Health")
	if _health != null and _health.has_signal(&"changed"):
		_health.changed.connect(_on_health_changed)
		_last_health = float(_health.get(&"current"))


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
	_show_dip()
	var visibility: Variant = _almos.get(&"dash_visibility")
	_art.modulate.a = float(visibility) if visibility != null else 1.0
	var side := side_for(_almos.facing)
	# Only the side animations flip; up and down are drawn for themselves.
	_art.flip_h = side == &"side" and (_almos.facing as Vector2).x < 0.0
	if _show_attack(side) or _show_casting(side):
		_was_rolling = false
		_gesture_frame = -1
		return
	if _almos.rolling or _almos.dead:
		_gesture_frame = -1
	if _almos.dead and not _almos.rolling:
		_was_rolling = false
		if _almos.get(&"falling_down_a_drop") != true:
			_play(StringName("death_" + side), _art.animation != StringName("death_" + side))
		return
	if _show_gesture(side):
		_was_rolling = false
		return
	if _almos.rolling:
		# A dash: he stays upright, striding, so that each shadow he leaves is his figure.
		var stride := StringName("walk_" + side)
		if not _was_rolling or _art.animation != stride:
			_play(stride, true)
		_dash_frame = 0 if not _was_rolling else _dash_frame + 1
		if _dash_frame % SHADOW_EVERY == 0:
			_leave_shadow()
		_was_rolling = true
		return
	_was_rolling = false
	if _show_hurt(side) or _show_jump(side):
		_still_for = 0.0
		_fidgeting = false
		return
	if _almos.get(&"parrying") == true and _hold(StringName("parry_" + side), 0 if _almos.get(&"parry_window_open") == true else 1):
		_still_for = 0.0
		_fidgeting = false
		return
	if _almos.get(&"blocking") == true and _hold(StringName("block_" + side), 0):
		_still_for = 0.0
		_fidgeting = false
		return
	if _almos.get(&"sipping") == true and _has(StringName("sip_" + side)):
		_play(StringName("sip_" + side), _art.animation != StringName("sip_" + side))
		_still_for = 0.0
		_fidgeting = false
		return
	var moving: bool = not _almos.dead and (_almos as CharacterBody2D).velocity.length() > WALK_SPEED
	var sprinting: bool = moving and _almos.get(&"sprinting") == true
	# A prop he lifts floats over his head, so his arms go up to it; a held flame burns at his own
	# place, so he moves as ever with it.
	var holding_a_prop: bool = _spell != null and _spell.get(&"holding") == true and _spell.get(&"holding_flame") != true
	if holding_a_prop and _has(StringName("hold_" + side)):
		_still_for = 0.0
		_fidgeting = false
		if moving:
			_play(StringName("hold_" + side))
		else:
			_hold(StringName("hold_" + side), 0)
		_was_moving = moving
		_was_sprinting = false
		return
	if moving:
		_still_for = 0.0
		_fidgeting = false
		var stride := StringName(("sprint_" if sprinting else "walk_") + side)
		if not _has(stride):
			stride = StringName("walk_" + side)
		_play(stride)
		if sprinting:
			if not _was_sprinting:
				_kick(-(_almos.facing as Vector2), 3)
			if _art.frame != _last_stride_frame and _art.frame in STRIDE_STRIKES:
				_kick(-(_almos.facing as Vector2), 2)
		_last_stride_frame = _art.frame
	else:
		if _was_sprinting:
			# Pulling up from a run: a skid of dust ahead of his feet.
			_kick(_almos.facing as Vector2, 3)
		_stand(side)
	_was_moving = moving
	_was_sprinting = sprinting


# He stands: idle, and now and then, after a still while, a fidget, once, before idling again;
# out of breath, bent over getting it back.
func _stand(side: StringName) -> void:
	if _almos.get(&"out_of_breath") == true and _has(StringName("winded_" + side)):
		_fidgeting = false
		_still_for = 0.0
		_play(StringName("winded_" + side))
		return
	var fidget := StringName("fidget_" + side)
	var awake: bool = (_almos as Node).is_physics_processing() and not _almos.dead
	if _fidgeting:
		if _art.animation == fidget and _art.is_playing():
			return
		_fidgeting = false
		_still_for = 0.0
		_fidget_after = FIDGET_AFTER + FIDGET_SPREAD * fposmod(sin(float(Time.get_ticks_msec()) * 0.001) * 43758.5, 1.0)
	if awake:
		_still_for += get_physics_process_delta_time()
	if awake and _still_for >= _fidget_after and _has(fidget):
		_fidgeting = true
		_play(fidget, true)
		return
	_play(StringName("idle_" + side))


func _has(animation_name: StringName) -> bool:
	return _art.sprite_frames != null and _art.sprite_frames.has_animation(animation_name)


# Holds one frame of an animation. Whether it has it.
func _hold(animation_name: StringName, frame: int) -> bool:
	if _art.sprite_frames == null or not _art.sprite_frames.has_animation(animation_name):
		return false
	if _art.animation != animation_name:
		_art.animation = animation_name
	_art.pause()
	_art.frame = mini(frame, _art.sprite_frames.get_frame_count(animation_name) - 1)
	return true


func _on_health_changed() -> void:
	var now := float(_health.get(&"current"))
	if now < _last_health and not _almos.dead:
		_hurt_left = HURT_FRAMES
	_last_health = now


# The flinch from a hit, for its few frames. Whether it showed.
func _show_hurt(side: StringName) -> bool:
	if _hurt_left <= 0 or _almos.dead:
		_hurt_left = 0
		return false
	_hurt_left -= 1
	return _hold(StringName("hurt_" + side), 0 if HURT_FRAMES - _hurt_left <= HURT_KEY else 1)


# The Jump's poses, picked from how far through it he is, and dust as he springs. Whether it showed.
func _show_jump(side: StringName) -> bool:
	var airborne: bool = _almos.get(&"airborne") == true
	if airborne and not _was_airborne:
		_kick(Vector2.ZERO, 3, 5.0)
	_was_airborne = airborne
	if not airborne or _jump == null:
		return false
	var progress := float(_jump.get(&"progress"))
	var frame := 0 if progress < JUMP_SPRING else (2 if progress >= JUMP_LAND else 1)
	return _hold(StringName("jump_" + side), frame)


func _on_landed(in_a_gap: bool) -> void:
	if in_a_gap:
		return
	_kick(Vector2.ZERO, 6, 9.0)
	_dip_left = DIP_FRAMES


# The landing's dip: his figure a pixel or two down into the crouch, coming back up.
func _show_dip() -> void:
	if _dip_left <= 0:
		if _art.position.y != 0.0:
			_art.position.y = 0.0
		return
	_dip_left -= 1
	_art.position.y = ceilf(DIP_DEPTH * float(_dip_left) / float(DIP_FRAMES))


# Dust kicked up at his feet, going mostly this way (zero for all round).
func _kick(way: Vector2, motes: int, reach := 6.0) -> void:
	var world := (_almos as Node).get_parent()
	if world == null or not (_almos as Node).is_inside_tree():
		return
	var feet := (_almos as Node2D).global_position + Vector2(0.0, 2.0)
	DustPuff.kick(world, feet + way * 4.0, motes, reach, way)


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
	var attack := _attack_for(side)
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


# The attack animation for the side: the Weapon in hand's own, if it has one drawn, or the plain one.
func _attack_for(side: StringName) -> StringName:
	var weapons: Node = _almos.get_node_or_null("Weapons")
	var weapon: WeaponData = weapons.get(&"in_hand") if weapons != null else null
	if weapon != null and weapon.look != &"" and _art.sprite_frames != null:
		var own := StringName("attack_%s_%s" % [weapon.look, side])
		if _art.sprite_frames.has_animation(own):
			return own
	return StringName("attack_" + side)


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


func _begin_gesture(pulling: bool, target: Node2D) -> void:
	_gesture = &"pull_" if pulling else &"shove_"
	_gesture_frame = 0
	# What a Shove sends flying leaves the air rippling in its wake.
	if not pulling and target != null and is_instance_valid(target) and target.get_parent() != null:
		AirRipple.trail(target.get_parent(), target)


# Shows the gesture of a Pull or Shove just cast, for its few frames. Whether it did.
func _show_gesture(side: StringName) -> bool:
	if _gesture_frame < 0:
		return false
	var frame := 0 if _gesture_frame < GESTURE_KEY else (1 if _gesture_frame < GESTURE_EASE else 2)
	_gesture_frame += 1
	if _gesture_frame >= GESTURE_FRAMES:
		_gesture_frame = -1
	var gesture := StringName(_gesture + side)
	if _art.sprite_frames == null or not _art.sprite_frames.has_animation(gesture):
		return false
	if _art.animation != gesture:
		_art.animation = gesture
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


# Leaves a still, dark copy of him as he looks now, where he is, fading away: one of the shadows of a dash.
func _leave_shadow() -> void:
	var world := (_almos as Node).get_parent()
	if world == null or _art.sprite_frames == null or not _art.sprite_frames.has_animation(_art.animation):
		return
	var ghost := Sprite2D.new()
	ghost.texture = _art.sprite_frames.get_frame_texture(_art.animation, _art.frame)
	ghost.centered = _art.centered
	ghost.offset = _art.offset
	ghost.flip_h = _art.flip_h
	ghost.z_index = (_almos as Node2D).z_index
	ghost.modulate = Color(SHADOW_TINT, SHADOW_ALPHA)
	world.add_child(ghost)
	ghost.global_transform = _art.global_transform
	var fade := ghost.create_tween()
	fade.tween_property(ghost, "modulate:a", 0.0, SHADOW_FADE)
	fade.tween_callback(ghost.queue_free)
