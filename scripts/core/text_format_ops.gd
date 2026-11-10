class_name TextFormatOps
extends RefCounted

const CHECKLIST_PREFIX: String = "- [ ] "
const FENCE: String = "```"
const ALIGN_TAGS: Array[String] = ["left", "center", "right"]

static var _heading_prefix_re: RegEx = null
static var _bullet_re: RegEx = null
static var _check_re: RegEx = null
static var _line_lead_re: RegEx = null
static var _align_re: RegEx = null
static var _block_open_re: RegEx = null
static var _block_close_re: RegEx = null
static var _check_mark_re: RegEx = null

static func wrap_selection(edit: TextEdit, open: String, close: String, allow_toggle: bool = true) -> void:
	if not edit.has_selection():
		var line: int = edit.get_caret_line()
		var column: int = edit.get_caret_column()
		edit.begin_complex_operation()
		edit.insert_text_at_caret(open + close)
		edit.end_complex_operation()
		edit.set_caret_line(line)
		edit.set_caret_column(column + open.length())
		return

	var from_line: int = edit.get_selection_from_line()
	var from_col: int = edit.get_selection_from_column()
	var to_line: int = edit.get_selection_to_line()
	var to_col: int = edit.get_selection_to_column()
	var new_from_col: int = from_col
	var new_to_col: int = to_col

	edit.begin_complex_operation()
	var line_index: int = to_line
	while line_index >= from_line:
		var line_text: String = edit.get_line(line_index)
		var segment_from: int = from_col if line_index == from_line else 0
		var segment_to: int = to_col if line_index == to_line else line_text.length()
		if segment_to > segment_from and not line_text.substr(segment_from, segment_to - segment_from).strip_edges().is_empty():
			var bounds: Vector2i = _wrap_segment(edit, line_index, segment_from, segment_to, open, close, allow_toggle)
			if line_index == from_line:
				new_from_col = bounds.x
			if line_index == to_line:
				new_to_col = bounds.y
		line_index -= 1
	edit.end_complex_operation()

	edit.select(from_line, new_from_col, to_line, new_to_col)

static func apply_value_tag(edit: TextEdit, tag: String, value: String) -> void:
	var open: String = "[%s=%s]" % [tag, value]
	var close: String = "[/%s]" % tag

	if edit.has_selection() and edit.get_selection_from_line() == edit.get_selection_to_line():
		var line: int = edit.get_selection_from_line()
		var from_col: int = edit.get_selection_from_column()
		var to_col: int = edit.get_selection_to_column()
		var text: String = edit.get_line(line)
		var before: String = text.substr(0, from_col)
		var after: String = text.substr(to_col)

		var existing_re: RegEx = RegEx.create_from_string("\\[" + tag + "=[^\\[\\]]*\\]$")
		var existing: RegExMatch = existing_re.search(before)
		if existing != null and after.begins_with(close) and existing.get_string() != open:
			var old_open: String = existing.get_string()
			var open_col: int = existing.get_start()
			edit.begin_complex_operation()
			edit.remove_text(line, open_col, line, from_col)
			edit.insert_text(open, line, open_col)
			edit.end_complex_operation()
			edit.select(line, open_col + open.length(), line, to_col - old_open.length() + open.length())
			return

	wrap_selection(edit, open, close)

static func toggle_line_prefix(edit: TextEdit, prefix: String, heading: bool) -> void:
	var lines: Vector2i = _line_range(edit)
	var targets: Array[int] = _target_lines(edit, lines)
	if targets.is_empty():
		return

	_ensure_regex()
	var remove: bool = true
	for line_index: int in targets:
		if not _has_prefix(edit.get_line(line_index), prefix, heading):
			remove = false
			break

	_rewrite_lines(edit, lines, targets, func(old_text: String) -> String:
		return _strip_prefix(old_text, heading) if remove else _apply_prefix(old_text, prefix, heading)
	)

