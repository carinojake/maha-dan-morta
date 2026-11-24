extends Node2D

const HeroData = preload("res://scripts/hero_data.gd")
const SfxSynth = preload("res://scripts/sfx_synth.gd")
const SaveManager = preload("res://scripts/save_manager.gd")
const ChapterData = preload("res://scripts/chapter_data.gd")
const VfxStudio = preload("res://scripts/vfx_studio.gd")
const MonsterData = preload("res://scripts/monster_data.gd")
const CodexUI = preload("res://scripts/codex_ui.gd")
const CharacterStatusUI = preload("res://scripts/character_status_ui.gd")
const CombatSystem = preload("res://scripts/combat_system.gd")
const CutinOverlay = preload("res://scripts/cutin_overlay.gd")
const EquipData = preload("res://scripts/equip_data.gd")
const CUTIN_MODES := ["full", "boss", "skip"]
const CUTIN_MODE_LABELS := {
	"full": "★ คัตอิน: เต็มจอ",
	"boss": "♛ คัตอิน: เฉพาะบอส",
	"skip": "☆ คัตอิน: ข้าม",
}
const CUTIN_MODE_BANNERS := {
	"full": "★ ท่าไม้ตาย: เล่นคลิปเต็มจอทุกครั้ง",
	"boss": "♛ ท่าไม้ตาย: เต็มจอเฉพาะเจอบอส (ปกติเป็นการ์ดเล็ก)",
	"skip": "☆ ท่าไม้ตาย: ข้ามคลิปอัตโนมัติ",
}
const MobileControlsLandscape = preload("res://scripts/mobile_controls_landscape.gd")
const TILE_SIZE := 64
const ROOM_STRIDE := ChapterData.ROOM_STRIDE
const HERO_SCALE := Vector2(0.42, 0.42)
const HERO_OFFSET := Vector2(0, -122)

const MONSTER_DEFS := MonsterData.DEFS

var world_node: Node2D
var floor_layer: Node2D
var fx_layer: Node2D
var sfx: Node
var player: CharacterBody2D
var player_sprite: Sprite2D
var player_shadow: Polygon2D
var player_z_height: float = 0.0
var player_light: PointLight2D
var camera: Camera2D
var target_reticle: Polygon2D
var screen_flash: ColorRect
var parallax_bg: ParallaxBackground
var parallax_mist_layer: ParallaxLayer
var floor_canvas_tex: CanvasTexture
var wall_canvas_tex: CanvasTexture
var room_lights: Array[PointLight2D] = []
var status_btn: Button
var replay_btn: Button
var home_btn: Button
var run_max_crit_dmg: int = 0

var active_hero_id: String = "bai_yueling"
var facing_dir: Vector2 = Vector2.RIGHT
var auto_attack_enabled: bool = false
var hero_hp: Dictionary = {}
var hero_sp: Dictionary = {}
var hero_textures: Dictionary = {}
var light_tex: Texture2D

var walk_timer: float = 0.0
var walk_step: int = 0
var walk_dist_accum: float = 0.0
var walk_was_moving: bool = false
var walk_next_lead: int = 0
var walk_dir_key: String = "walk_side"
var walk_cycle_phase: float = 0.0
var idle_breath_phase: float = 0.0
var footstep_dust_timer: float = 0.0
var cam_look_ahead: Vector2 = Vector2.ZERO
var dungeon_max_x: int = 180
var attack_timer: float = 0.0
var attack_anim_duration: float = 0.28
var pose_override_timer: float = 0.0
var pose_override_duration: float = 0.36
var pose_override_key: String = ""
var q_cd: float = 0.0
var e_cd: float = 0.0
var r_cd: float = 0.0
var dash_timer: float = 0.0
var dash_cooldown: float = 0.0
var dash_dir: Vector2 = Vector2.ZERO
var invuln_timer: float = 0.0
var shake_strength: float = 0.0
var hitstop_timer: float = 0.0
var last_skill_er_timer: float = 0.0
var synergy_cd: float = 0.0
var hazard_timer: float = 4.0
var combat: CombatSystem = CombatSystem.new()
var active_telegraphs: Array = []
var dying_corpses: Array = []
var active_float_labels: Array = []
var float_slot_cursor: int = 0
var end_input_guard_timer: float = 0.0
var _prev_enter_end: bool = false
var codex_fx_btn: Button
var codex_shake_btn: Button
var cultist_sheet_tex: Texture2D
var boss_ch1_sheet_tex: Texture2D
var active_exit_hint: Node2D = null
var fg_canopy_layer: Node2D = null
var ambient_motes: Array = []
var sway_props: Array = []
var mist_wisps: Array = []

var _prev_q: bool = false
var _prev_e: bool = false
var _prev_r: bool = false
var _prev_c: bool = false
var _prev_k: bool = false
var _prev_f: bool = false
var _prev_space: bool = false
var _prev_1: bool = false
var _prev_2: bool = false
var _prev_3: bool = false
var _prev_u: bool = false
var _prev_h: bool = false
var _prev_esc: bool = false

var chapter: int = 1
var current_room: int = 0
var cleared_rooms: Dictionary = {}
var room_gates: Array = []
var sawblades: Array = []
var orbit_blades: Array = []
var enemies: Array = []
var projectiles: Array = []
var enemy_projectiles: Array = []
var heal_orbs: Array = []
var game_over: bool = false
var victory: bool = false
var save_path: String = SaveManager.DEFAULT_PATH
var save_data: Dictionary = {}

var hp_bar: ProgressBar
var hp_label: Label
var sp_bar: ProgressBar
var sp_label: Label
var hero_cards: Dictionary = {}
var active_party: Array = []
var portrait_row: HBoxContainer
var q_title_lbl: Label
var q_val_lbl: Label
var e_title_lbl: Label
var e_val_lbl: Label
var r_title_lbl: Label
var r_val_lbl: Label
var dash_val_lbl: Label
var auto_val_lbl: Label
var room_label: Label
var jade_label: Label
var diff_btn: Button
var minimap_ctrl: Control
var upgrade_overlay: ColorRect
var upgrade_jade_lbl: Label
var upgrade_list_box: VBoxContainer
var codex_tab: int = 0
var codex_tab_btns: Array = []
var codex_upgrade_scroll: ScrollContainer
var codex_party_scroll: ScrollContainer
var codex_party_box: VBoxContainer
var codex_chapters_box: VBoxContainer
var codex_chapter_btns: Array = []
var help_overlay: ColorRect
var boon_overlay: ColorRect
var boon_btns: Array = []
var boon_choices: Array = []
var active_boons: Dictionary = {}
var phoenix_revive_used: bool = false
var codex_gear_scroll: ScrollContainer
var codex_gear_box: VBoxContainer
var codex_ach_scroll: ScrollContainer
var codex_ach_box: VBoxContainer
var codex_char_scroll: ScrollContainer
var codex_char_box: VBoxContainer
var char_status_selected_hid: String = "bai_yueling"
var char_status_drawer_slot: String = ""
var char_status_preview_id: String = ""
var codex_mirror_btn: Button
var gear_filter: String = "all"
var gear_target_hid: String = ""
var gear_inspect_id: String = "jade_sword"
var end_summary_box: VBoxContainer
var toast_panel: PanelContainer
var toast_label: Label
var toast_timer: float = 0.0
var run_hero_damage: Dictionary = {}
var run_elapsed_time: float = 0.0
var run_max_combo_hits: int = 0
var run_max_combo_rank: String = "D"
var run_perfect_dodges: int = 0
var run_reactions: int = 0
var run_jade_earned: int = 0
var run_drops: Array = []
var attack_hit_counter: int = 0
var tutorial_step: int = 0 # 0=inactive, 1=dodge, 2=skill_mark, 3=swap_react
var tutorial_panel: PanelContainer
var tutorial_lbl: Label
var tutorial_skip_btn: Button
var tutorial_arrow_lbl: Label
var boon_granted_rooms: Dictionary = {}
var boss_rush_mode: bool = false
var boss_panel: PanelContainer
var boss_bar: ProgressBar
var boss_name_label: Label
var banner_panel: PanelContainer
var banner_label: Label
var end_overlay: ColorRect
var end_title: Label
var restart_btn: Button
var end_upgrade_btn: Button
var combo_panel: PanelContainer
var combo_rank_label: Label
var combo_sub_label: Label
var combo_bar: ProgressBar
var dodge_ready_label: Label
var cutin_overlay: Control
var pending_ult_hero: String = ""
var codex_cutin_btn: Button
var codex_bgm_btn: Button
var codex_save_input: LineEdit
var _landscape_hint_shown: bool = false
var bot_center_row: HBoxContainer
var top_center_box: VBoxContainer
var room_strip: PanelContainer
var skill_auto_pill: PanelContainer
var skill_q_pill: PanelContainer
var skill_e_pill: PanelContainer
var skill_r_pill: PanelContainer
var skill_dash_pill: PanelContainer
var mobile_controls: Control
var touch_btn: Button
var speed_btn: Button
var menu_toggle_btn: Button
var top_right_panel: VBoxContainer
var top_right_btn_grid: GridContainer
var _prev_m: bool = false
var game_speed_mult: float = 1.0
var _touch_attack_queued: bool = false
var _touch_dash_queued: bool = false


func _exit_tree():
	Engine.time_scale = 1.0


func _total_rooms() -> int:
	return ChapterData.ROOMS_PER_CHAPTER


func _ready():
	chapter = int(Globals.get_meta("chapter", 1))
	boss_rush_mode = bool(Globals.get_meta("boss_rush", false))
	if Globals.has_meta("save_path"):
		save_path = str(Globals.get_meta("save_path"))
	save_data = SaveManager.load_data(save_path)
	game_speed_mult = 1.5 if float(save_data.get("game_speed", 1.0)) >= 1.25 else 1.0
	auto_attack_enabled = bool(Globals.get_meta("auto_attack", bool(save_data.get("auto_attack", false))))
	VfxStudio.set_fx_reduced(bool(save_data.get("fx_reduced", false)))
	active_party = SaveManager._sanitize_party(save_data.get("party", HeroData.DEFAULT_PARTY))
	light_tex = load("res://assets/env/light_radial.png")
	if ResourceLoader.exists("res://assets/monsters/shadow_cultist_sheet.png"):
		cultist_sheet_tex = load("res://assets/monsters/shadow_cultist_sheet.png")
	if ResourceLoader.exists("res://assets/monsters/boss_ch1_sheet.png"):
		boss_ch1_sheet_tex = load("res://assets/monsters/boss_ch1_sheet.png")
	sfx = SfxSynth.new()
	add_child(sfx)
	sfx.set_bgm_enabled(bool(save_data.get("bgm_enabled", true)))
	_preload_hero_textures()
	_init_hero_stats()
	_build_environment()
	_build_player()
	_build_hud()
	if boss_rush_mode:
		_warp_to_room(9)
		_show_banner("🔥 โหมด Boss Rush: พิชิตบอส 10 บทต่อเนื่อง!", 2.5)
	else:
		_spawn_room_wave(0)
	_switch_hero(active_party[0], false)


func _preload_hero_textures():
	var keys := [
		"stride_0", "stride_1", "stride_2",
		"strike_0", "strike_1", "strike_2",
		"walk_down", "walk_up", "walk_side", "attack_4f", "skill_4f",
		"dash", "hurt", "dead", "portrait", "skill_1", "skill_2", "special", "ultimate"
	]
	for hid in HeroData.HERO_ORDER:
		hero_textures[hid] = {"default": {}, "alt": {}, "alt_snow": {}}
		for k in keys:
			var p_def := "res://assets/heroes/%s/%s.png" % [hid, k]
			if ResourceLoader.exists(p_def):
				hero_textures[hid]["default"][k] = load(p_def)
			var p_alt := "res://assets/heroes/%s/alt/%s.png" % [hid, k]
			if ResourceLoader.exists(p_alt):
				hero_textures[hid]["alt"][k] = load(p_alt)
				hero_textures[hid]["alt_snow"][k] = hero_textures[hid]["alt"][k]
			var p_snow := "res://assets/heroes/%s/alt_snow/%s.png" % [hid, k]
			if ResourceLoader.exists(p_snow):
				hero_textures[hid]["alt_snow"][k] = load(p_snow)
				if not hero_textures[hid]["alt"].has(k):
					hero_textures[hid]["alt"][k] = hero_textures[hid]["alt_snow"][k]


func _get_hero_tex(hid: String, key: String, fallback: Texture2D = null) -> Texture2D:
	var costumes: Dictionary = save_data.get("costumes", {})
	var mode: String = str(costumes.get(hid, "default"))
	if mode == "alt_snow":
		mode = "alt"
	var hdict: Dictionary = hero_textures.get(hid, {})
	var cdict: Dictionary = hdict.get(mode, {})
	if cdict.has(key):
		return cdict[key]
	var ddict: Dictionary = hdict.get("default", {})
	return ddict.get(key, fallback)


func _has_4dir_sheet(hid: String) -> bool:
	return _get_hero_tex(hid, "walk_down") != null and _get_hero_tex(hid, "walk_up") != null and _get_hero_tex(hid, "walk_side") != null and _get_hero_tex(hid, "attack_4f") != null and _get_hero_tex(hid, "skill_4f") != null


func _set_player_strip(tex: Texture2D, hframes_cnt: int = 1, frame_idx: int = 0):
	if not is_instance_valid(player_sprite) or tex == null:
		return
	player_sprite.texture = tex
	player_sprite.hframes = maxi(1, hframes_cnt)
	player_sprite.vframes = 1
	player_sprite.frame = clampi(frame_idx, 0, maxi(0, hframes_cnt - 1))


func _update_walk_direction(dir_vec: Vector2):
	if dir_vec.length() <= 0.08:
		return
	var ax := absf(dir_vec.x)
	var ay := absf(dir_vec.y)
	# Pure 45-degree diagonals (ax == ay) always use side-profile stride + flip_h
	# while preserving hysteresis [1.12..1.38] against analog stick jitter.
	var switch_to_vert := (ay > ax * 1.38) if walk_dir_key == "walk_side" else (ay > ax * 1.12)
	if switch_to_vert:
		walk_dir_key = "walk_down" if dir_vec.y > 0.0 else "walk_up"
		if _has_4dir_sheet(active_hero_id) and is_instance_valid(player_sprite):
			player_sprite.flip_h = false
	else:
		walk_dir_key = "walk_side"
		if is_instance_valid(player_sprite):
			if dir_vec.x < -0.05:
				player_sprite.flip_h = true
			elif dir_vec.x > 0.05:
				player_sprite.flip_h = false


func _get_hero_stat(hid: String, key: String) -> float:
	var base := float(HeroData.HEROES[hid].get(key, 0.0))
	var cu: Dictionary = save_data.get("core_upgrades", {})
	var gear := EquipData.get_bonuses_for_hero(save_data.get("hero_gear", {}), hid, save_data.get("gear_levels", {}))
	if key == "max_hp":
		var val := base + float(cu.get("hp_lv", 0)) * 25.0 + float(gear["max_hp"])
		return val * (1.0 + float(gear.get("max_hp_pct", 0.0)))
	elif key == "max_sp":
		var val := base + float(cu.get("sp_lv", 0)) * 15.0 + float(gear["max_sp"]) + (30.0 if active_boons.has("qi_surge") else 0.0)
		return val * (1.0 + float(gear.get("max_sp_pct", 0.0)))
	elif key == "atk":
		var val := base + float(cu.get("atk_lv", 0)) * 6.0 + float(gear["atk"])
		val *= (1.0 + float(gear.get("atk_pct", 0.0)))
		if active_boons.has("lightning_edge"):
			val *= 1.22
		return val
	elif key == "crit":
		return base + float(gear["crit"]) + (0.18 if active_boons.has("crit_heaven") else 0.0)
	elif key == "dmg_red":
		return float(gear.get("dmg_red", 0.0))
	elif key == "cd_red":
		return float(gear.get("cd_red", 0.0))
	elif key == "speed":
		return base * (1.15 if active_boons.has("swift_blade") else 1.0)
	return base


func _init_hero_stats():
	run_hero_damage.clear()
	run_elapsed_time = 0.0
	run_max_combo_hits = 0
	run_max_combo_rank = "D"
	run_perfect_dodges = 0
	run_reactions = 0
	run_jade_earned = 0
	run_drops.clear()
	attack_hit_counter = 0
	for hid in HeroData.HERO_ORDER:
		hero_hp[hid] = _get_hero_stat(hid, "max_hp")
		hero_sp[hid] = _get_hero_stat(hid, "max_sp")
		run_hero_damage[hid] = 0


func _build_abyss_backdrop(cdata: Dictionary, max_x: int):
	var world_w := float(max_x * TILE_SIZE) + 2800.0
	var ftint: Color = cdata["floor_tint"]
	var lcol: Color = cdata["light_color"]
	var sky_col := Color(ftint.r * 0.14, ftint.g * 0.16, ftint.b * 0.22, 1.0)

	var fallback_bg := ColorRect.new()
	fallback_bg.color = sky_col
	fallback_bg.position = Vector2(-1200.0, -1200.0)
	fallback_bg.size = Vector2(world_w, 3400.0)
	fallback_bg.z_index = -100
	add_child(fallback_bg)

	parallax_bg = ParallaxBackground.new()
	parallax_bg.layer = -90
	add_child(parallax_bg)

	# Layer 1: Deep Valley Sky
	var sky_layer := ParallaxLayer.new()
	sky_layer.motion_scale = Vector2(0.02, 0.02)
	parallax_bg.add_child(sky_layer)
	var sky_rect := ColorRect.new()
	sky_rect.color = sky_col
	sky_rect.position = Vector2(-1800.0, -1400.0)
	sky_rect.size = Vector2(6400.0, 3600.0)
	sky_layer.add_child(sky_rect)

	# Layer 2: Distant Mountain Ridge (0.07x) + Mid-Valley Peaks (0.14x) for multi-plane depth
	var ridge_layer := ParallaxLayer.new()
	ridge_layer.motion_scale = Vector2(0.07, 0.07)
	parallax_bg.add_child(ridge_layer)
	var ridge_col := Color(ftint.r * 0.11, ftint.g * 0.15, ftint.b * 0.20, 0.72)
	for i in range(-2, 14):
		var rx_p := float(i) * 380.0
		var rh := 270.0 + float((i * 97) % 140)
		var ridge := Polygon2D.new()
		ridge.polygon = PackedVector2Array([
			Vector2(rx_p - 280.0, 920.0),
			Vector2(rx_p - 60.0, 390.0 - rh),
			Vector2(rx_p + 120.0, 430.0 - rh * 0.80),
			Vector2(rx_p + 320.0, 920.0),
		])
		ridge.color = ridge_col
		ridge_layer.add_child(ridge)

	var peak_layer := ParallaxLayer.new()
	peak_layer.motion_scale = Vector2(0.14, 0.14)
	parallax_bg.add_child(peak_layer)
	var peak_col := Color(ftint.r * 0.07, ftint.g * 0.09, ftint.b * 0.14, 0.92)
	for i in range(-2, 15):
		var px := float(i) * 310.0
		var h1 := 200.0 + float((i * 73) % 125)
		var peak := Polygon2D.new()
		peak.polygon = PackedVector2Array([
			Vector2(px - 220.0, 920.0),
			Vector2(px - 40.0, 430.0 - h1),
			Vector2(px + 95.0, 470.0 - h1 * 0.72),
			Vector2(px + 260.0, 920.0),
		])
		peak.color = peak_col
		peak_layer.add_child(peak)

	# Layer 3: Drifting Valley Mist Clouds (0.24x)
	parallax_mist_layer = ParallaxLayer.new()
	parallax_mist_layer.motion_scale = Vector2(0.24, 0.24)
	parallax_bg.add_child(parallax_mist_layer)
	for m in range(18):
		var cloud := Polygon2D.new()
		var rx := 155.0 + float((m * 47) % 115)
		var ry := 34.0 + float((m * 19) % 24)
		cloud.polygon = _make_ellipse(rx, ry, 18)
		cloud.position = Vector2(float(m) * 240.0 - 400.0, 110.0 + float((m * 137) % 580))
		cloud.color = Color(lcol.r, lcol.g, lcol.b, 0.11)
		parallax_mist_layer.add_child(cloud)


func _spawn_wall_25d(pos: Vector2, wall_tex: Texture2D, wtint: Color, has_floor_below: bool, is_bottom_edge: bool):
	var root := Node2D.new()
	root.position = pos
	var w := Sprite2D.new()
	w.texture = wall_tex
	var tw := maxf(1.0, float(wall_tex.get_width()))
	var th := maxf(1.0, float(wall_tex.get_height()))
	w.scale = Vector2(float(TILE_SIZE) / tw, float(TILE_SIZE) / th)
	w.modulate = wtint
	root.add_child(w)
	if has_floor_below:
		w.offset = Vector2(0.0, -10.0 * (th / float(TILE_SIZE)))
		var top_ridge := ColorRect.new()
		top_ridge.color = wtint.lightened(0.26)
		top_ridge.position = Vector2(-32.0, -42.0)
		top_ridge.size = Vector2(float(TILE_SIZE), 6.0)
		root.add_child(top_ridge)

		var cast_sh := ColorRect.new()
		cast_sh.color = Color(0.0, 0.0, 0.0, 0.34)
		cast_sh.position = pos + Vector2(-32.0, 22.0)
		cast_sh.size = Vector2(float(TILE_SIZE), 18.0)
		floor_layer.add_child(cast_sh)
	elif is_bottom_edge:
		var cliff := ColorRect.new()
		cliff.color = wtint.darkened(0.55)
		cliff.position = Vector2(-32.0, 32.0)
		cliff.size = Vector2(float(TILE_SIZE), 44.0)
		root.add_child(cliff)
		var cliff_rim := ColorRect.new()
		cliff_rim.color = wtint.darkened(0.32)
		cliff_rim.position = Vector2(-32.0, 30.0)
		cliff_rim.size = Vector2(float(TILE_SIZE), 4.0)
		root.add_child(cliff_rim)
	world_node.add_child(root)


func _make_canvas_tex(diffuse_path: String, normal_path: String, shininess: float = 0.32) -> CanvasTexture:
	var ct := CanvasTexture.new()
	ct.diffuse_texture = load(diffuse_path)
	if ResourceLoader.exists(normal_path):
		ct.normal_texture = load(normal_path)
	ct.specular_color = Color(0.58, 0.74, 0.90, 1.0)
	ct.specular_shininess = shininess
	return ct


func _update_active_room_lights():
	for l in room_lights:
		if not is_instance_valid(l):
			continue
		var r_idx := int(l.get_meta("room_idx", -1))
		l.enabled = (r_idx == current_room)


func _build_environment():
	var cdata := ChapterData.get_chapter(chapter)
	var total_rooms := _total_rooms()
	var max_x := total_rooms * ROOM_STRIDE
	dungeon_max_x = max_x
	_build_abyss_backdrop(cdata, max_x)

	var mod := CanvasModulate.new()
	mod.color = cdata["mod_color"]
	add_child(mod)

	floor_layer = Node2D.new()
	floor_layer.z_index = -10
	add_child(floor_layer)

	world_node = Node2D.new()
	world_node.y_sort_enabled = true
	add_child(world_node)

	fx_layer = Node2D.new()
	fx_layer.z_index = 20
	add_child(fx_layer)

	fg_canopy_layer = Node2D.new()
	fg_canopy_layer.z_index = 26
	add_child(fg_canopy_layer)
	sway_props.clear()
	mist_wisps.clear()
	ambient_motes.clear()

	var use_bamboo: bool = bool(cdata["use_bamboo"])
	var floor_diff_path := "res://assets/env/floor_bamboo.png" if use_bamboo else "res://assets/env/floor_slate.png"
	var floor_norm_path := "res://assets/env/floor_bamboo_n.png" if use_bamboo else "res://assets/env/floor_slate_n.png"
	var wall_diff_path := "res://assets/env/wall_bamboo.png" if use_bamboo else "res://assets/env/wall_stone.png"
	var wall_norm_path := "res://assets/env/wall_bamboo_n.png" if use_bamboo else "res://assets/env/wall_stone_n.png"
	floor_canvas_tex = _make_canvas_tex(floor_diff_path, floor_norm_path, 0.34)
	wall_canvas_tex = _make_canvas_tex(wall_diff_path, wall_norm_path, 0.26)
	var floor_tex: Texture2D = floor_canvas_tex
	var wall_tex: Texture2D = wall_canvas_tex
	var crystal_tex: Texture2D = load("res://assets/env/prop_jade_crystal.png")
	var lantern_tex: Texture2D = load("res://assets/env/prop_lantern.png")
	var bagua_tex: Texture2D = load("res://assets/env/prop_bagua_floor.png")
	var brazier_tex: Texture2D = load("res://assets/env/prop_brazier.png")
	var pillar_tex: Texture2D = load("res://assets/env/prop_dragon_pillar.png")
	var bamboo_tex: Texture2D = load("res://assets/env/prop_bamboo_clump.png")
	var tree_tex: Texture2D = load("res://assets/env/prop_peach_tree.png")
	var banner_tex: Texture2D = load("res://assets/env/prop_banner.png")

	var walkable := {}
	for r in range(total_rooms):
		var rx0 := 1 + r * ROOM_STRIDE
		var rx1 := 14 + r * ROOM_STRIDE
		for x in range(rx0, rx1):
			for y in range(1, 8):
				walkable[Vector2i(x, y)] = true
		if r < total_rooms - 1:
			for x in range(rx1, rx1 + 3):
				for y in range(3, 6):
					walkable[Vector2i(x, y)] = true

	var wall_body := StaticBody2D.new()
	add_child(wall_body)

	var ftint: Color = cdata["floor_tint"]
	var wtint: Color = cdata["wall_tint"]
	var slate_boss_tex: CanvasTexture = _make_canvas_tex("res://assets/env/floor_slate.png", "res://assets/env/floor_slate_n.png", 0.38) if use_bamboo else floor_canvas_tex
	for x in range(0, max_x):
		for y in range(0, 9):
			var cell := Vector2i(x, y)
			var pos := Vector2(x * TILE_SIZE + 32, y * TILE_SIZE + 32)
			if walkable.has(cell):
				var r_of_tile := int(x / ROOM_STRIDE)
				var is_boss_tile := (r_of_tile == total_rooms - 1)
				var f := Sprite2D.new()
				f.texture = slate_boss_tex if (is_boss_tile and use_bamboo) else floor_tex
				f.position = pos
				f.scale = Vector2(float(TILE_SIZE) / maxf(1.0, float(f.texture.get_width())), float(TILE_SIZE) / maxf(1.0, float(f.texture.get_height())))
				var checker_shift := 0.042 if ((x + y) % 2 == 0) else -0.028
				var edge_darken := 0.16 if (y == 1 or y == 7) else (0.05 if (y == 2 or y == 6) else 0.0)
				var center_lift := 0.055 if y == 4 else 0.0
				var base_ft := Color(0.58, 0.52, 0.56, 1.0) if (is_boss_tile and chapter == 1) else ftint
				f.modulate = base_ft.lightened(checker_shift + center_lift).darkened(edge_darken)
				floor_layer.add_child(f)
			else:
				var adj := false
				for d in [Vector2i(1,0), Vector2i(-1,0), Vector2i(0,1), Vector2i(0,-1), Vector2i(1,1), Vector2i(-1,-1), Vector2i(1,-1), Vector2i(-1,1)]:
					if walkable.has(cell + d):
						adj = true
						break
				if adj:
					var has_floor_below := walkable.has(cell + Vector2i(0, 1))
					var is_bottom_edge := walkable.has(cell + Vector2i(0, -1)) and not has_floor_below
					_spawn_wall_25d(pos, wall_tex, wtint, has_floor_below, is_bottom_edge)
					var col := CollisionShape2D.new()
					var shape := RectangleShape2D.new()
					var is_corridor_corner := (y == 2 or y == 6) and (walkable.has(cell + Vector2i(1, 1)) or walkable.has(cell + Vector2i(-1, 1)) or walkable.has(cell + Vector2i(1, -1)) or walkable.has(cell + Vector2i(-1, -1)))
					shape.size = Vector2(TILE_SIZE - 8.0, TILE_SIZE - 8.0) if is_corridor_corner else Vector2(TILE_SIZE, TILE_SIZE)
					col.shape = shape
					col.position = pos
					wall_body.add_child(col)

	var lcol: Color = cdata["light_color"]
	for r in range(total_rooms):
		var is_boss_room := (r == total_rooms - 1)
		var base_x := float(r * ROOM_STRIDE)
		var bx := base_x + 7.5
		var rx0_px := (base_x + 1.0) * TILE_SIZE
		var rx1_px := (base_x + 14.0) * TILE_SIZE
		var ry0_px := 1.0 * TILE_SIZE
		var ry1_px := 8.0 * TILE_SIZE

		# Distinct bevelled perimeter border curb so walkable floor separates cleanly from walls/cliffs
		var curb_col := Color(0.96, 0.56, 0.30, 0.42) if (is_boss_room and chapter == 1) else Color(lcol.r, lcol.g, lcol.b, 0.34)
		var curb_pts := PackedVector2Array([
			Vector2(rx0_px + 4.0, ry0_px + 4.0),
			Vector2(rx1_px - 4.0, ry0_px + 4.0),
			Vector2(rx1_px - 4.0, 3.0 * TILE_SIZE),
		])
		var curb_top := Line2D.new()
		curb_top.points = curb_pts
		curb_top.width = 2.5
		curb_top.default_color = curb_col
		curb_top.z_index = 1
		floor_layer.add_child(curb_top)

		var curb_bot := Line2D.new()
		curb_bot.points = PackedVector2Array([
			Vector2(rx1_px - 4.0, 6.0 * TILE_SIZE),
			Vector2(rx1_px - 4.0, ry1_px - 4.0),
			Vector2(rx0_px + 4.0, ry1_px - 4.0),
			Vector2(rx0_px + 4.0, 6.0 * TILE_SIZE if r > 0 else ry0_px + 4.0),
		])
		curb_bot.width = 2.5
		curb_bot.default_color = curb_col
		curb_bot.z_index = 1
		floor_layer.add_child(curb_bot)

		# Stepping-stone navigation path guiding eye toward center Bagua & Eastern Exit Gate
		var stone_col := Color(0.28, 0.22, 0.24, 0.48) if (is_boss_room and chapter == 1) else Color(0.16, 0.26, 0.24, 0.38)
		var stone_rim := Color(0.95, 0.58, 0.28, 0.26) if (is_boss_room and chapter == 1) else Color(0.55, 0.90, 0.80, 0.22)
		for st_i in range(7):
			var st_x := (base_x + 2.2 + float(st_i) * 1.85) * TILE_SIZE
			if absf(st_x - bx * TILE_SIZE) < 76.0:
				continue
			var st := Polygon2D.new()
			st.polygon = _make_ellipse(26.0, 13.0, 10)
			st.color = stone_col
			st.position = Vector2(st_x, 4.5 * TILE_SIZE + (5.0 if st_i % 2 == 0 else -5.0))
			st.z_index = 1
			floor_layer.add_child(st)
			var st_line := Line2D.new()
			var sp_pts := _make_ellipse(26.0, 13.0, 10)
			sp_pts.append(sp_pts[0])
			st_line.points = sp_pts
			st_line.width = 1.2
			st_line.default_color = stone_rim
			st_line.position = st.position
			st_line.z_index = 1
			floor_layer.add_child(st_line)

		var bag := Sprite2D.new()
		bag.texture = bagua_tex
		bag.position = Vector2(bx, 4.5) * TILE_SIZE
		bag.scale = Vector2(0.96, 0.96) if is_boss_room else Vector2(0.74, 0.74)
		var bag_alpha := 0.46 if is_boss_room else (0.34 if r == 4 else 0.20)
		bag.modulate = Color(1.0, 0.58, 0.30, bag_alpha) if (is_boss_room and chapter == 1) else Color(0.72, 0.92, 0.88, bag_alpha)
		floor_layer.add_child(bag)

		if is_boss_room:
			# Grand Soul-Furnace Octagon Ritual Seal in Boss Arena
			var seal_ring := Line2D.new()
			var seal_pts := _make_ellipse(168.0, 118.0, 24)
			seal_pts.append(seal_pts[0])
			seal_ring.points = seal_pts
			seal_ring.width = 3.0
			seal_ring.default_color = Color(0.98, 0.48, 0.22, 0.38) if chapter == 1 else Color(lcol.r, lcol.g, lcol.b, 0.36)
			seal_ring.position = Vector2(bx, 4.5) * TILE_SIZE
			seal_ring.z_index = 1
			floor_layer.add_child(seal_ring)

		# Low-lying atmospheric mist pools for depth & "ป่าไผ่หมอกพิษ" / "โถงเตาหลอม" storytelling
		var mist_col := Color(0.96, 0.42, 0.18, 0.075) if (is_boss_room and chapter == 1) else (Color(0.24, 0.88, 0.64, 0.095) if use_bamboo else Color(lcol.r, lcol.g, lcol.b, 0.07))
		var m_idx := 0
		for mp in [Vector2(base_x + 3.8, 2.0), Vector2(base_x + 10.8, 7.0), Vector2(base_x + 7.4, 1.85), Vector2(base_x + 4.8, 7.1)]:
			var mist := Polygon2D.new()
			mist.polygon = _make_ellipse(142.0, 38.0, 16)
			mist.color = mist_col
			var m_pos: Vector2 = mp * TILE_SIZE
			mist.position = m_pos
			mist.z_index = 1
			floor_layer.add_child(mist)
			mist_wisps.append({"node": mist, "base_pos": m_pos, "phase": float(r * 3 + m_idx) * 1.35, "room": r})
			m_idx += 1

		# Braziers & Lanterns strictly along room perimeter + warm amber contrast against cool jade mist
		var light_positions := [
			Vector2(base_x + 2.2, 1.65),
			Vector2(base_x + 12.6, 1.65),
			Vector2(base_x + 2.2, 7.45),
			Vector2(base_x + 12.6, 7.45),
		] if is_boss_room else [
			Vector2(base_x + 2.3, 1.68),
			Vector2(base_x + 12.5, 1.68),
			Vector2(base_x + 12.5, 7.42),
		]
		var warm_lantern_col := Color(1.0, 0.64, 0.28, 1.0) if (use_bamboo or (is_boss_room and chapter == 1)) else lcol
		for bsp in light_positions:
			var b := Sprite2D.new()
			b.texture = brazier_tex if is_boss_room else (lantern_tex if use_bamboo else brazier_tex)
			b.position = bsp * TILE_SIZE
			b.scale = Vector2(0.76, 0.76) if is_boss_room else Vector2(0.66, 0.66)
			b.offset = Vector2(0, -56) if b.texture == brazier_tex else Vector2(0, -68)
			world_node.add_child(b)
			_add_prop_shadow(b, 20.0, 8.0, 4.0)
			_add_light(b, warm_lantern_col, 1.28 if is_boss_room else 1.15, 3.8, r)

		# Perimeter props kept strictly outside combat lane (y <= 1.68 or y >= 7.55) with true root Y-sort offsets
		if is_boss_room and chapter == 1:
			# Place tall dragon pillars strictly along the northern back wall so they never occlude the arena floor
			for dp_pos in [Vector2(base_x + 3.8, 1.56), Vector2(base_x + 5.8, 1.56), Vector2(base_x + 9.2, 1.56), Vector2(base_x + 11.2, 1.56)]:
				var dp := Sprite2D.new()
				dp.texture = pillar_tex
				dp.position = dp_pos * TILE_SIZE
				dp.scale = Vector2(0.84, 0.84)
				dp.offset = Vector2(0, -98)
				dp.modulate = Color(0.92, 0.76, 0.72, 0.96)
				world_node.add_child(dp)
				_add_prop_shadow(dp, 26.0, 10.0, 4.0)
			for cr_pos in [Vector2(base_x + 5.2, 7.62), Vector2(base_x + 9.8, 7.62)]:
				var b_cr := Sprite2D.new()
				b_cr.texture = crystal_tex
				b_cr.position = cr_pos * TILE_SIZE
				b_cr.scale = Vector2(0.58, 0.58)
				b_cr.offset = Vector2(0, -64)
				b_cr.modulate = Color(1.0, 0.54, 0.26, 0.92)
				world_node.add_child(b_cr)
				_add_prop_shadow(b_cr, 18.0, 7.0, 4.0)
			var boss_bn := Sprite2D.new()
			boss_bn.texture = banner_tex
			boss_bn.position = Vector2(base_x + 7.5, 1.38) * TILE_SIZE
			boss_bn.scale = Vector2(0.78, 0.78)
			boss_bn.offset = Vector2(0, -88)
			world_node.add_child(boss_bn)
			sway_props.append({"node": boss_bn, "phase": float(r) * 0.9, "amp": 1.6, "room": r})
		else:
			var p_node := Sprite2D.new()
			p_node.texture = bamboo_tex if use_bamboo else pillar_tex
			p_node.position = Vector2(base_x + 3.8, 1.58) * TILE_SIZE
			p_node.scale = Vector2(0.84, 0.84)
			p_node.offset = Vector2(0, -106) if use_bamboo else Vector2(0, -98)
			p_node.modulate = ftint.lightened(0.18)
			world_node.add_child(p_node)
			_add_prop_shadow(p_node, 28.0, 10.0, 4.0)
			if use_bamboo:
				sway_props.append({"node": p_node, "phase": float(r) * 1.1, "amp": 1.4, "room": r})

			if use_bamboo:
				for bp_cfg in [
					[bamboo_tex, Vector2(base_x + 1.8, 7.65), Vector2(0.84, 0.84), 0.7],
					[tree_tex if r % 2 == 1 else bamboo_tex, Vector2(base_x + 10.6, 1.56), Vector2(0.86, 0.86), 1.9],
					[bamboo_tex, Vector2(base_x + 6.6, 7.72), Vector2(0.74, 0.74), 3.1],
				]:
					var bm := Sprite2D.new()
					bm.texture = bp_cfg[0]
					bm.position = bp_cfg[1] * TILE_SIZE
					bm.scale = bp_cfg[2]
					bm.offset = Vector2(0, -106)
					bm.modulate = ftint.lightened(0.20)
					world_node.add_child(bm)
					_add_prop_shadow(bm, 28.0, 10.0, 4.0)
					sway_props.append({"node": bm, "phase": float(r) + float(bp_cfg[3]), "amp": 1.5, "room": r})
				var cr_jade := Sprite2D.new()
				cr_jade.texture = crystal_tex
				cr_jade.position = Vector2(base_x + 9.4, 7.58) * TILE_SIZE
				cr_jade.scale = Vector2(0.60, 0.60)
				cr_jade.offset = Vector2(0, -64)
				cr_jade.modulate = Color(0.42, 0.96, 0.78, 0.94)
				world_node.add_child(cr_jade)
				_add_prop_shadow(cr_jade, 18.0, 7.0, 4.0)

				# Foreground silhouette canopy along extreme cliff edge (y=8.55, far below walkable floor y=1..7)
				for fg_x in [base_x + 3.4, base_x + 11.2]:
					var fg_bm := Sprite2D.new()
					fg_bm.texture = bamboo_tex
					fg_bm.position = Vector2(fg_x, 8.62) * TILE_SIZE
					fg_bm.scale = Vector2(0.95, 0.90)
					fg_bm.offset = Vector2(0, -106)
					fg_bm.modulate = Color(0.04, 0.11, 0.10, 0.38)
					fg_canopy_layer.add_child(fg_bm)
					sway_props.append({"node": fg_bm, "phase": fg_x * 0.4, "amp": 2.0, "room": r})
			else:
				if r % 2 == 0:
					var cr := Sprite2D.new()
					cr.texture = crystal_tex
					cr.position = Vector2(base_x + 3.2, 7.52) * TILE_SIZE
					cr.scale = Vector2(0.72, 0.72)
					cr.offset = Vector2(0, -64)
					cr.modulate = lcol.lightened(0.42)
					world_node.add_child(cr)
					_add_prop_shadow(cr, 20.0, 8.0, 4.0)
				var bn := Sprite2D.new()
				bn.texture = banner_tex
				bn.position = Vector2(base_x + 7.5, 1.38) * TILE_SIZE
				bn.scale = Vector2(0.72, 0.72)
				bn.offset = Vector2(0, -88)
				world_node.add_child(bn)
				_add_prop_shadow(bn, 18.0, 7.0, 4.0)
				sway_props.append({"node": bn, "phase": float(r) * 0.8, "amp": 1.4, "room": r})

		# Sawblade traps in mechanical / blade chapters (Ch 3, 6, 7, 10) or odd combat rooms
		if (chapter in [3, 6, 7, 10] and r in [0, 1, 2, 3, 5, 6, 7]) or (r in [2, 6]):
			_spawn_sawblade_trap(Vector2(base_x + 7.5, 2.8) * TILE_SIZE)
			_spawn_sawblade_trap(Vector2(base_x + 7.5, 6.2) * TILE_SIZE)

	for r in range(total_rooms - 1):
		var gx := 14.15 + float(r * ROOM_STRIDE)
		var gate_pos := Vector2(gx * TILE_SIZE, 4.5 * TILE_SIZE)
		# Permanent stone/jade archway pillars framing the eastern doorway so exit is always readable
		for py_tile in [2.85, 6.18]:
			var arch_p := Sprite2D.new()
			arch_p.texture = pillar_tex
			arch_p.position = Vector2((gx - 0.18) * TILE_SIZE, py_tile * TILE_SIZE)
			arch_p.scale = Vector2(0.58, 0.56)
			arch_p.offset = Vector2(0, -96)
			arch_p.modulate = Color(0.68, 0.94, 0.86, 0.92) if use_bamboo else wtint.lightened(0.24)
			world_node.add_child(arch_p)
			_add_prop_shadow(arch_p, 16.0, 6.0, 3.0)

		var thresh := Polygon2D.new()
		thresh.polygon = PackedVector2Array([
			Vector2(-14.0, -TILE_SIZE * 1.42),
			Vector2(18.0, -TILE_SIZE * 1.42),
			Vector2(18.0, TILE_SIZE * 1.42),
			Vector2(-14.0, TILE_SIZE * 1.42),
		])
		thresh.color = Color(lcol.r, lcol.g, lcol.b, 0.14)
		thresh.position = gate_pos
		thresh.z_index = 1
		floor_layer.add_child(thresh)

		var gate := StaticBody2D.new()
		gate.position = gate_pos
		var gcol := CollisionShape2D.new()
		var gshape := RectangleShape2D.new()
		gshape.size = Vector2(40, TILE_SIZE * 3.0)
		gcol.shape = gshape
		gate.add_child(gcol)

		var gband := Polygon2D.new()
		gband.polygon = PackedVector2Array([
			Vector2(-8.0, -TILE_SIZE * 1.45),
			Vector2(8.0, -TILE_SIZE * 1.45),
			Vector2(8.0, TILE_SIZE * 1.45),
			Vector2(-8.0, TILE_SIZE * 1.45),
		])
		gband.color = Color(0.95, 0.28, 0.36, 0.24)
		gate.add_child(gband)

		var gvis := Line2D.new()
		gvis.points = PackedVector2Array([Vector2(0, -TILE_SIZE * 1.45), Vector2(0, TILE_SIZE * 1.45)])
		gvis.width = 5.0
		gvis.default_color = Color(0.98, 0.38, 0.42, 0.82)
		gate.add_child(gvis)
		var gcore := Line2D.new()
		gcore.points = gvis.points
		gcore.width = 2.0
		gcore.default_color = Color(1.0, 0.94, 0.72, 0.92)
		gate.add_child(gcore)

		var seal_lbl := Label.new()
		seal_lbl.text = "⛩️ ผนึก"
		seal_lbl.position = Vector2(-30.0, -14.0)
		seal_lbl.add_theme_font_size_override("font_size", 12)
		seal_lbl.add_theme_color_override("font_color", Color("#fda4af"))
		seal_lbl.add_theme_color_override("font_outline_color", Color(0.05, 0.04, 0.08, 0.95))
		seal_lbl.add_theme_constant_override("outline_size", 3)
		gate.add_child(seal_lbl)

		world_node.add_child(gate)
		room_gates.append(gate)

	_init_ambient_motes(use_bamboo, lcol)

	target_reticle = Polygon2D.new()
	target_reticle.polygon = _make_ellipse(24.0, 11.0, 18)
	target_reticle.color = Color(0.98, 0.82, 0.25, 0.55)
	target_reticle.z_index = -5
	target_reticle.visible = false
	add_child(target_reticle)
	_update_active_room_lights()


