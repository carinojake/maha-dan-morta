extends SceneTree

const ART_DIR := "/Users/jake/.gemini/antigravity/brain/0abd22ec-3190-455d-a91e-76f1414aada7"
var _tick: int = 0
var _scene: Node2D
var _ch2_scene: Node2D


func _initialize():
	root.size = Vector2i(1280, 720)
	var packed: PackedScene = load("res://scenes/dark_jade_dungeon.tscn")
	_scene = packed.instantiate()
	root.add_child(_scene)


func _snap(fname: String):
	var img := root.get_texture().get_image()
	img.save_png("%s/%s" % [ART_DIR, fname])
	print("SAVED_SHOT: ", fname)


func _process(_delta: float) -> bool:
	_tick += 1
	if _tick == 12:
		# Move slightly right & cast Bai Yueling Q + R in Ch1 Room 0
		_scene.player.global_position = Vector2(360, 288)
		_scene._cast_skill_r()
	elif _tick == 20:
		_snap("playtest_r1_ch1_combat.png")
	elif _tick == 26:
		# Warp to Ch1 Boss Room & trigger Boss Slam Telegraph
		_scene.player.global_position = Vector2(31.5 * 64, 4.5 * 64)
		_scene.camera.reset_smoothing()
		_scene._spawn_room_wave(2)
		_scene._switch_hero("ye_shangye", true)
	elif _tick == 34:
		for e in _scene.enemies:
			if is_instance_valid(e) and e.get_meta("kind") == "boss":
				_scene._start_slam_telegraph(e, 165.0, 38, 0.85)
				break
	elif _tick == 44:
		_snap("playtest_r1_ch1_boss.png")
	elif _tick == 50:
		# Switch to Chapter 2 Moonlit Bamboo Shrine
		_scene.queue_free()
		root.get_node("Globals").set_meta("chapter", 2)
		_ch2_scene = load("res://scenes/dark_jade_dungeon.tscn").instantiate()
		root.add_child(_ch2_scene)
	elif _tick == 62:
		_ch2_scene._switch_hero("song_ren", false)
		_ch2_scene.player.global_position = Vector2(380, 288)
		_ch2_scene._cast_skill_e()
	elif _tick == 68:
		_snap("playtest_r1_ch2_bamboo.png")
	elif _tick == 74:
		_ch2_scene.player.global_position = Vector2(32.5 * 64, 4.5 * 64)
		_ch2_scene.camera.reset_smoothing()
		_ch2_scene._spawn_room_wave(2)
	elif _tick == 82:
		_snap("playtest_r1_ch2_boss.png")
		root.get_node("Globals").set_meta("chapter", 1)
		quit(0)
		return true
	return false
