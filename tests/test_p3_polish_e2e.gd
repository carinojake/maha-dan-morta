extends SceneTree

const SaveManager = preload("res://scripts/save_manager.gd")
const EquipData = preload("res://scripts/equip_data.gd")

var _tick: int = 0
var _scene: Node2D
var _test_save := "user://test_p3_polish_save.json"


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
	if not _check(EquipData.ITEM_ORDER.size() == 15, "EquipData must have 15 items (5 weapons, 5 armors, 5 relics)"):
		return
	if not _check(fresh.get("owned_gear", []).size() == 3, "Fresh save must start with 3 starter gear items"):
		return
	if not _check(bool(fresh.get("tutorial_completed", true)) == false, "Fresh save tutorial_completed must default to false"):
		return

	# Verify +5 scaling (2.0x) and Human Realm 3-piece Set Bonus
	var hg := {"bai_yueling": {"weapon": "jade_sword", "armor": "patched_hemp_robe", "relic": "spirit_orb"}}
	var gl := {"jade_sword": 5}
	var bonuses := EquipData.get_bonuses_for_hero(hg, "bai_yueling", gl)
	if not _check(int(bonuses["atk"]) == 16, "jade_sword +5 must double ATK from 8 to 16"):
		return
	if not _check(str(bonuses["set_realm"]) == "มนุษย์", "3 Human-realm pieces must activate Human Realm Set Bonus"):
		return
	if not _check(is_equal_approx(float(bonuses["max_hp_pct"]), 0.15), "Human Realm Set Bonus must grant +15% max_hp_pct"):
		return

	# Verify MDM1 export/import preserves P3 fields
	fresh["gear_levels"] = {"jade_sword": 3}
	fresh["touch_mirror"] = true
	fresh["tutorial_completed"] = true
	var code := SaveManager.export_save_code(fresh)
	var imp := SaveManager.import_save_code(code)
	if not _check(bool(imp.get("ok", false)), "MDM1 import must succeed"):
		return
	var imp_data: Dictionary = imp["data"]
	if not _check(int(imp_data.get("gear_levels", {}).get("jade_sword", 0)) == 3, "MDM1 must preserve gear_levels"):
		return
	if not _check(bool(imp_data.get("touch_mirror", false)) == true, "MDM1 must preserve touch_mirror"):
		return

	var packed: PackedScene = load("res://scenes/dark_jade_dungeon.tscn")
	_scene = packed.instantiate()
	_scene.save_path = _test_save
	get_root().add_child(_scene)


func _process(_delta: float) -> bool:
	_tick += 1
	if _tick == 3:
		_scene.save_data["spirit_jade"] = 500
		_scene.save_data["tutorial_completed"] = false
		_scene._enhance_gear_item("jade_sword")
		if not _check(int(_scene.save_data.get("gear_levels", {}).get("jade_sword", 0)) == 1, "Enhance must raise jade_sword to +1"):
			return true

		# Test Tab 3 (Armory filters), Tab 4 (Achievements), and Tab 5 (CharacterStatusUI + Quick Drawer + Stat Preview)
		_scene._set_codex_tab(3)
		_scene._set_gear_filter("armor")
		_scene._set_codex_tab(4)
		if not _check(_scene.codex_ach_scroll.visible and _scene.codex_ach_box.get_child_count() > 0, "Tab 4 must render achievements list"):
			return true
		_scene._set_codex_tab(5)
		if not _check(_scene.codex_char_scroll.visible and _scene.codex_char_box.get_child_count() > 0, "Tab 5 must render CharacterStatusUI"):
			return true
		_scene.char_status_drawer_slot = "weapon"
		_scene.char_status_preview_id = "heaven_halberd"
		_scene._rebuild_character_status()
		if not _check(_scene.codex_char_box.get_child_count() >= 2, "Quick Drawer + Stat Preview must render cleanly"):
			return true

		# Test game_speed toggle (1.0x <-> 1.5x) & sanitize
		var spd_test := SaveManager.sanitize_data({"game_speed": 1.4})
		if not _check(is_equal_approx(float(spd_test["game_speed"]), 1.5), "SaveManager must sanitize game_speed >= 1.25 to 1.5"):
			return true
		_scene._toggle_game_speed()
		if not _check(is_equal_approx(_scene.game_speed_mult, 1.5), "_toggle_game_speed must toggle to 1.5x"):
			return true
		_scene._toggle_game_speed()
		if not _check(is_equal_approx(_scene.game_speed_mult, 1.0), "_toggle_game_speed must toggle back to 1.0x"):
			return true

		# Test Achievement auto-reward + Toast
		var jade_before: int = int(_scene.save_data["spirit_jade"])
		_scene._record_achievement("dodge_5", 5)
		if not _check(int(_scene.save_data["spirit_jade"]) == jade_before + 30, "Unlocking dodge_5 must auto-grant +30 Spirit Jade"):
			return true
		if not _check(_scene.toast_panel.visible, "Unlocking achievement must show toast_panel"):
			return true

		# Test Touch Mirror toggle
		_scene._toggle_touch_mirror()
		if not _check(bool(_scene.save_data.get("touch_mirror", false)) == true, "toggle_touch_mirror must persist true"):
			return true

		# Test Interactive Tutorial 3-step flow
		_scene._start_interactive_tutorial()
		if not _check(_scene.tutorial_step == 1 and _scene.tutorial_panel.visible, "Tutorial must start at step 1"):
			return true
		_scene._advance_tutorial(2)
		_scene._advance_tutorial(3)
		_scene._complete_interactive_tutorial()
		if not _check(_scene.tutorial_step == 0 and bool(_scene.save_data.get("tutorial_completed", false)), "Completing tutorial must persist tutorial_completed"):
			return true

		# Test Battle Result / Damage Meter + Personal Best
		var active_id: String = _scene.active_hero_id
		_scene.run_hero_damage[active_id] = 420
		_scene.run_elapsed_time = 18.5
		_scene.run_max_combo_hits = 22
		_scene.run_max_combo_rank = "S"
		_scene._trigger_victory()
		if not _check(_scene.end_overlay.visible and _scene.end_summary_box.get_child_count() >= 3, "Victory must populate Battle Result / Damage Meter"):
			return true
		var rec: Dictionary = _scene.save_data.get("chapter_records", {}).get("1", {})
		if not _check(int(rec.get("best_damage", 0)) == 420, "Victory must save chapter Personal Best damage"):
			return true

		if FileAccess.file_exists(_test_save):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(_test_save))
		print("P3_POLISH_E2E_PASSED: 15 Gear + Armor + 4-Realm Set Bonus + +1..+5 Enhance + Battle Result + Achievements + Tutorial + Touch Mirror verified!")
		quit(0)
		return true
	if _tick > 60:
		_fail("Timeout")
		return true
	return false
