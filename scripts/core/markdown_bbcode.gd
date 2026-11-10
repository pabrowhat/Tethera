class_name MarkdownBBCode
extends RefCounted

enum Profile { CARD, PREVIEW }

const PLACEHOLDER_OPEN: String = "\u0001"
const PLACEHOLDER_CLOSE: String = "\u0002"
const NO_LINK_MARK: String = "\u0003"
const BRACKET_MARK: String = "\u0004"
const CHECK_OFF_MARK: String = "\u0005"
const CHECK_ON_MARK: String = "\u0006"
const RESERVED_CHARS: Array[String] = ["\u0001", "\u0002", "\u0003", "\u0004", "\u0005", "\u0006"]

const SAFE_TAGS: Array[String] = ["b", "i", "u", "s", "code", "center", "left", "right", "indent", "cell"]
const SINGLE_TAGS: Array[String] = ["br"]
const COLOR_TAGS: Array[String] = ["color", "bgcolor"]
const LINK_TAG: String = "url"
const FONT_SIZE_TAG: String = "font_size"
const TABLE_TAG: String = "table"
const FONT_SIZE_MIN: int = 8
const FONT_SIZE_MAX: int = 64
const CARD_FONT_SIZE_MAX: int = 24
const TABLE_COLUMNS_MIN: int = 1
const TABLE_COLUMNS_MAX: int = 8
const SAFE_LINK_PREFIXES: Array[String] = ["http://", "https://", "mailto:"]

const CARD_HEADING_SIZES: Array[int] = [16, 14, 13]
const PREVIEW_HEADING_SIZES: Array[int] = [28, 22, 18]
const HEADING_KEY: StringName = &"markdown.heading"
const WIKI_KEY: StringName = &"markdown.wiki"
const MISSING_IMAGE_KEY: StringName = &"markdown.missing_image"
const LINK_KEY: StringName = &"markdown.link"
const QUOTE_KEY: StringName = &"markdown.quote"
const RULE_KEY: StringName = &"border"
const TABLE_HEAD_KEY: StringName = &"markdown.table_head"
const TABLE_PAD_CARD: String = "4,2,4,2"
const TABLE_PAD_PREVIEW: String = "6,3,6,3"
const COPY_ICON: String = "res://assets/icons/copy.svg"
const COPIED_ICON: String = "res://assets/icons/check.svg"
const COPY_ICON_SIZE: int = 14
const TAB_WIDTH: int = 4
const CHECK_INDENT_WIDTH: int = 2
const CHECK_MAX_LEVELS: int = 4
const CHECK_OFF_ICON: String = "res://assets/icons/square.svg"
const CHECK_ON_ICON: String = "res://assets/icons/square-check.svg"
const CHECK_ICON_SIZE: int = 15
const CHECK_PAD: String = " "
const CODE_BG_KEY: StringName = &"markdown.code_bg"
const CODE_TEXT_KEY: StringName = &"text.primary"
const LIST_BULLET: String = "ul"
const LIST_NUMBERED: String = "ol"

const WIKI_META_PREFIX: String = "wiki:"
const IMAGE_META_PREFIX: String = "img:"
const CHECK_META_PREFIX: String = "check:"
const COPY_META_PREFIX: String = "copy:"

static var _protect_re: RegEx = null
static var _restore_re: RegEx = null
static var _heading_re: RegEx = null
static var _list_re: RegEx = null
static var _ordered_re: RegEx = null
static var _quote_re: RegEx = null
static var _fence_re: RegEx = null
static var _align_open_re: RegEx = null
static var _align_close_re: RegEx = null
static var _check_source_re: RegEx = null
static var _check_line_re: RegEx = null
static var _separator_cell_re: RegEx = null
static var _int_re: RegEx = null
static var _md_link_re: RegEx = null
static var _tag_re: RegEx = null
static var _color_name_re: RegEx = null
static var _inline_rules: Array[Dictionary] = []

