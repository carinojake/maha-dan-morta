extends Node2D

const HeroData = preload("res://scripts/hero_data.gd")
const SfxSynth = preload("res://scripts/sfx_synth.gd")
const SaveManager = preload("res://scripts/save_manager.gd")
const ChapterData = preload("res://scripts/chapter_data.gd")
const VfxStudio = preload("res://scripts/vfx_studio.gd")
const MonsterData = preload("res://scripts/monster_data.gd")
const CodexUI = preload("res://scripts/codex_ui.gd")
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
var player_light: PointLight2D
var camera: Camera2D
var target_reticle: Polygon2D
var screen_flash: ColorRect

var active_hero_id: String = "bai_yueling"
var facing_dir: Vector2 = Vector2.RIGHT
var auto_attack_enabled: bool = true
var hero_hp: Dictionary = {}
var hero_sp: Dictionary = {}
var hero_textures: Dictionary = {}
var light_tex: Texture2D

var walk_timer: float = 0.0
var walk_step: int = 0
var attack_timer: float = 0.0
var pose_override_timer: float = 0.0
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

var _prev_q: bool = false
var _prev_e: bool = false
var _prev_r: bool = false
var _prev_c: bool = false
var _prev_f: bool = false
var _prev_space: bool = false
var _prev_1: bool = false
var _prev_2: bool = false
var _prev_3: bool = false
var _prev_u: bool = false
var _prev_h: bool = false

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


func _total_rooms() -> int:
	return ChapterData.ROOMS_PER_CHAPTER


func _ready():
	chapter = int(Globals.get_meta("chapter", 1))
	boss_rush_mode = bool(Globals.get_meta("boss_rush", false))
	if Globals.has_meta("save_path"):
		save_path = str(Globals.get_meta("save_path"))
	save_data = SaveManager.load_data(save_path)
	active_party = SaveManager._sanitize_party(save_data.get("party", HeroData.DEFAULT_PARTY))
	light_tex = load("res://assets/env/light_radial.png")
	sfx = SfxSynth.new()
	add_child(sfx)
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
	var keys := ["stride_0", "stride_1", "stride_2", "strike_0", "strike_1", "strike_2", "dash", "hurt", "dead", "portrait", "skill_1", "skill_2", "special", "ultimate"]
	for hid in HeroData.HERO_ORDER:
		hero_textures[hid] = {"default": {}, "alt": {}}
		for k in keys:
			var p_def := "res://assets/heroes/%s/%s.png" % [hid, k]
			if ResourceLoader.exists(p_def):
				hero_textures[hid]["default"][k] = load(p_def)
			var p_alt := "res://assets/heroes/%s/alt/%s.png" % [hid, k]
			if ResourceLoader.exists(p_alt):
				hero_textures[hid]["alt"][k] = load(p_alt)


func _get_hero_tex(hid: String, key: String, fallback: Texture2D = null) -> Texture2D:
	var costumes: Dictionary = save_data.get("costumes", {})
	var mode: String = str(costumes.get(hid, "default"))
	var hdict: Dictionary = hero_textures.get(hid, {})
	var cdict: Dictionary = hdict.get(mode, {})
	if cdict.has(key):
		return cdict[key]
	var ddict: Dictionary = hdict.get("default", {})
	return ddict.get(key, fallback)


func _get_hero_stat(hid: String, key: String) -> float:
	var base := float(HeroData.HEROES[hid][key])
	var cu: Dictionary = save_data.get("core_upgrades", {})
	if key == "max_hp":
		return base + float(cu.get("hp_lv", 0)) * 25.0
	elif key == "max_sp":
		return base + float(cu.get("sp_lv", 0)) * 15.0
	elif key == "atk":
		var val := base + float(cu.get("atk_lv", 0)) * 6.0
		if active_boons.has("lightning_edge"):
			val *= 1.22
		return val
	elif key == "crit":
		return base + (0.18 if active_boons.has("crit_heaven") else 0.0)
	return base


func _init_hero_stats():
	for hid in HeroData.HERO_ORDER:
		hero_hp[hid] = _get_hero_stat(hid, "max_hp")
		hero_sp[hid] = _get_hero_stat(hid, "max_sp")


func _build_environment():
	var cdata := ChapterData.get_chapter(chapter)
	var total_rooms := _total_rooms()
	var max_x := total_rooms * ROOM_STRIDE
	var bg := ColorRect.new()
	bg.color = Color(0.04, 0.04, 0.06, 1.0)
	bg.position = Vector2(-1000, -1000)
	bg.size = Vector2(max_x * TILE_SIZE + 2500, 3000)
	bg.z_index = -100
	add_child(bg)

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

	var use_bamboo: bool = bool(cdata["use_bamboo"])
	var floor_tex: Texture2D = load("res://assets/env/floor_bamboo.png" if use_bamboo else "res://assets/env/floor_slate.png")
	var wall_tex: Texture2D = load("res://assets/env/wall_bamboo.png" if use_bamboo else "res://assets/env/wall_stone.png")
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
	for x in range(0, max_x):
		for y in range(0, 9):
			var cell := Vector2i(x, y)
			var pos := Vector2(x * TILE_SIZE + 32, y * TILE_SIZE + 32)
			if walkable.has(cell):
				var f := Sprite2D.new()
				f.texture = floor_tex
				f.position = pos
				f.modulate = ftint
				floor_layer.add_child(f)
			else:
				var adj := false
				for d in [Vector2i(1,0), Vector2i(-1,0), Vector2i(0,1), Vector2i(0,-1), Vector2i(1,1), Vector2i(-1,-1), Vector2i(1,-1), Vector2i(-1,1)]:
					if walkable.has(cell + d):
						adj = true
						break
				if adj:
					var w := Sprite2D.new()
					w.texture = wall_tex
					w.position = pos
					w.modulate = wtint
					world_node.add_child(w)
					var col := CollisionShape2D.new()
					var shape := RectangleShape2D.new()
					shape.size = Vector2(TILE_SIZE, TILE_SIZE)
					col.shape = shape
					col.position = pos
					wall_body.add_child(col)

	var lcol: Color = cdata["light_color"]
	for r in range(total_rooms):
		var base_x := float(r * ROOM_STRIDE)
		var bx := base_x + 7.5
		var bag := Sprite2D.new()
		bag.texture = bagua_tex
		bag.position = Vector2(bx, 4.5) * TILE_SIZE
		bag.modulate = Color(ftint.r, ftint.g, ftint.b, 0.72)
		floor_layer.add_child(bag)

		# Braziers & Lanterns per room
		for bsp in [Vector2(base_x + 2.5, 2.0), Vector2(base_x + 12.2, 2.0), Vector2(base_x + 12.2, 6.8)]:
			var b := Sprite2D.new()
			b.texture = lantern_tex if use_bamboo else brazier_tex
			b.position = bsp * TILE_SIZE
			b.offset = Vector2(0, -26)
			world_node.add_child(b)
			_add_light(b, lcol, 1.65, 3.0)

		# Zone-specific props across the 10 rooms
		if use_bamboo:
			var bm := Sprite2D.new()
			bm.texture = bamboo_tex if r % 2 == 0 else tree_tex
			bm.position = Vector2(base_x + 4.2, 2.1 if r % 2 == 0 else 6.8) * TILE_SIZE
			bm.offset = Vector2(0, -54)
			world_node.add_child(bm)
		else:
			if r % 2 == 0:
				var cr := Sprite2D.new()
				cr.texture = crystal_tex
				cr.position = Vector2(base_x + 3.2, 6.8) * TILE_SIZE
				cr.offset = Vector2(0, -24)
				cr.modulate = lcol.lightened(0.35)
				world_node.add_child(cr)
			else:
				var p := Sprite2D.new()
				p.texture = pillar_tex
				p.position = Vector2(base_x + 4.2, 2.3) * TILE_SIZE
				p.offset = Vector2(0, -54)
				p.modulate = ftint
				world_node.add_child(p)
			var bn := Sprite2D.new()
			bn.texture = banner_tex
			bn.position = Vector2(base_x + 7.5, 1.4) * TILE_SIZE
			bn.offset = Vector2(0, -40)
			world_node.add_child(bn)

		# Sawblade traps in mechanical / blade chapters (Ch 3, 6, 7, 10) or odd combat rooms
		if (chapter in [3, 6, 7, 10] and r in [0, 1, 2, 3, 5, 6, 7]) or (r in [2, 6]):
			_spawn_sawblade_trap(Vector2(base_x + 7.5, 2.8) * TILE_SIZE)
			_spawn_sawblade_trap(Vector2(base_x + 7.5, 6.2) * TILE_SIZE)

	for r in range(total_rooms - 1):
		var gx := 14.5 + float(r * ROOM_STRIDE)
		var gate := StaticBody2D.new()
		gate.position = Vector2(gx * TILE_SIZE, 4.5 * TILE_SIZE)
		var gcol := CollisionShape2D.new()
		var gshape := RectangleShape2D.new()
		gshape.size = Vector2(40, TILE_SIZE * 3.0)
		gcol.shape = gshape
		gate.add_child(gcol)
		var gvis := Line2D.new()
		gvis.points = PackedVector2Array([Vector2(0, -TILE_SIZE * 1.45), Vector2(0, TILE_SIZE * 1.45)])
		gvis.width = 4.0
		gvis.default_color = Color(lcol.r, lcol.g, lcol.b, 0.72)
		gate.add_child(gvis)
		var gcore := Line2D.new()
		gcore.points = gvis.points
		gcore.width = 1.5
		gcore.default_color = Color(1.0, 0.96, 0.75, 0.85)
		gate.add_child(gcore)
		world_node.add_child(gate)
		room_gates.append(gate)

	target_reticle = Polygon2D.new()
	target_reticle.polygon = _make_ellipse(24.0, 11.0, 18)
	target_reticle.color = Color(0.98, 0.82, 0.25, 0.55)
	target_reticle.z_index = -5
	target_reticle.visible = false
	add_child(target_reticle)


