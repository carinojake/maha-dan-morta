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
	if not _check(fresh.get("owned_gear", []).size() == 2, "Fresh save must start with 2 starter gear items"):
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
	var base_atk := _scene._get_hero_stat("bai_yueling", "atk")
	var base_hp := _scene._get_hero_stat("bai_yueling", "max_hp")
	var base_sp := _scene._get_hero_stat("bai_yueling", "max_sp")
	var base_spd := _scene._get_hero_stat("bai_yueling", "speed")

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

	Engine.time_scale = 1.0
	_scene.queue_free()
	print("P1_PROGRESSION_E2E_PASSED: 12 Boons, Miniboss/Boss HUD, 10 Gear items, Forging, Boss Drops, and Save Persistence verified!")
	quit(0)
	return true
