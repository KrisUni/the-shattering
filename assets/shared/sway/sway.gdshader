shader_type canvas_item;
// Something hanging that sways in moving air, such as moss: each row of its pixels shifts sideways,
// the lower the further, always by whole art pixels, so the art stays crisp. Its phase comes from
// where it hangs, so no two sway alike. Only a look.

// How far its foot swings, in art pixels, and how fast.
uniform float amplitude = 1.5;
uniform float speed = 1.1;

varying float phase;

void vertex() {
	phase = MODEL_MATRIX[3].x * 0.031 + MODEL_MATRIX[3].y * 0.017;
}

void fragment() {
	float shift = round(sin(TIME * speed + phase) * amplitude * UV.y * UV.y);
	vec2 uv = UV - vec2(shift * TEXTURE_PIXEL_SIZE.x, 0.0);
	vec4 colour = texture(TEXTURE, uv);
	if (uv.x < 0.0 || uv.x > 1.0) {
		colour.a = 0.0;
	}
	COLOR = colour * COLOR;
}
