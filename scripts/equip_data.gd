extends RefCounted

const SLOT_WEAPON := "weapon"
const SLOT_ARMOR := "armor"
const SLOT_RELIC := "relic"
const ALL_SLOTS := [SLOT_WEAPON, SLOT_ARMOR, SLOT_RELIC]

const REALM_SET_BONUSES := {
	"มนุษย์": {
		"name": "เซ็ตแดนมนุษย์: สัจจะผู้ไร้ชะตา",
		"max_hp_pct": 0.15,
		"low_hp_dmg_red": 0.15,
		"desc": "Max HP +15% · ลดดาเมจที่ได้รับ 15% เมื่อ HP < 30%",
	},
	"เซียน": {
		"name": "เซ็ตแดนเซียน: ไอเหมันต์และยันต์อาคม",
		"atk_pct": 0.08,
		"max_sp_pct": 0.20,
		"cd_red": 0.12,
		"desc": "ATK +8% · ปราณสูงสุด +20% · ลดคูลดาวน์สกิล 12%",
	},
	"มาร": {
		"name": "เซ็ตแดนมาร: เพลิงทมิฬและหนามโลหิต",
		"atk_pct": 0.06,
		"crit": 0.12,
		"lifesteal_crit": 0.03,
		"desc": "ATK +6% · คริติคอล +12% · ดูดซับ HP 3% เมื่อติดคริติคอล",
	},
	"เทพ": {
		"name": "เซ็ตแดนเทพ: ทัณฑ์ระเบียบอัสนี",
		"atk_pct": 0.12,
		"lightning_proc": 0.20,
		"desc": "ATK +12% · โจมตีครบ 5 ครั้งเรียกสายฟ้าฟาด +20% ATK",
	},
}

const ITEM_ORDER := [
	"jade_sword",
	"thunder_spear",
	"blood_blade",
	"star_fan",
	"heaven_halberd",
	"patched_hemp_robe",
	"talisman_ward_vestment",
	"obsidian_copper_plate",
	"frost_silk_robe",
	"golden_dragon_armor",
	"spirit_orb",
	"bagua_charm",
	"frost_jade",
	"demon_heart",
	"immortal_pill",
]

const STARTER_GEAR := ["jade_sword", "patched_hemp_robe", "spirit_orb"]