func _init_ambient_motes(use_bamboo: bool, lcol: Color):
	ambient_motes.clear()
	if not is_instance_valid(fx_layer):
		return
	var leaf_poly := PackedVector2Array([
		Vector2(-7.0, 0.0), Vector2(-1.5, -2.8), Vector2(7.0, 0.0), Vector2(1.5, 2.8)
	])
	var ember_poly := _make_ellipse(3.2, 3.2, 8)
	for i in range(18):
		var mote := Polygon2D.new()
		mote.polygon = leaf_poly if use_bamboo else ember_poly
		mote.z_index = 4
		fx_layer.add_child(mote)
		ambient_motes.append({
			"node": mote,
			"seed": float(i) * 1.73,
			"leaf_poly": leaf_poly,
			"ember_poly": ember_poly,
			"use_bamboo": use_bamboo,
			"lcol": lcol,
			"rel": Vector2(float((i * 83) % 820) + 70.0, float((i * 59) % 440) + 72.0),
		})
	_reposition_ambient_motes_to_room()


func _reposition_ambient_motes_to_room():
	var is_boss := (current_room == _total_rooms() - 1)
	var base_px := float(current_room * ROOM_STRIDE * TILE_SIZE)
	var reduced := bool(save_data.get("fx_reduced", false))
	for idx in range(ambient_motes.size()):
		var item: Dictionary = ambient_motes[idx]
		var n: Polygon2D = item.get("node")
		if not is_instance_valid(n):
			continue
		var ember_mode: bool = is_boss or not bool(item.get("use_bamboo", false))
		n.polygon = item["ember_poly"] if ember_mode else item["leaf_poly"]
		if ember_mode and chapter == 1:
			n.color = Color(1.0, 0.56, 0.20, 0.48) if idx % 2 == 0 else Color(1.0, 0.84, 0.34, 0.44)
		elif bool(item.get("use_bamboo", false)):
			n.color = Color(0.42, 0.92, 0.68, 0.40) if idx % 3 != 0 else Color(0.74, 0.98, 0.84, 0.30)
		else:
			var lc: Color = item["lcol"]
			n.color = Color(lc.r, lc.g, lc.b, 0.38)
		n.visible = not (reduced and idx % 2 == 1)
		var rel: Vector2 = item["rel"]
		n.position = Vector2(base_px + rel.x, rel.y)


func _process_ambient_world(delta: float):
	var t := run_elapsed_time
	for sp_item in sway_props:
		if int(sp_item.get("room", -1)) != current_room:
			continue
		var snode: Node2D = sp_item.get("node")
		if is_instance_valid(snode):
			var ph := float(sp_item.get("phase", 0.0))
			var amp := float(sp_item.get("amp", 1.4))
			snode.rotation = deg_to_rad(sin(t * 1.45 + ph) * amp)

	for mw_item in mist_wisps:
		if int(mw_item.get("room", -1)) != current_room:
			continue
		var mnode: Polygon2D = mw_item.get("node")
		if is_instance_valid(mnode):
			var bpos: Vector2 = mw_item.get("base_pos", mnode.position)
			var mph := float(mw_item.get("phase", 0.0))
			mnode.position = bpos + Vector2(sin(t * 0.52 + mph) * 22.0, cos(t * 0.38 + mph) * 6.0)

	var is_boss := (current_room == _total_rooms() - 1)
	var base_px := float(current_room * ROOM_STRIDE * TILE_SIZE)
	var reduced := bool(save_data.get("fx_reduced", false))
	for idx in range(ambient_motes.size()):
		var item: Dictionary = ambient_motes[idx]
		var n: Polygon2D = item.get("node")
		if not is_instance_valid(n):
			continue
		n.visible = not (reduced and idx % 2 == 1)
		if not n.visible:
			continue
		var sd := float(item.get("seed", 0.0))
		var ember_mode: bool = is_boss or not bool(item.get("use_bamboo", false))
		var rel: Vector2 = item["rel"]
		if ember_mode:
			rel.x += sin(t * 1.6 + sd) * 14.0 * delta
			rel.y -= (24.0 + fmod(sd * 7.0, 16.0)) * delta
			if rel.y < 68.0:
				rel.y = 500.0
				rel.x = fmod(rel.x + 137.0, 820.0) + 70.0
			n.rotation = sin(t * 2.0 + sd) * 0.4
		else:
			rel.x += (22.0 + sin(t * 1.1 + sd) * 9.0) * delta
			rel.y += (16.0 + cos(t * 0.9 + sd) * 5.0) * delta
			if rel.y > 505.0 or rel.x > 895.0:
				rel.y = 66.0
				rel.x = fmod(sd * 97.0 + t * 31.0, 780.0) + 65.0
			n.rotation = sin(t * 1.8 + sd) * 0.65 + 0.35
		item["rel"] = rel
		n.position = Vector2(base_px + rel.x, rel.y)
		n.modulate.a = (0.55 if reduced else 1.0) * (0.65 + 0.35 * sin(t * 2.2 + sd))

	if is_instance_valid(active_exit_hint):
		var eh_base: Vector2 = active_exit_hint.get_meta("base_pos", active_exit_hint.position)
		active_exit_hint.position = eh_base + Vector2(sin(t * 4.2) * 5.5, 0.0)


func _add_prop_shadow(parent: Node2D, rx: float, ry: float, y_off: float = 0.0):
	var sh := Polygon2D.new()
	sh.polygon = _make_ellipse(rx, ry, 14)
	sh.color = Color(0.0, 0.0, 0.0, 0.36)
	sh.position = Vector2(0, y_off)
	sh.z_index = -1
	parent.add_child(sh)


func _add_light(parent: Node2D, color: Color, energy: float, scale_val: float, room_idx: int = -1):
	var light := PointLight2D.new()
	light.texture = light_tex
	light.color = color
	light.energy = energy
	light.texture_scale = scale_val
	light.shadow_enabled = false
	light.position = Vector2(0, -18)
	parent.add_child(light)
	if room_idx >= 0:
		light.set_meta("room_idx", room_idx)
		room_lights.append(light)


func _build_player():
	player = CharacterBody2D.new()
	player.position = Vector2(4.0 * TILE_SIZE, 4.5 * TILE_SIZE)
	world_node.add_child(player)

	var col := CollisionShape2D.new()
	var shape := CircleShape2D.new()
	shape.radius = 14.0
	col.shape = shape
	player.add_child(col)

	var shadow := Polygon2D.new()
	shadow.polygon = _make_ellipse(22.0, 9.0, 14)
	shadow.color = Color(0.0, 0.0, 0.0, 0.58)
	shadow.z_index = -1
	player.add_child(shadow)
	player_shadow = shadow

	var p_rim := Line2D.new()
	var p_rim_pts := _make_ellipse(23.5, 9.8, 18)
	p_rim_pts.append(p_rim_pts[0])
	p_rim.points = p_rim_pts
	p_rim.width = 1.6
	p_rim.default_color = Color(0.22, 0.85, 0.96, 0.52)
	p_rim.z_index = -1
	player.add_child(p_rim)

	player_sprite = Sprite2D.new()
	player_sprite.scale = HERO_SCALE
	player_sprite.offset = HERO_OFFSET
	player.add_child(player_sprite)

	player_light = PointLight2D.new()
	player_light.texture = light_tex
	player_light.energy = 0.68
	player_light.texture_scale = 3.2
	player_light.position = Vector2(0, -24)
	player.add_child(player_light)

	camera = Camera2D.new()
	var vp := get_viewport_rect().size
	var z := clampf(vp.y / 610.0, 1.18, 1.45)
	camera.zoom = Vector2(z, z)
	camera.position_smoothing_enabled = true
	camera.position_smoothing_speed = 7.2
	camera.drag_horizontal_enabled = true
	camera.drag_vertical_enabled = true
	camera.drag_left_margin = 0.05
	camera.drag_right_margin = 0.05
	camera.drag_top_margin = 0.03
	camera.drag_bottom_margin = 0.03
	camera.limit_left = 0
	camera.limit_right = dungeon_max_x * TILE_SIZE
	camera.limit_smoothed = true
	player.add_child(camera)


func _make_ellipse(rx: float, ry: float, pts: int) -> PackedVector2Array:
	var arr := PackedVector2Array()
	for i in range(pts):
		var a := (float(i) / pts) * TAU
		arr.append(Vector2(cos(a) * rx, sin(a) * ry))
	return arr


func _build_hud():
	var hud := CanvasLayer.new()
	add_child(hud)

	screen_flash = ColorRect.new()
	screen_flash.color = Color(1, 1, 1, 0)
	screen_flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	screen_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(screen_flash)

	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.05, 0.07, 0.11, 0.85)
	sb.border_color = Color(0.82, 0.68, 0.25, 0.85)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(8)
	sb.set_content_margin_all(10)

	var top_left := VBoxContainer.new()
	top_left.position = Vector2(20, 18)
	top_left.add_theme_constant_override("separation", 8)
	hud.add_child(top_left)

	var bar_panel := PanelContainer.new()
	bar_panel.add_theme_stylebox_override("panel", sb)
	top_left.add_child(bar_panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	bar_panel.add_child(vbox)

	hp_bar = _make_bar(Color("#dc2626"), 250, 18)
	hp_label = Label.new()
	hp_label.add_theme_font_size_override("font_size", 12)
	hp_bar.add_child(hp_label)
	hp_label.position = Vector2(8, 0)
	vbox.add_child(hp_bar)

	sp_bar = _make_bar(Color("#0284c7"), 250, 14)
	sp_label = Label.new()
	sp_label.add_theme_font_size_override("font_size", 11)
	sp_bar.add_child(sp_label)
	sp_label.position = Vector2(8, -1)
	vbox.add_child(sp_bar)

	portrait_row = HBoxContainer.new()
	portrait_row.add_theme_constant_override("separation", 8)
	top_left.add_child(portrait_row)
	_rebuild_party_hud()

	var top_center := VBoxContainer.new()
	top_center_box = top_center
	top_center.position = Vector2(300, 14)
	top_center.size = Vector2(560, 96)
	top_center.add_theme_constant_override("separation", 6)
	top_center.alignment = BoxContainer.ALIGNMENT_CENTER
	hud.add_child(top_center)

	room_strip = PanelContainer.new()
	room_strip.custom_minimum_size = Vector2(540, 30)
	room_strip.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var strip_sb := sb.duplicate()
	strip_sb.bg_color = Color(0.04, 0.07, 0.12, 0.86)
	strip_sb.border_color = Color(0.35, 0.55, 0.65, 0.75)
	strip_sb.set_border_width_all(1)
	strip_sb.set_content_margin_all(4)
	room_strip.add_theme_stylebox_override("panel", strip_sb)
	top_center.add_child(room_strip)

	room_label = Label.new()
	room_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	room_label.custom_minimum_size = Vector2(520, 20)
	room_label.clip_text = true
	room_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	room_label.add_theme_font_size_override("font_size", 14)
	room_label.add_theme_color_override("font_color", Color("#99f6e4"))
	room_strip.add_child(room_label)

	boss_panel = PanelContainer.new()
	boss_panel.custom_minimum_size = Vector2(460, 42)
	boss_panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	boss_panel.add_theme_stylebox_override("panel", sb)
	boss_panel.visible = false
	top_center.add_child(boss_panel)

	var bv := VBoxContainer.new()
	boss_panel.add_child(bv)
	boss_name_label = Label.new()
	boss_name_label.text = "☠️ แม่ทัพอสูรดาบต้องสาป"
	boss_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	boss_name_label.add_theme_font_size_override("font_size", 13)
	boss_name_label.add_theme_color_override("font_color", Color("#fda4af"))
	bv.add_child(boss_name_label)
	boss_bar = _make_bar(Color("#9333ea"), 440, 16)
	bv.add_child(boss_bar)

	var bot_center := HBoxContainer.new()
	bot_center_row = bot_center
	bot_center.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	bot_center.position = Vector2(0, -82)
	bot_center.alignment = BoxContainer.ALIGNMENT_CENTER
	bot_center.add_theme_constant_override("separation", 10)
	hud.add_child(bot_center)

	var p_auto := _make_skill_pill("[F] โจมตี / [C] ออโต้", Color("#e2e8f0"), func():
		if not _is_modal_open():
			_touch_attack_queued = true
			_pulse_skill_pill(skill_auto_pill, true)
	)
	skill_auto_pill = p_auto
	auto_val_lbl = p_auto.find_child("Val", true, false)
	if auto_val_lbl:
		auto_val_lbl.mouse_filter = Control.MOUSE_FILTER_STOP
		auto_val_lbl.gui_input.connect(func(ev: InputEvent):
			if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
				_pulse_skill_pill(skill_auto_pill, true)
				_toggle_auto_attack()
		)
	bot_center.add_child(p_auto)

	var p_q := _make_skill_pill("[Q] สกิล 1", Color("#38bdf8"), func():
		if not _is_modal_open():
			_cast_skill_q(_get_auto_aim_dir())
	)
	skill_q_pill = p_q
	q_title_lbl = p_q.find_child("Title", true, false)
	q_val_lbl = p_q.find_child("Val", true, false)
	bot_center.add_child(p_q)

	var p_e := _make_skill_pill("[E] สกิล 2", Color("#a855f7"), func():
		if not _is_modal_open():
			_cast_skill_e()
	)
	skill_e_pill = p_e
	e_title_lbl = p_e.find_child("Title", true, false)
	e_val_lbl = p_e.find_child("Val", true, false)
	bot_center.add_child(p_e)

	var p_r := _make_skill_pill("[R] ท่าไม้ตาย!", Color("#facc15"), func():
		if not _is_modal_open():
			_cast_skill_r()
	)
	skill_r_pill = p_r
	r_title_lbl = p_r.find_child("Title", true, false)
	r_val_lbl = p_r.find_child("Val", true, false)
	bot_center.add_child(p_r)

	var p_dash := _make_skill_pill("[Space/Shift] วิชาตัวเบา", Color("#2dd4bf"), func():
		if not _is_modal_open():
			_touch_dash_queued = true
	)
	skill_dash_pill = p_dash
	dash_val_lbl = p_dash.find_child("Val", true, false)
	bot_center.add_child(p_dash)

	banner_panel = PanelContainer.new()
	banner_panel.set_anchors_preset(Control.PRESET_CENTER_TOP)
	banner_panel.position = Vector2(-240, 128)
	banner_panel.custom_minimum_size = Vector2(480, 44)
	banner_panel.add_theme_stylebox_override("panel", sb)
	banner_panel.visible = false
	hud.add_child(banner_panel)
	banner_label = Label.new()
	banner_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	banner_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	banner_label.add_theme_font_size_override("font_size", 15)
	banner_label.add_theme_color_override("font_color", Color("#fde047"))
	banner_panel.add_child(banner_label)

	var top_right := VBoxContainer.new()
	top_right_panel = top_right
	top_right.anchor_left = 1.0
	top_right.anchor_right = 1.0
	top_right.offset_left = -286.0
	top_right.offset_right = -16.0
	top_right.offset_top = 16.0
	top_right.offset_bottom = 340.0
	top_right.add_theme_constant_override("separation", 6)
	hud.add_child(top_right)

	var mm_panel := PanelContainer.new()
	mm_panel.add_theme_stylebox_override("panel", sb)
	top_right.add_child(mm_panel)

	var mm_vb := VBoxContainer.new()
	mm_vb.add_theme_constant_override("separation", 6)
	mm_panel.add_child(mm_vb)

	minimap_ctrl = Control.new()
	minimap_ctrl.custom_minimum_size = Vector2(204, 24)
	minimap_ctrl.draw.connect(_draw_minimap)
	mm_vb.add_child(minimap_ctrl)

	var jade_row := HBoxContainer.new()
	jade_row.add_theme_constant_override("separation", 8)
	mm_vb.add_child(jade_row)

	jade_label = Label.new()
	jade_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	jade_label.add_theme_font_size_override("font_size", 13)
	jade_label.add_theme_color_override("font_color", Color("#5eead4"))
	jade_row.add_child(jade_label)

	menu_toggle_btn = Button.new()
	menu_toggle_btn.text = "▼ เมนู [M]"
	menu_toggle_btn.custom_minimum_size = Vector2(96, 30)
	menu_toggle_btn.add_theme_font_size_override("font_size", 12)
	_style_hud_btn(menu_toggle_btn, Color("#d6ad4f"), Color("#fde047"))
	menu_toggle_btn.pressed.connect(_toggle_hud_menu)
	jade_row.add_child(menu_toggle_btn)

	var btn_row := GridContainer.new()
	top_right_btn_grid = btn_row
	btn_row.columns = 3
	btn_row.add_theme_constant_override("h_separation", 6)
	btn_row.add_theme_constant_override("v_separation", 6)
	mm_vb.add_child(btn_row)

	diff_btn = Button.new()
	diff_btn.custom_minimum_size = Vector2(118, 42)
	diff_btn.add_theme_font_size_override("font_size", 13)
	_style_hud_btn(diff_btn, Color("#64748b"), Color("#f8fafc"))
	diff_btn.pressed.connect(_toggle_difficulty)
	btn_row.add_child(diff_btn)

	var upg_btn := Button.new()
	upg_btn.text = "📜 คัมภีร์ [U]"
	upg_btn.custom_minimum_size = Vector2(118, 42)
	upg_btn.add_theme_font_size_override("font_size", 13)
	_style_hud_btn(upg_btn, Color("#38bdf8"), Color("#f8fafc"))
	upg_btn.pressed.connect(_toggle_upgrade_modal)
	btn_row.add_child(upg_btn)

	var help_btn := Button.new()
	help_btn.text = "❓ คู่มือ [H]"
	help_btn.custom_minimum_size = Vector2(118, 42)
	help_btn.add_theme_font_size_override("font_size", 13)
	_style_hud_btn(help_btn, Color("#64748b"), Color("#f8fafc"))
	help_btn.pressed.connect(_toggle_help_overlay)
	btn_row.add_child(help_btn)

	touch_btn = Button.new()
	touch_btn.text = "📱 ทัช"
	touch_btn.custom_minimum_size = Vector2(118, 42)
	touch_btn.add_theme_font_size_override("font_size", 13)
	_style_hud_btn(touch_btn, Color("#2dd4bf"), Color("#f8fafc"))
	touch_btn.pressed.connect(func(): _set_touch_mode(not mobile_controls.visible))
	btn_row.add_child(touch_btn)

	speed_btn = Button.new()
	speed_btn.text = "⏩ 1.0×"
	speed_btn.custom_minimum_size = Vector2(118, 42)
	speed_btn.add_theme_font_size_override("font_size", 13)
	_style_hud_btn(speed_btn, Color("#fbbf24"), Color("#f8fafc"))
	speed_btn.pressed.connect(_toggle_game_speed)
	btn_row.add_child(speed_btn)

	status_btn = Button.new()
	status_btn.text = "👤 สถานะ [K]"
	status_btn.custom_minimum_size = Vector2(118, 42)
	status_btn.add_theme_font_size_override("font_size", 13)
	_style_hud_btn(status_btn, Color("#a855f7"), Color("#f8fafc"))
	status_btn.pressed.connect(_toggle_character_status_modal)
	btn_row.add_child(status_btn)
	save_data["hud_menu_expanded"] = false
	_apply_hud_menu_state()

	var combo_sb := StyleBoxFlat.new()
	combo_sb.bg_color = Color(0.05, 0.07, 0.11, 0.78)
	combo_sb.border_color = Color(0.82, 0.68, 0.25, 0.68)
	combo_sb.set_border_width_all(1)
	combo_sb.set_corner_radius_all(6)
	combo_sb.content_margin_left = 9
	combo_sb.content_margin_right = 9
	combo_sb.content_margin_top = 4
	combo_sb.content_margin_bottom = 5

	combo_panel = PanelContainer.new()
	combo_panel.add_theme_stylebox_override("panel", combo_sb)
	combo_panel.size_flags_horizontal = Control.SIZE_SHRINK_END
	combo_panel.visible = false
	top_right.add_child(combo_panel)

	var cb_vb := VBoxContainer.new()
	cb_vb.add_theme_constant_override("separation", 2)
	combo_panel.add_child(cb_vb)

	var cb_row := HBoxContainer.new()
	cb_row.add_theme_constant_override("separation", 8)
	cb_vb.add_child(cb_row)

	combo_rank_label = Label.new()
	combo_rank_label.text = "D · 0"
	combo_rank_label.add_theme_font_size_override("font_size", 13)
	combo_rank_label.add_theme_color_override("font_color", Color("#94a3b8"))
	cb_row.add_child(combo_rank_label)

	combo_sub_label = Label.new()
	combo_sub_label.text = "+0% ดาเมจ · +0% หยก"
	combo_sub_label.add_theme_font_size_override("font_size", 10)
	combo_sub_label.add_theme_color_override("font_color", Color("#cbd5e1"))
	combo_sub_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	combo_sub_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cb_row.add_child(combo_sub_label)

	combo_bar = _make_bar(Color("#facc15"), 184, 4)
	combo_bar.max_value = 100.0
	combo_bar.value = 0.0
	cb_vb.add_child(combo_bar)

	dodge_ready_label = Label.new()
	dodge_ready_label.text = "★ คริสวนกลับ 100%"
	dodge_ready_label.add_theme_font_size_override("font_size", 10)
	dodge_ready_label.add_theme_color_override("font_color", Color("#fde047"))
	dodge_ready_label.visible = false
	cb_vb.add_child(dodge_ready_label)

	cutin_overlay = CutinOverlay.new()
	hud.add_child(cutin_overlay)
	cutin_overlay.fullscreen_finished.connect(_on_cutin_fullscreen_finished)

	mobile_controls = MobileControlsLandscape.new()
	hud.add_child(mobile_controls)
	mobile_controls.attack_pressed.connect(func():
		if not _is_modal_open():
			_touch_attack_queued = true
	)
	mobile_controls.dash_pressed.connect(func():
		if not _is_modal_open():
			_touch_dash_queued = true
	)
	mobile_controls.skill_q_pressed.connect(func():
		if not _is_modal_open():
			_cast_skill_q(_get_auto_aim_dir())
	)
	mobile_controls.skill_e_pressed.connect(func():
		if not _is_modal_open():
			_cast_skill_e()
	)
	mobile_controls.skill_r_pressed.connect(func():
		if not _is_modal_open():
			_cast_skill_r()
	)
	mobile_controls.auto_toggled.connect(_toggle_auto_attack)
	mobile_controls.speed_toggled.connect(_toggle_game_speed)
	mobile_controls.codex_pressed.connect(_toggle_upgrade_modal)

	end_overlay = ColorRect.new()
	end_overlay.color = Color(0.03, 0.04, 0.06, 0.86)
	end_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	end_overlay.visible = false
	hud.add_child(end_overlay)

	var end_panel := PanelContainer.new()
	end_panel.set_anchors_preset(Control.PRESET_CENTER)
	end_panel.position = Vector2(-280, -220)
	end_panel.custom_minimum_size = Vector2(560, 440)
	end_panel.add_theme_stylebox_override("panel", sb)
	end_overlay.add_child(end_panel)

	var end_box := VBoxContainer.new()
	end_box.add_theme_constant_override("separation", 10)
	end_panel.add_child(end_box)

	end_title = Label.new()
	end_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	end_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	end_title.add_theme_font_size_override("font_size", 20)
	end_box.add_child(end_title)

	end_summary_box = VBoxContainer.new()
	end_summary_box.add_theme_constant_override("separation", 6)
	end_summary_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	end_box.add_child(end_summary_box)

	restart_btn = Button.new()
	restart_btn.text = "🔄 เล่นใหม่อีกครั้ง [Enter]"
	restart_btn.custom_minimum_size = Vector2(340, 42)
	restart_btn.pressed.connect(_on_end_action_pressed)
	end_box.add_child(restart_btn)

	var end_sub_row := HBoxContainer.new()
	end_sub_row.alignment = BoxContainer.ALIGNMENT_CENTER
	end_sub_row.add_theme_constant_override("separation", 8)
	end_box.add_child(end_sub_row)

	replay_btn = Button.new()
	replay_btn.name = "ReplayChapterBtn"
	replay_btn.text = "🔄 เล่นซ้ำ"
	replay_btn.custom_minimum_size = Vector2(166, 38)
	replay_btn.pressed.connect(_replay_current_chapter)
	end_sub_row.add_child(replay_btn)

	home_btn = Button.new()
	home_btn.name = "ReturnHomeBtn"
	home_btn.text = "🏠 กลับหน้าหลัก"
	home_btn.custom_minimum_size = Vector2(166, 38)
	home_btn.pressed.connect(_return_to_hub)
	end_sub_row.add_child(home_btn)

	end_upgrade_btn = Button.new()
	end_upgrade_btn.text = "📜 เปิดหอคัมภีร์อัปเกรด [U]"
	end_upgrade_btn.custom_minimum_size = Vector2(340, 36)
	end_upgrade_btn.pressed.connect(_toggle_upgrade_modal)
	end_box.add_child(end_upgrade_btn)

	var codex_refs := CodexUI.build_modal(hud, sb, chapter, {
		"set_tab": _set_codex_tab,
		"jump_chapter": _jump_to_chapter,
		"warp_room": _warp_to_room,
		"boss_rush": _start_boss_rush,
		"toggle": _toggle_upgrade_modal,
		"toggle_cutin": _toggle_cutin,
		"toggle_fx_reduced": _toggle_fx_reduced,
		"toggle_shake_mode": _toggle_shake_mode,
		"toggle_bgm": _toggle_bgm,
		"toggle_touch_mirror": _toggle_touch_mirror,
		"export_save": _export_save_code,
		"import_save": _import_save_code,
	})
	upgrade_overlay = codex_refs["overlay"]
	upgrade_jade_lbl = codex_refs["jade_lbl"]
	codex_tab_btns = codex_refs["tab_btns"]
	codex_upgrade_scroll = codex_refs["upg_scroll"]
	upgrade_list_box = codex_refs["upg_list"]
	codex_party_scroll = codex_refs["party_scroll"]
	codex_party_box = codex_refs["party_box"]
	codex_chapters_box = codex_refs["chapters_box"]
	codex_gear_scroll = codex_refs.get("gear_scroll")
	codex_gear_box = codex_refs.get("gear_box")
	codex_ach_scroll = codex_refs.get("ach_scroll")
	codex_ach_box = codex_refs.get("ach_box")
	codex_char_scroll = codex_refs.get("char_scroll")
	codex_char_box = codex_refs.get("char_box")
	codex_chapter_btns = codex_refs["chapter_btns"]
	codex_cutin_btn = codex_refs["cutin_btn"]
	codex_fx_btn = codex_refs.get("fx_btn")
	codex_shake_btn = codex_refs.get("shake_btn")
	codex_bgm_btn = codex_refs.get("bgm_btn")
	codex_mirror_btn = codex_refs.get("mirror_btn")
	codex_save_input = codex_refs.get("save_code_input")
	_refresh_bgm_btn()
	_refresh_cutin_btn()
	_refresh_fx_and_shake_btns()
	_refresh_mirror_btn()
	if mobile_controls and mobile_controls.has_method("set_mirrored"):
		mobile_controls.set_mirrored(bool(save_data.get("touch_mirror", false)))
	_set_codex_tab(0)

	help_overlay = CodexUI.build_help_overlay(hud, sb, _toggle_help_overlay, {"open_party": _open_codex_tab.bind(1), "open_chapters": _open_codex_tab.bind(2)})
	help_overlay.visible = false

	_build_toast_and_tutorial_hud(hud, sb)
	if (DisplayServer.get_name() != "headless") and not bool(save_data.get("tutorial_completed", false)) and chapter == 1 and current_room == 0 and not boss_rush_mode:
		_start_interactive_tutorial()

	var boon_refs := CodexUI.build_boon_overlay(hud, sb, _pick_boon)
	boon_overlay = boon_refs["overlay"]
	boon_btns = boon_refs["btns"]

	_set_touch_mode(_detect_touch_device())
	if get_viewport():
		get_viewport().size_changed.connect(_on_viewport_resized)
	_on_viewport_resized()


func _detect_touch_device() -> bool:
	if DisplayServer.is_touchscreen_available():
		return true
	if OS.has_feature("web") and Engine.has_singleton("JavaScriptBridge"):
		var has_touch := bool(JavaScriptBridge.eval("('ontouchstart' in window) || (navigator.maxTouchPoints > 0)", true))
		return has_touch
	return false


func _set_touch_mode(enabled: bool):
	if mobile_controls:
		mobile_controls.visible = enabled
	if bot_center_row:
		bot_center_row.visible = not enabled
	if touch_btn:
		touch_btn.text = "📱 ทัช: ON" if enabled else "📱 ทัช"


func _on_viewport_resized():
	var vr := Vector2(1280.0, 720.0)
	if get_viewport():
		var rect_sz := get_viewport().get_visible_rect().size
		if rect_sz.x > 1.0 and rect_sz.y > 1.0:
			vr = rect_sz
	if mobile_controls:
		mobile_controls.layout_for_viewport(vr)
	if is_instance_valid(camera):
		var z := clampf(vr.y / 610.0, 1.18, 1.45)
		camera.zoom = Vector2(z, z)
	_layout_landscape_center_hud(vr)


func _layout_landscape_center_hud(vr: Vector2):
	var expanded := bool(save_data.get("hud_menu_expanded", false))
	var right_w := 402.0 if expanded else 286.0
	var left_bound := 296.0
	var right_bound := vr.x - right_w - 16.0
	var avail_w := maxf(320.0, right_bound - left_bound)
	var center_x := left_bound + avail_w * 0.5
	if top_center_box:
		top_center_box.position = Vector2(left_bound, 14.0)
		top_center_box.size = Vector2(avail_w, 96.0)
	if room_strip:
		var rw := minf(avail_w - 8.0, 560.0)
		room_strip.custom_minimum_size = Vector2(rw, 30.0)
	if room_label:
		room_label.custom_minimum_size = Vector2(minf(avail_w - 24.0, 540.0), 20.0)
	if boss_panel:
		boss_panel.custom_minimum_size = Vector2(minf(avail_w - 16.0, 460.0), 42.0)
	if bot_center_row:
		bot_center_row.anchor_left = 0.0
		bot_center_row.anchor_right = 0.0
		bot_center_row.anchor_top = 0.0
		bot_center_row.anchor_bottom = 0.0
		bot_center_row.position = Vector2(0.0, vr.y - 82.0)
		bot_center_row.size = Vector2(vr.x, 60.0)
	if tutorial_panel:
		var tw := minf(avail_w - 12.0, 520.0)
		tutorial_panel.position = Vector2(center_x - tw * 0.5, 114.0 if (not boss_panel or not boss_panel.visible) else 132.0)
		tutorial_panel.size = Vector2(tw, 52.0)
		tutorial_panel.custom_minimum_size = Vector2(tw, 52.0)


func _style_hud_btn(b: Button, border_col: Color, font_col: Color):
	var n := StyleBoxFlat.new()
	n.bg_color = Color(0.08, 0.12, 0.19, 0.96)
	n.border_color = border_col
	n.set_border_width_all(1)
	n.set_corner_radius_all(6)
	n.content_margin_left = 6
	n.content_margin_right = 6
	n.content_margin_top = 4
	n.content_margin_bottom = 4
	var h := n.duplicate()
	h.bg_color = Color(0.13, 0.19, 0.29, 0.98)
	h.border_color = border_col.lightened(0.25)
	var p := n.duplicate()
	p.bg_color = Color(0.18, 0.25, 0.36, 1.0)
	b.add_theme_stylebox_override("normal", n)
	b.add_theme_stylebox_override("hover", h)
	b.add_theme_stylebox_override("pressed", p)
	b.add_theme_color_override("font_color", font_col)
	b.add_theme_color_override("font_hover_color", Color("#fde047"))
	b.focus_mode = Control.FOCUS_NONE


func _is_modal_open() -> bool:
	return game_over or victory or (upgrade_overlay != null and upgrade_overlay.visible) or (help_overlay != null and help_overlay.visible) or (boon_overlay != null and boon_overlay.visible) or _is_cutin_fullscreen()


func _input(event: InputEvent):
	if event is InputEventScreenTouch and event.pressed and mobile_controls and not mobile_controls.visible:
		_set_touch_mode(true)


func _make_bar(fill_color: Color, w: int, h: int) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.custom_minimum_size = Vector2(w, h)
	bar.show_percentage = false
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.1, 0.12, 0.16, 0.95)
	bg.set_corner_radius_all(4)
	var fg := StyleBoxFlat.new()
	fg.bg_color = fill_color
	fg.set_corner_radius_all(4)
	bar.add_theme_stylebox_override("background", bg)
	bar.add_theme_stylebox_override("fill", fg)
	return bar


