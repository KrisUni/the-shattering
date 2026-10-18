class_name AlmosAttacks
extends Node
## Almos's Light and Heavy attacks, and his Critical hit, with his Weapon: the timeline of each
## swing, from the button presses to the Hitbox being switched on and off. Every number comes from the
## Weapon's data.
##
## A swing is startup, active and recovery frames one after the other. Holding the Heavy
## attack button comes before its swing, and the charge only starts building once the button
## has been held for the charge start, so a quick tap gives the plain Heavy attack. From the
## first frame of the hold or the swing until its recovery ends he is committed: Almos can
## do nothing else. A press of an attack button in the last frames of a recovery is kept, and
## the attack it asked for begins as the recovery ends. There is room for one kept press, and
## the latest press wins, the one made on the very frame the recovery ends included. A press
## at any other time during an attack is lost.
##
## The Critical hit is made in place of a Light swing: whenever a Light swing would begin, if
## an enemy that is broken has its centre within the Weapon's critical_range of his centre, he
## makes the Critical hit at the nearest such enemy instead. It is a swing like the others,
## with its own timeline and recovery, but it is aimed at that enemy's true angle, restarts
## the Light combo, spends no Stamina and builds no Stagger.
##
## The Jump attack is a Heavy attack press made in the air: at once, with no charging, it spends
## the Jump attack's Stamina (and is lost if that cannot be paid), is aimed as a swing begun at
## the press would be, and commits him. It waits for the Jump to end, which is its startup, and
## strikes on the frame he lands: Almos tells it when. A Jump that ends in a gap cancels it, with
## no strike and no recovery. Once it strikes it is a swing like the others, with its own
## timeline and recovery, and the Weapon's buffer window applies at the end of its recovery.

## Emitted when the Critical hit begins, with the direction to the enemy it is aimed at, so
## that Almos can turn to face it.
signal critical_began(direction: Vector2)

## Emitted when a swing's recovery is over, in the frame it ends and before any press kept for
## that frame begins its attack. Almos makes a switch that waited for the swing here, so that the
## kept attack is made with the Weapon switched to.
signal swing_ended

## Which attack button a press was of.
enum Press { NONE, LIGHT, HEAVY }

## The attacks of the Weapon in his hand. It can be changed at any time, and the sword is
## placed at the new Weapon's reach at once. A different Weapon starts the Light combo over. It is
## never changed in the middle of an attack: whoever hands over a Weapon waits until he is not
## committed, or for swing_ended. Almos hands over Unarmed when his hands are empty. Null is
## only a guard: every attack press is lost and the sword is off.
@export var weapon: WeaponData:
	set(value):
		var different := value != weapon
		weapon = value
		# Before the node is ready the Hitbox is not set up yet, and _ready places the sword.
		if not is_node_ready():
			return
		if different:
			_light_swing = 0
		if weapon != null:
			hitbox.set_reach(weapon.reach)
		else:
			reset()

## The sword's Hitbox, switched on for a swing's active frames.
@export var hitbox: Hitbox

## What each swing spends when it begins.
@export var stamina: Stamina

## Whether a swing is under way: from its first frame to the end of its recovery. A Jump attack
## is under way from the frame he lands.
var attacking: bool:
	get:
		return _frame >= 0

## Whether a Jump attack is under way: from the press in the air to the end of its recovery.
var jump_attacking: bool:
	get:
		return _jump_pending or (attacking and _jump_swing)

## Whether the swing under way is the Critical hit.
var critical: bool:
	get:
		return _critical

## Whether he is holding the Heavy attack button for a swing that has not begun. The charge
## itself only builds once the button has been held for the charge start.
var charging: bool:
	get:
		return _charging

## Whether he is tied up in an attack, charging it or swinging it, or flying to a Jump attack,
## and so can do nothing else.
var committed: bool:
	get:
		return attacking or _charging or _jump_pending

## Which swing of the Light combo is under way, from 1, or 0 when none is.
var light_swing: int:
	get:
		return _light_swing

