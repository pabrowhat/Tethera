shader_type canvas_item;
render_mode blend_premul_alpha;

uniform vec2 rect_size = vec2(24.0, 24.0);
uniform vec4 fill_color : source_color = vec4(1.0);
uniform vec4 border_color : source_color = vec4(0.0);
uniform float border_width = 0.0;
uniform float corner_radius = -1.0;
uniform vec4 inner_color : source_color = vec4(0.0);
uniform float inner_inset = 0.0;
uniform bool inner_right_half = false;
uniform vec4 tick_color : source_color = vec4(0.0);
uniform vec2 tick_a = vec2(0.0);
uniform vec2 tick_b = vec2(0.0);
uniform vec2 tick_c = vec2(0.0);
uniform float tick_width = 1.4;

float sd_rounded_box(vec2 p, vec2 half_size, float r) {
	vec2 q = abs(p) - half_size + vec2(r);
	return min(max(q.x, q.y), 0.0) + length(max(q, vec2(0.0))) - r;
}

float sd_segment(vec2 p, vec2 a, vec2 b) {
	vec2 pa = p - a;
	vec2 ba = b - a;
	float h = clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0);
	return length(pa - ba * h);
}

vec4 premultiply(vec4 c) {
	return vec4(c.rgb * c.a, c.a);
}

void fragment() {
	vec2 half_size = rect_size * 0.5;
	vec2 p = UV * rect_size - half_size;
	float max_radius = min(half_size.x, half_size.y);
	float r = corner_radius < 0.0 ? max_radius : min(corner_radius, max_radius);

	float dist = sd_rounded_box(p, half_size, r);
	float px = max(fwidth(dist), 0.0001);
	float outer_alpha = 1.0 - smoothstep(-px, 0.0, dist);

	vec4 result = premultiply(fill_color);
	if (border_width > 0.0) {
		float effective_border = max(border_width, px);
		float inner_mask = 1.0 - smoothstep(-px, 0.0, dist + effective_border);
		result = premultiply(border_color) * (1.0 - inner_mask) + premultiply(fill_color) * inner_mask;
	}

	if (inner_color.a > 0.0) {
		vec2 inner_half = max(half_size - vec2(inner_inset), vec2(0.0));
		float inner_r = min(max(r - inner_inset, 0.0), min(inner_half.x, inner_half.y));
		float inner_dist = sd_rounded_box(p, inner_half, inner_r);
		if (inner_right_half) {
			inner_dist = max(inner_dist, -p.x);
		}
		float inner_alpha = 1.0 - smoothstep(-px, 0.0, inner_dist);
		result = premultiply(inner_color) * inner_alpha + result * (1.0 - inner_color.a * inner_alpha);
	}

	if (tick_color.a > 0.0) {
		float tick_dist = min(sd_segment(p, tick_a, tick_b), sd_segment(p, tick_b, tick_c)) - tick_width * 0.5;
		float tick_alpha = 1.0 - smoothstep(-px * 0.5, px * 0.5, tick_dist);
		result = premultiply(tick_color) * tick_alpha + result * (1.0 - tick_color.a * tick_alpha);
	}

	result.rgb *= COLOR.rgb;
	COLOR = result * outer_alpha * COLOR.a;
}
