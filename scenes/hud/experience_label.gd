extends Label
## A placeholder Experience count for the HUD. It shows the Experience it is pointed at and
## follows it through its changed signal.

@export var experience: Experience


func _ready() -> void:
	experience.changed.connect(_refresh)
	_refresh()


func _refresh() -> void:
	text = "Experience %d" % experience.total
