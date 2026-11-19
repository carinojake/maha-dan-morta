extends SceneTree

var _tick: int = 0
var _failed: bool = false
var _scene: Node2D


func _fail(msg: String):
	if _failed:
		return
	_failed = true
	printerr("FAIL: " + msg)
	quit(1)


func _check(cond: bool, msg: String) -> bool:
	if not cond:
		_fail(msg)
		return false
	return true


func _initialize():
	var test_save := "user://test_ipad_touch_save.json"
	if FileAccess.file_exists(test_save):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(test_save))
	var globals := root.get_node("Globals")
	globals.set_meta("save_path", test_save)
	globals.set_meta("chapter", 1)
	root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_IGNORE
	root.content_scale_size = Vector2i(1280, 960)
	root.size = Vector2i(1280, 960)
	_scene = load("res://scenes/dark_jade_dungeon.tscn").instantiate()
	root.add_child(_scene)


func _process(_delta: float) -> bool:
	if _failed:
		return true
	_tick += 1
	if _tick == 4:
		if _scene.help_overlay:
			_scene.help_overlay.visible = false
		_scene._set_touch_mode(true)
		_scene._on_viewport_resized()
		_check(_scene.mobile_controls.visible, "Touch controls must be visible in touch mode")
		_check(not _scene.bot_center_row.visible, "Desktop keyboard pills must hide when touch mode is active")

		var mc: Control = _scene.mobile_controls
		for b in [mc.btn_q, mc.btn_dash, mc.btn_e, mc.btn_r, mc.btn_attack, mc.btn_auto, mc.btn_codex]:
			var r := (b as Control).get_global_rect()
			_check(r.position.x >= 0.0 and r.end.x <= 600.0 and r.position.y >= 400.0 and r.end.y <= 950.0, "iPad left-hand button out of thumb zone: %s -> %s" % [b.text, str(r)])

		var prev_pos: Vector2 = _scene.player.global_position
		mc.joy_vector = Vector2(1.0, 0.0)
		_scene._physics_process(0.05)
		_check(_scene.player.global_position.x > prev_pos.x, "Joystick RIGHT must move hero right")
		mc.joy_vector = Vector2.ZERO

		_scene._trigger_victory()
		_scene._toggle_upgrade_modal()
		_check(_scene.upgrade_overlay.get_index() > _scene.end_overlay.get_index(), "Codex must render above Victory overlay")
		_scene._toggle_upgrade_modal()

		_scene._set_touch_mode(false)
		_check(not _scene.mobile_controls.visible and _scene.bot_center_row.visible, "Desktop mode must restore keyboard pills")

		_scene.queue_free()
		if not _failed:
			print("IPAD_LANDSCAPE_TOUCH_E2E_PASSED: 1280x960 iPad left-hand touch, joystick, and Z-order verified!")
			quit(0)
			return true
	return _failed
