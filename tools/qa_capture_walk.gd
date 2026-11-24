extends SceneTree

var _frame: int = 0
var _scene: Node2D
var _out_dir: String = ""
var _tag: String = "before"
var _held_keys: Array[int] = []


func _set_keys(keys: Array[int]):
	for old_k in _held_keys:
		if not keys.has(old_k):
			var ev_up := InputEventKey.new()
			ev_up.keycode = old_k as Key
			ev_up.physical_keycode = old_k as Key
			ev_up.pressed = false
			Input.parse_input_event(ev_up)
	for new_k in keys:
		if not _held_keys.has(new_k):
			var ev_dn := InputEventKey.new()
			ev_dn.keycode = new_k as Key
			ev_dn.physical_keycode = new_k as Key
			ev_dn.pressed = true
			Input.parse_input_event(ev_dn)
	_held_keys = keys.duplicate()
	Input.flush_buffered_events()


func _initialize():
	var args := OS.get_cmdline_user_args()
	for a in args:
		if a.begins_with("--out="):
			_out_dir = a.substr(6)
		elif a.begins_with("--tag="):
			_tag = a.substr(6)
	if _out_dir == "":
		_out_dir = ProjectSettings.globalize_path("res://docs/quality_improvement/frames_" + _tag)
	DirAccess.make_dir_recursive_absolute(_out_dir)

	var test_save := "user://qa_walk_capture_save.json"
	if FileAccess.file_exists(test_save):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(test_save))
	var globals := root.get_node("Globals")
	globals.set_meta("save_path", test_save)
	globals.set_meta("chapter", 1)
	root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP
	root.content_scale_size = Vector2i(1280, 720)
	root.size = Vector2i(1280, 720)
	_scene = load("res://scenes/dark_jade_dungeon.tscn").instantiate()
	root.add_child(_scene)


func _process(_delta: float) -> bool:
	_frame += 1
	if _frame == 2:
		# Clear Room 0 tutorial enemy & UI clutter so feet and gait are 100% visible
		for e in _scene.enemies.duplicate():
			if is_instance_valid(e):
				e.queue_free()
		_scene.enemies.clear()
		_scene.auto_attack_enabled = false
		if _scene.help_overlay:
			_scene.help_overlay.visible = false
		if _scene.tutorial_panel:
			_scene.tutorial_panel.visible = false
		if _scene.tutorial_arrow_lbl:
			_scene.tutorial_arrow_lbl.visible = false
		_scene.tutorial_step = 0
		if _scene.banner_panel:
			_scene.banner_panel.visible = false
		_scene.player.global_position = Vector2(320.0, 288.0)
		_scene.camera.reset_smoothing()
		return false

	if _frame < 4:
		return false

	var f := _frame - 4
	# Schedule (30 fps):
	# Default costume:
	#   0..14   : Idle front/side
	#   15..54  : Walk RIGHT (KEY_D)
	#   55..69  : Stop RIGHT (show planted feet)
	#   70..109 : Walk LEFT (KEY_A)
	#   110..124: Stop LEFT (show planted feet)
	#   125..154: Walk DOWN (KEY_S)
	#   155..169: Stop DOWN (show planted feet)
	#   170..199: Walk UP (KEY_W)
	#   200..214: Stop UP (show planted feet)
	#   215..241: Walk DIAGONAL Down-Right (KEY_D + KEY_S)
	#   242..268: Walk DIAGONAL Up-Left (KEY_A + KEY_W)
	#   269..283: Stop
	# Alt Snow Cloak costume:
	#   284     : Switch to alt costume at same start pos
	#   285..296: Idle alt
	#   297..329: Walk RIGHT alt
	#   330..341: Stop RIGHT alt
	#   342..374: Walk LEFT alt
	#   375..386: Stop LEFT alt
	#   387..412: Walk DOWN alt
	#   413..424: Stop DOWN alt
	#   425..450: Walk UP alt
	#   451..464: Stop UP alt
	if f == 0:
		_set_keys([])
	elif f == 15:
		_set_keys([KEY_D])
	elif f == 55:
		_set_keys([])
	elif f == 70:
		_set_keys([KEY_A])
	elif f == 110:
		_set_keys([])
	elif f == 125:
		_scene.player.global_position = Vector2(450.0, 210.0)
		_scene.camera.reset_smoothing()
		_set_keys([KEY_S])
	elif f == 155:
		_set_keys([])
	elif f == 170:
		_set_keys([KEY_W])
	elif f == 200:
		_set_keys([])
	elif f == 215:
		_scene.player.global_position = Vector2(360.0, 215.0)
		_scene.camera.reset_smoothing()
		_set_keys([KEY_D, KEY_S])
	elif f == 242:
		_set_keys([KEY_A, KEY_W])
	elif f == 269:
		_set_keys([])
	elif f == 284:
		_set_keys([])
		_scene.save_data["costumes"]["bai_yueling"] = "alt"
		_scene._switch_hero("bai_yueling", false)
		_scene.player.global_position = Vector2(320.0, 288.0)
		_scene.camera.reset_smoothing()
	elif f == 297:
		_set_keys([KEY_D])
	elif f == 330:
		_set_keys([])
	elif f == 342:
		_set_keys([KEY_A])
	elif f == 375:
		_set_keys([])
	elif f == 387:
		_scene.player.global_position = Vector2(450.0, 210.0)
		_scene.camera.reset_smoothing()
		_set_keys([KEY_S])
	elif f == 413:
		_set_keys([])
	elif f == 425:
		_set_keys([KEY_W])
	elif f == 451:
		_set_keys([])

	if _scene.banner_panel:
		_scene.banner_panel.visible = false

	var img := root.get_texture().get_image()
	if img != null:
		img.save_png("%s/frame_%04d.png" % [_out_dir, f])

	if f >= 464:
		_set_keys([])
		_scene.queue_free()
		print("WALK_CAPTURE_DONE:", _tag, "frames=", f + 1, "final_pos=", _scene.player.global_position)
		quit(0)
		return true
	return false
