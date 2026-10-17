extends RefCounted
## What the training enemy tests share: the enemy and a target for it in the test's scene
## tree, and a sample of them taken every physics frame, so that what happened can be read
## back frame by frame. It lives under test/helpers without the test_ prefix, so GUT does
## not collect it as a test.
##
## A sample is taken at the start of each physics frame, before anything has moved in it,
## so it shows how that frame's predecessor left things. A sample's index is also the index
## of the physics frame it was taken at the start of. Sampling stops when the enemy is gone.

const ENEMY_SCENE_PATH := "res://scenes/enemies/training_enemy.tscn"
const TUNING_PATH := "res://data/training_enemy.tres"

# In pixels.
const TARGET_RADIUS := 8.0
# In Health points. Far more than any run of attacks in these tests can take off.
const TARGET_HEALTH := 1000.0
# In pixels. A Hitbox this wide covers all of the enemy.
const HITBOX_RADIUS := 200.0

var enemy
## What the enemy goes after.
var target: Node2D
## The Health that hits on the target show in.
var target_health: Health
var samples: Array[Dictionary] = []

var _test: GutTest
var _extras := {}


func _init(test: GutTest) -> void:
	_test = test


## The tuning data file's numbers, with these properties changed, for a test that needs a
## case the shipped numbers do not give. Nothing is shared with the data file.
func tuning_with(changes: Dictionary = {}) -> EnemyTuning:
	var loaded := load(TUNING_PATH) as EnemyTuning
	_test.assert_not_null(loaded, "the training enemy tuning data file should load")
	var tuning := loaded.duplicate(true) as EnemyTuning
	for property in changes:
		tuning.set(property, changes[property])
	return tuning


## The training enemy in the test's scene tree, standing here, given this tuning if there is
## one, and sampled from now on. The test frees it. It is put in place before it enters the
## tree: moved after, it would still count as standing where it entered for the first
## physics frame, and anything solid that overlaps that spot would be pushed away from it.
func spawn_enemy(tuning: EnemyTuning = null, at: Vector2 = Vector2.ZERO):
	var scene := load(ENEMY_SCENE_PATH) as PackedScene
	_test.assert_not_null(scene, "the training enemy scene should load")
	enemy = scene.instantiate()
	enemy.position = at
	if tuning != null:
		enemy.tuning = tuning
	_test.add_child_autofree(enemy)
	_test.get_tree().physics_frame.connect(_take_sample)
	return enemy


## Sets the enemy after this node, whose hits taken show in this Health, such as Almos and
## his Health.
func set_target(node: Node2D, health: Health) -> void:
	target = node
	target_health = health
	enemy.target = node


## A target standing here, which the enemy goes after. It stands in for Almos: it is hurt
## by hits on the player_hurtbox layer. The test frees it.
func place_target(at: Vector2) -> Node2D:
	var placed := Node2D.new()
	placed.position = at
	var health := Health.new()
	health.maximum = TARGET_HEALTH
	placed.add_child(health)
	var hurtbox := Hurtbox.new()
	hurtbox.collision_layer = layer_bit("player_hurtbox")
	hurtbox.collision_mask = 0
	hurtbox.monitoring = false
	hurtbox.health = health
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = TARGET_RADIUS
	shape.shape = circle
	hurtbox.add_child(shape)
	placed.add_child(hurtbox)
	_test.add_child_autofree(placed)
	set_target(placed, health)
	return placed


## Something more to sample every physics frame, under this name.
func sample_also(key: String, read: Callable) -> void:
	_extras[key] = read


## A Hitbox, switched off, laid over this node and wide enough to cover it, aimed at the
## Hurtboxes on this layer. The test frees it.
func hitbox_over(node: Node2D, damage: float, layer_name: String) -> Hitbox:
	var hitbox := Hitbox.new()
	hitbox.damage = damage
	hitbox.collision_mask = layer_bit(layer_name)
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = HITBOX_RADIUS
	shape.shape = circle
	hitbox.add_child(shape)
	hitbox.global_position = node.global_position
	_test.add_child_autofree(hitbox)
	return hitbox


## Switches the hitbox on for this many physics frames, then off again. It waits on the
## physics_frame signal, which comes before the hitbox is processed in a frame, so the
## hitbox is processed on exactly this many frames while it is on.
func swing(hitbox: Hitbox, frames: int) -> void:
	hitbox.active = true
	await wait_frames(frames)
	hitbox.active = false


func stop_sampling() -> void:
	if _test.get_tree().physics_frame.is_connected(_take_sample):
		_test.get_tree().physics_frame.disconnect(_take_sample)


## Waits this many physics frames. It waits on the physics_frame signal, which comes before
## the enemy is processed in a frame, so whatever the test does next is seen by the very
## next frame to be processed.
func wait_frames(count: int) -> void:
	for i in count:
		await _test.get_tree().physics_frame


## The index of the first sample in which this is true, or -1.
func first_sample_where(state: String) -> int:
	for i in samples.size():
		if samples[i][state]:
			return i
	return -1


## The first stretch of samples in which this is true, as Vector2i(first, end): the index of
## the first sample showing it and of the first showing it over. Either is -1 if it has not
## happened yet. The state lasted that many frames, as the end is as far past the first as
## it lasted frames.
func span(state: String) -> Vector2i:
	var first := -1
	for i in samples.size():
		if first == -1 and samples[i][state]:
			first = i
		elif first != -1 and not samples[i][state]:
			return Vector2i(first, i)
	return Vector2i(first, -1)


## Each hit the target took, as {"sample": the index of the first sample to show it,
## "damage": how much it took}. The frame it landed in is the one before that sample.
func hits() -> Array[Dictionary]:
	return drops("target_health")


## Each time the sampled number under this key went down, as {"sample": the index of the
## first sample to show it, "damage": how much it went down by}.
func drops(key: String) -> Array[Dictionary]:
	var found: Array[Dictionary] = []
	for i in range(1, samples.size()):
		var taken: float = samples[i - 1][key] - samples[i][key]
		if taken > 0.0:
			found.append({"sample": i, "damage": taken})
	return found


## Each time the enemy announces its death, how things stood at that moment, as {"dead",
## "striking"}. The enemy is gone soon after, so this is the way to see them. The list
## fills in as the enemy dies.
func record_deaths() -> Array[Dictionary]:
	var deaths: Array[Dictionary] = []
	var dying = enemy
	dying.died.connect(func() -> void: deaths.append({"dead": dying.dead, "striking": dying.striking}))
	return deaths


## The collision layer the project calls this, as the bit that sets it in a collision mask.
func layer_bit(layer_name: String) -> int:
	for layer in range(1, 33):
		if ProjectSettings.get_setting("layer_names/2d_physics/layer_%d" % layer, "") == layer_name:
			return 1 << (layer - 1)
	_test.fail_test("the project should name a 2D physics layer %s" % layer_name)
	return 0


func _take_sample() -> void:
	if not is_instance_valid(enemy):
		return
	var sample := {
		"position": enemy.position,
		"winding_up": enemy.winding_up,
		"attacking": enemy.attacking,
		"striking": enemy.striking,
		"look": enemy.modulate,
		"enemy_health": enemy.health.current,
		"target_health": target_health.current if target_health != null else 0.0,
	}
	for key in _extras:
		sample[key] = _extras[key].call()
	samples.append(sample)
