extends Control

signal attack_pressed
signal skill_q_pressed
signal skill_e_pressed
signal skill_r_pressed
signal dash_pressed
signal auto_toggled
signal codex_pressed

const JOY_MAX_RADIUS := 64.0
const JOY_KNOB_RADIUS := 26.0

var joy_vector: Vector2 = Vector2.ZERO
var joy_active: bool = false

var btn_q: Button
var btn_e: Button
var btn_r: Button
var btn_dash: Button
var btn_attack: Button
var btn_auto: Button
var btn_codex: Button

var _active: bool = true
var _auto_is_on: bool = true
var _last_styled_auto: int = -1
var _touch_idx: int = -1
var _mouse_joy_active: bool = false
var _idle_joy_anchor: Vector2 = Vector2(118.0, 602.0)
var _playfield_min_y: float = 165.0
var _playfield_max_y: float = 698.0
var _joy_origin: Vector2 = _idle_joy_anchor
var _joy_knob_pos: Vector2 = _idle_joy_anchor
var _pulse_t: float = 0.0
var _r_ready: bool = true
var _buttons: Array[Button] = []


func _ready():
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	btn_q = _make_circle_btn("Q\nพร้อม", Vector2(228.0, 616.0), Vector2(68.0, 68.0), Color("#38bdf8"), Color(0.04, 0.14, 0.24, 0.90), 12)
	btn_q.pressed.connect(func(): skill_q_pressed.emit())

	btn_dash = _make_circle_btn("หลบ\nพร้อม", Vector2(308.0, 616.0), Vector2(68.0, 68.0), Color("#2dd4bf"), Color(0.03, 0.16, 0.16, 0.90), 11)
	btn_dash.pressed.connect(func(): dash_pressed.emit())

	btn_e = _make_circle_btn("E\nพร้อม", Vector2(254.0, 536.0), Vector2(68.0, 68.0), Color("#a855f7"), Color(0.14, 0.06, 0.24, 0.90), 12)
	btn_e.pressed.connect(func(): skill_e_pressed.emit())

	btn_r = _make_circle_btn("★ R\nพร้อม", Vector2(336.0, 516.0), Vector2(78.0, 78.0), Color("#facc15"), Color(0.22, 0.15, 0.03, 0.94), 13)
	btn_r.pressed.connect(func(): skill_r_pressed.emit())

	btn_attack = _make_circle_btn("⚔️ ตี", Vector2(392.0, 606.0), Vector2(64.0, 64.0), Color("#f87171"), Color(0.28, 0.06, 0.08, 0.92), 13)
	btn_attack.pressed.connect(func(): attack_pressed.emit())

	btn_auto = _make_pill_btn("⚡ ออโต้ ON", Vector2(24.0, 472.0), Vector2(96.0, 44.0), Color("#34d399"), 11)
	btn_auto.pressed.connect(func(): auto_toggled.emit())

	btn_codex = _make_pill_btn("📜 คัมภีร์", Vector2(126.0, 472.0), Vector2(96.0, 44.0), Color("#38bdf8"), 11)
	btn_codex.pressed.connect(func(): codex_pressed.emit())

	_buttons = [btn_q, btn_dash, btn_e, btn_r, btn_attack, btn_auto, btn_codex]
	layout_for_viewport(Vector2(1280.0, 720.0))


func layout_for_viewport(vp: Vector2):
	var h := maxf(vp.y, 720.0)
	btn_q.position = Vector2(228.0, h - 104.0)
	btn_dash.position = Vector2(308.0, h - 104.0)
	btn_e.position = Vector2(254.0, h - 184.0)
	btn_r.position = Vector2(336.0, h - 204.0)
	btn_attack.position = Vector2(392.0, h - 114.0)
	btn_auto.position = Vector2(24.0, h - 248.0)
	btn_codex.position = Vector2(126.0, h - 248.0)

	_idle_joy_anchor = Vector2(118.0, h - 118.0)
	_playfield_min_y = 165.0
	_playfield_max_y = h - 20.0
	if not joy_active:
		_joy_origin = _idle_joy_anchor
		_joy_knob_pos = _idle_joy_anchor
	queue_redraw()