func _add_light(parent: Node2D, color: Color, energy: float, scale_val: float):
	var light := PointLight2D.new()
	light.texture = light_tex
	light.color = color
	light.energy = energy
	light.texture_scale = scale_val
	light.position = Vector2(0, -18)
	parent.add_child(light)


func _build_player():
	player = CharacterBody2D.new()
	player.position = Vector2(4.0 * TILE_SIZE, 4.5 * TILE_SIZE)
	world_node.add_child(player)

	var col := CollisionShape2D.new()
	var shape := CircleShape2D.new()
	shape.radius = 18.0
	col.shape = shape
	player.add_child(col)

	var shadow := Polygon2D.new()
	shadow.polygon = _make_ellipse(22.0, 9.0, 14)
	shadow.color = Color(0.0, 0.0, 0.0, 0.55)
	shadow.z_index = -1
	player.add_child(shadow)

	player_sprite = Sprite2D.new()
	player_sprite.scale = HERO_SCALE
	player_sprite.offset = HERO_OFFSET
	player.add_child(player_sprite)

	player_light = PointLight2D.new()
	player_light.texture = light_tex
	player_light.energy = 1.35
	player_light.texture_scale = 3.2
	player_light.position = Vector2(0, -24)
	player.add_child(player_light)

	camera = Camera2D.new()
	camera.zoom = Vector2(1.15, 1.15)
	camera.position_smoothing_enabled = true
	camera.position_smoothing_speed = 8.0
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
	top_center.set_anchors_preset(Control.PRESET_TOP_WIDE)
	top_center.position = Vector2(0, 16)
	top_center.alignment = BoxContainer.ALIGNMENT_CENTER
	hud.add_child(top_center)

	room_label = Label.new()
	room_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	room_label.add_theme_font_size_override("font_size", 16)
	room_label.add_theme_color_override("font_color", Color("#99f6e4"))
	top_center.add_child(room_label)

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
	bot_center.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	bot_center.position = Vector2(0, -82)
	bot_center.alignment = BoxContainer.ALIGNMENT_CENTER
	bot_center.add_theme_constant_override("separation", 10)
	hud.add_child(bot_center)

	var p_auto := _make_skill_pill("[F] โจมตี / [C] ออโต้", Color("#e2e8f0"))
	auto_val_lbl = p_auto.find_child("Val", true, false)
	bot_center.add_child(p_auto)

	var p_q := _make_skill_pill("[Q] สกิล 1", Color("#38bdf8"))
	q_title_lbl = p_q.find_child("Title", true, false)
	q_val_lbl = p_q.find_child("Val", true, false)
	bot_center.add_child(p_q)

	var p_e := _make_skill_pill("[E] สกิล 2", Color("#a855f7"))
	e_title_lbl = p_e.find_child("Title", true, false)
	e_val_lbl = p_e.find_child("Val", true, false)
	bot_center.add_child(p_e)

	var p_r := _make_skill_pill("[R] ท่าไม้ตาย!", Color("#facc15"))
	r_title_lbl = p_r.find_child("Title", true, false)
	r_val_lbl = p_r.find_child("Val", true, false)
	bot_center.add_child(p_r)

	var p_dash := _make_skill_pill("[Space] วิชาตัวเบา", Color("#2dd4bf"))
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
	top_right.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	top_right.position = Vector2(-248, 18)
	top_right.custom_minimum_size = Vector2(228, 120)
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

	jade_label = Label.new()
	jade_label.add_theme_font_size_override("font_size", 13)
	jade_label.add_theme_color_override("font_color", Color("#5eead4"))
	mm_vb.add_child(jade_label)

	var btn_row := HBoxContainer.new()
	btn_row.add_theme_constant_override("separation", 6)
	mm_vb.add_child(btn_row)

	diff_btn = Button.new()
	diff_btn.custom_minimum_size = Vector2(106, 26)
	diff_btn.add_theme_font_size_override("font_size", 11)
	diff_btn.pressed.connect(_toggle_difficulty)
	btn_row.add_child(diff_btn)

	var upg_btn := Button.new()
	upg_btn.text = "📜 คัมภีร์ [U]"
	upg_btn.custom_minimum_size = Vector2(92, 26)
	upg_btn.add_theme_font_size_override("font_size", 11)
	upg_btn.pressed.connect(_toggle_upgrade_modal)
	btn_row.add_child(upg_btn)

	var help_btn := Button.new()
	help_btn.text = "❓ คู่มือ [H]"
	help_btn.custom_minimum_size = Vector2(82, 26)
	help_btn.add_theme_font_size_override("font_size", 11)
	help_btn.pressed.connect(_toggle_help_overlay)
	btn_row.add_child(help_btn)

	var codex_refs := CodexUI.build_modal(hud, sb, chapter, {
		"set_tab": _set_codex_tab,
		"jump_chapter": _jump_to_chapter,
		"warp_room": _warp_to_room,
		"boss_rush": _start_boss_rush,
		"toggle": _toggle_upgrade_modal,
	})
	upgrade_overlay = codex_refs["overlay"]
	upgrade_jade_lbl = codex_refs["jade_lbl"]
	codex_tab_btns = codex_refs["tab_btns"]
	codex_upgrade_scroll = codex_refs["upg_scroll"]
	upgrade_list_box = codex_refs["upg_list"]
	codex_party_scroll = codex_refs["party_scroll"]
	codex_party_box = codex_refs["party_box"]
	codex_chapters_box = codex_refs["chapters_box"]
	codex_chapter_btns = codex_refs["chapter_btns"]
	_set_codex_tab(0)

	help_overlay = CodexUI.build_help_overlay(hud, sb, _toggle_help_overlay)
	help_overlay.visible = (DisplayServer.get_name() != "headless") and not bool(Globals.get_meta("skip_intro", false)) and not boss_rush_mode

	var boon_refs := CodexUI.build_boon_overlay(hud, sb, _pick_boon)
	boon_overlay = boon_refs["overlay"]
	boon_btns = boon_refs["btns"]

	end_overlay = ColorRect.new()
	end_overlay.color = Color(0.03, 0.04, 0.06, 0.82)
	end_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	end_overlay.visible = false
	hud.add_child(end_overlay)

	var end_box := VBoxContainer.new()
	end_box.set_anchors_preset(Control.PRESET_CENTER)
	end_box.position = Vector2(-210, -80)
	end_box.custom_minimum_size = Vector2(420, 160)
	end_box.add_theme_constant_override("separation", 14)
	end_overlay.add_child(end_box)

	end_title = Label.new()
	end_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	end_title.add_theme_font_size_override("font_size", 26)
	end_box.add_child(end_title)

	restart_btn = Button.new()
	restart_btn.text = "🔄 เล่นใหม่อีกครั้ง [Enter]"
	restart_btn.custom_minimum_size = Vector2(280, 46)
	restart_btn.pressed.connect(_on_end_action_pressed)
	end_box.add_child(restart_btn)

	end_upgrade_btn = Button.new()
	end_upgrade_btn.text = "📜 เปิดหอคัมภีร์อัปเกรด [U]"
	end_upgrade_btn.custom_minimum_size = Vector2(280, 40)
	end_upgrade_btn.pressed.connect(_toggle_upgrade_modal)
	end_box.add_child(end_upgrade_btn)


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