func _make_skill_pill(title: String, col: Color, on_click: Callable = Callable()) -> PanelContainer:
	var p := PanelContainer.new()
	p.custom_minimum_size = Vector2(148, 54)
	p.mouse_filter = Control.MOUSE_FILTER_STOP
	p.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.05, 0.08, 0.12, 0.92)
	sb.border_color = col
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(8)
	sb.set_content_margin_all(6)
	p.add_theme_stylebox_override("panel", sb)
	var hb := VBoxContainer.new()
	hb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(hb)
	var l1 := Label.new()
	l1.name = "Title"
	l1.text = title
	l1.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l1.add_theme_font_size_override("font_size", 12)
	l1.add_theme_color_override("font_color", col)
	l1.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hb.add_child(l1)
	var l2 := Label.new()
	l2.name = "Val"
	l2.text = "พร้อมใช้"
	l2.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l2.add_theme_font_size_override("font_size", 11)
	l2.add_theme_color_override("font_color", Color("#94a3b8"))
	l2.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hb.add_child(l2)
	if on_click.is_valid():
		p.gui_input.connect(func(ev: InputEvent):
			if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
				on_click.call()
		)
	return p


func _pulse_skill_pill(pill: Control, success: bool = true):
	if not is_instance_valid(pill):
		return
	pill.pivot_offset = pill.size * 0.5
	pill.scale = Vector2(0.92, 0.92) if success else Vector2(1.06, 0.94)
	pill.modulate = Color(1.45, 1.45, 1.45, 1.0) if success else Color(1.5, 0.55, 0.55, 1.0)
	var tw := pill.create_tween()
	tw.tween_property(pill, "scale", Vector2.ONE, 0.14).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(pill, "modulate", Color.WHITE, 0.16)


func _reject_skill_feedback(pill: Control, reason: String):
	_pulse_skill_pill(pill, false)
	if is_instance_valid(player):
		_spawn_floating_text(player.global_position + Vector2(0, -72), reason, Color("#f87171"), false)


func _switch_hero(hid: String, with_vfx: bool):
	if _is_cutin_fullscreen():
		return
	if hero_hp[hid] <= 0.0:
		return
	var prev_hid := active_hero_id
	active_hero_id = hid
	var data: Dictionary = HeroData.HEROES[hid]
	player_light.color = data["color"]
	attack_timer = 0.0
	pose_override_timer = 0.0
	if _has_4dir_sheet(hid):
		_set_player_strip(_get_hero_tex(hid, walk_dir_key), 3, 0)
	else:
		_set_player_strip(_get_hero_tex(hid, "stride_0"), 1, 0)
	if with_vfx:
		invuln_timer = maxf(invuln_timer, 0.35)
		sfx.play_sfx("switch")
		_spawn_ring_vfx(player.global_position, data["color"], 60.0)
		if prev_hid != hid and last_skill_er_timer > 0.0 and synergy_cd <= 0.0:
			_trigger_switch_in_skill(hid)
		else:
			_show_banner("สลับร่าง: %s (%s)" % [data["name"], data["title"]], 1.4)
	_refresh_hud()


func _trigger_switch_in_skill(hid: String):
	synergy_cd = 2.0
	last_skill_er_timer = 0.0
	combat.add_combo(20.0, false)
	var data: Dictionary = HeroData.HEROES[hid]
	var atk := _get_hero_stat(hid, "atk")
	var col: Color = data["color"]
	pose_override_key = "special"
	pose_override_timer = 0.35
	shake_strength = maxf(shake_strength, 12.0)
	_spawn_ring_vfx(player.global_position, col, 200.0)
	VfxStudio.spawn_galaxy_vortex(floor_layer, player.global_position, col, 175.0)
	_spawn_domain_vfx(player.global_position, data["vfx_domain"], 1.15)
	_show_banner("⚡ Switch-In! %s พุ่งผสานปราณ!" % data["name"], 1.5)
	_spawn_floating_text(player.global_position + Vector2(0, -68), "⚡ Switch-In!", col, true)

	if hid == "song_ren" and int(save_data.get("hero_passives", {}).get("song_ren", 0)) > 0:
		q_cd = maxf(0.0, q_cd - 1.2)
		e_cd = maxf(0.0, e_cd - 1.2)
		hero_hp[hid] = minf(_get_hero_stat(hid, "max_hp"), hero_hp[hid] + 15.0)
		_spawn_floating_text(player.global_position + Vector2(0, -90), "+15 HP & ลดคูลดาวน์!", Color("#4ade80"), false)

	for e in enemies.duplicate():
		if not is_instance_valid(e):
			continue
		if e.global_position.distance_to(player.global_position) <= 215.0:
			var push: Vector2 = (e.global_position - player.global_position).normalized()
			_damage_enemy(e, int(atk * 1.9), push, col, 0.45, true)


func _warp_to_room(room_idx: int):
	upgrade_overlay.visible = false
	if mobile_controls and mobile_controls.has_method("reset_joystick"):
		mobile_controls.reset_joystick()
	if room_idx > 0 and tutorial_step > 0:
		_complete_interactive_tutorial()
	for e in enemies.duplicate():
		if is_instance_valid(e):
			e.queue_free()
	enemies.clear()
	_clear_all_telegraphs()
	_clear_exit_hint()
	for dc in dying_corpses.duplicate():
		if typeof(dc) == TYPE_DICTIONARY and is_instance_valid(dc.get("node")):
			(dc["node"] as Node).queue_free()
	dying_corpses.clear()
	for ob in orbit_blades.duplicate():
		if is_instance_valid(ob):
			ob.queue_free()
	orbit_blades.clear()
	boss_panel.visible = false
	player.global_position = Vector2((4.2 + float(room_idx * ROOM_STRIDE)) * TILE_SIZE, 4.5 * TILE_SIZE)
	camera.reset_smoothing()
	_spawn_room_wave(room_idx)


func _spawn_room_wave(room_idx: int):
	_clear_exit_hint()
	if mobile_controls and mobile_controls.has_method("reset_joystick"):
		mobile_controls.reset_joystick()
	current_room = clampi(room_idx, 0, _total_rooms() - 1)
	if boss_panel:
		boss_panel.visible = false
	_update_active_room_lights()
	_reposition_ambient_motes_to_room()
	if sfx and sfx.has_method("set_bgm_mode"):
		sfx.set_bgm_mode(current_room == 4 or current_room == 9 or boss_rush_mode)
	if minimap_ctrl:
		minimap_ctrl.queue_redraw()
	var cdata := ChapterData.get_chapter(chapter)
	var floor_no := ChapterData.get_floor_number(chapter, current_room)
	var zone_name := ChapterData.get_zone_name(chapter, current_room)
	var ch_title := str(cdata["title"])
	var bx := float(current_room * ROOM_STRIDE)

	if current_room in [0, 1, 2, 3]:
		room_label.text = "ชั้นที่ %d/100 — บทที่ %d: %s · %s (%d/10) [%s]" % [floor_no, chapter, ch_title, zone_name, current_room + 1, cdata["mob_a"]]
		if chapter == 1 and current_room == 0 and not boss_rush_mode:
			_spawn_enemy("cultist", Vector2(bx + 9.4, 4.5) * TILE_SIZE)
			if enemies.size() > 0 and is_instance_valid(enemies[0]):
				enemies[0].set_meta("hp", 150.0)
				enemies[0].set_meta("max_hp", 150.0)
		else:
			_spawn_enemy("puppet" if chapter in [2, 6, 7] else "cultist", Vector2(bx + 9.0, 2.8) * TILE_SIZE)
			_spawn_enemy("hound", Vector2(bx + 10.2, 6.0) * TILE_SIZE)
			_spawn_enemy("cultist" if current_room % 2 == 0 else "golem", Vector2(bx + 11.4, 4.5) * TILE_SIZE)
		if current_room == 0:
			_show_banner("⚔️ บทที่ %d: %s — %s" % [chapter, ch_title, cdata["hazard_desc"]], 2.6)
	elif current_room == 4 or current_room == 8:
		room_label.text = "ชั้นที่ %d/100 — บทที่ %d: %s · %s (%d/10) [มินิบอส!]" % [floor_no, chapter, ch_title, zone_name, current_room + 1]
		_spawn_enemy("bronze_sentinel", Vector2(bx + 9.5, 4.5) * TILE_SIZE)
		var mb: CharacterBody2D = enemies[enemies.size() - 1]
		var mb_sp: Sprite2D = mb.get_node("Sprite")
		mb_sp.texture = load(str(cdata["miniboss_tex"]))
		var mb_sc := float(cdata["miniboss_scale"])
		mb_sp.scale = Vector2(mb_sc, mb_sc)
		mb_sp.offset = Vector2(0, -mb_sp.texture.get_height() * 0.42) if mb_sp.texture else Vector2.ZERO
		mb.set_meta("base_offset_y", mb_sp.offset.y)
		mb.set_meta("custom_tint", cdata["miniboss_tint"])
		mb_sp.modulate = cdata["miniboss_tint"]
		var mb_lbl := Label.new()
		mb_lbl.text = "🛡️ " + str(cdata["miniboss"]).split(" (")[0]
		mb_lbl.position = Vector2(-80, -138)
		mb_lbl.custom_minimum_size = Vector2(160, 20)
		mb_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		mb_lbl.add_theme_font_size_override("font_size", 12)
		mb_lbl.add_theme_color_override("font_color", Color("#fde047"))
		mb_lbl.add_theme_color_override("font_outline_color", Color.BLACK)
		mb_lbl.add_theme_constant_override("outline_size", 3)
		mb.add_child(mb_lbl)
		_spawn_enemy("puppet" if chapter >= 5 else "cultist", Vector2(bx + 11.2, 2.4) * TILE_SIZE)
		_spawn_enemy("hound", Vector2(bx + 11.2, 6.6) * TILE_SIZE)
		boss_name_label.text = "🛡️ มินิบอส: %s" % str(cdata["miniboss"]).split(" (")[0]
		boss_bar.max_value = float(mb.get_meta("max_hp"))
		boss_bar.value = float(mb.get_meta("hp"))
		boss_panel.visible = true
		_show_boss_warning(str(cdata["miniboss"]).split(" (")[0], true)
	elif current_room in [5, 6, 7]:
		room_label.text = "ชั้นที่ %d/100 — บทที่ %d: %s · %s (%d/10) [%s]" % [floor_no, chapter, ch_title, zone_name, current_room + 1, cdata["mob_b"]]
		_spawn_enemy("puppet", Vector2(bx + 8.8, 2.6) * TILE_SIZE)
		_spawn_enemy("golem", Vector2(bx + 10.2, 4.5) * TILE_SIZE)
		_spawn_enemy("cultist", Vector2(bx + 9.2, 6.3) * TILE_SIZE)
		_spawn_enemy("hound", Vector2(bx + 11.8, 3.6) * TILE_SIZE)
	elif current_room == 9:
		room_label.text = "ชั้นที่ %d/100 — บทที่ %d: %s · %s (10/10) [โถงบอสใหญ่!]" % [floor_no, chapter, ch_title, zone_name]
		boss_name_label.text = "☠️ %s (เฟส 1)" % cdata["boss"]
		var b_kind := "boss" if chapter in [1, 3, 4, 8] else ("boss_ch2" if chapter in [2, 5, 9] else "boss_ch3")
		_spawn_enemy(b_kind, Vector2(bx + 10.0, 4.5) * TILE_SIZE)
		var boss_e: CharacterBody2D = enemies[enemies.size() - 1]
		var mult := 1.35 if str(save_data.get("difficulty", "normal")) == "hard" else 1.0
		var bhp := float(cdata["boss_hp"]) * mult
		boss_e.set_meta("hp", bhp)
		boss_e.set_meta("max_hp", bhp)
		var b_sp: Sprite2D = boss_e.get_node("Sprite")
		if chapter == 1 and boss_ch1_sheet_tex != null:
			b_sp.texture = boss_ch1_sheet_tex
			b_sp.hframes = 10
			b_sp.vframes = 1
			b_sp.frame = 0
			boss_e.set_meta("sheet_type", "boss_ch1_10f")
			var b_sc := float(cdata["boss_scale"])
			b_sp.scale = Vector2(b_sc, b_sc)
			b_sp.offset = Vector2(0.0, -151.0)
		else:
			b_sp.texture = load(str(cdata["boss_tex"]))
			b_sp.hframes = 1
			b_sp.vframes = 1
			b_sp.frame = 0
			boss_e.set_meta("sheet_type", "")
			var b_sc := float(cdata["boss_scale"])
			b_sp.scale = Vector2(b_sc, b_sc)
			b_sp.offset = Vector2(0, -b_sp.texture.get_height() * 0.42) if b_sp.texture else Vector2.ZERO
		boss_e.set_meta("base_scale", b_sp.scale)
		boss_e.set_meta("base_offset_y", b_sp.offset.y)
		boss_e.set_meta("custom_tint", cdata["boss_tint"])
		b_sp.modulate = cdata["boss_tint"]
		var b_aura := Line2D.new()
		var a_pts := VfxStudio._make_star_poly(78.0, 46.0, 8)
		a_pts.append(a_pts[0])
		b_aura.points = a_pts
		b_aura.width = 2.8
		var lc: Color = cdata["light_color"]
		b_aura.default_color = Color(lc.r, lc.g, lc.b, 0.72)
		boss_e.add_child(b_aura)
		if chapter in [6, 7, 8, 9, 10]:
			_spawn_enemy("turret", Vector2(bx + 11.8, 2.0) * TILE_SIZE)
			_spawn_enemy("turret", Vector2(bx + 11.8, 7.0) * TILE_SIZE)
		else:
			_spawn_enemy("hound", Vector2(bx + 8.6, 2.4) * TILE_SIZE)
			_spawn_enemy("hound", Vector2(bx + 8.6, 6.6) * TILE_SIZE)
		boss_bar.max_value = bhp
		boss_bar.value = bhp
		boss_panel.visible = true
		_show_boss_warning(str(cdata["boss"]), false)


func _spawn_enemy(kind: String, pos: Vector2):
	var def: Dictionary = MONSTER_DEFS[kind]
	var mult := 1.35 if str(save_data.get("difficulty", "normal")) == "hard" else 1.0
	var hp_val := float(def["hp"]) * mult
	var e := CharacterBody2D.new()
	e.collision_layer = 2
	e.collision_mask = 1
	e.position = pos
	e.set_meta("kind", kind)
	e.set_meta("hp", hp_val)
	e.set_meta("max_hp", hp_val)
	e.set_meta("atk_cd", 0.6)
	e.set_meta("special_cd", 2.0)
	e.set_meta("casting", 0.0)
	e.set_meta("boss_phase", 0)
	e.set_meta("phase2_done", false)
	e.set_meta("flash", 0.0)
	e.set_meta("stun", 0.0)
	e.set_meta("kb", Vector2.ZERO)
	e.set_meta("trap_cd", 0.0)
	e.set_meta("qi_mark", "")
	e.set_meta("windup_timer", 0.0)
	e.set_meta("attack_pose_timer", 0.0)
	e.set_meta("recovery_timer", 0.0)
	e.set_meta("hurt_timer", 0.0)
	e.set_meta("vuln_open", 0.0)
	e.set_meta("ai_state", "idle")
	e.set_meta("walk_dist", 0.0)
	e.set_meta("walk_idx", 0)
	e.set_meta("attack_dir", Vector2.LEFT)
	e.set_meta("cast_pose", "slam")
	e.set_meta("is_dead", false)
	var compass_slots := [0.0, 1.15, -1.15, 2.35, -2.35, 0.58, -0.58]
	e.set_meta("surround_angle", float(compass_slots[enemies.size() % compass_slots.size()]))
	e.set_meta("shield", float(def.get("shield", 0.0)) * mult)
	e.set_meta("max_shield", float(def.get("shield", 0.0)) * mult)

	var col := CollisionShape2D.new()
	var sh := CircleShape2D.new()
	sh.radius = 28.0 if def["is_boss"] else 18.0
	col.shape = sh
	e.add_child(col)

	var shadow := Polygon2D.new()
	shadow.name = "Shadow"
	var s_rx := 34.0 if def["is_boss"] else 20.0
	shadow.polygon = _make_ellipse(s_rx, s_rx * 0.42, 12)
	shadow.color = Color(0, 0, 0, 0.58)
	e.add_child(shadow)

	var rim := Line2D.new()
	var rim_pts := _make_ellipse(s_rx + 2.0, (s_rx + 2.0) * 0.42, 16)
	rim_pts.append(rim_pts[0])
	rim.points = rim_pts
	rim.width = 2.0 if def["is_boss"] else 1.5
	rim.default_color = Color("#fb923c", 0.65) if (def["is_boss"] or def.get("is_miniboss", false)) else Color("#f87171", 0.48)
	e.add_child(rim)

	var sp := Sprite2D.new()
	sp.name = "Sprite"
	var sc: float = def["scale"]
	sp.scale = Vector2(sc, sc)
	var base_tint: Color = def.get("tint", Color.WHITE)
	sp.modulate = Color(1.18, 1.14, 1.14, 1.0) if base_tint == Color.WHITE else base_tint
	if kind == "cultist" and cultist_sheet_tex != null:
		sp.texture = cultist_sheet_tex
		sp.hframes = 8
		sp.vframes = 1
		sp.frame = 0
		sp.offset = Vector2(0.0, -72.0)
		e.set_meta("sheet_type", "cultist_8f")
	else:
		sp.texture = load(def["tex"])
		sp.offset = Vector2(0, -sp.texture.get_height() * 0.42) if sp.texture else Vector2.ZERO
		e.set_meta("sheet_type", "")
	e.set_meta("base_scale", sp.scale)
	e.set_meta("base_offset_y", sp.offset.y)
	e.set_meta("z_height", 0.0)
	e.add_child(sp)

	if not def["is_boss"]:
		var hp_bg := ColorRect.new()
		hp_bg.name = "HPBg"
		hp_bg.color = Color(0.1, 0.1, 0.1, 0.8)
		hp_bg.size = Vector2(54 if def.get("is_miniboss", false) else 44, 6 if def.get("is_miniboss", false) else 5)
		hp_bg.position = Vector2(-hp_bg.size.x * 0.5, -96)
		e.add_child(hp_bg)
		var hp_fg := ColorRect.new()
		hp_fg.name = "HPFg"
		hp_fg.color = Color("#f97316") if def.get("is_miniboss", false) else Color("#ef4444")
		hp_fg.size = hp_bg.size
		hp_bg.add_child(hp_fg)

		if float(e.get_meta("max_shield")) > 0.0:
			var sh_bg := ColorRect.new()
			sh_bg.name = "ShieldBg"
			sh_bg.color = Color(0.08, 0.12, 0.18, 0.9)
			sh_bg.size = Vector2(54, 5)
			sh_bg.position = Vector2(-27, -104)
			e.add_child(sh_bg)
			var sh_fg := ColorRect.new()
			sh_fg.name = "ShieldFg"
			sh_fg.color = Color("#38bdf8")
			sh_fg.size = Vector2(54, 5)
			sh_bg.add_child(sh_fg)
			var sh_aura := Line2D.new()
			sh_aura.name = "ShieldAura"
			var s_pts := _make_ellipse(42.0, 22.0, 24)
			s_pts.append(s_pts[0])
			sh_aura.points = s_pts
			sh_aura.width = 3.0
			sh_aura.default_color = Color(0.22, 0.74, 0.97, 0.85)
			e.add_child(sh_aura)
		if def.get("is_turret", false):
			var tring := Line2D.new()
			var t_pts := _make_ellipse(30.0, 18.0, 20)
			t_pts.append(t_pts[0])
			tring.points = t_pts
			tring.width = 3.0
			tring.default_color = Color(0.96, 0.25, 0.30, 0.85)
			e.add_child(tring)
	else:
		_add_light(e, Color("#ef4444") if kind == "boss_ch3" else Color("#a855f7"), 1.6, 3.2)
	if not def["is_boss"]:
		_add_light(e, Color("#f59e0b") if def.get("is_miniboss", false) else Color("#94a3b8"), 0.85, 1.8)

	var mark_lbl := Label.new()
	mark_lbl.name = "MarkLabel"
	mark_lbl.text = ""
	mark_lbl.position = Vector2(-12, -124)
	mark_lbl.add_theme_font_size_override("font_size", 16)
	mark_lbl.add_theme_color_override("font_outline_color", Color.BLACK)
	mark_lbl.add_theme_constant_override("outline_size", 3)
	e.add_child(mark_lbl)

	var wind_ring := Line2D.new()
	wind_ring.name = "WindupRing"
	var wr_rx := float(def.get("range", 58.0)) * 0.85
	var wr_pts := _make_ellipse(wr_rx, wr_rx * 0.52, 24)
	wr_pts.append(wr_pts[0])
	wind_ring.points = wr_pts
	wind_ring.width = 3.0
	wind_ring.default_color = Color(0.98, 0.20, 0.20, 0.92)
	wind_ring.z_index = -1
	wind_ring.visible = false
	e.add_child(wind_ring)

	var wind_lbl := Label.new()
	wind_lbl.name = "WindupLabel"
	wind_lbl.text = "⚠️ โจมตี!"
	wind_lbl.position = Vector2(-36, -122)
	wind_lbl.custom_minimum_size = Vector2(72, 22)
	wind_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	wind_lbl.add_theme_font_size_override("font_size", 13)
	wind_lbl.add_theme_color_override("font_color", Color("#fef08a"))
	wind_lbl.add_theme_color_override("font_outline_color", Color("#dc2626"))
	wind_lbl.add_theme_constant_override("outline_size", 4)
	wind_lbl.visible = false
	e.add_child(wind_lbl)

	# Directional slash sector telegraph so player sees exact melee swing direction & reach
	var cone := Polygon2D.new()
	cone.name = "SlashCone"
	var cr := float(def.get("range", 72.0)) + 10.0
	var cpts := PackedVector2Array([Vector2.ZERO])
	for ci in range(11):
		var a := lerpf(-0.62, 0.62, float(ci) / 10.0)
		cpts.append(Vector2(cos(a) * cr, sin(a) * cr * 0.72))
	cone.polygon = cpts
	cone.color = Color(0.98, 0.20, 0.24, 0.30)
	cone.z_index = -1
	cone.visible = false
	e.add_child(cone)

	var open_lbl := Label.new()
	open_lbl.name = "VulnOpenLabel"
	open_lbl.text = "⚡ ช่องว่าง!"
	open_lbl.position = Vector2(-52, -148 if def["is_boss"] else -118)
	open_lbl.custom_minimum_size = Vector2(104, 22)
	open_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	open_lbl.add_theme_font_size_override("font_size", 13)
	open_lbl.add_theme_color_override("font_color", Color("#5eead4"))
	open_lbl.add_theme_color_override("font_outline_color", Color("#0f172a"))
	open_lbl.add_theme_constant_override("outline_size", 4)
	open_lbl.visible = false
	e.add_child(open_lbl)

	world_node.add_child(e)
	enemies.append(e)


func _set_enemy_sheet_pose(e: CharacterBody2D, sp: Sprite2D, state_name: String, walk_idx: int = 0, cast_pose: String = "slam"):
	var stype := str(e.get_meta("sheet_type", ""))
	if stype == "cultist_8f":
		match state_name:
			"idle":
				sp.frame = 0
			"move":
				sp.frame = 1 if (walk_idx % 2 == 0) else 2
			"windup":
				sp.frame = 3
			"attack":
				sp.frame = 4
			"recovery":
				sp.frame = 5
			"hurt":
				sp.frame = 6
			"death":
				sp.frame = 7
	elif stype == "boss_ch1_10f":
		match state_name:
			"idle":
				sp.frame = 0
			"move":
				sp.frame = 1 if (walk_idx % 2 == 0) else 2
			"windup":
				sp.frame = 5 if cast_pose == "wave" else 3
			"attack":
				sp.frame = 6 if cast_pose == "wave" else 4
			"recovery":
				sp.frame = 7
			"hurt":
				sp.frame = 8
			"death":
				sp.frame = 9


func _get_nearest_enemy(max_dist: float = 540.0) -> CharacterBody2D:
	var best: CharacterBody2D = null
	var best_d := max_dist
	for e in enemies.duplicate():
		if not is_instance_valid(e):
			continue
		var d: float = e.global_position.distance_to(player.global_position)
		if d < best_d:
			best_d = d
			best = e
	return best


func _get_auto_aim_dir() -> Vector2:
	var target := _get_nearest_enemy(540.0)
	if target != null:
		return (target.global_position - player.global_position).normalized()
	return facing_dir


func _process(delta: float):
	var modal_open := _is_modal_open()
	if mobile_controls:
		mobile_controls.set_active(not modal_open)
	if tutorial_panel:
		tutorial_panel.visible = (tutorial_step > 0 and not modal_open)
	if tutorial_arrow_lbl:
		tutorial_arrow_lbl.visible = (tutorial_step > 0 and not modal_open)
	if game_over or victory:
		if _is_cutin_fullscreen():
			cutin_overlay.skip()
		Engine.time_scale = 1.0
		var real_dt := delta / maxf(Engine.time_scale, 0.05)
		if end_input_guard_timer > 0.0:
			end_input_guard_timer = maxf(0.0, end_input_guard_timer - real_dt)
			if end_input_guard_timer <= 0.0 and restart_btn:
				restart_btn.disabled = false
			_prev_enter_end = Input.is_key_pressed(KEY_ENTER) or Input.is_key_pressed(KEY_KP_ENTER)
			return
		# Require a clean Enter press (never Space/Dash or Q/E/R skill keys!) after guard expires
		var ent_now := Input.is_key_pressed(KEY_ENTER) or Input.is_key_pressed(KEY_KP_ENTER)
		if ent_now and not _prev_enter_end:
			_prev_enter_end = ent_now
			_on_end_action_pressed()
		_prev_enter_end = ent_now
		return

	var kh := Input.is_key_pressed(KEY_H)
	if kh and not _prev_h:
		_toggle_help_overlay()
	_prev_h = kh
	if help_overlay and help_overlay.visible:
		Engine.time_scale = 1.0
		if Input.is_key_pressed(KEY_ENTER) or Input.is_key_pressed(KEY_ESCAPE):
			help_overlay.visible = false
		return

	if boon_overlay and boon_overlay.visible:
		if _is_cutin_fullscreen():
			cutin_overlay.skip()
		Engine.time_scale = 1.0
		if Input.is_key_pressed(KEY_1):
			_pick_boon(0)
		elif Input.is_key_pressed(KEY_2):
			_pick_boon(1)
		elif Input.is_key_pressed(KEY_3):
			_pick_boon(2)
		return

	if _is_cutin_fullscreen():
		if mobile_controls:
			mobile_controls.set_active(false)
		var clip_delta := delta / maxf(Engine.time_scale, 0.05)
		Engine.time_scale = 1.0
		cutin_overlay.tick(clip_delta)
		return

	var ku := Input.is_key_pressed(KEY_U)
	if ku and not _prev_u:
		_toggle_upgrade_modal()
	_prev_u = ku
	var kk := Input.is_key_pressed(KEY_K)
	if kk and not _prev_k:
		_toggle_character_status_modal()
	_prev_k = kk
	var km := Input.is_key_pressed(KEY_M)
	if km and not _prev_m:
		_toggle_hud_menu()
	_prev_m = km
	var kesc := Input.is_key_pressed(KEY_ESCAPE)
	if kesc and not _prev_esc and upgrade_overlay and upgrade_overlay.visible:
		_toggle_upgrade_modal()
	_prev_esc = kesc
	if upgrade_overlay and upgrade_overlay.visible:
		Engine.time_scale = 1.0
		return

	if is_instance_valid(parallax_mist_layer):
		parallax_mist_layer.motion_offset.x += delta * 14.0

	var real_delta := delta / maxf(Engine.time_scale, 0.05)
	combat.tick(real_delta)
	if cutin_overlay:
		cutin_overlay.tick(real_delta)

	var desired_scale: float = combat.get_desired_time_scale(hitstop_timer)
	if hitstop_timer <= 0.0 and cutin_overlay and cutin_overlay.is_playing():
		desired_scale = minf(desired_scale, cutin_overlay.get_slowmo_scale())
	elif hitstop_timer <= 0.0 and desired_scale >= 0.99:
		desired_scale = game_speed_mult

	if hitstop_timer > 0.0:
		hitstop_timer = maxf(0.0, hitstop_timer - real_delta)
		Engine.time_scale = desired_scale
		return
	Engine.time_scale = desired_scale

	var sp_rate := 9.0 * (1.35 if active_boons.has("qi_surge") else 1.0)
	hero_sp[active_hero_id] = minf(_get_hero_stat(active_hero_id, "max_sp"), hero_sp[active_hero_id] + sp_rate * delta)
	q_cd = maxf(0.0, q_cd - delta)
	e_cd = maxf(0.0, e_cd - delta)
	r_cd = maxf(0.0, r_cd - delta)
	dash_cooldown = maxf(0.0, dash_cooldown - delta)
	invuln_timer = maxf(0.0, invuln_timer - delta)
	pose_override_timer = maxf(0.0, pose_override_timer - delta)
	run_elapsed_time += delta
	if combat.combo_hits > run_max_combo_hits:
		run_max_combo_hits = combat.combo_hits
		run_max_combo_rank = str(combat.get_rank_data()["id"])
		if run_max_combo_rank == "SSS":
			_record_achievement("combo_sss", 1, true)
	if toast_timer > 0.0:
		toast_timer -= delta
		if toast_timer <= 0.0 and toast_panel:
			toast_panel.visible = false
	_update_interactive_tutorial(delta)

	last_skill_er_timer = maxf(0.0, last_skill_er_timer - delta)
	synergy_cd = maxf(0.0, synergy_cd - delta)
	if enemies.size() > 0:
		hazard_timer -= delta
		if hazard_timer <= 0.0:
			hazard_timer = 4.2 if current_room == 9 else 5.5
			_trigger_chapter_hazard()

	var nearest := _get_nearest_enemy(540.0)
	if nearest != null:
		target_reticle.visible = true
		target_reticle.position = nearest.global_position + Vector2(0, 6)
	else:
		target_reticle.visible = false

	if parallax_mist_layer:
		parallax_mist_layer.motion_offset.x += 14.0 * delta
		parallax_mist_layer.motion_offset.y = sin(run_elapsed_time * 0.55) * 8.0

	_process_ambient_world(delta)
	_handle_one_handed_actions()
	_process_camera_shake(delta)
	_process_projectiles(delta)
	_process_enemy_projectiles(delta)
	_process_telegraphs(delta)
	_process_sawblades(delta)
	_process_heal_orbs()
	_process_enemies(delta)
	_process_dying_corpses(delta)
	_check_room_progression()
	_refresh_hud()


