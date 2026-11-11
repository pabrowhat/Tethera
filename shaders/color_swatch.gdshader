shader_type canvas_item;

uniform vec4 circle_color : source_color = vec4(1.0);
uniform bool is_selected = false;

float edge(float dist, float at, float blur) {
	return smoothstep(at - blur, at + blur, dist);
}

void fragment() {
	vec2 uv = UV - vec2(0.5);
	float dist = length(uv);
	float blur = max(fwidth(dist) * 0.5, 0.0001);
	float alpha = 1.0 - edge(dist, 0.465, blur);

	vec4 col = circle_color;
	if (is_selected) {
		float white = (1.0 - edge(dist, 0.44, blur)) * edge(dist, 0.36, blur);
		float dark = edge(dist, 0.44, blur) * (1.0 - edge(dist, 0.48, blur));
		col = mix(col, vec4(1.0), white);
		col = mix(col, vec4(0.0, 0.0, 0.0, 1.0), dark * 0.55);
		alpha = 1.0 - edge(dist, 0.49, blur);
	}

	COLOR = vec4(col.rgb, col.a * alpha);
}