func _make_skill_pill(title: String, col: Color) -> PanelContainer:
	var p := PanelContainer.new()
	p.custom_minimum_size = Vector2(142, 54)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.05, 0.08, 0.12, 0.90)
	sb.border_color = col
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(8)
	sb.set_content_margin_all(6)
	p.add_theme_stylebox_override("panel", sb)
	var hb := VBoxContainer.new()
	p.add_child(hb)
	var l1 := Label.new()
	l1.name = "Title"
	l1.text = title
	l1.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l1.add_theme_font_size_override("font_size", 12)
	l1.add_theme_color_override("font_color", col)
	hb.add_child(l1)
	var l2 := Label.new()
	l2.name = "Val"
	l2.text = "พร้อมใช้"
	l2.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l2.add_theme_font_size_override("font_size", 11)
	l2.add_theme_color_override("font_color", Color("#94a3b8"))
	hb.add_child(l2)
	return p


func _switch_hero(hid: String, with_vfx: bool):
	if hero_hp[hid] <= 0.0:
		return
	var prev_hid := active_hero_id
	active_hero_id = hid
	var data: Dictionary = HeroData.HEROES[hid]
	player_light.color = data["color"]
	player_sprite.texture = _get_hero_tex(hid, "stride_0")
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
	for e in enemies.duplicate():
		if is_instance_valid(e):
			e.queue_free()
	enemies.clear()
	for ob in orbit_blades.duplicate():
		if is_instance_valid(ob):
			ob.queue_free()
	orbit_blades.clear()
	boss_panel.visible = false
	player.global_position = Vector2((4.2 + float(room_idx * ROOM_STRIDE)) * TILE_SIZE, 4.5 * TILE_SIZE)
	camera.reset_smoothing()
	_spawn_room_wave(room_idx)


func _spawn_room_wave(room_idx: int):
	current_room = clampi(room_idx, 0, _total_rooms() - 1)
	if sfx and sfx.has_method("set_bgm_mode"):
		sfx.set_bgm_mode(current_room == 9)
	if minimap_ctrl:
		minimap_ctrl.queue_redraw()
	var cdata := ChapterData.get_chapter(chapter)
	var floor_no := ChapterData.get_floor_number(chapter, current_room)
	var zone_name := ChapterData.get_zone_name(chapter, current_room)
	var ch_title := str(cdata["title"])
	var bx := float(current_room * ROOM_STRIDE)

	if current_room in [0, 1, 2, 3]:
		room_label.text = "ชั้นที่ %d/100 — บทที่ %d: %s · %s (%d/10) [%s]" % [floor_no, chapter, ch_title, zone_name, current_room + 1, cdata["mob_a"]]
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
		_show_banner("🛡️ มินิบอสชั้นที่ %d: %s! ใช้ [E]/[R] ทะลวงเกราะ!" % [floor_no, cdata["miniboss"]], 2.8)
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
		b_sp.texture = load(str(cdata["boss_tex"]))
		var b_sc := float(cdata["boss_scale"])
		b_sp.scale = Vector2(b_sc, b_sc)
		b_sp.offset = Vector2(0, -b_sp.texture.get_height() * 0.42) if b_sp.texture else Vector2.ZERO
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
		_show_banner("☠️ บอสประจำบทที่ %d: %s ปรากฏตัว!" % [chapter, cdata["boss"]], 2.8)


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
	e.set_meta("shield", float(def.get("shield", 0.0)) * mult)
	e.set_meta("max_shield", float(def.get("shield", 0.0)) * mult)

	var col := CollisionShape2D.new()
	var sh := CircleShape2D.new()
	sh.radius = 28.0 if def["is_boss"] else 18.0
	col.shape = sh
	e.add_child(col)

	var shadow := Polygon2D.new()
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
	sp.texture = load(def["tex"])
	var sc: float = def["scale"]
	sp.scale = Vector2(sc, sc)
	var base_tint: Color = def.get("tint", Color.WHITE)
	sp.modulate = Color(1.18, 1.14, 1.14, 1.0) if base_tint == Color.WHITE else base_tint
	sp.offset = Vector2(0, -sp.texture.get_height() * 0.42) if sp.texture else Vector2.ZERO
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

	world_node.add_child(e)
	enemies.append(e)


