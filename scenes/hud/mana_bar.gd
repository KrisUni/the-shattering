extends "res://scenes/hud/hud_bar.gd"
## The Mana bar of the HUD: steel blue. It is hidden until Almos has his Mana bar, then shows the
## Mana it is pointed at and follows it through its changed signal.

@export var mana: Mana


func _ready() -> void:
	fill_color = Color("4a6fb5")
	fill_light = Color("6f93d4")
	fill_shade = Color("344f86")
	mana.changed.connect(_refresh)
	_refresh()


func _refresh() -> void:
	visible = mana.granted
	show_amount(mana.current, mana.maximum)
