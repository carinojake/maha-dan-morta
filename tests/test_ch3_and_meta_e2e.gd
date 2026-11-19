extends SceneTree

const SaveManager = preload("res://scripts/save_manager.gd")
const TEST_SAVE := "user://test_ch3_meta_save.json"


var _tick: int = 0
var scene: Node2D


func _initialize():
	if FileAccess.file_exists(TEST_SAVE):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_SAVE))

	var globals := root.get_node("Globals")
	globals.set_meta("chapter", 3)
	globals.set_meta("save_path", TEST_SAVE)

	scene = load("res://scenes/dark_jade_dungeon.tscn").instantiate()
	root.add_child(scene)


func _process(_delta: float) -> bool:
	_tick += 1
	if _tick < 2:
		return false

	# 1. Verify Chapter 3 10-room environment + Sawblades + Puppets
	if scene._total_rooms() != 10:
		push_error("Expected 10 rooms, got %d (chapter=%d)" % [scene._total_rooms(), scene.chapter])
		quit(1)
		return true
	assert(scene.sawblades.size() >= 14, "Chapter 3 must spawn sawblade traps in combat rooms")
	assert(scene.room_gates.size() == 9, "Chapter 3 must have 9 room gates for 10 rooms")
	assert(scene.enemies.size() == 3, "Room 0 should spawn 3 enemies")

	# 2. Verify Tag-Team Synergy (E -> Switch-In -> Qi Resonance)
	scene._cast_skill_e()
	assert(scene.last_skill_er_timer > 0.0, "E must arm Switch-In synergy window")
	scene._switch_hero("ye_shangye", true)
	assert(scene.synergy_cd > 0.0, "Switch-In within 2.5s must fire Switch-In skill")

	# 3. Verify Room 5 (idx 4) Bronze Sentinel Shield & Skill Break
	for e in scene.enemies.duplicate():
		if is_instance_valid(e):
			e.queue_free()
	scene.enemies.clear()
	scene.player.global_position = Vector2((6.5 + 4.0 * 14.0) * 64.0, 4.5 * 64.0)
	scene._spawn_room_wave(4)
	var sentinel: CharacterBody2D = scene.enemies[0]
	assert(sentinel.get_meta("kind") == "bronze_sentinel", "Room 5 must spawn bronze_sentinel")
	var hp_before: float = sentinel.get_meta("hp")
	var sh_before: float = sentinel.get_meta("shield")
	assert(sh_before > 0.0, "Bronze Sentinel must start with shield")
	scene._damage_enemy(sentinel, 30, Vector2.RIGHT, Color.WHITE, 0.0, false)
	assert(sentinel.get_meta("hp") == hp_before, "Basic attack must NOT bypass Bronze Sentinel shield")
	scene._damage_enemy(sentinel, 200, Vector2.RIGHT, Color.CYAN, 0.0, true)
	assert(float(sentinel.get_meta("shield")) < sh_before, "Skill attack must damage Bronze Sentinel shield")

	# 4. Verify Room 10 (idx 9) Boss Xuanji Phase 1 -> Phase 2 (<50% HP)
	for e in scene.enemies.duplicate():
		if is_instance_valid(e):
			e.queue_free()
	scene.enemies.clear()
	scene.player.global_position = Vector2((6.5 + 9.0 * 14.0) * 64.0, 4.5 * 64.0)
	scene._spawn_room_wave(9)
	var boss: CharacterBody2D = scene.enemies[0]
	assert(scene.MONSTER_DEFS[boss.get_meta("kind")]["is_boss"], "Room 10 must spawn a boss")
	assert(scene.enemies.size() == 3, "Room 10 must spawn boss_ch3 + 2 turrets")
	boss.set_meta("hp", float(boss.get_meta("max_hp")) * 0.45)
	scene._process_enemies(0.016)
	assert(bool(boss.get_meta("phase2_done", false)), "Boss Ch3 must transition to Phase 2 under 50% HP")
	assert(scene.orbit_blades.size() == 3, "Phase 2 must spawn 3 orbiting sawblades")

	# 5. Verify Meta-Progression Save/Load & Difficulty Toggle
	scene._toggle_difficulty()
	assert(scene.save_data["difficulty"] == "hard", "Difficulty toggle must switch to hard")
	scene._award_spirit_jade(40) # x1.5 on hard = +60
	scene._buy_core_upgrade("hp_lv")
	var reloaded := SaveManager.load_data(TEST_SAVE)
	assert(int(reloaded["core_upgrades"]["hp_lv"]) == 1, "Core upgrade must persist to save JSON")
	assert(int(reloaded["spirit_jade"]) > 0, "Spirit Jade must persist to save JSON")

	if FileAccess.file_exists(TEST_SAVE):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_SAVE))
	var globals := root.get_node("Globals")
	globals.set_meta("chapter", 1)
	globals.remove_meta("save_path")

	print("CH3_10ROOMS_SYNERGY_META_E2E_PASSED: All 5 systems verified!")
	quit(0)
	return true