func _get_nearest_enemy(max_dist: float = 540.0) -> CharacterBody2D:
	var best: CharacterBody2D = null
	var best_d := max_dist
	for e in enemies:
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
	if game_over or victory:
		if Input.is_key_pressed(KEY_ENTER):
			_on_end_action_pressed()
		return

	var kh := Input.is_key_pressed(KEY_H)
	if kh and not _prev_h:
		_toggle_help_overlay()
	_prev_h = kh
	if help_overlay and help_overlay.visible:
		if Input.is_key_pressed(KEY_ENTER) or Input.is_key_pressed(KEY_ESCAPE):
			help_overlay.visible = false
		return

	if boon_overlay and boon_overlay.visible:
		if Input.is_key_pressed(KEY_1):
			_pick_boon(0)
		elif Input.is_key_pressed(KEY_2):
			_pick_boon(1)
		elif Input.is_key_pressed(KEY_3):
			_pick_boon(2)
		return

	var ku := Input.is_key_pressed(KEY_U)
	if ku and not _prev_u:
		_toggle_upgrade_modal()
	_prev_u = ku
	if upgrade_overlay and upgrade_overlay.visible:
		return

	if hitstop_timer > 0.0:
		hitstop_timer -= delta
		Engine.time_scale = 0.08 if hitstop_timer > 0.0 else 1.0
		if hitstop_timer <= 0.0:
			Engine.time_scale = 1.0
		return

	hero_sp[active_hero_id] = minf(_get_hero_stat(active_hero_id, "max_sp"), hero_sp[active_hero_id] + 9.0 * delta)
	q_cd = maxf(0.0, q_cd - delta)
	e_cd = maxf(0.0, e_cd - delta)
	r_cd = maxf(0.0, r_cd - delta)
	dash_cooldown = maxf(0.0, dash_cooldown - delta)
	invuln_timer = maxf(0.0, invuln_timer - delta)
	pose_override_timer = maxf(0.0, pose_override_timer - delta)
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

	_handle_one_handed_actions()
	_process_camera_shake(delta)
	_process_projectiles(delta)
	_process_enemy_projectiles(delta)
	_process_sawblades(delta)
	_process_heal_orbs()
	_process_enemies(delta)
	_check_room_progression()
	_refresh_hud()


func _physics_process(delta: float):
	if game_over or victory or hitstop_timer > 0.0 or (upgrade_overlay and upgrade_overlay.visible) or (help_overlay and help_overlay.visible) or (boon_overlay and boon_overlay.visible):
		return

	var move_vec := Vector2(
		float(Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT)) - float(Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT)),
		float(Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN)) - float(Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP))
	).normalized()

	if move_vec.length() > 0.1:
		facing_dir = move_vec

	var aim_dir := _get_auto_aim_dir()
	var face_vec := aim_dir if _get_nearest_enemy(350.0) != null else facing_dir
	if face_vec.x < -0.05:
		player_sprite.flip_h = true
	elif face_vec.x > 0.05:
		player_sprite.flip_h = false

	var sp_now := Input.is_key_pressed(KEY_SPACE)
	if sp_now and not _prev_space and dash_cooldown <= 0.0 and dash_timer <= 0.0:
		dash_dir = move_vec if move_vec.length() > 0.1 else facing_dir
		dash_timer = 0.18
		dash_cooldown = 0.80
		invuln_timer = 0.28
		sfx.play_sfx("dash")
		_spawn_ghost_afterimage()
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
		player_sprite.texture = _get_hero_tex(active_hero_id, "dash", player_sprite.texture)
		if int(dash_timer * 60.0) % 3 == 0:
			_spawn_ghost_afterimage()
		return

	var f_now := Input.is_key_pressed(KEY_F)
	var f_just := f_now and not _prev_f
	_prev_f = f_now

	var data: Dictionary = HeroData.HEROES[active_hero_id]
	var auto_trigger := false
	if auto_attack_enabled:
		var nearest := _get_nearest_enemy(float(data["range"]) + 20.0)
		if nearest != null:
			auto_trigger = true

	if (f_just or auto_trigger) and attack_timer <= 0.0 and pose_override_timer <= 0.0:
		_perform_basic_attack(aim_dir)

	if pose_override_timer > 0.0:
		player_sprite.texture = _get_hero_tex(active_hero_id, pose_override_key, player_sprite.texture)
		player.velocity = move_vec * data["speed"] * 0.25
		player.move_and_slide()
		return

	if attack_timer > 0.0:
		attack_timer -= delta
		var frame_idx := clampi(int((0.28 - attack_timer) / 0.09), 0, 2)
		player_sprite.texture = _get_hero_tex(active_hero_id, "strike_%d" % frame_idx, player_sprite.texture)
		player.velocity = move_vec * data["speed"] * 0.45
		player.move_and_slide()
		return

	player.velocity = move_vec * data["speed"]
	player.move_and_slide()

	if move_vec.length() > 0.1:
		walk_timer += delta
		if walk_timer >= 0.11:
			walk_timer = 0.0
			walk_step = (walk_step + 1) % 4
		var seq: int = [0, 1, 2, 1][walk_step]
		player_sprite.texture = _get_hero_tex(active_hero_id, "stride_%d" % seq, player_sprite.texture)
	else:
		player_sprite.texture = _get_hero_tex(active_hero_id, "stride_0", player_sprite.texture)


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
		auto_attack_enabled = not auto_attack_enabled
		_show_banner("โหมดตีอัตโนมัติ: %s" % ("เปิด (ON)" if auto_attack_enabled else "ปิด (OFF)"), 1.2)
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
	attack_timer = 0.28
	var data: Dictionary = HeroData.HEROES[active_hero_id]
	var atk := int(_get_hero_stat(active_hero_id, "atk"))
	if data["is_ranged"]:
		sfx.play_sfx("talisman")
		VfxStudio.spawn_critical_star_burst(fx_layer, player.global_position + aim_dir * 32.0, data["color"], 0.45)
		_spawn_projectile(player.global_position + aim_dir * 26.0, aim_dir, atk, data["vfx_attack"], data["color"], 660.0, false)
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
				_damage_enemy(e, atk, aim_dir, data["color"], data["crit"], false)
				hit_any = true
		if hit_any:
			shake_strength = 5.5


