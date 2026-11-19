extends RefCounted

const HeroData = preload("res://scripts/hero_data.gd")
const DEFAULT_PATH := "user://save_data.json"

static func _default_costumes() -> Dictionary:
	var c := {}
	for hid in HeroData.HERO_ORDER:
		c[hid] = "default"
	return c

static func _default_passives() -> Dictionary:
	var p := {}
	for hid in HeroData.HERO_ORDER:
		p[hid] = 0
	return p

static func _sanitize_party(raw_party: Variant) -> Array:
	var out: Array = []
	if typeof(raw_party) == TYPE_ARRAY:
		for item in raw_party:
			var hid := str(item)
			if HeroData.HEROES.has(hid) and not out.has(hid):
				out.append(hid)
			if out.size() >= 3:
				break
	for fallback in HeroData.DEFAULT_PARTY:
		if out.size() >= 3:
			break
		if not out.has(fallback):
			out.append(fallback)
	return out

static func load_data(path: String = DEFAULT_PATH) -> Dictionary:
	var data := {
		"spirit_jade": 0,
		"difficulty": "normal",
		"core_upgrades": {
			"hp_lv": 0,
			"sp_lv": 0,
			"atk_lv": 0,
			"orb_lv": 0,
		},
		"hero_passives": _default_passives(),
		"party": HeroData.DEFAULT_PARTY.duplicate(),
		"costumes": _default_costumes(),
		"cleared_chapters": [],
	}
	if not FileAccess.file_exists(path):
		return data
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return data
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	f.close()
	if typeof(parsed) != TYPE_DICTIONARY:
		return data
	var d: Dictionary = parsed
	data["spirit_jade"] = int(d.get("spirit_jade", 0))
	data["difficulty"] = str(d.get("difficulty", "normal"))
	if d.has("core_upgrades") and typeof(d["core_upgrades"]) == TYPE_DICTIONARY:
		for k in data["core_upgrades"].keys():
			data["core_upgrades"][k] = int(d["core_upgrades"].get(k, 0))
	if d.has("hero_passives") and typeof(d["hero_passives"]) == TYPE_DICTIONARY:
		for k in data["hero_passives"].keys():
			data["hero_passives"][k] = int(d["hero_passives"].get(k, 0))
	if d.has("party"):
		data["party"] = _sanitize_party(d["party"])
	if d.has("costumes") and typeof(d["costumes"]) == TYPE_DICTIONARY:
		for k in data["costumes"].keys():
			var v := str(d["costumes"].get(k, "default"))
			data["costumes"][k] = "alt" if v == "alt" else "default"
	if d.has("cleared_chapters") and typeof(d["cleared_chapters"]) == TYPE_ARRAY:
		var cc: Array = []
		for item in d["cleared_chapters"]:
			var ch := int(item)
			if ch >= 1 and ch <= 10 and not cc.has(ch):
				cc.append(ch)
		data["cleared_chapters"] = cc
	return data


static func save_data(data: Dictionary, path: String = DEFAULT_PATH) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return
	f.store_string(JSON.stringify(data, "\t"))
	f.close()


static func get_core_cost(key: String, current_lv: int) -> int:
	var base := 15 if key != "orb_lv" else 20
	return base + current_lv * 15


static func get_core_max_lv(key: String) -> int:
	return 3 if key == "orb_lv" else 5


static func get_passive_cost() -> int:
	return 40
