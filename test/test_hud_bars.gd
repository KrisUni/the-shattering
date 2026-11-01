extends GutTest
## The HUD's Health, Stamina and Mana bars draw themselves pixel-exact instead of the default
## ProgressBar look: a frame, a recessed background, a lit and shaded fill in each bar's own colour,
## none of them Danger red, and a pale trail that a loss leaves behind and that drains down to the
## new value. They are still ProgressBars that show what they follow. In the Dungeons' HUD the Health
## bar is on top and the longest.

const HUD_BAR := preload("res://scenes/hud/hud_bar.gd")
const DUNGEONS_PATH := "res://scenes/areas/dungeons/dungeons.tscn"
const DANGER_RED := Color("d62839")


func _bar() -> ProgressBar:
	var bar := HUD_BAR.new() as ProgressBar
	bar.size = Vector2(80, 7)
	add_child_autofree(bar)
	return bar


func test_the_default_look_is_replaced() -> void:
	var bar := _bar()
	assert_false(bar.show_percentage, "no percentage text")
	assert_true(bar.get_theme_stylebox(&"background") is StyleBoxEmpty, "no default background")
	assert_true(bar.get_theme_stylebox(&"fill") is StyleBoxEmpty, "no default fill")


func test_each_bar_has_its_own_colour_and_none_is_danger_red() -> void:
	var dungeons := (load(DUNGEONS_PATH) as PackedScene).instantiate()
	add_child_autofree(dungeons)
	var colours := {}
	for name in ["HealthBar", "StaminaBar"]:
		var bar = dungeons.get_node("Hud/" + name)
		assert_true(bar is ProgressBar, "%s is still a ProgressBar" % name)
		assert_true(bar.get_script().get_base_script() == HUD_BAR, "%s draws as a HUD bar" % name)
		colours[bar.fill_color.to_html(false)] = true
		for colour in [bar.fill_color, bar.fill_light, bar.fill_shade]:
			assert_ne(colour.to_html(false), DANGER_RED.to_html(false), "%s keeps clear of Danger red" % name)
	assert_eq(colours.size(), 2, "Health and Stamina are told apart by colour")


func test_health_is_on_top_and_longest_in_the_dungeons() -> void:
	var dungeons := (load(DUNGEONS_PATH) as PackedScene).instantiate()
	add_child_autofree(dungeons)
	var health := dungeons.get_node("Hud/HealthBar") as Control
	var stamina := dungeons.get_node("Hud/StaminaBar") as Control
	assert_lt(health.position.y, stamina.position.y, "Health is above Stamina")
	assert_gt(health.size.x, stamina.size.x, "and longer")
	assert_lt(health.size.x, 576.0 / 4.0, "neither takes much of the screen")


func test_a_loss_leaves_a_trail_that_drains_down_to_the_new_value() -> void:
	var bar := _bar()
	bar.show_amount(100.0, 100.0)
	bar.show_amount(60.0, 100.0)
	assert_eq(bar.value, 60.0, "the bar shows the new value at once")
	assert_eq(bar.trail_end(), 100.0, "the trail holds where it was")
	await wait_seconds(HUD_BAR.TRAIL_HOLD + 1.0 / HUD_BAR.TRAIL_SPEED * 0.4 + 0.3)
	assert_almost_eq(bar.trail_end(), 60.0, 0.01, "then drains down to it")


func test_a_gain_leaves_no_trail() -> void:
	var bar := _bar()
	bar.show_amount(40.0, 100.0)
	bar.show_amount(70.0, 100.0)
	assert_eq(bar.value, 70.0, "the bar rises at once")
	assert_eq(bar.trail_end(), 70.0, "with no trail")