func _cast_skill_q(aim_dir: Vector2):
	var data: Dictionary = HeroData.HEROES[active_hero_id]
	if q_cd > 0.0 or hero_sp[active_hero_id] < data["q_cost"]:
		return
	hero_sp[active_hero_id] -= data["q_cost"]
	q_cd = 3.0 * (0.80 if active_boons.has("swift_qi") else 1.0)
	var atk := _get_hero_stat(active_hero_id, "atk")
	pose_override_key = "skill_1"
	pose_override_timer = 0.28
	shake_strength = 7.0
	sfx.play_sfx("skill_q")
	_show_banner("✨ %s!" % data["q_name"], 1.0)
	VfxStudio.spawn_azure_star_slash(fx_layer, player.global_position + aim_dir * 36.0, aim_dir.angle(), data["color"], 1.25)

	if active_hero_id == "bai_yueling":
		for ang in [-0.28, 0.0, 0.28]:
			var d := aim_dir.rotated(ang)
			_spawn_projectile(player.global_position + d * 28.0, d, int(atk * 1.35), data["vfx_attack"], data["color"], 720.0, true)
	elif active_hero_id == "ye_shangye":
		_spawn_slash_vfx(player.global_position + aim_dir * 75.0, aim_dir.angle(), data["vfx_attack"], data["color"], 1.55)
		for e in enemies:
			if not is_instance_valid(e):
				continue
			if e.global_position.distance_to(player.global_position) <= 240.0:
				var pull_pos := player.global_position + aim_dir * 68.0
				var tw := create_tween()
				tw.tween_property(e, "global_position", pull_pos, 0.16)
				_damage_enemy(e, int(atk * 1.45), aim_dir, data["color"], 0.30, true)
				e.set_meta("stun", 0.85)
	elif active_hero_id == "song_ren":
		for ang in [-0.40, -0.20, 0.0, 0.20, 0.40]:
			var d := aim_dir.rotated(ang)
			_spawn_projectile(player.global_position + d * 28.0, d, int(atk * 1.15), data["vfx_attack"], data["color"], 700.0, true)
	else:
		var reach := 270.0 if active_hero_id == "yu_han" else 220.0
		_spawn_slash_vfx(player.global_position + aim_dir * 65.0, aim_dir.angle(), data["vfx_attack"], data["color"], 1.35)
		for e in enemies:
			if is_instance_valid(e) and e.global_position.distance_to(player.global_position) <= reach:
				_damage_enemy(e, int(atk * 1.40), aim_dir, data["color"], _get_hero_stat(active_hero_id, "crit"), true)


func _cast_skill_e():
	var data: Dictionary = HeroData.HEROES[active_hero_id]
	if e_cd > 0.0 or hero_sp[active_hero_id] < data["e_cost"]:
		return
	hero_sp[active_hero_id] -= data["e_cost"]
	e_cd = 6.0 * (0.80 if active_boons.has("swift_qi") else 1.0)
	last_skill_er_timer = 2.5
	var atk := _get_hero_stat(active_hero_id, "atk")
	pose_override_key = "skill_2"
	pose_override_timer = 0.36
	shake_strength = 12.0
	sfx.play_sfx("skill_e")
	_show_banner("🔥 %s! (สลับตัว [1/2/3/Tab] เพื่อผสานปราณ!)" % data["e_name"], 1.4)
	_spawn_ring_vfx(player.global_position, data["color"], 210.0)
	VfxStudio.spawn_frostbound_eruption(floor_layer, fx_layer, player.global_position, data["color"])
	VfxStudio.spawn_galaxy_vortex(floor_layer, player.global_position, data["color"], 185.0)

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
	for e in enemies:
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
	if r_cd > 0.0 or hero_sp[active_hero_id] < data["r_cost"]:
		return
	hero_sp[active_hero_id] -= data["r_cost"]
	r_cd = 12.0 * (0.80 if active_boons.has("swift_qi") else 1.0)
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

	for e in enemies:
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


func _damage_enemy(e: CharacterBody2D, base_dmg: int, push_dir: Vector2, col: Color, crit_chance: float, is_skill: bool = false):
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

	if is_skill:
		var prev_mark: String = str(e.get_meta("qi_mark", ""))
		if prev_mark != "" and prev_mark != active_hero_id:
			e.set_meta("qi_mark", "")
			if e.has_node("MarkLabel"):
				e.get_node("MarkLabel").text = ""
			var res_mult := 2.75 if int(save_data.get("hero_passives", {}).get("ye_shangye", 0)) > 0 else 2.2
			var res_dmg := int(_get_hero_stat(active_hero_id, "atk") * res_mult)
			base_dmg += res_dmg
			sfx.play_sfx("resonance")
			_spawn_ring_vfx(e.global_position, Color("#fde047"), 105.0)
			_spawn_floating_text(e.global_position + Vector2(0, -82), "⚡ ผสานปราณ! +%d" % res_dmg, Color("#fde047"), true)
			_award_spirit_jade(4)
		else:
			e.set_meta("qi_mark", active_hero_id)
			if e.has_node("MarkLabel"):
				e.get_node("MarkLabel").text = ("❄️" if active_hero_id == "bai_yueling" else ("🩸" if active_hero_id == "ye_shangye" else "⚡"))

	var is_crit := randf() < crit_chance
	var crit_mult := 2.15 if (active_hero_id == "bai_yueling" and int(save_data.get("hero_passives", {}).get("bai_yueling", 0)) > 0) else 1.80
	var dmg := int(base_dmg * (crit_mult if is_crit else 1.0))
	var hp: float = e.get_meta("hp") - dmg
	e.set_meta("hp", hp)
	e.set_meta("flash", 0.14)
	if not def.get("is_turret", false):
		e.set_meta("kb", push_dir * (140.0 if (def["is_boss"] or def.get("is_miniboss", false)) else 360.0))

	if is_crit:
		hitstop_timer = 0.04
		shake_strength = maxf(shake_strength, 8.5)
		sfx.play_sfx("crit")
		VfxStudio.spawn_critical_star_burst(fx_layer, e.global_position + Vector2(0, -32), col, 0.90)
		if active_hero_id == "chen_xi":
			hero_hp["chen_xi"] = minf(_get_hero_stat("chen_xi", "max_hp"), hero_hp["chen_xi"] + 6.0)
	else:
		sfx.play_sfx("hit")

	_spawn_floating_text(e.global_position + Vector2(0, -52), ("★ %d!" % dmg) if is_crit else str(dmg), col, is_crit)

	if hp <= 0.0:
		_spawn_ring_vfx(e.global_position, col, 48.0)
		var was_boss: bool = def["is_boss"]
		var was_mini: bool = def.get("is_miniboss", false)
		enemies.erase(e)
		e.queue_free()
		if active_hero_id == "yu_han":
			hero_hp["yu_han"] = minf(_get_hero_stat("yu_han", "max_hp"), hero_hp["yu_han"] + 8.0)
		if active_boons.has("blood_lotus"):
			hero_hp[active_hero_id] = minf(_get_hero_stat(active_hero_id, "max_hp"), hero_hp[active_hero_id] + 5.0)
		if was_mini:
			_award_spirit_jade(15)
			_spawn_floating_text(player.global_position + Vector2(0, -78), "+15 💎 หยกปราณ!", Color("#5eead4"), true)
		if was_boss:
			_award_spirit_jade(35)
			_trigger_victory()


