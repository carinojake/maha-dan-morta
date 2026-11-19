extends RefCounted

const SLOT_WEAPON := "weapon"
const SLOT_RELIC := "relic"

const ITEM_ORDER := [
	"jade_sword",
	"thunder_spear",
	"blood_blade",
	"star_fan",
	"heaven_halberd",
	"spirit_orb",
	"bagua_charm",
	"frost_jade",
	"demon_heart",
	"immortal_pill",
]

const ITEMS := {
	"jade_sword": {
		"name": "กระบี่หยกเหมันต์",
		"slot": "weapon",
		"rarity": "ธรรมดา",
		"color": "#38bdf8",
		"atk": 8,
		"max_hp": 0,
		"max_sp": 0,
		"crit": 0.04,
		"cost": 0,
		"desc": "+8 ATK · +4% คริติคอล (อาวุธเริ่มต้น)",
	},
	"thunder_spear": {
		"name": "ทวนอัสนีสวรรค์",
		"slot": "weapon",
		"rarity": "วิญญาณ",
		"color": "#fbbf24",
		"atk": 16,
		"max_hp": 0,
		"max_sp": 15,
		"crit": 0.06,
		"cost": 45,
		"desc": "+16 ATK · +15 ปราณ · +6% คริติคอล",
	},
	"blood_blade": {
		"name": "ดาบโลหิตอสูร",
		"slot": "weapon",
		"rarity": "วิญญาณ",
		"color": "#f87171",
		"atk": 22,
		"max_hp": 30,
		"max_sp": 0,
		"crit": 0.05,
		"cost": 60,
		"desc": "+22 ATK · +30 Max HP · +5% คริติคอล",
	},
	"star_fan": {
		"name": "พัดดาราแปดทิศ",
		"slot": "weapon",
		"rarity": "เซียน",
		"color": "#c084fc",
		"atk": 24,
		"max_hp": 0,
		"max_sp": 35,
		"crit": 0.12,
		"cost": 95,
		"desc": "+24 ATK · +35 ปราณ · +12% คริติคอล",
	},
	"heaven_halberd": {
		"name": "ง้าวสะบั้นเก้าชั้นฟ้า",
		"slot": "weapon",
		"rarity": "เซียน",
		"color": "#fde047",
		"atk": 34,
		"max_hp": 45,
		"max_sp": 20,
		"crit": 0.10,
		"cost": 130,
		"desc": "+34 ATK · +45 Max HP · +20 ปราณ · +10% คริ",
	},
	"spirit_orb": {
		"name": "ลูกแก้วปราณบริสุทธิ์",
		"slot": "relic",
		"rarity": "ธรรมดา",
		"color": "#34d399",
		"atk": 0,
		"max_hp": 35,
		"max_sp": 15,
		"crit": 0.0,
		"cost": 0,
		"desc": "+35 Max HP · +15 ปราณ (เครื่องรางเริ่มต้น)",
	},
	"bagua_charm": {
		"name": "ยันต์แปดทิศพิทักษ์กาย",
		"slot": "relic",
		"rarity": "วิญญาณ",
		"color": "#22d3ee",
		"atk": 6,
		"max_hp": 60,
		"max_sp": 20,
		"crit": 0.03,
		"cost": 50,
		"desc": "+60 Max HP · +20 ปราณ · +6 ATK · +3% คริ",
	},
	"frost_jade": {
		"name": "หยกเหมันต์พันปี",
		"slot": "relic",
		"rarity": "วิญญาณ",
		"color": "#60a5fa",
		"atk": 10,
		"max_hp": 45,
		"max_sp": 30,
		"crit": 0.08,
		"cost": 65,
		"desc": "+10 ATK · +45 Max HP · +30 ปราณ · +8% คริ",
	},
	"demon_heart": {
		"name": "แก่นอสูรทมิฬ",
		"slot": "relic",
		"rarity": "เซียน",
		"color": "#fb7185",
		"atk": 18,
		"max_hp": 85,
		"max_sp": 0,
		"crit": 0.10,
		"cost": 100,
		"desc": "+18 ATK · +85 Max HP · +10% คริติคอล",
	},
	"immortal_pill": {
		"name": "โอสถเซียนเก้าวัฏจักร",
		"slot": "relic",
		"rarity": "เซียน",
		"color": "#4ade80",
		"atk": 12,
		"max_hp": 120,
		"max_sp": 40,
		"crit": 0.06,
		"cost": 125,
		"desc": "+120 Max HP · +40 ปราณ · +12 ATK · +6% คริ",
	},
}


static func get_item(item_id: String) -> Dictionary:
	return ITEMS.get(item_id, {})


static func get_bonuses_for_hero(hero_gear: Dictionary, hid: String) -> Dictionary:
	var out := {"atk": 0.0, "max_hp": 0.0, "max_sp": 0.0, "crit": 0.0}
	var slots: Variant = hero_gear.get(hid, {})
	if typeof(slots) != TYPE_DICTIONARY:
		return out
	for slot_key in [SLOT_WEAPON, SLOT_RELIC]:
		var item_id := str((slots as Dictionary).get(slot_key, ""))
		if ITEMS.has(item_id):
			var it: Dictionary = ITEMS[item_id]
			out["atk"] += float(it.get("atk", 0))
			out["max_hp"] += float(it.get("max_hp", 0))
			out["max_sp"] += float(it.get("max_sp", 0))
			out["crit"] += float(it.get("crit", 0.0))
	return out


static func get_drop_pool(chapter: int, is_boss: bool) -> Array:
	if is_boss or chapter >= 4:
		return ["thunder_spear", "blood_blade", "bagua_charm", "frost_jade", "star_fan", "demon_heart", "heaven_halberd", "immortal_pill"]
	return ["thunder_spear", "blood_blade", "bagua_charm", "frost_jade"]
