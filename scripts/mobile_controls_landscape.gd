extends Control

signal attack_pressed
signal skill_q_pressed
signal skill_e_pressed
signal skill_r_pressed
signal dash_pressed
signal auto_toggled
signal speed_toggled
signal codex_pressed

const JOY_MAX_RADIUS := 64.0
const JOY_KNOB_RADIUS := 26.0
const JOY_DEADZONE := 8.0

var joy_vector: Vector2 = Vector2.ZERO
var joy_active: bool = false

var btn_q: Button
var btn_e: Button
var btn_r: Button
var btn_dash: Button
var btn_attack: Button
var btn_auto: Button
var btn_speed: Button
var btn_codex: Button

var _active: bool = true
var _auto_is_on: bool = true
var _last_styled_auto: int = -1
var _last_styled_fast: int = -1
var _touch_idx: int = -1
var _mouse_joy_active: bool = false
var _idle_joy_anchor: Vector2 = Vector2(120.0, 600.0)
var _joy_origin: Vector2 = _idle_joy_anchor
var _joy_knob_pos: Vector2 = _idle_joy_anchor
var _pulse_t: float = 0.0
var _r_ready: bool = true
var _mirrored: bool = false
var _last_vp: Vector2 = Vector2(1280.0, 720.0)
var _buttons: Array[Button] = []
var _attack_held: bool = false
var _attack_hold_timer: float = 0.0


func _ready():
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	btn_attack = _make_circle_btn("⚔️\nตี", Vector2.ZERO, Vector2(76.0, 76.0), Color("#f87171"), Color(0.32, 0.08, 0.09, 0.94), 14)
	btn_attack.button_down.connect(func():
		_attack_held = true
		_attack_hold_timer = 0.0
		attack_pressed.emit()
	)
	btn_attack.button_up.connect(func(): _attack_held = false)

	btn_dash = _make_circle_btn("หลบ\nพร้อม", Vector2.ZERO, Vector2(68.0, 68.0), Color("#2dd4bf"), Color(0.04, 0.18, 0.18, 0.92), 11)
	btn_dash.button_down.connect(func(): dash_pressed.emit())

	btn_q = _make_circle_btn("Q\n18", Vector2.ZERO, Vector2(64.0, 64.0), Color("#38bdf8"), Color(0.04, 0.14, 0.24, 0.92), 12)
	btn_q.button_down.connect(func(): skill_q_pressed.emit())

	btn_e = _make_circle_btn("E\n32", Vector2.ZERO, Vector2(66.0, 66.0), Color("#c084fc"), Color(0.16, 0.06, 0.26, 0.92), 12)
	btn_e.button_down.connect(func(): skill_e_pressed.emit())

	btn_r = _make_circle_btn("★ R\n50", Vector2.ZERO, Vector2(76.0, 76.0), Color("#facc15"), Color(0.24, 0.16, 0.04, 0.95), 13)
	btn_r.button_down.connect(func(): skill_r_pressed.emit())

	btn_auto = _make_pill_btn("⚡ ออโต้ ON", Vector2.ZERO, Vector2(100.0, 40.0), Color("#34d399"), 11)
	btn_auto.pressed.connect(func(): auto_toggled.emit())

	btn_speed = _make_pill_btn("⏩ 1.0×", Vector2.ZERO, Vector2(84.0, 40.0), Color("#fbbf24"), 12)
	btn_speed.pressed.connect(func(): speed_toggled.emit())

	btn_codex = _make_pill_btn("📜 คัมภีร์", Vector2.ZERO, Vector2(96.0, 40.0), Color("#38bdf8"), 11)
	btn_codex.pressed.connect(func(): codex_pressed.emit())

	_buttons = [btn_attack, btn_dash, btn_q, btn_e, btn_r, btn_auto, btn_speed, btn_codex]
	layout_for_viewport(Vector2(1280.0, 720.0))


func set_mirrored(mirrored: bool):
	if _mirrored == mirrored:
		return
	_mirrored = mirrored
	layout_for_viewport(_last_vp)


