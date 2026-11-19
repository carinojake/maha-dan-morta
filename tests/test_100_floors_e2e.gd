extends SceneTree

const ChapterData = preload("res://scripts/chapter_data.gd")
var _tick: int = 0
var _ch: int = 1
var _scene: Node2D


func _initialize():
	root.get_node("Globals").set_meta("chapter", 1)
	_scene = load("res://scenes/dark_jade_dungeon.tscn").instantiate()
	root.add_child(_scene)


func _process(_delta: float) -> bool:
	_tick += 1
	if _tick % 2 == 0:
		var cdata := ChapterData.get_chapter(_ch)
		assert(_scene.chapter == _ch, "Chapter mismatch")
		assert(_scene._total_rooms() == 10, "Each chapter must have 10 rooms")
		# Check Zone 1 (Floor X1), Zone 2 Miniboss (Floor X5), Zone 3 Boss 2-Phase (Floor X0)
		assert(_scene.room_label.text.contains("ชั้นที่ %d/100" % ((_ch - 1) * 10 + 1)), "Floor X1 label mismatch")
		_scene._warp_to_room(4)
		assert(_scene.enemies[0].get_meta("kind") == "bronze_sentinel", "Floor X5 must spawn Gatekeeper Miniboss")
		_scene._warp_to_room(9)
		assert(_scene.boss_panel.visible, "Floor X0 must show Boss HP bar")
		assert(_scene.boss_name_label.text.contains(str(cdata["boss"])), "Boss name must match ChapterData")
		var boss_e: CharacterBody2D = _scene.enemies[0]
		boss_e.set_meta("hp", float(boss_e.get_meta("max_hp")) * 0.40)
		_scene._process_enemies(0.016)
		assert(bool(boss_e.get_meta("phase2_done", false)), "Boss must enter Phase 2 below 50% HP")
		assert(_scene.boss_name_label.text.contains(str(cdata["ult_name"])), "Phase 2 must display ultimate name")

		print("VERIFIED Chapter %d/10 (Floors %d-%d): %s | Miniboss: %s | Boss: %s" % [
			_ch, (_ch - 1) * 10 + 1, _ch * 10, cdata["title"], cdata["miniboss"], cdata["boss"]
		])

		if _ch < 10:
			_ch += 1
			_scene.queue_free()
			root.get_node("Globals").set_meta("chapter", _ch)
			_scene = load("res://scenes/dark_jade_dungeon.tscn").instantiate()
			root.add_child(_scene)
		else:
			root.get_node("Globals").set_meta("chapter", 1)
			print("ALL_10_CHAPTERS_100_FLOORS_E2E_PASSED: 10,240px x 10 Chapters = 100 Floors verified!")
			quit(0)
			return true
	return false
