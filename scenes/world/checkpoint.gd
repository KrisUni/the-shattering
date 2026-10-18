class_name Checkpoint
extends Node2D
## A Checkpoint: an arch-tree shoot, drawn as a placeholder glowing sapling. Almos rests at it
## by pressing Interact within reach, and it flashes when he does. It is in the group
## "checkpoints", which is where Almos looks for one, and has no body, so he walks through it.

## What it is tinted while it flashes: a white brighter than the placeholder's own colours,
## which a plain white tint would not be. It is a look, not a tuning number.
const FLASH_TINT := Color(3.0, 3.0, 2.2)

## Whether it is flashing: it has been rested at and the flash has not run out.
var flashing: bool:
	get:
		return _flash_left > 0.0

var _flash_left := 0.0


func _ready() -> void:
	set_physics_process(false)


## Almos rests here: it flashes for this long, in seconds, and the flash starts over if it
## was already going. The length is Almos's tuning, not the Checkpoint's.
func rest(flash_duration: float) -> void:
	_flash_left = flash_duration
	modulate = FLASH_TINT
	set_physics_process(flashing)
	if not flashing:
		modulate = Color.WHITE


func _physics_process(delta: float) -> void:
	_flash_left -= delta
	if not flashing:
		_flash_left = 0.0
		modulate = Color.WHITE
		set_physics_process(false)
