shader_type canvas_item;

uniform vec4 circle_color : source_color = vec4(1.0);
uniform bool is_selected = false;

void fragment() {
	vec2 uv = UV - vec2(0.5);
	float dist = length(uv);
	float alpha = 1.0 - smoothstep(0.45, 0.48, dist);
	
	vec4 col = circle_color;
	if (is_selected) {
		float ring = smoothstep(0.48, 0.44, dist) * (1.0 - smoothstep(0.36, 0.40, dist));
		col = mix(col, vec4(1.0, 1.0, 1.0, 1.0), ring);
	}
	
	COLOR = vec4(col.rgb, col.a * alpha);
}