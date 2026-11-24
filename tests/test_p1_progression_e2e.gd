extends SceneTree

const SaveManager = preload("res://scripts/save_manager.gd")
const EquipData = preload("res://scripts/equip_data.gd")
const CodexUI = preload("res://scripts/codex_ui.gd")

var _tick: int = 0
var _scene: Node2D
var _test_save := "user://test_p1_progression_save.json"


func _fail(msg: String):
	Engine.time_scale = 1.0
	printerr("FAIL: " + msg)
	quit(1)


func _check(cond: bool, msg: String) -> bool:
	if not cond:
		_fail(msg)
		return false
	return true


func _initialize():
	if FileAccess.file_exists(_test_save):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(_test_save))
	var fresh := SaveManager.load_data(_test_save)
	if not _check(fresh.get("owned_gear", []).size() == EquipData.STARTER_GEAR.size(), "Fresh save must start with 3 starter gear items"):
		return
	var globals := root.get_node("Globals")
	globals.set_meta("save_path", _test_save)
	globals.set_meta("chapter", 1)
	_scene = load("res://scenes/dark_jade_dungeon.tscn").instantiate()
	root.add_child(_scene)


func _process(_delta: float) -> bool:
	_tick += 1
	if _tick != 4:
		return false

	# 1. P1.1: 12 Boons + non-duplicate picker + stat effects
	if not _check(CodexUI.BOON_DEFS.size() == 12, "BOON_DEFS must contain 12 boons"):
		return true
	var base_atk: float = _scene._get_hero_stat("bai_yueling", "atk")
	var base_hp: float = _scene._get_hero_stat("bai_yueling", "max_hp")
	var base_sp: float = _scene._get_hero_stat("bai_yueling", "max_sp")
	var base_spd: float = _scene._get_hero_stat("bai_yueling", "speed")

	_scene.active_boons["qi_surge"] = true
	_scene.active_boons["swift_blade"] = true
	if not _check(_scene._get_hero_stat("bai_yueling", "max_sp") > base_sp, "qi_surge must boost max_sp"):
		return true
	if not _check(_scene._get_hero_stat("bai_yueling", "speed") > base_spd, "swift_blade must boost speed"):
		return true

	_scene._open_boon_picker()
	if not _check(_scene.boon_overlay.visible, "Boon picker must open"):
		return true
	for ch in _scene.boon_choices:
		if not _check(not _scene.active_boons.has(ch["id"]), "Boon picker must not offer already owned boon %s" % ch["id"]):
			return true
	_scene._pick_boon(0)
	if not _check(not _scene.boon_overlay.visible, "Picking boon must close boon overlay"):
		return true

	# 2. P1.3: Equip weapon + relic, forge new gear, persist across SaveManager
	_scene._toggle_equip_gear("jade_sword")
	_scene._toggle_equip_gear("spirit_orb")
	if not _check(_scene._get_hero_stat("bai_yueling", "atk") >= base_atk + 8.0, "Equipping jade_sword must add +8 ATK"):
		return true
	if not _check(_scene._get_hero_stat("bai_yueling", "max_hp") >= base_hp + 35.0, "Equipping spirit_orb must add +35 Max HP"):
		return true

	_scene.save_data["spirit_jade"] = 200
	_scene._forge_gear_item("thunder_spear")
	if not _check(_scene.save_data["owned_gear"].has("thunder_spear"), "Forging thunder_spear must add it to owned_gear"):
		return true
	if not _check(int(_scene.save_data["spirit_jade"]) == 155, "Forging thunder_spear must spend 45 spirit jade"):
		return true

	var reloaded := SaveManager.load_data(_test_save)
	if not _check(reloaded["owned_gear"].has("thunder_spear"), "Forged gear must persist across SaveManager.load_data"):
		return true
	if not _check(str(reloaded.get("hero_gear", {}).get("bai_yueling", {}).get("weapon", "")) == "jade_sword", "Equipped weapon must persist across SaveManager.load_data"):
		return true

	# Codex Tab 3: Armory UI populates cleanly
	_scene._set_codex_tab(3)
	if not _check(_scene.codex_gear_scroll.visible and _scene.codex_gear_box.get_child_count() >= EquipData.ITEM_ORDER.size(), "Codex Tab 3 must render all 10 gear items"):
		return true

	# 3. P1.2: Miniboss Room 5 & Boss Room 10 HUD + Boss gear drop
	for e in _scene.enemies.duplicate():
		if is_instance_valid(e):
			e.queue_free()
	_scene.enemies.clear()
	_scene._spawn_room_wave(4)
	if not _check(_scene.boss_panel.visible, "Miniboss Room 5 must display boss_panel"):
		return true

	for e in _scene.enemies.duplicate():
		if is_instance_valid(e):
			e.queue_free()
	_scene.enemies.clear()
	_scene._spawn_room_wave(9)
	if not _check(_scene.boss_panel.visible, "Boss Room 10 must display boss_panel"):
		return true

	var owned_before: int = _scene.save_data["owned_gear"].size()
	_scene._grant_boss_gear_drop(true)
	if not _check(_scene.save_data["owned_gear"].size() == owned_before + 1, "Boss kill drop must unlock a new unowned gear item"):
		return true

	# 4. P2: Cross-device Save Code export / import round-trip & invalid rejection
	_scene.save_data["spirit_jade"] = 777
	var code: String = SaveManager.export_save_code(_scene.save_data)
	if not _check(code.begins_with("MDM1:"), "Exported save code must begin with MDM1:"):
		return true
	var bad_res: Dictionary = SaveManager.import_save_code("BAD_CODE")
	if not _check(not bool(bad_res.get("ok", true)), "Invalid save code must be rejected"):
		return true
	_scene.save_data["spirit_jade"] = 10
	_scene._import_save_code(code)
	if not _check(int(_scene.save_data.get("spirit_jade", 0)) == 777, "Importing save code must restore spirit_jade=777"):
		return true

	# 5. Game Speed 1.0x <-> 1.5x toggle, sanitize, and HUD sync
	if not _check(is_equal_approx(float(SaveManager.sanitize_data({"game_speed": 1.5})["game_speed"]), 1.5), "sanitize_data must keep 1.5x game_speed"):
		return true
	if not _check(is_equal_approx(float(SaveManager.sanitize_data({"game_speed": 1.0})["game_speed"]), 1.0), "sanitize_data must keep 1.0x game_speed"):
		return true
	_scene._toggle_game_speed()
	if not _check(is_equal_approx(_scene.game_speed_mult, 1.5), "_toggle_game_speed must switch to 1.5x"):
		return true
	if not _check(_scene.speed_btn.text.contains("1.5"), "Top-right speed_btn must display 1.5x"):
		return true
	if not _check(_scene.mobile_controls.btn_speed.text.contains("1.5"), "Mobile controls btn_speed must display 1.5x"):
		return true
	_scene._toggle_game_speed()
	if not _check(is_equal_approx(_scene.game_speed_mult, 1.0), "_toggle_game_speed must switch back to 1.0x"):
		return true

	# 6. Gear Enhancement (+1..+5), CharacterStatusUI (Tab 5), Quick Drawer & Real-time Stat Preview
	_scene.save_data["spirit_jade"] = 500
	var atk_before_enh: float = _scene._get_hero_stat("bai_yueling", "atk")
	_scene._enhance_gear_item("jade_sword")
	if not _check(int(_scene.save_data.get("gear_levels", {}).get("jade_sword", 0)) == 1, "Enhancing jade_sword must set level to +1"):
		return true
	if not _check(_scene._get_hero_stat("bai_yueling", "atk") > atk_before_enh, "Enhancing equipped weapon must boost hero ATK"):
		return true

	_scene._set_codex_tab(5)
	if not _check(_scene.codex_char_scroll.visible and _scene.codex_char_box.get_child_count() >= 2, "Codex Tab 5 (Character Status) must render hero bar + 3-column layout"):
		return true
	var grid_node: Node = _scene.codex_char_box.find_child("SlotsGrid", true, false)
	if not _check(grid_node != null and grid_node.get_child_count() == 4, "Character Status normal mode must show 2x2 SlotsGrid (weapon, relic, costume, passive)"):
		return true

	# Open Quick Drawer for weapon slot and verify real-time Stat Preview (▲ green / ▼ red)
	_scene.char_status_drawer_slot = "weapon"
	_scene._rebuild_character_status()
	var drawer_list: Node = _scene.codex_char_box.find_child("DrawerItemList", true, false)
	if not _check(drawer_list != null and drawer_list.get_child_count() == 5, "Weapon Quick Drawer must list all 5 weapons"):
		return true
	var d_labels: Dictionary = _scene.codex_char_box.get_meta("delta_labels", {})
	var CharacterStatusUI = load("res://scripts/character_status_ui.gd")
	CharacterStatusUI.update_stat_preview(d_labels, _scene.save_data, "bai_yueling", "weapon", "heaven_halberd")
	var atk_dl: Label = d_labels.get("atk")
	if not _check(atk_dl != null and atk_dl.visible and atk_dl.text.begins_with("▲ +"), "Stat Preview for stronger weapon must show green ▲ +XX (got %s)" % (atk_dl.text if atk_dl else "null")):
		return true
	CharacterStatusUI.update_stat_preview(d_labels, _scene.save_data, "bai_yueling", "weapon", "jade_sword")
	if not _check(atk_dl != null and atk_dl.visible and atk_dl.text.begins_with("▼ -"), "Stat Preview for unequipping current weapon must show red ▼ -XX (got %s)" % (atk_dl.text if atk_dl else "null")):
		return true

	# 7. Battle Summary on end_overlay & Fake 2.5D verification
	_scene.combat.add_combo(350.0, true)
	_scene.combat.perfect_dodge_count = 3
	_scene.combat.reaction_count = 4
	_scene._populate_battle_summary(true)
	if not _check(_scene.end_summary_box.get_child_count() >= 3, "Battle summary must populate meta stats, damage header, and hero rows"):
		return true
	var summary_meta: Label = _scene.end_summary_box.get_child(0) as Label
	if not _check(summary_meta.text.contains("SSS") and summary_meta.text.contains("3") and summary_meta.text.contains("4"), "Battle summary must reflect CombatSystem peak_rank_idx, perfect_dodge_count, and reaction_count"):
		return true

	if not _check(_scene.parallax_bg != null and _scene.parallax_mist_layer != null, "Fake 2.5D ParallaxBackground and mist layer must exist"):
		return true
	if not _check(_scene.player_shadow != null, "Fake 2.5D player_shadow reference must be initialized"):
		return true
	_scene.dash_timer = 0.15
	_scene._update_fake_z_height(0.1)
	if not _check(_scene.player_z_height > 1.0 and _scene.player_sprite.offset.y < _scene.HERO_OFFSET.y and _scene.player_shadow.scale.x < 1.0, "Fake 2.5D Z-height must lift player_sprite and shrink player_shadow during Dash"):
		return true
	_scene.dash_timer = 0.0
	if _scene.enemies.size() > 0:
		var test_e: CharacterBody2D = _scene.enemies[0]
		test_e.set_meta("kb", Vector2(280.0, 0.0))
		_scene._process_enemies(0.05)
		if not _check(float(test_e.get_meta("z_height", 0.0)) > 0.5, "Fake 2.5D enemy knockback must lift enemy z_height above shadow"):
			return true

	Engine.time_scale = 1.0
	_scene.queue_free()
	print("P1_PROGRESSION_E2E_PASSED: 12 Boons, Gear +1..+5, CharacterStatusUI + Stat Preview, Battle Summary, Game Speed 1.5x, and Fake 2.5D verified!")
	quit(0)
	return true
