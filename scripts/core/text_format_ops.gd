class_name TextFormatOps
extends RefCounted

static var _heading_prefix_re: RegEx = null
static var _bullet_re: RegEx = null

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
	var first_line: int = edit.get_caret_line()
	var last_line: int = first_line
	var had_selection: bool = edit.has_selection()
	if had_selection:
		first_line = edit.get_selection_from_line()
		last_line = edit.get_selection_to_line()
		if last_line > first_line and edit.get_selection_to_column() == 0:
			last_line -= 1

	var targets: Array[int] = []
	for line_index: int in range(first_line, last_line + 1):
		if first_line == last_line or not edit.get_line(line_index).strip_edges().is_empty():
			targets.append(line_index)
	if targets.is_empty():
		return

	_ensure_regex()
	var remove: bool = true
	for line_index: int in targets:
		if not _has_prefix(edit.get_line(line_index), prefix, heading):
			remove = false
			break

	var caret_line: int = edit.get_caret_line()
	var caret_column: int = edit.get_caret_column()
	var caret_delta: int = 0

	edit.begin_complex_operation()
	for line_index: int in targets:
		var old_text: String = edit.get_line(line_index)
		var new_text: String = _strip_prefix(old_text, heading) if remove else _apply_prefix(old_text, prefix, heading)
		if new_text == old_text:
			continue
		edit.set_line(line_index, new_text)
		if line_index == caret_line:
			caret_delta = new_text.length() - old_text.length()
	edit.end_complex_operation()

	if had_selection:
		edit.select(first_line, 0, last_line, edit.get_line(last_line).length())
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

static func _has_prefix(line: String, prefix: String, heading: bool) -> bool:
	if heading:
		return line.begins_with(prefix)
	return _bullet_re.search(line) != null

static func _strip_prefix(line: String, heading: bool) -> String:
	if heading:
		var heading_match: RegExMatch = _heading_prefix_re.search(line)
		return line.substr(heading_match.get_end()) if heading_match != null else line
	var bullet_match: RegExMatch = _bullet_re.search(line)
	if bullet_match == null:
		return line
	return bullet_match.get_string(1) + line.substr(bullet_match.get_end())

static func _apply_prefix(line: String, prefix: String, heading: bool) -> String:
	if heading:
		return prefix + _strip_prefix(line, true)
	if _bullet_re.search(line) != null:
		return line
	var body: String = line.lstrip(" \t")
	var indent: String = line.substr(0, line.length() - body.length())
	return indent + prefix + body
