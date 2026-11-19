extends SceneTree

var _tick: int = 0
var _scene: Node2D
var _ch2_scene: Node2D


func _initialize():
	var test_save := "user://test_dark_jade_save.json"
	if FileAccess.file_exists(test_save):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(test_save))
	var globals := root.get_node("Globals")
	globals.set_meta("save_path", test_save)
	globals.set_meta("chapter", 1)
	_scene = load("res://scenes/dark_jade_dungeon.tscn").instantiate()
	root.add_child(_scene)


func _process(_delta: float) -> bool:
	_tick += 1
	if _tick == 4:
		assert(_scene.active_hero_id == "bai_yueling", "Default hero must be Bai Yueling")
		assert(_scene._total_rooms() == 10, "Chapter 1 must have 10 rooms (10,240 px)")
		assert(_scene.enemies.size() == 3, "Ch1 Room 0 should spawn 3 enemies")
		_scene._cast_skill_q(Vector2.RIGHT)
		_scene._cast_skill_e()
		_scene._cast_skill_r()
		assert(_scene.cutin_overlay.is_fullscreen_playing(), "[R] must open full-screen Cut-in")
		_scene.cutin_overlay.skip()
		_scene._switch_hero("ye_shangye", true)
		assert(_scene.active_hero_id == "ye_shangye", "Should switch to Ye Shangye")
		_scene._switch_hero("song_ren", true)
		assert(_scene.active_hero_id == "song_ren", "Should switch to Song Ren")
	elif _tick == 8:
		for e in _scene.enemies.duplicate():
			if is_instance_valid(e):
				e.queue_free()
		_scene.enemies.clear()
		_scene._spawn_room_wave(9)
		assert(_scene.boss_panel.visible, "Ch1 Boss HP panel must be visible on Room 10 (idx 9)")
		_scene.queue_free()
		root.get_node("Globals").set_meta("chapter", 2)
		_ch2_scene = load("res://scenes/dark_jade_dungeon.tscn").instantiate()
		root.add_child(_ch2_scene)
	elif _tick == 12:
		assert(_ch2_scene.chapter == 2, "Chapter 2 must load cleanly")
		assert(_ch2_scene._total_rooms() == 10, "Chapter 2 must have 10 rooms")
		for e in _ch2_scene.enemies.duplicate():
			if is_instance_valid(e):
				e.queue_free()
		_ch2_scene.enemies.clear()
		_ch2_scene._spawn_room_wave(9)
		assert(_ch2_scene.boss_panel.visible, "Ch2 Boss HP panel must be visible on Room 10 (idx 9)")
		root.get_node("Globals").set_meta("chapter", 1)
		print("CH1_AND_CH2_BAMBOO_E2E_PASSED: 10-Room Ch1 & Ch2 verified!")
		quit(0)
		return true
	return false
