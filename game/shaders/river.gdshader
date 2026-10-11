shader_type canvas_item;
// Gentle moving glints on river lines, sampled in world space so the pattern
// flows continuously across segments.

uniform sampler2D noise_tex : repeat_enable, filter_linear;
uniform float motion = 1.0;
uniform vec2 flow = vec2(0.0, 1.0);

varying vec2 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

void fragment() {
	float t = TIME * 0.06 * motion;
	float n = texture(noise_tex, world_pos / 220.0 - flow * t).r;
	float glint = smoothstep(0.68, 0.88, n) * 0.22;
	COLOR = vec4(COLOR.rgb + vec3(glint), COLOR.a);
}