const ITEMS := {
	"jade_sword": {
		"name": "กระบี่หยกเหมันต์",
		"slot": "weapon",
		"rarity": "ธรรมดา",
		"realm": "มนุษย์",
		"color": "#38bdf8",
		"atk": 8,
		"max_hp": 0,
		"max_sp": 0,
		"crit": 0.04,
		"dmg_red": 0.0,
		"cost": 0,
		"desc": "+8 ATK · +4% คริติคอล (อาวุธเริ่มต้น)",
	},
	"thunder_spear": {
		"name": "ทวนอัสนีสวรรค์",
		"slot": "weapon",
		"rarity": "วิญญาณ",
		"realm": "เทพ",
		"color": "#fbbf24",
		"atk": 16,
		"max_hp": 0,
		"max_sp": 15,
		"crit": 0.06,
		"dmg_red": 0.0,
		"cost": 45,
		"desc": "+16 ATK · +15 ปราณ · +6% คริติคอล",
	},
	"blood_blade": {
		"name": "ดาบโลหิตอสูร",
		"slot": "weapon",
		"rarity": "วิญญาณ",
		"realm": "มาร",
		"color": "#f87171",
		"atk": 22,
		"max_hp": 30,
		"max_sp": 0,
		"crit": 0.05,
		"dmg_red": 0.0,
		"cost": 60,
		"desc": "+22 ATK · +30 Max HP · +5% คริติคอล",
	},
	"star_fan": {
		"name": "พัดดาราแปดทิศ",
		"slot": "weapon",
		"rarity": "เซียน",
		"realm": "เซียน",
		"color": "#c084fc",
		"atk": 26,
		"max_hp": 25,
		"max_sp": 35,
		"crit": 0.12,
		"dmg_red": 0.0,
		"cost": 95,
		"desc": "+26 ATK · +25 Max HP · +35 ปราณ · +12% คริติคอล",
	},
	"heaven_halberd": {
		"name": "ง้าวสะบั้นเก้าชั้นฟ้า",
		"slot": "weapon",
		"rarity": "เซียน",
		"realm": "เทพ",
		"color": "#fde047",
		"atk": 28,
		"max_hp": 35,
		"max_sp": 20,
		"crit": 0.08,
		"dmg_red": 0.0,
		"cost": 130,
		"desc": "+28 ATK · +35 Max HP · +20 ปราณ · +8% คริ",
	},
	"patched_hemp_robe": {
		"name": "เสื้อผ้าป่านปะชุนกรำศึก",
		"slot": "armor",
		"rarity": "ธรรมดา",
		"realm": "มนุษย์",
		"color": "#a3e635",
		"atk": 0,
		"max_hp": 45,
		"max_sp": 0,
		"crit": 0.0,
		"dmg_red": 0.03,
		"cost": 0,
		"desc": "+45 Max HP · ลดดาเมจ 3% (เกราะเริ่มต้น)",
	},
	"talisman_ward_vestment": {
		"name": "อาภรณ์ยันต์คุ้มภัย",
		"slot": "armor",
		"rarity": "วิญญาณ",
		"realm": "เซียน",
		"color": "#60a5fa",
		"atk": 0,
		"max_hp": 80,
		"max_sp": 25,
		"crit": 0.0,
		"dmg_red": 0.05,
		"cost": 50,
		"desc": "+80 Max HP · +25 ปราณ · ลดดาเมจ 5%",
	},
	"obsidian_copper_plate": {
		"name": "เกราะทมิฬขลิบทองแดง",
		"slot": "armor",
		"rarity": "วิญญาณ",
		"realm": "มาร",
		"color": "#fb923c",
		"atk": 8,
		"max_hp": 110,
		"max_sp": 0,
		"crit": 0.0,
		"dmg_red": 0.06,
		"cost": 70,
		"desc": "+110 Max HP · +8 ATK · ลดดาเมจ 6%",
	},
	"frost_silk_robe": {
		"name": "อาภรณ์ไหมขาวขลิบหยก",
		"slot": "armor",
		"rarity": "เซียน",
		"realm": "เซียน",
		"color": "#93c5fd",
		"atk": 0,
		"max_hp": 130,
		"max_sp": 45,
		"crit": 0.02,
		"dmg_red": 0.09,
		"cost": 105,
		"desc": "+130 Max HP · +45 ปราณ · ลดดาเมจ 9%",
	},
	"golden_dragon_armor": {
		"name": "เกราะทองคำสลักลายมังกร",
		"slot": "armor",
		"rarity": "เซียน",
		"realm": "เทพ",
		"color": "#facc15",
		"atk": 10,
		"max_hp": 150,
		"max_sp": 30,
		"crit": 0.03,
		"dmg_red": 0.10,
		"cost": 145,
		"desc": "+150 Max HP · +10 ATK · +30 ปราณ · ลดดาเมจ 10%",
	},
	"spirit_orb": {
		"name": "ลูกแก้วปราณบริสุทธิ์",
		"slot": "relic",
		"rarity": "ธรรมดา",
		"realm": "มนุษย์",
		"color": "#34d399",
		"atk": 0,
		"max_hp": 35,
		"max_sp": 15,
		"crit": 0.0,
		"dmg_red": 0.0,
		"cost": 0,
		"desc": "+35 Max HP · +15 ปราณ (เครื่องรางเริ่มต้น)",
	},
	"bagua_charm": {
		"name": "ยันต์แปดทิศพิทักษ์กาย",
		"slot": "relic",
		"rarity": "วิญญาณ",
		"realm": "เซียน",
		"color": "#22d3ee",
		"atk": 6,
		"max_hp": 60,
		"max_sp": 20,
		"crit": 0.03,
		"dmg_red": 0.0,
		"cost": 50,
		"desc": "+60 Max HP · +20 ปราณ · +6 ATK · +3% คริ",
	},
	"frost_jade": {
		"name": "หยกเหมันต์พันปี",
		"slot": "relic",
		"rarity": "วิญญาณ",
		"realm": "เซียน",
		"color": "#60a5fa",
		"atk": 10,
		"max_hp": 45,
		"max_sp": 30,
		"crit": 0.08,
		"dmg_red": 0.0,
		"cost": 65,
		"desc": "+10 ATK · +45 Max HP · +30 ปราณ · +8% คริ",
	},
	"demon_heart": {
		"name": "แก่นอสูรทมิฬ",
		"slot": "relic",
		"rarity": "เซียน",
		"realm": "มาร",
		"color": "#fb7185",
		"atk": 18,
		"max_hp": 85,
		"max_sp": 0,
		"crit": 0.10,
		"dmg_red": 0.0,
		"cost": 100,
		"desc": "+18 ATK · +85 Max HP · +10% คริติคอล",
	},
	"immortal_pill": {
		"name": "โอสถเซียนเก้าวัฏจักร",
		"slot": "relic",
		"rarity": "เซียน",
		"realm": "เทพ",
		"color": "#4ade80",
		"atk": 12,
		"max_hp": 120,
		"max_sp": 40,
		"crit": 0.06,
		"dmg_red": 0.0,
		"cost": 125,
		"desc": "+120 Max HP · +40 ปราณ · +12 ATK · +6% คริ",
	},
}

const MAX_ENHANCE_LV := 5


static func get_item(item_id: String) -> Dictionary:
	return ITEMS.get(item_id, {})


static func get_enhance_multiplier(lv: int) -> float:
	return 1.0 + 0.20 * float(clampi(lv, 0, MAX_ENHANCE_LV))


static func get_enhance_cost(item_id: String, current_lv: int) -> int:
	var it := get_item(item_id)
	var rarity := str(it.get("rarity", "ธรรมดา"))
	var base := 20
	if rarity == "วิญญาณ":
		base = 30
	elif rarity == "เซียน":
		base = 45
	return base + current_lv * 20


