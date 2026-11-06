class_name SnapshotExporter
extends Node

const CULL_LAYER: int = 1
const GRID_SHADER: Shader = preload("res://shaders/snapshot_grid.gdshader")

const TILE: int = 2048
const EXPORT_SCALE: float = 2.0
const MAX_SIDE: float = 8192.0
const MAX_PIXELS: float = 8192.0 * 4096.0
const PADDING: float = 80.0
const DRAW_TIMEOUT_MS: int = 2000

const BACKGROUND_KEY: StringName = &"canvas.background"
const DOT_KEY: StringName = &"canvas.dot"
const FALLBACK_SPACING: float = 32.0
const FALLBACK_DOT_RADIUS: float = 1.2

static func fit_scale(region_size: Vector2) -> float:
	var longest: float = maxf(maxf(region_size.x, region_size.y), 1.0)
	var area: float = maxf(region_size.x * region_size.y, 1.0)
	return minf(EXPORT_SCALE, minf(MAX_SIDE / longest, sqrt(MAX_PIXELS / area)))

func capture(canvas: Control, region: Rect2, px_per_unit: float, grid_material: Material) -> Image:
	var out_size: Vector2i = Vector2i(
		maxi(ceili(region.size.x * px_per_unit), 1),
		maxi(ceili(region.size.y * px_per_unit), 1)
	)
	var tile_px: Vector2i = Vector2i(mini(TILE, out_size.x), mini(TILE, out_size.y))
	var result: Image = Image.create_empty(out_size.x, out_size.y, false, Image.FORMAT_RGB8)

	var view: SubViewport = SubViewport.new()
	view.size = tile_px
	view.world_2d = get_viewport().world_2d
	view.canvas_cull_mask = CULL_LAYER
	view.transparent_bg = false
	view.disable_3d = true
	view.gui_disable_input = true
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(view)

	var backdrop_layer: CanvasLayer = CanvasLayer.new()
	backdrop_layer.layer = -1
	view.add_child(backdrop_layer)

	var backdrop_material: ShaderMaterial = _make_backdrop_material(grid_material, region.position, px_per_unit, tile_px)
	var backdrop: ColorRect = ColorRect.new()
	backdrop.size = Vector2(tile_px)
	backdrop.material = backdrop_material
	backdrop_layer.add_child(backdrop)

	var local_to_pixels: Transform2D = Transform2D(
		Vector2(px_per_unit, 0.0), Vector2(0.0, px_per_unit), -region.position * px_per_unit
	)
	var global_to_pixels: Transform2D = local_to_pixels * canvas.get_global_transform().affine_inverse()

	var tiles_x: int = ceili(float(out_size.x) / float(tile_px.x))
	var tiles_y: int = ceili(float(out_size.y) / float(tile_px.y))

	await get_tree().process_frame

	var complete: bool = true
	for tile_y: int in tiles_y:
		for tile_x: int in tiles_x:
			var origin: Vector2i = Vector2i(tile_x * tile_px.x, tile_y * tile_px.y)
			view.canvas_transform = Transform2D(Vector2.RIGHT, Vector2.DOWN, -Vector2(origin)) * global_to_pixels
			backdrop_material.set_shader_parameter("tile_origin", Vector2(origin))

			if not await _wait_for_draw():
				complete = false
				break

			var tile: Image = view.get_texture().get_image()
			if tile == null or tile.is_empty():
				complete = false
				break
			if tile.get_format() != Image.FORMAT_RGB8:
				tile.convert(Image.FORMAT_RGB8)
			var copy_size: Vector2i = Vector2i(
				mini(tile_px.x, out_size.x - origin.x),
				mini(tile_px.y, out_size.y - origin.y)
			)
			result.blit_rect(tile, Rect2i(Vector2i.ZERO, copy_size), origin)
		if not complete:
			break

	view.render_target_update_mode = SubViewport.UPDATE_DISABLED
	view.queue_free()
	return result if complete else null

func _wait_for_draw() -> bool:
	var state: Dictionary = {"drawn": false}
	var mark_drawn: Callable = func() -> void: state["drawn"] = true
	RenderingServer.frame_post_draw.connect(mark_drawn, CONNECT_ONE_SHOT)

	var deadline: int = Time.get_ticks_msec() + DRAW_TIMEOUT_MS
	while not bool(state["drawn"]) and Time.get_ticks_msec() < deadline:
		await get_tree().process_frame

	if not bool(state["drawn"]) and RenderingServer.frame_post_draw.is_connected(mark_drawn):
		RenderingServer.frame_post_draw.disconnect(mark_drawn)
	return bool(state["drawn"])

func _make_backdrop_material(source: Material, region_origin: Vector2, px_per_unit: float, tile_px: Vector2i) -> ShaderMaterial:
	var material: ShaderMaterial = ShaderMaterial.new()
	material.shader = GRID_SHADER

	var bg_color: Color = ThemeColors.color(BACKGROUND_KEY)
	var dot_color: Color = ThemeColors.color(DOT_KEY)
	var spacing: float = FALLBACK_SPACING
	var dot_radius: float = FALLBACK_DOT_RADIUS
	if source is ShaderMaterial:
		var live: ShaderMaterial = source as ShaderMaterial
		bg_color = _param_color(live, "bg_color", bg_color)
		dot_color = _param_color(live, "dot_color", dot_color)
		spacing = _param_float(live, "grid_spacing", spacing)
		dot_radius = _param_float(live, "dot_radius", dot_radius)
		var texture_value: Variant = live.get_shader_parameter("bg_texture")
		if texture_value is Texture2D and _param_bool(live, "use_texture", false):
			material.set_shader_parameter("bg_texture", texture_value)
			material.set_shader_parameter("bg_opacity", _param_float(live, "bg_opacity", 1.0))
			material.set_shader_parameter("use_texture", true)

	material.set_shader_parameter("bg_color", bg_color)
	material.set_shader_parameter("dot_color", dot_color)
	material.set_shader_parameter("grid_spacing", spacing)
	material.set_shader_parameter("dot_radius", dot_radius)
	material.set_shader_parameter("px_per_unit", px_per_unit)
	material.set_shader_parameter("region_origin", region_origin)
	material.set_shader_parameter("tile_origin", Vector2.ZERO)
	material.set_shader_parameter("tile_size", Vector2(tile_px))
	return material

func _param_color(material: ShaderMaterial, key: String, fallback: Color) -> Color:
	var value: Variant = material.get_shader_parameter(key)
	return value as Color if value is Color else fallback

func _param_bool(material: ShaderMaterial, key: String, fallback: bool) -> bool:
	var value: Variant = material.get_shader_parameter(key)
	return bool(value) if value is bool else fallback

func _param_float(material: ShaderMaterial, key: String, fallback: float) -> float:
	var value: Variant = material.get_shader_parameter(key)
	return float(value) if value is float else fallback
