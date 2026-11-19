extends SceneTree

const SaveManager = preload("res://scripts/save_manager.gd")
const HeroData = preload("res://scripts/hero_data.gd")

const VIEWPORT_W := 1280.0
const VIEWPORT_H := 720.0
const SET_CONTENT_SCALE := false

var _tick: int = 0
var _scene: Node2D
var _test_save := "user://test_bai_cutin_save.json"
var _finished_signals: int = 0


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
	if str(fresh_save.get("cutin_mode", "")) != "full":
		_fail("SaveManager.load_data must default cutin_mode to 'full'")
		return
	var globals := root.get_node("Globals")
	globals.set_meta("save_path", _test_save)
	globals.set_meta("chapter", 1)
	if SET_CONTENT_SCALE:
		root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_IGNORE
		root.content_scale_size = Vector2i(int(VIEWPORT_W), int(VIEWPORT_H))
	root.size = Vector2i(int(VIEWPORT_W), int(VIEWPORT_H))
	_scene = load("res://scenes/dark_jade_dungeon.tscn").instantiate()
	root.add_child(_scene)


func _on_finished(_hid: String):
	_finished_signals += 1


func _cast_ready_r(hid: String):
	_scene.hero_sp[hid] = 150.0
	_scene.r_cd = 0.0
	_scene.last_skill_er_timer = 0.0
	_scene._cast_skill_r()