func _physics_process(delta: float):
	if game_over or victory or hitstop_timer > 0.0 or _is_cutin_fullscreen() or (upgrade_overlay and upgrade_overlay.visible) or (help_overlay and help_overlay.visible) or (boon_overlay and boon_overlay.visible):
		return

	var move_vec := Vector2(
		float(Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT)) - float(Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT)),
		float(Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN)) - float(Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP))
	).normalized()

	if mobile_controls and mobile_controls.visible and mobile_controls.joy_vector.length() > 0.08:
		move_vec = mobile_controls.joy_vector

	var data: Dictionary = HeroData.HEROES[active_hero_id]
	if move_vec.length() <= 0.08 and auto_attack_enabled and mobile_controls and mobile_controls.visible:
		var nearest_e := _get_nearest_enemy(900.0)
		if nearest_e != null:
			var to_e := nearest_e.global_position - player.global_position
			var want_dist := 250.0 if bool(data["is_ranged"]) else maxf(85.0, float(data["range"]) * 0.78)
			if to_e.length() > want_dist:
				move_vec = to_e.normalized()
		elif enemies.size() == 0 and heal_orbs.size() > 0:
			for orb in heal_orbs:
				if is_instance_valid(orb):
					var to_o: Vector2 = orb.global_position - player.global_position
					if to_o.length() > 16.0:
						move_vec = to_o.normalized()
					break
		elif enemies.size() == 0 and heal_orbs.size() == 0 and current_room < _total_rooms() - 1:
			var target_x := (16.0 + float(current_room * ROOM_STRIDE)) * TILE_SIZE
			if player.global_position.x < target_x:
				var to_gate := Vector2(target_x, 4.5 * TILE_SIZE) - player.global_position
				if to_gate.length() > 10.0:
					move_vec = to_gate.normalized()

	if move_vec.length() > 0.1:
		facing_dir = move_vec.normalized()
		_update_walk_direction(move_vec)

	var aim_dir := _get_auto_aim_dir()
	var is_acting := attack_timer > 0.0 or pose_override_timer > 0.0
	var use_aim_face := pose_override_timer > 0.0 or (move_vec.length() <= 0.1 and (is_acting or _get_nearest_enemy(350.0) != null))
	var face_vec := aim_dir if use_aim_face else facing_dir
	if not (_has_4dir_sheet(active_hero_id) and walk_dir_key != "walk_side" and not is_acting):
		if face_vec.x < -0.05:
			player_sprite.flip_h = true
		elif face_vec.x > 0.05:
			player_sprite.flip_h = false

	var sp_now := Input.is_key_pressed(KEY_SPACE) or Input.is_key_pressed(KEY_SHIFT)
	var sp_trigger := (sp_now and not _prev_space) or _touch_dash_queued
	_touch_dash_queued = false
	if sp_trigger and dash_timer <= 0.0:
		if dash_cooldown > 0.0:
			_reject_skill_feedback(skill_dash_pill, "⏳ วิชาตัวเบา %.1fs" % dash_cooldown)
		else:
			_pulse_skill_pill(skill_dash_pill, true)
			dash_dir = move_vec.normalized() if move_vec.length() > 0.1 else facing_dir
			dash_timer = 0.18
			dash_cooldown = 0.80
			invuln_timer = 0.28
			combat.on_dash_started()
			sfx.play_sfx("dash")
			_spawn_ghost_afterimage()
			if _has_incoming_threat():
				_activate_perfect_dodge()
			if active_boons.has("thunder_dash"):
				_spawn_ring_vfx(player.global_position, Color("#38bdf8"), 150.0)
				for e in enemies:
					if is_instance_valid(e) and e.global_position.distance_to(player.global_position) <= 155.0:
						_damage_enemy(e, 45, (e.global_position - player.global_position).normalized(), Color("#38bdf8"), 0.2, true)
	_prev_space = sp_now

	if dash_timer > 0.0:
		dash_timer -= delta
		player.velocity = dash_dir * 820.0
		player.move_and_slide()
		if _has_4dir_sheet(active_hero_id):
			_set_player_strip(_get_hero_tex(active_hero_id, "walk_side", player_sprite.texture), 3, 2)
			if dash_dir.x < -0.05:
				player_sprite.flip_h = true
			elif dash_dir.x > 0.05:
				player_sprite.flip_h = false
		else:
			_set_player_strip(_get_hero_tex(active_hero_id, "dash", player_sprite.texture), 1, 0)
		if int(dash_timer * 60.0) % 3 == 0:
			_spawn_ghost_afterimage()
		_update_fake_z_height(delta)
		return

	var f_now := Input.is_key_pressed(KEY_F)
	var f_just := (f_now and not _prev_f) or _touch_attack_queued
	_touch_attack_queued = false
	_prev_f = f_now

	var auto_trigger := false
	if auto_attack_enabled:
		var nearest := _get_nearest_enemy(float(data["range"]) + 20.0)
		if nearest != null:
			auto_trigger = true

	if (f_just or auto_trigger) and attack_timer <= 0.0 and pose_override_timer <= 0.0:
		_perform_basic_attack(aim_dir)

	if pose_override_timer > 0.0:
		if _has_4dir_sheet(active_hero_id):
			var sk_tex := _get_hero_tex(active_hero_id, "skill_4f", player_sprite.texture)
			if pose_override_key == "ultimate" or pose_override_key == "special":
				_set_player_strip(sk_tex, 4, 2)
			else:
				var dur := maxf(pose_override_duration, 0.08)
				var sk_frame := clampi(int(((dur - pose_override_timer) / dur) * 4.0), 0, 3)
				_set_player_strip(sk_tex, 4, sk_frame)
		else:
			_set_player_strip(_get_hero_tex(active_hero_id, pose_override_key, player_sprite.texture), 1, 0)
		player.velocity = move_vec * data["speed"] * 0.25
		player.move_and_slide()
		_update_fake_z_height(delta)
		return

	if attack_timer > 0.0:
		attack_timer -= delta
		if _has_4dir_sheet(active_hero_id):
			var adur := maxf(attack_anim_duration, 0.08)
			var aframe := clampi(int(((adur - maxf(0.0, attack_timer)) / adur) * 4.0), 0, 3)
			_set_player_strip(_get_hero_tex(active_hero_id, "attack_4f", player_sprite.texture), 4, aframe)
		else:
			var frame_idx := clampi(int((0.28 - attack_timer) / 0.09), 0, 2)
			_set_player_strip(_get_hero_tex(active_hero_id, "strike_%d" % frame_idx, player_sprite.texture), 1, 0)
		player.velocity = move_vec * data["speed"] * 0.45
		player.move_and_slide()
		_update_fake_z_height(delta)
		return

	var target_vel := move_vec * float(data["speed"])
	var accel := 2400.0 if move_vec.length() > 0.1 else 2800.0
	player.velocity = player.velocity.move_toward(target_vel, accel * delta)
	player.move_and_slide()

	var speed_now := player.velocity.length()
	var actively_walking := (move_vec.length() > 0.08 and speed_now >= 14.0) or speed_now >= 65.0
	if actively_walking:
		if not walk_was_moving:
			# Immediately enter a contact stride on the first frame of motion so feet never slide in idle pose.
			walk_step = walk_next_lead
			walk_next_lead = 2 if walk_next_lead == 0 else 0
			walk_dist_accum = 0.0
			walk_was_moving = true
		else:
			# Advance walk phases strictly by world distance covered (~28 px per quarter-cycle at 0.42x scale).
			walk_dist_accum += speed_now * delta
			const WALK_PHASE_DIST := 28.0
			while walk_dist_accum >= WALK_PHASE_DIST:
				walk_dist_accum -= WALK_PHASE_DIST
				walk_step = (walk_step + 1) % 4
		var seq: int = [0, 1, 2, 1][walk_step]
		if _has_4dir_sheet(active_hero_id):
			_set_player_strip(_get_hero_tex(active_hero_id, walk_dir_key, player_sprite.texture), 3, seq)
		else:
			_set_player_strip(_get_hero_tex(active_hero_id, "stride_%d" % seq, player_sprite.texture), 1, 0)
	else:
		walk_was_moving = false
		walk_dist_accum = 0.0
		walk_timer = 0.0
		if _has_4dir_sheet(active_hero_id):
			_set_player_strip(_get_hero_tex(active_hero_id, walk_dir_key, player_sprite.texture), 3, 1)
		else:
			_set_player_strip(_get_hero_tex(active_hero_id, "stride_0", player_sprite.texture), 1, 0)
	_update_fake_z_height(delta)


func _spawn_footstep_dust():
	if not is_instance_valid(floor_layer) or not is_instance_valid(player):
		return
	var puff := Polygon2D.new()
	puff.polygon = _make_ellipse(7.5, 4.0, 10)
	puff.color = Color(0.72, 0.78, 0.84, 0.34)
	puff.position = player.global_position + Vector2(randf_range(-5.0, 5.0), 6.0)
	puff.z_index = 2
	floor_layer.add_child(puff)
	var drift := -player.velocity.normalized() * 14.0 + Vector2(0.0, -5.0)
	var tw := create_tween()
	tw.tween_property(puff, "position", puff.position + drift, 0.28).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(puff, "scale", Vector2(1.75, 1.55), 0.28)
	tw.parallel().tween_property(puff, "modulate:a", 0.0, 0.28)
	tw.tween_callback(puff.queue_free)


func _update_fake_z_height(delta: float):
	var target_z := 0.0
	var is_moving := is_instance_valid(player) and player.velocity.length() > 20.0 and dash_timer <= 0.0 and attack_timer <= 0.0 and pose_override_timer <= 0.0
	if dash_timer > 0.0:
		target_z = 22.0
	elif pose_override_timer > 0.0:
		if pose_override_key == "ultimate":
			target_z = 32.0
		elif pose_override_key == "skill_2" or pose_override_key == "special":
			target_z = 22.0
		else:
			target_z = 12.0
	elif attack_timer > 0.0:
		var prog := clampf((0.28 - attack_timer) / 0.28, 0.0, 1.0)
		target_z = sin(prog * PI) * 8.0
	elif is_moving:
		walk_cycle_phase += delta * 10.5
		target_z = 0.0 # Keep the planted foot on the floor during the walk cycle.
		footstep_dust_timer += delta
		if footstep_dust_timer >= 0.20:
			footstep_dust_timer = 0.0
			_spawn_footstep_dust()
	else:
		idle_breath_phase += delta * 3.0
		footstep_dust_timer = 0.14

	player_z_height = lerpf(player_z_height, target_z, minf(1.0, delta * 24.0))
	if player_sprite:
		player_sprite.offset = Vector2(HERO_OFFSET.x, HERO_OFFSET.y - player_z_height)
		if is_moving:
			# Sprite frames provide the gait; scaling/tilting around the centre slides feet.
			player_sprite.scale = player_sprite.scale.lerp(HERO_SCALE, minf(1.0, delta * 20.0))
			player_sprite.rotation = lerpf(player_sprite.rotation, 0.0, minf(1.0, delta * 18.0))
		else:
			var br := sin(idle_breath_phase)
			var target_sc := HERO_SCALE * Vector2(1.0 - br * 0.015, 1.0 + br * 0.022)
			player_sprite.scale = player_sprite.scale.lerp(target_sc, minf(1.0, delta * 14.0))
			player_sprite.rotation = lerpf(player_sprite.rotation, 0.0, minf(1.0, delta * 18.0))

	if is_instance_valid(camera):
		var target_ahead := Vector2(facing_dir.x * (36.0 if is_moving else 12.0), facing_dir.y * (14.0 if is_moving else 5.0))
		cam_look_ahead = cam_look_ahead.lerp(target_ahead, minf(1.0, delta * 3.5))
		camera.position = cam_look_ahead

	if player_shadow:
		var sc := clampf(1.0 - (player_z_height / 95.0), 0.62, 1.0)
		player_shadow.scale = Vector2(sc, sc)
		player_shadow.color.a = clampf(0.55 * (1.0 - player_z_height / 75.0), 0.20, 0.55)


func _handle_one_handed_actions():
	var k1 := Input.is_key_pressed(KEY_1)
	var k2 := Input.is_key_pressed(KEY_2)
	var k3 := Input.is_key_pressed(KEY_3)
	if k1 and not _prev_1 and active_party.size() >= 1 and active_hero_id != active_party[0]:
		_switch_hero(active_party[0], true)
	elif k2 and not _prev_2 and active_party.size() >= 2 and active_hero_id != active_party[1]:
		_switch_hero(active_party[1], true)
	elif k3 and not _prev_3 and active_party.size() >= 3 and active_hero_id != active_party[2]:
		_switch_hero(active_party[2], true)
	elif Input.is_action_just_pressed("ui_focus_next") and active_party.size() > 0:
		var idx := (active_party.find(active_hero_id) + 1) % active_party.size()
		_switch_hero(active_party[idx], true)
	_prev_1 = k1
	_prev_2 = k2
	_prev_3 = k3

	var kc := Input.is_key_pressed(KEY_C)
	if kc and not _prev_c:
		_toggle_auto_attack()
	_prev_c = kc

	var kq := Input.is_key_pressed(KEY_Q)
	var ke := Input.is_key_pressed(KEY_E)
	var kr := Input.is_key_pressed(KEY_R)
	var aim := _get_auto_aim_dir()
	if kq and not _prev_q:
		_cast_skill_q(aim)
	if ke and not _prev_e:
		_cast_skill_e()
	if kr and not _prev_r:
		_cast_skill_r()
	_prev_q = kq
	_prev_e = ke
	_prev_r = kr


func _perform_basic_attack(aim_dir: Vector2):
	_pulse_skill_pill(skill_auto_pill, true)
	attack_anim_duration = 0.32 if _has_4dir_sheet(active_hero_id) else 0.28
	attack_timer = attack_anim_duration
	if _has_4dir_sheet(active_hero_id):
		if aim_dir.x < -0.05:
			player_sprite.flip_h = true
		elif aim_dir.x > 0.05:
			player_sprite.flip_h = false
		_set_player_strip(_get_hero_tex(active_hero_id, "attack_4f", player_sprite.texture), 4, 0)
	var data: Dictionary = HeroData.HEROES[active_hero_id]
	var atk := int(_get_hero_stat(active_hero_id, "atk"))
	var eff_crit := _get_hero_stat(active_hero_id, "crit")
	if data["is_ranged"]:
		sfx.play_sfx("talisman")
		VfxStudio.spawn_critical_star_burst(fx_layer, player.global_position + aim_dir * 32.0, data["color"], 0.45)
		_spawn_projectile(player.global_position + aim_dir * 26.0, aim_dir, atk, data["vfx_attack"], data["color"], 660.0, false, eff_crit)
	else:
		sfx.play_sfx("slash")
		VfxStudio.spawn_azure_star_slash(fx_layer, player.global_position + aim_dir * 28.0, aim_dir.angle(), data["color"], 0.92)
		_spawn_slash_vfx(player.global_position + aim_dir * 52.0, aim_dir.angle(), data["vfx_attack"], data["color"])
		var hit_any := false
		for e in enemies:
			if not is_instance_valid(e):
				continue
			var to_e: Vector2 = e.global_position - player.global_position
			if to_e.length() <= data["range"] and to_e.normalized().dot(aim_dir) > 0.05:
				_damage_enemy(e, atk, aim_dir, data["color"], eff_crit, false)
				hit_any = true
		if hit_any:
			shake_strength = 5.5


func _cast_skill_q(aim_dir: Vector2):
	var data: Dictionary = HeroData.HEROES[active_hero_id]
	if q_cd > 0.0:
		_reject_skill_feedback(skill_q_pill, "⏳ ติดคูลดาวน์ %.1fs!" % q_cd)
		return
	if hero_sp[active_hero_id] < data["q_cost"]:
		_reject_skill_feedback(skill_q_pill, "💧 ปราณไม่พอ! (%d/%d)" % [int(hero_sp[active_hero_id]), int(data["q_cost"])])
		return
	_pulse_skill_pill(skill_q_pill, true)
	hero_sp[active_hero_id] -= data["q_cost"]
	var cdr_mult := clampf(1.0 - _get_hero_stat(active_hero_id, "cd_red"), 0.50, 1.0)
	q_cd = 3.0 * (0.80 if active_boons.has("swift_qi") else 1.0) * cdr_mult
	var atk := _get_hero_stat(active_hero_id, "atk")
	var eff_crit := _get_hero_stat(active_hero_id, "crit")
	pose_override_key = "skill_4f" if _has_4dir_sheet(active_hero_id) else "skill_1"
	pose_override_duration = 0.32 if _has_4dir_sheet(active_hero_id) else 0.28
	pose_override_timer = pose_override_duration
	if _has_4dir_sheet(active_hero_id):
		if aim_dir.x < -0.05:
			player_sprite.flip_h = true
		elif aim_dir.x > 0.05:
			player_sprite.flip_h = false
		_set_player_strip(_get_hero_tex(active_hero_id, "skill_4f", player_sprite.texture), 4, 0)
	shake_strength = 7.0
	sfx.play_sfx("skill_q")
	_show_banner("✨ %s!" % data["q_name"], 1.0)
	VfxStudio.spawn_azure_star_slash(fx_layer, player.global_position + aim_dir * 36.0, aim_dir.angle(), data["color"], 1.25)

	if active_hero_id == "bai_yueling":
		VfxStudio.spawn_ice_crescent_wave(fx_layer, player.global_position + aim_dir * 32.0, aim_dir.angle(), data["color"])
		for ang in [-0.28, 0.0, 0.28]:
			var d := aim_dir.rotated(ang)
			_spawn_projectile(player.global_position + d * 28.0, d, int(atk * 1.35), data["vfx_attack"], data["color"], 720.0, true, eff_crit)
	elif active_hero_id == "ye_shangye":
		VfxStudio.spawn_demon_chain_lash(fx_layer, player.global_position + aim_dir * 42.0, aim_dir.angle(), data["color"])
		_spawn_slash_vfx(player.global_position + aim_dir * 75.0, aim_dir.angle(), data["vfx_attack"], data["color"], 1.55)
		for e in enemies:
			if not is_instance_valid(e):
				continue
			if e.global_position.distance_to(player.global_position) <= 240.0:
				var pull_pos := player.global_position + aim_dir * 68.0
				var tw := create_tween()
				tw.tween_property(e, "global_position", pull_pos, 0.16)
				_damage_enemy(e, int(atk * 1.45), aim_dir, data["color"], maxf(0.30, eff_crit), true)
				e.set_meta("stun", 0.85)
	elif active_hero_id == "song_ren":
		VfxStudio.spawn_talisman_lightning_burst(fx_layer, player.global_position + aim_dir * 30.0, aim_dir.angle(), data["color"])
		for ang in [-0.40, -0.20, 0.0, 0.20, 0.40]:
			var d := aim_dir.rotated(ang)
			_spawn_projectile(player.global_position + d * 28.0, d, int(atk * 1.15), data["vfx_attack"], data["color"], 700.0, true, eff_crit)
	else:
		var reach := 235.0 if active_hero_id == "yu_han" else 220.0
		if active_hero_id == "hei_shan":
			VfxStudio.spawn_crimson_ribbon_needles(fx_layer, player.global_position + aim_dir * 28.0, aim_dir.angle(), data["color"])
		elif active_hero_id == "chen_xi":
			VfxStudio.spawn_ink_shadow_cleave(fx_layer, player.global_position + aim_dir * 42.0, aim_dir.angle(), data["color"])
		elif active_hero_id == "yu_han":
			VfxStudio.spawn_thunder_spear_thrust(fx_layer, player.global_position + aim_dir * 34.0, aim_dir.angle(), data["color"])
		elif active_hero_id == "zhao_yan":
			VfxStudio.spawn_alchemy_soul_bolt(fx_layer, player.global_position + aim_dir * 30.0, aim_dir.angle(), data["color"])
		else:
			_spawn_slash_vfx(player.global_position + aim_dir * 65.0, aim_dir.angle(), data["vfx_attack"], data["color"], 1.35)
		for e in enemies:
			if is_instance_valid(e) and e.global_position.distance_to(player.global_position) <= reach:
				_damage_enemy(e, int(atk * 1.40), aim_dir, data["color"], _get_hero_stat(active_hero_id, "crit"), true)


func _cast_skill_e():
	var data: Dictionary = HeroData.HEROES[active_hero_id]
	if e_cd > 0.0:
		_reject_skill_feedback(skill_e_pill, "⏳ ติดคูลดาวน์ %.1fs!" % e_cd)
		return
	if hero_sp[active_hero_id] < data["e_cost"]:
		_reject_skill_feedback(skill_e_pill, "💧 ปราณไม่พอ! (%d/%d)" % [int(hero_sp[active_hero_id]), int(data["e_cost"])])
		return
	_pulse_skill_pill(skill_e_pill, true)
	hero_sp[active_hero_id] -= data["e_cost"]
	var cdr_mult_e := clampf(1.0 - _get_hero_stat(active_hero_id, "cd_red"), 0.50, 1.0)
	e_cd = 6.0 * (0.80 if active_boons.has("swift_qi") else 1.0) * cdr_mult_e
	last_skill_er_timer = 2.5
	var atk := _get_hero_stat(active_hero_id, "atk")
	pose_override_key = "skill_4f" if _has_4dir_sheet(active_hero_id) else "skill_2"
	pose_override_duration = 0.36
	pose_override_timer = pose_override_duration
	if _has_4dir_sheet(active_hero_id):
		_set_player_strip(_get_hero_tex(active_hero_id, "skill_4f", player_sprite.texture), 4, 0)
	shake_strength = 12.0
	sfx.play_sfx("skill_e")
	_show_banner("🔥 %s! (สลับตัว [1/2/3/Tab] เพื่อผสานปราณ!)" % data["e_name"], 1.4)
	_spawn_ring_vfx(player.global_position, data["color"], 210.0)
	VfxStudio.spawn_frostbound_eruption(floor_layer, fx_layer, player.global_position, data["color"])
	VfxStudio.spawn_galaxy_vortex(floor_layer, player.global_position, data["color"], 185.0)
	if active_hero_id == "bai_yueling":
		VfxStudio.spawn_ice_lotus_and_sword_halo(floor_layer, fx_layer, player.global_position, data["color"])
	elif active_hero_id == "song_ren":
		VfxStudio.spawn_bagua_binding_array(floor_layer, fx_layer, player.global_position, data["color"])
	elif active_hero_id == "hei_shan":
		VfxStudio.spawn_golden_vine_sanctuary(floor_layer, fx_layer, player.global_position, data["color"])
	elif active_hero_id == "ye_shangye":
		VfxStudio.spawn_hellfire_wave_eruption(floor_layer, fx_layer, player.global_position, data["color"])
	elif active_hero_id == "chen_xi":
		VfxStudio.spawn_blood_qi_ignition(floor_layer, fx_layer, player.global_position, data["color"])
	elif active_hero_id == "yu_han":
		VfxStudio.spawn_solar_thunder_ring(floor_layer, fx_layer, player.global_position, data["color"])
	elif active_hero_id == "zhao_yan":
		VfxStudio.spawn_soul_siphon_cauldron_ring(floor_layer, fx_layer, player.global_position, data["color"])

	for i in range(6):
		var ang := (float(i) / 6.0) * TAU
		var p := player.global_position + Vector2(cos(ang), sin(ang)) * 115.0
		_spawn_burst_vfx(p, data["vfx_burst"], 0.42)

	if active_hero_id == "song_ren":
		_spawn_domain_vfx(player.global_position, data["vfx_domain"], 1.35)
		for hid in active_party:
			if hero_hp[hid] > 0:
				hero_hp[hid] = minf(_get_hero_stat(hid, "max_hp"), hero_hp[hid] + 45.0)
		_spawn_floating_text(player.global_position + Vector2(0, -52), "+45 HP ทีม!", Color("#4ade80"), true)

	var e_hit := false
	for e in enemies.duplicate():
		if not is_instance_valid(e):
			continue
		if e.global_position.distance_to(player.global_position) <= 220.0:
			e_hit = true
			var push: Vector2 = (e.global_position - player.global_position).normalized()
			_damage_enemy(e, int(atk * 2.3), push, data["color"], 0.45, true)
			e.set_meta("stun", 1.7)
			if active_hero_id == "ye_shangye":
				hero_hp[active_hero_id] = minf(_get_hero_stat(active_hero_id, "max_hp"), hero_hp[active_hero_id] + 15.0)

	if e_hit:
		if active_hero_id == "zhao_yan":
			var heal_self := 32.0 if int(save_data.get("hero_passives", {}).get("zhao_yan", 0)) > 0 else 24.0
			hero_hp[active_hero_id] = minf(_get_hero_stat(active_hero_id, "max_hp"), hero_hp[active_hero_id] + heal_self)
			_spawn_floating_text(player.global_position + Vector2(0, -52), "+%d HP จ้าว!" % int(heal_self), Color("#4ade80"), true)
		elif active_hero_id == "hei_shan":
			var heal_ally := 22.0 if int(save_data.get("hero_passives", {}).get("hei_shan", 0)) > 0 else 16.0
			var healed_any := false
			for hid in active_party:
				if hid != active_hero_id and hero_hp[hid] > 0.0:
					hero_hp[hid] = minf(_get_hero_stat(hid, "max_hp"), hero_hp[hid] + heal_ally)
					healed_any = true
			if healed_any:
				_spawn_floating_text(player.global_position + Vector2(0, -52), "+%d HP สำรอง!" % int(heal_ally), Color("#f472b6"), true)


func _cast_skill_r():
	var data: Dictionary = HeroData.HEROES[active_hero_id]
	if pending_ult_hero != "":
		return
	if r_cd > 0.0:
		_reject_skill_feedback(skill_r_pill, "⏳ ติดคูลดาวน์ %.1fs!" % r_cd)
		return
	if hero_sp[active_hero_id] < data["r_cost"]:
		_reject_skill_feedback(skill_r_pill, "💧 ปราณไม่พอ! (%d/%d)" % [int(hero_sp[active_hero_id]), int(data["r_cost"])])
		return
	_pulse_skill_pill(skill_r_pill, true)
	hero_sp[active_hero_id] -= data["r_cost"]
	var cdr_mult_r := clampf(1.0 - _get_hero_stat(active_hero_id, "cd_red"), 0.50, 1.0)
	r_cd = 12.0 * (0.80 if active_boons.has("swift_qi") else 1.0) * cdr_mult_r

	var mode := _get_cutin_mode()
	var has_clip: bool = cutin_overlay != null and cutin_overlay.has_cutin(active_hero_id)
	if has_clip and _should_play_fullscreen_cutin(mode):
		if cutin_overlay.play(active_hero_id, true):
			# Combat is frozen (see _is_cutin_fullscreen in _process); damage is
			# released by _on_cutin_fullscreen_finished so the clip lands the hit.
			pending_ult_hero = active_hero_id
			sfx.set_bgm_ducked(true)
			invuln_timer = maxf(invuln_timer, 1.0)
			Engine.time_scale = 1.0
			if mobile_controls:
				mobile_controls.set_active(false)
			return

	_release_ultimate(data)
	if has_clip and mode != "skip":
		if cutin_overlay.play(active_hero_id, false) and hitstop_timer <= 0.0:
			Engine.time_scale = minf(Engine.time_scale, cutin_overlay.get_slowmo_scale())


func _release_ultimate(data: Dictionary):
	last_skill_er_timer = 2.5
	pose_override_key = "ultimate"
	pose_override_timer = 0.55
	invuln_timer = 1.0
	shake_strength = 18.0
	sfx.play_sfx("ultimate")
	_show_banner("⚡ ท่าไม้ตาย: %s!" % data["r_name"], 2.0)

	var col: Color = data["color"]
	screen_flash.color = Color(col.r, col.g, col.b, 0.38)
	var ftw := create_tween()
	ftw.tween_property(screen_flash, "color:a", 0.0, 0.45)

	var ztw := create_tween()
	ztw.tween_property(camera, "zoom", Vector2(1.28, 1.28), 0.14)
	ztw.tween_property(camera, "zoom", Vector2(1.15, 1.15), 0.40)

	VfxStudio.spawn_summoning_pillar(floor_layer, fx_layer, player.global_position, col)
	_spawn_domain_vfx(player.global_position, data["vfx_domain"], 1.65)
	_spawn_ring_vfx(player.global_position, col, 280.0)
	if active_hero_id == "bai_yueling":
		VfxStudio.spawn_myriad_ice_domain(floor_layer, fx_layer, player.global_position, col)
	elif active_hero_id == "song_ren":
		VfxStudio.spawn_heavenly_bagua_dome(floor_layer, fx_layer, player.global_position, col)
	elif active_hero_id == "hei_shan":
		VfxStudio.spawn_ninetail_blossom_domain(floor_layer, fx_layer, player.global_position, col)
	elif active_hero_id == "ye_shangye":
		VfxStudio.spawn_demon_king_chain_abyss(floor_layer, fx_layer, player.global_position, col)
	elif active_hero_id == "chen_xi":
		VfxStudio.spawn_heaven_severing_blood_slash(floor_layer, fx_layer, player.global_position, col)
	elif active_hero_id == "yu_han":
		VfxStudio.spawn_nine_heavens_spear_judgment(floor_layer, fx_layer, player.global_position, col)
	elif active_hero_id == "zhao_yan":
		VfxStudio.spawn_primordial_cauldron_nova(floor_layer, fx_layer, player.global_position, col)

	var targets := enemies.duplicate()
	for i in range(12):
		var drop_pos: Vector2
		if targets.size() > 0 and is_instance_valid(targets[i % targets.size()]):
			drop_pos = targets[i % targets.size()].global_position + Vector2(randf_range(-28, 28), randf_range(-18, 18))
		else:
			drop_pos = player.global_position + Vector2(randf_range(-220, 220), randf_range(-140, 140))

		var dtw := create_tween()
		dtw.tween_interval(0.05 * i)
		dtw.tween_callback(_trigger_ultimate_impact.bind(drop_pos, data))


func _trigger_ultimate_impact(pos: Vector2, data: Dictionary):
	if game_over or victory:
		return
	var col: Color = data["color"]
	var atk := _get_hero_stat(active_hero_id, "atk")
	VfxStudio.spawn_sky_sword_drop(fx_layer, pos, col)
	_spawn_burst_vfx(pos, data["vfx_burst"], 0.55)
	if active_hero_id == "bai_yueling":
		_spawn_slash_vfx(pos, PI * 0.5, data["vfx_attack"], col, 1.05)
	_spawn_ring_vfx(pos, col, 85.0)
	shake_strength = maxf(shake_strength, 8.5)

	for e in enemies.duplicate():
		if not is_instance_valid(e):
			continue
		if e.global_position.distance_to(pos) <= 130.0:
			var push: Vector2 = (e.global_position - pos).normalized()
			_damage_enemy(e, int(atk * 1.4), push, col, 0.65, true)
			e.set_meta("stun", 1.2)
			if active_hero_id == "ye_shangye":
				var steal := 12.0 if int(save_data.get("hero_passives", {}).get("ye_shangye", 0)) > 0 else 8.0
				hero_hp[active_hero_id] = minf(_get_hero_stat(active_hero_id, "max_hp"), hero_hp[active_hero_id] + steal)
			elif active_hero_id == "zhao_yan":
				hero_hp[active_hero_id] = minf(_get_hero_stat(active_hero_id, "max_hp"), hero_hp[active_hero_id] + 10.0)
			elif active_hero_id == "hei_shan":
				for hid in active_party:
					if hid != active_hero_id and hero_hp[hid] > 0.0:
						hero_hp[hid] = minf(_get_hero_stat(hid, "max_hp"), hero_hp[hid] + 8.0)


func _has_incoming_threat() -> bool:
	if not is_instance_valid(player):
		return false
	var ppos := player.global_position
	for ep in enemy_projectiles:
		if is_instance_valid(ep) and ep.global_position.distance_to(ppos) <= CombatSystem.PERFECT_DODGE_PROJ_RADIUS:
			return true
	for t in active_telegraphs:
		if ppos.distance_to(t["pos"]) <= float(t["radius"]) + 18.0:
			return true
	for e in enemies.duplicate():
		if not is_instance_valid(e):
			continue
		if float(e.get_meta("stun", 0.0)) > 0.0:
			continue
		if float(e.get_meta("windup_timer", 0.0)) > 0.0:
			return true
		var def: Dictionary = MONSTER_DEFS[str(e.get_meta("kind"))]
		if e.global_position.distance_to(ppos) <= float(def["range"]) + CombatSystem.PERFECT_DODGE_THREAT_PAD:
			return true
	return false


func _activate_perfect_dodge() -> bool:
	if not combat.trigger_perfect_dodge():
		return false
	run_perfect_dodges += 1
	_record_achievement("dodge_5", 1)
	_record_achievement("dodge_25", 1)
	if tutorial_step == 1:
		_advance_tutorial(2)
	invuln_timer = maxf(invuln_timer, 0.55)
	hero_sp[active_hero_id] = minf(_get_hero_stat(active_hero_id, "max_sp"), hero_sp[active_hero_id] + CombatSystem.PERFECT_DODGE_SP_GAIN)
	Engine.time_scale = combat.get_desired_time_scale(hitstop_timer)
	sfx.play_sfx("perfect_dodge")
	_spawn_ring_vfx(player.global_position, Color("#fde047"), 140.0)
	_spawn_floating_text(player.global_position + Vector2(0, -84), "⚡ หลบพริบตา! +30 ปราณ", Color("#fde047"), true)
	if screen_flash:
		screen_flash.color = Color(1.0, 0.85, 0.25, 0.18)
		var ftw := create_tween()
		ftw.tween_property(screen_flash, "color:a", 0.0, 0.24)
	_refresh_hud()
	return true


