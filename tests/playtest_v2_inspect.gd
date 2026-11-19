extends SceneTree

const ART_DIR := "/Users/jake/.gemini/antigravity/brain/0abd22ec-3190-455d-a91e-76f1414aada7"
var _tick: int = 0
var _scene: Node2D


func _initialize():
	root.size = Vector2i(1280, 720)
	root.get_node("Globals").set_meta("chapter", 4)
	_scene = load("res://scenes/dark_jade_dungeon.tscn").instantiate()
	root.add_child(_scene)


func _snap(fname: String):
	var img := root.get_texture().get_image()
	img.save_png("%s/%s" % [ART_DIR, fname])
	print("SAVED_V5_SHOT: ", fname)


func _process(_delta: float) -> bool:
	_tick += 1
	if _tick == 6:
		# Ch4 Miniboss: Three-Headed Hellfire Lion (ราชสีห์เพลิงอสูรสามเศียร) + ShieldAura + Nameplate
		_scene._warp_to_room(4)
	elif _tick == 12:
		_snap("v5_ch4_miniboss.png")
	elif _tick == 16:
		# Ch5 Boss: Sky-Sword Grandmaster Lu Tian (หมื่นกระบี่ไร้พ่ายตัดดารา)
		_scene.queue_free()
		root.get_node("Globals").set_meta("chapter", 5)
		_scene = load("res://scenes/dark_jade_dungeon.tscn").instantiate()
		root.add_child(_scene)
	elif _tick == 22:
		_scene._warp_to_room(9)
		var boss: CharacterBody2D = _scene.enemies[0]
		boss.set_meta("hp", float(boss.get_meta("max_hp")) * 0.42)
		_scene._process_enemies(0.016)
	elif _tick == 28:
		_snap("v5_ch5_boss_swords.png")
	elif _tick == 32:
		# Ch10 Finale Boss: Supreme Fate Wheel Avatar (วัฏจักรหมื่นภพดับสูญ)
		_scene.queue_free()
		root.get_node("Globals").set_meta("chapter", 10)
		_scene = load("res://scenes/dark_jade_dungeon.tscn").instantiate()
		root.add_child(_scene)
	elif _tick == 38:
		_scene._warp_to_room(9)
		var boss10: CharacterBody2D = _scene.enemies[0]
		boss10.set_meta("hp", float(boss10.get_meta("max_hp")) * 0.42)
		_scene._process_enemies(0.016)
	elif _tick == 44:
		_snap("v5_ch10_fate_wheel.png")
		root.get_node("Globals").set_meta("chapter", 1)
		quit(0)
		return true
	return false
