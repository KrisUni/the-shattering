class_name AlmosAttacks
extends Node
## Almos's Light and Heavy attacks with his Weapon: the timeline of each swing, from the
## button presses to the Hitbox being switched on and off. Every number comes from the
## Weapon's data.
##
## A swing is startup, active and recovery frames one after the other. Holding the Heavy
## attack button comes before its swing, and the charge only starts building once the button
## has been held for the charge start, so a quick tap gives the plain Heavy attack. From the
## first frame of the hold or the swing until its recovery ends he is committed: Almos can
## do nothing else. A press of an attack button in the last frames of a recovery is kept, and
## the attack it asked for begins as the recovery ends. A press at any other time during an
## attack is lost.

## Which attack button a press was of.
enum Press { NONE, LIGHT, HEAVY }

## The attacks of the Weapon he carries.
@export var weapon: WeaponData

## The sword's Hitbox, switched on for a swing's active frames.
@export var hitbox: Hitbox

## What each swing spends when it begins.
@export var stamina: Stamina

## Whether a swing is under way: from its first frame to the end of its recovery.
var attacking: bool:
	get:
		return _frame >= 0

## Whether he is holding the Heavy attack button for a swing that has not begun. The charge
## itself only builds once the button has been held for the charge start.
var charging: bool:
	get:
		return _charging

## Whether he is tied up in an attack, charging it or swinging it, and so can do nothing else.
var committed: bool:
	get:
		return attacking or _charging

## Which swing of the Light combo is under way, from 1, or 0 when none is.
var light_swing: int:
	get:
		return _light_swing

# How many frames into the swing under way, which is 0 on its first frame. -1 when there is
# no swing.
var _frame := -1
var _swing: AttackData
var _light_swing := 0
var _charging := false
# How many physics frames the Heavy attack button has been held, the frame of the press
# included.
var _frames_held := 0
# The press kept in the buffer window for the end of the swing under way, if any.
var _queued := Press.NONE


## Lets one physics frame go by. Called once per frame by Almos, who says which way a swing
## that begins now is aimed (at the target under Lock-on, along his facing otherwise) and
## whether he is free to begin an attack, which he is not in the middle of a Roll. The aim is
## fixed when the swing begins: the swing commits, so it does not follow the target after.
## It reads the attack buttons itself.
func advance(aim: Vector2, can_start: bool) -> void:
	var press := _pressed()
	if attacking and _frame >= _swing_frames():
		_end_swing()
		# A press that was kept for the end of the swing is made as it ends.
		if _queued != Press.NONE:
			press = _queued
		_queued = Press.NONE
	if not attacking and not _charging and can_start and press != Press.NONE:
		_begin(press, aim)
		press = Press.NONE
	if _charging:
		_charge(aim)
	if attacking:
		_set_sword(_frame >= _swing.startup_frames and _frame < _swing.startup_frames + _swing.active_frames)
		if press != Press.NONE and _in_buffer_window():
			_queued = press
		_frame += 1


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
	# After the last swing the combo starts over at the first.
	var index := _light_swing % weapon.light_attacks.size()
	var next := weapon.light_attacks[index]
	if not stamina.spend(next.stamina_cost):
		# No swing to go on with, so the combo is over.
		_light_swing = 0
		return
	_light_swing = index + 1
	_begin_swing(next, next.damage, aim)


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
	# the plain Heavy attack. From there damage and cost grow in a straight line from the
	# plain ones to those of a full charge, which comes when the button has been held for
	# charge_frames_max.
	var built := float(_frames_held - heavy.charge_start_frames)
	var charge := clampf(built / (heavy.charge_frames_max - heavy.charge_start_frames), 0.0, 1.0)
	if stamina.spend(lerpf(heavy.stamina_cost, heavy.charged_stamina_cost, charge)):
		_begin_swing(heavy, lerpf(heavy.damage, heavy.charged_damage, charge), aim)


func _begin_swing(swing: AttackData, damage: float, aim: Vector2) -> void:
	_swing = swing
	_frame = 0
	hitbox.damage = damage
	hitbox.rotation = aim.angle()


# The swing's recovery is over, and the sword is switched off whatever frame it was on: a
# swing with no recovery ends in its last active frame. The combo is over with the swing,
# unless a press was kept to go on.
func _end_swing() -> void:
	_frame = -1
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
	var recovery_start := _swing.startup_frames + _swing.active_frames
	return _frame >= recovery_start and _frame >= _swing_frames() - weapon.attack_buffer_frames


func _swing_frames() -> int:
	return _swing.startup_frames + _swing.active_frames + _swing.recovery_frames