static func toggle_line_align(edit: TextEdit, tag: String) -> void:
	if not ALIGN_TAGS.has(tag):
		return
	_ensure_regex()
	var lines: Vector2i = _line_range(edit)
	var table: Vector2i = _table_range(edit, lines)
	if table.x >= 0:
		_toggle_block_align(edit, table, tag)
		return
	var targets: Array[int] = _target_lines(edit, lines)
	if targets.is_empty():
		return

	var remove: bool = true
	for line_index: int in targets:
		if _line_align(edit.get_line(line_index)) != tag:
			remove = false
			break

	_rewrite_lines(edit, lines, targets, func(old_text: String) -> String:
		return _align_line(old_text, tag, remove)
	)
	if lines.x == lines.y and not edit.has_selection() and edit.get_line(lines.x) == "[%s][/%s]" % [tag, tag]:
		edit.set_caret_column(tag.length() + 2)

static func fence_completion(text: String, caret_line: int) -> Dictionary:
	var lines: PackedStringArray = text.split("\n")
	if caret_line < 0 or caret_line >= lines.size() or lines[caret_line].strip_edges() != FENCE:
		return {}
	var fences_above: int = 0
	var offset: int = 0
	for index: int in caret_line:
		if lines[index].strip_edges().begins_with(FENCE):
			fences_above += 1
		offset += lines[index].length() + 1
	if fences_above % 2 == 1:
		return {}
	var closed: bool = caret_line + 1 < lines.size() and lines[caret_line + 1].strip_edges() == FENCE
	var insert: String = "\n" if closed else "\n\n" + FENCE
	offset += lines[caret_line].length()
	return {"text": text.insert(offset, insert), "insert": insert, "line": caret_line + 1, "column": 0}

static func complete_fence(edit: TextEdit) -> bool:
	if edit.has_selection():
		return false
	var line: int = edit.get_caret_line()
	var result: Dictionary = fence_completion(edit.text, line)
	if result.is_empty():
		return false
	edit.begin_complex_operation()
	edit.insert_text(str(result["insert"]), line, edit.get_line(line).length())
	edit.end_complex_operation()
	edit.set_caret_line(int(result["line"]))
	edit.set_caret_column(int(result["column"]))
	return true

static func insert_code_block(edit: TextEdit) -> void:
	var lines: Vector2i = _line_range(edit)
	var had_selection: bool = edit.has_selection()
	var caret_column: int = edit.get_caret_column()
	edit.begin_complex_operation()
	edit.insert_text("\n" + FENCE, lines.y, edit.get_line(lines.y).length())
	edit.insert_line_at(lines.x, FENCE)
	edit.end_complex_operation()
	if had_selection:
		edit.select(lines.x + 1, 0, lines.y + 1, edit.get_line(lines.y + 1).length())
	else:
		edit.set_caret_line(lines.x + 1)
		edit.set_caret_column(mini(caret_column, edit.get_line(lines.x + 1).length()))

static func toggle_checkbox(edit: TextEdit, line: int) -> bool:
	if line < 0 or line >= edit.get_line_count():
		return false
	_ensure_regex()
	var item: RegExMatch = _check_mark_re.search(edit.get_line(line))
	if item == null:
		return false
	var column: int = item.get_start(1)
	edit.begin_complex_operation()
	edit.remove_text(line, column, line, column + 1)
	edit.insert_text("x" if item.get_string(1) == " " else " ", line, column)
	edit.end_complex_operation()
	return true

static func _is_pipe_line(edit: TextEdit, line: int) -> bool:
	return line >= 0 and line < edit.get_line_count() and edit.get_line(line).strip_edges().begins_with("|")

static func _table_range(edit: TextEdit, lines: Vector2i) -> Vector2i:
	for line_index: int in range(lines.x, lines.y + 1):
		if not _is_pipe_line(edit, line_index):
			return Vector2i(-1, -1)
	var first: int = lines.x
	var last: int = lines.y
	while _is_pipe_line(edit, first - 1):
		first -= 1
	while _is_pipe_line(edit, last + 1):
		last += 1
	return Vector2i(first, last)

static func _block_tag(edit: TextEdit, line: int, closing: bool) -> String:
	if line < 0 or line >= edit.get_line_count():
		return ""
	var found: RegExMatch = (_block_close_re if closing else _block_open_re).search(edit.get_line(line))
	return found.get_string(1) if found != null else ""

