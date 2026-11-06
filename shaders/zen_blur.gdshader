shader_type canvas_item;

uniform sampler2D screen_tex : hint_screen_texture, filter_linear;
uniform float strength : hint_range(0.0, 8.0) = 0.0;
uniform float dim : hint_range(0.0, 1.0) = 0.0;
uniform float vignette : hint_range(0.0, 1.0) = 0.0;
uniform vec4 shade_color : source_color;

const vec2 RING_A[6] = vec2[6](
	vec2(1.0, 0.0), vec2(0.5, 0.866), vec2(-0.5, 0.866),
	vec2(-1.0, 0.0), vec2(-0.5, -0.866), vec2(0.5, -0.866)
);
const vec2 RING_B[6] = vec2[6](
	vec2(0.866, 0.5), vec2(0.0, 1.0), vec2(-0.866, 0.5),
	vec2(-0.866, -0.5), vec2(0.0, -1.0), vec2(0.866, -0.5)
);

void fragment() {
	vec2 px = SCREEN_PIXEL_SIZE * strength;
	vec3 base = texture(screen_tex, SCREEN_UV).rgb;
	vec3 col = base;

	if (strength > 0.01) {
		vec3 sum = base * 0.14;
		float total = 0.14;
		for (int i = 0; i < 6; i++) {
			sum += texture(screen_tex, SCREEN_UV + RING_A[i] * px * 0.35).rgb * 0.06;
			sum += texture(screen_tex, SCREEN_UV + RING_B[i] * px * 0.7).rgb * 0.0433;
			sum += texture(screen_tex, SCREEN_UV + RING_A[i] * px * 1.0).rgb * 0.04;
			total += 0.06 + 0.0433 + 0.04;
		}
		col = sum / total;
	}

	vec2 centered = (SCREEN_UV - vec2(0.5)) * vec2(1.0, 0.85);
	float edge = smoothstep(0.3, 0.8, length(centered));
	col = mix(col, shade_color.rgb, clamp(dim + vignette * edge * 0.5, 0.0, 1.0));
	COLOR = vec4(col, 1.0);
}
