extends GutTest
## Rooms and the screen have some life, as looks only: a lantern's flame leans away as Almos dashes
## past; hanging moss sways and the chasm's root ends sway in its rising air under a drifting fog;
## motes drift in each lamp's light. The screen fades in from black as he comes into a Room, a
## wine-dark vignette pulses round its edges while his Health is low, and it flashes white as he
## rests.

const LAMP_SCENE := preload("res://scenes/world/lamp.tscn")
const DUNGEONS_PATH := "res://scenes/areas/dungeons/dungeons.tscn"
const AlmosInput := preload("res://test/helpers/almos_input.gd")


class Dasher:
	extends Node2D
	var rolling := true
	var sprinting := false


func test_a_lanterns_flame_leans_as_he_dashes_past() -> void:
	var lamp := LAMP_SCENE.instantiate() as Node2D
	add_child_autofree(lamp)
	var art := lamp.get_node("Flame/Art") as Node2D
	var home := art.position
	var dasher := Dasher.new()
	dasher.add_to_group(&"almos")
	add_child_autofree(dasher)
	dasher.global_position = lamp.global_position + Vector2(-30, 10)
	await wait_process_frames(3)
	assert_ne(art.position, home, "the flame leans")
	assert_gt(art.position.x, home.x, "away from him")
	dasher.rolling = false
	await wait_seconds(1.0)
	assert_eq(art.position, home, "and settles")


func test_hanging_moss_sways() -> void:
	var hall := (load("res://scenes/areas/dungeons/corridor_1.tscn") as PackedScene).instantiate()
	add_child_autofree(hall)
	for moss in hall.get_node("WallGrowth").get_children():
		var material := (moss as CanvasItem).material as ShaderMaterial
		assert_not_null(material, "%s has its sway" % moss.name)
		if material != null:
			assert_eq(material.shader.resource_path, "res://assets/shared/sway/sway.gdshader", "%s sways" % moss.name)


func test_the_chasm_keeps_being_drawn_for_its_sway_and_fog() -> void:
	var hall := (load("res://scenes/areas/dungeons/corridor_1.tscn") as PackedScene).instantiate()
	add_child_autofree(hall)
	assert_true((hall.get_node("ChasmEdge") as Node).is_processing(), "the chasm's edge goes on drawing itself")


func test_motes_drift_in_a_lamps_light() -> void:
	var lamp := LAMP_SCENE.instantiate() as Node2D
	add_child_autofree(lamp)
	assert_not_null(lamp.get_node_or_null("Flame/Glow/Motes"), "its glow holds motes")


func _dungeons() -> DungeonsBuilding:
	var view := SubViewport.new()
	view.size = Vector2i(1152, 648)
	add_child_autofree(view)
	var dungeons := (load(DUNGEONS_PATH) as PackedScene).instantiate() as DungeonsBuilding
	view.add_child(dungeons)
	return dungeons


func test_the_screen_fades_in_at_each_room_and_flashes_at_a_rest() -> void:
	WorldState.reset()
	var dungeons := _dungeons()
	await wait_physics_frames(2)
	var screen := dungeons.screen_effects
	assert_not_null(screen, "the building has its screen effects")
	screen.set(&"_fade_left", 0.0)
	dungeons.room_changed.emit(dungeons.current_room)
	assert_gt(float(screen.get(&"_fade_left")), 0.0, "coming into a Room, the screen fades in")
	dungeons.almos.rested.emit(null)
	assert_gt(float(screen.get(&"_flash_left")), 0.0, "resting, it flashes")
	WorldState.reset()


func test_low_health_brings_on_the_vignette() -> void:
	WorldState.reset()
	var dungeons := _dungeons()
	await wait_physics_frames(2)
	var screen := dungeons.screen_effects
	assert_false(screen.vignette_showing(), "at full Health, none")
	var health := dungeons.almos.get_node("Health") as Health
	health.take_damage(health.maximum * 0.8)
	assert_true(screen.vignette_showing(), "low, it pulses round the edges")
	WorldState.reset()
