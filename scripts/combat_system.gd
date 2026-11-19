extends RefCounted

const PERFECT_DODGE_WINDOW := 0.22
const PERFECT_DODGE_SLOWMO_SCALE := 0.35
const PERFECT_DODGE_SLOWMO_DURATION := 0.90
const PERFECT_DODGE_SP_GAIN := 30.0
const PERFECT_DODGE_CRIT_MULT := 1.80
const PERFECT_DODGE_THREAT_PAD := 44.0
const PERFECT_DODGE_PROJ_RADIUS := 92.0

const COMBO_DECAY_DELAY := 4.0
const COMBO_DECAY_STEP := 2.0
const ELEMENT_MARK_DURATION := 6.0

const RANKS := [
	{"id": "D", "min_score": 0, "dmg_bonus": 0.00, "jade_bonus": 0.00, "color": Color("#94a3b8")},
	{"id": "C", "min_score": 20, "dmg_bonus": 0.05, "jade_bonus": 0.05, "color": Color("#38bdf8")},
	{"id": "B", "min_score": 50, "dmg_bonus": 0.10, "jade_bonus": 0.12, "color": Color("#34d399")},
	{"id": "A", "min_score": 95, "dmg_bonus": 0.15, "jade_bonus": 0.20, "color": Color("#facc15")},
	{"id": "S", "min_score": 155, "dmg_bonus": 0.22, "jade_bonus": 0.30, "color": Color("#fb923c")},
	{"id": "SS", "min_score": 230, "dmg_bonus": 0.28, "jade_bonus": 0.40, "color": Color("#f43f5e")},
	{"id": "SSS", "min_score": 320, "dmg_bonus": 0.35, "jade_bonus": 0.50, "color": Color("#fde047")},
]

const HERO_ELEMENTS := {
	"bai_yueling": "ice",
	"ye_shangye": "pyro",
	"song_ren": "lightning",
	"chen_xi": "pyro",
	"yu_han": "lightning",
	"zhao_yan": "pyro",
	"hei_shan": "nature",
}

const ELEMENT_INFO := {
	"ice": {"name": "เหมันต์", "icon": "❄️", "color": Color("#38bdf8")},
	"lightning": {"name": "อัสนี", "icon": "⚡", "color": Color("#facc15")},
	"pyro": {"name": "เพลิงโลหิต", "icon": "🔥", "color": Color("#fb7185")},
	"nature": {"name": "พฤกษา", "icon": "🌿", "color": Color("#4ade80")},
}

const REACTIONS := {
	"ice+pyro": {
		"id": "melt",
		"name": "หลอมละลาย",
		"icon": "🌋",
		"color": Color("#fb923c"),
		"dmg_mult": 1.60,
		"aoe_radius": 0.0,
		"aoe_mult": 0.0,
	},
	"lightning+pyro": {
		"id": "overload",
		"name": "อสุนีบาตปะทุ",
		"icon": "💥",
		"color": Color("#f43f5e"),
		"dmg_mult": 1.0,
		"aoe_radius": 155.0,
		"aoe_mult": 1.25,
		"stun": 0.8,
	},
	"ice+lightning": {
		"id": "superconduct",
		"name": "น้ำแข็งช็อต",
		"icon": "🌩️",
		"color": Color("#60a5fa"),
		"dmg_mult": 1.0,
		"aoe_radius": 155.0,
		"aoe_mult": 0.90,
		"vuln_duration": 5.0,
	},
	"nature+pyro": {
		"id": "burning",
		"name": "อัคคีผลาญพนา",
		"icon": "🔥",
		"color": Color("#f97316"),
		"dmg_mult": 1.15,
		"aoe_radius": 0.0,
		"aoe_mult": 0.0,
		"burn_duration": 4.0,
	},
	"lightning+nature": {
		"id": "quicken",
		"name": "อัสนีพฤกษา",
		"icon": "⚡🌿",
		"color": Color("#a3e635"),
		"dmg_mult": 1.20,
		"aoe_radius": 0.0,
		"aoe_mult": 0.0,
		"quicken_duration": 5.0,
	},
	"ice+nature": {
		"id": "frostbind",
		"name": "เหมันต์พันธนาการ",
		"icon": "🧊",
		"color": Color("#2dd4bf"),
		"dmg_mult": 1.15,
		"aoe_radius": 0.0,
		"aoe_mult": 0.0,
		"frostbind_duration": 1.5,
	},
}

