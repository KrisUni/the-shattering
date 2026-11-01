class_name StaminaBar
extends "res://scenes/hud/hud_bar.gd"
## The Stamina bar of the HUD: sage green. It shows the Stamina it is pointed at and follows it
## through its changed signal.

@export var stamina: Stamina


func _ready() -> void:
	fill_color = Color("7f9a5a")
	fill_light = Color("a3bd77")
	fill_shade = Color("58703e")
	stamina.changed.connect(_refresh)
	_refresh()


func _refresh() -> void:
	show_amount(stamina.current, stamina.maximum)