func layout_for_viewport(vp: Vector2):
	_last_vp = vp
	var w := maxf(vp.x, 960.0)
	var h := maxf(vp.y, 540.0)
	var center_x := w * 0.5
	var util_y := h - 52.0

	if not _mirrored:
		# One-handed Left-Thumb Ergonomic Mode ("มือซ้ายข้างเดียว"): all buttons inside x <= 600
		_idle_joy_anchor = Vector2(355.0, h - 142.0)
		btn_attack.position = Vector2(18.0, h - 98.0)
		btn_dash.position = Vector2(104.0, h - 86.0)
		btn_q.position = Vector2(180.0, h - 86.0)
		btn_e.position = Vector2(148.0, h - 170.0)
		btn_r.position = Vector2(52.0, h - 194.0)
		btn_auto.position = Vector2(282.0, util_y)
		btn_speed.position = Vector2(390.0, util_y)
		btn_codex.position = Vector2(482.0, util_y)
	else:
		# Two-handed Dual-Thumb Mode ("สลับ 2 มือ (ขวา)"): joystick left, skills right
		_idle_joy_anchor = Vector2(120.0, h - 120.0)
		btn_attack.position = Vector2(w - 92.0, h - 92.0)
		btn_dash.position = Vector2(w - 176.0, h - 80.0)
		btn_q.position = Vector2(w - 248.0, h - 80.0)
		btn_e.position = Vector2(w - 216.0, h - 165.0)
		btn_r.position = Vector2(w - 130.0, h - 188.0)
		btn_auto.position = Vector2(center_x - 146.0, util_y)
		btn_speed.position = Vector2(center_x - 40.0, util_y)
		btn_codex.position = Vector2(center_x + 50.0, util_y)

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
	_apply_btn_styles(b, Color(0.06, 0.09, 0.15, 0.92), border_col, 10, 2)
	add_child(b)
	return b


func _apply_btn_styles(b: Button, bg_col: Color, border_col: Color, radius: int, border_w: int):
	var normal := StyleBoxFlat.new()
	normal.bg_color = bg_col
	normal.border_color = border_col
	normal.set_border_width_all(border_w)
	normal.set_corner_radius_all(radius)

	var pressed := normal.duplicate()
	pressed.bg_color = bg_col.lightened(0.28)
	pressed.border_color = Color.WHITE

	b.add_theme_stylebox_override("normal", normal)
	b.add_theme_stylebox_override("hover", normal)
	b.add_theme_stylebox_override("pressed", pressed)


func set_active(enabled: bool):
	_active = enabled
	if not enabled:
		reset_joystick()


func reset_joystick():
	_touch_idx = -1
	_mouse_joy_active = false
	joy_active = false
	joy_vector = Vector2.ZERO
	_joy_origin = _idle_joy_anchor
	_joy_knob_pos = _idle_joy_anchor
	_attack_held = false
	queue_redraw()


func _is_in_joy_zone(pos: Vector2) -> bool:
	var vp_w := _last_vp.x
	var vp_h := _last_vp.y
	if not _mirrored:
		# In one-handed left mode, floating joystick activates anywhere in left/center open space not covered by buttons
		return pos.x >= 0.0 and pos.x <= vp_w * 0.58 and pos.y >= 90.0 and pos.y <= vp_h
	else:
		return pos.x >= 0.0 and pos.x <= vp_w * 0.46 and pos.y >= 90.0 and pos.y <= vp_h


func _is_over_any_button(pos: Vector2) -> bool:
	for b in _buttons:
		if is_instance_valid(b) and b.visible and b.get_global_rect().grow(8.0).has_point(pos):
			return true
	return false


func _update_joy_at(pos: Vector2):
	var diff := pos - _joy_origin
	var len_val := diff.length()
	if len_val > JOY_MAX_RADIUS and len_val > 0.001:
		diff = (diff / len_val) * JOY_MAX_RADIUS
	_joy_knob_pos = _joy_origin + diff
	joy_vector = (diff / JOY_MAX_RADIUS) if len_val > JOY_DEADZONE else Vector2.ZERO
	queue_redraw()


