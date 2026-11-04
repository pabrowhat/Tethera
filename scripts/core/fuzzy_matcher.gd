class_name FuzzyMatcher
extends RefCounted

const WORD_SEPARATORS: String = " -_/.,:;"

static func score(query: String, text: String) -> int:
	var q: String = query.strip_edges().to_lower()
	if q == "":
		return 0

	var t: String = text.to_lower()
	var query_index: int = 0
	var streak: int = 0
	var total: int = 0

	for i: int in t.length():
		if query_index >= q.length():
			break
		if t[i] == q[query_index]:
			streak += 1
			total += 1 + streak * 2
			if i == 0 or WORD_SEPARATORS.contains(t[i - 1]):
				total += 8
			query_index += 1
		else:
			streak = 0

	if query_index < q.length():
		return -1
	return maxi(total - t.length(), 0)

static func rank(query: String, items: Array[Dictionary], limit: int = 8) -> Array[Dictionary]:
	var scored: Array[Dictionary] = []
	for item: Dictionary in items:
		var title: String = str(item.get("title", ""))
		var s: int = score(query, title)
		if s >= 0:
			scored.append({"id": str(item.get("id", "")), "title": title, "score": s})

	scored.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if a["score"] != b["score"]:
			return a["score"] > b["score"]
		return str(a["title"]).naturalnocasecmp_to(str(b["title"])) < 0
	)

	if scored.size() > limit:
		scored.resize(limit)
	return scored
