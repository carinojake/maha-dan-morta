extends SceneTree

const SaveManager = preload("res://scripts/save_manager.gd")
const EquipData = preload("res://scripts/equip_data.gd")
const HeroData = preload("res://scripts/hero_data.gd")

func _init():
	call_deferred("_run")

func _step(scene: Node, dt: float):
	scene._process(dt)
	scene._physics_process(dt)

func _simulate_gauntlet(hid: String, gear_slots: Dictionary, gear_lvs: Dictionary, mode: String, seed_val: int) -> Dictionary:
	seed(seed_val)
	var temp_save := "user://qa_bal_tmp_%s.json" % hid
	if FileAccess.file_exists(temp_save):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(temp_save))

	var globals := root.get_node("Globals")
	globals.set_meta("save_path", temp_save)
	globals.set_meta("chapter", 10 if mode == "Ch10_Boss_Sustained" else 2)
	globals.set_meta("skip_intro", true)

	var scene: Node2D = load("res://scenes/dark_jade_dungeon.tscn").instantiate()
	scene.save_path = temp_save
	root.add_child(scene)
	await process_frame

	scene.save_data["tutorial_completed"] = true
	scene.save_data["cutin_mode"] = "skip"
	scene.save_data["difficulty"] = "hard" if mode == "Ch10_Boss_Sustained" else "normal"
	scene.save_data["owned_gear"] = EquipData.ITEM_ORDER.duplicate()
	scene.save_data["gear_levels"] = gear_lvs.duplicate()
	scene.save_data["hero_gear"] = {hid: gear_slots.duplicate()}
	scene.active_party = [hid]
	scene.active_hero_id = hid
	scene._init_hero_stats()
	scene._switch_hero(hid, false)
	if scene.tutorial_step > 0:
		scene._complete_interactive_tutorial()

	var rooms_to_clear: Array = [9] if mode == "Ch10_Boss_Sustained" else [1, 2, 3, 4]
	var max_hp := float(scene._get_hero_stat(hid, "max_hp"))
	var max_sp := float(scene._get_hero_stat(hid, "max_sp"))
	var atk_stat := float(scene._get_hero_stat(hid, "atk"))
	var crit_stat := float(scene._get_hero_stat(hid, "crit")) * 100.0
	var dr_stat := float(scene._get_hero_stat(hid, "dmg_red")) * 100.0
	scene.hero_sp[hid] = max_sp * 0.35 # Realistic combat entry SP so SP pool & regen matter

	var dmg_taken := 0.0
	var deaths := 0
	var dt := 1.0 / 30.0
	var total_elapsed := 0.0

	for r_idx in rooms_to_clear:
		scene.victory = false
		scene.game_over = false
		scene._warp_to_room(r_idx)
		var prev_hp := float(scene.hero_hp[hid])
		var room_t := 0.0
		var room_cap := 45.0
		while room_t < room_cap and scene.enemies.size() > 0 and not scene.victory:
			room_t += dt
			total_elapsed += dt
			var ppos: Vector2 = scene.player.global_position
			var nearest: CharacterBody2D = scene._get_nearest_enemy(950.0)
			var move_dir := Vector2.ZERO
			var need_dodge := false

			for t in scene.active_telegraphs:
				var tpos: Vector2 = t.get("pos", ppos)
				var trad := float(t.get("radius", 80.0))
				if str(t.get("type", "")) == "eight_dir_storm":
					var cpos: Vector2 = t.get("center", tpos)
					if ppos.distance_to(cpos) > 80.0:
						move_dir = (cpos - ppos).normalized()
						if float(t.get("elapsed", 0.0)) > 0.75:
							need_dodge = true
				elif ppos.distance_to(tpos) < trad + 18.0:
					var away := ppos - tpos
					move_dir = (away.normalized() if away.length() > 1.0 else Vector2.LEFT)
					if float(t.get("elapsed", 0.0)) > float(t.get("duration", 0.8)) * 0.65:
						need_dodge = true

			if nearest != null and move_dir == Vector2.ZERO:
				var to_e := nearest.global_position - ppos
				var dist := to_e.length()
				var want := float(HeroData.HEROES[hid]["range"]) * 0.82
				if float(nearest.get_meta("windup_timer", 0.0)) > 0.0 and float(nearest.get_meta("windup_timer", 0.0)) < 0.14 and dist < 125.0:
					need_dodge = true
				if dist > want:
					move_dir = to_e.normalized()
				elif dist < 56.0:
					move_dir = -to_e.normalized()

			if move_dir.length() > 0.05:
				scene.facing_dir = move_dir
				scene._update_walk_direction(move_dir)
				scene.player.velocity = move_dir * scene._get_hero_stat(hid, "speed")
				scene.player.move_and_slide()

			if need_dodge and scene.dash_cooldown <= 0.0 and scene.dash_timer <= 0.0:
				scene._touch_dash_queued = true

			var aim: Vector2 = scene._get_auto_aim_dir()
			if nearest != null:
				var d_now := nearest.global_position.distance_to(scene.player.global_position)
				var has_refl_shield := float(nearest.get_meta("shield", 0.0)) > 0.0
				if scene.r_cd <= 0.0 and float(scene.hero_sp[hid]) >= float(HeroData.HEROES[hid]["r_cost"]) and d_now <= 230.0:
					scene._cast_skill_r()
					# Resolve delayed ultimate drops deterministically in headless benchmark
					for _u in range(6):
						scene._trigger_ultimate_impact(nearest.global_position, HeroData.HEROES[hid])
						if not is_instance_valid(nearest) or bool(nearest.get_meta("is_dead", false)):
							break
				elif scene.e_cd <= 0.0 and float(scene.hero_sp[hid]) >= float(HeroData.HEROES[hid]["e_cost"]) and d_now <= 205.0:
					scene._cast_skill_e()
				elif not has_refl_shield and scene.q_cd <= 0.0 and float(scene.hero_sp[hid]) >= float(HeroData.HEROES[hid]["q_cost"]) and d_now <= 250.0:
					scene._cast_skill_q(aim)
				elif not has_refl_shield and scene.attack_timer <= 0.0 and scene.pose_override_timer <= 0.0 and d_now <= float(HeroData.HEROES[hid]["range"]) + 10.0:
					scene._perform_basic_attack(aim)

			_step(scene, dt)
			if scene.boon_overlay and scene.boon_overlay.visible:
				scene.boon_overlay.visible = false
			Engine.time_scale = 1.0
			scene.hitstop_timer = 0.0

			var cur_hp := float(scene.hero_hp[hid])
			if cur_hp < prev_hp:
				dmg_taken += (prev_hp - cur_hp)
			if scene.game_over or cur_hp <= 0.0:
				deaths += 1
				scene.game_over = false
				if scene.end_overlay:
					scene.end_overlay.visible = false
				scene.hero_hp[hid] = max_hp
				cur_hp = max_hp
			prev_hp = cur_hp

	var total_dmg := int(scene.run_hero_damage.get(hid, 0))
	var dps := float(total_dmg) / maxf(0.1, total_elapsed)
	scene.free()
	if FileAccess.file_exists(temp_save):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(temp_save))
	return {
		"hero": hid,
		"max_hp": int(round(max_hp)),
		"max_sp": int(round(max_sp)),
		"atk": int(round(atk_stat)),
		"crit": snappedf(crit_stat, 0.1),
		"dmg_red": snappedf(dr_stat, 0.1),
		"clear_time": snappedf(total_elapsed, 0.05),
		"total_dmg": total_dmg,
		"dps": snappedf(dps, 0.1),
		"dmg_taken": int(round(dmg_taken)),
		"deaths": deaths,
	}

