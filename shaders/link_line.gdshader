shader_type canvas_item;

void fragment() {
	float edge_distance = length(UV) - 1.0;
	float blur = max(fwidth(edge_distance), 0.0001);
	COLOR.a *= clamp(0.5 - edge_distance / blur, 0.0, 1.0);
}
