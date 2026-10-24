class_name StaminaBar
extends ProgressBar
## A placeholder Stamina bar for the HUD. It shows the Stamina it is pointed at and
## follows it through its changed signal.

@export var stamina: Stamina


func _ready() -> void:
	stamina.changed.connect(_refresh)
	_refresh()


func _refresh() -> void:
	max_value = stamina.maximum
	value = stamina.current
