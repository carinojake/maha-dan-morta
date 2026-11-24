extends SceneTree

const EquipData = preload("res://scripts/equip_data.gd")

func _init():
	call_deferred("_run")

func _step_frames(scene: Node, n: int):
	for _i in range(n):
		scene._process(1.0 / 30.0)
		await process_frame
	await RenderingServer.frame_post_draw

func _save_shot(path: String):
	await RenderingServer.frame_post_draw
	var img := root.get_viewport().get_texture().get_image()
	img.save_png(path)
	print("Saved UI screenshot: ", path)

func _run():
	var out_dir := "/Users/jake/Downloads/rocg/maha-dan-morta/docs/quality_improvement/screenshots"
	var temp_save := "user://qa_equip_ui_shot.json"
	if FileAccess.file_exists(temp_save):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(temp_save))

	var scene: Node2D = load("res://scenes/dark_jade_dungeon.tscn").instantiate()
	scene.save_path = temp_save
	root.add_child(scene)
	await _step_frames(scene, 4)

	if scene.tutorial_step > 0:
		scene._complete_interactive_tutorial()
	scene.save_data["spirit_jade"] = 320
	scene.save_data["owned_gear"] = ["jade_sword", "patched_hemp_robe", "spirit_orb", "star_fan", "frost_silk_robe", "frost_jade", "heaven_halberd"]
	scene.save_data["gear_levels"] = {"jade_sword": 2, "star_fan": 3, "heaven_halberd": 4}
	scene.save_data["hero_gear"] = {
		"bai_yueling": {"weapon": "jade_sword", "armor": "frost_silk_robe"},
		"yu_han": {"weapon": "heaven_halberd"},
	}
	scene.gear_inspect_id = "star_fan"
	scene._open_codex_tab(3)
	await _step_frames(scene, 4)
	await _save_shot(out_dir + "/equip_tab3_after.png")

	scene.char_status_selected_hid = "bai_yueling"
	scene.char_status_drawer_slot = "weapon"
	scene.char_status_preview_id = "star_fan"
	scene._set_codex_tab(5)
	await _step_frames(scene, 4)
	await _save_shot(out_dir + "/equip_tab5_after.png")

	if FileAccess.file_exists(temp_save):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(temp_save))
	scene.free()
	quit(0)
