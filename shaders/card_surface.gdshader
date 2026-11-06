shader_type canvas_item;

uniform vec2 rect_size = vec2(180.0, 100.0);
uniform vec4 bg_color : source_color;
uniform vec4 bg_color2 : source_color;
uniform vec4 border_color : source_color;
uniform float border_thickness = 2.0;
uniform float corner_radius = 8.0;
uniform sampler2D bg_texture : source_color, filter_linear_mipmap, repeat_disable;
uniform vec2 bg_texture_size = vec2(1.0);
uniform float bg_image_amount = 0.0;
uniform float bg_overlay_alpha = 0.55;

float sd_rounded_box(vec2 p, vec2 half_size, float r) {
	vec2 q = abs(p) - half_size + vec2(r);
	return min(max(q.x, q.y), 0.0) + length(max(q, vec2(0.0))) - r;
}

void fragment() {
	vec2 p = UV * rect_size - (rect_size * 0.5);
	vec2 half_size = rect_size * 0.5;
	
	float dist = sd_rounded_box(p, half_size, corner_radius);
	float pixel_size = fwidth(dist);
	float effective_border = max(border_thickness, pixel_size * 1.5);
	
	float outer_alpha = 1.0 - smoothstep(-pixel_size, 0.0, dist);
	float inner_mask = 1.0 - smoothstep(-pixel_size, 0.0, dist + effective_border);
	
	vec4 body = mix(bg_color, bg_color2, UV.y);
	if (bg_image_amount > 0.0) {
		float cover_scale = max(rect_size.x / bg_texture_size.x, rect_size.y / bg_texture_size.y);
		vec2 tex_uv = (UV * rect_size - rect_size * 0.5) / cover_scale / bg_texture_size + vec2(0.5);
		vec4 picture = texture(bg_texture, clamp(tex_uv, vec2(0.0), vec2(1.0)));
		vec3 shaded = mix(picture.rgb, vec3(0.0), bg_overlay_alpha);
		body.rgb = mix(body.rgb, shaded, picture.a * bg_image_amount);
	}

	vec4 col = mix(border_color, body, inner_mask);
	COLOR = vec4(col.rgb, col.a * outer_alpha) * COLOR;
}