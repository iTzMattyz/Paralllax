// Soft box-blur for the main-menu background (the room art behind the menu).
shader_type canvas_item;

uniform float spread : hint_range(0.0, 10.0) = 4.0;

void fragment() {
	vec2 ps = TEXTURE_PIXEL_SIZE * spread;
	vec4 sum = vec4(0.0);
	for (int x = -3; x <= 3; x++) {
		for (int y = -3; y <= 3; y++) {
			sum += texture(TEXTURE, UV + vec2(float(x), float(y)) * ps);
		}
	}
	COLOR = sum / 49.0;
}
