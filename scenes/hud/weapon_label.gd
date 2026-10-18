extends Label
## A placeholder label for the HUD that names the Weapon in Almos's hand, or "Unarmed" when his
## hands are empty. It follows his Weapons through their changed signal.

@export var weapons: AlmosWeapons


func _ready() -> void:
	weapons.changed.connect(_refresh)
	_refresh()


func _refresh() -> void:
	text = weapons.in_hand.display_name if weapons.in_hand != null else "Unarmed"
