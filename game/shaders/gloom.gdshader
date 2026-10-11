// Gloom veil: inside a soft, slowly breathing circle the world loses most of
// its color and dims to cool blue-grey. `strength` fades to 0 when the gloom
// is cleared, so color visibly flows back. Original shader for CALMQUEST.
shader_type canvas_item;

uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
uniform float strength : hint_range(0.0, 1.0) = 1.0;
uniform float seed = 0.0;
uniform float motion = 1.0;

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float d = length(p);
	float wobble = 0.05 * sin(atan(p.y, p.x) * 5.0 + TIME * 0.35 * motion + seed);
	float mask = (1.0 - smoothstep(0.5 + wobble, 1.0, d)) * strength;
	vec3 c = textureLod(screen_tex, SCREEN_UV, 0.0).rgb;
	float grey = dot(c, vec3(0.299, 0.587, 0.114));
	vec3 gloom = mix(c, vec3(grey), 0.85) * vec3(0.70, 0.72, 0.83);
	COLOR = vec4(mix(c, gloom, mask), 1.0);
}