func _damage_enemy(e: CharacterBody2D, base_dmg: int, push_dir: Vector2, col: Color, crit_chance: float, is_skill: bool = false, allow_reaction: bool = true):
	if not is_instance_valid(e):
		return
	var kind: String = e.get_meta("kind")
	var def: Dictionary = MONSTER_DEFS[kind]
	var shield: float = float(e.get_meta("shield", 0.0))

	if shield > 0.0:
		if not is_skill:
			_spawn_floating_text(e.global_position + Vector2(0, -64), "🛡️ เกราะสะท้อน! ใช้ [E]/[R]", Color("#38bdf8"), false)
			sfx.play_sfx("hit")
			_enemy_hit_player(6, e.global_position, false)
			return
		var sh_dmg := float(base_dmg) * 1.8
		shield = maxf(0.0, shield - sh_dmg)
		e.set_meta("shield", shield)
		e.set_meta("flash", 0.14)
		if e.has_node("ShieldBg/ShieldFg"):
			var sfg: ColorRect = e.get_node("ShieldBg/ShieldFg")
			sfg.size.x = 54.0 * clampf(shield / float(e.get_meta("max_shield", 1.0)), 0.0, 1.0)
		if shield <= 0.0:
			sfx.play_sfx("shield_break")
			_spawn_ring_vfx(e.global_position, Color("#38bdf8"), 85.0)
			_spawn_floating_text(e.global_position + Vector2(0, -76), "💥 เกราะแตก!", Color("#fde047"), true)
			if e.has_node("ShieldBg"):
				e.get_node("ShieldBg").visible = false
			if e.has_node("ShieldAura"):
				e.get_node("ShieldAura").visible = false
		else:
			sfx.play_sfx("crit")
			_spawn_floating_text(e.global_position + Vector2(0, -64), "🛡️ -%d" % int(sh_dmg), Color("#38bdf8"), false)
		return

	base_dmg = int(round(float(base_dmg) * combat.get_damage_multiplier() * (1.15 if active_boons.has("frost_bite") else 1.0)))
	if active_boons.has("frost_bite"):
		e.set_meta("slow_timer", 1.2)
	if float(e.get_meta("vuln_timer", 0.0)) > 0.0:
		base_dmg = int(round(float(base_dmg) * 1.25))
	if float(e.get_meta("quicken_timer", 0.0)) > 0.0:
		crit_chance = minf(1.0, crit_chance + 0.30)

	if allow_reaction:
		var hero_elem := CombatSystem.get_hero_element(active_hero_id)
		var existing_elem: String = str(e.get_meta("elem_mark", ""))
		var existing_timer: float = float(e.get_meta("elem_timer", 0.0))
		if existing_elem != "" and existing_timer > 0.0 and existing_elem != hero_elem:
			var react := CombatSystem.lookup_reaction(existing_elem, hero_elem)
			if not react.is_empty() and active_boons.has("elemental_mastery"):
				react = react.duplicate()
				react["bonus_dmg"] = int(round(float(react["bonus_dmg"]) * 1.35))
			if not react.is_empty():
				e.set_meta("elem_mark", "")
				e.set_meta("elem_timer", 0.0)
				if e.has_node("MarkLabel"):
					e.get_node("MarkLabel").text = ""
				combat.reaction_count += 1
				run_reactions += 1
				_record_achievement("reaction_10", 1)
				_record_achievement("reaction_50", 1)
				if tutorial_step == 3:
					_complete_interactive_tutorial()
				combat.add_combo(25.0, false)
				var passive_mult := 1.25 if int(save_data.get("hero_passives", {}).get("ye_shangye", 0)) > 0 else 1.0
				var r_col: Color = react["color"]
				base_dmg = int(round(float(base_dmg) * float(react.get("dmg_mult", 1.0)) * passive_mult))
				sfx.play_sfx("reaction")
				_spawn_ring_vfx(e.global_position, r_col, 115.0)
				_spawn_floating_text(e.global_position + Vector2(0, -82), "%s %s!" % [react["icon"], react["name"]], r_col, true)
				_award_spirit_jade(4)

				var r_id: String = str(react["id"])
				var hero_atk := _get_hero_stat(active_hero_id, "atk")
				if r_id == "overload":
					e.set_meta("stun", maxf(float(e.get_meta("stun", 0.0)), float(react["stun"])))
					var aoe_dmg := int(hero_atk * float(react["aoe_mult"]) * passive_mult)
					for other in enemies.duplicate():
						if is_instance_valid(other) and other != e and other.global_position.distance_to(e.global_position) <= float(react["aoe_radius"]):
							var opush: Vector2 = (other.global_position - e.global_position).normalized()
							other.set_meta("stun", maxf(float(other.get_meta("stun", 0.0)), float(react["stun"])))
							_damage_enemy(other, aoe_dmg, opush, r_col, 0.2, true, false)
				elif r_id == "superconduct":
					e.set_meta("vuln_timer", float(react["vuln_duration"]))
					var aoe_dmg := int(hero_atk * float(react["aoe_mult"]) * passive_mult)
					for other in enemies.duplicate():
						if is_instance_valid(other) and other != e and other.global_position.distance_to(e.global_position) <= float(react["aoe_radius"]):
							other.set_meta("vuln_timer", float(react["vuln_duration"]))
							var opush: Vector2 = (other.global_position - e.global_position).normalized()
							_damage_enemy(other, aoe_dmg, opush, r_col, 0.2, true, false)
				elif r_id == "burning":
					e.set_meta("burn_timer", float(react["burn_duration"]))
					e.set_meta("burn_tick", 0.5)
					e.set_meta("burn_dmg", maxi(8, int(hero_atk * 0.35 * passive_mult)))
				elif r_id == "quicken":
					e.set_meta("quicken_timer", float(react["quicken_duration"]))
				elif r_id == "frostbind":
					e.set_meta("frostbind_timer", float(react["frostbind_duration"]))
		elif is_skill:
			e.set_meta("elem_mark", hero_elem)
			e.set_meta("elem_timer", CombatSystem.ELEMENT_MARK_DURATION)
			if tutorial_step == 2:
				_advance_tutorial(3)
			if e.has_node("MarkLabel"):
				var einfo := CombatSystem.get_element_info(hero_elem)
				var ml: Label = e.get_node("MarkLabel")
				ml.text = str(einfo["icon"])
				ml.add_theme_color_override("font_color", einfo["color"])

	var counter_crit: bool = allow_reaction and combat.consume_perfect_dodge_crit()
	var vuln_open_now: float = float(e.get_meta("vuln_open", 0.0))
	var is_crit := counter_crit or (randf() < crit_chance)
	var crit_mult := 2.15 if (active_hero_id == "bai_yueling" and int(save_data.get("hero_passives", {}).get("bai_yueling", 0)) > 0) else 1.80
	if counter_crit:
		crit_mult = maxf(crit_mult, CombatSystem.PERFECT_DODGE_CRIT_MULT)
		_spawn_floating_text(e.global_position + Vector2(0, -104), "★ สวนกลับพริบตา!", Color("#fde047"), true)
	if vuln_open_now > 0.0:
		base_dmg = int(round(float(base_dmg) * 1.25))
	var dmg := int(base_dmg * (crit_mult if is_crit else 1.0))
	var active_gear := EquipData.get_bonuses_for_hero(save_data.get("hero_gear", {}), active_hero_id, save_data.get("gear_levels", {}))
	if allow_reaction:
		combat.add_combo(12.0 if is_skill else 6.0, true)
		attack_hit_counter += 1
		var l_proc := float(active_gear.get("lightning_proc", 0.0))
		if l_proc > 0.0 and attack_hit_counter % 5 == 0:
			var bolt := int(round(_get_hero_stat(active_hero_id, "atk") * l_proc))
			dmg += bolt
			_spawn_ring_vfx(e.global_position, Color("#fde047"), 65.0)
	run_hero_damage[active_hero_id] = int(run_hero_damage.get(active_hero_id, 0)) + dmg
	var hp: float = e.get_meta("hp") - dmg
	e.set_meta("hp", hp)
	e.set_meta("flash", 0.12)
	if hp > 0.0:
		# Trigger Hurt recoil pose; heavy skills/crits also interrupt normal mob windups
		if not def["is_boss"] or float(e.get_meta("casting", 0.0)) <= 0.0:
			e.set_meta("hurt_timer", 0.16 if def["is_boss"] else 0.20)
		if not def["is_boss"] and (is_skill or is_crit) and float(e.get_meta("windup_timer", 0.0)) > 0.0:
			e.set_meta("windup_timer", 0.0)
			e.set_meta("recovery_timer", 0.35)
			var wc: Polygon2D = e.get_node_or_null("SlashCone")
			if wc:
				wc.visible = false
			var wr: Line2D = e.get_node_or_null("WindupRing")
			if wr:
				wr.visible = false
			var wl: Label = e.get_node_or_null("WindupLabel")
			if wl:
				wl.visible = false
	if e.has_node("Sprite"):
		var esp: Sprite2D = e.get_node("Sprite")
		var base_sc: Vector2 = e.get_meta("base_scale", esp.scale)
		esp.scale = Vector2(base_sc.x * 1.12, base_sc.y * 0.88)
		var htw := esp.create_tween()
		htw.tween_property(esp, "scale", base_sc, 0.11).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	var is_heavy_hit: bool = is_skill or vuln_open_now > 0.0
	if is_instance_valid(fx_layer) and not bool(save_data.get("fx_reduced", false)):
		for si in range(3 if is_heavy_hit else 2):
			var spk := ColorRect.new()
			spk.size = Vector2(5.0, 5.0) if is_heavy_hit else Vector2(4.0, 4.0)
			spk.color = col.lightened(0.35)
			spk.position = e.global_position + Vector2(randf_range(-10.0, 10.0), randf_range(-38.0, -14.0))
			fx_layer.add_child(spk)
			var sdir := (push_dir.normalized() if push_dir.length() > 0.1 else Vector2.RIGHT).rotated(randf_range(-0.85, 0.85)) * randf_range(28.0, 56.0)
			var stw := spk.create_tween()
			stw.tween_property(spk, "position", spk.position + sdir, 0.20).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			stw.parallel().tween_property(spk, "modulate:a", 0.0, 0.20)
			stw.tween_callback(spk.queue_free)

	# 3-tier Hit Impact: Light Basic vs Critical vs Heavy/Skill/Vulnerable-Counter
	if not def.get("is_turret", false):
		var kb_mag := (165.0 if is_heavy_hit else 95.0) if (def["is_boss"] or def.get("is_miniboss", false)) else (390.0 if is_heavy_hit else 240.0)
		e.set_meta("kb", push_dir * kb_mag)

	if is_crit:
		run_max_crit_dmg = maxi(run_max_crit_dmg, dmg)
		hitstop_timer = maxf(hitstop_timer, 0.048 if is_heavy_hit else 0.032)
		shake_strength = maxf(shake_strength, 7.5 if is_heavy_hit else 5.2)
		sfx.play_sfx("heavy_hit" if is_heavy_hit else "crit", 0.04)
		VfxStudio.spawn_critical_star_burst(fx_layer, e.global_position + Vector2(0, -32), col, 0.95 if is_heavy_hit else 0.78)
		var ls_crit := float(active_gear.get("lifesteal_crit", 0.0))
		if ls_crit > 0.0:
			hero_hp[active_hero_id] = minf(_get_hero_stat(active_hero_id, "max_hp"), hero_hp[active_hero_id] + maxf(2.0, float(dmg) * ls_crit))
		if active_hero_id == "chen_xi":
			hero_hp["chen_xi"] = minf(_get_hero_stat("chen_xi", "max_hp"), hero_hp["chen_xi"] + 6.0)
		_spawn_floating_text(e.global_position, ("💥 %d!" % dmg) if is_heavy_hit else ("★ %d!" % dmg), Color("#fde047"), true)
	elif is_heavy_hit:
		hitstop_timer = maxf(hitstop_timer, 0.038)
		shake_strength = maxf(shake_strength, 5.8)
		sfx.play_sfx("heavy_hit", 0.05)
		_spawn_floating_text(e.global_position, "✦ %d" % dmg, col.lightened(0.25), true)
	else:
		shake_strength = maxf(shake_strength, 2.0)
		sfx.play_sfx("hit", 0.08)
		_spawn_floating_text(e.global_position, str(dmg), Color("#f8fafc"), false)

	if hp <= 0.0:
		_spawn_ring_vfx(e.global_position, col, 48.0)
		var was_boss: bool = def["is_boss"]
		var was_mini: bool = def.get("is_miniboss", false)
		e.set_meta("is_dead", true)
		_cancel_telegraphs_for(e)
		enemies.erase(e)
		_enter_enemy_death_pose(e, def)
		if active_hero_id == "yu_han":
			hero_hp["yu_han"] = minf(_get_hero_stat("yu_han", "max_hp"), hero_hp["yu_han"] + 8.0)
		if active_boons.has("blood_lotus"):
			hero_hp[active_hero_id] = minf(_get_hero_stat(active_hero_id, "max_hp"), hero_hp[active_hero_id] + 5.0)
		if was_mini:
			if boss_panel:
				boss_panel.visible = false
			_award_spirit_jade(15)
			_spawn_floating_text(player.global_position + Vector2(0, -78), "+15 💎 หยกปราณ!", Color("#5eead4"), true)
			_grant_boss_gear_drop(false)
		if was_boss:
			for ob in orbit_blades.duplicate():
				if is_instance_valid(ob):
					ob.queue_free()
			orbit_blades.clear()
			_award_spirit_jade(35)
			_grant_boss_gear_drop(true)
			_trigger_victory()


func _enter_enemy_death_pose(e: CharacterBody2D, def: Dictionary):
	if not is_instance_valid(e):
		return
	e.collision_layer = 0
	e.collision_mask = 0
	e.velocity = Vector2.ZERO
	for child_name in ["HPBg", "ShieldBg", "ShieldAura", "MarkLabel", "WindupRing", "WindupLabel", "SlashCone", "VulnOpenLabel", "Phase2Aura"]:
		var cn := e.get_node_or_null(child_name)
		if cn:
			cn.visible = false
	var sp: Sprite2D = e.get_node_or_null("Sprite")
	if sp:
		sp.scale = e.get_meta("base_scale", sp.scale)
		sp.modulate = Color(0.82, 0.78, 0.80, 1.0)
		var stype := str(e.get_meta("sheet_type", ""))
		if stype != "":
			sp.rotation = 0.0
			_set_enemy_sheet_pose(e, sp, "death")
		else:
			# Fallback collapse pose for single-frame monsters
			sp.rotation = deg_to_rad(82.0 if not sp.flip_h else -82.0)
			sp.offset.y = float(e.get_meta("base_offset_y", sp.offset.y)) * 0.25
	dying_corpses.append({"node": e, "timer": 0.72 if bool(def.get("is_boss", false)) else 0.48})


func _process_dying_corpses(delta: float):
	for item in dying_corpses.duplicate():
		var node_v: Variant = item.get("node")
		if not is_instance_valid(node_v):
			dying_corpses.erase(item)
			continue
		var n := node_v as Node2D
		var t := float(item.get("timer", 0.0)) - delta
		item["timer"] = t
		if t <= 0.22:
			n.modulate.a = clampf(t / 0.22, 0.0, 1.0)
		if t <= 0.0:
			dying_corpses.erase(item)
			n.queue_free()


func _process_enemies(delta: float):
	var hard := str(save_data.get("difficulty", "normal")) == "hard"
	var spd_mult := 1.20 if hard else 1.0
	var active_windups := 0
	for ew in enemies:
		if is_instance_valid(ew) and float(ew.get_meta("windup_timer", 0.0)) > 0.0:
			active_windups += 1
	for e in enemies.duplicate():
		if not is_instance_valid(e):
			enemies.erase(e)
			continue
		var kind: String = e.get_meta("kind")
		var def: Dictionary = MONSTER_DEFS[kind]
		var sp: Sprite2D = e.get_node("Sprite")
		var cdata := ChapterData.get_chapter(chapter)
		var base_tint: Color = e.get_meta("custom_tint", cdata["boss_tint"] if def["is_boss"] else def.get("tint", Color.WHITE))
		var wind_lbl: Label = e.get_node_or_null("WindupLabel")
		var wind_ring: Line2D = e.get_node_or_null("WindupRing")

		var trap_cd: float = float(e.get_meta("trap_cd", 0.0))
		if trap_cd > 0.0:
			e.set_meta("trap_cd", trap_cd - delta)

		var elem_timer: float = float(e.get_meta("elem_timer", 0.0))
		if elem_timer > 0.0:
			elem_timer -= delta
			e.set_meta("elem_timer", maxf(0.0, elem_timer))
			if elem_timer <= 0.0:
				e.set_meta("elem_mark", "")
				if e.has_node("MarkLabel"):
					e.get_node("MarkLabel").text = ""

		var vuln_t: float = float(e.get_meta("vuln_timer", 0.0))
		if vuln_t > 0.0:
			e.set_meta("vuln_timer", maxf(0.0, vuln_t - delta))

		var quicken_t: float = float(e.get_meta("quicken_timer", 0.0))
		if quicken_t > 0.0:
			e.set_meta("quicken_timer", maxf(0.0, quicken_t - delta))

		var burn_t: float = float(e.get_meta("burn_timer", 0.0))
		if burn_t > 0.0:
			burn_t -= delta
			e.set_meta("burn_timer", maxf(0.0, burn_t))
			var btick: float = float(e.get_meta("burn_tick", 0.5)) - delta
			if btick <= 0.0:
				e.set_meta("burn_tick", 0.5)
				var bdmg: int = int(e.get_meta("burn_dmg", 10))
				var bhp: float = float(e.get_meta("hp")) - float(bdmg)
				e.set_meta("hp", bhp)
				_spawn_floating_text(e.global_position + Vector2(0, -48), "🔥 %d" % bdmg, Color("#f97316"), false)
				if bhp <= 0.0:
					_damage_enemy(e, 1, Vector2.ZERO, Color("#f97316"), 0.0, false, false)
					continue
			else:
				e.set_meta("burn_tick", btick)

		var frost_t: float = float(e.get_meta("frostbind_timer", 0.0))
		var enemy_spd_mult := spd_mult
		if frost_t > 0.0:
			e.set_meta("frostbind_timer", maxf(0.0, frost_t - delta))
			sp.modulate = Color(0.45, 0.95, 1.0, 1.0)
			if not def["is_boss"]:
				continue
			enemy_spd_mult *= 0.50

		var flash: float = e.get_meta("flash")
		if flash > 0.0:
			flash -= delta
			e.set_meta("flash", flash)
			sp.modulate = Color(3.0, 3.0, 3.0, 1.0) if flash > 0.0 else base_tint

		var kb: Vector2 = e.get_meta("kb")
		var ez: float = float(e.get_meta("z_height", 0.0))
		if kb.length() > 10.0:
			var target_ez := clampf(kb.length() * 0.055, 0.0, 18.0)
			ez = lerpf(ez, target_ez, minf(1.0, delta * 20.0))
		else:
			ez = move_toward(ez, 0.0, 60.0 * delta)
		e.set_meta("z_height", ez)
		var base_oy := float(e.get_meta("base_offset_y", sp.offset.y))
		var stype := str(e.get_meta("sheet_type", ""))
		if stype != "":
			sp.offset.y = base_oy - ez
			sp.rotation = lerpf(sp.rotation, 0.0, minf(1.0, delta * 14.0))
		else:
			var life_phase := float(Time.get_ticks_msec()) * 0.004 + float(e.get_instance_id() % 31)
			var gait := sin(life_phase * 3.0) if e.velocity.length() > 12.0 else sin(life_phase) * 0.25
			sp.offset.y = base_oy - ez - absf(gait) * 1.5
			sp.rotation = lerpf(sp.rotation, deg_to_rad(gait * 1.5), minf(1.0, delta * 10.0))
		if e.has_node("Shadow"):
			var esh: Polygon2D = e.get_node("Shadow")
			var esc := clampf(1.0 - ez / 65.0, 0.68, 1.0)
			esh.scale = Vector2(esc, esc)
			esh.color.a = clampf(0.58 * (1.0 - ez / 55.0), 0.24, 0.58)

		var slash_cone: Polygon2D = e.get_node_or_null("SlashCone")
		var open_lbl: Label = e.get_node_or_null("VulnOpenLabel")
		var vuln_open_t := maxf(0.0, float(e.get_meta("vuln_open", 0.0)) - delta)
		e.set_meta("vuln_open", vuln_open_t)
		if open_lbl:
			open_lbl.visible = vuln_open_t > 0.0

		var hurt_t := maxf(0.0, float(e.get_meta("hurt_timer", 0.0)) - delta)
		e.set_meta("hurt_timer", hurt_t)

		if kb.length() > 10.0:
			e.velocity = kb
			e.move_and_slide()
			e.set_meta("kb", kb.lerp(Vector2.ZERO, 12.0 * delta))
			_set_enemy_sheet_pose(e, sp, "hurt")
			continue

		var stun: float = e.get_meta("stun")
		if stun > 0.0:
			e.set_meta("stun", stun - delta)
			e.set_meta("windup_timer", 0.0)
			e.set_meta("attack_pose_timer", 0.0)
			if wind_lbl:
				wind_lbl.visible = false
			if wind_ring:
				wind_ring.visible = false
			if slash_cone:
				slash_cone.visible = false
			_set_enemy_sheet_pose(e, sp, "hurt")
			sp.modulate = Color(0.5, 0.85, 1.0, 1.0)
			continue
		elif flash <= 0.0:
			sp.modulate = base_tint

		# 1. Melee Windup State -> Strike Transition (exact visual-to-damage sync onlocked cone)
		var wind_t: float = float(e.get_meta("windup_timer", 0.0))
		if wind_t > 0.0:
			wind_t -= delta
			e.set_meta("windup_timer", maxf(0.0, wind_t))
			e.set_meta("ai_state", "windup")
			var wprog := clampf(1.0 - (wind_t / 0.48), 0.0, 1.0)
			var lock_dir: Vector2 = e.get_meta("attack_dir", Vector2.RIGHT)
			sp.flip_h = lock_dir.x < 0.0
			_set_enemy_sheet_pose(e, sp, "windup", 0, "slam")
			if wind_lbl:
				wind_lbl.visible = true
			if wind_ring:
				wind_ring.visible = true
				var rsc := lerpf(0.76, 1.06, wprog)
				wind_ring.scale = Vector2(rsc, rsc)
			if slash_cone:
				slash_cone.visible = true
				slash_cone.rotation = lock_dir.angle()
				slash_cone.color = Color(0.98, 0.22, 0.26, lerpf(0.18, 0.46, wprog))
			if stype == "":
				sp.rotation = deg_to_rad((-12.0 if not sp.flip_h else 12.0) * wprog)
			if flash <= 0.0:
				sp.modulate = Color(1.50, 0.72, 0.72, 1.0)
			if wind_t <= 0.0:
				if wind_lbl:
					wind_lbl.visible = false
				if wind_ring:
					wind_ring.visible = false
				if slash_cone:
					slash_cone.visible = false
				sp.modulate = base_tint
				e.set_meta("ai_state", "attack")
				e.set_meta("attack_pose_timer", 0.18)
				e.set_meta("recovery_timer", 0.65 if not def["is_boss"] else 0.50)
				e.set_meta("atk_cd", 1.35 if def["is_boss"] else 1.75)
				_set_enemy_sheet_pose(e, sp, "attack", 0, "slam")
				var base_sc: Vector2 = e.get_meta("base_scale", sp.scale)
				sp.scale = Vector2(base_sc.x * 1.12, base_sc.y * 0.92)
				var ltw := sp.create_tween()
				ltw.tween_property(sp, "scale", base_sc, 0.14)
				# Lunge micro-step in locked swing direction + cone check so player sidestepping behind avoids hit!
				e.velocity = lock_dir * 165.0
				e.move_and_slide()
				var p_vec: Vector2 = player.global_position - e.global_position
				var p_dist := p_vec.length()
				var in_arc := p_dist <= 30.0 or (p_dist <= float(def["range"]) + 16.0 and p_vec.normalized().dot(lock_dir) >= 0.18)
				if in_arc:
					_enemy_hit_player(def["atk"], e.global_position, def["is_boss"])
			continue

		# 2. Active Attack Swing Hold -> Recovery Window
		var atk_pose_t: float = float(e.get_meta("attack_pose_timer", 0.0))
		if atk_pose_t > 0.0:
			e.set_meta("attack_pose_timer", maxf(0.0, atk_pose_t - delta))
			e.set_meta("ai_state", "attack")
			e.velocity = Vector2.ZERO
			_set_enemy_sheet_pose(e, sp, "attack", 0, str(e.get_meta("cast_pose", "slam")))
			continue

		var recov_t: float = float(e.get_meta("recovery_timer", 0.0))
		if recov_t > 0.0:
			e.set_meta("recovery_timer", maxf(0.0, recov_t - delta))
			e.set_meta("ai_state", "recovery")
			e.velocity = Vector2.ZERO
			_set_enemy_sheet_pose(e, sp, "recovery")
			if vuln_open_t > 0.0 and flash <= 0.0:
				sp.modulate = Color(0.86, 0.92, 1.05, 1.0)
			continue

		# 3. Boss Phase 2 Transformation (HP <= 50%)
		if def["is_boss"] and not bool(e.get_meta("phase2_done", false)) and float(e.get_meta("hp")) < float(e.get_meta("max_hp")) * 0.5:
			e.set_meta("phase2_done", true)
			if boss_name_label:
				boss_name_label.add_theme_color_override("font_color", Color("#ef4444"))
			boss_name_label.text = "☠️ %s (เฟส 2 — %s!)" % [cdata["boss"], cdata["ult_name"]]
			_show_banner("🔥 เฟส 2! %s คลุ้มคลั่ง — สังเกตช่องว่างหลังท่าใหญ่เพื่อสวนกลับ!" % cdata["ult_name"], 3.0)
			_spawn_ring_vfx(e.global_position, Color("#ef4444"), 240.0)
			var push_out: Vector2 = (player.global_position - e.global_position).normalized()
			if push_out.length() < 0.1:
				push_out = Vector2.LEFT
			player.global_position += push_out * 90.0
			VfxStudio.spawn_boss_ultimate_vfx(floor_layer, fx_layer, e.global_position, chapter, cdata["light_color"])
			_attach_boss_phase2_aura(e)
			_spawn_orbit_blades(e.global_position)
			_start_eight_dir_storm(e)

		if bool(e.get_meta("phase2_done", false)):
			enemy_spd_mult *= 1.22
			var p2_aura: Node2D = e.get_node_or_null("Phase2Aura")
			if p2_aura:
				p2_aura.rotation += delta * 2.4
				var pls := 1.0 + 0.08 * sin(run_elapsed_time * 7.5)
				p2_aura.scale = Vector2(pls, pls)

		var to_p: Vector2 = player.global_position - e.global_position
		var dist: float = to_p.length()
		var casting: float = e.get_meta("casting")
		if casting > 0.0:
			e.set_meta("casting", maxf(0.0, casting - delta))
			e.set_meta("ai_state", "windup")
			e.velocity = Vector2.ZERO
			_set_enemy_sheet_pose(e, sp, "windup", 0, str(e.get_meta("cast_pose", "slam")))
			if flash <= 0.0:
				sp.modulate = Color(1.45, 0.88, 0.72, 1.0)
		elif def.get("is_turret", false):
			var atk_cd: float = e.get_meta("atk_cd") - delta
			e.set_meta("atk_cd", atk_cd)
			if atk_cd <= 0.0 and dist < 620.0:
				e.set_meta("atk_cd", 2.2)
				_spawn_enemy_orb(e.global_position, to_p.normalized(), 16)
		elif dist < 580.0:
			sp.flip_h = to_p.x < 0.0
			var atk_cd: float = e.get_meta("atk_cd") - delta
			e.set_meta("atk_cd", atk_cd)
			var special_cd: float = e.get_meta("special_cd") - delta
			e.set_meta("special_cd", special_cd)
			var is_p2: bool = bool(e.get_meta("phase2_done", false))

			if (def["is_boss"] or kind == "golem" or kind == "bronze_sentinel") and special_cd <= 0.0 and dist < 420.0:
				if kind == "golem" or kind == "bronze_sentinel":
					e.set_meta("special_cd", 4.2)
					e.set_meta("cast_pose", "slam")
					_start_slam_telegraph(e, 120.0, 26, 0.75)
				elif chapter == 1 and def["is_boss"]:
					# Furnace Guardian: 3 distinct readable patterns + overheat counter window
					var pat: int = int(e.get_meta("boss_phase", 0))
					e.set_meta("boss_phase", (pat + 1) % 3)
					e.set_meta("special_cd", 2.65 if is_p2 else 3.25)
					if pat == 0:
						e.set_meta("cast_pose", "slam")
						_start_slam_telegraph(e, 158.0, 36, 0.70 if is_p2 else 0.88)
					elif pat == 1:
						e.set_meta("cast_pose", "wave")
						_start_boss_wave_attack(e, to_p.normalized())
					else:
						e.set_meta("cast_pose", "slam")
						_start_furnace_pillars(e, is_p2)
				elif kind == "boss_ch3":
					e.set_meta("special_cd", 2.9)
					var phase: int = e.get_meta("boss_phase")
					e.set_meta("boss_phase", (phase + 1) % 3)
					if phase == 0:
						e.set_meta("cast_pose", "wave")
						_start_laser_telegraph(e, to_p.normalized())
					elif phase == 1 and is_p2:
						e.set_meta("cast_pose", "slam")
						_start_eight_dir_storm(e)
					else:
						e.set_meta("cast_pose", "wave")
						_start_boss_wave_attack(e, to_p.normalized())
				else:
					e.set_meta("special_cd", 2.7 if kind == "boss_ch2" else 3.1)
					var phase: int = e.get_meta("boss_phase")
					e.set_meta("boss_phase", (phase + 1) % 2)
					if phase == 0:
						e.set_meta("cast_pose", "slam")
						_start_slam_telegraph(e, 175.0 if kind == "boss_ch2" else 160.0, 42 if kind == "boss_ch2" else 38, 0.72 if kind == "boss_ch2" else 0.85)
					else:
						e.set_meta("cast_pose", "wave")
						_start_boss_wave_attack(e, to_p.normalized())
			else:
				# Anti-stacking surround positioning + personal-space standoff so mobs never pile onto hero sprite
				var sep_vec: Vector2 = Vector2.ZERO
				var sep_rad := 105.0 if def["is_boss"] else 86.0
				for other in enemies:
					if is_instance_valid(other) and other != e:
						var o_pos: Vector2 = (other as Node2D).global_position
						var od: float = e.global_position.distance_to(o_pos)
						if od > 0.1 and od < sep_rad:
							sep_vec += (e.global_position - o_pos).normalized() * ((sep_rad - od) / sep_rad) * 2.1

				var max_simul: int = 1 if (current_room == 0 and chapter == 1) else 2
				var can_engage: bool = def["is_boss"] or (atk_cd <= 0.35 and active_windups < max_simul)
				var slot_ang: float = float(e.get_meta("surround_angle", 0.0))
				var ring_r: float = (float(def["range"]) * 0.86) if can_engage else (float(def["range"]) * 1.38)
				var min_standoff: float = 88.0 if def["is_boss"] else 56.0
				ring_r = maxf(ring_r, min_standoff)

				var radial_from_p: Vector2 = -to_p.normalized() if dist > 0.1 else Vector2.RIGHT
				var slot_dir: Vector2 = Vector2(cos(slot_ang), sin(slot_ang) * 0.74).normalized()
				var desired_dir: Vector2 = (radial_from_p * 0.55 + slot_dir * 0.45).normalized()
				var desired_pos: Vector2 = player.global_position + desired_dir * ring_r
				var e_pos: Vector2 = (e as Node2D).global_position
				var to_slot: Vector2 = desired_pos - e_pos

				if dist < min_standoff - 6.0:
					# Step outward cleanly if overlapping the player
					var push_away: Vector2 = (radial_from_p * 1.5 + sep_vec).normalized()
					e.velocity = push_away * float(def["speed"]) * 0.85 * enemy_spd_mult
					e.move_and_slide()
				elif to_slot.length() > 14.0 or sep_vec.length() > 0.18:
					var steer_dir: Vector2 = ((to_slot.normalized() if to_slot.length() > 8.0 else Vector2.ZERO) + sep_vec).normalized()
					var spd_scale: float = 1.0 if dist > float(def["range"]) else 0.74
					e.velocity = steer_dir * float(def["speed"]) * spd_scale * enemy_spd_mult
					e.move_and_slide()
				else:
					e.velocity = Vector2.ZERO

				var e_vel: Vector2 = (e as CharacterBody2D).velocity
				if hurt_t > 0.0:
					_set_enemy_sheet_pose(e, sp, "hurt")
				elif e_vel.length() > 14.0:
					e.set_meta("ai_state", "move")
					var wdist: float = float(e.get_meta("walk_dist", 0.0)) + e_vel.length() * delta
					var widx: int = int(e.get_meta("walk_idx", 0))
					if wdist >= (38.0 if def["is_boss"] else 28.0):
						wdist = 0.0
						widx = (widx + 1) % 2
					e.set_meta("walk_dist", wdist)
					e.set_meta("walk_idx", widx)
					_set_enemy_sheet_pose(e, sp, "move", widx)
				else:
					e.set_meta("ai_state", "idle")
					_set_enemy_sheet_pose(e, sp, "idle")

				if dist <= float(def["range"]) + 10.0 and atk_cd <= 0.0 and active_windups < max_simul:
					var lock_d := to_p.normalized() if dist > 0.1 else Vector2.RIGHT
					e.set_meta("attack_dir", lock_d)
					e.set_meta("windup_timer", 0.48)
					e.set_meta("ai_state", "windup")
					e.velocity = Vector2.ZERO
					active_windups += 1
					_set_enemy_sheet_pose(e, sp, "windup", 0, "slam")
					if wind_lbl:
						wind_lbl.visible = true
					if wind_ring:
						wind_ring.visible = true
					if slash_cone:
						slash_cone.visible = true
						slash_cone.rotation = lock_d.angle()
		else:
			e.velocity = Vector2.ZERO
			e.set_meta("ai_state", "idle")
			_set_enemy_sheet_pose(e, sp, "hurt" if hurt_t > 0.0 else "idle")

		if def["is_boss"] or def.get("is_miniboss", false):
			boss_bar.max_value = e.get_meta("max_hp")
			boss_bar.value = e.get_meta("hp")
		elif e.has_node("HPBg/HPFg"):
			var fg: ColorRect = e.get_node("HPBg/HPFg")
			var max_w := 54.0 if def.get("is_miniboss", false) else 44.0
			fg.size.x = max_w * clampf(e.get_meta("hp") / e.get_meta("max_hp"), 0.0, 1.0)


func _enemy_hit_player(dmg: int, _src_pos: Vector2, is_boss: bool):
	if combat.can_trigger_perfect_dodge():
		_activate_perfect_dodge()
		return
	if invuln_timer > 0.0:
		return
	invuln_timer = 0.45
	combat.on_player_damaged()
	var dmg_mult := 0.82 if active_boons.has("jade_aegis") else 1.0
	var gear_b := EquipData.get_bonuses_for_hero(save_data.get("hero_gear", {}), active_hero_id, save_data.get("gear_levels", {}))
	var dmg_red := float(gear_b.get("dmg_red", 0.0))
	if hero_hp[active_hero_id] < _get_hero_stat(active_hero_id, "max_hp") * 0.30:
		dmg_red += float(gear_b.get("low_hp_dmg_red", 0.0))
	dmg_mult *= maxf(0.25, 1.0 - dmg_red)
	var final_dmg := int(round(float(dmg) * dmg_mult))
	if chapter == 1 and current_room == 0:
		final_dmg = maxi(2, int(round(float(final_dmg) * 0.40)))
	if tutorial_step > 0 and current_room == 0:
		hero_hp[active_hero_id] = maxf(35.0, hero_hp[active_hero_id] - final_dmg)
	else:
		hero_hp[active_hero_id] = maxf(0.0, hero_hp[active_hero_id] - final_dmg)
	shake_strength = 10.0 if is_boss else 6.0
	_spawn_floating_text(player.global_position + Vector2(0, -54), "-%d" % final_dmg, Color("#ef4444"), false)

	if hero_hp[active_hero_id] <= 0.0:
		for hid in active_party:
			if hero_hp[hid] > 0.0:
				_switch_hero(hid, true)
				return
		if active_boons.has("phoenix_rebirth") and not phoenix_revive_used:
			phoenix_revive_used = true
			var rev_hp := _get_hero_stat(active_hero_id, "max_hp") * 0.45
			hero_hp[active_hero_id] = rev_hp
			invuln_timer = 1.6
			sfx.play_sfx("resonance")
			_spawn_ring_vfx(player.global_position, Color("#fb923c"), 160.0)
			_show_banner("🔥 หงส์เพลิงคืนชีพ! ฟื้นฟูพลัง 45%!", 2.2)
			_refresh_hud()
			return
		_trigger_defeat()


func _process_projectiles(delta: float):
	for p in projectiles.duplicate():
		if not is_instance_valid(p):
			projectiles.erase(p)
			continue
		p.position += p.get_meta("vel") * delta
		p.set_meta("life", p.get_meta("life") - delta)
		if p.get_meta("life") <= 0.0:
			projectiles.erase(p)
			p.queue_free()
			continue
		for e in enemies:
			if is_instance_valid(e) and e.global_position.distance_to(p.global_position) < 42.0:
				_damage_enemy(e, p.get_meta("dmg"), p.get_meta("vel").normalized(), p.get_meta("col"), float(p.get_meta("crit", 0.25)), bool(p.get_meta("is_skill", false)))
				projectiles.erase(p)
				p.queue_free()
				break


func _clear_exit_hint():
	if is_instance_valid(active_exit_hint):
		active_exit_hint.queue_free()
	active_exit_hint = null


func _spawn_exit_hint_badge(orb_x: float):
	_clear_exit_hint()
	var holder := Node2D.new()
	var base_p := Vector2(orb_x + 56.0, 3.35 * TILE_SIZE)
	holder.position = base_p
	holder.set_meta("base_pos", base_p)
	holder.z_index = 9

	var glow := Polygon2D.new()
	glow.polygon = PackedVector2Array([
		Vector2(-8.0, -4.0), Vector2(126.0, -4.0), Vector2(136.0, 16.0), Vector2(126.0, 36.0), Vector2(-8.0, 36.0)
	])
	glow.color = Color(0.04, 0.16, 0.15, 0.84)
	holder.add_child(glow)

	var border := Line2D.new()
	border.points = PackedVector2Array([
		Vector2(-8.0, -4.0), Vector2(126.0, -4.0), Vector2(136.0, 16.0), Vector2(126.0, 36.0), Vector2(-8.0, 36.0), Vector2(-8.0, -4.0)
	])
	border.width = 2.0
	border.default_color = Color("#34d399")
	holder.add_child(border)

	var exit_lbl := Label.new()
	exit_lbl.text = "⛩️ ทางออก →"
	exit_lbl.position = Vector2(2.0, 1.0)
	exit_lbl.add_theme_font_size_override("font_size", 18)
	exit_lbl.add_theme_color_override("font_color", Color("#a7f3d0"))
	exit_lbl.add_theme_color_override("font_outline_color", Color(0.02, 0.06, 0.08, 0.96))
	exit_lbl.add_theme_constant_override("outline_size", 4)
	holder.add_child(exit_lbl)

	# Portal threshold glow right at the corridor entrance
	var gate_glow := Polygon2D.new()
	gate_glow.polygon = _make_ellipse(22.0, TILE_SIZE * 1.32, 18)
	gate_glow.color = Color(0.20, 0.94, 0.72, 0.24)
	gate_glow.position = Vector2(82.0, 1.15 * TILE_SIZE)
	holder.add_child(gate_glow)

	fx_layer.add_child(holder)
	active_exit_hint = holder


func _check_room_progression():
	var total := _total_rooms()
	if enemies.size() == 0 and current_room < total - 1:
		if not cleared_rooms.has(current_room):
			cleared_rooms[current_room] = true
			_award_spirit_jade(5)
			if minimap_ctrl:
				minimap_ctrl.queue_redraw()
		if current_room < room_gates.size() and is_instance_valid(room_gates[current_room]):
			room_gates[current_room].queue_free()
			var orb_x := (12.0 + float(current_room * ROOM_STRIDE)) * TILE_SIZE
			_spawn_heal_orb(Vector2(orb_x, 4.5 * TILE_SIZE))
			_spawn_exit_hint_badge(orb_x)
			var floor_no := ChapterData.get_floor_number(chapter, current_room)
			_show_banner("✨ ชั้นที่ %d/100 เคลียร์! (+5 💎) เก็บโอสถหยกแล้วเดินไปทางขวา" % floor_no, 2.8)
			if (current_room == 2 or current_room == 4 or current_room == 6 or current_room == 8) and not boon_granted_rooms.has(current_room):
				boon_granted_rooms[current_room] = true
				_open_boon_picker()

	var next_x := (15.5 + float(current_room * ROOM_STRIDE)) * TILE_SIZE
	if current_room < total - 1 and player.global_position.x > next_x:
		_clear_exit_hint()
		_spawn_room_wave(current_room + 1)


func _spawn_projectile(pos: Vector2, dir: Vector2, dmg: int, tex_path: String, col: Color, speed: float = 640.0, is_skill: bool = false, crit_chance: float = -1.0):
	var p := Sprite2D.new()
	p.texture = load(tex_path)
	p.position = pos
	p.rotation = dir.angle()
	p.scale = Vector2(0.82, 0.82)
	p.set_meta("vel", dir * speed)
	p.set_meta("dmg", dmg)
	p.set_meta("col", col)
	p.set_meta("life", 0.85)
	p.set_meta("is_skill", is_skill)
	p.set_meta("crit", crit_chance if crit_chance >= 0.0 else _get_hero_stat(active_hero_id, "crit"))
	fx_layer.add_child(p)
	projectiles.append(p)