func _make_circle_btn(lbl_text: String, pos: Vector2, sz: Vector2, border_col: Color, bg_col: Color, font_sz: int) -> Button:
	var b := Button.new()
	b.text = lbl_text
	b.position = pos
	b.custom_minimum_size = sz
	b.size = sz
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", font_sz)
	b.add_theme_color_override("font_color", Color.WHITE)
	_apply_btn_styles(b, bg_col, border_col, int(sz.x * 0.5), 2)
	add_child(b)
	return b


func _make_pill_btn(lbl_text: String, pos: Vector2, sz: Vector2, border_col: Color, font_sz: int) -> Button:
	var b := Button.new()
	b.text = lbl_text
	b.position = pos
	b.custom_minimum_size = sz
	b.size = sz
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", font_sz)
	b.add_theme_color_override("font_color", Color.WHITE)
	_apply_btn_styles(b, Color(0.05, 0.08, 0.13, 0.90), border_col, 12, 2)
	add_child(b)
	return b


func _apply_btn_styles(b: Button, bg_col: Color, border_col: Color, radius: int, border_w: int):
	var normal := StyleBoxFlat.new()
	normal.bg_color = bg_col
	normal.border_color = border_col
	normal.set_border_width_all(border_w)
	normal.set_corner_radius_all(radius)

	var pressed := normal.duplicate()
	pressed.bg_color = bg_col.lightened(0.25)
	pressed.border_color = Color.WHITE

	b.add_theme_stylebox_override("normal", normal)
	b.add_theme_stylebox_override("hover", normal)
	b.add_theme_stylebox_override("pressed", pressed)


func set_active(enabled: bool):
	_active = enabled
	if not enabled:
		_reset_joystick()


func _reset_joystick():
	_touch_idx = -1
	_mouse_joy_active = false
	joy_active = false
	joy_vector = Vector2.ZERO
	_joy_origin = _idle_joy_anchor
	_joy_knob_pos = _idle_joy_anchor
	queue_redraw()


func _is_over_any_button(pos: Vector2) -> bool:
	for b in _buttons:
		if is_instance_valid(b) and b.visible and b.get_global_rect().grow(6.0).has_point(pos):
			return true
	return false


func _update_joy_at(pos: Vector2):
	var diff := pos - _joy_origin
	var len_val := diff.length()
	if len_val > JOY_MAX_RADIUS and len_val > 0.001:
		diff = (diff / len_val) * JOY_MAX_RADIUS
	_joy_knob_pos = _joy_origin + diff
	joy_vector = (diff / JOY_MAX_RADIUS) if len_val > 6.0 else Vector2.ZERO
	queue_redraw()


func _input(event: InputEvent):
	if not _active or not visible:
		return

	if event is InputEventScreenTouch:
		var ev := make_input_local(event) as InputEventScreenTouch
		var pos := ev.position
		if ev.pressed:
			if _touch_idx == -1 and pos.y >= _playfield_min_y and pos.y <= _playfield_max_y and not _is_over_any_button(pos):
				_touch_idx = ev.index
				joy_active = true
				_joy_origin = pos
				_update_joy_at(pos)
		elif ev.index == _touch_idx:
			_reset_joystick()
	elif event is InputEventScreenDrag:
		var ev := make_input_local(event) as InputEventScreenDrag
		if joy_active and ev.index == _touch_idx:
			_update_joy_at(ev.position)
	elif event is InputEventMouseButton:
		if event.device == InputEvent.DEVICE_ID_EMULATION:
			return
		var ev := make_input_local(event) as InputEventMouseButton
		if ev.button_index == MOUSE_BUTTON_LEFT:
			var pos := ev.position
			if ev.pressed:
				if _touch_idx == -1 and pos.y >= _playfield_min_y and pos.y <= _playfield_max_y and not _is_over_any_button(pos):
					_mouse_joy_active = true
					joy_active = true
					_joy_origin = pos
					_update_joy_at(pos)
			elif _mouse_joy_active:
				_reset_joystick()
	elif event is InputEventMouseMotion:
		if event.device == InputEvent.DEVICE_ID_EMULATION:
			return
		if _mouse_joy_active and joy_active:
			var ev := make_input_local(event) as InputEventMouseMotion
			_update_joy_at(ev.position)