func _process_enemies(delta: float):
	var hard := str(save_data.get("difficulty", "normal")) == "hard"
	var spd_mult := 1.20 if hard else 1.0
	for e in enemies.duplicate():
		if not is_instance_valid(e):
			enemies.erase(e)
			continue
		var kind: String = e.get_meta("kind")
		var def: Dictionary = MONSTER_DEFS[kind]
		var sp: Sprite2D = e.get_node("Sprite")
		var cdata := ChapterData.get_chapter(chapter)
		var base_tint: Color = e.get_meta("custom_tint", cdata["boss_tint"] if def["is_boss"] else def.get("tint", Color.WHITE))

		var trap_cd: float = float(e.get_meta("trap_cd", 0.0))
		if trap_cd > 0.0:
			e.set_meta("trap_cd", trap_cd - delta)

		var flash: float = e.get_meta("flash")
		if flash > 0.0:
			flash -= delta
			e.set_meta("flash", flash)
			sp.modulate = Color(3.0, 3.0, 3.0, 1.0) if flash > 0.0 else base_tint

		var kb: Vector2 = e.get_meta("kb")
		if kb.length() > 10.0:
			e.velocity = kb
			e.move_and_slide()
			e.set_meta("kb", kb.lerp(Vector2.ZERO, 12.0 * delta))
			continue

		var stun: float = e.get_meta("stun")
		if stun > 0.0:
			e.set_meta("stun", stun - delta)
			sp.modulate = Color(0.5, 0.85, 1.0, 1.0)
			continue
		elif flash <= 0.0:
			sp.modulate = base_tint

		if def["is_boss"] and not bool(e.get_meta("phase2_done", false)) and float(e.get_meta("hp")) < float(e.get_meta("max_hp")) * 0.5:
			e.set_meta("phase2_done", true)
			boss_name_label.text = "☠️ %s (เฟส 2 — %s!)" % [cdata["boss"], cdata["ult_name"]]
			_show_banner("🔥 เฟส 2! ท่าไม้ตายบอส: %s! พุ่งเข้าจุดปลอดภัยตรงกลาง!" % cdata["ult_name"], 3.0)
			_spawn_ring_vfx(e.global_position, Color("#ef4444"), 240.0)
			var push_out: Vector2 = (player.global_position - e.global_position).normalized()
			player.global_position += push_out * 90.0
			VfxStudio.spawn_boss_ultimate_vfx(floor_layer, fx_layer, e.global_position, chapter, cdata["light_color"])
			_spawn_orbit_blades(e.global_position)
			_start_eight_dir_storm(e)

		var to_p: Vector2 = player.global_position - e.global_position
		var dist: float = to_p.length()
		var casting: float = e.get_meta("casting")
		if casting > 0.0:
			e.set_meta("casting", casting - delta)
			sp.modulate = Color(1.8, 0.7, 1.8, 1.0)
		elif def.get("is_turret", false):
			var atk_cd: float = e.get_meta("atk_cd") - delta
			e.set_meta("atk_cd", atk_cd)
			if atk_cd <= 0.0 and dist < 620.0:
				e.set_meta("atk_cd", 2.2)
				_spawn_enemy_orb(e.global_position, to_p.normalized(), 16)
		elif dist < 560.0:
			sp.flip_h = to_p.x < 0.0
			var atk_cd: float = e.get_meta("atk_cd") - delta
			e.set_meta("atk_cd", atk_cd)
			var special_cd: float = e.get_meta("special_cd") - delta
			e.set_meta("special_cd", special_cd)

			if (def["is_boss"] or kind == "golem" or kind == "bronze_sentinel") and special_cd <= 0.0 and dist < 380.0:
				if kind == "golem" or kind == "bronze_sentinel":
					e.set_meta("special_cd", 4.0)
					_start_slam_telegraph(e, 120.0, 26, 0.72)
				elif kind == "boss_ch3":
					e.set_meta("special_cd", 2.9)
					var phase: int = e.get_meta("boss_phase")
					e.set_meta("boss_phase", (phase + 1) % 3)
					if phase == 0:
						_start_laser_telegraph(e, to_p.normalized())
					elif phase == 1 and bool(e.get_meta("phase2_done", false)):
						_start_eight_dir_storm(e)
					else:
						_start_boss_wave_attack(e, to_p.normalized())
				else:
					e.set_meta("special_cd", 2.7 if kind == "boss_ch2" else 3.1)
					var phase: int = e.get_meta("boss_phase")
					e.set_meta("boss_phase", (phase + 1) % 2)
					if phase == 0:
						_start_slam_telegraph(e, 175.0 if kind == "boss_ch2" else 165.0, 42 if kind == "boss_ch2" else 38, 0.72 if kind == "boss_ch2" else 0.85)
					else:
						_start_boss_wave_attack(e, to_p.normalized())
			elif dist > def["range"]:
				e.velocity = to_p.normalized() * float(def["speed"]) * spd_mult
				e.move_and_slide()
			elif atk_cd <= 0.0:
				e.set_meta("atk_cd", 1.35 if def["is_boss"] else 1.65)
				_enemy_hit_player(def["atk"], e.global_position, def["is_boss"])

		if def["is_boss"]:
			boss_bar.max_value = e.get_meta("max_hp")
			boss_bar.value = e.get_meta("hp")
		elif e.has_node("HPBg/HPFg"):
			var fg: ColorRect = e.get_node("HPBg/HPFg")
			var max_w := 54.0 if def.get("is_miniboss", false) else 44.0
			fg.size.x = max_w * clampf(e.get_meta("hp") / e.get_meta("max_hp"), 0.0, 1.0)


func _enemy_hit_player(dmg: int, _src_pos: Vector2, is_boss: bool):
	if invuln_timer > 0.0:
		return
	invuln_timer = 0.45
	var final_dmg := int(round(float(dmg) * (0.82 if active_boons.has("jade_aegis") else 1.0)))
	hero_hp[active_hero_id] = maxf(0.0, hero_hp[active_hero_id] - final_dmg)
	shake_strength = 10.0 if is_boss else 6.0
	_spawn_floating_text(player.global_position + Vector2(0, -54), "-%d" % final_dmg, Color("#ef4444"), false)

	if hero_hp[active_hero_id] <= 0.0:
		for hid in active_party:
			if hero_hp[hid] > 0.0:
				_switch_hero(hid, true)
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
				_damage_enemy(e, p.get_meta("dmg"), p.get_meta("vel").normalized(), p.get_meta("col"), 0.25, bool(p.get_meta("is_skill", false)))
				projectiles.erase(p)
				p.queue_free()
				break


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
			var floor_no := ChapterData.get_floor_number(chapter, current_room)
			_show_banner("✨ ชั้นที่ %d/100 เคลียร์! (+5 💎) เก็บโอสถหยกแล้วเดินไปทางขวา" % floor_no, 2.8)
			if (current_room == 4 or current_room == 8) and not boon_granted_rooms.has(current_room):
				boon_granted_rooms[current_room] = true
				_open_boon_picker()

	var next_x := (15.5 + float(current_room * ROOM_STRIDE)) * TILE_SIZE
	if current_room < total - 1 and player.global_position.x > next_x:
		_spawn_room_wave(current_room + 1)


func _spawn_projectile(pos: Vector2, dir: Vector2, dmg: int, tex_path: String, col: Color, speed: float = 640.0, is_skill: bool = false):
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
	var poly := Polygon2D.new()
	poly.polygon = _make_ellipse(14.0, 14.0, 16)
	poly.color = Color("#4ade80")
	orb.add_child(poly)
	_add_light(orb, Color("#4ade80"), 1.5, 2.2)
	world_node.add_child(orb)
	heal_orbs.append(orb)


