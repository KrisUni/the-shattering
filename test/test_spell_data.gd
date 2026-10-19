extends GutTest
## The numbers of a Spell: how its fireball's damage grows with Channelling, worked by hand, and
## that Flame draw's data file loads as them.

const FLAME_DRAW_PATH := "res://data/flame_draw.tres"
const TOLERANCE := 0.0001


func test_damage_without_channelling_is_the_base_damage() -> void:
	var spell := _spell(7.0, 3.0)

	assert_almost_eq(spell.damage_for(0), 7.0, TOLERANCE)


func test_each_point_of_channelling_adds_its_damage() -> void:
	# 7 + 3 * 4 = 19.
	var spell := _spell(7.0, 3.0)

	assert_almost_eq(spell.damage_for(4), 19.0, TOLERANCE)


func test_flame_draws_data_file_loads_as_spell_data() -> void:
	assert_true(load(FLAME_DRAW_PATH) is SpellData)


func _spell(base: float, per_channelling: float) -> SpellData:
	var spell := SpellData.new()
	spell.base_damage = base
	spell.damage_per_channelling = per_channelling
	return spell
