shader_type canvas_item;

// Mixes the sprite's colour toward a flash colour, by flash_amount (0 = none, 1 = all the way).
// Alpha is the sprite's own, so transparent pixels stay transparent and edges keep their shape.
// The flash colour is a palette colour, set by the code that drives the sprite.
uniform vec4 flash_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float flash_amount : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	vec4 base = texture(TEXTURE, UV) * COLOR;
	COLOR = vec4(mix(base.rgb, flash_color.rgb, flash_amount), base.a);
}
