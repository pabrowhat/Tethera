shader_type canvas_item;

uniform vec4 bg_color : source_color;
uniform vec4 dot_color : source_color;
uniform float grid_spacing = 32.0;
uniform float dot_radius = 1.2;
uniform float px_per_unit = 1.0;
uniform vec2 region_origin = vec2(0.0);
uniform vec2 tile_origin = vec2(0.0);
uniform vec2 tile_size = vec2(1.0);

uniform sampler2D bg_texture : source_color, filter_linear_mipmap, repeat_enable;
uniform float bg_opacity = 1.0;
uniform bool use_texture = false;

void fragment() {
	vec2 export_px = tile_origin + UV * tile_size;
	vec2 world_coord = region_origin + export_px / px_per_unit;

	vec4 base = bg_color;
	if (use_texture) {
		vec4 tex = texture(bg_texture, world_coord / vec2(textureSize(bg_texture, 0)));
		base = mix(bg_color, vec4(tex.rgb, 1.0), tex.a * bg_opacity);
	}

	vec2 cell = mod(world_coord + (grid_spacing * 0.5), grid_spacing) - (grid_spacing * 0.5);
	float dist = length(cell);

	float px = fwidth(dist);
	float alpha = 1.0 - smoothstep(dot_radius - px, dot_radius + px, dist);

	float lod_fade = clamp((px_per_unit - 0.12) * 5.0, 0.0, 1.0);

	COLOR = mix(base, dot_color, alpha * dot_color.a * lod_fade);
}