var combo_score: float = 0.0
var combo_hits: int = 0
var combo_decay_timer: float = 0.0
var peak_rank_idx: int = 0

var slowmo_timer: float = 0.0
var perfect_dodge_crit_ready: bool = false
var perfect_dodge_count: int = 0
var reaction_count: int = 0
var _dash_age: float = 99.0
var _dash_perfect_used: bool = false


func reset():
	combo_score = 0.0
	combo_hits = 0
	combo_decay_timer = 0.0
	peak_rank_idx = 0
	slowmo_timer = 0.0
	perfect_dodge_crit_ready = false
	perfect_dodge_count = 0
	reaction_count = 0
	_dash_age = 99.0
	_dash_perfect_used = false


func on_dash_started():
	_dash_age = 0.0
	_dash_perfect_used = false


func tick(real_delta: float):
	_dash_age += real_delta
	if slowmo_timer > 0.0:
		slowmo_timer = maxf(0.0, slowmo_timer - real_delta)
	if combo_score > 0.0:
		combo_decay_timer -= real_delta
		if combo_decay_timer <= 0.0:
			var idx := get_rank_index()
			if idx > 0:
				combo_score = float(RANKS[idx - 1]["min_score"])
				combo_decay_timer = COMBO_DECAY_STEP
			else:
				combo_score = 0.0
				combo_hits = 0
				combo_decay_timer = 0.0


func can_trigger_perfect_dodge() -> bool:
	return (not _dash_perfect_used) and _dash_age <= PERFECT_DODGE_WINDOW


func trigger_perfect_dodge() -> bool:
	if not can_trigger_perfect_dodge():
		return false
	_dash_perfect_used = true
	slowmo_timer = PERFECT_DODGE_SLOWMO_DURATION
	perfect_dodge_crit_ready = true
	perfect_dodge_count += 1
	add_combo(35.0, false)
	return true


func consume_perfect_dodge_crit() -> bool:
	if not perfect_dodge_crit_ready:
		return false
	perfect_dodge_crit_ready = false
	return true


func get_desired_time_scale(hitstop_timer: float) -> float:
	if hitstop_timer > 0.0:
		return 0.08
	if slowmo_timer > 0.0:
		return PERFECT_DODGE_SLOWMO_SCALE
	return 1.0


func add_combo(points: float, increment_hits: bool = true):
	combo_score = minf(combo_score + points, 420.0)
	if increment_hits:
		combo_hits += 1
	combo_decay_timer = COMBO_DECAY_DELAY
	var idx := get_rank_index()
	if idx > peak_rank_idx:
		peak_rank_idx = idx


func on_player_damaged():
	var idx := get_rank_index()
	if idx > 0:
		combo_score = float(RANKS[idx - 1]["min_score"])
		combo_decay_timer = COMBO_DECAY_DELAY * 0.75
	else:
		combo_score = 0.0
		combo_hits = 0
		combo_decay_timer = 0.0


func get_rank_index() -> int:
	var idx := 0
	for i in range(RANKS.size()):
		if combo_score >= float(RANKS[i]["min_score"]):
			idx = i
	return idx


func get_rank_data() -> Dictionary:
	return RANKS[get_rank_index()]


func get_damage_multiplier() -> float:
	return 1.0 + float(get_rank_data()["dmg_bonus"])


func get_jade_multiplier() -> float:
	return 1.0 + float(get_rank_data()["jade_bonus"])


func get_decay_ratio() -> float:
	if combo_score <= 0.0:
		return 0.0
	return clampf(combo_decay_timer / COMBO_DECAY_DELAY, 0.0, 1.0)


static func get_hero_element(hid: String) -> String:
	return str(HERO_ELEMENTS.get(hid, "pyro"))


static func get_element_info(elem: String) -> Dictionary:
	return ELEMENT_INFO.get(elem, ELEMENT_INFO["pyro"])


static func lookup_reaction(elem_a: String, elem_b: String) -> Dictionary:
	if elem_a == "" or elem_b == "" or elem_a == elem_b:
		return {}
	var pair := [elem_a, elem_b]
	pair.sort()
	var key := "%s+%s" % [pair[0], pair[1]]
	return REACTIONS.get(key, {})
