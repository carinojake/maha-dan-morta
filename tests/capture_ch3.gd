extends SceneTree

const ART_DIR := "/Users/jake/.gemini/antigravity/brain/0abd22ec-3190-455d-a91e-76f1414aada7"
var _tick: int = 0
var _scene: Node2D


func _initialize():
	root.size = Vector2i(1280, 720)
	root.get_node("Globals").set_meta("chapter", 3)
	_scene = load("res://scenes/dark_jade_dungeon.tscn").instantiate()
	root.add_child(_scene)


func _snap(fname: String):
	var img := root.get_texture().get_image()
	img.save_png("%s/%s" % [ART_DIR, fname])
	print("SAVED_SHOT: ", fname)


func _process(_delta: float) -> bool:
	_tick += 1
	if _tick == 8:
		# Room 5 (idx 4): Miniboss Bronze Sentinel + Shield Bar + 10-Room Minimap
		for e in _scene.enemies.duplicate():
			if is_instance_valid(e):
				e.queue_free()
		_scene.enemies.clear()
		_scene.player.global_position = Vector2((4.5 + 4.0 * 14.0) * 64.0, 4.5 * 64.0)
		_scene.camera.reset_smoothing()
		_scene._spawn_room_wave(4)
		_scene._cast_skill_e()
	elif _tick == 14:
		_scene._switch_hero("ye_shangye", true)
	elif _tick == 20:
		_snap("playtest_ch3_miniboss.png")
	elif _tick == 26:
		# Room 10 (idx 9): Boss Xuanji Phase 2 + Orbiting Sawblades + 8-Dir Storm Safe Zone
		for e in _scene.enemies.duplicate():
			if is_instance_valid(e):
				e.queue_free()
		_scene.enemies.clear()
		_scene.player.global_position = Vector2((4.5 + 9.0 * 14.0) * 64.0, 4.5 * 64.0)
		_scene.camera.reset_smoothing()
		_scene._spawn_room_wave(9)
		var boss: CharacterBody2D = _scene.enemies[0]
		boss.set_meta("hp", float(boss.get_meta("max_hp")) * 0.42)
		_scene._process_enemies(0.016)
	elif _tick == 36:
		_snap("playtest_ch3_boss_p2.png")
		root.get_node("Globals").set_meta("chapter", 1)
		quit(0)
		return true
	return false
