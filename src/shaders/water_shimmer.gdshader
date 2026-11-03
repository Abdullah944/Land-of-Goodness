// src/shaders/water_shimmer.gdshader
// Purpose: Moves soft light across the blue parts of a picture, so still water looks alive.

shader_type canvas_item;

uniform vec3 grass_tint = vec3(1.0);

void fragment() {
	vec4 picture = texture(TEXTURE, UV);
	float water = step(picture.r + 0.08, picture.b) * step(picture.r + 0.02, picture.g);
	float wave = sin((UV.x + UV.y * 1.6) * 42.0 + TIME * 1.8) * sin((UV.x - UV.y) * 26.0 - TIME * 1.1);
	COLOR = picture;
	COLOR.rgb += water * wave * 0.07;
	float green = step(picture.r + 0.02, picture.g) * step(picture.b + 0.02, picture.g);
	COLOR.rgb = mix(COLOR.rgb, COLOR.rgb * grass_tint, green);
}
