class_name EnemyLook
extends Node
## Makes an enemy's sprite show what the enemy is doing. It looks for an AnimatedSprite2D named
## Art in the enemy's Look; with none it does nothing, and the enemy tints its whole look as it
## always did. With one, it plays the animation for the enemy's state (idle, walk, strike, low,
## unblockable, break, and sit or sleep at a seated post; a name the sprite lacks is skipped) and
## draws the wind-up flashes on the sprite itself, in palette colours, with a shader that leaves its
## alpha alone. Over those it shows, for a moment each: hurt, a flinch when a blow costs it Health;
## startle, a jerk into guard as it notices Almos; rise, getting up from its seat or out of its
## sleep; and look, a glance round while a patrol pauses at one of its points. When it dies it is
## gone at once, as ever, but it leaves its body behind as a look: a copy that plays death, the
## buckle, the knees and the fall, lies a moment and fades away.
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
var _smear: BladeSmear
var _striking_for := 0
# Physics frames still to show of the flinch, the startle and the rise, or 0.
var _hurt_left := 0
var _startle_left := 0
var _rise_left := 0
var _last_health := -1.0
var _was_pursuing := false
var _was_seated := false
var _shown_attack_frame := -1
var _has_played := false


# For how many physics frames a flinch and a startle show. Looks.
const HURT_FRAMES := 14
const STARTLE_FRAMES := 16
# How long the body lies before it fades, and how long the fade takes, in seconds. Looks.
const BODY_LIES := 0.7
const BODY_FADES := 0.9


func _ready() -> void:
	_enemy = get_parent().get_parent()
	var health: Node = (_enemy as Node).get_node_or_null(^"Health")
	if health != null and health.has_signal(&"changed"):
		_last_health = float(health.get(&"current"))
		health.changed.connect(func() -> void:
			var now := float(health.get(&"current"))
			if now < _last_health:
				_hurt_left = HURT_FRAMES
			_last_health = now)
	if _enemy.has_signal(&"died"):
		_enemy.died.connect(_leave_body)


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
	_note_moments()
	_show_smear()
	_show_strain()
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
	if _hurt_left > 0 and _has(&"hurt"):
		return &"hurt"
	if _startle_left > 0 and _has(&"startle"):
		return &"startle"
	if _rise_left > 0 and _has(&"rise"):
		return &"rise"
	if not (_enemy as CharacterBody2D).velocity.is_zero_approx():
		return &"walk"
	if _enemy.has_method(&"sleeping") and _enemy.sleeping():
		return &"sleep"
	if _enemy.has_method(&"sitting") and _enemy.sitting():
		return &"sit"
	var patrol: Variant = _enemy.get(&"patrol")
	if patrol is PackedVector2Array and (patrol as PackedVector2Array).size() > 0 and not _enemy.in_pursuit:
		return &"look"
	return &"idle"


# For how many physics frames a blow's arc sweeps. A look.
const SMEAR_FRAMES := 6
# How full the Stagger is before the guard starts to shake, as a share of it. A look.
const STRAIN_FROM := 0.7


# The sword's arc through a live blow.
func _show_smear() -> void:
	if _smear == null:
		_smear = BladeSmear.new()
		get_parent().add_child(_smear)
	if _enemy.dead or not _enemy.get(&"striking"):
		_striking_for = 0
		_smear.clear()
		return
	_striking_for += 1
	_smear.show_at(float(_striking_for) / float(SMEAR_FRAMES), _enemy.facing)


# As its Stagger nears a Break, its guard strains: the figure shakes, a pixel each way.
func _show_strain() -> void:
	var stagger: Node = (_enemy as Node).get_node_or_null(^"Stagger")
	var shaking := false
	if stagger != null and not _enemy.broken and not _enemy.dead:
		var capacity := float(stagger.get(&"capacity"))
		shaking = capacity > 0.0 and float(stagger.get(&"current")) / capacity >= STRAIN_FROM
	_art.position.x = (1.0 if (Engine.get_process_frames() / 3) % 2 == 0 else -1.0) if shaking else 0.0


func _has(animation: StringName) -> bool:
	return _art.sprite_frames != null and _art.sprite_frames.has_animation(animation)


# Counts down the moments it shows for a while, and starts them: a startle as it takes up the chase,
# a rise as it leaves its seat or its sleep.
func _note_moments() -> void:
	_hurt_left = maxi(_hurt_left - 1, 0)
	_startle_left = maxi(_startle_left - 1, 0)
	_rise_left = maxi(_rise_left - 1, 0)
	var pursuing: bool = _enemy.in_pursuit
	if pursuing and not _was_pursuing:
		_startle_left = STARTLE_FRAMES
	_was_pursuing = pursuing
	var seated: bool = (_enemy.has_method(&"sitting") and _enemy.sitting()) \
		or (_enemy.has_method(&"sleeping") and _enemy.sleeping())
	if _was_seated and not seated and not _enemy.dead and _has(&"rise"):
		var frames := _art.sprite_frames
		_rise_left = ceili(frames.get_frame_count(&"rise") / maxf(frames.get_animation_speed(&"rise"), 0.1) * 60.0)
		# Getting up comes before the startle: it jerks awake, then stands.
		_startle_left = 0
	_was_seated = seated


# It died and is gone: its body is left as a look, falling as it dies, lying a moment and fading.
func _leave_body() -> void:
	if _art == null or not is_instance_valid(_art) or not _has(&"death"):
		return
	var world := (_enemy as Node).get_parent()
	if world == null:
		return
	var body := AnimatedSprite2D.new()
	body.sprite_frames = _art.sprite_frames
	body.offset = _art.offset
	body.centered = _art.centered
	body.flip_h = _art.flip_h
	body.z_index = (_enemy as Node2D).z_index
	world.add_child(body)
	body.global_transform = _art.global_transform
	body.play(&"death")
	var frames := _art.sprite_frames
	var falling := frames.get_frame_count(&"death") / maxf(frames.get_animation_speed(&"death"), 0.1)
	var fade := body.create_tween()
	fade.tween_interval(falling + BODY_LIES)
	fade.tween_property(body, ^"modulate:a", 0.0, BODY_FADES)
	fade.tween_callback(body.queue_free)


# Plays this animation, if the sprite has it. It starts over when it changes and at the first
# frame of every attack, such as each swing of a combo. One that is not a loop and has ended
# stays on its last frame for as long as the enemy is in that state.
func _play(animation: StringName) -> void:
	var frames := _art.sprite_frames
	if frames == null or not frames.has_animation(animation):
		return
	var attack_frame: int = _enemy.attack_frame
	var new_swing: bool = attack_frame == 0 and _shown_attack_frame != 0
	_shown_attack_frame = attack_frame
	if _art.animation != animation or new_swing or not _has_played:
		_has_played = true
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
