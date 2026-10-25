extends GutTest
## Root crawlers that hear the same Noise: all of them go into Pursuit and close in on it, and none
## crowds into another, however close they get. The test room has the real Almos, three crawlers with
## the shipped tuning, and every distance is worked from the data and the crawler's own scene.

const AlmosInput := preload("res://test/helpers/almos_input.gd")

const TEST_ROOM_PATH := "res://scenes/test_room.tscn"
const CRAWLER_TUNING_PATH := "res://data/root_crawler.tres"
const TRAINING_TUNING_PATH := "res://data/training_enemy.tres"
const CRAWLER_NAMES: Array[String] = ["RootCrawler1", "RootCrawler2", "RootCrawler3"]
const FAR_AWAY := Vector2(-10000.0, -10000.0)
# In pixels. Where Almos stands, from the crawler that is nearest to him at the start.
const ALMOS_FROM_NEAREST := Vector2.LEFT * 100.0
# In physics frames. How long the crawlers are watched once they have heard the Noise: long enough
# to arrive, and to stand around him a while.
const WATCH_FRAMES := 240
const TAP_FRAMES := 3
const TOLERANCE := 0.001

var _almos_input: AlmosInput
var _crawler_tuning: EnemyTuning


func before_each() -> void:
	await get_tree().process_frame
	_almos_input = AlmosInput.new(self)
	_crawler_tuning = load(CRAWLER_TUNING_PATH) as EnemyTuning


func after_each() -> void:
	_almos_input.release_everything()


func test_the_root_crawler_keeps_clear_of_other_enemies_by_more_than_its_body_and_the_others_do_not() -> void:
	var diameter := _body_diameter()
	assert_gt(_crawler_tuning.separation_radius, diameter, "a Root crawler steers clear of one before they touch")
	assert_gt(_crawler_tuning.separation_strength, 0.0)
	var training := load(TRAINING_TUNING_PATH) as EnemyTuning
	assert_eq(training.separation_radius, 0.0, "the training enemy does not")
	assert_eq(EnemyTuning.new().separation_radius, 0.0, "nor does any tuning that says nothing")


func test_three_crawlers_that_hear_the_same_noise_all_go_into_pursuit_and_close_in_on_it() -> void:
	var c := _case(_crawler_tuning)
	var started: Array[float] = []
	for crawler in c.crawlers:
		started.append(crawler.global_position.distance_to(c.almos.global_position))

	await _make_noise_and_watch(c)

	for i in c.crawlers.size():
		var crawler: Node2D = c.crawlers[i]
		assert_true(crawler.in_pursuit, "%s hears it" % crawler.name)
		var gap: float = crawler.global_position.distance_to(c.almos.global_position)
		assert_lt(gap, started[i] - 1.0, "%s has come closer" % crawler.name)
		assert_lte(gap, _crawler_tuning.attack_range + _body_diameter(), "%s ends around him" % crawler.name)


func test_crawlers_closing_in_on_the_same_noise_never_come_closer_to_one_another_than_their_body() -> void:
	var c := _case(_crawler_tuning)

	await _make_noise_and_watch(c)

	assert_gte(c.closest, _body_diameter() - TOLERANCE, "at no frame did two overlap")
	assert_gte(_closest_pair(c.crawlers), _body_diameter() - TOLERANCE, "nor at the end")


func test_without_separation_the_same_crawlers_do_crowd_into_one_another() -> void:
	var bare := _crawler_tuning.duplicate() as EnemyTuning
	bare.separation_radius = 0.0
	var c := _case(bare)

	await _make_noise_and_watch(c)

	assert_lt(c.closest, _body_diameter(), "control: the test would see an overlap")


# The test room with the three crawlers kept, their post facing left and this tuning, Almos a way
# to the left of the nearest of them, and the other enemies out of the way. The test frees it. The
# closest the crawlers have come to one another is kept in the returned dictionary under closest.
func _case(tuning: EnemyTuning) -> Dictionary:
	var room := (load(TEST_ROOM_PATH) as PackedScene).instantiate()
	for enemy_name in ["TrainingEnemy", "SoundHunter", "NarJailer"]:
		room.get_node(enemy_name).position = FAR_AWAY
	var crawlers: Array[Node2D] = []
	var nearest: Node2D = null
	for crawler_name in CRAWLER_NAMES:
		var crawler := room.get_node(crawler_name) as Node2D
		crawler.tuning = tuning
		crawler.post_facing = Vector2.LEFT
		crawlers.append(crawler)
		if nearest == null or crawler.position.x < nearest.position.x:
			nearest = crawler
	var almos := room.get_node("Almos") as Node2D
	almos.position = nearest.position + ALMOS_FROM_NEAREST
	add_child_autofree(room)
	return {"room": room, "almos": almos, "crawlers": crawlers, "closest": INF}


# Almos swings, which is Noise all three hear, and the crawlers are watched for WATCH_FRAMES
# frames, the closest pair among them in each frame kept.
func _make_noise_and_watch(c: Dictionary) -> void:
	_almos_input.press_action(&"attack_light")
	for i in WATCH_FRAMES:
		await get_tree().physics_frame
		if i == TAP_FRAMES:
			_almos_input.release_action(&"attack_light")
		c.closest = minf(c.closest, _closest_pair(c.crawlers))


func _closest_pair(crawlers: Array[Node2D]) -> float:
	var closest := INF
	for i in crawlers.size():
		for j in range(i + 1, crawlers.size()):
			closest = minf(closest, crawlers[i].global_position.distance_to(crawlers[j].global_position))
	return closest


# In pixels. How wide a crawler's body is, read from its scene.
func _body_diameter() -> float:
	var crawler := (load("res://scenes/enemies/root_crawler.tscn") as PackedScene).instantiate()
	var shape := crawler.get_node("CollisionShape2D").shape as CircleShape2D
	crawler.free()
	return shape.radius * 2.0
