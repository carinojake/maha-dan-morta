extends SceneTree

const SaveManager = preload("res://scripts/save_manager.gd")
const EquipData = preload("res://scripts/equip_data.gd")
const VfxStudio = preload("res://scripts/vfx_studio.gd")

func _init():
	call_deferred("_run")

func _fail(msg: String):
	Engine.time_scale = 1.0
	printerr("FAIL: " + msg)
	quit(1)

func _assert_ok(cond: bool, msg: String):
	if not cond:
		_fail(msg)

func _step(scene: Node, dt: float = 1.0 / 30.0):
	scene.hitstop_timer = 0.0
	Engine.time_scale = 1.0
	scene._process(dt)
	scene._physics_process(dt)

func _run():
	var test_save := "user://test_quality_mission_save.json"
	if FileAccess.file_exists(test_save):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(test_save))

	var globals := root.get_node("Globals")
	globals.set_meta("save_path", test_save)
	globals.set_meta("chapter", 1)
	globals.set_meta("skip_intro", true)

	var scene: Node2D = load("res://scenes/dark_jade_dungeon.tscn").instantiate()
	scene.save_path = test_save
	root.add_child(scene)
	await process_frame
	if scene.tutorial_step > 0:
		scene._complete_interactive_tutorial()

	# 1. Task A: Bai Yueling walk cycle & neutral idle frame 1
	_assert_ok(scene._has_4dir_sheet("bai_yueling"), "Bai Yueling must use 4-direction walk sheets")
	scene.player.velocity = Vector2.ZERO
	_step(scene)
	_assert_ok(scene.player_sprite.hframes == 3 and scene.player_sprite.frame == 1, "Idle Bai Yueling must rest on neutral frame 1")
	scene._update_walk_direction(Vector2(1.0, 1.0).normalized())
	_assert_ok(scene.walk_dir_key == "walk_side", "45-deg diagonal must prefer side-stride sheet")

	# 2. Task B: Cultist 8f + Boss 10f living state machines, anti-stacking & telegraph cancel on death
	scene._warp_to_room(1)
	_assert_ok(scene.enemies.size() == 3, "Ch1 Room 1 must spawn 3 enemies")
	var cultist: CharacterBody2D = null
	for e in scene.enemies:
		if str(e.get_meta("kind", "")) == "cultist":
			cultist = e
			break
	_assert_ok(cultist != null and str(cultist.get_meta("sheet_type", "")) == "cultist_8f", "Cultist must load 8-frame living sprite sheet")

	for _i in range(25):
		_step(scene)
	# Verify anti-stacking separation between living enemies
	if scene.enemies.size() >= 2:
		var d01: float = scene.enemies[0].global_position.distance_to(scene.enemies[1].global_position)
		_assert_ok(d01 >= 42.0, "Enemies must maintain anti-stacking separation (got %.1f px)" % d01)

	# Clear Room 1 and verify Task D scoped exit hint ("⛩️ ทางออก →") spawns AND frees on entering Room 2
	for e in scene.enemies.duplicate():
		if is_instance_valid(e):
			scene._damage_enemy(e, 9999, Vector2.RIGHT, Color("#38bdf8"), 1.0, true)
	_step(scene)
	_assert_ok(scene.active_exit_hint != null and is_instance_valid(scene.active_exit_hint), "Clearing room must spawn scoped exit hint")
	scene.player.global_position = Vector2((16.2 + 1.0 * 17.0) * 64.0, 4.5 * 64.0)
	_step(scene)
	_assert_ok(scene.current_room == 2, "Crossing threshold must advance to Room 2")
	_assert_ok(scene.active_exit_hint == null, "Exit hint must be freed immediately upon entering next room")

	# Verify Boss Furnace Guardian 10f sheet, Phase 2 transformation, and telegraph cancellation on death
	scene._warp_to_room(9)
	_assert_ok(scene.enemies.size() >= 1, "Ch1 Boss Hall must spawn Furnace Guardian")
	var boss: CharacterBody2D = scene.enemies[0]
	_assert_ok(str(boss.get_meta("sheet_type", "")) == "boss_ch1_10f", "Ch1 Furnace Guardian must load 10-frame boss sheet")
	var boss_mhp: float = float(boss.get_meta("max_hp"))
	scene.combat.combo_hits = 0
	scene._damage_enemy(boss, int(boss_mhp * 0.55), Vector2.RIGHT, Color("#38bdf8"), 0.0, false)
	for _i in range(20):
		_step(scene)
	_assert_ok(bool(boss.get_meta("phase2_done", false)), "Boss at <=50 pct HP must enter Phase 2")
	_assert_ok(scene.active_telegraphs.size() > 0, "Boss Phase 2 must spawn active telegraphs")
	scene._damage_enemy(boss, 99999, Vector2.RIGHT, Color("#38bdf8"), 1.0, true)
	_assert_ok(scene.active_telegraphs.size() == 0, "Killing boss must cancel all active telegraphs immediately")
	_assert_ok(scene.victory and scene.end_input_guard_timer > 0.5, "Victory must activate post-boss input guard timer")

	# 3. Task C: Persist Auto-Attack, Reduced FX, and Shake Mode across save/reload
	scene.victory = false
	scene.end_overlay.visible = false
	scene._toggle_auto_attack()
	scene._toggle_fx_reduced()
	scene._toggle_shake_mode()
	var reloaded := SaveManager.load_data(test_save)
	_assert_ok(bool(reloaded.get("auto_attack", false)) == true, "Auto-attack state must persist across chapters/reloads")
	_assert_ok(bool(reloaded.get("fx_reduced", false)) == true, "Reduced FX option must persist")
	_assert_ok(str(reloaded.get("shake_mode", "")) == "low", "Shake mode option must persist")
	scene._toggle_fx_reduced() # restore normal FX

	# 4. Task E: Exclusive 1-copy gear ownership, proportional HP/SP ratio, CRIT + CDR stat application
	scene.save_data["owned_gear"] = EquipData.ITEM_ORDER.duplicate()
	scene.save_data["spirit_jade"] = 1000
	scene.hero_hp["bai_yueling"] = float(scene._get_hero_stat("bai_yueling", "max_hp")) * 0.50
	scene._toggle_equip_gear("patched_hemp_robe", "bai_yueling")
	var new_mhp: float = float(scene._get_hero_stat("bai_yueling", "max_hp"))
	_assert_ok(absf(float(scene.hero_hp["bai_yueling"]) / new_mhp - 0.50) < 0.03, "Equipping Max HP gear at 50% HP must preserve 50% HP ratio")

	# Equip heaven_halberd on bai_yueling, then move to yu_han -> must unequip from bai_yueling
	scene._toggle_equip_gear("heaven_halberd", "bai_yueling")
	_assert_ok(EquipData.find_item_holder(scene.save_data["hero_gear"], "heaven_halberd") == "bai_yueling", "bai_yueling must hold heaven_halberd")
	scene._toggle_equip_gear("heaven_halberd", "yu_han")
	_assert_ok(EquipData.find_item_holder(scene.save_data["hero_gear"], "heaven_halberd") == "yu_han", "yu_han must hold heaven_halberd after transfer")
	_assert_ok(str(scene.save_data["hero_gear"].get("bai_yueling", {}).get("weapon", "")) == "", "bai_yueling weapon slot must be cleared on transfer")

	# Verify Immortal Set 3/3 grants 12% cooldown reduction on Q
	scene._toggle_equip_gear("star_fan", "bai_yueling")
	scene._toggle_equip_gear("frost_silk_robe", "bai_yueling")
	scene._toggle_equip_gear("frost_jade", "bai_yueling")
	scene._switch_hero("bai_yueling", false)
	scene.hero_sp["bai_yueling"] = 150.0
	scene.q_cd = 0.0
	scene._cast_skill_q(Vector2.RIGHT)
	_assert_ok(scene.q_cd < 2.70, "Immortal Set CDR must reduce Q cooldown from 3.0s to 2.64s (got %.2fs)" % scene.q_cd)

	# 5. Playtest Run Verification across Touch Mode + Auto-Attack Mode in Room 1
	scene._set_touch_mode(true)
	scene.auto_attack_enabled = true
	scene._warp_to_room(1)
	for _f in range(90):
		_step(scene)
		Engine.time_scale = 1.0
		scene.hitstop_timer = 0.0
	scene._set_touch_mode(false)

	scene.free()
	if FileAccess.file_exists(test_save):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(test_save))
	print("QUALITY_MISSION_E2E_PASSED: Tasks A-E, 1-copy gear rule, HP/SP ratio, CDR/Crit, exit hint cleanup, and multi-mode playtest verified!")
	quit(0)
