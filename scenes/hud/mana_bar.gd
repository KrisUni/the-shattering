extends ProgressBar
## A placeholder Mana bar for the HUD. It is hidden until Almos has his Mana bar, then shows the
## Mana it is pointed at and follows it through its changed signal.

@export var mana: Mana


func _ready() -> void:
	mana.changed.connect(_refresh)
	_refresh()


func _refresh() -> void:
	visible = mana.granted
	max_value = mana.maximum
	value = mana.current
