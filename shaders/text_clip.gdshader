shader_type canvas_item;

uniform vec2 clip_size = vec2(100000.0);
uniform bool fade_on = false;
uniform float fade_height = 36.0;

varying vec2 local_pos;

void vertex() {
	local_pos = VERTEX;
}

void fragment() {
	if (local_pos.x < 0.0 || local_pos.y < 0.0 || local_pos.x > clip_size.x || local_pos.y > clip_size.y) {
		discard;
	}
	if (fade_on) {
		float t = clamp((local_pos.y - (clip_size.y - fade_height)) / fade_height, 0.0, 1.0);
		float covered = t < 0.55 ? 0.72 * t / 0.55 : 0.72 + 0.28 * (t - 0.55) / 0.45;
		COLOR.a *= 1.0 - covered;
	}
}
