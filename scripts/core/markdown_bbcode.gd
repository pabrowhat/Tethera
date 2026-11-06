class_name MarkdownBBCode
extends RefCounted

enum Profile { CARD, PREVIEW }

const PLACEHOLDER_OPEN: String = "\u0001"
const PLACEHOLDER_CLOSE: String = "\u0002"
const NO_LINK_MARK: String = "\u0003"
const BRACKET_MARK: String = "\u0004"
const RESERVED_CHARS: Array[String] = ["\u0001", "\u0002", "\u0003", "\u0004"]

const SAFE_TAGS: Array[String] = ["b", "i", "u", "s", "code", "center", "left", "right"]
const COLOR_TAGS: Array[String] = ["color", "bgcolor"]
const LINK_TAG: String = "url"
const SAFE_LINK_PREFIXES: Array[String] = ["http://", "https://", "mailto:"]

const CARD_HEADING_SIZES: Array[int] = [16, 14, 13]
const PREVIEW_HEADING_SIZES: Array[int] = [28, 22, 18]
const HEADING_KEY: StringName = &"markdown.heading"
const WIKI_KEY: StringName = &"markdown.wiki"
const MISSING_IMAGE_KEY: StringName = &"markdown.missing_image"
const LINK_KEY: StringName = &"markdown.link"
const TAB_WIDTH: int = 4

const WIKI_META_PREFIX: String = "wiki:"
const IMAGE_META_PREFIX: String = "img:"

static var _protect_re: RegEx = null
static var _restore_re: RegEx = null
static var _heading_re: RegEx = null
static var _list_re: RegEx = null
static var _md_link_re: RegEx = null
static var _tag_re: RegEx = null
static var _color_name_re: RegEx = null
static var _inline_rules: Array[Dictionary] = []

static func to_bbcode(text: String, profile: Profile = Profile.CARD, max_image_width: int = 0, heading_color: String = "") -> String:
	if text.is_empty():
		return text
	_ensure_regex()

	var clean: String = text
	for reserved: String in RESERVED_CHARS:
		clean = clean.replace(reserved, "")

	var tokens: Array[String] = []
	var guarded: String = _protect(clean, tokens)

	var lines: Array[String] = []
	var list_indents: Array[int] = []
	for raw_line: String in guarded.split("\n"):
		var item: RegExMatch = _list_re.search(raw_line)
		if item != null:
			_append_list_item(lines, list_indents, _indent_width(item.get_string(1)), _inline(item.get_string(2)))
		else:
			_close_lists(lines, list_indents)
			lines.append(_format_block(raw_line, profile, heading_color))
	_close_lists(lines, list_indents)

	return _restore("\n".join(PackedStringArray(lines)), tokens, profile, max_image_width).replace(BRACKET_MARK, "[lb]")

static func _hex(key: StringName) -> String:
	return "#" + ThemeColors.color(key).to_html(false)