static func to_bbcode(text: String, profile: Profile = Profile.CARD, max_image_width: int = 0, heading_color: String = "", copied_line: int = -1) -> String:
	if text.is_empty():
		return text
	_ensure_regex()

	var clean: String = text
	for reserved: String in RESERVED_CHARS:
		clean = clean.replace(reserved, "")

	var raw_lines: PackedStringArray = clean.split("\n")
	var tokens: Array[String] = []
	var guarded_lines: PackedStringArray = _protect("\n".join(_mark_checklists(raw_lines)), tokens).split("\n")

	var lines: Array[String] = []
	var list_indents: Array[int] = []
	var list_kinds: Array[String] = []
	var index: int = 0
	while index < guarded_lines.size():
		var guarded: String = guarded_lines[index]
		var bullet: RegExMatch = _list_re.search(guarded)
		var numbered: RegExMatch = _ordered_re.search(guarded)
		var checklist: RegExMatch = _check_line_re.search(guarded)

		if checklist == null and bullet != null:
			_append_list_item(lines, list_indents, list_kinds, _indent_width(bullet.get_string(1)), LIST_BULLET, _inline(bullet.get_string(2)))
			index += 1
			continue
		if numbered != null:
			_append_list_item(lines, list_indents, list_kinds, _indent_width(numbered.get_string(1)), LIST_NUMBERED, _inline(numbered.get_string(2)))
			index += 1
			continue

		_close_lists(lines, list_indents, list_kinds)
		if _align_open_re.search(raw_lines[index]) != null and _block_starts(raw_lines, guarded_lines, index + 1):
			index = _append_aligned_block(lines, raw_lines, guarded_lines, index, profile, copied_line)
		elif _fence_re.search(raw_lines[index]) != null:
			index = _append_code_block(lines, raw_lines, index, profile, copied_line)
		elif _table_columns(guarded_lines, index) > 0:
			index = _append_table(lines, guarded_lines, index, profile)
		else:
			lines.append(_format_line(guarded, checklist, index, profile, heading_color))
			index += 1
	_close_lists(lines, list_indents, list_kinds)

	return _restore("\n".join(PackedStringArray(lines)), tokens, profile, max_image_width).replace(BRACKET_MARK, "[lb]")

static func _hex(key: StringName) -> String:
	return "#" + ThemeColors.color(key).to_html(false)