# The frame of the swing under way that advance is processing, counted as AttackData counts
# them, from 0 for its first frame; it moves on to the next frame as advance finishes. -1 when
# there is no swing.
var _frame := -1
var _swing: AttackData
var _light_swing := 0
var _critical := false
var _charging := false
# Whether a Jump attack has been pressed in the air and has not struck yet, and the way it is
# aimed, fixed at the press.
var _jump_pending := false
var _jump_aim := Vector2.ZERO
# Whether the swing under way is the Jump attack.
var _jump_swing := false
# How many physics frames the Heavy attack button has been held, the frame of the press
# included.
var _frames_held := 0
# The press kept in the buffer window for the end of the swing under way, if any.
var _queued := Press.NONE


func _ready() -> void:
	# The sword sits as far out as the Weapon's data says it reaches, if he has one in hand.
	if weapon != null:
		hitbox.set_reach(weapon.reach)


## Lets one physics frame go by. Called once per frame by Almos, who says which way a swing
## that begins now is aimed (at the target under Lock-on, along his facing otherwise) and
## whether he is free to begin an attack, which he is not in the middle of a Roll, and whether
## he is in the air, where a Heavy attack press begins the Jump attack and a Light attack press
## is lost. The aim is fixed when the swing begins: the swing commits, so it does not follow the
## target after. It reads the attack buttons itself.
func advance(aim: Vector2, can_start: bool, in_the_air := false) -> void:
	# With no Weapon handed over there is nothing to swing, so a press of an attack button is lost.
	var press := _pressed() if weapon != null else Press.NONE
	if attacking and _frame >= _swing.total_frames():
		# A press seen on this frame is later than one kept for it, so it takes its place:
		# the latest press wins.
		if press != Press.NONE and _queued != Press.NONE:
			_queued = press
		_end_swing()
		# A switch that waited for the swing is made now, so that a press kept for its end is made
		# with the new Weapon.
		swing_ended.emit()
		# A press that was kept for the end of the swing is made as it ends.
		if _queued != Press.NONE:
			press = _queued
		_queued = Press.NONE
	if not attacking and not _charging and can_start and press != Press.NONE:
		_begin(press, aim)
		press = Press.NONE
	elif in_the_air and press == Press.HEAVY and not jump_attacking:
		_begin_jump_attack(aim)
		press = Press.NONE
	if _charging:
		_charge(aim)
	if attacking:
		_set_sword(_swing.is_active(_frame))
		if press != Press.NONE and _in_buffer_window():
			_queued = press
		_frame += 1


## He has come down from a Jump: a Jump attack pressed in it strikes now, in this very frame. It
## is called once per landing, as the Jump ends, with whether it ended in a gap, which puts him
## back where it began and cancels the Jump attack with no strike and no recovery.
func jump_ended(in_a_gap: bool) -> void:
	if not _jump_pending:
		return
	_jump_pending = false
	if in_a_gap:
		return
	var swing := weapon.jump_attack
	_jump_swing = true
	_begin_swing(swing, swing.damage, swing.stagger, _jump_aim)
	_set_sword(swing.is_active(_frame))
	_frame += 1


## Whatever attack he was in is over, at once: a swing or a charge, a Jump attack waiting for
## the landing, a press kept for the end of a swing, and the Light combo. The sword is off.
## Called when Almos falls or is returned.
func reset() -> void:
	_frame = -1
	_critical = false
	_charging = false
	_jump_pending = false
	_jump_swing = false
	_frames_held = 0
	_queued = Press.NONE
	_light_swing = 0
	hitbox.critical = false
	_set_sword(false)


# Which attack button was pressed this frame. If both were, it is the Light attack.
func _pressed() -> Press:
	if Input.is_action_just_pressed(&"attack_light"):
		return Press.LIGHT
	if Input.is_action_just_pressed(&"attack_heavy"):
		return Press.HEAVY
	return Press.NONE


func _begin(press: Press, aim: Vector2) -> void:
	if press == Press.LIGHT:
		_begin_light(aim)
	else:
		_begin_charge()


func _begin_light(aim: Vector2) -> void:
	var broken_enemy := _nearest_broken_enemy_in_range()
	if broken_enemy != null:
		_begin_critical(broken_enemy, aim)
		return
	# After the last swing the combo starts over at the first.
	var index := _light_swing % weapon.light_attacks.size()
	var next := weapon.light_attacks[index]
	if not stamina.spend(next.stamina_cost):
		# No swing to go on with, so the combo is over.
		_light_swing = 0
		return
	_light_swing = index + 1
	_begin_swing(next, next.damage, next.stagger, aim)