static func _toggle_block_align(edit: TextEdit, table: Vector2i, tag: String) -> void:
	var above: int = table.x - 1
	var below: int = table.y + 1
	var current: String = _block_tag(edit, above, false)
	var wrapped: bool = current != "" and current == _block_tag(edit, below, true)
	edit.begin_complex_operation()
	if wrapped and current == tag:
		edit.remove_line_at(below, false)
		edit.remove_line_at(above, false)
	elif wrapped:
		edit.set_line(above, "[%s]" % tag)
		edit.set_line(below, "[/%s]" % tag)
	else:
		edit.insert_line_at(table.y + 1, "[/%s]" % tag)
		edit.insert_line_at(table.x, "[%s]" % tag)
	edit.end_complex_operation()

static func _line_range(edit: TextEdit) -> Vector2i:
	var first_line: int = edit.get_caret_line()
	var last_line: int = first_line
	if edit.has_selection():
		first_line = edit.get_selection_from_line()
		last_line = edit.get_selection_to_line()
		if last_line > first_line and edit.get_selection_to_column() == 0:
			last_line -= 1
	return Vector2i(first_line, last_line)

static func _target_lines(edit: TextEdit, lines: Vector2i) -> Array[int]:
	var targets: Array[int] = []
	for line_index: int in range(lines.x, lines.y + 1):
		if lines.x == lines.y or not edit.get_line(line_index).strip_edges().is_empty():
			targets.append(line_index)
	return targets

static func _rewrite_lines(edit: TextEdit, lines: Vector2i, targets: Array[int], rewrite: Callable) -> void:
	var had_selection: bool = edit.has_selection()
	var caret_line: int = edit.get_caret_line()
	var caret_column: int = edit.get_caret_column()
	var caret_delta: int = 0

	edit.begin_complex_operation()
	for line_index: int in targets:
		var old_text: String = edit.get_line(line_index)
		var new_text: String = str(rewrite.call(old_text))
		if new_text == old_text:
			continue
		edit.set_line(line_index, new_text)
		if line_index == caret_line:
			caret_delta = new_text.length() - old_text.length()
	edit.end_complex_operation()

	if had_selection:
		edit.select(lines.x, 0, lines.y, edit.get_line(lines.y).length())
	else:
		edit.set_caret_line(caret_line)
		edit.set_caret_column(clampi(caret_column + caret_delta, 0, edit.get_line(caret_line).length()))


static func _wrap_segment(edit: TextEdit, line: int, from_col: int, to_col: int, open: String, close: String, allow_toggle: bool) -> Vector2i:
	var text: String = edit.get_line(line)
	var before: String = text.substr(0, from_col)
	var after: String = text.substr(to_col)
	var inner: String = text.substr(from_col, to_col - from_col)

	if allow_toggle and _is_wrapped_outside(before, after, open, close):
		edit.remove_text(line, to_col, line, to_col + close.length())
		edit.remove_text(line, from_col - open.length(), line, from_col)
		return Vector2i(from_col - open.length(), to_col - open.length())

	if allow_toggle and _is_wrapped_inside(inner, open, close):
		edit.remove_text(line, to_col - close.length(), line, to_col)
		edit.remove_text(line, from_col, line, from_col + open.length())
		return Vector2i(from_col, to_col - open.length() - close.length())

	edit.insert_text(close, line, to_col)
	edit.insert_text(open, line, from_col)
	return Vector2i(from_col + open.length(), to_col + open.length())

static func _is_wrapped_outside(before: String, after: String, open: String, close: String) -> bool:
	if not before.ends_with(open) or not after.begins_with(close):
		return false
	var marker: String = _uniform_char(open)
	if marker != "" and open == close:
		var depth: int = mini(_trailing_run(before, marker), _leading_run(after, marker))
		return _marker_active(depth, open.length())
	return true

