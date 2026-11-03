// src/shaders/ground_blend.gdshader
// Purpose: Paints a place's ground from painted HD textures. Three small mask maps say which ground lies where;
// a little noise makes the edges between grass, dirt, sand, and roads wander like real ground.

shader_type canvas_item;

// The sprite's own texture is the first mask too, so the sprite has the right size; it is read here smoothly.
uniform sampler2D mask_a : filter_linear, repeat_disable; // red grass, green dirt, blue sand
uniform sampler2D mask_b : filter_linear, repeat_disable; // red road, green cobble, blue water
uniform sampler2D mask_c : filter_linear, repeat_disable; // red planks, green forest floor, blue water depth
uniform sampler2D grass : filter_linear_mipmap, repeat_enable;
uniform sampler2D dirt : filter_linear_mipmap, repeat_enable;
uniform sampler2D sand : filter_linear_mipmap, repeat_enable;
uniform sampler2D road : filter_linear_mipmap, repeat_enable;
uniform sampler2D cobble : filter_linear_mipmap, repeat_enable;
uniform sampler2D water : filter_linear_mipmap, repeat_enable;
uniform sampler2D planks : filter_linear_mipmap, repeat_enable;
uniform sampler2D forest : filter_linear_mipmap, repeat_enable;
// The place's size in world pixels, and how many world pixels one texture covers.
uniform vec2 world_size = vec2(1000.0);
uniform float tile = 160.0;
uniform vec3 grass_tint = vec3(1.0);

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

float wander(vec2 p) {
	return noise(p * 0.09) * 0.6 + noise(p * 0.23) * 0.4;
}

void fragment() {
	vec2 world = UV * world_size;
	vec2 at = world / tile;
	vec3 a = texture(mask_a, UV).rgb;
	vec3 b = texture(mask_b, UV).rgb;
	vec3 c = texture(mask_c, UV).rgb;
	// Each kind's share grows or shrinks with the noise, then the strongest ones win with a soft edge.
	float shares[8] = float[8](a.r, a.g, a.b, b.r, b.g, b.b, c.r, c.g);
	float best = 0.0;
	for (int i = 0; i < 8; i++) {
		// Each kind gets its own noise, so two kinds meeting push and pull and the edge wanders.
		float wobble = (i == 6 || i == 5) ? 0.0 : (wander(world + float(i) * 37.0) - 0.5) * 0.55;
		shares[i] = shares[i] + (shares[i] > 0.01 ? wobble : 0.0);
		best = max(best, shares[i]);
	}
	float total = 0.0;
	for (int i = 0; i < 8; i++) {
		shares[i] = smoothstep(best - 0.08, best, shares[i]);
		total += shares[i];
	}
	vec2 drift = vec2(TIME * 0.012, TIME * 0.007);
	// Two grass samples at different sizes hide the repeat.
	vec3 lawn = mix(texture(grass, at).rgb, texture(grass, at * 0.43 + 0.31).rgb, noise(world * 0.006) * 0.6);
	// The painted grass is bright; this calms it toward the warm Gulf palette.
	lawn *= vec3(0.86, 0.9, 0.78) * (0.92 + noise(world * 0.004) * 0.16);
	vec3 sea = (texture(water, at * 0.8 + drift).rgb + texture(water, at * 0.6 - drift * 1.3 + 0.5).rgb) * 0.5;
	sea *= mix(1.0, 0.72, c.b);
	vec3 color = lawn * grass_tint * shares[0]
		+ texture(dirt, at).rgb * shares[1]
		+ texture(sand, at).rgb * shares[2]
		+ texture(road, at * 1.3).rgb * shares[3]
		+ texture(cobble, at * 1.6).rgb * shares[4]
		+ sea * shares[5]
		+ texture(planks, at * 1.6).rgb * shares[6]
		+ texture(forest, at).rgb * grass_tint * 0.82 * shares[7];
	COLOR = vec4(color / max(total, 0.001), 1.0);
}
