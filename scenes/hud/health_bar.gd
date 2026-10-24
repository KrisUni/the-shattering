class_name HealthBar
extends ProgressBar
## A placeholder Health bar for the HUD. It shows the Health it is pointed at and follows
## it through its changed signal.

@export var health: Health


func _ready() -> void:
	health.changed.connect(_refresh)
	_refresh()


func _refresh() -> void:
	max_value = health.maximum
	value = health.current