func _spawn_slash_vfx(pos: Vector2, angle: float, tex_path: String, col: Color, sc: float = 0.95):
	var s := Sprite2D.new()
	s.texture = load(tex_path)
	s.position = pos
	s.rotation = angle
	s.scale = Vector2(sc, sc)
	s.modulate = col.lightened(0.35)
	fx_layer.add_child(s)
	var tw := create_tween()
	tw.tween_property(s, "scale", Vector2(sc * 1.35, sc * 1.35), 0.20)
	tw.parallel().tween_property(s, "modulate:a", 0.0, 0.20)
	tw.tween_callback(s.queue_free)


func _spawn_burst_vfx(pos: Vector2, tex_path: String, sc: float = 1.0):
	if not ResourceLoader.exists(tex_path):
		return
	var s := Sprite2D.new()
	s.texture = load(tex_path)
	s.position = pos + Vector2(0, -24)
	s.scale = Vector2(sc * 0.65, sc * 0.65)
	s.modulate.a = 0.72
	fx_layer.add_child(s)
	var tw := create_tween()
	tw.tween_property(s, "scale", Vector2(sc * 1.1, sc * 1.1), 0.24)
	tw.parallel().tween_property(s, "modulate:a", 0.0, 0.30)
	tw.tween_callback(s.queue_free)


func _spawn_domain_vfx(pos: Vector2, tex_path: String, target_sc: float = 1.5):
	if not ResourceLoader.exists(tex_path):
		return
	var s := Sprite2D.new()
	s.texture = load(tex_path)
	s.position = pos
	s.scale = Vector2(0.6, 0.6)
	s.modulate.a = 0.58
	floor_layer.add_child(s)
	var tw := create_tween()
	tw.tween_property(s, "scale", Vector2(target_sc, target_sc), 0.40)
	tw.parallel().tween_property(s, "modulate:a", 0.0, 0.90)
	tw.tween_callback(s.queue_free)


func _spawn_ring_vfx(pos: Vector2, col: Color, radius: float):
	var ring := Line2D.new()
	var pts := _make_ellipse(radius, radius * 0.72, 28)
	pts.append(pts[0])
	ring.points = pts
	ring.width = 4.0
	ring.default_color = Color(col.r, col.g, col.b, 0.78)
	ring.position = pos
	fx_layer.add_child(ring)
	var tw := create_tween()
	tw.tween_property(ring, "scale", Vector2(1.28, 1.28), 0.28)
	tw.parallel().tween_property(ring, "modulate:a", 0.0, 0.28)
	tw.tween_callback(ring.queue_free)


func _spawn_heal_orb(pos: Vector2):
	var orb := Node2D.new()
	orb.position = pos
	orb.set_meta("base_y", pos.y)
	var shadow := Polygon2D.new()
	shadow.polygon = _make_ellipse(15.0, 6.0, 12)
	shadow.color = Color(0.0, 0.0, 0.0, 0.42)
	shadow.position = Vector2(0, 12.0)
	orb.add_child(shadow)

	var aura := Line2D.new()
	var a_pts := _make_ellipse(18.0, 18.0, 20)
	a_pts.append(a_pts[0])
	aura.points = a_pts
	aura.width = 2.0
	aura.default_color = Color(0.32, 0.96, 0.72, 0.68)
	aura.name = "OrbAura"
	orb.add_child(aura)

	var outer := Polygon2D.new()
	outer.polygon = _make_ellipse(12.5, 12.5, 16)
	outer.color = Color("#10b981")
	outer.name = "OrbCore"
	orb.add_child(outer)

	var inner := Polygon2D.new()
	inner.polygon = _make_ellipse(6.5, 6.5, 12)
	inner.color = Color("#d1fae5")
	inner.position = Vector2(-2.5, -2.5)
	outer.add_child(inner)

	_add_light(orb, Color("#34d399"), 1.35, 2.1)
	world_node.add_child(orb)
	heal_orbs.append(orb)


func _process_heal_orbs():
	for orb in heal_orbs.duplicate():
		if not is_instance_valid(orb):
			heal_orbs.erase(orb)
			continue
		var core := orb.get_node_or_null("OrbCore") as Node2D
		var aura := orb.get_node_or_null("OrbAura") as Node2D
		if core:
			core.position.y = sin(run_elapsed_time * 4.0) * 3.5 - 4.0
		if aura:
			var asc := 1.0 + 0.10 * sin(run_elapsed_time * 3.2)
			aura.scale = Vector2(asc, asc)
			aura.position.y = core.position.y if core else 0.0
		var pickup_dist := 160.0 if active_boons.has("jade_magnet") else 48.0
		if player.global_position.distance_to(orb.global_position) < pickup_dist:
			var max_hp := _get_hero_stat(active_hero_id, "max_hp")
			var max_sp := _get_hero_stat(active_hero_id, "max_sp")
			var bonus := float(save_data.get("core_upgrades", {}).get("orb_lv", 0)) * 15.0
			var mult_orb := 1.35 if active_boons.has("jade_magnet") else 1.0
			var heal_hp := (40.0 + bonus) * mult_orb
			var heal_sp := (30.0 + bonus) * mult_orb
			hero_hp[active_hero_id] = minf(max_hp, hero_hp[active_hero_id] + heal_hp)
			hero_sp[active_hero_id] = minf(max_sp, hero_sp[active_hero_id] + heal_sp)
			sfx.play_sfx("dodge")
			_spawn_floating_text(player.global_position + Vector2(0, -54), "+%d HP +%d ปราณ!" % [int(heal_hp), int(heal_sp)], Color("#4ade80"), true)
			heal_orbs.erase(orb)
			orb.queue_free()


func _spawn_ghost_afterimage():
	var g := Sprite2D.new()
	g.texture = player_sprite.texture
	g.hframes = player_sprite.hframes
	g.vframes = player_sprite.vframes
	g.frame = player_sprite.frame
	g.flip_h = player_sprite.flip_h
	g.scale = HERO_SCALE
	g.offset = HERO_OFFSET
	g.position = player.global_position
	var c: Color = HeroData.HEROES[active_hero_id]["color"]
	g.modulate = Color(c.r, c.g, c.b, 0.55)
	world_node.add_child(g)
	var tw := create_tween()
	tw.tween_property(g, "modulate:a", 0.0, 0.22)
	tw.tween_callback(g.queue_free)


func _spawn_floating_text(pos: Vector2, text_val: String, col: Color, is_big: bool):
	if not is_instance_valid(fx_layer):
		return
	# Prune expired floating labels and recycle oldest if > 10 so rapid combos never clutter the arena
	for fl in active_float_labels.duplicate():
		if not is_instance_valid(fl):
			active_float_labels.erase(fl)
	if active_float_labels.size() >= 10:
		var oldest: Node = active_float_labels.pop_front()
		if is_instance_valid(oldest):
			oldest.queue_free()

	# Staircase fan around upper flank so numbers never stack on top of each other or cover feet/telegraphs
	var fan_offsets := [
		Vector2(-28.0, -64.0),
		Vector2(22.0, -70.0),
		Vector2(-38.0, -84.0),
		Vector2(30.0, -88.0),
		Vector2(-4.0, -100.0),
	]
	var slot_ofs: Vector2 = fan_offsets[float_slot_cursor % fan_offsets.size()]
	float_slot_cursor = (float_slot_cursor + 1) % fan_offsets.size()

	var lbl := Label.new()
	lbl.text = text_val
	lbl.position = pos + slot_ofs
	lbl.z_index = 9
	lbl.add_theme_font_size_override("font_size", 20 if is_big else 14)
	lbl.add_theme_color_override("font_color", col)
	lbl.add_theme_color_override("font_outline_color", Color(0.04, 0.06, 0.10, 0.96))
	lbl.add_theme_constant_override("outline_size", 4 if is_big else 3)
	fx_layer.add_child(lbl)
	active_float_labels.append(lbl)
	if is_big:
		lbl.scale = Vector2(1.22, 1.22)
	var tw := lbl.create_tween()
	if is_big:
		tw.tween_property(lbl, "scale", Vector2.ONE, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(lbl, "position:y", lbl.position.y - 26.0, 0.46).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(lbl, "modulate:a", 0.0, 0.46)
	tw.tween_callback(func():
		active_float_labels.erase(lbl)
		lbl.queue_free()
	)


func _get_shake_scale() -> float:
	var sm := str(save_data.get("shake_mode", "normal"))
	if sm == "off":
		return 0.0
	elif sm == "low":
		return 0.35
	return 1.0


func _process_camera_shake(delta: float):
	var s_scale := _get_shake_scale()
	if shake_strength > 0.1 and s_scale > 0.01:
		var eff := minf(shake_strength * s_scale, 9.0)
		camera.offset = Vector2(randf_range(-eff, eff), randf_range(-eff, eff))
		shake_strength = lerpf(shake_strength, 0.0, 14.0 * delta)
	else:
		shake_strength = move_toward(shake_strength, 0.0, 24.0 * delta)
		camera.offset = Vector2.ZERO


func _show_banner(msg: String, duration: float):
	banner_label.text = msg
	if banner_panel:
		if tutorial_panel != null and tutorial_panel.visible:
			banner_panel.position.y = 178.0
		elif boss_panel != null and boss_panel.visible:
			banner_panel.position.y = 112.0
		else:
			banner_panel.position.y = 72.0
	banner_panel.visible = true
	var tw := create_tween()
	tw.tween_interval(duration)
	tw.tween_callback(func(): banner_panel.visible = false)


func _refresh_hud():
	var data: Dictionary = HeroData.HEROES[active_hero_id]
	var mhp := int(_get_hero_stat(active_hero_id, "max_hp"))
	var msp := int(_get_hero_stat(active_hero_id, "max_sp"))
	hp_bar.max_value = mhp
	hp_bar.value = hero_hp[active_hero_id]
	hp_label.text = "%s  HP %d / %d" % [data["name"], int(hero_hp[active_hero_id]), mhp]

	sp_bar.max_value = msp
	sp_bar.value = hero_sp[active_hero_id]
	sp_label.text = "ปราณ %d / %d" % [int(hero_sp[active_hero_id]), msp]

	var nearest_marked: CharacterBody2D = _get_nearest_enemy(520.0)
	var marked_elem := ""
	if nearest_marked != null and float(nearest_marked.get_meta("elem_timer", 0.0)) > 0.0:
		marked_elem = str(nearest_marked.get_meta("elem_mark", ""))

	for hid in active_party:
		if not hero_cards.has(hid):
			continue
		var card: PanelContainer = hero_cards[hid]
		var r_ready: bool = float(hero_sp.get(hid, 0.0)) >= 35.0 and hero_hp[hid] > 0.0
		var hero_elem := CombatSystem.get_hero_element(hid)
		var can_react: bool = hid != active_hero_id and hero_hp[hid] > 0.0 and not marked_elem.is_empty() and marked_elem != hero_elem and not CombatSystem.lookup_reaction(marked_elem, hero_elem).is_empty()
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.08, 0.11, 0.16, 0.9)
		if hid == active_hero_id:
			sb.border_color = Color("#fde047")
			sb.set_border_width_all(3)
		elif can_react:
			sb.border_color = Color("#38bdf8")
			sb.set_border_width_all(2)
		elif r_ready:
			sb.border_color = Color("#f59e0b")
			sb.set_border_width_all(2)
		else:
			sb.border_color = Color(0.3, 0.35, 0.45, 0.6)
			sb.set_border_width_all(1)
		sb.set_corner_radius_all(8)
		card.add_theme_stylebox_override("panel", sb)
		card.modulate = Color(0.35, 0.35, 0.35, 0.7) if hero_hp[hid] <= 0.0 else Color.WHITE
		if card.has_node("SwapStatusBadge"):
			var badge: Label = card.get_node("SwapStatusBadge")
			if can_react:
				badge.text = "⚡"
				badge.add_theme_color_override("font_color", Color("#38bdf8"))
				badge.visible = true
			elif r_ready and hid != active_hero_id:
				badge.text = "R!"
				badge.add_theme_color_override("font_color", Color("#fde047"))
				badge.visible = true
			else:
				badge.visible = false

	q_title_lbl.text = "[Q] " + data["q_name"]
	e_title_lbl.text = "[E] " + data["e_name"]
	r_title_lbl.text = "[R] " + data["r_name"]

	var cur_sp := int(hero_sp[active_hero_id])
	var qc := int(data["q_cost"])
	var ec := int(data["e_cost"])
	var rc := int(data["r_cost"])
	q_val_lbl.text = ("⏳ %.1fs" % q_cd) if q_cd > 0.0 else (("💧 %d/%d ปราณ" % [cur_sp, qc]) if cur_sp < qc else ("พร้อมใช้ (%d)" % qc))
	e_val_lbl.text = ("⏳ %.1fs" % e_cd) if e_cd > 0.0 else (("💧 %d/%d ปราณ" % [cur_sp, ec]) if cur_sp < ec else ("พร้อมใช้ (%d)" % ec))
	r_val_lbl.text = ("⏳ %.1fs" % r_cd) if r_cd > 0.0 else (("💧 %d/%d ปราณ" % [cur_sp, rc]) if cur_sp < rc else ("พร้อมใช้ (%d)" % rc))
	dash_val_lbl.text = ("⏳ %.1fs" % dash_cooldown) if dash_cooldown > 0.0 else "พร้อมใช้"
	auto_val_lbl.text = "ออโต้: ON (คลิกสลับ)" if auto_attack_enabled else "ออโต้: OFF (คลิกสลับ)"
	if mobile_controls:
		mobile_controls.update_state(data, q_cd, e_cd, r_cd, dash_cooldown, float(hero_sp[active_hero_id]), auto_attack_enabled, game_speed_mult)
	if speed_btn:
		speed_btn.text = "⏩ 1.5×" if game_speed_mult >= 1.25 else "⏩ 1.0×"
		speed_btn.add_theme_color_override("font_color", Color("#fbbf24") if game_speed_mult >= 1.25 else Color.WHITE)
	if jade_label:
		jade_label.text = "💎 หยกปราณ: %d" % int(save_data.get("spirit_jade", 0))
	if diff_btn:
		diff_btn.text = "โหมด: ท้าทาย" if str(save_data.get("difficulty", "normal")) == "hard" else "โหมด: ปกติ"
	if combo_panel:
		var rdata: Dictionary = combat.get_rank_data()
		combo_panel.visible = combat.combo_score > 0.0 or combat.perfect_dodge_crit_ready
		combo_rank_label.text = "%s · %d HITS" % [rdata["id"], combat.combo_hits]
		combo_rank_label.add_theme_color_override("font_color", rdata["color"])
		combo_sub_label.text = "+%d%% DMG · +%d%% หยก" % [int(round(float(rdata["dmg_bonus"]) * 100.0)), int(round(float(rdata["jade_bonus"]) * 100.0))]
		combo_bar.value = combat.get_decay_ratio() * 100.0
		dodge_ready_label.visible = combat.perfect_dodge_crit_ready
	_refresh_cutin_btn()


func _trigger_victory():
	boss_panel.visible = false
	sfx.play_sfx("victory")
	var cleared: Array = save_data.get("cleared_chapters", [])
	var first_clear_bonus := 0
	if not cleared.has(chapter):
		cleared.append(chapter)
		save_data["cleared_chapters"] = cleared
		first_clear_bonus = 50
		run_jade_earned += first_clear_bonus
		save_data["spirit_jade"] = int(save_data.get("spirit_jade", 0)) + first_clear_bonus
		SaveManager.save_data(save_data, save_path)
	if chapter >= 1:
		_record_achievement("clear_ch1", 1, true)
	if chapter >= 5:
		_record_achievement("clear_ch5", 1, true)
	if chapter >= 10:
		_record_achievement("clear_ch10", 1, true)

	if boss_rush_mode and chapter < ChapterData.TOTAL_CHAPTERS:
		_award_spirit_jade(40)
		for hid in active_party:
			if hero_hp[hid] > 0.0:
				hero_hp[hid] = minf(_get_hero_stat(hid, "max_hp"), hero_hp[hid] + _get_hero_stat(hid, "max_hp") * 0.40)
			hero_sp[hid] = minf(_get_hero_stat(hid, "max_sp"), hero_sp[hid] + _get_hero_stat(hid, "max_sp") * 0.40)
		Globals.set_meta("chapter", chapter + 1)
		Globals.set_meta("boss_rush", true)
		Globals.set_meta("skip_intro", true)
		get_tree().reload_current_scene()
		return

	victory = true
	if boss_rush_mode and chapter == ChapterData.TOTAL_CHAPTERS:
		_award_spirit_jade(150)
		Globals.set_meta("boss_rush", false)
	var bonus_txt := (" + โบนัสเคลียร์ครั้งแรก +%d 💎" % first_clear_bonus) if first_clear_bonus > 0 else ""
	if boss_rush_mode:
		bonus_txt += " + แชมป์ Boss Rush +150 💎!"
	var cdata := ChapterData.get_chapter(chapter)
	if chapter < ChapterData.TOTAL_CHAPTERS:
		var nxt := ChapterData.get_chapter(chapter + 1)
		end_title.text = "🏆 พิชิตบทที่ %d (%s) สำเร็จ! (+35 💎%s)" % [chapter, cdata["title"], bonus_txt]
		restart_btn.text = "⚔️ ลุยต่อ บทที่ %d: %s [Enter]" % [chapter + 1, nxt["title"]]
	else:
		end_title.text = "👑 พิชิตครบทั้ง 10 บท 100 ชั้น! ผนึกกระบี่สะบั้นสวรรค์สำเร็จ!%s" % bonus_txt
		restart_btn.text = "🔄 เริ่มวัฏจักรใหม่ บทที่ 1 [Enter]"
	end_title.add_theme_color_override("font_color", Color("#fde047"))
	Engine.time_scale = 1.0
	if replay_btn:
		replay_btn.visible = true
	_populate_battle_summary(true)
	end_input_guard_timer = 0.85
	_prev_enter_end = true
	if restart_btn:
		# Do NOT grab_focus() so Spacebar (Dash) or skill taps on Floor 100 never skip the summary!
		restart_btn.focus_mode = Control.FOCUS_NONE
		restart_btn.disabled = true
	end_overlay.visible = true


func _trigger_defeat():
	game_over = true
	Engine.time_scale = 1.0
	end_title.text = "💀 เหล่าผู้กล้าพ่ายแพ้"
	restart_btn.text = "🔄 ลองใหม่อีกครั้ง [Enter]"
	end_title.add_theme_color_override("font_color", Color("#f87171"))
	if replay_btn:
		replay_btn.visible = false
	_populate_battle_summary(false)
	end_input_guard_timer = 0.65
	_prev_enter_end = true
	if restart_btn:
		restart_btn.focus_mode = Control.FOCUS_NONE
		restart_btn.disabled = true
	end_overlay.visible = true


func _on_end_action_pressed():
	Engine.time_scale = 1.0
	Globals.set_meta("auto_attack", auto_attack_enabled)
	if victory:
		var nxt := (chapter + 1) if chapter < ChapterData.TOTAL_CHAPTERS else 1
		Globals.set_meta("chapter", nxt)
	get_tree().reload_current_scene()


func _replay_current_chapter():
	Engine.time_scale = 1.0
	Globals.set_meta("auto_attack", auto_attack_enabled)
	Globals.set_meta("chapter", chapter)
	get_tree().reload_current_scene()


func _toggle_auto_attack():
	auto_attack_enabled = not auto_attack_enabled
	save_data["auto_attack"] = auto_attack_enabled
	Globals.set_meta("auto_attack", auto_attack_enabled)
	SaveManager.save_data(save_data, save_path)
	_show_banner("โหมดตีอัตโนมัติ: %s" % ("เปิด (ON)" if auto_attack_enabled else "ปิด (OFF)"), 1.2)
	_refresh_hud()


func _refresh_fx_and_shake_btns():
	var fx_red := bool(save_data.get("fx_reduced", false))
	VfxStudio.set_fx_reduced(fx_red)
	if codex_fx_btn:
		codex_fx_btn.text = "✨ เอฟเฟกต์: ลดแสง" if fx_red else "✨ เอฟเฟกต์: ปกติ"
		codex_fx_btn.add_theme_color_override("font_color", Color("#5eead4") if fx_red else Color("#e2e8f0"))
	var sm := str(save_data.get("shake_mode", "normal"))
	if codex_shake_btn:
		var slbl := "ปกติ" if sm == "normal" else ("เบา" if sm == "low" else "ปิด")
		codex_shake_btn.text = "📳 สั่นจอ: %s" % slbl
		codex_shake_btn.add_theme_color_override("font_color", Color("#fde047") if sm != "normal" else Color("#e2e8f0"))


func _toggle_fx_reduced():
	var next_v := not bool(save_data.get("fx_reduced", false))
	save_data["fx_reduced"] = next_v
	SaveManager.save_data(save_data, save_path)
	_refresh_fx_and_shake_btns()
	_show_banner("✨ ความเข้มเอฟเฟกต์: %s" % ("โหมดลดแสง (อ่านสนามชัด + ประหยัดเครื่อง)" if next_v else "ปกติ"), 1.6)


func _toggle_shake_mode():
	var order := ["normal", "low", "off"]
	var cur := str(save_data.get("shake_mode", "normal"))
	var idx := (order.find(cur) + 1) % order.size()
	var nxt: String = order[idx]
	save_data["shake_mode"] = nxt
	SaveManager.save_data(save_data, save_path)
	_refresh_fx_and_shake_btns()
	var desc := "ปกติ (100%)" if nxt == "normal" else ("ลดการสั่น (35%)" if nxt == "low" else "ปิดการสั่น (0%)")
	_show_banner("📳 การสั่นหน้าจอ: %s" % desc, 1.5)


func _return_to_hub():
	Engine.time_scale = 1.0
	end_overlay.visible = false
	_open_codex_tab(0)


func _attach_boss_phase2_aura(e: CharacterBody2D):
	if not is_instance_valid(e) or e.has_node("Phase2Aura"):
		return
	var aura := Node2D.new()
	aura.name = "Phase2Aura"
	aura.position = Vector2(0.0, -56.0)
	aura.z_index = -1
	var outer_r := Line2D.new()
	var pts1 := VfxStudio._make_star_poly(88.0, 56.0, 10)
	pts1.append(pts1[0])
	outer_r.points = pts1
	outer_r.width = 3.2
	outer_r.default_color = Color(1.0, 0.34, 0.14, 0.85)
	aura.add_child(outer_r)
	var inner_r := Line2D.new()
	var pts2 := VfxStudio._make_star_poly(66.0, 42.0, 8)
	pts2.append(pts2[0])
	inner_r.points = pts2
	inner_r.width = 2.4
	inner_r.default_color = Color(0.24, 0.92, 0.88, 0.78)
	aura.add_child(inner_r)
	e.add_child(aura)


func _free_telegraph_nodes(tinfo: Dictionary):
	if tinfo.has("node") and is_instance_valid(tinfo["node"]):
		(tinfo["node"] as Node).queue_free()
	if tinfo.has("nodes") and typeof(tinfo["nodes"]) == TYPE_ARRAY:
		for n in tinfo["nodes"]:
			if is_instance_valid(n):
				(n as Node).queue_free()


func _cancel_telegraphs_for(caster: Object):
	for t in active_telegraphs.duplicate():
		if typeof(t) == TYPE_DICTIONARY and t.get("caster") == caster:
			_free_telegraph_nodes(t)
			active_telegraphs.erase(t)


func _clear_all_telegraphs():
	for t in active_telegraphs.duplicate():
		if typeof(t) == TYPE_DICTIONARY:
			_free_telegraph_nodes(t)
	active_telegraphs.clear()


func _make_danger_zone_visual(target_pos: Vector2, radius: float, y_aspect: float = 0.72) -> Dictionary:
	# Floor fill stays beneath character sprites while crisp bright rim stays readable above spell clutter
	var root_n := Node2D.new()
	root_n.position = target_pos
	root_n.z_index = 6
	floor_layer.add_child(root_n)

	var outer := Polygon2D.new()
	outer.polygon = _make_ellipse(radius, radius * y_aspect, 32)
	outer.color = Color(0.95, 0.16, 0.22, 0.16)
	root_n.add_child(outer)

	var inner := Polygon2D.new()
	inner.polygon = _make_ellipse(radius, radius * y_aspect, 32)
	inner.color = Color(0.98, 0.24, 0.28, 0.34)
	inner.scale = Vector2(0.05, 0.05)
	root_n.add_child(inner)

	var rim := Line2D.new()
	var rpts := _make_ellipse(radius, radius * y_aspect, 36)
	rpts.append(rpts[0])
	rim.points = rpts
	rim.width = 2.8
	rim.default_color = Color(1.0, 0.38, 0.28, 0.92)
	root_n.add_child(rim)
	return {"root": root_n, "inner": inner, "rim": rim}


func _process_telegraphs(delta: float):
	for t in active_telegraphs.duplicate():
		if typeof(t) != TYPE_DICTIONARY or not t.has("type"):
			continue
		var caster_v: Variant = t.get("caster", null)
		var req_caster: bool = bool(t.get("require_caster", true))
		if req_caster:
			if not is_instance_valid(caster_v) or bool((caster_v as Object).get_meta("is_dead", false)):
				_free_telegraph_nodes(t)
				active_telegraphs.erase(t)
				continue
		var elapsed := float(t.get("elapsed", 0.0)) + delta
		var dur := maxf(float(t.get("duration", 0.5)), 0.05)
		t["elapsed"] = elapsed
		var prog := clampf(elapsed / dur, 0.0, 1.0)
		var ttype := str(t["type"])
		if ttype == "slam" or ttype == "hazard_ring":
			if t.has("inner") and is_instance_valid(t["inner"]):
				(t["inner"] as Node2D).scale = Vector2(lerpf(0.08, 1.0, prog), lerpf(0.08, 1.0, prog))
		elif ttype == "furnace_pillars":
			if t.has("inners"):
				for in_n in t["inners"]:
					if is_instance_valid(in_n):
						(in_n as Node2D).scale = Vector2(lerpf(0.08, 1.0, prog), lerpf(0.08, 1.0, prog))
		elif ttype == "wave_fan" or ttype == "laser":
			if t.has("node") and is_instance_valid(t["node"]):
				(t["node"] as CanvasItem).modulate.a = lerpf(0.45, 1.0, prog)

		if elapsed >= dur:
			active_telegraphs.erase(t)
			if ttype == "slam":
				_execute_slam(caster_v, t["pos"], float(t["radius"]), int(t["dmg"]), t.get("node"), {})
			elif ttype == "wave_fan":
				_free_telegraph_nodes(t)
				_fire_boss_waves(caster_v, t["dir"])
			elif ttype == "furnace_pillars":
				_execute_furnace_pillars(caster_v, t["centers"], float(t["pillar_radius"]), int(t["dmg"]), t)
			elif ttype == "laser":
				_fire_laser_beam(caster_v, t["dir"], t.get("node"))
			elif ttype == "eight_dir_storm":
				_execute_eight_dir_storm(caster_v, t["center"], t.get("node"))
			elif ttype == "hazard_ring":
				_free_telegraph_nodes(t)
				if not game_over and not victory:
					var hpos: Vector2 = t["pos"]
					var hrad: float = float(t["radius"])
					var hcol: Color = t["col"]
					_spawn_ring_vfx(hpos, hcol, hrad + 4.0)
					if player.global_position.distance_to(hpos) <= hrad and invuln_timer <= 0.0:
						_enemy_hit_player(16, hpos, false)


func _start_slam_telegraph(e: CharacterBody2D, radius: float, dmg: int, windup: float):
	e.set_meta("cast_pose", "slam")
	e.set_meta("casting", windup)
	sfx.play_sfx("boss_warn")
	var target_pos: Vector2 = player.global_position if bool(MONSTER_DEFS.get(str(e.get_meta("kind")), {}).get("is_boss", false)) else e.global_position
	var vis := _make_danger_zone_visual(target_pos, radius, 0.72)
	var tinfo := {
		"type": "slam",
		"caster": e,
		"require_caster": true,
		"pos": target_pos,
		"radius": radius,
		"dmg": dmg,
		"elapsed": 0.0,
		"duration": windup,
		"node": vis["root"],
		"inner": vis["inner"],
	}
	active_telegraphs.append(tinfo)


func _execute_slam(e: Variant, pos: Vector2, radius: float, dmg: int, warn_node: Variant, tinfo: Dictionary = {}):
	if not tinfo.is_empty():
		active_telegraphs.erase(tinfo)
	if is_instance_valid(warn_node):
		(warn_node as Node).queue_free()
	if not is_instance_valid(e) or bool((e as Object).get_meta("is_dead", false)) or game_over or victory:
		return
	var eb := e as CharacterBody2D
	eb.set_meta("casting", 0.0)
	eb.set_meta("attack_pose_timer", 0.24)
	eb.set_meta("recovery_timer", 0.85 if bool(MONSTER_DEFS.get(str(eb.get_meta("kind")), {}).get("is_boss", false)) else 0.65)
	sfx.play_sfx("boss_slam")
	shake_strength = 13.5
	var cdata := ChapterData.get_chapter(chapter)
	VfxStudio.spawn_critical_star_burst(fx_layer, pos, cdata["light_color"], 1.25)
	_spawn_ring_vfx(pos, Color("#f43f5e"), radius)
	_spawn_burst_vfx(pos, "res://assets/vfx/vfx_firaga.png", 1.2)

	# Visual hit radius matches exact 1:1 ellipse/circle radius shown on telegraph
	var d_vec := player.global_position - pos
	var norm_ell := Vector2(d_vec.x / maxf(radius, 1.0), d_vec.y / maxf(radius * 0.72, 1.0)).length()
	if norm_ell <= 1.0:
		if combat.can_trigger_perfect_dodge():
			_activate_perfect_dodge()
		elif invuln_timer > 0.0:
			sfx.play_sfx("dodge")
			_award_spirit_jade(4)
			_spawn_floating_text(player.global_position + Vector2(0, -56), "⚡ หลบพ้น! +4 💎", Color("#2dd4bf"), true)
		else:
			_enemy_hit_player(dmg, pos, true)


func _start_boss_wave_attack(e: CharacterBody2D, dir: Vector2):
	var clean_dir := dir.normalized() if dir.length() > 0.05 else Vector2.LEFT
	var is_p2 := bool(e.get_meta("phase2_done", false))
	var windup := 0.56 if is_p2 else 0.68
	e.set_meta("cast_pose", "wave")
	e.set_meta("casting", windup)
	sfx.play_sfx("boss_warn")

	var angles := [-0.46, -0.23, 0.0, 0.23, 0.46] if (e.get_meta("kind") == "boss_ch2" or is_p2) else [-0.28, 0.0, 0.28]
	var lane_root := Node2D.new()
	lane_root.z_index = 6
	floor_layer.add_child(lane_root)
	for ang in angles:
		var ld := clean_dir.rotated(ang)
		var ln := Line2D.new()
		ln.points = PackedVector2Array([e.global_position + ld * 30.0, e.global_position + ld * 430.0])
		ln.width = 16.0
		ln.default_color = Color(1.0, 0.32, 0.20, 0.22)
		lane_root.add_child(ln)
		var core_ln := Line2D.new()
		core_ln.points = ln.points
		core_ln.width = 2.5
		core_ln.default_color = Color(1.0, 0.68, 0.30, 0.82)
		lane_root.add_child(core_ln)

	active_telegraphs.append({
		"type": "wave_fan",
		"caster": e,
		"require_caster": true,
		"pos": e.global_position + clean_dir * 140.0,
		"radius": 135.0,
		"dir": clean_dir,
		"elapsed": 0.0,
		"duration": windup,
		"node": lane_root,
	})


func _fire_boss_waves(e: Variant, dir: Vector2):
	if not is_instance_valid(e) or bool((e as Object).get_meta("is_dead", false)) or game_over or victory:
		return
	var eb := e as CharacterBody2D
	eb.set_meta("casting", 0.0)
	eb.set_meta("attack_pose_timer", 0.24)
	eb.set_meta("recovery_timer", 0.72)
	sfx.play_sfx("boss_slam")
	var is_p2 := bool(eb.get_meta("phase2_done", false))
	var angles := [-0.46, -0.23, 0.0, 0.23, 0.46] if (eb.get_meta("kind") == "boss_ch2" or is_p2) else [-0.28, 0.0, 0.28]
	for ang in angles:
		var d := dir.rotated(ang)
		var p := Sprite2D.new()
		p.texture = load("res://assets/vfx/vfx_whip_blood_chain.png")
		p.position = eb.global_position + d * 36.0
		p.rotation = d.angle()
		p.scale = Vector2(0.85, 0.85)
		p.modulate = Color("#fb7185") if not is_p2 else Color("#fb923c")
		p.set_meta("vel", d * (420.0 if is_p2 else 380.0))
		p.set_meta("dmg", 24 if is_p2 else 22)
		p.set_meta("life", 1.55)
		fx_layer.add_child(p)
		enemy_projectiles.append(p)


func _start_furnace_pillars(e: CharacterBody2D, is_p2: bool):
	# Pattern 3 of Furnace Guardian: Multi-pillar Soul-Furnace Eruption followed by Overheat Counter Window!
	var windup := 0.78 if is_p2 else 0.95
	var p_rad := 84.0
	e.set_meta("cast_pose", "slam")
	e.set_meta("casting", windup)
	sfx.play_sfx("boss_warn")

	var cnt := 6 if is_p2 else 4
	var base_center := player.global_position
	var room_min_x := float(current_room * ROOM_STRIDE + 2) * TILE_SIZE
	var room_max_x := float(current_room * ROOM_STRIDE + 14) * TILE_SIZE
	var centers: Array[Vector2] = []
	var nodes: Array = []
	var inners: Array = []
	for i in range(cnt):
		var a := (float(i) / float(cnt)) * TAU + (0.35 if is_p2 else 0.0)
		var ring_d := 118.0 if (i % 2 == 0) else 165.0
		var cpos := base_center + Vector2(cos(a) * ring_d, sin(a) * ring_d * 0.68)
		cpos.x = clampf(cpos.x, room_min_x, room_max_x)
		cpos.y = clampf(cpos.y, 2.1 * TILE_SIZE, 6.9 * TILE_SIZE)
		centers.append(cpos)
		var vis := _make_danger_zone_visual(cpos, p_rad, 0.72)
		nodes.append(vis["root"])
		inners.append(vis["inner"])

	active_telegraphs.append({
		"type": "furnace_pillars",
		"caster": e,
		"require_caster": true,
		"pos": base_center,
		"radius": 180.0,
		"centers": centers,
		"pillar_radius": p_rad,
		"dmg": 32 if is_p2 else 28,
		"elapsed": 0.0,
		"duration": windup,
		"nodes": nodes,
		"inners": inners,
	})


func _execute_furnace_pillars(e: Variant, centers: Array, p_rad: float, dmg: int, tinfo: Dictionary):
	_free_telegraph_nodes(tinfo)
	if not is_instance_valid(e) or bool((e as Object).get_meta("is_dead", false)) or game_over or victory:
		return
	var eb := e as CharacterBody2D
	eb.set_meta("casting", 0.0)
	eb.set_meta("attack_pose_timer", 0.26)
	# Reward dodging Pattern 3 with a generous 1.55s Overheat Vulnerable Counter Window (+25% dmg taken)!
	eb.set_meta("recovery_timer", 1.55)
	eb.set_meta("vuln_open", 1.55)
	sfx.play_sfx("boss_slam")
	shake_strength = 12.0
	var hit_player := false
	for cpos_v in centers:
		var cpos: Vector2 = cpos_v
		_spawn_ring_vfx(cpos, Color("#fb923c"), p_rad)
		_spawn_burst_vfx(cpos, "res://assets/vfx/vfx_firaga.png", 0.92)
		var dv := player.global_position - cpos
		var nell := Vector2(dv.x / p_rad, dv.y / (p_rad * 0.72)).length()
		if nell <= 1.0:
			hit_player = true
	if hit_player:
		if combat.can_trigger_perfect_dodge():
			_activate_perfect_dodge()
		elif invuln_timer > 0.0:
			sfx.play_sfx("dodge")
			_award_spirit_jade(4)
			_spawn_floating_text(player.global_position + Vector2(0, -56), "⚡ หลบเสาเพลิงพ้น! +4 💎", Color("#2dd4bf"), true)
		else:
			_enemy_hit_player(dmg, eb.global_position, true)
	_spawn_floating_text(eb.global_position + Vector2(0, -110), "⚡ เตาหลอมคลายความร้อน — สวนกลับ!", Color("#5eead4"), true)


