class_name AlmosParry
extends Node
## Almos's Parry: a press of the Parry button opens a window, counted in physics frames, in
## which a hit from the front is parried: it is negated, it deals no damage and does not
## reach Block. Almos says every frame whether he is free to Parry, which he is not in a Roll,
## in an attack, charging a Heavy attack, in a Guard break or in a Parry already under way. He
## can start it from a Sprint or while blocking.
##
## The window opens on the frame of the press, which counts as the first, and lasts
## parry_window_frames. A window that caught nothing is followed by parry_recovery_frames in
## which he stands open: every hit lands in full, and he cannot Roll, attack, Block or Parry.
## He is free again on the frame after the last of them. A press while he is not free is lost,
## not kept, so presses never stack. A Parry costs no Stamina.
##
## A hit is parried when it comes in the window, from the front that the Parry covers:
## parry_arc_degrees wide, centred on the way Almos faces, judged from the Hitbox's position as
## Block judges its front. A parried hit ends the Parry at once: he is free from the next frame.
## Almos decides what else he cannot do while it lasts. A shape is drawn in front of him while
## the window is open, and his placeholder is tinted during the recovery.
##
## Both frame guarantees, that the press frame is the first of the window and that a parried
## hit frees him from the next frame, hold only if Almos is processed before the attacker's
## Hitbox in each physics frame, as scenes/test_room.tscn orders them. With the Hitbox first, a
## hit on the press frame arrives before the window opens and is not parried.

## What his placeholder is tinted during the recovery of a Parry, so that the player can see
## him left open. It is a look, not a tuning number, and differs from AlmosBlock.GUARD_BREAK_TINT.
const RECOVERY_TINT := Color(0.3, 0.9, 1.0)

## What the numbers of Parry come from. Almos gives his own tuning.
@export var tuning: PlayerTuning

## What is drawn while the window is open. Optional.
@export var placeholder: CanvasItem

## What is tinted during the recovery: the placeholder of Almos himself. Optional.
@export var tinted_placeholder: CanvasItem

## Whether a Parry is under way: its window or its recovery. It is false from the frame after
## the last recovery frame, and from the frame after a hit was parried.
var parrying: bool:
	get:
		return _frame >= 0

## Whether the window is open: a hit in front of him now is parried.
var window_open: bool:
	get:
		return _frame >= 0 and _frame < tuning.parry_window_frames

# The frame of the Parry under way that advance last processed, counted from 0 for the frame of
# the press. -1 when there is none.
var _frame := -1
# Whether the placeholder is tinted by the recovery.
var _tinted := false


## Lets one physics frame go by. Called once per frame by Almos, after the attacks and the
## Roll have read their presses, who says whether he is free to begin a Parry. It reads the
## Parry button itself. The Parry under way moves on a frame, and ends once its last recovery
## frame has been processed, so that it still counts as under way for Almos in that frame.
func advance(free: bool) -> void:
	if _frame >= 0:
		_frame += 1
	elif free and Input.is_action_just_pressed(&"parry"):
		_frame = 0
	if _frame >= tuning.parry_window_frames + tuning.parry_recovery_frames - 1:
		_end()
	_show()


## A hit comes from this point in the world, on Almos standing at centre and facing this way
## (a unit vector). Returns whether the Parry parries it, and if it does the Parry ends. Called
## by his Hurtbox for every hit that is not on someone untouchable, so it is to be called once
## for each.
func catches(from: Vector2, centre: Vector2, facing: Vector2) -> bool:
	if not window_open or not FrontArc.covers(from, centre, facing, tuning.parry_arc_degrees):
		return false
	_end()
	_show()
	return true


func _end() -> void:
	_frame = -1


# The look follows the state in the moment it changes, so that what is drawn is never a frame
# behind it. Neither this tint nor the Guard break's can begin during the other, since a Parry
# cannot begin in a Guard break nor a Guard break in a Parry (he is not blocking).
func _show() -> void:
	if placeholder != null:
		placeholder.visible = window_open
	if tinted_placeholder != null:
		var recovering := parrying and not window_open
		if recovering:
			tinted_placeholder.modulate = RECOVERY_TINT
		elif _tinted:
			tinted_placeholder.modulate = Color.WHITE
		_tinted = recovering

