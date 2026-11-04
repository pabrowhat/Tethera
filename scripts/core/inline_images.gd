class_name InlineImages
extends RefCounted

static var missing_reporter: Callable = Callable()

static var _images_dir: String = ""

static var _textures: Dictionary = {}
static var _reported: Dictionary = {}
static var _averages: Dictionary = {}

const AVERAGE_SAMPLES: int = 24

static func set_images_dir(dir: String) -> void:
	_images_dir = dir
	_textures.clear()
	_averages.clear()
	_reported.clear()

static func disk_path(reference: String) -> String:
	if _images_dir == "" or not NoteImages.is_vault_image(reference):
		return ""
	return _images_dir + reference.substr(VaultStorage.IMAGE_REF_PREFIX.length())

static func texture_for(path: String) -> Texture2D:
	var file_path: String = disk_path(path)
	if file_path == "" or not FileAccess.file_exists(file_path):
		_textures.erase(path)
		return null

	var cached: Variant = _textures.get(path, null)
	if cached is Texture2D:
		return cached as Texture2D

	var image: Image = ImageGuard.load_image(path)
	if image == null:
		return null
	_averages[path] = estimate_average_color(image)
	image.generate_mipmaps()
	var texture: ImageTexture = ImageTexture.create_from_image(image)
	texture.take_over_path(path)
	_textures[path] = texture
	_reported.erase(path)
	return texture

static func average_color_of(texture: Texture2D, fallback: Color) -> Color:
	if texture == null:
		return fallback
	var found: Variant = _averages.get(texture.resource_path, null)
	return found as Color if found is Color else fallback

static func estimate_average_color(image: Image) -> Color:
	var width: int = image.get_width()
	var height: int = image.get_height()
	if width <= 0 or height <= 0 or image.is_compressed():
		return Color.BLACK
	var red: float = 0.0
	var green: float = 0.0
	var blue: float = 0.0
	var weight: float = 0.0
	for row: int in AVERAGE_SAMPLES:
		var y: int = clampi(int((float(row) + 0.5) / float(AVERAGE_SAMPLES) * float(height)), 0, height - 1)
		for column: int in AVERAGE_SAMPLES:
			var x: int = clampi(int((float(column) + 0.5) / float(AVERAGE_SAMPLES) * float(width)), 0, width - 1)
			var pixel: Color = image.get_pixel(x, y)
			red += pixel.r * pixel.a
			green += pixel.g * pixel.a
			blue += pixel.b * pixel.a
			weight += pixel.a
	if weight <= 0.0:
		return Color.BLACK
	return Color(red / weight, green / weight, blue / weight, 1.0)

static func forget(path: String) -> void:
	_averages.erase(path)
	_textures.erase(path)
	_reported.erase(path)

static func report_missing(path: String) -> void:
	if _reported.has(path) or not missing_reporter.is_valid():
		return
	_reported[path] = true
	missing_reporter.call(path)