func _process_enemy_projectiles(delta: float):
	for p in enemy_projectiles.duplicate():
		if not is_instance_valid(p):
			enemy_projectiles.erase(p)
			continue
		p.position += p.get_meta("vel") * delta
		p.set_meta("life", p.get_meta("life") - delta)
		if p.get_meta("life") <= 0.0:
			enemy_projectiles.erase(p)
			p.queue_free()
			continue
		if player.global_position.distance_to(p.global_position) < 32.0:
			if combat.can_trigger_perfect_dodge():
				_activate_perfect_dodge()
			elif invuln_timer > 0.0:
				sfx.play_sfx("dodge")
				_spawn_floating_text(player.global_position + Vector2(0, -56), "⚡ หลบพ้น!", Color("#2dd4bf"), false)
			else:
				_enemy_hit_player(p.get_meta("dmg"), p.global_position, true)
			enemy_projectiles.erase(p)
			p.queue_free()


func _spawn_enemy_orb(pos: Vector2, dir: Vector2, dmg: int):
	var p := Sprite2D.new()
	p.texture = load("res://assets/vfx/vfx_proj_talisman.png")
	p.position = pos + dir * 24.0
	p.rotation = dir.angle()
	p.scale = Vector2(0.75, 0.75)
	p.modulate = Color("#ef4444")
	p.set_meta("vel", dir * 320.0)
	p.set_meta("dmg", dmg)
	p.set_meta("life", 2.0)
	fx_layer.add_child(p)
	enemy_projectiles.append(p)


func _make_gear_poly(outer_r: float, inner_r: float, teeth_cnt: int) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var total := teeth_cnt * 2
	for i in range(total):
		var a := (float(i) / float(total)) * TAU
		var r := outer_r if (i % 2 == 0) else inner_r
		pts.append(Vector2(cos(a) * r, sin(a) * r))
	return pts


func _spawn_sawblade_trap(pos: Vector2):
	var saw := Node2D.new()
	saw.position = pos
	var disc := Polygon2D.new()
	disc.polygon = _make_gear_poly(32.0, 19.0, 10)
	disc.color = Color("#cbd5e1")
	saw.add_child(disc)
	var core := Polygon2D.new()
	core.polygon = _make_ellipse(11.0, 11.0, 12)
	core.color = Color("#ef4444")
	saw.add_child(core)
	var ring := Line2D.new()
	var rpts := _make_ellipse(35.0, 35.0, 24)
	rpts.append(rpts[0])
	ring.points = rpts
	ring.width = 2.0
	ring.default_color = Color(0.95, 0.25, 0.28, 0.45)
	saw.add_child(ring)
	saw.set_meta("player_cd", 0.0)
	floor_layer.add_child(saw)
	sawblades.append(saw)


func _process_sawblades(delta: float):
	for s in sawblades:
		if not is_instance_valid(s):
			continue
		s.rotation += 6.5 * delta
		var pcd := float(s.get_meta("player_cd", 0.0)) - delta
		s.set_meta("player_cd", maxf(0.0, pcd))
		if pcd <= 0.0 and player.global_position.distance_to(s.global_position) < 34.0 and invuln_timer <= 0.0:
			s.set_meta("player_cd", 0.85)
			_enemy_hit_player(14, s.global_position, false)
		for e in enemies.duplicate():
			if not is_instance_valid(e):
				continue
			if float(e.get_meta("trap_cd", 0.0)) <= 0.0 and e.global_position.distance_to(s.global_position) < 42.0:
				e.set_meta("trap_cd", 0.75)
				_damage_enemy(e, 38, (e.global_position - s.global_position).normalized(), Color("#fca5a5"), 0.15, false)

	for ob in orbit_blades:
		if not is_instance_valid(ob):
			continue
		var center: Vector2 = ob.get_meta("center")
		var ang: float = float(ob.get_meta("angle")) + 2.2 * delta
		var rad: float = float(ob.get_meta("radius"))
		ob.set_meta("angle", ang)
		ob.position = center + Vector2(cos(ang), sin(ang) * 0.65) * rad
		ob.rotation += 8.0 * delta
		if player.global_position.distance_to(ob.global_position) < 34.0 and invuln_timer <= 0.0:
			_enemy_hit_player(18, ob.global_position, true)


func _spawn_orbit_blades(center: Vector2):
	for i in range(3):
		var ob := Node2D.new()
		var disc := Polygon2D.new()
		disc.polygon = _make_gear_poly(28.0, 16.0, 8)
		disc.color = Color("#f43f5e")
		ob.add_child(disc)
		var core := Polygon2D.new()
		core.polygon = _make_ellipse(9.0, 9.0, 10)
		core.color = Color("#fde047")
		ob.add_child(core)
		ob.set_meta("center", center)
		ob.set_meta("angle", (float(i) / 3.0) * TAU)
		ob.set_meta("radius", 165.0)
		fx_layer.add_child(ob)
		orbit_blades.append(ob)


func _start_laser_telegraph(e: CharacterBody2D, dir: Vector2):
	var clean_dir := dir.normalized() if dir.length() > 0.05 else Vector2.LEFT
	e.set_meta("cast_pose", "wave")
	e.set_meta("casting", 0.80)
	sfx.play_sfx("laser_warn")
	var line := Line2D.new()
	line.points = PackedVector2Array([e.global_position, e.global_position + clean_dir * 520.0])
	line.width = 8.0
	line.default_color = Color(1.0, 0.24, 0.28, 0.78)
	line.z_index = 7
	floor_layer.add_child(line)
	active_telegraphs.append({
		"type": "laser",
		"caster": e,
		"require_caster": true,
		"pos": e.global_position + clean_dir * 160.0,
		"radius": 140.0,
		"dir": clean_dir,
		"elapsed": 0.0,
		"duration": 0.80,
		"node": line,
	})


func _fire_laser_beam(e: Variant, dir: Vector2, line: Variant):
	if is_instance_valid(line):
		(line as Node).queue_free()
	if not is_instance_valid(e) or bool((e as Object).get_meta("is_dead", false)) or game_over or victory:
		return
	var eb := e as CharacterBody2D
	eb.set_meta("casting", 0.0)
	eb.set_meta("attack_pose_timer", 0.22)
	eb.set_meta("recovery_timer", 0.70)
	sfx.play_sfx("boss_slam")
	for ang in [-0.14, 0.0, 0.14]:
		_spawn_enemy_orb(eb.global_position, dir.rotated(ang), 24)


func _start_eight_dir_storm(e: CharacterBody2D):
	e.set_meta("cast_pose", "slam")
	e.set_meta("casting", 1.10)
	sfx.play_sfx("boss_warn")
	var center := Vector2((7.5 + float(current_room * ROOM_STRIDE)) * TILE_SIZE, 4.5 * TILE_SIZE)
	var danger := Node2D.new()
	danger.position = center
	danger.z_index = 6
	floor_layer.add_child(danger)

	var outer_rim := Line2D.new()
	var opts := _make_ellipse(340.0, 215.0, 36)
	opts.append(opts[0])
	outer_rim.points = opts
	outer_rim.width = 3.0
	outer_rim.default_color = Color(0.98, 0.26, 0.32, 0.78)
	danger.add_child(outer_rim)

	for spoke_i in range(8):
		var sang := (float(spoke_i) / 8.0) * TAU
		var sdir := Vector2(cos(sang), sin(sang))
		var spoke := Line2D.new()
		spoke.points = PackedVector2Array([sdir * 98.0, sdir * 230.0])
		spoke.width = 12.0
		spoke.default_color = Color(0.96, 0.22, 0.28, 0.28)
		danger.add_child(spoke)

	var safe := Polygon2D.new()
	safe.polygon = _make_ellipse(96.0, 96.0, 28)
	safe.color = Color(0.14, 0.88, 0.52, 0.26)
	danger.add_child(safe)

	var safe_rim := Line2D.new()
	var spts := _make_ellipse(96.0, 96.0, 32)
	spts.append(spts[0])
	safe_rim.points = spts
	safe_rim.width = 3.0
	safe_rim.default_color = Color(0.35, 0.98, 0.62, 0.95)
	danger.add_child(safe_rim)

	var safe_lbl := Label.new()
	safe_lbl.text = "🟢 เขตปลอดภัย!"
	safe_lbl.position = Vector2(-58.0, -12.0)
	safe_lbl.add_theme_font_size_override("font_size", 14)
	safe_lbl.add_theme_color_override("font_color", Color("#a7f3d0"))
	safe_lbl.add_theme_color_override("font_outline_color", Color(0.02, 0.08, 0.06, 0.96))
	safe_lbl.add_theme_constant_override("outline_size", 4)
	danger.add_child(safe_lbl)

	active_telegraphs.append({
		"type": "eight_dir_storm",
		"caster": e,
		"require_caster": true,
		"pos": player.global_position,
		"radius": 220.0,
		"center": center,
		"elapsed": 0.0,
		"duration": 1.10,
		"node": danger,
	})


func _trigger_chapter_hazard():
	if game_over or victory or enemies.size() == 0:
		return
	var cdata := ChapterData.get_chapter(chapter)
	var htype := str(cdata["hazard"])
	var lcol: Color = cdata["light_color"]
	if htype == "poison_mist":
		_spawn_ring_vfx(player.global_position, Color("#4ade80"), 140.0)
		if active_hero_id != "song_ren" and invuln_timer <= 0.0:
			hero_hp[active_hero_id] = maxf(1.0, hero_hp[active_hero_id] - 8.0)
			_spawn_floating_text(player.global_position + Vector2(0, -54), "☠️ หมอกพิษ -8", Color("#4ade80"), false)
	elif htype == "mountain_wind":
		player.global_position.x -= 42.0
		_spawn_floating_text(player.global_position + Vector2(0, -54), "🌬️ ลมเมฆาพัดผลัก!", Color("#38bdf8"), false)
	else:
		var target_pos := player.global_position
		var vis := _make_danger_zone_visual(target_pos, 78.0, 0.72)
		active_telegraphs.append({
			"type": "hazard_ring",
			"caster": null,
			"require_caster": false,
			"pos": target_pos,
			"radius": 78.0,
			"col": lcol,
			"elapsed": 0.0,
			"duration": 0.75,
			"node": vis["root"],
			"inner": vis["inner"],
		})


func _execute_eight_dir_storm(e: Variant, center: Vector2, warn_node: Variant):
	if is_instance_valid(warn_node):
		(warn_node as Node).queue_free()
	if not is_instance_valid(e) or bool((e as Object).get_meta("is_dead", false)) or game_over or victory:
		return
	var eb := e as CharacterBody2D
	eb.set_meta("casting", 0.0)
	eb.set_meta("attack_pose_timer", 0.28)
	eb.set_meta("recovery_timer", 1.35)
	eb.set_meta("vuln_open", 1.35)
	sfx.play_sfx("ultimate")
	shake_strength = 14.0
	var cdata := ChapterData.get_chapter(chapter)
	VfxStudio.spawn_boss_ultimate_vfx(floor_layer, fx_layer, eb.global_position, chapter, cdata["light_color"])
	for i in range(8):
		var a := (float(i) / 8.0) * TAU
		_spawn_enemy_orb(eb.global_position, Vector2(cos(a), sin(a)), 26)
	var d := player.global_position.distance_to(center)
	if d <= 96.0:
		sfx.play_sfx("dodge")
		_award_spirit_jade(5)
		_spawn_floating_text(player.global_position + Vector2(0, -56), "⚡ หลบพายุพ้น! +5 💎", Color("#4ade80"), true)
	elif invuln_timer <= 0.0:
		_enemy_hit_player(34, center, true)


func _award_spirit_jade(base_amt: int):
	var mult: float = (1.5 if str(save_data.get("difficulty", "normal")) == "hard" else 1.0) * combat.get_jade_multiplier()
	var gain := maxi(1, int(round(float(base_amt) * mult)))
	run_jade_earned += gain
	save_data["spirit_jade"] = int(save_data.get("spirit_jade", 0)) + gain
	SaveManager.save_data(save_data, save_path)
	_refresh_hud()


func _draw_minimap():
	if not minimap_ctrl:
		return
	var total := _total_rooms()
	var box_w := 14.0
	var gap := 4.0
	for r in range(total):
		var rect := Rect2(Vector2(float(r) * (box_w + gap), 4.0), Vector2(box_w, 16.0))
		var col := Color("#334155")
		if r == total - 1:
			col = Color("#ef4444")
		elif r == 4 or r == 8:
			col = Color("#f97316")
		elif cleared_rooms.has(r):
			col = Color("#22c55e")
		if r == current_room:
			col = Color("#fde047")
		minimap_ctrl.draw_rect(rect, col, true)
		minimap_ctrl.draw_rect(rect, Color.WHITE if r == current_room else Color(0.1, 0.1, 0.15), false, 1.5)


func _toggle_difficulty():
	var cur := str(save_data.get("difficulty", "normal"))
	save_data["difficulty"] = "hard" if cur == "normal" else "normal"
	SaveManager.save_data(save_data, save_path)
	_show_banner("เปลี่ยนความยาก: %s" % ("ท้าทายเทวราช (1.5x หยก)" if save_data["difficulty"] == "hard" else "ยุทธภพปกติ"), 1.6)
	_refresh_hud()


func _set_codex_tab(idx: int):
	codex_tab = clampi(idx, 0, 5)
	if codex_upgrade_scroll:
		codex_upgrade_scroll.visible = (codex_tab == 0)
	if codex_party_scroll:
		codex_party_scroll.visible = (codex_tab == 1)
	if codex_chapters_box:
		codex_chapters_box.visible = (codex_tab == 2)
	if codex_gear_scroll:
		codex_gear_scroll.visible = (codex_tab == 3)
	if codex_ach_scroll:
		codex_ach_scroll.visible = (codex_tab == 4)
	if codex_char_scroll:
		codex_char_scroll.visible = (codex_tab == 5)
	if codex_tab == 3:
		if gear_target_hid.is_empty() or not HeroData.HEROES.has(gear_target_hid):
			gear_target_hid = active_hero_id
		_rebuild_gear_list()
	elif codex_tab == 4 and codex_ach_box:
		CodexUI.rebuild_achievements_list(codex_ach_box, save_data)
	elif codex_tab == 5:
		_rebuild_character_status()
	for i in range(codex_tab_btns.size()):
		var b: Button = codex_tab_btns[i]
		if i == codex_tab:
			b.add_theme_color_override("font_color", Color("#fde047"))
		else:
			b.remove_theme_color_override("font_color")


func _toggle_help_overlay():
	if help_overlay:
		help_overlay.visible = not help_overlay.visible
		if help_overlay.visible:
			Engine.time_scale = 1.0
		elif not _is_modal_open():
			Engine.time_scale = game_speed_mult
		if not help_overlay.visible and sfx and sfx.has_method("resume_audio"):
			sfx.resume_audio()


func _open_boon_picker():
	if not boon_overlay:
		return
	if mobile_controls and mobile_controls.has_method("reset_joystick"):
		mobile_controls.reset_joystick()
	Engine.time_scale = 1.0
	var pool: Array = []
	for b in CodexUI.BOON_DEFS:
		if not active_boons.has(b["id"]):
			pool.append(b)
	if pool.size() < 3:
		pool = CodexUI.BOON_DEFS.duplicate()
	pool.shuffle()
	boon_choices = pool.slice(0, 3)
	for i in range(3):
		var b: Dictionary = boon_choices[i]
		boon_btns[i].text = "[%d] %s\n\n%s" % [i + 1, b["title"], b["desc"]]
	boon_overlay.visible = true


func _pick_boon(idx: int):
	if idx < 0 or idx >= boon_choices.size():
		return
	var chosen: Dictionary = boon_choices[idx]
	active_boons[chosen["id"]] = true
	boon_overlay.visible = false
	if mobile_controls and mobile_controls.has_method("reset_joystick"):
		mobile_controls.reset_joystick()
	if chosen["id"] == "jade_aegis":
		for hid in active_party:
			if hero_hp[hid] > 0.0:
				hero_hp[hid] = minf(_get_hero_stat(hid, "max_hp"), hero_hp[hid] + 25.0)
	sfx.play_sfx("resonance")
	_show_banner("⛩️ รับพรเซียน: %s!" % chosen["title"], 2.0)


func _start_boss_rush():
	Engine.time_scale = 1.0
	Globals.set_meta("chapter", 1)
	Globals.set_meta("boss_rush", true)
	Globals.set_meta("skip_intro", true)
	get_tree().reload_current_scene()


func _toggle_upgrade_modal():
	upgrade_overlay.visible = not upgrade_overlay.visible
	if upgrade_overlay.visible:
		Engine.time_scale = 1.0
		upgrade_overlay.move_to_front()
		_rebuild_upgrade_list()
		_refresh_cutin_btn()
	elif not _is_modal_open():
		Engine.time_scale = game_speed_mult


func _toggle_character_status_modal():
	if upgrade_overlay and upgrade_overlay.visible and codex_tab == 5:
		_toggle_upgrade_modal()
	else:
		char_status_selected_hid = active_hero_id
		_open_codex_tab(5)


func _is_cutin_fullscreen() -> bool:
	return cutin_overlay != null and cutin_overlay.is_fullscreen_playing()


func _is_boss_present() -> bool:
	for e in enemies.duplicate():
		if not is_instance_valid(e):
			continue
		var def: Dictionary = MONSTER_DEFS[str(e.get_meta("kind"))]
		if def["is_boss"] or def.get("is_miniboss", false):
			return true
	return false


func _get_cutin_mode() -> String:
	var m := str(save_data.get("cutin_mode", ""))
	if m in CUTIN_MODES:
		return m
	if save_data.has("cutin_enabled"):
		return "boss" if bool(save_data.get("cutin_enabled", true)) else "skip"
	return "boss"


func _should_play_fullscreen_cutin(mode: String) -> bool:
	if mode == "full":
		return true
	if mode == "boss":
		return _is_boss_present()
	return false


func _on_cutin_fullscreen_finished(_hid: String):
	sfx.set_bgm_ducked(false)
	if pending_ult_hero == "":
		return
	pending_ult_hero = ""
	if game_over or victory:
		return
	invuln_timer = maxf(invuln_timer, 1.0)
	_release_ultimate(HeroData.HEROES[active_hero_id])


func _refresh_cutin_btn():
	if not codex_cutin_btn:
		return
	var mode := _get_cutin_mode()
	codex_cutin_btn.text = str(CUTIN_MODE_LABELS[mode])
	codex_cutin_btn.add_theme_color_override("font_color", Color("#94a3b8") if mode == "skip" else (Color("#fbbf24") if mode == "boss" else Color("#38bdf8")))


func _toggle_cutin():
	var idx := CUTIN_MODES.find(_get_cutin_mode())
	var mode: String = CUTIN_MODES[(idx + 1) % CUTIN_MODES.size()]
	save_data["cutin_mode"] = mode
	save_data["cutin_enabled"] = mode != "skip"
	SaveManager.save_data(save_data, save_path)
	_refresh_cutin_btn()
	_show_banner(str(CUTIN_MODE_BANNERS[mode]), 1.6)


func _refresh_bgm_btn():
	if not codex_bgm_btn:
		return
	var enabled := bool(save_data.get("bgm_enabled", true))
	codex_bgm_btn.text = "🎵 เพลง: เปิด" if enabled else "🔇 เพลง: ปิด"
	codex_bgm_btn.add_theme_color_override("font_color", Color("#86efac") if enabled else Color("#94a3b8"))


func _toggle_bgm():
	var next_val := not bool(save_data.get("bgm_enabled", true))
	save_data["bgm_enabled"] = next_val
	SaveManager.save_data(save_data, save_path)
	sfx.set_bgm_enabled(next_val)
	_refresh_bgm_btn()
	_show_banner("เพลงประกอบฉาก: %s" % ("เปิด" if next_val else "ปิด"), 1.3)


func _open_codex_tab(tab_idx: int):
	if help_overlay:
		help_overlay.visible = false
	if sfx and sfx.has_method("resume_audio"):
		sfx.resume_audio()
	if upgrade_overlay and not upgrade_overlay.visible:
		_toggle_upgrade_modal()
	_set_codex_tab(tab_idx)


func _rebuild_upgrade_list():
	CodexUI.rebuild_lists(upgrade_list_box, codex_party_box, upgrade_jade_lbl, save_data, active_party, {
		"buy_core": _buy_core_upgrade,
		"buy_passive": _buy_hero_passive,
		"toggle_party": _toggle_party_member,
		"toggle_costume": _toggle_hero_costume,
	})
	CodexUI.refresh_chapters(codex_chapter_btns, chapter, save_data.get("cleared_chapters", []))


func _rebuild_party_hud():
	if portrait_row == null:
		return
	for c in portrait_row.get_children():
		c.queue_free()
	hero_cards.clear()
	for i in range(active_party.size()):
		var hid: String = active_party[i]
		var card := PanelContainer.new()
		card.custom_minimum_size = Vector2(54, 54)
		var btn := Button.new()
		btn.flat = true
		btn.custom_minimum_size = Vector2(50, 50)
		btn.pressed.connect(_switch_hero.bind(hid, true))
		var tex_rect := TextureRect.new()
		tex_rect.texture = _get_hero_tex(hid, "portrait")
		tex_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tex_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
		btn.add_child(tex_rect)
		var key_lbl := Label.new()
		key_lbl.text = str(i + 1)
		key_lbl.add_theme_font_size_override("font_size", 12)
		key_lbl.add_theme_color_override("font_color", Color("#fde047"))
		key_lbl.position = Vector2(3, 1)
		btn.add_child(key_lbl)
		card.add_child(btn)
		var swap_badge := Label.new()
		swap_badge.name = "SwapStatusBadge"
		swap_badge.text = "R!"
		swap_badge.add_theme_font_size_override("font_size", 11)
		swap_badge.add_theme_color_override("font_outline_color", Color.BLACK)
		swap_badge.add_theme_constant_override("outline_size", 3)
		swap_badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		swap_badge.position = Vector2(22, 32)
		swap_badge.size = Vector2(24, 16)
		swap_badge.visible = false
		card.add_child(swap_badge)
		portrait_row.add_child(card)
		hero_cards[hid] = card


func _toggle_party_member(hid: String):
	var idx := active_party.find(hid)
	if idx != -1:
		# Move to slot 0 (leader) if not already leader
		if idx != 0:
			active_party.remove_at(idx)
			active_party.insert(0, hid)
	else:
		# Rotate reserve slots so multiple newly-picked heroes stay in the party
		if active_party.size() >= 3:
			active_party[1] = active_party[2]
			active_party[2] = hid
		else:
			active_party.append(hid)
	save_data["party"] = active_party.duplicate()
	SaveManager.save_data(save_data, save_path)
	if not active_party.has(active_hero_id):
		_switch_hero(active_party[0], false)
	elif active_party[0] == hid and active_hero_id != hid:
		_switch_hero(hid, false)
	_rebuild_party_hud()
	_refresh_hud()
	_rebuild_upgrade_list()


func _toggle_hero_costume(hid: String):
	if not save_data.has("costumes") or typeof(save_data["costumes"]) != TYPE_DICTIONARY:
		save_data["costumes"] = {}
	var cur := str(save_data["costumes"].get(hid, "default"))
	save_data["costumes"][hid] = "default" if cur == "alt" else "alt"
	SaveManager.save_data(save_data, save_path)
	if active_hero_id == hid:
		if _has_4dir_sheet(hid):
			_set_player_strip(_get_hero_tex(hid, walk_dir_key, player_sprite.texture), 3, 0)
		else:
			_set_player_strip(_get_hero_tex(hid, "stride_0", player_sprite.texture), 1, 0)
	_rebuild_party_hud()
	_refresh_hud()
	_rebuild_upgrade_list()


func _buy_core_upgrade(key: String):
	var cu: Dictionary = save_data["core_upgrades"]
	var lv := int(cu.get(key, 0))
	var cost := SaveManager.get_core_cost(key, lv)
	if lv < SaveManager.get_core_max_lv(key) and int(save_data["spirit_jade"]) >= cost:
		save_data["spirit_jade"] = int(save_data["spirit_jade"]) - cost
		cu[key] = lv + 1
		SaveManager.save_data(save_data, save_path)
		sfx.play_sfx("crit")
		_init_hero_stats()
		_refresh_hud()
		_rebuild_upgrade_list()


func _buy_hero_passive(hid: String):
	var hp_passives: Dictionary = save_data["hero_passives"]
	var cost := SaveManager.get_passive_cost()
	if int(hp_passives.get(hid, 0)) == 0 and int(save_data["spirit_jade"]) >= cost:
		save_data["spirit_jade"] = int(save_data["spirit_jade"]) - cost
		hp_passives[hid] = 1
		SaveManager.save_data(save_data, save_path)
		sfx.play_sfx("resonance")
		_refresh_hud()
		_rebuild_upgrade_list()


func _jump_to_chapter(ch_idx: int):
	Engine.time_scale = 1.0
	Globals.set_meta("chapter", ch_idx)
	get_tree().reload_current_scene()


func _show_boss_warning(boss_title: String, is_miniboss: bool):
	if sfx:
		sfx.play_sfx("boss_warn")
	if screen_flash:
		screen_flash.color = Color(0.95, 0.35, 0.15, 0.28) if not is_miniboss else Color(0.95, 0.65, 0.15, 0.22)
		var tw := create_tween()
		tw.tween_property(screen_flash, "color:a", 0.0, 0.55)
	if boss_name_label:
		boss_name_label.add_theme_color_override("font_color", Color("#fbbf24") if is_miniboss else Color("#fda4af"))
	var prefix := "⚠️ มินิบอสปรากฏกาย!" if is_miniboss else "☠️ คำเตือนจอมมารปรากฏกาย!"
	_show_banner("%s — %s" % [prefix, boss_title], 3.0)


func _grant_boss_gear_drop(is_boss: bool):
	var owned: Array = save_data.get("owned_gear", []).duplicate()
	var candidates: Array = []
	for item_id in EquipData.get_drop_pool(chapter, is_boss):
		if not owned.has(item_id):
			candidates.append(item_id)
	if candidates.size() > 0:
		var drop_id: String = str(candidates[randi() % candidates.size()])
		owned.append(drop_id)
		run_drops.append(drop_id)
		save_data["owned_gear"] = owned
		SaveManager.save_data(save_data, save_path)
		_record_achievement("gear_collect_8", owned.size(), true)
		var it := EquipData.get_item(drop_id)
		_show_banner("🎁 ดรอปศาสตราวุธ [%s]: %s!" % [str(it.get("rarity", "")), str(it.get("name", drop_id))], 2.8)
	else:
		var bonus_jade := 25 if is_boss else 12
		_award_spirit_jade(bonus_jade)
		_show_banner("💎 ศาสตราวุธซ้ำ! แปลงเป็นหยกปราณ +%d 💎" % bonus_jade, 2.4)


func _apply_hero_max_stat_change(hid: String, old_max_hp: float, old_max_sp: float):
	if not HeroData.HEROES.has(hid):
		return
	var new_max_hp := _get_hero_stat(hid, "max_hp")
	var new_max_sp := _get_hero_stat(hid, "max_sp")
	var cur_hp := float(hero_hp.get(hid, new_max_hp))
	var cur_sp := float(hero_sp.get(hid, new_max_sp))
	if cur_hp <= 0.0:
		hero_hp[hid] = 0.0
	else:
		var hp_ratio := clampf(cur_hp / maxf(1.0, old_max_hp), 0.0, 1.0)
		hero_hp[hid] = clampf(round(new_max_hp * hp_ratio), 1.0, new_max_hp)
	var sp_ratio := clampf(cur_sp / maxf(1.0, old_max_sp), 0.0, 1.0)
	hero_sp[hid] = clampf(round(new_max_sp * sp_ratio), 0.0, new_max_sp)


func _sync_hero_armor_costume(hid: String, has_armor: bool):
	if not save_data.has("costumes") or typeof(save_data["costumes"]) != TYPE_DICTIONARY:
		save_data["costumes"] = {}
	save_data["costumes"][hid] = "alt" if has_armor else "default"
	if hid == active_hero_id and is_instance_valid(player_sprite):
		if _has_4dir_sheet(active_hero_id):
			_set_player_strip(_get_hero_tex(active_hero_id, walk_dir_key, player_sprite.texture), 3, 1)
		else:
			_set_player_strip(_get_hero_tex(active_hero_id, "stride_0", player_sprite.texture), 1, 0)


func _toggle_equip_gear(item_id: String, target_hid: String = ""):
	var it := EquipData.get_item(item_id)
	if it.is_empty():
		return
	var eff_hid := target_hid if (not target_hid.is_empty() and HeroData.HEROES.has(target_hid)) else active_hero_id
	var slot := str(it["slot"])
	var hg: Dictionary = save_data.get("hero_gear", {}).duplicate(true)
	var prev_holder := EquipData.find_item_holder(hg, item_id)
	var old_hp_target := _get_hero_stat(eff_hid, "max_hp")
	var old_sp_target := _get_hero_stat(eff_hid, "max_sp")
	var old_hp_prev := _get_hero_stat(prev_holder, "max_hp") if (not prev_holder.is_empty() and HeroData.HEROES.has(prev_holder)) else 0.0
	var old_sp_prev := _get_hero_stat(prev_holder, "max_sp") if (not prev_holder.is_empty() and HeroData.HEROES.has(prev_holder)) else 0.0

	var cur_slots: Dictionary = hg.get(eff_hid, {}).duplicate()
	var equipped_now := false
	var moved_from := ""
	if str(cur_slots.get(slot, "")) == item_id:
		cur_slots.erase(slot)
		equipped_now = false
	else:
		# Enforce 1-copy-per-hero ownership: cleanly move item if worn by another hero
		if not prev_holder.is_empty() and prev_holder != eff_hid:
			var other_slots: Dictionary = hg.get(prev_holder, {}).duplicate()
			other_slots.erase(slot)
			hg[prev_holder] = other_slots
			moved_from = prev_holder
		cur_slots[slot] = item_id
		equipped_now = true
	hg[eff_hid] = cur_slots
	save_data["hero_gear"] = hg
	gear_inspect_id = item_id

	if slot == "armor":
		_sync_hero_armor_costume(eff_hid, equipped_now)
		if not moved_from.is_empty():
			_sync_hero_armor_costume(moved_from, false)
		_rebuild_party_hud()

	SaveManager.save_data(save_data, save_path)
	_apply_hero_max_stat_change(eff_hid, old_hp_target, old_sp_target)
	if not moved_from.is_empty():
		_apply_hero_max_stat_change(moved_from, old_hp_prev, old_sp_prev)
		var from_name := str(HeroData.HEROES[moved_from]["name"])
		var to_name := str(HeroData.HEROES[eff_hid]["name"])
		_show_banner("🔄 ย้าย %s จาก %s มาสวมให้ %s!" % [str(it["name"]), from_name, to_name], 2.0)

	_rebuild_gear_list()
	_refresh_hud()


func _forge_gear_item(item_id: String):
	var it := EquipData.get_item(item_id)
	if it.is_empty():
		return
	var owned: Array = save_data.get("owned_gear", []).duplicate()
	if owned.has(item_id):
		return
	var cost := int(it.get("cost", 50))
	var jade := int(save_data.get("spirit_jade", 0))
	if jade < cost:
		_show_banner("หยกปราณไม่พอ! (ต้องการ %d 💎)" % cost, 1.5)
		return
	save_data["spirit_jade"] = jade - cost
	owned.append(item_id)
	save_data["owned_gear"] = owned
	SaveManager.save_data(save_data, save_path)
	_record_achievement("gear_collect_8", owned.size(), true)
	sfx.play_sfx("crit")
	_rebuild_gear_list()
	_refresh_hud()
	if upgrade_jade_lbl:
		upgrade_jade_lbl.text = "💎 หยกปราณคงเหลือ: %d" % int(save_data["spirit_jade"])


func _set_gear_filter(flt: String):
	gear_filter = flt
	_rebuild_gear_list()


func _enhance_gear_item(item_id: String):
	var owned: Array = save_data.get("owned_gear", [])
	if not owned.has(item_id):
		return
	var gl: Dictionary = save_data.get("gear_levels", {}).duplicate()
	var cur_lv := int(gl.get(item_id, 0))
	if cur_lv >= EquipData.MAX_ENHANCE_LV:
		return
	var cost := EquipData.get_enhance_cost(item_id, cur_lv)
	var jade := int(save_data.get("spirit_jade", 0))
	if jade < cost:
		_show_banner("หยกปราณไม่พอ! (ต้องการ %d 💎)" % cost, 1.5)
		return
	var old_hp_map := {}
	var old_sp_map := {}
	for hid in HeroData.HERO_ORDER:
		old_hp_map[hid] = _get_hero_stat(hid, "max_hp")
		old_sp_map[hid] = _get_hero_stat(hid, "max_sp")
	save_data["spirit_jade"] = jade - cost
	gl[item_id] = cur_lv + 1
	save_data["gear_levels"] = gl
	gear_inspect_id = item_id
	SaveManager.save_data(save_data, save_path)
	for hid in HeroData.HERO_ORDER:
		_apply_hero_max_stat_change(hid, float(old_hp_map[hid]), float(old_sp_map[hid]))
	if cur_lv + 1 >= EquipData.MAX_ENHANCE_LV:
		_record_achievement("enhance_plus5", 1, true)
	sfx.play_sfx("crit")
	_rebuild_gear_list()
	_refresh_hud()
	if upgrade_jade_lbl:
		upgrade_jade_lbl.text = "💎 หยกปราณคงเหลือ: %d" % int(save_data["spirit_jade"])


func _format_gear_delta(item_id: String, cur_lv: int) -> String:
	var cur := EquipData.get_scaled_item_stats(item_id, cur_lv)
	if cur_lv >= EquipData.MAX_ENHANCE_LV:
		var max_parts: Array[String] = []
		if int(cur["atk"]) > 0:
			max_parts.append("+%d ATK" % int(cur["atk"]))
		if int(cur["max_hp"]) > 0:
			max_parts.append("+%d HP" % int(cur["max_hp"]))
		if int(cur["max_sp"]) > 0:
			max_parts.append("+%d ปราณ" % int(cur["max_sp"]))
		if float(cur["crit"]) > 0.0:
			max_parts.append("+%d%% คริ" % int(round(float(cur["crit"]) * 100.0)))
		if float(cur["dmg_red"]) > 0.0:
			max_parts.append("ลดดาเมจ %d%%" % int(round(float(cur["dmg_red"]) * 100.0)))
		return " · ".join(max_parts) + " (MAX)"
	var nxt := EquipData.get_scaled_item_stats(item_id, cur_lv + 1)
	var parts: Array[String] = []
	if int(nxt["atk"]) > 0:
		parts.append("ATK +%d➔+%d" % [int(cur["atk"]), int(nxt["atk"])])
	if int(nxt["max_hp"]) > 0:
		parts.append("HP +%d➔+%d" % [int(cur["max_hp"]), int(nxt["max_hp"])])
	if int(nxt["max_sp"]) > 0:
		parts.append("ปราณ +%d➔+%d" % [int(cur["max_sp"]), int(nxt["max_sp"])])
	if float(nxt["crit"]) > 0.0:
		parts.append("คริ +%.1f%%➔+%.1f%%" % [float(cur["crit"]) * 100.0, float(nxt["crit"]) * 100.0])
	if float(nxt["dmg_red"]) > 0.0:
		parts.append("ลดดาเมจ %.1f%%➔%.1f%%" % [float(cur["dmg_red"]) * 100.0, float(nxt["dmg_red"]) * 100.0])
	return " · ".join(parts)


func _select_gear_target_hero(hid: String):
	if HeroData.HEROES.has(hid):
		gear_target_hid = hid
		_rebuild_gear_list()


func _inspect_gear_item(item_id: String):
	if EquipData.ITEMS.has(item_id):
		gear_inspect_id = item_id
		_rebuild_gear_list()


