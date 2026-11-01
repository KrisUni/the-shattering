class_name HealthBar
extends "res://scenes/hud/hud_bar.gd"
## The Health bar of the HUD: blood red, kept well apart from the Danger red of the Unblockable. It
## shows the Health it is pointed at and follows it through its changed signal.

@export var health: Health


func _ready() -> void:
	fill_color = Color("9b3a46")
	fill_light = Color("c25a63")
	fill_shade = Color("6e2632")
	health.changed.connect(_refresh)
	_refresh()


func _refresh() -> void:
	show_amount(health.current, health.maximum)
