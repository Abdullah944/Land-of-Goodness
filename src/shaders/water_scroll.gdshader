// src/shaders/water_scroll.gdshader
// Purpose: Slowly drifts the sea texture, so the Gulf looks like moving water.

shader_type canvas_item;

void fragment() {
	vec2 drift = vec2(TIME * 0.015, sin(TIME * 0.5 + UV.x * 6.0) * 0.012);
	COLOR = texture(TEXTURE, UV + drift);
}
