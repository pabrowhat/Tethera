shader_type canvas_item;

uniform vec4 circle_color : source_color = vec4(1.0);
uniform bool is_selected = false;

void fragment() {
	vec2 uv = UV - vec2(0.5);
	float dist = length(uv);
	float alpha = 1.0 - smoothstep(0.45, 0.48, dist);
	
	vec4 col = circle_color;
	if (is_selected) {
		float white = (1.0 - smoothstep(0.43, 0.45, dist)) * smoothstep(0.35, 0.37, dist);
		float dark = smoothstep(0.43, 0.45, dist) * (1.0 - smoothstep(0.47, 0.49, dist));
		col = mix(col, vec4(1.0), white);
		col = mix(col, vec4(0.0, 0.0, 0.0, 1.0), dark * 0.55);
		alpha = 1.0 - smoothstep(0.48, 0.5, dist);
	}
	
	COLOR = vec4(col.rgb, col.a * alpha);
}