static func _ensure_regex() -> void:
	if _protect_re != null:
		return

	_protect_re = RegEx.create_from_string(
		NoteImages.token_pattern()
		+ "|\\[[^\\[\\]\\n]+\\]\\((?:https?://|mailto:)[^()\\s\\[\\]]+\\)"
		+ "|\\[\\[[^\\[\\]\\n]+\\]\\]"
		+ "|\\[/?[A-Za-z_][A-Za-z0-9_]*(?:[= ][^\\[\\]\\n]*)?\\]"
		+ "|https?://[^\\s\\[\\]<>]*[^\\s\\[\\]<>.,;:!?)\"']"
	)
	_md_link_re = RegEx.create_from_string("^\\[([^\\[\\]\\n]+)\\]\\(([^()\\s]+)\\)$")
	_tag_re = RegEx.create_from_string("^\\[(/?)([A-Za-z_][A-Za-z0-9_]*)(?:=([^\\[\\]\\n]*))?\\]$")
	_color_name_re = RegEx.create_from_string("^[A-Za-z_]+$")
	_restore_re = RegEx.create_from_string("\\x01(\\d+)\\x02")
	_heading_re = RegEx.create_from_string("^(#{1,6})[ \\t]+(.*\\S)[ \\t]*$")
	_list_re = RegEx.create_from_string("^([ \\t]*)[-*+][ \\t]+(.*)$")

	var rules: Array[Array] = [
		["\\*\\*\\*(?=\\S)(.+?)(?<=\\S)\\*\\*\\*", "[b][i]$1[/i][/b]"],
		["\\*\\*(?=\\S)(.+?)(?<=\\S)\\*\\*", "[b]$1[/b]"],
		["__(?=\\S)(.+?)(?<=\\S)__", "[b]$1[/b]"],
		["~~(?=\\S)(.+?)(?<=\\S)~~", "[s]$1[/s]"],
		["\\*(?=[^\\s*])(.+?)(?<=[^\\s*])\\*", "[i]$1[/i]"],
		["(?<![A-Za-z0-9_])_(?=[^\\s_])(.+?)(?<=[^\\s_])_(?![A-Za-z0-9_])", "[i]$1[/i]"],
	]
	for rule: Array in rules:
		_inline_rules.append({
			"regex": RegEx.create_from_string(str(rule[0])),
			"replacement": str(rule[1]),
		})

static func _protect(text: String, tokens: Array[String]) -> String:
	var result: String = ""
	var cursor: int = 0
	for found: RegExMatch in _protect_re.search_all(text):
		var token: String = found.get_string()
		result += text.substr(cursor, found.get_start() - cursor).replace("[", BRACKET_MARK)

		if token.begins_with("http") and found.get_start() == cursor and not tokens.is_empty():
			var previous: String = tokens[tokens.size() - 1]
			if previous.begins_with("[url") or previous.begins_with("[img"):
				token = NO_LINK_MARK + token

		result += PLACEHOLDER_OPEN + str(tokens.size()) + PLACEHOLDER_CLOSE
		tokens.append(token)
		cursor = found.get_end()
	return result + text.substr(cursor).replace("[", BRACKET_MARK)

static func _restore(text: String, tokens: Array[String], profile: Profile, max_image_width: int) -> String:
	var result: String = ""
	var cursor: int = 0
	for found: RegExMatch in _restore_re.search_all(text):
		result += text.substr(cursor, found.get_start() - cursor)
		var index: int = found.get_string(1).to_int()
		if index >= 0 and index < tokens.size():
			result += _render_token(tokens[index], profile, max_image_width)
		cursor = found.get_end()
	return result + text.substr(cursor)

static func _render_token(token: String, profile: Profile, max_image_width: int) -> String:
	var interactive: bool = profile == Profile.PREVIEW

	if token.begins_with(NO_LINK_MARK):
		return token.substr(NO_LINK_MARK.length())

	if token.begins_with("![") or token.begins_with("[img"):
		var picture: Dictionary = NoteImages.parse_token(token)
		if not picture.is_empty():
			var image_tag: String = _image_bbcode(picture, max_image_width)
			if interactive and image_tag.begins_with("[img"):
				return "[url=%s%s][color=#00000000]%s[/color][/url]" % [IMAGE_META_PREFIX, str(picture["path"]), image_tag]
			return image_tag

	if token.begins_with("[["):
		var inner: String = token.substr(2, token.length() - 4)
		if not WikiLink.is_note_link(inner):
			return "[lb][lb]%s[rb][rb]" % inner
		var styled: String = "[color=%s][lb][lb]%s[rb][rb][/color]" % [_hex(WIKI_KEY), WikiLink.display_text(inner)]
		var title: String = WikiLink.split(inner)["title"]
		return "[url=%s%s]%s[/url]" % [WIKI_META_PREFIX, title, styled] if interactive else styled

	if token.begins_with("http"):
		if not interactive:
			return token
		return "[url=%s][color=%s]%s[/color][/url]" % [token, _hex(LINK_KEY), token]

	var md_link: RegExMatch = _md_link_re.search(token)
	if md_link != null:
		var label: String = _inline(md_link.get_string(1))
		if interactive:
			return "[url=%s][color=%s]%s[/color][/url]" % [md_link.get_string(2), _hex(LINK_KEY), label]
		return "[color=%s][u]%s[/u][/color]" % [_hex(LINK_KEY), label]

	return token if _is_safe_tag(token) else "[lb]" + token.substr(1)

