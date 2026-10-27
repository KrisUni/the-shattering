extends GutTest
## The flash shader may only mix the sprite's colour toward the flash colour. In a canvas_item
## fragment() Godot already hands over COLOR as the texture times the node's modulate, so a second
## multiplication by the texture squares the sprite's own colours and darkens it even at flash
## amount 0 (a half grey pixel came out at a quarter). Rendering needs a real display, which the
## headless test runner does not have, so this checks the shader's source: that the base colour is
## COLOR as it arrives, and that the texture is not sampled again.

const SHADER_PATH := "res://assets/shared/flash/flash.gdshader"


func _code() -> String:
	var shader := load(SHADER_PATH) as Shader
	assert_not_null(shader, "the flash shader should load")
	return shader.code


func test_the_base_colour_is_the_colour_godot_hands_over() -> void:
	assert_true(_code().contains("vec4 base = COLOR;"), "the sprite's colour is COLOR as it arrives")


func test_the_texture_is_not_multiplied_in_a_second_time() -> void:
	assert_false(_code().contains("texture(TEXTURE"), "COLOR already holds the texture")