static func get_scaled_item_stats(item_id: String, lv: int) -> Dictionary:
	var it := get_item(item_id)
	var mult := get_enhance_multiplier(lv)
	return {
		"atk": int(round(float(it.get("atk", 0)) * mult)),
		"max_hp": int(round(float(it.get("max_hp", 0)) * mult)),
		"max_sp": int(round(float(it.get("max_sp", 0)) * mult)),
		"crit": float(it.get("crit", 0.0)) * mult,
		"dmg_red": float(it.get("dmg_red", 0.0)) * mult,
	}


static func find_item_holder(hero_gear: Dictionary, item_id: String) -> String:
	if item_id.is_empty():
		return ""
	for hid in hero_gear.keys():
		var slots: Variant = hero_gear.get(hid, {})
		if typeof(slots) != TYPE_DICTIONARY:
			continue
		for sk in ALL_SLOTS:
			if str((slots as Dictionary).get(sk, "")) == item_id:
				return str(hid)
	return ""


static func get_realm_progress(hero_gear: Dictionary, hid: String) -> Dictionary:
	var counts := {}
	var slots: Variant = hero_gear.get(hid, {})
	if typeof(slots) == TYPE_DICTIONARY:
		for sk in ALL_SLOTS:
			var item_id := str((slots as Dictionary).get(sk, ""))
			if ITEMS.has(item_id):
				var rm := str(ITEMS[item_id].get("realm", ""))
				if not rm.is_empty():
					counts[rm] = int(counts.get(rm, 0)) + 1
	var best_realm := ""
	var best_count := 0
	for rm in counts.keys():
		var c := int(counts[rm])
		if c > best_count:
			best_count = c
			best_realm = str(rm)
	var active_rm := best_realm if best_count >= 3 else ""
	return {
		"active_realm": active_rm,
		"best_realm": best_realm,
		"best_count": best_count,
		"counts": counts,
	}


static func get_active_realm_set(hero_gear: Dictionary, hid: String) -> String:
	var slots: Variant = hero_gear.get(hid, {})
	if typeof(slots) != TYPE_DICTIONARY:
		return ""
	var realms: Array[String] = []
	for slot_key in ALL_SLOTS:
		var item_id := str((slots as Dictionary).get(slot_key, ""))
		if not ITEMS.has(item_id):
			return ""
		realms.append(str(ITEMS[item_id].get("realm", "")))
	if realms.size() == 3 and not realms[0].is_empty() and realms[0] == realms[1] and realms[1] == realms[2]:
		return realms[0]
	return ""


static func get_bonuses_for_hero(hero_gear: Dictionary, hid: String, gear_levels: Dictionary = {}) -> Dictionary:
	var out := {
		"atk": 0.0,
		"max_hp": 0.0,
		"max_sp": 0.0,
		"crit": 0.0,
		"dmg_red": 0.0,
		"atk_pct": 0.0,
		"max_hp_pct": 0.0,
		"max_sp_pct": 0.0,
		"cd_red": 0.0,
		"lifesteal_crit": 0.0,
		"low_hp_dmg_red": 0.0,
		"lightning_proc": 0.0,
		"set_realm": "",
	}
	var slots: Variant = hero_gear.get(hid, {})
	if typeof(slots) != TYPE_DICTIONARY:
		return out
	for slot_key in ALL_SLOTS:
		var item_id := str((slots as Dictionary).get(slot_key, ""))
		if ITEMS.has(item_id):
			var lv := int(gear_levels.get(item_id, 0))
			var st := get_scaled_item_stats(item_id, lv)
			out["atk"] += float(st["atk"])
			out["max_hp"] += float(st["max_hp"])
			out["max_sp"] += float(st["max_sp"])
			out["crit"] += float(st["crit"])
			out["dmg_red"] += float(st["dmg_red"])
	var realm := get_active_realm_set(hero_gear, hid)
	if not realm.is_empty() and REALM_SET_BONUSES.has(realm):
		var sb: Dictionary = REALM_SET_BONUSES[realm]
		out["set_realm"] = realm
		out["atk_pct"] += float(sb.get("atk_pct", 0.0))
		out["max_hp_pct"] += float(sb.get("max_hp_pct", 0.0))
		out["max_sp_pct"] += float(sb.get("max_sp_pct", 0.0))
		out["crit"] += float(sb.get("crit", 0.0))
		out["cd_red"] += float(sb.get("cd_red", 0.0))
		out["lifesteal_crit"] += float(sb.get("lifesteal_crit", 0.0))
		out["low_hp_dmg_red"] += float(sb.get("low_hp_dmg_red", 0.0))
		out["lightning_proc"] += float(sb.get("lightning_proc", 0.0))
	return out


static func get_drop_pool(chapter: int, is_boss: bool) -> Array:
	if is_boss or chapter >= 4:
		return [
			"thunder_spear", "blood_blade", "talisman_ward_vestment", "obsidian_copper_plate",
			"bagua_charm", "frost_jade", "star_fan", "frost_silk_robe", "demon_heart",
			"heaven_halberd", "golden_dragon_armor", "immortal_pill",
		]
	return ["thunder_spear", "blood_blade", "talisman_ward_vestment", "obsidian_copper_plate", "bagua_charm", "frost_jade"]
