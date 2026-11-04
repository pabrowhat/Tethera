shader_type canvas_item;

uniform float hue : hint_range(0.0, 1.0) = 0.0;

vec3 hsv2rgb(vec3 c) {
	vec3 p = abs(fract(c.xxx + vec3(1.0, 2.0 / 3.0, 1.0 / 3.0)) * 6.0 - vec3(3.0));
	return c.z * mix(vec3(1.0), clamp(p - vec3(1.0), 0.0, 1.0), c.y);
}

void fragment() {
	COLOR = vec4(hsv2rgb(vec3(hue, UV.x, 1.0 - UV.y)), 1.0);
}
