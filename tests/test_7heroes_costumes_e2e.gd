extends SceneTree

func _init():
	var test_save := "user://test_7heroes_save.json"
	if FileAccess.file_exists(test_save):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(test_save))
	await process_frame
	var globals = root.get_node("Globals")
	globals.set_meta("save_path", test_save)
	globals.set_meta("chapter", 1)

	var scene: PackedScene = load("res://scenes/dark_jade_dungeon.tscn")
	var game = scene.instantiate()
	root.add_child(game)
	await process_frame
	await process_frame

	var HeroData = load("res://scripts/hero_data.gd")
	var SaveManager = load("res://scripts/save_manager.gd")

	# 1. Verify all 7 heroes and both costumes have valid textures
	for hid in HeroData.HERO_ORDER:
		for mode in ["default", "alt"]:
			var tex_dict: Dictionary = game.hero_textures[hid][mode]
			for k in ["stride_0", "strike_1", "skill_1", "portrait"]:
				assert(tex_dict.has(k) and tex_dict[k] != null, "Missing %s/%s/%s" % [hid, mode, k])

	# 2. Verify yu_han extended reach
	assert(float(HeroData.HEROES["yu_han"]["range"]) == 215.0, "yu_han range mismatch")

	# 3. Verify party swap & costume toggle + save persistence
	game._toggle_party_member("zhao_yan")
	game._toggle_party_member("hei_shan")
	game._toggle_hero_costume("zhao_yan")
	assert(game.active_party.has("zhao_yan"), "zhao_yan should be in party")
	assert(game.active_party.has("hei_shan"), "hei_shan should be in party")
	var reloaded: Dictionary = SaveManager.load_data(test_save)
	assert(reloaded["costumes"]["zhao_yan"] == "alt", "zhao_yan costume should persist as alt")

	# 4. Verify zhao_yan self-heal on E hit & hei_shan reserve-only heal (no revive)
	game._switch_hero("zhao_yan", false)
	game.hero_hp["zhao_yan"] = 100.0
	game.hero_sp["zhao_yan"] = 100.0
	game.e_cd = 0.0
	if game.enemies.size() > 0:
		game.enemies[0].global_position = game.player.global_position + Vector2(60, 0)
	game._cast_skill_e()
	assert(game.hero_hp["zhao_yan"] > 100.0, "zhao_yan E should heal self on hit")

	# Set first teammate HP=0 (fallen), second teammate injured
	var fallen_id: String = ""
	var injured_id: String = ""
	for hid in game.active_party:
		if hid != "hei_shan":
			if fallen_id == "":
				fallen_id = hid
			else:
				injured_id = hid
	if not game.active_party.has("hei_shan"):
		game._toggle_party_member("hei_shan")
	game._switch_hero("hei_shan", false)
	game.hero_hp[fallen_id] = 0.0
	game.hero_hp[injured_id] = 50.0
	game.hero_sp["hei_shan"] = 100.0
	game.e_cd = 0.0
	if game.enemies.size() > 0:
		game.enemies[0].global_position = game.player.global_position + Vector2(60, 0)
	game._cast_skill_e()
	assert(game.hero_hp[fallen_id] == 0.0, "hei_shan must NOT revive fallen ally")
	assert(game.hero_hp[injured_id] == 66.0, "hei_shan E should heal living reserve ally by 16")

	if FileAccess.file_exists(test_save):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(test_save))

	print("SEVEN_HEROES_AND_COSTUMES_E2E_PASSED: All 7 heroes, 2 costumes each, party swap, and heal mechanics verified!")
	quit(0)
