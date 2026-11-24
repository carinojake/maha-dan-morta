extends RefCounted

const HeroData = preload("res://scripts/hero_data.gd")
const EquipData = preload("res://scripts/equip_data.gd")
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

static func _default_data() -> Dictionary:
	return {
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
		"cutin_enabled": true,
		"cutin_mode": "full",
		"bgm_enabled": true,
		"owned_gear": EquipData.STARTER_GEAR.duplicate(),
		"hero_gear": {},
		"gear_levels": {},
		"chapter_records": {},
		"achievements": {},
		"tutorial_completed": false,
		"touch_mirror": false,
		"hud_menu_expanded": false,
		"game_speed": 1.0,
		"auto_attack": false,
		"fx_reduced": false,
		"shake_mode": "normal",
	}


static func load_data(path: String = DEFAULT_PATH) -> Dictionary:
	if not FileAccess.file_exists(path):
		return _default_data()
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return _default_data()
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	f.close()
	if typeof(parsed) != TYPE_DICTIONARY:
		return _default_data()
	return sanitize_data(parsed as Dictionary)


static func sanitize_data(d: Dictionary) -> Dictionary:
	var data := _default_data()
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
	data["cutin_enabled"] = bool(d.get("cutin_enabled", true))
	var cmode := str(d.get("cutin_mode", ""))
	# Saves from before the 3-mode setting only carried an on/off flag.
	if not (cmode in ["full", "boss", "skip"]):
		cmode = "full" if data["cutin_enabled"] else "skip"
	data["cutin_mode"] = cmode
	data["bgm_enabled"] = bool(d.get("bgm_enabled", true))
	if d.has("owned_gear") and typeof(d["owned_gear"]) == TYPE_ARRAY:
		var og: Array = []
		for item_id in d["owned_gear"]:
			var k := str(item_id)
			if EquipData.ITEMS.has(k) and not og.has(k):
				og.append(k)
		for starter in EquipData.STARTER_GEAR:
			if not og.has(starter):
				og.append(starter)
		data["owned_gear"] = og
	if d.has("hero_gear") and typeof(d["hero_gear"]) == TYPE_DICTIONARY:
		var hg: Dictionary = {}
		for hid in HeroData.HERO_ORDER:
			var raw_slots: Variant = d["hero_gear"].get(hid, {})
			if typeof(raw_slots) == TYPE_DICTIONARY:
				var clean_slots: Dictionary = {}
				for slot_k in EquipData.ALL_SLOTS:
					var item_id := str((raw_slots as Dictionary).get(slot_k, ""))
					if EquipData.ITEMS.has(item_id) and data["owned_gear"].has(item_id):
						clean_slots[slot_k] = item_id
				if not clean_slots.is_empty():
					hg[hid] = clean_slots
		data["hero_gear"] = hg
	if d.has("gear_levels") and typeof(d["gear_levels"]) == TYPE_DICTIONARY:
		var gl: Dictionary = {}
		for item_id in (d["gear_levels"] as Dictionary).keys():
			var k := str(item_id)
			if EquipData.ITEMS.has(k):
				gl[k] = clampi(int(d["gear_levels"][item_id]), 0, EquipData.MAX_ENHANCE_LV)
		data["gear_levels"] = gl
	if d.has("chapter_records") and typeof(d["chapter_records"]) == TYPE_DICTIONARY:
		var cr: Dictionary = {}
		for ch_k in (d["chapter_records"] as Dictionary).keys():
			var raw_rec: Variant = d["chapter_records"][ch_k]
			if typeof(raw_rec) == TYPE_DICTIONARY:
				cr[str(ch_k)] = {
					"best_time": float((raw_rec as Dictionary).get("best_time", 0.0)),
					"best_combo": int((raw_rec as Dictionary).get("best_combo", 0)),
					"best_damage": int((raw_rec as Dictionary).get("best_damage", 0)),
				}
		data["chapter_records"] = cr
	if d.has("achievements") and typeof(d["achievements"]) == TYPE_DICTIONARY:
		var ach: Dictionary = {}
		for aid in (d["achievements"] as Dictionary).keys():
			var raw_a: Variant = d["achievements"][aid]
			if typeof(raw_a) == TYPE_DICTIONARY:
				ach[str(aid)] = {
					"unlocked": bool((raw_a as Dictionary).get("unlocked", false)),
					"progress": maxi(0, int((raw_a as Dictionary).get("progress", 0))),
				}
		data["achievements"] = ach
	data["tutorial_completed"] = bool(d.get("tutorial_completed", false))
	data["touch_mirror"] = bool(d.get("touch_mirror", false))
	data["hud_menu_expanded"] = bool(d.get("hud_menu_expanded", false))
	data["game_speed"] = 1.5 if float(d.get("game_speed", 1.0)) >= 1.25 else 1.0
	data["auto_attack"] = bool(d.get("auto_attack", false))
	data["fx_reduced"] = bool(d.get("fx_reduced", false))
	var smode := str(d.get("shake_mode", "normal"))
	data["shake_mode"] = smode if smode in ["normal", "low", "off"] else "normal"
	data["cutin_enabled"] = cmode != "skip"
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


