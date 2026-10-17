extends CharacterBody2D

# Almos's sprites show eight facings, so his facing is always one of eight directions.
const FACING_STEP := TAU / 8.0

## Where Almos last moved, snapped to the nearest of eight directions, as a unit
## vector. A Roll with no input goes this way.
var facing := Vector2.DOWN

@export var tuning: PlayerTuning

@onready var _placeholder: Polygon2D = $Placeholder


func _physics_process(_delta: float) -> void:
	# get_vector applies the deadzone to the stick as a whole, not axis by axis, and
	# never returns more than length 1, so diagonals are no faster.
	var direction := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if direction != Vector2.ZERO:
		facing = Vector2.from_angle(snappedf(direction.angle(), FACING_STEP))
	# Turning the placeholder shape stands in for the eight facing sprites.
	_placeholder.rotation = facing.angle()
	velocity = direction * tuning.walk_speed
	move_and_slide()