func _run():
	var heroes := ["bai_yueling", "hei_shan", "yu_han"]
	var tiers := [
		{
			"id": "T1_unequipped",
			"label": "1. ไม่มีอุปกรณ์ (Unequipped)",
			"levels": {},
			"gear_by_hero": {
				"bai_yueling": {},
				"hei_shan": {},
				"yu_han": {},
			},
		},
		{
			"id": "T2_starter",
			"label": "2. อุปกรณ์เริ่มต้น +0 (Starter Human Set)",
			"levels": {},
			"gear_by_hero": {
				"bai_yueling": {"weapon": "jade_sword", "armor": "patched_hemp_robe", "relic": "spirit_orb"},
				"hei_shan": {"weapon": "jade_sword", "armor": "patched_hemp_robe", "relic": "spirit_orb"},
				"yu_han": {"weapon": "jade_sword", "armor": "patched_hemp_robe", "relic": "spirit_orb"},
			},
		},
		{
			"id": "T3_midgame_plus2",
			"label": "3. อุปกรณ์กลางเกม +2 (Midgame Spirit +2)",
			"levels": {
				"thunder_spear": 2, "blood_blade": 2, "talisman_ward_vestment": 2,
				"obsidian_copper_plate": 2, "frost_jade": 2, "bagua_charm": 2,
			},
			"gear_by_hero": {
				"bai_yueling": {"weapon": "thunder_spear", "armor": "talisman_ward_vestment", "relic": "frost_jade"},
				"hei_shan": {"weapon": "thunder_spear", "armor": "talisman_ward_vestment", "relic": "bagua_charm"},
				"yu_han": {"weapon": "blood_blade", "armor": "obsidian_copper_plate", "relic": "frost_jade"},
			},
		},
		{
			"id": "T4A_role_set_plus5",
			"label": "4A. เซ็ตประจำสาย +5 (Immortal +5 vs Divine +5)",
			"levels": {
				"star_fan": 5, "frost_silk_robe": 5, "frost_jade": 5,
				"heaven_halberd": 5, "golden_dragon_armor": 5, "immortal_pill": 5,
			},
			"gear_by_hero": {
				"bai_yueling": {"weapon": "star_fan", "armor": "frost_silk_robe", "relic": "frost_jade"},
				"hei_shan": {"weapon": "star_fan", "armor": "frost_silk_robe", "relic": "frost_jade"},
				"yu_han": {"weapon": "heaven_halberd", "armor": "golden_dragon_armor", "relic": "immortal_pill"},
			},
		},
		{
			"id": "T4B_divine_set_plus5",
			"label": "4B. เซ็ตแดนเทพสูงสุดเหมือนกัน +5 (Same BiS Divine +5)",
			"levels": {
				"heaven_halberd": 5, "golden_dragon_armor": 5, "immortal_pill": 5,
			},
			"gear_by_hero": {
				"bai_yueling": {"weapon": "heaven_halberd", "armor": "golden_dragon_armor", "relic": "immortal_pill"},
				"hei_shan": {"weapon": "heaven_halberd", "armor": "golden_dragon_armor", "relic": "immortal_pill"},
				"yu_han": {"weapon": "heaven_halberd", "armor": "golden_dragon_armor", "relic": "immortal_pill"},
			},
		},
	]

	var results := []
	for mode in ["Ch2_4Room_Gauntlet", "Ch10_Boss_Sustained"]:
		for tier in tiers:
			for hid in heroes:
				var r := await _simulate_gauntlet(hid, tier["gear_by_hero"][hid], tier["levels"], mode, 1337)
				r["arena"] = mode
				r["tier_id"] = tier["id"]
				r["tier_label"] = tier["label"]
				results.append(r)
				print("%-20s | %-20s | %-12s | HP=%4d SP=%3d ATK=%3d CRIT=%5.1f%% DR=%4.1f%% | Time=%5.2fs | DMG=%5d | DPS=%6.1f | Taken=%4d | Deaths=%d" % [
					mode, tier["id"], hid, r["max_hp"], r["max_sp"], r["atk"], r["crit"], r["dmg_red"],
					r["clear_time"], r["total_dmg"], r["dps"], r["dmg_taken"], r["deaths"]
				])

	var out_json := "/Users/jake/.gemini/antigravity/brain/2c2a760f-992e-4227-ab58-78b849405519/scratch/balance_results_after.json"
	var f := FileAccess.open(out_json, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(results, "\t"))
		f.close()
	quit(0)
