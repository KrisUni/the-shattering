extends Label
## A placeholder label for the HUD that shows the charges of Almos's Health Flask, such as
## "Health Flask 2/3". It follows his Flasks through their changed signal.

@export var flasks: AlmosFlasks


func _ready() -> void:
	flasks.changed.connect(_refresh)
	_refresh()


func _refresh() -> void:
	text = "Health Flask %d/%d" % [flasks.health_charges, flasks.health_charges_maximum]
