shader_type canvas_item;
// Ground of the Lumeria overworld, drawn on one world-sized quad.
// The authored macro map (one texel per cell, red = palette index) is blended
// with noise-warped, smoothed bilinear interpolation, so biome borders are
// soft and organic instead of rectangular. Water cells shimmer gently.

uniform sampler2D biome_map : filter_nearest;
// Row 0 = base color, row 1 = variation color, row 2 alpha = 1 for water.
uniform sampler2D palette : filter_nearest;
uniform sampler2D noise_tex : repeat_enable, filter_linear;
uniform vec2 world_size = vec2(10240.0, 6144.0);
uniform float cell_size = 256.0;
uniform float warp_amount = 0.2;
// 0..1, scaled down by the Reduce Motion setting.
uniform float motion = 1.0;
// 0..1, rises when the Heart of Lumeria is restored (slightly warmer, livelier colors).
uniform float restoration = 0.0;

int index_at(ivec2 cell) {
	ivec2 size = textureSize(biome_map, 0);
	cell = clamp(cell, ivec2(0), size - ivec2(1));
	return int(texelFetch(biome_map, cell, 0).r * 255.0 + 0.5);
}

vec4 cell_color(ivec2 cell, float variation) {
	int idx = index_at(cell);
	vec3 a = texelFetch(palette, ivec2(idx, 0), 0).rgb;
	vec3 b = texelFetch(palette, ivec2(idx, 1), 0).rgb;
	float water = texelFetch(palette, ivec2(idx, 2), 0).a;
	return vec4(mix(a, b, variation), water);
}

void fragment() {
	vec2 wp = UV * world_size;
	float n_large = texture(noise_tex, wp / 1500.0).r;
	float n_small = texture(noise_tex, wp / 380.0 + vec2(0.37, 0.71)).r;
	vec2 warp = vec2(n_large, texture(noise_tex, wp / 1500.0 + vec2(0.53, 0.19)).r) - 0.5;
	vec2 c = wp / cell_size + warp * 2.0 * warp_amount - 0.5;
	ivec2 base = ivec2(floor(c));
	vec2 f = smoothstep(0.15, 0.85, fract(c));
	vec4 c00 = cell_color(base, n_small);
	vec4 c10 = cell_color(base + ivec2(1, 0), n_small);
	vec4 c01 = cell_color(base + ivec2(0, 1), n_small);
	vec4 c11 = cell_color(base + ivec2(1, 1), n_small);
	vec4 blended = mix(mix(c00, c10, f.x), mix(c01, c11, f.x), f.y);
	vec3 col = blended.rgb;

	// Fine grain so large areas never look flat.
	float grain = texture(noise_tex, wp / 95.0).r;
	col *= 0.95 + 0.09 * grain;

	// Water: soft moving highlights and a lighter band near the shore.
	float water = blended.a;
	if (water > 0.01) {
		float t = TIME * 0.05 * motion;
		float ripple = texture(noise_tex, wp / 260.0 + vec2(t, t * 0.6)).r;
		float glint = smoothstep(0.72, 0.9, ripple) * 0.18;
		float shore = 1.0 - smoothstep(0.55, 1.0, water);
		col = mix(col, col + vec3(glint), water);
		col = mix(col, vec3(0.86, 0.93, 0.9), shore * 0.35 * water);
	}

	// Restoration: a gentle lift in warmth and saturation across the world.
	float lum = dot(col, vec3(0.299, 0.587, 0.114));
	vec3 muted = mix(vec3(lum), col, 0.86);
	vec3 lively = col * vec3(1.03, 1.02, 0.98);
	COLOR = vec4(mix(muted, lively, restoration), 1.0);
}