static func _ensure_regex() -> void:
	if _protect_re != null:
		return

	_protect_re = RegEx.create_from_string(
		"(?<!`)`[^`\\n]+`(?!`)|"
		+ NoteImages.token_pattern()
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
	_ordered_re = RegEx.create_from_string("^([ \\t]*)[0-9]+\\.[ \\t]+(.*)$")
	_quote_re = RegEx.create_from_string("^[ \\t]*>(?:[ \\t](.*))?$")
	_fence_re = RegEx.create_from_string("^[ \\t]*```[A-Za-z0-9_+#.-]*[ \\t]*$")
	_check_source_re = RegEx.create_from_string("^([ \\t]*[-*+][ \\t]+)\\[([ xX])\\]((?:[ \\t].*)?)$")
	_check_line_re = RegEx.create_from_string("^([ \\t]*)[-*+][ \\t]+[\\x05\\x06](?:[ \\t]+(.*))?$")
	_align_open_re = RegEx.create_from_string("^[ \\t]*[\\[<](left|center|right)[\\]>][ \\t]*$")
	_align_close_re = RegEx.create_from_string("^[ \\t]*[\\[<]/(left|center|right)[\\]>][ \\t]*$")
	_separator_cell_re =RegEx.create_from_string("^:?-+:?$")
	_int_re = RegEx.create_from_string("^[0-9]{1,4}$")

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

	if token.begins_with("`"):
		return "[color=%s][code]%s[/code][/color]" % [_hex(CODE_TEXT_KEY), token.substr(1, token.length() - 2).replace("[", "[lb]")]

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
		return "[url=%s%s][u]%s[/u][/url]" % [WIKI_META_PREFIX, title, styled] if interactive else styled

	if token.begins_with("http"):
		if not interactive:
			return token
		return "[url=%s][u][color=%s]%s[/color][/u][/url]" % [token, _hex(LINK_KEY), token]

	var md_link: RegExMatch = _md_link_re.search(token)
	if md_link != null:
		var label: String = _inline(md_link.get_string(1))
		if interactive:
			return "[url=%s][u][color=%s]%s[/color][/u][/url]" % [md_link.get_string(2), _hex(LINK_KEY), label]
		return "[color=%s][u]%s[/u][/color]" % [_hex(LINK_KEY), label]

	var checked: String = _checked_tag(token, profile)
	return checked if checked != "" else "[lb]" + token.substr(1)

static func _checked_tag(token: String, profile: Profile) -> String:
	var tag: RegExMatch = _tag_re.search(token)
	if tag == null:
		return ""
	var closing: bool = tag.get_string(1) == "/"
	var tag_name: String = tag.get_string(2).to_lower()
	var has_value: bool = token.contains("=")
	var value: String = tag.get_string(3).strip_edges()
	if SINGLE_TAGS.has(tag_name):
		return token if not closing and not has_value else ""
	if closing:
		var paired: bool = SAFE_TAGS.has(tag_name) or COLOR_TAGS.has(tag_name) or tag_name == LINK_TAG or tag_name == FONT_SIZE_TAG or tag_name == TABLE_TAG
		return token if paired and not has_value else ""
	if SAFE_TAGS.has(tag_name):
		return token if not has_value else ""
	if COLOR_TAGS.has(tag_name):
		return token if Color.html_is_valid(value) or _color_name_re.search(value) != null else ""
	if tag_name == FONT_SIZE_TAG:
		var pixels: int = _bounded_int(value, FONT_SIZE_MIN, FONT_SIZE_MAX)
		if pixels < 0:
			return ""
		return "[%s=%d]" % [FONT_SIZE_TAG, mini(pixels, CARD_FONT_SIZE_MAX) if profile == Profile.CARD else pixels]
	if tag_name == TABLE_TAG:
		var columns: int = _bounded_int(value, TABLE_COLUMNS_MIN, TABLE_COLUMNS_MAX)
		return "[%s=%d]" % [TABLE_TAG, columns] if columns >= 0 else ""
	if tag_name == LINK_TAG:
		if not has_value:
			return token
		for prefix: String in SAFE_LINK_PREFIXES:
			if value.to_lower().begins_with(prefix) and not value.contains(" "):
				return token
	return ""

static func _bounded_int(value: String, low: int, high: int) -> int:
	if _int_re.search(value) == null:
		return -1
	var number: int = value.to_int()
	return number if number >= low and number <= high else -1

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

static func _format_line(line: String, checklist: RegExMatch, line_index: int, profile: Profile, heading_color: String) -> String:
	if checklist != null:
		return _checklist_markup(checklist, line_index, profile, heading_color)
	if _trim(line) == "---":
		return "[hr color=%s]" % _hex(RULE_KEY)
	var quote: RegExMatch = _quote_re.search(line)
	if quote != null:
		return "[indent][color=%s]%s[/color][/indent]" % [_hex(QUOTE_KEY), _inline(quote.get_string(1))]
	return _format_block(line, profile, heading_color)

static func _mark_checklists(lines: PackedStringArray) -> PackedStringArray:
	var marked: PackedStringArray = lines.duplicate()
	for index: int in marked.size():
		var item: RegExMatch = _check_source_re.search(marked[index])
		if item != null:
			marked[index] = item.get_string(1) + (CHECK_OFF_MARK if item.get_string(2) == " " else CHECK_ON_MARK) + item.get_string(3)
	return marked

static func _checklist_markup(item: RegExMatch, line_index: int, profile: Profile, ink_color: String) -> String:
	var icon: String = CHECK_ON_ICON if item.get_string(0).contains(CHECK_ON_MARK) else CHECK_OFF_ICON
	var glyph: String = "[img width=%d height=%d color=%s]%s[/img]" % [CHECK_ICON_SIZE, CHECK_ICON_SIZE, ink_color if ink_color != "" else _hex(HEADING_KEY), icon]
	if profile == Profile.PREVIEW:
		glyph = "[url=%s%d]%s%s%s[/url]" % [CHECK_META_PREFIX, line_index, CHECK_PAD, glyph, CHECK_PAD]
	var levels: int = mini(int(_indent_width(item.get_string(1)) / float(CHECK_INDENT_WIDTH)), CHECK_MAX_LEVELS)
	return "[indent]".repeat(levels) + glyph + " " + _inline(item.get_string(2)) + "[/indent]".repeat(levels)

static func code_block_at(text: String, start: int) -> String:
	_ensure_regex()
	var raw_lines: PackedStringArray = text.split("\n")
	if start < 0 or start >= raw_lines.size() or _fence_re.search(raw_lines[start]) == null:
		return ""
	return "\n".join(_read_code_block(raw_lines, start)["body"] as PackedStringArray)

static func _read_code_block(raw_lines: PackedStringArray, start: int) -> Dictionary:
	var end: int = start + 1
	var body: PackedStringArray = PackedStringArray()
	while end < raw_lines.size() and raw_lines[end].strip_edges() != "```":
		body.append(raw_lines[end])
		end += 1
	return {"body": body, "end": end + 1}

static func _block_starts(raw_lines: PackedStringArray, guarded_lines: PackedStringArray, index: int) -> bool:
	return index < raw_lines.size() and (_fence_re.search(raw_lines[index]) != null or _table_columns(guarded_lines, index) > 0)

static func _append_aligned_block(lines: Array[String], raw_lines: PackedStringArray, guarded_lines: PackedStringArray, start: int, profile: Profile, copied_line: int) -> int:
	var tag: String = _align_open_re.search(raw_lines[start]).get_string(1)
	var inner: Array[String] = []
	var next: int = start + 1
	if _fence_re.search(raw_lines[next]) != null:
		next = _append_code_block(inner, raw_lines, next, profile, copied_line)
	else:
		next = _append_table(inner, guarded_lines, next, profile)
	if next < raw_lines.size():
		var closing: RegExMatch = _align_close_re.search(raw_lines[next])
		if closing != null and closing.get_string(1) == tag:
			next += 1
	lines.append("[%s]%s[/%s]" % [tag, inner[0], tag])
	return next

static func _append_code_block(lines: Array[String], raw_lines: PackedStringArray, start: int, profile: Profile, copied_line: int) -> int:
	var block: Dictionary = _read_code_block(raw_lines, start)
	var inner: String = "[color=%s][code]%s[/code][/color]" % [_hex(CODE_TEXT_KEY), "\n".join(block["body"] as PackedStringArray).replace("[", "[lb]")]
	if profile == Profile.PREVIEW:
		var icon: String = COPIED_ICON if copied_line == start else COPY_ICON
		inner = "[right][url=%s%d][img width=%d height=%d color=%s]%s[/img][/url][/right]\n%s" % [COPY_META_PREFIX, start, COPY_ICON_SIZE, COPY_ICON_SIZE, _hex(LINK_KEY), icon, inner]
	lines.append("[table=1][cell bg=%s padding=10,6,10,8]%s[/cell][/table]" % [_hex(CODE_BG_KEY), inner])
	return int(block["end"])

static func _trim(value: String) -> String:
	return value.lstrip(" \t").rstrip(" \t")

static func _split_row(line: String) -> PackedStringArray:
	var body: String = _trim(line)
	if body.begins_with("|"):
		body = body.substr(1)
	if body.ends_with("|"):
		body = body.left(body.length() - 1)
	var cells: PackedStringArray = body.split("|")
	for index: int in cells.size():
		cells[index] = _trim(cells[index])
	return cells

static func _is_pipe_row(line: String) -> bool:
	return _trim(line).begins_with("|")

static func _is_separator_row(line: String, columns: int) -> bool:
	if not _is_pipe_row(line):
		return false
	var cells: PackedStringArray = _split_row(line)
	if cells.size() != columns:
		return false
	for cell: String in cells:
		if _separator_cell_re.search(cell) == null:
			return false
	return true

static func _table_columns(guarded_lines: PackedStringArray, start: int) -> int:
	if start + 1 >= guarded_lines.size() or not _is_pipe_row(guarded_lines[start]):
		return 0
	var columns: int = _split_row(guarded_lines[start]).size()
	if columns < TABLE_COLUMNS_MIN or columns > TABLE_COLUMNS_MAX:
		return 0
	return columns if _is_separator_row(guarded_lines[start + 1], columns) else 0

static func _append_table(lines: Array[String], guarded_lines: PackedStringArray, start: int, profile: Profile) -> int:
	var columns: int = _table_columns(guarded_lines, start)
	var end: int = start + 2
	while end < guarded_lines.size() and _is_pipe_row(guarded_lines[end]):
		end += 1
	var padding: String = TABLE_PAD_PREVIEW if profile == Profile.PREVIEW else TABLE_PAD_CARD
	var head_ink: String = _hex(&"text.strong")
	var body_ink: String = _hex(CODE_TEXT_KEY)
	var head_open: String = "[cell bg=%s padding=%s]" % [_hex(TABLE_HEAD_KEY), padding]
	var cell_open: String = "[cell bg=%s padding=%s]" % [_hex(CODE_BG_KEY), padding]
	var markup: String = "[table=%d]" % columns
	for row: int in range(start, end):
		if row == start + 1:
			continue
		var cells: PackedStringArray = _split_row(guarded_lines[row])
		for column: int in columns:
			var content: String = _inline(cells[column]) if column < cells.size() else ""
			markup += (head_open + "[color=%s][b]%s[/b][/color]" % [head_ink, content] if row == start else cell_open + "[color=%s]%s[/color]" % [body_ink, content]) + "[/cell]"
	lines.append(markup + "[/table]")
	return end

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

static func _append_list_item(lines: Array[String], indents: Array[int], kinds: Array[String], indent: int, kind: String, body: String) -> void:
	var closing: String = ""
	while not indents.is_empty() and indent < indents[indents.size() - 1]:
		indents.pop_back()
		closing += "[/%s]" % kinds.pop_back()
	if not indents.is_empty() and indent == indents[indents.size() - 1] and kind != kinds[kinds.size() - 1]:
		indents.pop_back()
		closing += "[/%s]" % kinds.pop_back()
	if closing != "" and not lines.is_empty():
		lines[lines.size() - 1] += closing

	var prefix: String = ""
	if indents.is_empty() or indent > indents[indents.size() - 1]:
		indents.append(indent)
		kinds.append(kind)
		prefix = "[ul]" if kind == LIST_BULLET else "[ol type=1]"
	lines.append(prefix + body)

static func _close_lists(lines: Array[String], indents: Array[int], kinds: Array[String]) -> void:
	if indents.is_empty():
		return
	if not lines.is_empty():
		var closing: String = ""
		for kind: String in kinds:
			closing = "[/%s]" % kind + closing
		lines[lines.size() - 1] += closing
	indents.clear()
	kinds.clear()
