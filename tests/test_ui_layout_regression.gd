extends SceneTree

const VIEWPORT_W := 1280.0
const VIEWPORT_H := 720.0

var _tick: int = 0
var _scene: Node2D


func _initialize():
	var test_save := "user://test_ui_layout_save.json"
	if FileAccess.file_exists(test_save):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(test_save))
	var globals := root.get_node("Globals")
	globals.set_meta("save_path", test_save)
	globals.set_meta("chapter", 1)
	root.size = Vector2i(int(VIEWPORT_W), int(VIEWPORT_H))
	_scene = load("res://scenes/dark_jade_dungeon.tscn").instantiate()
	root.add_child(_scene)


func _fail(msg: String):
	printerr("FAIL: " + msg)
	quit(1)


func _assert_in_bounds(ctrl: Control, label: String):
	if not is_instance_valid(ctrl):
		_fail("%s must be valid" % label)
		return
	var rect := ctrl.get_global_rect()
	if rect.size.x <= 0.0 or rect.size.y <= 0.0:
		_fail("%s must have non-zero size (got %s)" % [label, str(rect.size)])
	elif rect.position.x < -1.0:
		_fail("%s clips left edge: x=%.1f" % [label, rect.position.x])
	elif rect.position.y < -1.0:
		_fail("%s clips top edge: y=%.1f" % [label, rect.position.y])
	elif rect.end.x > VIEWPORT_W + 1.0:
		_fail("%s clips right edge: end.x=%.1f > %.1f" % [label, rect.end.x, VIEWPORT_W])
	elif rect.end.y > VIEWPORT_H + 1.0:
		_fail("%s clips bottom edge: end.y=%.1f > %.1f" % [label, rect.end.y, VIEWPORT_H])


func _process(_delta: float) -> bool:
	_tick += 1
	if _tick == 4:
		if _scene.help_overlay:
			_scene.help_overlay.visible = false
		_scene._warp_to_room(9)
		_scene.combat.add_combo(360.0, true)
		_scene.combat.perfect_dodge_crit_ready = true
		_scene._show_banner("ทดสอบแบนเนอร์ HUD 1280x720", 2.0)
		_scene._refresh_hud()
	elif _tick == 8:
		_assert_in_bounds(_scene.hp_bar, "hp_bar")
		_assert_in_bounds(_scene.sp_bar, "sp_bar")
		_assert_in_bounds(_scene.portrait_row, "portrait_row")
		_assert_in_bounds(_scene.room_label, "room_label")
		_assert_in_bounds(_scene.boss_panel, "boss_panel")
		_assert_in_bounds(_scene.banner_panel, "banner_panel")
		_assert_in_bounds(_scene.minimap_ctrl, "minimap_ctrl")
		_assert_in_bounds(_scene.diff_btn, "diff_btn")
		_assert_in_bounds(_scene.combo_panel, "combo_panel")
		_assert_in_bounds(_scene.dodge_ready_label, "dodge_ready_label")
		# Verify every button in top-right row fits inside viewport
		var btn_row: Node = _scene.diff_btn.get_parent()
		for child in btn_row.get_children():
			if child is Control:
				_assert_in_bounds(child, "top_right_btn:" + child.text)
		_scene.queue_free()
		print("UI_LAYOUT_REGRESSION_PASSED: All HUD controls fit cleanly inside 1280x720!")
		quit(0)
		return true
	return false