func _input(event: InputEvent):
	if not _active or not visible:
		return

	if event is InputEventScreenTouch:
		var ev := make_input_local(event) as InputEventScreenTouch
		var pos := ev.position
		if ev.pressed:
			if _touch_idx == -1 and _is_in_joy_zone(pos) and not _is_over_any_button(pos):
				_touch_idx = ev.index
				joy_active = true
				_joy_origin = pos
				_update_joy_at(pos)
		else:
			if ev.index == _touch_idx:
				reset_joystick()

	elif event is InputEventScreenDrag:
		var ev := make_input_local(event) as InputEventScreenDrag
		if joy_active and ev.index == _touch_idx:
			_update_joy_at(ev.position)

	elif event is InputEventMouseButton:
		var ev := make_input_local(event) as InputEventMouseButton
		if ev.button_index == MOUSE_BUTTON_LEFT:
			var pos := ev.position
			if ev.pressed:
				if _touch_idx == -1 and _is_in_joy_zone(pos) and not _is_over_any_button(pos):
					_mouse_joy_active = true
					joy_active = true
					_joy_origin = pos
					_update_joy_at(pos)
			else:
				if _mouse_joy_active:
					reset_joystick()

	elif event is InputEventMouseMotion:
		if _mouse_joy_active and joy_active:
			var ev := make_input_local(event) as InputEventMouseMotion
			_update_joy_at(ev.position)


func _notification(what: int):
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_PAUSED:
		reset_joystick()


func _process(delta: float):
	_pulse_t += delta

	if _attack_held:
		_attack_hold_timer += delta
		if _attack_hold_timer >= 0.22:
			_attack_hold_timer = 0.0
			attack_pressed.emit()

	if _r_ready and is_instance_valid(btn_r) and visible:
		var sc := 1.0 + 0.045 * sin(_pulse_t * 4.2)
		btn_r.scale = Vector2(sc, sc)
		btn_r.pivot_offset = btn_r.size * 0.5
	elif is_instance_valid(btn_r):
		btn_r.scale = Vector2.ONE


func update_state(hero_data: Dictionary, q_cd: float, e_cd: float, r_cd: float, dash_cd: float, cur_sp: float, auto_on: bool, speed_mult: float = 1.0):
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
		_apply_btn_styles(btn_auto, auto_bg, auto_bd, 10, 2)

	var is_fast := speed_mult >= 1.25
	btn_speed.text = "⏩ 1.5×" if is_fast else "⏩ 1.0×"
	var fast_flag := 1 if is_fast else 0
	if fast_flag != _last_styled_fast:
		_last_styled_fast = fast_flag
		var spd_bg := Color(0.24, 0.16, 0.04, 0.94) if is_fast else Color(0.06, 0.08, 0.13, 0.88)
		var spd_bd := Color("#fbbf24") if is_fast else Color("#64748b")
		_apply_btn_styles(btn_speed, spd_bg, spd_bd, 10, 2)
	queue_redraw()


func _draw():
	if not visible:
		return
	var alpha := 0.85 if joy_active else (0.32 if _auto_is_on else 0.52)
	var ring_col := Color(0.18, 0.83, 0.75, alpha * 0.45)
	var fill_col := Color(0.05, 0.11, 0.16, alpha * 0.42)
	var knob_col := Color(0.38, 0.88, 0.96, alpha)

	draw_circle(_joy_origin, JOY_MAX_RADIUS, fill_col)
	draw_arc(_joy_origin, JOY_MAX_RADIUS, 0.0, TAU, 36, ring_col, 2.5, true)
	draw_arc(_joy_origin, JOY_MAX_RADIUS * 0.55, 0.0, TAU, 28, Color(0.82, 0.68, 0.25, alpha * 0.35), 1.5, true)
	draw_circle(_joy_knob_pos, JOY_KNOB_RADIUS, knob_col)
	draw_arc(_joy_knob_pos, JOY_KNOB_RADIUS, 0.0, TAU, 24, Color(1.0, 1.0, 1.0, alpha * 0.85), 2.0, true)
