extends Label
## A placeholder "Fallen" label for the HUD. It shows from the moment Almos falls to the moment he
## is returned, and is hidden the rest of the time.

@export var almos: Almos


func _ready() -> void:
	almos.died.connect(_show_fallen)
	almos.returned.connect(hide)
	visible = almos.dead


func _show_fallen(_place: Vector2) -> void:
	show()
