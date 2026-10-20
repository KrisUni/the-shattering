extends Label
## A placeholder label for the HUD that names the Spell Almos has selected, "Pull", "Shove" or "Deep bolt". It
## follows the selection through the Spell's selection_changed signal.

@export var spell: AlmosSpell


func _ready() -> void:
	spell.selection_changed.connect(_refresh)
	_refresh()


func _refresh() -> void:
	match spell.selected:
		AlmosSpell.Spell.SHOVE:
			text = "Shove"
		AlmosSpell.Spell.DEEP_BOLT:
			text = "Deep bolt"
		_:
			text = "Pull"