func _process(_delta: float) -> bool:
	_tick += 1
	if _tick != 4:
		return false
	if not _check(_scene.active_hero_id == "bai_yueling", "Default hero must be bai_yueling"):
		return true
	if not _check(_scene.cutin_overlay != null, "cutin_overlay must be initialized"):
		return true

	var cutin: Control = _scene.cutin_overlay
	cutin.fullscreen_finished.connect(_on_finished)
	var vp: Vector2 = _scene.get_viewport_rect().size
	var i := 0
	for hid in HeroData.HERO_ORDER:
		if not _check(cutin.has_cutin(hid), "cutin_overlay must register %s" % hid):
			return true
		_scene._switch_hero(hid, false)
		if not _check(_scene.active_hero_id == hid, "Must switch to %s" % hid):
			return true
		var sp_before := 150.0
		_cast_ready_r(hid)

		# 1) [R] opens a full-screen clip and pauses combat; damage is held back.
		if not _check(cutin.is_fullscreen_playing(), "%s [R] must open FULL-SCREEN Cut-in" % hid):
			return true
		if not _check(_scene.pending_ult_hero == hid, "%s ultimate damage must be pending until the clip ends" % hid):
			return true
		if not _check(_scene._is_modal_open(), "%s full-screen Cut-in must block combat like a modal" % hid):
			return true
		if not _check(_scene.r_cd > 0.0 and _scene.hero_sp[hid] < sp_before, "%s [R] cost/cooldown must be paid at press time" % hid):
			return true
		if not _check(is_equal_approx(_scene.last_skill_er_timer, 0.0), "%s ultimate must NOT fire before the clip ends" % hid):
			return true

		_scene._process(0.016)
		if not _check(is_equal_approx(Engine.time_scale, 1.0), "%s Engine.time_scale must be 1.0 while paused for clip" % hid):
			return true
		cutin.tick(0.3)
		var full_rect: Rect2 = cutin.get_full_root().get_global_rect()
		if not _check(full_rect.position.x <= 0.5 and full_rect.position.y <= 0.5 and full_rect.size.x >= vp.x - 1.0 and full_rect.size.y >= vp.y - 1.0, "%s full-screen rect %s must cover viewport %s" % [hid, str(full_rect), str(vp)]):
			return true

		# Second [R] press while the clip plays must be ignored.
		_scene.r_cd = 0.0
		_scene.hero_sp[hid] = 150.0
		_scene._cast_skill_r()
		if not _check(is_equal_approx(_scene.hero_sp[hid], 150.0), "%s second [R] during clip must not double-cast" % hid):
			return true

		# 2) Finish either naturally, via tap-skip, or via skip().
		var before_signals := _finished_signals
		if i % 3 == 0:
			for _k in range(8):
				cutin.tick(0.4)
		elif i % 3 == 1:
			var tap := InputEventMouseButton.new()
			tap.button_index = MOUSE_BUTTON_LEFT
			tap.pressed = true
			cutin._on_full_gui_input(tap)
		else:
			cutin.skip()

		if not _check(not cutin.is_playing(), "%s Cut-in must end (mode %d)" % [hid, i % 3]):
			return true
		if not _check(_finished_signals == before_signals + 1, "%s fullscreen_finished must emit exactly once" % hid):
			return true
		if not _check(_scene.pending_ult_hero == "", "%s pending ultimate must be released" % hid):
			return true
		if not _check(_scene.last_skill_er_timer > 0.0, "%s ultimate must fire right after returning to gameplay" % hid):
			return true
		if not _check(not _scene._is_modal_open(), "%s gameplay must resume after clip" % hid):
			return true
		i += 1

	# Tap-skip guard: a tap in the first frames must not instantly close the clip.
	_scene._switch_hero("bai_yueling", false)
	_cast_ready_r("bai_yueling")
	var early_tap := InputEventMouseButton.new()
	early_tap.button_index = MOUSE_BUTTON_LEFT
	early_tap.pressed = true
	cutin._on_full_gui_input(early_tap)
	if not _check(cutin.is_fullscreen_playing(), "Tap during skip-guard window must not skip the clip"):
		return true
	cutin.skip()

	# 3) Mode cycle: full -> boss -> skip -> full, persisted.
	_scene._toggle_cutin()
	if not _check(_scene._get_cutin_mode() == "boss", "Toggle #1 must switch to 'boss' mode"):
		return true
	for e in _scene.enemies.duplicate():
		if is_instance_valid(e):
			e.queue_free()
	_scene.enemies.clear()
	_cast_ready_r("bai_yueling")
	if not _check(cutin.is_playing() and not cutin.is_fullscreen_playing(), "'boss' mode without a boss must use the small side card"):
		return true
	if not _check(_scene.pending_ult_hero == "" and _scene.last_skill_er_timer > 0.0, "Card mode must fire the ultimate immediately"):
		return true
	if not _check(cutin.get_slowmo_scale() < 1.0, "Card mode must keep its short slow-mo"):
		return true
	cutin.tick(0.25)
	var card_rect: Rect2 = cutin.get_card_panel().get_global_rect()
	if not _check(card_rect.position.x >= 0.0 and card_rect.position.y >= 0.0 and card_rect.end.x <= vp.x and card_rect.end.y <= vp.y, "Card rect %s must fit inside viewport %s" % [str(card_rect), str(vp)]):
		return true
	for _k in range(8):
		cutin.tick(0.4)
	if not _check(not cutin.is_playing(), "Card Cut-in must finish"):
		return true

	_scene._spawn_room_wave(9)
	if not _check(_scene._is_boss_present(), "Room 10 wave must contain a boss"):
		return true
	_cast_ready_r("bai_yueling")
	if not _check(cutin.is_fullscreen_playing(), "'boss' mode with a boss present must play FULL-SCREEN"):
		return true
	cutin.skip()

	_scene._toggle_cutin()
	if not _check(_scene._get_cutin_mode() == "skip", "Toggle #2 must switch to 'skip' mode"):
		return true
	var reloaded := SaveManager.load_data(_test_save)
	if not _check(str(reloaded.get("cutin_mode", "")) == "skip" and not bool(reloaded.get("cutin_enabled", true)), "cutin_mode=skip must persist across SaveManager.load_data"):
		return true
	_cast_ready_r("bai_yueling")
	if not _check(not cutin.is_playing(), "'skip' mode must NOT play any Cut-in"):
		return true
	if not _check(_scene.last_skill_er_timer > 0.0, "'skip' mode must still fire the ultimate"):
		return true

	_scene._toggle_cutin()
	if not _check(_scene._get_cutin_mode() == "full", "Toggle #3 must cycle back to 'full'"):
		return true

	Engine.time_scale = 1.0
	_scene.queue_free()
	print("ALL_7_HEROES_FULLSCREEN_CUTIN_E2E_PASSED: pause, held damage, tap/auto skip, 3-mode cycle and persistence verified!")
	quit(0)
	return true