# The Critical hit at this enemy. It costs no Stamina, so it is made at zero Stamina too.
func _begin_critical(enemy: Node2D, aim: Vector2) -> void:
	var to_enemy := enemy.global_position - hitbox.global_position
	# An enemy right on top of him has no direction to be aimed at.
	var direction := to_enemy.normalized() if not to_enemy.is_zero_approx() else aim
	_light_swing = 0
	_critical = true
	var swing := weapon.critical_attack
	_begin_swing(swing, swing.damage, swing.stagger, direction)
	hitbox.critical = true
	critical_began.emit(direction)


# The nearest enemy in the group that is broken and within the Critical hit's range, or null.
# The Hitbox sits at his centre. Only nodes that can be broken are asked.
func _nearest_broken_enemy_in_range() -> Node2D:
	if weapon.critical_attack == null:
		return null
	var nearest: Node2D = null
	var nearest_distance := INF
	for node in get_tree().get_nodes_in_group(&"enemies"):
		var enemy := node as Node2D
		if enemy == null or not "broken" in enemy or not enemy.broken:
			continue
		var distance := hitbox.global_position.distance_to(enemy.global_position)
		if distance <= weapon.critical_range and distance < nearest_distance:
			nearest = enemy
			nearest_distance = distance
	return nearest


# A Heavy attack press in the air. Nothing is charged: the Jump attack is committed at once and
# paid for now, and a press that cannot be paid for is lost, so he just keeps jumping.
func _begin_jump_attack(aim: Vector2) -> void:
	if weapon.jump_attack == null or not stamina.spend(weapon.jump_attack.stamina_cost):
		return
	_jump_pending = true
	_jump_aim = aim
	_light_swing = 0
	# The sword is turned now, with the Hitbox off, so that the physics server has it in place
	# by the frame he lands, and the strike hits in the first of its active frames.
	hitbox.rotation = aim.angle()


func _begin_charge() -> void:
	# The swing is paid for when it comes out, and no attack begins at zero Stamina, so there
	# is nothing to charge for either.
	if stamina.current <= 0.0:
		return
	_charging = true
	_frames_held = 0
	_light_swing = 0


# The button is held for as long as it stays down, up to the full charge, and the swing
# begins when it is let go or the charge is full. What the charge has built then depends on
# how long it was held.
func _charge(aim: Vector2) -> void:
	var heavy := weapon.heavy_attack
	if Input.is_action_pressed(&"attack_heavy") and _frames_held < heavy.charge_frames_max:
		_frames_held += 1
		return
	_charging = false
	# Nothing is charged until the button has been held for the charge start, so a tap gives
	# the plain Heavy attack. From there damage, Stagger and cost grow in a straight line from the
	# plain ones to those of a full charge, which comes when the button has been held for
	# charge_frames_max.
	var built := float(_frames_held - heavy.charge_start_frames)
	var charge := clampf(built / (heavy.charge_frames_max - heavy.charge_start_frames), 0.0, 1.0)
	if stamina.spend(lerpf(heavy.stamina_cost, heavy.charged_stamina_cost, charge)):
		_begin_swing(heavy, lerpf(heavy.damage, heavy.charged_damage, charge), lerpf(heavy.stagger, heavy.charged_stagger, charge), aim)


func _begin_swing(swing: AttackData, damage: float, stagger: float, aim: Vector2) -> void:
	_swing = swing
	_frame = 0
	hitbox.damage = damage
	hitbox.stagger = stagger
	hitbox.rotation = aim.angle()


# The swing's recovery is over, and the sword is switched off whatever frame it was on: a
# swing with no recovery ends in its last active frame. The combo is over with the swing,
# unless a press was kept to go on.
func _end_swing() -> void:
	_frame = -1
	_critical = false
	_jump_swing = false
	hitbox.critical = false
	_set_sword(false)
	if _queued != Press.LIGHT:
		_light_swing = 0


# Switches the sword's Hitbox on or off, and its placeholder look, which shows while it can
# hurt.
func _set_sword(on: bool) -> void:
	hitbox.active = on
	hitbox.visible = on


# Whether a press now is kept for the end of the swing: it comes in the last frames of the
# recovery, however long the buffer window is.
func _in_buffer_window() -> bool:
	return _swing.is_recovering(_frame) and _frame >= _swing.total_frames() - weapon.attack_buffer_frames
