extends RefCounted
## What the attack tests share: Almos in the test's scene tree, a target in front of him,
## and a sample of both taken every physics frame, so that what happened can be read back
## frame by frame. The target is a Hurtbox on the enemy_hurtbox layer with a Health of its
## own, so its Health shows when and how hard the sword hit. It lives under test/helpers
## without the test_ prefix, so GUT does not collect it as a test.
##
## A sample is taken at the start of each physics frame, before anything has moved in it,
## so it shows how that frame's predecessor left things. A sample's index is also the index
## of the physics frame it was taken at the start of.

const AlmosInput := preload("res://test/helpers/almos_input.gd")

# In pixels. How far in front of Almos the target stands: inside the reach of the sword as
# the scene draws it.
const TARGET_DISTANCE := 30.0
# In pixels.
const TARGET_RADIUS := 8.0
# In Health points. Far more than any run of swings in these tests can take off.
const TARGET_HEALTH := 1000.0
# The most physics frames any wait in these tests may take.
const WAIT_FRAME_LIMIT := 240

## A thing for the sword to hit.
class Target:
	extends RefCounted
	var health: Health
	var hurtbox: Hurtbox

var almos
## The target placed in front of Almos, facing down as he starts out, when he is spawned.
var target: Target
var samples: Array[Dictionary] = []

var _test: GutTest


func _init(test: GutTest) -> void:
	_test = test


## Almos in the test's scene tree with a target in front of him, sampled from now on. He is
## given this tuning and this weapon data if there are any.
func spawn_almos(almos_input: AlmosInput, tuning: PlayerTuning = null, weapon: WeaponData = null):
	almos = almos_input.spawn_almos(tuning, weapon)
	target = place_target(almos.global_position + Vector2.DOWN * TARGET_DISTANCE)
	_test.get_tree().physics_frame.connect(_take_sample)
	return almos


## A target standing here. The test frees it.
func place_target(at: Vector2) -> Target:
	var placed := Target.new()
	var holder := Node2D.new()
	holder.position = at
	placed.health = Health.new()
	placed.health.maximum = TARGET_HEALTH
	holder.add_child(placed.health)
	placed.hurtbox = Hurtbox.new()
	placed.hurtbox.collision_layer = _layer_bit("enemy_hurtbox")
	placed.hurtbox.collision_mask = 0
	placed.hurtbox.monitoring = false
	placed.hurtbox.health = placed.health
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = TARGET_RADIUS
	shape.shape = circle
	placed.hurtbox.add_child(shape)
	holder.add_child(placed.hurtbox)
	_test.add_child_autofree(holder)
	return placed


func stop_sampling() -> void:
	if _test.get_tree().physics_frame.is_connected(_take_sample):
		_test.get_tree().physics_frame.disconnect(_take_sample)


## The index of the physics frame that is about to be processed, when a test resumes after
## a physics_frame signal.
func frame() -> int:
	return samples.size() - 1


## The index of the first sample in which this is true, or -1.
func first_sample_where(state: String) -> int:
	for i in samples.size():
		if samples[i][state]:
			return i
	return -1


## Waits this many physics frames. It waits on the physics_frame signal, which comes before
## Almos is processed in a frame, so whatever the test does next is seen by the very next
## frame to be processed, unlike after wait_physics_frames, which can span one frame more
## than it is asked for.
func wait_frames(count: int) -> void:
	for i in count:
		await _test.get_tree().physics_frame


## The first stretch of samples in which Almos was attacking, as Vector2i(first, end): the
## index of the first sample showing him attacking and of the first showing him done.
## Either is -1 if it has not happened yet. A swing is that many frames long, as the end
## is as far past the first as the swing has frames.
func attack_span() -> Vector2i:
	var first := -1
	for i in samples.size():
		if first == -1 and samples[i].attacking:
			first = i
		elif first != -1 and not samples[i].attacking:
			return Vector2i(first, i)
	return Vector2i(first, -1)


## Waits until a press made now is the one that Almos sees at this frame of the run of
## swings under way, the first frame of the first swing being 0. In a combo the count runs
## on from one swing into the next. A button pressed by a test is seen as just pressed by
## the frame after the one it was pressed in. Called once the swing has begun, and before
## that frame.
func wait_to_press_for_swing_frame(swing_frame: int) -> void:
	var begun := first_sample_where("attacking")
	_test.assert_ne(begun, -1, "the swing should have begun")
	# The first sample to show the swing follows its first frame, and the press is seen a
	# frame after the one it is made in.
	for i in WAIT_FRAME_LIMIT:
		if frame() >= begun - 2 + swing_frame:
			return
		await _test.get_tree().physics_frame
	_test.fail_test("the swing should have got to frame %d" % swing_frame)


## The first stretch of samples in which Almos was charging, as Vector2i(first, end), like
## attack_span.
func charge_span() -> Vector2i:
	var first := -1
	for i in samples.size():
		if first == -1 and samples[i].charging:
			first = i
		elif first != -1 and not samples[i].charging:
			return Vector2i(first, i)
	return Vector2i(first, -1)


## Makes the target shrug off every hit until this many frames into the swing under way,
## counted from the swing's first frame, which is 0. A swing that is still on when the
## target stops shrugging hits it then, so whether the target is hurt at all shows whether
## the sword was still on that late. Called any time before that frame.
func shrug_off_hits_until_swing_frame(swing_frame: int) -> void:
	target.hurtbox.is_untouchable = func() -> bool:
		var begun := first_sample_where("attacking")
		# The first sample to show the swing follows its first frame.
		return begun == -1 or frame() < begun - 1 + swing_frame


## Each hit the target took, as {"sample": the index of the first sample to show it,
## "damage": how much it took}. The frame it landed in is the one before that sample.
func hits() -> Array[Dictionary]:
	var found: Array[Dictionary] = []
	for i in range(1, samples.size()):
		var taken: float = samples[i - 1].target_health - samples[i].target_health
		if taken > 0.0:
			found.append({"sample": i, "damage": taken})
	return found


func _take_sample() -> void:
	if not is_instance_valid(almos) or target == null or not is_instance_valid(target.health):
		return
	samples.append({
		"position": almos.position,
		"attacking": almos.attacking,
		"charging": almos.charging,
		"light_swing": almos.light_swing,
		"rolling": almos.rolling,
		"sprinting": almos.sprinting,
		"stamina": almos.stamina.current,
		"target_health": target.health.current,
	})


# The collision layer the project calls this, as the bit that sets it in a collision mask.
func _layer_bit(layer_name: String) -> int:
	for layer in range(1, 33):
		if ProjectSettings.get_setting("layer_names/2d_physics/layer_%d" % layer, "") == layer_name:
			return 1 << (layer - 1)
	_test.fail_test("the project should name a 2D physics layer %s" % layer_name)
	return 0
