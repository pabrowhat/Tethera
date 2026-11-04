class_name NoteBackground
extends RefCounted

static func sanitize_hex(value: Variant) -> String:
	var hex: String = str(value).strip_edges().trim_prefix("#")
	if hex == "" or not Color.html_is_valid(hex):
		return ""
	return Color(hex).to_html(false)

const FROM_NOTE: String = "note"
const FROM_TYPE: String = "type"
const FROM_DEFAULT: String = "default"

static func resolve(own_color: String, own_color2: String, own_image: String, entity_type: EntityType) -> Dictionary:
	var color: Variant = null
	var color2: Variant = null
	var color_from: String = FROM_DEFAULT
	var image: String = ""
	var image_from: String = FROM_DEFAULT

	if sanitize_hex(own_color) != "":
		color = Color(sanitize_hex(own_color))
		color_from = FROM_NOTE
		if sanitize_hex(own_color2) != "":
			color2 = Color(sanitize_hex(own_color2))
	elif entity_type != null and sanitize_hex(entity_type.bg_color) != "":
		color = Color(sanitize_hex(entity_type.bg_color))
		color_from = FROM_TYPE
		if sanitize_hex(entity_type.bg_color2) != "":
			color2 = Color(sanitize_hex(entity_type.bg_color2))

	if own_image != "":
		image = own_image
		image_from = FROM_NOTE
	elif entity_type != null and entity_type.bg_image != "":
		image = entity_type.bg_image
		image_from = FROM_TYPE

	return {"color": color, "color2": color2, "image": image, "color_from": color_from, "image_from": image_from}
