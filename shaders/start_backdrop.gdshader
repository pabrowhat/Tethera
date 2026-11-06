shader_type canvas_item;

uniform vec2 rect_size = vec2(1280.0, 720.0);
uniform float speed = 1.0;
uniform vec4 base_color : source_color;
uniform vec4 glow_a : source_color;
uniform vec4 glow_b : source_color;
uniform vec4 star_color : source_color;
uniform vec4 vignette_color : source_color;

float hash(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

float value_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x),
		mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

float fbm(vec2 p) {
	float value = 0.0;
	float amplitude = 0.5;
	for (int i = 0; i < 5; i++) {
		value += amplitude * value_noise(p);
		p = p * 2.02 + vec2(17.0, 9.0);
		amplitude *= 0.5;
	}
	return value;
}

void fragment() {
	vec2 uv = (UV - 0.5) * vec2(rect_size.x / rect_size.y, 1.0);
	float t = TIME * 0.03 * speed;

	vec2 q = vec2(fbm(uv * 1.6 + vec2(t, 0.0)), fbm(uv * 1.6 + vec2(5.2 - t, 1.3)));
	float n = fbm(uv * 1.8 + 2.0 * q + vec2(t * 2.0, -t));

	vec3 col = base_color.rgb;
	col = mix(col, glow_a.rgb, smoothstep(0.3, 0.8, n) * 0.5);
	col = mix(col, glow_b.rgb, smoothstep(0.45, 0.95, q.x * q.y * 2.2) * 0.3);

	vec2 grid = uv * 38.0;
	vec2 cell = floor(grid);
	vec2 local = fract(grid) - 0.5;
	float h = hash(cell);
	vec2 offset = (vec2(hash(cell + 3.1), hash(cell + 7.7)) - 0.5) * 0.5;
	float star = step(0.93, h) * smoothstep(0.12, 0.0, length(local - offset));
	star *= 0.5 + 0.5 * sin(TIME * speed * (1.0 + h * 2.0) + h * 40.0);
	col = mix(col, star_color.rgb, star * 0.6);

	col = mix(col, vignette_color.rgb, smoothstep(0.35, 0.95, length(UV - 0.5) * 1.25) * 0.55);
	COLOR = vec4(col, 1.0);
}