func _process(delta: float):
	_pulse_t += delta
	if _r_ready and is_instance_valid(btn_r) and visible:
		var sc := 1.0 + 0.04 * sin(_pulse_t * 4.2)
		btn_r.scale = Vector2(sc, sc)
		btn_r.pivot_offset = btn_r.size * 0.5
	elif is_instance_valid(btn_r):
		btn_r.scale = Vector2.ONE


func update_state(hero_data: Dictionary, q_cd: float, e_cd: float, r_cd: float, dash_cd: float, cur_sp: float, auto_on: bool):
	_auto_is_on = auto_on
	var q_cost := int(hero_data.get("q_cost", 18))
	var e_cost := int(hero_data.get("e_cost", 32))
	var r_cost := int(hero_data.get("r_cost", 50))

	btn_q.text = "Q\n%.1fs" % q_cd if q_cd > 0.0 else ("Q\n%d" % q_cost)
	btn_q.modulate = Color(0.55, 0.55, 0.60, 0.85) if (q_cd > 0.0 or cur_sp < q_cost) else Color.WHITE

	btn_e.text = "E\n%.1fs" % e_cd if e_cd > 0.0 else ("E\n%d" % e_cost)
	btn_e.modulate = Color(0.55, 0.55, 0.60, 0.85) if (e_cd > 0.0 or cur_sp < e_cost) else Color.WHITE

	_r_ready = (r_cd <= 0.0 and cur_sp >= r_cost)
	btn_r.text = "★ R\n%.1fs" % r_cd if r_cd > 0.0 else ("★ R\n%d" % r_cost)
	btn_r.modulate = Color(0.58, 0.58, 0.62, 0.88) if not _r_ready else Color.WHITE

	btn_dash.text = "หลบ\n%.1fs" % dash_cd if dash_cd > 0.0 else "หลบ\nพร้อม"
	btn_dash.modulate = Color(0.55, 0.55, 0.60, 0.85) if dash_cd > 0.0 else Color.WHITE

	btn_auto.text = "⚡ ออโต้ ON" if auto_on else "⚡ ออโต้ OFF"
	var auto_flag := 1 if auto_on else 0
	if auto_flag != _last_styled_auto:
		_last_styled_auto = auto_flag
		var auto_bg := Color(0.04, 0.25, 0.19, 0.94) if auto_on else Color(0.06, 0.08, 0.13, 0.88)
		var auto_bd := Color("#34d399") if auto_on else Color("#64748b")
		_apply_btn_styles(btn_auto, auto_bg, auto_bd, 12, 2)
	queue_redraw()


func _draw():
	if not visible:
		return
	var alpha := 0.82 if joy_active else (0.35 if _auto_is_on else 0.58)
	var ring_col := Color(0.18, 0.83, 0.75, alpha * 0.45)
	var fill_col := Color(0.05, 0.11, 0.16, alpha * 0.42)
	var knob_col := Color(0.38, 0.88, 0.96, alpha)
	draw_circle(_joy_origin, JOY_MAX_RADIUS, fill_col)
	draw_arc(_joy_origin, JOY_MAX_RADIUS, 0.0, TAU, 36, ring_col, 2.5, true)
	draw_arc(_joy_origin, JOY_MAX_RADIUS * 0.55, 0.0, TAU, 28, Color(0.82, 0.68, 0.25, alpha * 0.35), 1.5, true)
	draw_circle(_joy_knob_pos, JOY_KNOB_RADIUS, knob_col)
	draw_arc(_joy_knob_pos, JOY_KNOB_RADIUS, 0.0, TAU, 24, Color(1.0, 1.0, 1.0, alpha * 0.85), 2.0, true)