static func export_save_code(data: Dictionary) -> String:
	var clean := sanitize_data(data)
	var json_str := JSON.stringify(clean)
	var b64 := Marshalls.raw_to_base64(json_str.to_utf8_buffer())
	return "MDM1:" + b64


static func import_save_code(raw_code: String) -> Dictionary:
	var code := raw_code.strip_edges()
	if not code.begins_with("MDM1:"):
		return {"ok": false, "error": "รหัสไม่ถูกต้อง (ต้องขึ้นต้นด้วย MDM1:)"}
	var b64 := code.substr(5).strip_edges()
	if b64.is_empty():
		return {"ok": false, "error": "รหัสว่างเปล่า"}
	var raw := Marshalls.base64_to_raw(b64)
	if raw.is_empty():
		return {"ok": false, "error": "ถอดรหัส Base64 ไม่สำเร็จ"}
	var json_str := raw.get_string_from_utf8()
	var parsed: Variant = JSON.parse_string(json_str)
	if typeof(parsed) != TYPE_DICTIONARY:
		return {"ok": false, "error": "ข้อมูลเซฟเสียหายหรือไม่ใช่ JSON"}
	return {"ok": true, "data": sanitize_data(parsed as Dictionary)}


const ACHIEVEMENTS := [
	{
		"id": "dodge_5",
		"title": "พริบตาเหนือสายลม",
		"desc": "หลบพริบตา (Perfect Dodge) สะสม 5 ครั้ง",
		"target": 5,
		"reward": 30,
	},
	{
		"id": "dodge_25",
		"title": "เงาไร้ร่องรอย",
		"desc": "หลบพริบตา (Perfect Dodge) สะสม 25 ครั้ง",
		"target": 25,
		"reward": 60,
	},
	{
		"id": "combo_sss",
		"title": "กระบี่ไร้ช่องโหว่",
		"desc": "ทำคอมโบถึงระดับ SSS ในการต่อสู้",
		"target": 1,
		"reward": 45,
	},
	{
		"id": "reaction_10",
		"title": "ปราณผสานห้าธาตุ",
		"desc": "ระเบิดปฏิกิริยาธาตุสะสม 10 ครั้ง",
		"target": 10,
		"reward": 35,
	},
	{
		"id": "reaction_50",
		"title": "เจ้าแห่งปฏิกิริยา",
		"desc": "ระเบิดปฏิกิริยาธาตุสะสม 50 ครั้ง",
		"target": 50,
		"reward": 75,
	},
	{
		"id": "clear_ch1",
		"title": "ก้าวแรกสู่หอคอย",
		"desc": "พิชิตบทที่ 1 สำเร็จ",
		"target": 1,
		"reward": 30,
	},
	{
		"id": "clear_ch5",
		"title": "ผู้ทะลวงห้าชั้นฟ้า",
		"desc": "พิชิตบทที่ 5 สำเร็จ",
		"target": 1,
		"reward": 60,
	},
	{
		"id": "clear_ch10",
		"title": "ผู้ผนึกกระบี่สะบั้นสวรรค์",
		"desc": "พิชิตครบทั้ง 10 บท (100 ชั้น)",
		"target": 1,
		"reward": 120,
	},
	{
		"id": "enhance_plus5",
		"title": "ช่างหลอมระดับเซียน",
		"desc": "ตีบวกศาสตราวุธถึงระดับ +5 สำเร็จ",
		"target": 1,
		"reward": 50,
	},
	{
		"id": "gear_collect_8",
		"title": "คลังศาสตรามหาแดน",
		"desc": "สะสมศาสตราวุธครบ 8 ชิ้น",
		"target": 8,
		"reward": 55,
	},
]


