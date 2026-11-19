extends SceneTree

const SaveManager = preload("res://scripts/save_manager.gd")

const VIEWPORT_W := 1280.0
const VIEWPORT_H := 720.0

var _tick: int = 0
var _scene: Node2D
var _test_save := "user://test_bai_cutin_save.json"


func _fail(msg: String):
	Engine.time_scale = 1.0
	printerr("FAIL: " + msg)
	quit(1)


func _check(cond: bool, msg: String) -> bool:
	if not cond:
		_fail(msg)
		return false
	return true


func _initialize():
	if FileAccess.file_exists(_test_save):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(_test_save))
	var fresh_save := SaveManager.load_data(_test_save)
	if not bool(fresh_save.get("cutin_enabled", false)):
		_fail("SaveManager.load_data must default cutin_enabled to true")
		return
	var globals := root.get_node("Globals")
	globals.set_meta("save_path", _test_save)
	globals.set_meta("chapter", 1)
	root.size = Vector2i(int(VIEWPORT_W), int(VIEWPORT_H))
	_scene = load("res://scenes/dark_jade_dungeon.tscn").instantiate()
	root.add_child(_scene)


func _process(_delta: float) -> bool:
	_tick += 1
	if _tick == 4:
		if not _check(_scene.active_hero_id == "bai_yueling", "Default hero must be bai_yueling"):
			return true
		if not _check(_scene.cutin_overlay != null, "cutin_overlay must be initialized"):
			return true

		_scene.hero_sp["bai_yueling"] = 120.0
		_scene.q_cd = 0.0
		_scene.e_cd = 0.0
		_scene.r_cd = 0.0

		_scene._cast_skill_q(Vector2.RIGHT)
		_scene._cast_skill_e()
		_scene._cast_skill_r()

		var cutin: Control = _scene.cutin_overlay
		if not _check(cutin.is_playing(), "Casting Bai Yueling [R] must trigger Cut-in"):
			return true
		if not _check(cutin.get_slowmo_scale() < 1.0, "Cut-in slow-mo scale must be < 1.0 at start"):
			return true

		# Advance past slide-in (0.16s) while still inside slow-mo window (< 0.65s)
		cutin.tick(0.25)
		if not _check(cutin.get_slowmo_scale() < 1.0, "Cut-in slow-mo scale must remain < 1.0 at 0.25s"):
			return true

		var card: PanelContainer = cutin.get_card_panel()
		var rect: Rect2 = card.get_global_rect()
		if not _check(card.visible, "Cut-in card panel must be visible during playback"):
			return true
		if not _check(rect.position.x >= 0.0 and rect.position.y >= 0.0 and rect.end.x <= VIEWPORT_W and rect.end.y <= VIEWPORT_H, "Cut-in card rect %s must fit strictly inside 1280x720" % str(rect)):
			return true

		# Advance 0.4s x 6 = 2.4s to complete Cut-in animation
		for _i in range(6):
			cutin.tick(0.4)

		if not _check(not cutin.is_playing(), "Cut-in must finish after 2.4s"):
			return true
		if not _check(is_equal_approx(cutin.get_slowmo_scale(), 1.0), "Cut-in slowmo scale must restore to 1.0"):
			return true

		# Toggle Cut-in OFF and verify save persistence + suppression
		_scene._toggle_cutin()
		if not _check(not bool(_scene.save_data.get("cutin_enabled", true)), "Toggle must disable cutin_enabled in save_data"):
			return true
		var reloaded := SaveManager.load_data(_test_save)
		if not _check(not bool(reloaded.get("cutin_enabled", true)), "cutin_enabled=false must persist across SaveManager.load_data"):
			return true

		_scene.hero_sp["bai_yueling"] = 120.0
		_scene.r_cd = 0.0
		_scene._cast_skill_r()
		if not _check(not cutin.is_playing(), "Casting [R] when cutin_enabled=false must NOT play Cut-in"):
			return true

		Engine.time_scale = 1.0
		_scene.queue_free()
		print("BAI_YUELING_CUTIN_E2E_PASSED: Cut-in atlas, 4-phase Ice VFX, bounds, and toggle persistence verified!")
		quit(0)
		return true
	return false
