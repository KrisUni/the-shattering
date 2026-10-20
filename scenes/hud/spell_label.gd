extends Label
## A placeholder label for the HUD that names the Spell Almos has selected, "Pull" or "Shove". It
## follows the selection through the Spell's selection_changed signal.

@export var spell: AlmosSpell


func _ready() -> void:
	spell.selection_changed.connect(_refresh)
	_refresh()


func _refresh() -> void:
	text = "Shove" if spell.selected == AlmosSpell.Spell.SHOVE else "Pull"