func _rebuild_gear_list():
	if not codex_gear_box:
		return
	for ch in codex_gear_box.get_children():
		ch.queue_free()
	var target_hid := gear_target_hid if (not gear_target_hid.is_empty() and HeroData.HEROES.has(gear_target_hid)) else active_hero_id
	gear_target_hid = target_hid
	var hdata: Dictionary = HeroData.HEROES[target_hid]
	var owned: Array = save_data.get("owned_gear", [])
	var hg_all: Dictionary = save_data.get("hero_gear", {})
	var cur_slots: Dictionary = hg_all.get(target_hid, {})
	var gl: Dictionary = save_data.get("gear_levels", {})
	var jade_now := int(save_data.get("spirit_jade", 0))
	if not EquipData.ITEMS.has(gear_inspect_id):
		gear_inspect_id = str(cur_slots.get("weapon", "jade_sword"))
		if not EquipData.ITEMS.has(gear_inspect_id):
			gear_inspect_id = "jade_sword"

	# 1. Hero Selector Bar + Clear Active Target Header
	var hero_sel_box := VBoxContainer.new()
	hero_sel_box.add_theme_constant_override("separation", 4)
	codex_gear_box.add_child(hero_sel_box)

	var hdr := Label.new()
	hdr.text = "🎯 กำลังจัดศาสตราวุธให้: %s (%s)%s  ·  กฎอุปกรณ์: 1 ชิ้นสวมได้ทีละ 1 ตัวละคร" % [
		str(hdata["name"]), str(hdata["title"]),
		(" [กำลังบังคับ]" if target_hid == active_hero_id else " [สลับตัวละครได้ด้านล่าง]")
	]
	hdr.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hdr.add_theme_font_size_override("font_size", 13)
	hdr.add_theme_color_override("font_color", Color("#fde047"))
	hero_sel_box.add_child(hdr)

	var hbar := HBoxContainer.new()
	hbar.add_theme_constant_override("separation", 4)
	hero_sel_box.add_child(hbar)
	for hid in HeroData.HERO_ORDER:
		var hi: Dictionary = HeroData.HEROES[hid]
		var hb := Button.new()
		var in_pty := active_party.has(hid)
		var is_t := (str(hid) == target_hid)
		var eq_cnt := 0
		var hs_d: Variant = hg_all.get(hid, {})
		if typeof(hs_d) == TYPE_DICTIONARY:
			for sk_c in EquipData.ALL_SLOTS:
				if not str((hs_d as Dictionary).get(sk_c, "")).is_empty():
					eq_cnt += 1
		hb.text = "%s%s (%d/3)" % [("★ " if in_pty else ""), str(hi["name"]).split(" ")[0], eq_cnt]
		hb.custom_minimum_size = Vector2(108, 30)
		hb.add_theme_font_size_override("font_size", 11)
		if is_t:
			hb.add_theme_color_override("font_color", Color("#fde047"))
		elif in_pty:
			hb.add_theme_color_override("font_color", Color("#4ade80"))
		hb.pressed.connect(_select_gear_target_hero.bind(str(hid)))
		hbar.add_child(hb)

	# 2. 3 Equipped Slot Cards Row (Weapon / Armor / Relic) + Set Bonus Condition Banner
	var slots_wrap := VBoxContainer.new()
	slots_wrap.add_theme_constant_override("separation", 5)
	codex_gear_box.add_child(slots_wrap)

	var slots_row := HBoxContainer.new()
	slots_row.name = "EquippedSlotsRow"
	slots_row.add_theme_constant_override("separation", 8)
	slots_wrap.add_child(slots_row)
	for s_cfg in [
		["weapon", "⚔️ ช่องอาวุธ"],
		["armor", "🛡️ ช่องเกราะ"],
		["relic", "🔮 ช่องเครื่องราง"],
	]:
		var sk_id: String = s_cfg[0]
		var sk_lbl: String = s_cfg[1]
		var eq_id := str(cur_slots.get(sk_id, ""))
		var card_p := PanelContainer.new()
		card_p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card_p.custom_minimum_size = Vector2(252, 58)
		var csb := StyleBoxFlat.new()
		csb.bg_color = Color(0.06, 0.09, 0.14, 0.92)
		csb.border_color = Color("#38bdf8") if not eq_id.is_empty() else Color(0.28, 0.34, 0.44, 0.65)
		csb.set_border_width_all(1)
		csb.set_corner_radius_all(6)
		csb.set_content_margin_all(6)
		card_p.add_theme_stylebox_override("panel", csb)
		slots_row.add_child(card_p)

		var chb := HBoxContainer.new()
		chb.add_theme_constant_override("separation", 4)
		card_p.add_child(chb)

		var cvb := VBoxContainer.new()
		cvb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		cvb.add_theme_constant_override("separation", 1)
		chb.add_child(cvb)

		var st_title := Label.new()
		st_title.text = sk_lbl
		st_title.add_theme_font_size_override("font_size", 10)
		st_title.add_theme_color_override("font_color", Color("#94a3b8"))
		cvb.add_child(st_title)

		var st_val := Label.new()
		st_val.clip_text = true
		st_val.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		st_val.add_theme_font_size_override("font_size", 11)
		if eq_id.is_empty():
			st_val.text = "— ว่าง (เลือกสวมจากรายการ) —"
			st_val.add_theme_color_override("font_color", Color("#64748b"))
			cvb.add_child(st_val)
		else:
			var eq_it := EquipData.get_item(eq_id)
			var eq_lv := int(gl.get(eq_id, 0))
			var lv_t := (" +%d" % eq_lv) if eq_lv > 0 else ""
			st_val.text = "%s%s [ภพ%s]" % [str(eq_it.get("name", eq_id)), lv_t, str(eq_it.get("realm", ""))]
			st_val.add_theme_color_override("font_color", Color(str(eq_it.get("color", "#fde047"))))
			cvb.add_child(st_val)

			var v_btn := Button.new()
			v_btn.text = "ดู"
			v_btn.custom_minimum_size = Vector2(34, 34)
			v_btn.add_theme_font_size_override("font_size", 10)
			v_btn.pressed.connect(_inspect_gear_item.bind(eq_id))
			chb.add_child(v_btn)

			var u_btn := Button.new()
			u_btn.text = "ถอดออก"
			u_btn.custom_minimum_size = Vector2(58, 34)
			u_btn.add_theme_font_size_override("font_size", 10)
			u_btn.add_theme_color_override("font_color", Color("#fca5a5"))
			u_btn.pressed.connect(_toggle_equip_gear.bind(eq_id, target_hid))
			chb.add_child(u_btn)

	var rprog := EquipData.get_realm_progress(hg_all, target_hid)
	var active_realm := str(rprog.get("active_realm", ""))
	var set_lbl := Label.new()
	set_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	set_lbl.add_theme_font_size_override("font_size", 12)
	if not active_realm.is_empty() and EquipData.REALM_SET_BONUSES.has(active_realm):
		var sb_def: Dictionary = EquipData.REALM_SET_BONUSES[active_realm]
		set_lbl.text = "✨ เปิดใช้งานโบนัสเซ็ตครบ 3/3 ชิ้น — %s: %s" % [str(sb_def["name"]), str(sb_def["desc"])]
		set_lbl.add_theme_color_override("font_color", Color("#4ade80"))
	else:
		var b_rm := str(rprog.get("best_realm", ""))
		var b_cnt := int(rprog.get("best_count", 0))
		if b_cnt > 0 and EquipData.REALM_SET_BONUSES.has(b_rm):
			var p_def: Dictionary = EquipData.REALM_SET_BONUSES[b_rm]
			set_lbl.text = "☯ เงื่อนไขโบนัสเซ็ต (ปัจจุบัน ภพ%s %d/3 ชิ้น): สวมอาวุธ+เกราะ+เครื่องรางภพ%sครบ 3 ช่อง ➔ %s" % [b_rm, b_cnt, b_rm, str(p_def["desc"])]
		else:
			set_lbl.text = "☯ เงื่อนไขโบนัสเซ็ต (0/3 ชิ้น): สวมอาวุธ + เกราะ + เครื่องรางในภพเดียวกันครบ 3 ชิ้น เพื่อปลดล็อกพลังเซ็ต 4 ภพ!"
		set_lbl.add_theme_color_override("font_color", Color("#93c5fd"))
	slots_wrap.add_child(set_lbl)

	# 3. Live Item Detail + Before -> After Hero Stat Comparison + Next Upgrade Preview Card
	var insp_it := EquipData.get_item(gear_inspect_id)
	var insp_slot := str(insp_it.get("slot", "weapon"))
	var insp_lv := int(gl.get(gear_inspect_id, 0))
	var insp_eq_now: bool = str(cur_slots.get(insp_slot, "")) == gear_inspect_id
	var cur_hero_st := CharacterStatusUI._compute_hero_stats(save_data, target_hid)
	var sim_item := "" if insp_eq_now else gear_inspect_id
	var after_hero_st := CharacterStatusUI._compute_hero_stats(save_data, target_hid, insp_slot, sim_item)

	var insp_panel := PanelContainer.new()
	insp_panel.name = "GearInspectPanel"
	var isb := StyleBoxFlat.new()
	isb.bg_color = Color(0.05, 0.08, 0.13, 0.95)
	isb.border_color = Color("#fde047")
	isb.set_border_width_all(1)
	isb.set_corner_radius_all(6)
	isb.set_content_margin_all(8)
	insp_panel.add_theme_stylebox_override("panel", isb)
	codex_gear_box.add_child(insp_panel)

	var ivb := VBoxContainer.new()
	ivb.add_theme_constant_override("separation", 3)
	insp_panel.add_child(ivb)

	var insp_rm := str(insp_it.get("realm", ""))
	var rm_set_desc := str(EquipData.REALM_SET_BONUSES.get(insp_rm, {}).get("desc", ""))
	var ititle := Label.new()
	ititle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	ititle.add_theme_font_size_override("font_size", 12)
	ititle.add_theme_color_override("font_color", Color(str(insp_it.get("color", "#fde047"))))
	ititle.text = "🔍 รายละเอียด: %s%s [%s · ภพ%s]  |  เซ็ตภพ%s (3 ชิ้น): %s" % [
		str(insp_it.get("name", "")),
		((" +%d" % insp_lv) if insp_lv > 0 else ""),
		str(insp_it.get("rarity", "")),
		insp_rm,
		insp_rm,
		rm_set_desc,
	]
	ivb.add_child(ititle)

	var cmp_parts: Array[String] = []
	for s_meta in [
		["HP", "max_hp", false],
		["ปราณ", "max_sp", false],
		["ATK", "atk", false],
		["CRIT", "crit", true],
		["ลดดาเมจ", "dmg_red", true],
	]:
		var sl: String = s_meta[0]
		var sk: String = s_meta[1]
		var pct: bool = s_meta[2]
		var b_v := float(cur_hero_st[sk])
		var a_v := float(after_hero_st[sk])
		var df := a_v - b_v
		if pct:
			if absf(df) >= 0.05:
				cmp_parts.append("%s %.0f%%➔%.0f%% (%s%.0f%%)" % [sl, b_v, a_v, ("+" if df > 0 else ""), df])
			else:
				cmp_parts.append("%s %.0f%%" % [sl, b_v])
		else:
			var bi := int(round(b_v))
			var ai := int(round(a_v))
			var di := ai - bi
			if di != 0:
				cmp_parts.append("%s %d➔%d (%s%d)" % [sl, bi, ai, ("+" if di > 0 else ""), di])
			else:
				cmp_parts.append("%s %d" % [sl, bi])

	var icmp := Label.new()
	icmp.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	icmp.add_theme_font_size_override("font_size", 11)
	icmp.add_theme_color_override("font_color", Color("#e2e8f0"))
	var act_verb := "เมื่อถอดออก" if insp_eq_now else "เมื่อสวมใส่"
	icmp.text = "📊 เทียบค่าพลัง %s (%s):  %s" % [str(hdata["name"]).split(" ")[0], act_verb, "  ·  ".join(cmp_parts)]
	ivb.add_child(icmp)

	var iupg := Label.new()
	iupg.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	iupg.add_theme_font_size_override("font_size", 11)
	if insp_lv >= EquipData.MAX_ENHANCE_LV:
		iupg.text = "⚒️ อัปเกรด: ระดับสูงสุด +5 (MAX) — %s" % _format_gear_delta(gear_inspect_id, insp_lv)
		iupg.add_theme_color_override("font_color", Color("#fde047"))
	else:
		var u_cost := EquipData.get_enhance_cost(gear_inspect_id, insp_lv)
		iupg.text = "⚒️ ตัวอย่างอัปเกรด +%d ➔ +%d: ใช้หยกปราณ %d 💎 (มี %d 💎)  ·  ผลเพิ่ม: %s" % [
			insp_lv, insp_lv + 1, u_cost, jade_now, _format_gear_delta(gear_inspect_id, insp_lv)
		]
		iupg.add_theme_color_override("font_color", Color("#86efac") if jade_now >= u_cost else Color("#fca5a5"))
	ivb.add_child(iupg)

	# 4. Slot Filter Row
	var flt_row := HBoxContainer.new()
	flt_row.add_theme_constant_override("separation", 6)
	codex_gear_box.add_child(flt_row)
	for f_item in [["all", "ทั้งหมด (15)"], ["weapon", "⚔️ อาวุธ (5)"], ["armor", "🛡️ เครื่องป้องกัน (5)"], ["relic", "🔮 เครื่องราง (5)"]]:
		var fb := Button.new()
		fb.text = str(f_item[1])
		fb.custom_minimum_size = Vector2(150, 38)
		fb.add_theme_font_size_override("font_size", 11)
		if gear_filter == str(f_item[0]):
			fb.add_theme_color_override("font_color", Color("#fde047"))
		fb.pressed.connect(_set_gear_filter.bind(str(f_item[0])))
		flt_row.add_child(fb)

	# 5. Item Rows (direct children of codex_gear_box) with distinct Inspect / Enhance / Equip-Unequip-Forge actions
	for item_id in EquipData.ITEM_ORDER:
		var it := EquipData.get_item(item_id)
		var slot_k := str(it["slot"])
		if gear_filter != "all" and slot_k != gear_filter:
			continue
		var is_owned := owned.has(item_id)
		var is_eq: bool = str(cur_slots.get(slot_k, "")) == item_id
		var holder_hid := EquipData.find_item_holder(hg_all, item_id)
		var held_other: bool = (not holder_hid.is_empty() and holder_hid != target_hid)
		var holder_short := str(HeroData.HEROES.get(holder_hid, {}).get("name", holder_hid)).split(" ")[0] if held_other else ""
		var cur_lv := int(gl.get(item_id, 0))

		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		codex_gear_box.add_child(row)

		var slot_tag := "⚔️ อาวุธ" if slot_k == "weapon" else ("🛡️ เกราะ" if slot_k == "armor" else "🔮 เครื่องราง")
		var lv_tag := (" +%d" % cur_lv) if cur_lv > 0 else ""
		var owner_tag := (" [สวมอยู่]" if is_eq else ((" [สวมโดย %s]" % holder_short) if held_other else ""))
		var lbl := Label.new()
		var stat_txt := _format_gear_delta(item_id, cur_lv) if is_owned else str(it["desc"])
		lbl.text = "[%s · %s · ภพ%s] %s%s%s\n%s" % [slot_tag, str(it["rarity"]), str(it.get("realm", "")), str(it["name"]), lv_tag, owner_tag, stat_txt]
		lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		lbl.add_theme_font_size_override("font_size", 12)
		lbl.add_theme_color_override("font_color", Color(str(it["color"])) if is_owned else Color("#94a3b8"))
		row.add_child(lbl)

		var det_btn := Button.new()
		det_btn.text = "★ กำลังดู" if gear_inspect_id == item_id else "ดูรายละเอียด"
		det_btn.custom_minimum_size = Vector2(92, 42)
		det_btn.add_theme_font_size_override("font_size", 11)
		if gear_inspect_id == item_id:
			det_btn.add_theme_color_override("font_color", Color("#fde047"))
		det_btn.pressed.connect(_inspect_gear_item.bind(item_id))
		det_btn.mouse_entered.connect(func():
			if gear_inspect_id != item_id:
				gear_inspect_id = item_id
		)
		row.add_child(det_btn)

		if is_owned:
			var enh_btn := Button.new()
			enh_btn.custom_minimum_size = Vector2(114, 42)
			enh_btn.add_theme_font_size_override("font_size", 11)
			if cur_lv >= EquipData.MAX_ENHANCE_LV:
				enh_btn.text = "อัปเกรด MAX"
				enh_btn.disabled = true
			else:
				var e_cost := EquipData.get_enhance_cost(item_id, cur_lv)
				enh_btn.text = "อัปเกรด +%d (%d💎)" % [cur_lv + 1, e_cost]
				enh_btn.disabled = jade_now < e_cost
				enh_btn.add_theme_color_override("font_color", Color("#4ade80") if not enh_btn.disabled else Color("#94a3b8"))
			enh_btn.pressed.connect(_enhance_gear_item.bind(item_id))
			row.add_child(enh_btn)

		var btn := Button.new()
		btn.custom_minimum_size = Vector2(104, 42)
		btn.add_theme_font_size_override("font_size", 11)
		if is_owned:
			if is_eq:
				btn.text = "ถอดออก"
				btn.tooltip_text = "ถอดอุปกรณ์ออกจากช่องนี้"
				btn.add_theme_color_override("font_color", Color("#fca5a5"))
			elif held_other:
				btn.text = "ย้ายมาสวม"
				btn.tooltip_text = "ย้ายอุปกรณ์จาก %s มาสวมให้ตัวละครนี้" % holder_short
				btn.add_theme_color_override("font_color", Color("#fbbf24"))
			else:
				btn.text = "สวมใส่"
				btn.tooltip_text = "สวมใส่อุปกรณ์ลงในช่อง"
				btn.add_theme_color_override("font_color", Color("#4ade80"))
			btn.pressed.connect(_toggle_equip_gear.bind(item_id, target_hid))
		else:
			var cost := int(it.get("cost", 50))
			btn.text = "หลอม %d 💎" % cost
			btn.disabled = jade_now < cost
			btn.pressed.connect(_forge_gear_item.bind(item_id))
		row.add_child(btn)


func _export_save_code():
	var code := SaveManager.export_save_code(save_data)
	if codex_save_input:
		codex_save_input.text = code
		codex_save_input.select_all()
	DisplayServer.clipboard_set(code)
	sfx.play_sfx("crit")
	_show_banner("📤 คัดลอกรหัสย้ายเซฟแล้ว! นำไปวางอีกเครื่องได้เลย", 2.4)


func _import_save_code(raw_override: String = ""):
	var raw_code := raw_override.strip_edges()
	if raw_code.is_empty() and codex_save_input:
		raw_code = codex_save_input.text.strip_edges()
	if raw_code.is_empty():
		raw_code = DisplayServer.clipboard_get().strip_edges()
	var res := SaveManager.import_save_code(raw_code)
	if not bool(res.get("ok", false)):
		_show_banner("❌ " + str(res.get("error", "รหัสเซฟไม่ถูกต้อง")), 2.2)
		return
	save_data = res["data"]
	SaveManager.save_data(save_data, save_path)
	active_party = save_data.get("party", HeroData.DEFAULT_PARTY.duplicate()).duplicate()
	if not active_party.has(active_hero_id):
		active_hero_id = str(active_party[0])
	_init_hero_stats()
	_switch_hero(active_hero_id, false)
	if sfx:
		sfx.set_bgm_enabled(bool(save_data.get("bgm_enabled", true)))
	_refresh_cutin_btn()
	_refresh_bgm_btn()
	_rebuild_upgrade_list()
	_rebuild_party_hud()
	_rebuild_gear_list()
	CodexUI.refresh_chapters(codex_chapter_btns, chapter, save_data.get("cleared_chapters", []))
	if upgrade_jade_lbl:
		upgrade_jade_lbl.text = "💎 หยกปราณคงเหลือ: %d" % int(save_data["spirit_jade"])
	_refresh_hud()
	sfx.play_sfx("victory")
	_show_banner("✅ นำเข้าเซฟสำเร็จ! หยกปราณ %d 💎" % int(save_data["spirit_jade"]), 2.6)


func _refresh_mirror_btn():
	if not codex_mirror_btn:
		return
	var mir := bool(save_data.get("touch_mirror", false))
	codex_mirror_btn.text = "🎮 ปุ่มทัช: สลับฝั่ง" if mir else "🎮 ปุ่มทัช: ปกติ"
	codex_mirror_btn.add_theme_color_override("font_color", Color("#fde047") if mir else Color("#93c5fd"))


func _toggle_touch_mirror():
	var next_val := not bool(save_data.get("touch_mirror", false))
	save_data["touch_mirror"] = next_val
	SaveManager.save_data(save_data, save_path)
	if mobile_controls and mobile_controls.has_method("set_mirrored"):
		mobile_controls.set_mirrored(next_val)
	_refresh_mirror_btn()
	_show_banner("🎮 จัดวางปุ่มทัช: %s" % ("สลับ 2 มือ (ขวา)" if next_val else "มือซ้ายข้างเดียว"), 1.6)


func _toggle_game_speed():
	game_speed_mult = 1.5 if game_speed_mult < 1.25 else 1.0
	save_data["game_speed"] = game_speed_mult
	SaveManager.save_data(save_data, save_path)
	if not _is_modal_open() and hitstop_timer <= 0.0 and combat.get_desired_time_scale(hitstop_timer) >= 0.99:
		Engine.time_scale = game_speed_mult
	_show_banner("⏩ ความเร็วเกม: %.1f×" % game_speed_mult, 1.2)
	_refresh_hud()


func _toggle_hud_menu():
	var next_val := not bool(save_data.get("hud_menu_expanded", false))
	save_data["hud_menu_expanded"] = next_val
	SaveManager.save_data(save_data, save_path)
	_apply_hud_menu_state()


func _apply_hud_menu_state():
	var expanded := bool(save_data.get("hud_menu_expanded", false))
	if top_right_btn_grid:
		top_right_btn_grid.visible = expanded
	if menu_toggle_btn:
		menu_toggle_btn.text = "▲ ยุบ [M]" if expanded else "▼ เมนู [M]"
	if top_right_panel:
		top_right_panel.offset_left = -402.0 if expanded else -286.0
	if get_viewport():
		var vr := get_viewport().get_visible_rect().size
		if vr.x > 1.0 and vr.y > 1.0:
			_layout_landscape_center_hud(vr)


func _populate_battle_summary(is_victory: bool):
	if not end_summary_box:
		return
	for ch in end_summary_box.get_children():
		ch.queue_free()

	var total_dmg := 0
	var mvp_hid := ""
	var mvp_dmg := -1
	for hid in active_party:
		var d := int(run_hero_damage.get(hid, 0))
		total_dmg += d
		if d > mvp_dmg:
			mvp_dmg = d
			mvp_hid = str(hid)

	var peak_idx := clampi(combat.peak_rank_idx, 0, CombatSystem.RANKS.size() - 1)
	var peak_rank := str(CombatSystem.RANKS[peak_idx]["id"])
	if CombatSystem.RANKS.find_custom(func(r): return r["id"] == run_max_combo_rank) > peak_idx:
		peak_rank = run_max_combo_rank
	var pd_cnt := maxi(run_perfect_dodges, combat.perfect_dodge_count)
	var react_cnt := maxi(run_reactions, combat.reaction_count)

	var rec_flags := {"new_time": false, "new_combo": false, "new_damage": false, "any_new": false}
	if is_victory:
		rec_flags = SaveManager.update_chapter_record(save_data, chapter, run_elapsed_time, run_max_combo_hits, total_dmg)
		SaveManager.save_data(save_data, save_path)

	var meta_lbl := Label.new()
	var rec_tag := "  🔥 NEW RECORD!" if bool(rec_flags.get("any_new", false)) else ""
	meta_lbl.text = "⏱️ เวลา: %.1f วิ  ·  🔥 คอมโบสูงสุด: %d Hits (%s)  ·  💥 คริสูงสุด: %d  ·  ⚡ หลบพริบตา: %d  ·  💥 ปฏิกิริยาธาตุ: %d  ·  💎 หยกปราณ: +%d%s" % [
		run_elapsed_time, run_max_combo_hits, peak_rank, run_max_crit_dmg, pd_cnt, react_cnt, run_jade_earned, rec_tag
	]
	meta_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	meta_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	meta_lbl.add_theme_font_size_override("font_size", 12)
	meta_lbl.add_theme_color_override("font_color", Color("#fde047") if bool(rec_flags.get("any_new", false)) else Color("#cbd5e1"))
	end_summary_box.add_child(meta_lbl)

	if not is_victory:
		var tip_lbl := Label.new()
		var tip_txt := "💡 เคล็ดลับแก้ทาง: "
		if pd_cnt == 0:
			tip_txt += "สังเกตป้าย '⚠️ โจมตี!' และวงสีแดงใต้เท้าศัตรู แล้วกด [Space / Shift] หลบพริบตา จะได้ปราณ +30 และคริติคอล 100%!"
		elif react_cnt == 0:
			tip_txt += "ลองกดสกิล [Q] หรือ [E] แปะตราธาตุใส่ศัตรู แล้วกด [1 / 2 / 3] สลับตัวละครเพื่อระเบิดปฏิกิริยาธาตุทำดาเมจหมู่!"
		else:
			tip_txt += "แวะเปิด [U] หอคัมภีร์เซียน เพื่อนำหยกปราณไปอัปเกรดพลังชีวิต/พลังโจมตี และสวมใส่ศาสตราวุธก่อนลุยรอบถัดไป!"
		tip_lbl.text = tip_txt
		tip_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		tip_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		tip_lbl.add_theme_font_size_override("font_size", 13)
		tip_lbl.add_theme_color_override("font_color", Color("#5eead4"))
		end_summary_box.add_child(tip_lbl)

	var dmg_hdr := Label.new()
	dmg_hdr.text = "── ตารางสรุปดาเมจรวม (%d DMG) ──" % total_dmg
	dmg_hdr.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	dmg_hdr.add_theme_font_size_override("font_size", 12)
	dmg_hdr.add_theme_color_override("font_color", Color("#93c5fd"))
	end_summary_box.add_child(dmg_hdr)

	for hid in active_party:
		var hinfo: Dictionary = HeroData.HEROES[hid]
		var hdmg := int(run_hero_damage.get(hid, 0))
		var pct := (float(hdmg) / float(maxi(1, total_dmg))) * 100.0
		var is_mvp: bool = (str(hid) == mvp_hid and hdmg > 0)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		end_summary_box.add_child(row)

		var nlbl := Label.new()
		nlbl.custom_minimum_size = Vector2(180, 22)
		nlbl.text = "%s%s" % [("👑 MVP " if is_mvp else "   "), str(hinfo["name"])]
		nlbl.add_theme_font_size_override("font_size", 12)
		nlbl.add_theme_color_override("font_color", Color("#fde047") if is_mvp else Color("#e2e8f0"))
		row.add_child(nlbl)

		var bar := ProgressBar.new()
		bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		bar.custom_minimum_size = Vector2(160, 14)
		bar.show_percentage = false
		bar.max_value = 100.0
		bar.value = pct
		row.add_child(bar)

		var vlbl := Label.new()
		vlbl.custom_minimum_size = Vector2(130, 22)
		vlbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		vlbl.text = "%d (%.0f%%)" % [hdmg, pct]
		vlbl.add_theme_font_size_override("font_size", 12)
		vlbl.add_theme_color_override("font_color", Color("#4ade80") if is_mvp else Color("#cbd5e1"))
		row.add_child(vlbl)

	if run_drops.size() > 0:
		var drop_names: Array[String] = []
		for did in run_drops:
			drop_names.append(str(EquipData.get_item(str(did)).get("name", did)))
		var dlbl := Label.new()
		dlbl.text = "🎁 ศาสตราวุธที่ได้: " + ", ".join(drop_names)
		dlbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		dlbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		dlbl.add_theme_font_size_override("font_size", 12)
		dlbl.add_theme_color_override("font_color", Color("#34d399"))
		end_summary_box.add_child(dlbl)


func _record_achievement(ach_id: String, amount: int = 1, set_absolute: bool = false):
	var res := SaveManager.record_achievement_progress(save_data, ach_id, amount, set_absolute)
	if bool(res.get("unlocked_now", false)):
		SaveManager.save_data(save_data, save_path)
		_show_toast("🏆 สำเร็จภารกิจ: %s (+%d 💎)" % [str(res["title"]), int(res["reward"])])
		if upgrade_jade_lbl:
			upgrade_jade_lbl.text = "💎 หยกปราณคงเหลือ: %d" % int(save_data["spirit_jade"])


func _show_toast(msg: String):
	if not toast_panel or not toast_label:
		return
	toast_label.text = msg
	toast_panel.visible = true
	toast_timer = 2.8


func _build_toast_and_tutorial_hud(hud: CanvasLayer, sb: StyleBoxFlat):
	toast_panel = PanelContainer.new()
	toast_panel.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	toast_panel.position = Vector2(-390, 148)
	toast_panel.custom_minimum_size = Vector2(360, 42)
	var tsb := sb.duplicate()
	tsb.border_color = Color("#fde047")
	tsb.bg_color = Color(0.06, 0.09, 0.14, 0.94)
	toast_panel.add_theme_stylebox_override("panel", tsb)
	toast_panel.visible = false
	hud.add_child(toast_panel)

	toast_label = Label.new()
	toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast_label.add_theme_font_size_override("font_size", 13)
	toast_label.add_theme_color_override("font_color", Color("#fde047"))
	toast_panel.add_child(toast_label)

	tutorial_panel = PanelContainer.new()
	tutorial_panel.position = Vector2(316, 114)
	tutorial_panel.custom_minimum_size = Vector2(520, 52)
	var tut_sb := sb.duplicate()
	tut_sb.border_color = Color("#38bdf8")
	tut_sb.bg_color = Color(0.04, 0.08, 0.14, 0.94)
	tutorial_panel.add_theme_stylebox_override("panel", tut_sb)
	tutorial_panel.visible = false
	hud.add_child(tutorial_panel)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 10)
	tutorial_panel.add_child(hbox)

	tutorial_lbl = Label.new()
	tutorial_lbl.custom_minimum_size = Vector2(360, 0)
	tutorial_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tutorial_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tutorial_lbl.add_theme_font_size_override("font_size", 12)
	tutorial_lbl.add_theme_color_override("font_color", Color("#f8fafc"))
	hbox.add_child(tutorial_lbl)

	tutorial_skip_btn = Button.new()
	tutorial_skip_btn.text = "ข้ามการสอน ✕"
	tutorial_skip_btn.custom_minimum_size = Vector2(110, 34)
	tutorial_skip_btn.add_theme_font_size_override("font_size", 12)
	_style_hud_btn(tutorial_skip_btn, Color("#38bdf8"), Color("#f8fafc"))
	tutorial_skip_btn.pressed.connect(_complete_interactive_tutorial)
	hbox.add_child(tutorial_skip_btn)

	tutorial_arrow_lbl = Label.new()
	tutorial_arrow_lbl.text = "⬇ กดเลย!"
	tutorial_arrow_lbl.add_theme_font_size_override("font_size", 14)
	tutorial_arrow_lbl.add_theme_color_override("font_color", Color("#fde047"))
	tutorial_arrow_lbl.add_theme_color_override("font_outline_color", Color.BLACK)
	tutorial_arrow_lbl.add_theme_constant_override("outline_size", 4)
	tutorial_arrow_lbl.visible = false
	hud.add_child(tutorial_arrow_lbl)


func _start_interactive_tutorial():
	_advance_tutorial(1)


func _get_tutorial_target_ctrl(step: int) -> Control:
	var touch_on := mobile_controls != null and mobile_controls.visible
	if step == 1:
		return mobile_controls.btn_dash if touch_on else skill_dash_pill
	elif step == 2:
		return mobile_controls.btn_e if touch_on else skill_e_pill
	elif step == 3:
		if active_party.size() >= 2 and hero_cards.has(active_party[1]):
			return hero_cards[active_party[1]]
		elif active_party.size() >= 1 and hero_cards.has(active_party[0]):
			return hero_cards[active_party[0]]
	return null


func _clear_tutorial_highlights():
	for c in [skill_dash_pill, skill_e_pill]:
		if is_instance_valid(c):
			c.modulate = Color.WHITE
	if mobile_controls:
		for c in [mobile_controls.btn_dash, mobile_controls.btn_e]:
			if is_instance_valid(c):
				c.modulate = Color.WHITE
	for card in hero_cards.values():
		if is_instance_valid(card):
			(card as Control).modulate = Color.WHITE


func _position_tutorial_arrow():
	if not tutorial_arrow_lbl or tutorial_step == 0:
		return
	var target := _get_tutorial_target_ctrl(tutorial_step)
	if not is_instance_valid(target):
		return
	var r := target.get_global_rect()
	if r.size.x <= 0.0:
		return
	var bob := sin(float(Time.get_ticks_msec()) * 0.008) * 4.0
	if tutorial_step == 3:
		tutorial_arrow_lbl.text = "⬆ แตะสลับ!" if (mobile_controls and mobile_controls.visible) else "⬆ กดสลับ!"
		tutorial_arrow_lbl.position = Vector2(r.position.x - 4.0, r.end.y + 6.0 + bob)
	else:
		tutorial_arrow_lbl.text = "⬇ กดเลย!"
		tutorial_arrow_lbl.position = Vector2(r.position.x + (r.size.x - 74.0) * 0.5, r.position.y - 28.0 + bob)


func _advance_tutorial(step: int):
	_clear_tutorial_highlights()
	tutorial_step = step
	if not tutorial_panel or not tutorial_lbl:
		return
	tutorial_panel.visible = true
	if tutorial_arrow_lbl:
		tutorial_arrow_lbl.visible = true
	if step == 1:
		tutorial_lbl.text = "👉 ขั้นที่ 1/3: เดินด้วย [WASD] รอศัตรูขึ้นเตือน \"⚠️ โจมตี!\" แล้วกด [Space / Shift] เพื่อหลบพริบตา!"
	elif step == 2:
		Engine.time_scale = 1.0
		if chapter == 1 and current_room == 0 and enemies.size() == 0:
			_spawn_enemy("cultist", player.global_position + Vector2(140.0, 0.0))
		tutorial_lbl.text = "👉 ขั้นที่ 2/3: กดหรือคลิกสกิล [E] ใส่ศัตรูเพื่อ \"แปะตราธาตุ\"!"
	elif step == 3:
		if chapter == 1 and current_room == 0 and enemies.size() == 0:
			_spawn_enemy("cultist", player.global_position + Vector2(140.0, 0.0))
		tutorial_lbl.text = "👉 ขั้นที่ 3/3: กดสลับตัว [1 / 2 / 3] (หรือแตะรูปตัวละครซ้ายบน) เพื่อ \"ระเบิดปฏิกิริยาธาตุ\"!"
	if get_viewport():
		_layout_landscape_center_hud(get_viewport().get_visible_rect().size)
	_position_tutorial_arrow()


func _complete_interactive_tutorial():
	tutorial_step = 0
	_clear_tutorial_highlights()
	Engine.time_scale = 1.0
	if tutorial_panel:
		tutorial_panel.visible = false
	if tutorial_arrow_lbl:
		tutorial_arrow_lbl.visible = false
	save_data["tutorial_completed"] = true
	SaveManager.save_data(save_data, save_path)
	_show_toast("🎓 ฝึกยุทธ์สำเร็จ! ลุยหอคอยได้เลย!")


func _update_interactive_tutorial(_delta: float):
	if tutorial_step == 0:
		return
	_position_tutorial_arrow()
	var target := _get_tutorial_target_ctrl(tutorial_step)
	if is_instance_valid(target):
		var glow := 0.88 + 0.12 * sin(float(Time.get_ticks_msec()) * 0.01)
		target.modulate = Color(1.15, 1.08, glow, 1.0)
	if tutorial_step == 1 and _has_incoming_threat():
		Engine.time_scale = 0.35
	elif tutorial_step == 1 and Engine.time_scale < 0.99:
		Engine.time_scale = 1.0


func _rebuild_character_status():
	if not codex_char_box:
		return
	CharacterStatusUI.build_view(codex_char_box, {
		"save_data": save_data,
		"active_party": active_party,
		"selected_hid": char_status_selected_hid,
		"drawer_slot": char_status_drawer_slot,
		"preview_item_id": char_status_preview_id,
		"is_portrait": false,
	}, {
		"get_portrait": func(hid: String): return _get_hero_tex(hid, "portrait"),
		"select_hero": func(hid: String):
			char_status_selected_hid = hid
			char_status_drawer_slot = ""
			char_status_preview_id = ""
			_rebuild_character_status(),
		"open_drawer": func(slot_k: String):
			char_status_drawer_slot = slot_k
			char_status_preview_id = ""
			_rebuild_character_status(),
		"close_drawer": func():
			char_status_drawer_slot = ""
			char_status_preview_id = ""
			_rebuild_character_status(),
		"preview_item": func(item_id: String):
			if char_status_preview_id != item_id:
				char_status_preview_id = item_id
				_rebuild_character_status(),
		"equip_item": func(hid: String, item_id: String):
			_toggle_equip_gear(item_id, hid)
			char_status_preview_id = ""
			_rebuild_character_status(),
		"forge_item": func(item_id: String):
			_forge_gear_item(item_id)
			_rebuild_character_status(),
		"enhance_item": func(item_id: String):
			_enhance_gear_item(item_id)
			_rebuild_character_status(),
		"toggle_costume": func(hid: String):
			_toggle_hero_costume(hid)
			_rebuild_character_status(),
		"buy_passive": func(hid: String):
			_buy_hero_passive(hid)
			_rebuild_character_status(),
	})
