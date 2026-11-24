extends SceneTree

const SaveManager = preload("res://scripts/save_manager.gd")

func _init():
	call_deferred("_run")

func _step_frames(scene: Node, n: int):
	for _i in range(n):
		scene._process(1.0 / 30.0)
		scene._physics_process(1.0 / 30.0)
		await process_frame
	await RenderingServer.frame_post_draw

func _save_shot(path: String):
	await RenderingServer.frame_post_draw
	var img := root.get_viewport().get_texture().get_image()
	img.save_png(path)
	print("Saved screenshot: ", path)

func _run():
	var out_dir := "/Users/jake/Downloads/rocg/maha-dan-morta/docs/quality_improvement/screenshots"
	DirAccess.make_dir_recursive_absolute(out_dir)
	var temp_save := "user://qa_showcase_stills_save.json"
	if FileAccess.file_exists(temp_save):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(temp_save))

	var scene_packed: PackedScene = load("res://scenes/dark_jade_dungeon.tscn")
	var scene: Node2D = scene_packed.instantiate()
	scene.set("save_path", temp_save)
	root.add_child(scene)
	await _step_frames(scene, 6)

	# Hide interactive tutorial banner for clean visual review of Room 0 combat
	if scene.tutorial_step > 0:
		scene._complete_interactive_tutorial()
	if scene.banner_panel:
		scene.banner_panel.visible = false

	# Position player facing Cultist and trigger Cultist windup so slash cone + pose are visible
	scene.player.global_position = Vector2(7.6 * 64.0, 4.5 * 64.0)
	scene.camera.reset_smoothing()
	await _step_frames(scene, 14)
	await _save_shot(out_dir + "/room0_combat_after.png")

	# Optional camera framing comparison (1.18x standard vs 1.26x closer tactical framing)
	var orig_zoom: Vector2 = scene.camera.zoom
	scene.camera.zoom = Vector2(1.26, 1.26)
	await _step_frames(scene, 3)
	await _save_shot(out_dir + "/room0_camera_126x.png")
	scene.camera.zoom = orig_zoom
	await _step_frames(scene, 2)

	# Clear Room 0 to verify Jade Elixir Orb + Exit Archway + "⛩️ ทางออก →"
	for e in scene.enemies.duplicate():
		if is_instance_valid(e):
			scene._damage_enemy(e, 9999, Vector2.RIGHT, Color("#38bdf8"), 1.0, true)
	scene.player.global_position = Vector2(10.8 * 64.0, 4.5 * 64.0)
	scene.camera.reset_smoothing()
	await _step_frames(scene, 20)
	await _save_shot(out_dir + "/room0_cleared_exit_after.png")

	# Walk across threshold into Room 1 and verify active_exit_hint was freed cleanly
	scene.player.global_position = Vector2(16.2 * 64.0, 4.5 * 64.0)
	await _step_frames(scene, 12)
	assert(scene.current_room == 1, "Player must advance to Room 1")
	assert(scene.active_exit_hint == null, "Exit hint from Room 0 must be freed upon entering Room 1")
	scene.player.global_position = Vector2((6.8 + 17.0) * 64.0, 4.5 * 64.0)
	scene.camera.reset_smoothing()
	await _step_frames(scene, 18)
	await _save_shot(out_dir + "/room1_anti_stack_after.png")

	# Warp to Room 9 (Furnace Guardian Boss Hall) and capture Phase 2 + Telegraph
	scene._warp_to_room(9)
	scene.player.global_position = Vector2((6.8 + 9.0 * 17.0) * 64.0, 4.5 * 64.0)
	scene.camera.reset_smoothing()
	if scene.enemies.size() > 0 and is_instance_valid(scene.enemies[0]):
		var boss = scene.enemies[0]
		var mhp := float(boss.get_meta("max_hp"))
		scene._damage_enemy(boss, int(mhp * 0.55), Vector2.RIGHT, Color("#38bdf8"), 0.0, true)
	await _step_frames(scene, 24)
	await _save_shot(out_dir + "/boss_furnace_arena_after.png")

	if FileAccess.file_exists(temp_save):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(temp_save))
	scene.free()
	quit(0)
