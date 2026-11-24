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

	# 1b. Verify 4-dir walk (walk_down, walk_up, walk_side 3f) + attack_4f + skill_4f across ALL 7 heroes
	for hid in HeroData.HERO_ORDER:
		assert(game._has_4dir_sheet(hid), "_has_4dir_sheet must be true for %s" % hid)
		var hdict: Dictionary = game.hero_textures[hid]["default"]
		for k in ["walk_down", "walk_up", "walk_side"]:
			assert(hdict.has(k) and hdict[k] != null, "Missing %s/default/%s" % [hid, k])
			assert(hdict[k].get_width() == 1200 and hdict[k].get_height() == 320, "%s/%s must be 1200x320" % [hid, k])
		for k in ["attack_4f", "skill_4f"]:
			assert(hdict.has(k) and hdict[k] != null, "Missing %s/default/%s" % [hid, k])
			assert(hdict[k].get_width() == 1600 and hdict[k].get_height() == 320, "%s/%s must be 1600x320" % [hid, k])

	for mode in ["default", "alt", "alt_snow"]:
		var bdict: Dictionary = game.hero_textures["bai_yueling"][mode]
		for k in ["walk_down", "walk_up", "walk_side", "attack_4f", "skill_4f"]:
			assert(bdict.has(k) and bdict[k] != null, "Missing bai_yueling/%s/%s" % [mode, k])
		assert(bdict["walk_down"].get_width() == 1200 and bdict["walk_down"].get_height() == 320, "walk_down must be 1200x320 (3x 400x320)")
		assert(bdict["attack_4f"].get_width() == 1600 and bdict["attack_4f"].get_height() == 320, "attack_4f must be 1600x320 (4x 400x320)")
		assert(bdict["skill_4f"].get_width() == 1600 and bdict["skill_4f"].get_height() == 320, "skill_4f must be 1600x320 (4x 400x320)")

	game._switch_hero("bai_yueling", false)
	game._update_walk_direction(Vector2(0.0, 1.0))
	assert(game.walk_dir_key == "walk_down", "Moving down must set walk_dir_key to walk_down")
	game._update_walk_direction(Vector2(0.0, -1.0))
	assert(game.walk_dir_key == "walk_up", "Moving up must set walk_dir_key to walk_up")
	game._update_walk_direction(Vector2(-1.0, 0.0))
	assert(game.walk_dir_key == "walk_side" and game.player_sprite.flip_h, "Moving left must set walk_side + flip_h")
	game._perform_basic_attack(Vector2.RIGHT)
	assert(game.player_sprite.texture == game._get_hero_tex("bai_yueling", "attack_4f") and game.player_sprite.hframes == 4, "Basic attack must play attack_4f (4 frames)")
	game._cast_skill_q(Vector2.RIGHT)
	assert(game.player_sprite.texture == game._get_hero_tex("bai_yueling", "skill_4f") and game.player_sprite.hframes == 4, "Skill Q must play skill_4f (4 frames)")
	game.attack_timer = 0.0
	game.pose_override_timer = 0.0

	# 2. Verify yu_han extended spear reach (> sword 145 & chain 165)
	assert(float(HeroData.HEROES["yu_han"]["range"]) >= 180.0 and float(HeroData.HEROES["yu_han"]["range"]) > float(HeroData.HEROES["bai_yueling"]["range"]), "yu_han extended spear reach mismatch")

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