static func get_achievement_state(data: Dictionary, ach_id: String) -> Dictionary:
	var all_ach: Dictionary = data.get("achievements", {})
	var st: Variant = all_ach.get(ach_id, {})
	if typeof(st) != TYPE_DICTIONARY:
		return {"unlocked": false, "progress": 0}
	return {
		"unlocked": bool((st as Dictionary).get("unlocked", false)),
		"progress": int((st as Dictionary).get("progress", 0)),
	}


static func record_achievement_progress(data: Dictionary, ach_id: String, amount: int = 1, set_absolute: bool = false) -> Dictionary:
	var def: Dictionary = {}
	for a in ACHIEVEMENTS:
		if a["id"] == ach_id:
			def = a
			break
	if def.is_empty():
		return {"unlocked_now": false}
	if not data.has("achievements") or typeof(data["achievements"]) != TYPE_DICTIONARY:
		data["achievements"] = {}
	var st := get_achievement_state(data, ach_id)
	if bool(st["unlocked"]):
		return {"unlocked_now": false}
	var target := int(def["target"])
	var next_prog := amount if set_absolute else (int(st["progress"]) + amount)
	next_prog = mini(target, maxi(0, next_prog))
	var unlocked_now := next_prog >= target
	data["achievements"][ach_id] = {
		"unlocked": unlocked_now,
		"progress": next_prog,
	}
	if unlocked_now:
		var reward := int(def["reward"])
		data["spirit_jade"] = int(data.get("spirit_jade", 0)) + reward
		return {"unlocked_now": true, "title": str(def["title"]), "reward": reward, "id": ach_id}
	return {"unlocked_now": false}


static func update_chapter_record(data: Dictionary, chapter: int, elapsed: float, max_combo: int, total_dmg: int) -> Dictionary:
	if not data.has("chapter_records") or typeof(data["chapter_records"]) != TYPE_DICTIONARY:
		data["chapter_records"] = {}
	var key := str(chapter)
	var prev: Dictionary = data["chapter_records"].get(key, {})
	var prev_time := float(prev.get("best_time", 0.0))
	var prev_combo := int(prev.get("best_combo", 0))
	var prev_dmg := int(prev.get("best_damage", 0))
	var is_new_time := elapsed > 0.0 and (prev_time <= 0.0 or elapsed < prev_time)
	var is_new_combo := max_combo > prev_combo
	var is_new_dmg := total_dmg > prev_dmg
	data["chapter_records"][key] = {
		"best_time": elapsed if is_new_time else prev_time,
		"best_combo": max_combo if is_new_combo else prev_combo,
		"best_damage": total_dmg if is_new_dmg else prev_dmg,
	}
	return {
		"new_time": is_new_time,
		"new_combo": is_new_combo,
		"new_damage": is_new_dmg,
		"any_new": is_new_time or is_new_combo or is_new_dmg,
	}
