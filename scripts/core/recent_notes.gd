class_name RecentNotes
extends RefCounted

const DEFAULT_LIMIT: int = 20
const WEEK_SECONDS: int = 7 * 86400

static func top(entries: Array[Dictionary], limit: int = DEFAULT_LIMIT) -> Array[Dictionary]:
	var kept: Array[Dictionary] = []
	for entry: Dictionary in entries:
		if int(entry.get("modified", 0)) > 0:
			kept.append(entry)
	kept.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var time_a: int = int(a["modified"])
		var time_b: int = int(b["modified"])
		if time_a != time_b:
			return time_a > time_b
		return str(a.get("id", "")) < str(b.get("id", "")))
	if limit >= 0 and kept.size() > limit:
		kept.resize(limit)
	return kept

static func relative_time(modified: int, now: int) -> String:
	var age: int = now - modified
	if age < 0:
		return _date_text(modified)
	if age < 60:
		return str(TranslationServer.translate("recent.just_now"))
	if age < 3600:
		return str(TranslationServer.translate("recent.minutes")) % (age / 60)
	if age < 86400:
		return str(TranslationServer.translate("recent.hours")) % (age / 3600)
	if age < WEEK_SECONDS:
		return str(TranslationServer.translate("recent.days")) % (age / 86400)
	return _date_text(modified)

static func _date_text(unix_time: int) -> String:
	var d: Dictionary = Time.get_datetime_dict_from_unix_time(unix_time)
	return "%02d.%02d.%04d" % [d["day"], d["month"], d["year"]]