static func _is_safe_tag(token: String) -> bool:
	var tag: RegExMatch = _tag_re.search(token)
	if tag == null:
		return false
	var closing: bool = tag.get_string(1) == "/"
	var tag_name: String = tag.get_string(2).to_lower()
	var has_value: bool = token.contains("=")
	var value: String = tag.get_string(3).strip_edges()
	if closing:
		return not has_value and (SAFE_TAGS.has(tag_name) or COLOR_TAGS.has(tag_name) or tag_name == LINK_TAG)
	if SAFE_TAGS.has(tag_name):
		return not has_value
	if COLOR_TAGS.has(tag_name):
		return Color.html_is_valid(value) or _color_name_re.search(value) != null
	if tag_name == LINK_TAG:
		if not has_value:
			return true
		for prefix: String in SAFE_LINK_PREFIXES:
			if value.to_lower().begins_with(prefix) and not value.contains(" "):
				return true
	return false

static func _image_bbcode(picture: Dictionary, max_image_width: int) -> String:
	var path: String = str(picture["path"])
	var texture: Texture2D = InlineImages.texture_for(path)
	if texture == null:
		InlineImages.report_missing(path)
		var shown_name: String = path.get_file().replace("[", "(").replace("]", ")")
		var message: String = str(TranslationServer.translate("image.missing")).replace("%s", shown_name)
		return "[color=%s][i]%s[/i][/color]" % [_hex(MISSING_IMAGE_KEY), message]

	var width: int = int(picture["width"])
	if width <= 0:
		width = texture.get_width()
	if max_image_width > 0:
		width = mini(width, max_image_width)
	return "[img width=%d]%s[/img]" % [maxi(width, 1), path]

static func _format_block(line: String, profile: Profile, heading_color: String) -> String:
	var heading: RegExMatch = _heading_re.search(line)
	if heading == null:
		return _inline(line)

	var sizes: Array[int] = PREVIEW_HEADING_SIZES if profile == Profile.PREVIEW else CARD_HEADING_SIZES
	var level: int = mini(heading.get_string(1).length(), sizes.size())
	var font_px: int = sizes[level - 1]
	return "[font_size=%d][b][color=%s]%s[/color][/b][/font_size]" % [font_px, heading_color if heading_color != "" else _hex(HEADING_KEY), _inline(heading.get_string(2))]

static func _inline(text: String) -> String:
	var result: String = text
	for rule: Dictionary in _inline_rules:
		result = (rule["regex"] as RegEx).sub(result, rule["replacement"] as String, true)
	return result

static func _indent_width(whitespace: String) -> int:
	var width: int = 0
	for i: int in whitespace.length():
		width += TAB_WIDTH if whitespace[i] == "\t" else 1
	return width

static func _append_list_item(lines: Array[String], indents: Array[int], indent: int, body: String) -> void:
	var closing: String = ""
	while not indents.is_empty() and indent < indents[indents.size() - 1]:
		indents.pop_back()
		closing += "[/ul]"
	if closing != "" and not lines.is_empty():
		lines[lines.size() - 1] += closing

	var prefix: String = ""
	if indents.is_empty() or indent > indents[indents.size() - 1]:
		indents.append(indent)
		prefix = "[ul]"
	lines.append(prefix + body)

static func _close_lists(lines: Array[String], indents: Array[int]) -> void:
	if indents.is_empty():
		return
	if not lines.is_empty():
		lines[lines.size() - 1] += "[/ul]".repeat(indents.size())
	indents.clear()