func _process_heal_orbs():
	for orb in heal_orbs.duplicate():
		if not is_instance_valid(orb):
			heal_orbs.erase(orb)
			continue
		if player.global_position.distance_to(orb.global_position) < 48.0:
			var max_hp := _get_hero_stat(active_hero_id, "max_hp")
			var max_sp := _get_hero_stat(active_hero_id, "max_sp")
			var bonus := float(save_data.get("core_upgrades", {}).get("orb_lv", 0)) * 15.0
			var heal_hp := 40.0 + bonus
			var heal_sp := 30.0 + bonus
			hero_hp[active_hero_id] = minf(max_hp, hero_hp[active_hero_id] + heal_hp)
			hero_sp[active_hero_id] = minf(max_sp, hero_sp[active_hero_id] + heal_sp)
			sfx.play_sfx("dodge")
			_spawn_floating_text(player.global_position + Vector2(0, -54), "+%d HP +%d ปราณ!" % [int(heal_hp), int(heal_sp)], Color("#4ade80"), true)
			heal_orbs.erase(orb)
			orb.queue_free()


func _spawn_ghost_afterimage():
	var g := Sprite2D.new()
	g.texture = player_sprite.texture
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
	var lbl := Label.new()
	lbl.text = text_val
	lbl.position = pos + Vector2(randf_range(-16, 16), 0)
	lbl.add_theme_font_size_override("font_size", 24 if is_big else 16)
	lbl.add_theme_color_override("font_color", Color("#fde047") if is_big else col)
	lbl.add_theme_color_override("font_outline_color", Color.BLACK)
	lbl.add_theme_constant_override("outline_size", 4)
	fx_layer.add_child(lbl)
	var tw := create_tween()
	tw.tween_property(lbl, "position:y", lbl.position.y - 36.0, 0.55).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(lbl, "modulate:a", 0.0, 0.55)
	tw.tween_callback(lbl.queue_free)


func _process_camera_shake(delta: float):
	if shake_strength > 0.1:
		camera.offset = Vector2(randf_range(-shake_strength, shake_strength), randf_range(-shake_strength, shake_strength))
		shake_strength = lerpf(shake_strength, 0.0, 12.0 * delta)
	else:
		camera.offset = Vector2.ZERO


func _show_banner(msg: String, duration: float):
	banner_label.text = msg
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

	for hid in active_party:
		if not hero_cards.has(hid):
			continue
		var card: PanelContainer = hero_cards[hid]
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.08, 0.11, 0.16, 0.9)
		sb.border_color = Color("#fde047") if hid == active_hero_id else Color(0.3, 0.35, 0.45, 0.6)
		sb.set_border_width_all(3 if hid == active_hero_id else 1)
		sb.set_corner_radius_all(8)
		card.add_theme_stylebox_override("panel", sb)
		card.modulate = Color(0.35, 0.35, 0.35, 0.7) if hero_hp[hid] <= 0.0 else Color.WHITE

	q_title_lbl.text = "[Q] " + data["q_name"]
	e_title_lbl.text = "[E] " + data["e_name"]
	r_title_lbl.text = "[R] " + data["r_name"]

	q_val_lbl.text = ("%.1fs" % q_cd) if q_cd > 0.0 else "พร้อมใช้"
	e_val_lbl.text = ("%.1fs" % e_cd) if e_cd > 0.0 else "พร้อมใช้"
	r_val_lbl.text = ("%.1fs" % r_cd) if r_cd > 0.0 else "พร้อมใช้"
	dash_val_lbl.text = ("%.1fs" % dash_cooldown) if dash_cooldown > 0.0 else "พร้อมใช้"
	auto_val_lbl.text = "ออโต้: ON" if auto_attack_enabled else "ออโต้: OFF"
	if jade_label:
		jade_label.text = "💎 หยกปราณ: %d" % int(save_data.get("spirit_jade", 0))
	if diff_btn:
		diff_btn.text = "โหมด: ท้าทาย" if str(save_data.get("difficulty", "normal")) == "hard" else "โหมด: ปกติ"


func _trigger_victory():
	boss_panel.visible = false
	sfx.play_sfx("victory")
	var cleared: Array = save_data.get("cleared_chapters", [])
	var first_clear_bonus := 0
	if not cleared.has(chapter):
		cleared.append(chapter)
		save_data["cleared_chapters"] = cleared
		first_clear_bonus = 50
		save_data["spirit_jade"] = int(save_data.get("spirit_jade", 0)) + first_clear_bonus
		SaveManager.save_data(save_data, save_path)

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
	end_overlay.visible = true


func _trigger_defeat():
	game_over = true
	end_title.text = "💀 เหล่าผู้กล้าพ่ายแพ้"
	restart_btn.text = "🔄 ลองใหม่อีกครั้ง [Enter]"
	end_title.add_theme_color_override("font_color", Color("#f87171"))
	end_overlay.visible = true


func _on_end_action_pressed():
	if victory:
		var nxt := (chapter + 1) if chapter < ChapterData.TOTAL_CHAPTERS else 1
		Globals.set_meta("chapter", nxt)
	get_tree().reload_current_scene()


func _start_slam_telegraph(e: CharacterBody2D, radius: float, dmg: int, windup: float):
	e.set_meta("casting", windup + 0.15)
	sfx.play_sfx("boss_warn")
	var target_pos: Vector2 = player.global_position if e.get_meta("kind") == "boss" else e.global_position

	var outer := Polygon2D.new()
	outer.polygon = _make_ellipse(radius, radius * 0.72, 28)
	outer.color = Color(0.95, 0.18, 0.25, 0.22)
	outer.position = target_pos
	outer.z_index = -4
	add_child(outer)

	var inner := Polygon2D.new()
	inner.polygon = _make_ellipse(radius, radius * 0.72, 28)
	inner.color = Color(0.98, 0.22, 0.30, 0.50)
	inner.scale = Vector2(0.05, 0.05)
	outer.add_child(inner)

	var tw := create_tween()
	tw.tween_property(inner, "scale", Vector2(1.0, 1.0), windup)
	tw.tween_callback(_execute_slam.bind(e, target_pos, radius, dmg, outer))


func _execute_slam(e: Variant, pos: Vector2, radius: float, dmg: int, warn_node: Node2D):
	if is_instance_valid(warn_node):
		warn_node.queue_free()
	if not is_instance_valid(e) or game_over or victory:
		return
	sfx.play_sfx("boss_slam")
	shake_strength = 13.5
	var cdata := ChapterData.get_chapter(chapter)
	VfxStudio.spawn_critical_star_burst(fx_layer, pos, cdata["light_color"], 1.35)
	_spawn_ring_vfx(pos, Color("#f43f5e"), radius)
	_spawn_burst_vfx(pos, "res://assets/vfx/vfx_firaga.png", 1.3)

	if player.global_position.distance_to(pos) <= radius:
		if invuln_timer > 0.0:
			sfx.play_sfx("dodge")
			_award_spirit_jade(4)
			_spawn_floating_text(player.global_position + Vector2(0, -56), "⚡ หลบพ้น! +4 💎", Color("#2dd4bf"), true)
		else:
			_enemy_hit_player(dmg, pos, true)


