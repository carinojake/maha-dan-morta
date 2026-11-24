extends SceneTree

const SaveManager = preload("res://scripts/save_manager.gd")
const HeroData = preload("res://scripts/hero_data.gd")
const EquipData = preload("res://scripts/equip_data.gd")

func _init():
	call_deferred("_run")

func _capture_frame(dir_path: String, idx: int):
	await RenderingServer.frame_post_draw
	var img := root.get_viewport().get_texture().get_image()
	img.save_png("%s/frame_%04d.png" % [dir_path, idx])

func _step_and_record(scene: Node, dir_path: String, start_idx: int, count: int, action_cb: Callable = Callable()) -> int:
	var idx := start_idx
	var dt := 1.0 / 30.0
	for i in range(count):
		if action_cb.is_valid():
			action_cb.call(i, dt)
		scene._process(dt)
		scene._physics_process(dt)
		Engine.time_scale = 1.0
		scene.hitstop_timer = 0.0
		await process_frame
		await _capture_frame(dir_path, idx)
		idx += 1
	return idx

func _reset_dir(p: String):
	if DirAccess.dir_exists_absolute(p):
		var d := DirAccess.open(p)
		if d:
			d.list_dir_begin()
			var fn := d.get_next()
			while fn != "":
				if not d.current_is_dir():
					d.remove(fn)
				fn = d.get_next()
	else:
		DirAccess.make_dir_recursive_absolute(p)