static func _is_wrapped_inside(inner: String, open: String, close: String) -> bool:
	if inner.length() < open.length() + close.length():
		return false
	if not inner.begins_with(open) or not inner.ends_with(close):
		return false
	var marker: String = _uniform_char(open)
	if marker != "" and open == close:
		var depth: int = mini(mini(_leading_run(inner, marker), _trailing_run(inner, marker)), int(inner.length() / 2.0))
		return _marker_active(depth, open.length())
	return true

static func _marker_active(depth: int, marker_length: int) -> bool:
	if marker_length == 1:
		return depth % 2 == 1
	return depth >= marker_length

static func _uniform_char(token: String) -> String:
	if token.is_empty():
		return ""
	var first: String = token[0]
	return first if token == first.repeat(token.length()) else ""

static func _trailing_run(text: String, marker: String) -> int:
	var count: int = 0
	var index: int = text.length() - 1
	while index >= 0 and text[index] == marker:
		count += 1
		index -= 1
	return count

static func _leading_run(text: String, marker: String) -> int:
	var count: int = 0
	while count < text.length() and text[count] == marker:
		count += 1
	return count


static func _ensure_regex() -> void:
	if _heading_prefix_re != null:
		return
	_heading_prefix_re = RegEx.create_from_string("^#{1,6}[ \\t]+")
	_bullet_re = RegEx.create_from_string("^([ \\t]*)[-*+][ \\t]+")
	_block_open_re = RegEx.create_from_string("^[ \\t]*\\[(left|center|right)\\][ \\t]*$")
	_block_close_re = RegEx.create_from_string("^[ \\t]*\\[/(left|center|right)\\][ \\t]*$")
	_check_re = RegEx.create_from_string("^([ \\t]*)[-*+][ \\t]+\\[[ xX]\\](?:[ \\t]+|$)")
	_check_mark_re = RegEx.create_from_string("^[ \\t]*[-*+][ \\t]+\\[([ xX])\\](?=[ \\t]|$)")
	_line_lead_re = RegEx.create_from_string("^([ \\t]*(?:#{1,6}[ \\t]+|[-*+][ \\t]+(?:\\[[ xX]\\][ \\t]+)?|[0-9]+\\.[ \\t]+|>[ \\t]+)?)(.*)$")
	_align_re = RegEx.create_from_string("^\\[(left|center|right)\\](.*)\\[/\\1\\]$")

static func _has_prefix(line: String, prefix: String, heading: bool) -> bool:
	if heading:
		return line.begins_with(prefix)
	if prefix == CHECKLIST_PREFIX:
		return _check_re.search(line) != null
	return _bullet_re.search(line) != null

static func _strip_prefix(line: String, heading: bool) -> String:
	if heading:
		var heading_match: RegExMatch = _heading_prefix_re.search(line)
		return line.substr(heading_match.get_end()) if heading_match != null else line
	var marker: RegExMatch = _check_re.search(line)
	if marker == null:
		marker = _bullet_re.search(line)
	if marker == null:
		return line
	return marker.get_string(1) + line.substr(marker.get_end())

static func _apply_prefix(line: String, prefix: String, heading: bool) -> String:
	if heading:
		return prefix + _strip_prefix(line, true)
	if prefix == CHECKLIST_PREFIX:
		if _check_re.search(line) != null:
			return line
		return _with_prefix(_strip_prefix(line, false), prefix)
	if _bullet_re.search(line) != null:
		return line
	return _with_prefix(line, prefix)

static func _with_prefix(line: String, prefix: String) -> String:
	var body: String = line.lstrip(" \t")
	var indent: String = line.substr(0, line.length() - body.length())
	return indent + prefix + body

static func _line_align(line: String) -> String:
	var current: RegExMatch = _align_re.search(_line_lead_re.search(line).get_string(2))
	return current.get_string(1) if current != null else ""

static func _align_line(line: String, tag: String, remove: bool) -> String:
	var parts: RegExMatch = _line_lead_re.search(line)
	var rest: String = parts.get_string(2)
	var current: RegExMatch = _align_re.search(rest)
	if current != null:
		rest = current.get_string(2)
	if remove:
		return parts.get_string(1) + rest
	return "%s[%s]%s[/%s]" % [parts.get_string(1), tag, rest, tag]