func _start_boss_wave_attack(e: CharacterBody2D, dir: Vector2):
	e.set_meta("casting", 0.65)
	sfx.play_sfx("boss_warn")
	var tw := create_tween()
	tw.tween_interval(0.50)
	tw.tween_callback(_fire_boss_waves.bind(e, dir))


func _fire_boss_waves(e: Variant, dir: Vector2):
	if not is_instance_valid(e) or game_over or victory:
		return
	sfx.play_sfx("boss_slam")
	var angles := [-0.45, -0.22, 0.0, 0.22, 0.45] if e.get_meta("kind") == "boss_ch2" else [-0.30, 0.0, 0.30]
	for ang in angles:
		var d := dir.rotated(ang)
		var p := Sprite2D.new()
		p.texture = load("res://assets/vfx/vfx_whip_blood_chain.png")
		p.position = e.global_position + d * 36.0
		p.rotation = d.angle()
		p.scale = Vector2(0.85, 0.85)
		p.modulate = Color("#f43f5e")
		p.set_meta("vel", d * 390.0)
		p.set_meta("dmg", 22)
		p.set_meta("life", 1.6)
		fx_layer.add_child(p)
		enemy_projectiles.append(p)


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
			if invuln_timer > 0.0:
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
	e.set_meta("casting", 0.95)
	sfx.play_sfx("laser_warn")
	var line := Line2D.new()
	line.points = PackedVector2Array([e.global_position, e.global_position + dir * 520.0])
	line.width = 6.0
	line.default_color = Color(1.0, 0.2, 0.25, 0.7)
	fx_layer.add_child(line)
	var tw := create_tween()
	tw.tween_interval(0.80)
	tw.tween_callback(_fire_laser_beam.bind(e, dir, line))


func _fire_laser_beam(e: Variant, dir: Vector2, line: Line2D):
	if is_instance_valid(line):
		line.queue_free()
	if not is_instance_valid(e) or game_over or victory:
		return
	sfx.play_sfx("boss_slam")
	for ang in [-0.14, 0.0, 0.14]:
		_spawn_enemy_orb(e.global_position, dir.rotated(ang), 24)


func _start_eight_dir_storm(e: CharacterBody2D):
	e.set_meta("casting", 1.25)
	sfx.play_sfx("boss_warn")
	var center := Vector2((7.5 + float(current_room * ROOM_STRIDE)) * TILE_SIZE, 4.5 * TILE_SIZE)
	var danger := Polygon2D.new()
	danger.polygon = _make_ellipse(360.0, 230.0, 32)
	danger.color = Color(0.95, 0.16, 0.24, 0.25)
	danger.position = center
	danger.z_index = -5
	add_child(danger)

	var safe := Polygon2D.new()
	safe.polygon = _make_ellipse(92.0, 68.0, 24)
	safe.color = Color(0.22, 0.90, 0.45, 0.35)
	danger.add_child(safe)

	var tw := create_tween()
	tw.tween_interval(1.10)
	tw.tween_callback(_execute_eight_dir_storm.bind(e, center, danger))


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
		# Eruption / Lightning / Sword Array / Lava / Seal Hazard Telegraph at player position
		var target_pos := player.global_position
		var warn := Polygon2D.new()
		warn.polygon = _make_ellipse(78.0, 56.0, 20)
		warn.color = Color(lcol.r, lcol.g, lcol.b, 0.28)
		warn.position = target_pos
		warn.z_index = -4
		add_child(warn)
		var tw := create_tween()
		tw.tween_interval(0.75)
		tw.tween_callback(func():
			if is_instance_valid(warn):
				warn.queue_free()
			if game_over or victory:
				return
			_spawn_ring_vfx(target_pos, lcol, 82.0)
			if player.global_position.distance_to(target_pos) <= 78.0 and invuln_timer <= 0.0:
				_enemy_hit_player(16, target_pos, false)
		)


func _execute_eight_dir_storm(e: Variant, center: Vector2, warn_node: Node2D):
	if is_instance_valid(warn_node):
		warn_node.queue_free()
	if not is_instance_valid(e) or game_over or victory:
		return
	sfx.play_sfx("ultimate")
	shake_strength = 15.0
	var cdata := ChapterData.get_chapter(chapter)
	VfxStudio.spawn_boss_ultimate_vfx(floor_layer, fx_layer, e.global_position, chapter, cdata["light_color"])
	for i in range(8):
		var a := (float(i) / 8.0) * TAU
		_spawn_enemy_orb(e.global_position, Vector2(cos(a), sin(a)), 26)
	var d := player.global_position.distance_to(center)
	if d <= 96.0:
		sfx.play_sfx("dodge")
		_award_spirit_jade(5)
		_spawn_floating_text(player.global_position + Vector2(0, -56), "⚡ หลบพายุพ้น! +5 💎", Color("#4ade80"), true)
	elif invuln_timer <= 0.0:
		_enemy_hit_player(34, center, true)


func _award_spirit_jade(base_amt: int):
	var mult := 1.5 if str(save_data.get("difficulty", "normal")) == "hard" else 1.0
	var gain := maxi(1, int(round(float(base_amt) * mult)))
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
	codex_tab = clampi(idx, 0, 2)
	if codex_upgrade_scroll:
		codex_upgrade_scroll.visible = (codex_tab == 0)
	if codex_party_scroll:
		codex_party_scroll.visible = (codex_tab == 1)
	if codex_chapters_box:
		codex_chapters_box.visible = (codex_tab == 2)
	for i in range(codex_tab_btns.size()):
		var b: Button = codex_tab_btns[i]
		if i == codex_tab:
			b.add_theme_color_override("font_color", Color("#fde047"))
		else:
			b.remove_theme_color_override("font_color")


func _toggle_help_overlay():
	if help_overlay:
		help_overlay.visible = not help_overlay.visible


func _open_boon_picker():
	if not boon_overlay:
		return
	var pool := CodexUI.BOON_DEFS.duplicate()
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
	if chosen["id"] == "jade_aegis":
		for hid in active_party:
			if hero_hp[hid] > 0.0:
				hero_hp[hid] = minf(_get_hero_stat(hid, "max_hp"), hero_hp[hid] + 25.0)
	sfx.play_sfx("resonance")
	_show_banner("⛩️ รับพรเซียน: %s!" % chosen["title"], 2.0)


func _start_boss_rush():
	Globals.set_meta("chapter", 1)
	Globals.set_meta("boss_rush", true)
	Globals.set_meta("skip_intro", true)
	get_tree().reload_current_scene()


func _toggle_upgrade_modal():
	upgrade_overlay.visible = not upgrade_overlay.visible
	if upgrade_overlay.visible:
		_rebuild_upgrade_list()


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
		player_sprite.texture = _get_hero_tex(hid, "stride_0", player_sprite.texture)
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
	Globals.set_meta("chapter", ch_idx)
	get_tree().reload_current_scene()