func _run():
	var base_scratch := "/Users/jake/.gemini/antigravity/brain/2c2a760f-992e-4227-ab58-78b849405519/scratch"
	var dir_enemy := base_scratch + "/clip_enemy_frames"
	var dir_boss := base_scratch + "/clip_boss_frames"
	var dir_arena := base_scratch + "/clip_arena_frames"
	_reset_dir(dir_enemy)
	_reset_dir(dir_boss)
	_reset_dir(dir_arena)

	var temp_save := "user://qa_clips_capture_save.json"
	if FileAccess.file_exists(temp_save):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(temp_save))

	var globals := root.get_node("Globals")
	globals.set_meta("save_path", temp_save)
	globals.set_meta("chapter", 1)
	globals.set_meta("skip_intro", true)

	var scene: Node2D = load("res://scenes/dark_jade_dungeon.tscn").instantiate()
	scene.save_path = temp_save
	root.add_child(scene)
	await process_frame
	if scene.tutorial_step > 0:
		scene._complete_interactive_tutorial()
	scene.save_data["cutin_mode"] = "skip"
	if scene.toast_panel:
		scene.toast_panel.visible = false

	# --- CLIP 1: Cultist States (Idle -> Move -> Windup -> Attack -> Recovery -> Hurt -> Death) + Anti-Stacking ---
	var f1 := 0
	scene.player.global_position = Vector2(5.2 * 64.0, 4.5 * 64.0)
	scene.camera.reset_smoothing()
	if scene.banner_panel:
		scene.banner_panel.visible = false
	# Let cultist approach, windup, slash, enter recovery, then counter-attack to show Hurt + Death collapse
	f1 = await _step_and_record(scene, dir_enemy, f1, 95, func(i: int, _dt: float):
		scene.hero_hp["bai_yueling"] = 190.0
		if i == 18:
			scene.player.velocity = Vector2(0, -140)
			scene.player.move_and_slide()
		elif i == 55 and scene.enemies.size() > 0:
			scene._perform_basic_attack(scene._get_auto_aim_dir())
		elif i == 70 and scene.enemies.size() > 0:
			scene._cast_skill_q(scene._get_auto_aim_dir())
		elif i == 80:
			for e in scene.enemies.duplicate():
				if is_instance_valid(e):
					scene._damage_enemy(e, 999, Vector2.RIGHT, Color("#38bdf8"), 1.0, true)
	)
	# Warp to Room 1 to show 3 enemies spreading into compass slots (Anti-Stacking)
	scene._warp_to_room(1)
	scene.player.global_position = Vector2((6.6 + 17.0) * 64.0, 4.5 * 64.0)
	scene.camera.reset_smoothing()
	f1 = await _step_and_record(scene, dir_enemy, f1, 85, func(i: int, _dt: float):
		scene.hero_hp["bai_yueling"] = 190.0
		if i == 45:
			scene._cast_skill_e()
	)
	print("Captured enemy clip frames: ", f1)

	# --- CLIP 2: Furnace Guardian Boss Arena (3 Patterns + Phase 2 + Overheat Counter Window + Death Cancel) ---
	var f2 := 0
	scene._warp_to_room(9)
	scene.player.global_position = Vector2((6.8 + 9.0 * 17.0) * 64.0, 4.5 * 64.0)
	scene.camera.reset_smoothing()
	f2 = await _step_and_record(scene, dir_boss, f2, 260, func(i: int, _dt: float):
		scene.hero_hp["bai_yueling"] = 190.0
		scene.hero_sp["bai_yueling"] = 120.0
		if scene.enemies.size() > 0 and is_instance_valid(scene.enemies[0]):
			var boss: CharacterBody2D = scene.enemies[0]
			var ppos: Vector2 = scene.player.global_position
			# Gently strafe around telegraphs so patterns read clearly
			var strafe := Vector2(cos(float(i) * 0.08), sin(float(i) * 0.11)) * 120.0
			scene.player.velocity = strafe
			scene.facing_dir = (boss.global_position - ppos).normalized()
			scene.player.move_and_slide()
			if i == 115:
				# Push Boss into Phase 2 (<= 50% HP)
				var mhp := float(boss.get_meta("max_hp"))
				scene._damage_enemy(boss, int(mhp * 0.54), Vector2.RIGHT, Color("#38bdf8"), 0.0, true)
			elif i == 195:
				# Punish during Overheat / Phase 2 with Skill E
				scene._cast_skill_e()
			elif i == 235:
				# Finish boss to show Death collapse & instant telegraph cleanup
				scene._damage_enemy(boss, 99999, Vector2.RIGHT, Color("#fde047"), 1.0, true)
	)
	print("Captured boss clip frames: ", f2)

	# --- CLIP 3: Prototype Room ("ป่าไผ่หมอกพิษ") + VFX Hierarchy + Exit Portal Transition + Reduced FX ---
	scene.victory = false
	if scene.end_overlay:
		scene.end_overlay.visible = false
	scene._warp_to_room(0)
	scene._spawn_enemy("hound", Vector2(10.4 * 64.0, 5.6 * 64.0))
	scene.player.global_position = Vector2(6.5 * 64.0, 4.5 * 64.0)
	scene.camera.reset_smoothing()
	var f3 := 0
	f3 = await _step_and_record(scene, dir_arena, f3, 210, func(i: int, _dt: float):
		scene.hero_hp["bai_yueling"] = 190.0
		scene.hero_sp["bai_yueling"] = 120.0
		if i < 28:
			scene.player.velocity = Vector2(180.0, 0.0)
			scene.facing_dir = Vector2.RIGHT
			scene._update_walk_direction(Vector2.RIGHT)
			scene.player.move_and_slide()
		elif i == 32:
			scene._perform_basic_attack(scene._get_auto_aim_dir())
		elif i == 46:
			scene._cast_skill_q(scene._get_auto_aim_dir())
		elif i == 62:
			scene._cast_skill_e()
			for e in scene.enemies.duplicate():
				if is_instance_valid(e):
					scene._damage_enemy(e, 9999, Vector2.RIGHT, Color("#38bdf8"), 1.0, true)
		elif i >= 85 and i < 155:
			# Walk right through Jade Elixir Orb and Spirit Portal into Room 1!
			var target := Vector2(18.5 * 64.0, 4.5 * 64.0)
			var pnow: Vector2 = scene.player.global_position
			var dir: Vector2 = target - pnow
			if dir.length() > 8.0:
				scene.facing_dir = dir.normalized()
				scene._update_walk_direction(scene.facing_dir)
				scene.player.velocity = scene.facing_dir * 310.0
				scene.player.move_and_slide()
		elif i == 165:
			# Demonstrate Reduced FX mode cleanly in Room 1
			scene._toggle_fx_reduced()
			scene._cast_skill_e()
	)
	print("Captured prototype arena & VFX clip frames: ", f3)

	if FileAccess.file_exists(temp_save):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(temp_save))
	scene.free()
	quit(0)
