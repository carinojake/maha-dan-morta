extends Control

# Full-screen mode pauses combat in the host scene; the host releases the
# ultimate's damage only when this signal fires (natural end or tap-skip).
signal fullscreen_finished(hid: String)

const FULL_FADE_IN := 0.14
const FULL_HOLD := 0.30
const FULL_FADE_OUT := 0.22
# The tap that pressed [★ R] must not instantly skip the clip it just opened.
const FULL_SKIP_GUARD := 0.25

const CARD_W := 240.0
const CARD_H := 426.0
const SLIDE_IN_DUR := 0.16
const SLIDE_OUT_DUR := 0.22
const SLOWMO_DUR := 0.65
const SLOWMO_SCALE := 0.30

const CUTINS := {
	"bai_yueling": {
		"sheet": "res://assets/vfx/cutin_bai_yueling_r_sheet.jpg",
		"audio": "res://assets/vfx/cutin_bai_yueling_r.wav",
		"cols": 6,
		"rows": 5,
		"frames": 30,
		"fps": 18.0,
		"title": "★ แดนเหมันต์หมื่นกระบี่",
		"subtitle": "ไป๋เยว่หลิง · เซียนกระบี่เหมันต์",
		"accent": Color("#38bdf8"),
	},
	"hei_shan": {
		"sheet": "res://assets/vfx/cutin_hei_shan_r_sheet.jpg",
		"audio": "res://assets/vfx/cutin_hei_shan_r.wav",
		"cols": 6,
		"rows": 5,
		"frames": 30,
		"fps": 17.5,
		"title": "★ สวนสวรรค์ร้อยบุปผา",
		"subtitle": "เฮยซานเหล่ากุ่ย · เซียนพฤกษาจิ้งจอกเก้าหาง",
		"accent": Color("#fbbf24"),
	},
	"song_ren": {
		"sheet": "res://assets/vfx/cutin_song_ren_r_sheet.jpg",
		"audio": "res://assets/vfx/cutin_song_ren_r.wav",
		"cols": 6,
		"rows": 5,
		"frames": 30,
		"fps": 16.5,
		"title": "★ อัสนีบาตสวรรค์",
		"subtitle": "ซ่งเหริน · นักพรตยันต์แปดทิศ",
		"accent": Color("#22d3ee"),
	},
	"ye_shangye": {
		"sheet": "res://assets/vfx/cutin_ye_shangye_r_sheet.jpg",
		"audio": "res://assets/vfx/cutin_ye_shangye_r.wav",
		"cols": 6,
		"rows": 5,
		"frames": 30,
		"fps": 17.0,
		"title": "★ ราชันมารกลืนพิภพ",
		"subtitle": "เยี่ยซางเยี่ย · จอมมารโซ่โลหิต",
		"accent": Color("#a855f7"),
	},
	"chen_xi": {
		"sheet": "res://assets/vfx/cutin_chen_xi_r_sheet.jpg",
		"audio": "res://assets/vfx/cutin_chen_xi_r.wav",
		"cols": 6,
		"rows": 5,
		"frames": 30,
		"fps": 17.5,
		"title": "★ สังหารโลหิตสะบั้นฟ้า",
		"subtitle": "เฉินซี · กระบี่หักโลหิต",
		"accent": Color("#ef4444"),
	},
	"yu_han": {
		"sheet": "res://assets/vfx/cutin_yu_han_r_sheet.jpg",
		"audio": "res://assets/vfx/cutin_yu_han_r.wav",
		"cols": 6,
		"rows": 5,
		"frames": 30,
		"fps": 17.5,
		"title": "★ ทัณฑ์สวรรค์เก้าชั้นฟ้า",
		"subtitle": "อวี่หาน · เทพหอกอัสนีสุริยัน",
		"accent": Color("#fbbf24"),
	},
	"zhao_yan": {
		"sheet": "res://assets/vfx/cutin_zhao_yan_r_sheet.jpg",
		"audio": "res://assets/vfx/cutin_zhao_yan_r.wav",
		"cols": 6,
		"rows": 5,
		"frames": 30,
		"fps": 17.5,
		"title": "★ มหาเตาหลอมฟื้นกายา",
		"subtitle": "จ้าวเหยียน · ผู้อาวุโสเตาโอสถ",
		"accent": Color("#22c55e"),
	},
}

var panel: PanelContainer
var tex_rect: TextureRect
var caption_bg: ColorRect
var title_lbl: Label
var sub_lbl: Label
var audio_player: AudioStreamPlayer

var _panel_style: StyleBoxFlat
var _atlas_tex: AtlasTexture
var _sheet_cache: Dictionary = {}
var _audio_cache: Dictionary = {}

var _playing: bool = false
var _elapsed: float = 0.0
var _active_cfg: Dictionary = {}
var _frame_w: float = CARD_W
var _frame_h: float = CARD_H
var _total_dur: float = 1.8
var _target_x: float = 18.0
var _hidden_x: float = -290.0
var _card_y: float = 142.0

var full_root: Control
var full_bg_tex: TextureRect
var full_fg_tex: TextureRect
var full_caption: ColorRect
var full_accent_line: ColorRect
var full_title_lbl: Label
var full_sub_lbl: Label
var full_skip_lbl: Label
var _fullscreen: bool = false
var _active_hid: String = ""
var _top_safe: float = 0.0


func layout_for_viewport(vp: Vector2, top_safe: float):
	_target_x = vp.x - CARD_W - 16.0
	_hidden_x = vp.x + 24.0
	_card_y = top_safe + 150.0
	_top_safe = top_safe
	if is_instance_valid(full_skip_lbl):
		full_skip_lbl.offset_top = 18.0 + _top_safe
		full_skip_lbl.offset_bottom = 50.0 + _top_safe
	if is_instance_valid(panel) and not _playing:
		panel.position = Vector2(_hidden_x, _card_y)


func _ready():
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	_panel_style = StyleBoxFlat.new()
	_panel_style.bg_color = Color("#08111f")
	_panel_style.border_color = Color("#38bdf8")
	_panel_style.set_border_width_all(2)
	_panel_style.set_corner_radius_all(10)
	_panel_style.set_content_margin_all(5)
	_panel_style.shadow_color = Color(0.0, 0.0, 0.0, 0.65)
	_panel_style.shadow_size = 10

	panel = PanelContainer.new()
	panel.position = Vector2(_hidden_x, _card_y)
	panel.visible = false
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_theme_stylebox_override("panel", _panel_style)
	add_child(panel)

	var frame_wrap := Control.new()
	frame_wrap.custom_minimum_size = Vector2(CARD_W, CARD_H)
	frame_wrap.clip_contents = true
	frame_wrap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(frame_wrap)

	_atlas_tex = AtlasTexture.new()

	tex_rect = TextureRect.new()
	tex_rect.position = Vector2.ZERO
	tex_rect.size = Vector2(CARD_W, CARD_H)
	tex_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tex_rect.stretch_mode = TextureRect.STRETCH_SCALE
	tex_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tex_rect.texture = _atlas_tex
	frame_wrap.add_child(tex_rect)

	caption_bg = ColorRect.new()
	caption_bg.color = Color(0.03, 0.06, 0.12, 0.84)
	caption_bg.position = Vector2(0.0, CARD_H - 52.0)
	caption_bg.size = Vector2(CARD_W, 52.0)
	caption_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame_wrap.add_child(caption_bg)

	var cap_vb := VBoxContainer.new()
	cap_vb.set_anchors_preset(Control.PRESET_FULL_RECT)
	cap_vb.alignment = BoxContainer.ALIGNMENT_CENTER
	cap_vb.add_theme_constant_override("separation", 2)
	cap_vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	caption_bg.add_child(cap_vb)

	title_lbl = Label.new()
	title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_lbl.add_theme_font_size_override("font_size", 14)
	title_lbl.add_theme_color_override("font_color", Color("#fde047"))
	title_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cap_vb.add_child(title_lbl)

	sub_lbl = Label.new()
	sub_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub_lbl.add_theme_font_size_override("font_size", 10)
	sub_lbl.add_theme_color_override("font_color", Color("#bae6fd"))
	sub_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cap_vb.add_child(sub_lbl)

	audio_player = AudioStreamPlayer.new()
	audio_player.volume_db = -4.0
	add_child(audio_player)

	_build_fullscreen()


func _build_fullscreen():
	full_root = Control.new()
	full_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	full_root.mouse_filter = Control.MOUSE_FILTER_STOP
	full_root.clip_contents = true
	full_root.visible = false
	full_root.gui_input.connect(_on_full_gui_input)
	add_child(full_root)

	var backdrop := ColorRect.new()
	backdrop.color = Color(0.0, 0.0, 0.0, 0.96)
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	full_root.add_child(backdrop)

	# Blurred-looking cover layer fills whatever the 9:16 clip does not cover
	# (iPad landscape / tall iPhone), so there are never hard black bars.
	full_bg_tex = TextureRect.new()
	full_bg_tex.set_anchors_preset(Control.PRESET_FULL_RECT)
	full_bg_tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	full_bg_tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	full_bg_tex.modulate = Color(0.34, 0.34, 0.42, 1.0)
	full_bg_tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
	full_bg_tex.texture = _atlas_tex
	full_root.add_child(full_bg_tex)

	full_fg_tex = TextureRect.new()
	full_fg_tex.set_anchors_preset(Control.PRESET_FULL_RECT)
	full_fg_tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	full_fg_tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	full_fg_tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
	full_fg_tex.texture = _atlas_tex
	full_root.add_child(full_fg_tex)

	full_caption = ColorRect.new()
	full_caption.color = Color(0.02, 0.04, 0.09, 0.84)
	full_caption.anchor_left = 0.0
	full_caption.anchor_right = 1.0
	full_caption.anchor_top = 1.0
	full_caption.anchor_bottom = 1.0
	full_caption.offset_top = -150.0
	full_caption.offset_bottom = -40.0
	full_caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	full_root.add_child(full_caption)

	full_accent_line = ColorRect.new()
	full_accent_line.anchor_right = 1.0
	full_accent_line.offset_bottom = 3.0
	full_accent_line.color = Color("#38bdf8")
	full_accent_line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	full_caption.add_child(full_accent_line)

	var cap_vb := VBoxContainer.new()
	cap_vb.set_anchors_preset(Control.PRESET_FULL_RECT)
	cap_vb.alignment = BoxContainer.ALIGNMENT_CENTER
	cap_vb.add_theme_constant_override("separation", 4)
	cap_vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	full_caption.add_child(cap_vb)

	full_title_lbl = Label.new()
	full_title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	full_title_lbl.add_theme_font_size_override("font_size", 34)
	full_title_lbl.add_theme_color_override("font_color", Color("#fde047"))
	full_title_lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	full_title_lbl.add_theme_constant_override("outline_size", 6)
	full_title_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cap_vb.add_child(full_title_lbl)

	full_sub_lbl = Label.new()
	full_sub_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	full_sub_lbl.add_theme_font_size_override("font_size", 17)
	full_sub_lbl.add_theme_color_override("font_color", Color("#e0f2fe"))
	full_sub_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cap_vb.add_child(full_sub_lbl)

	full_skip_lbl = Label.new()
	full_skip_lbl.text = "แตะจอเพื่อข้าม ▶▶"
	full_skip_lbl.anchor_left = 1.0
	full_skip_lbl.anchor_right = 1.0
	full_skip_lbl.offset_left = -230.0
	full_skip_lbl.offset_right = -20.0
	full_skip_lbl.offset_top = 18.0 + _top_safe
	full_skip_lbl.offset_bottom = 50.0 + _top_safe
	full_skip_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	full_skip_lbl.add_theme_font_size_override("font_size", 16)
	full_skip_lbl.add_theme_color_override("font_color", Color(1, 1, 1, 0.85))
	full_skip_lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	full_skip_lbl.add_theme_constant_override("outline_size", 4)
	full_skip_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	full_root.add_child(full_skip_lbl)


func _on_full_gui_input(event: InputEvent):
	if not (_playing and _fullscreen) or _elapsed < FULL_SKIP_GUARD:
		return
	var tapped: bool = (event is InputEventScreenTouch and event.pressed) or (event is InputEventMouseButton and event.pressed)
	if tapped:
		accept_event()
		skip()


func _input(event: InputEvent):
	if not (_playing and _fullscreen) or _elapsed < FULL_SKIP_GUARD:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode in [KEY_ENTER, KEY_KP_ENTER, KEY_SPACE, KEY_ESCAPE]:
			get_viewport().set_input_as_handled()
			skip()


func _exit_tree():
	_playing = false
	_fullscreen = false
	if is_instance_valid(audio_player):
		audio_player.stop()
		audio_player.stream = null
	if is_instance_valid(tex_rect):
		tex_rect.texture = null
	_atlas_tex = null
	_sheet_cache.clear()
	_audio_cache.clear()


func _load_tex(res_path: String) -> Texture2D:
	if _sheet_cache.has(res_path):
		return _sheet_cache[res_path]
	var tex: Texture2D = null
	if ResourceLoader.exists(res_path):
		var loaded: Resource = load(res_path)
		if loaded is Texture2D:
			tex = loaded
	if tex == null:
		var abs_path: String = ProjectSettings.globalize_path(res_path)
		if FileAccess.file_exists(abs_path):
			var img := Image.load_from_file(abs_path)
			if img != null and not img.is_empty():
				tex = ImageTexture.create_from_image(img)
	if tex != null:
		_sheet_cache[res_path] = tex
	return tex


func _load_audio(res_path: String) -> AudioStream:
	if _audio_cache.has(res_path):
		return _audio_cache[res_path]
	var stream: AudioStream = null
	if ResourceLoader.exists(res_path):
		var loaded: Resource = load(res_path)
		if loaded is AudioStream:
			stream = loaded
	if stream != null:
		_audio_cache[res_path] = stream
	return stream


func has_cutin(hid: String) -> bool:
	return CUTINS.has(hid)


func play(hid: String, fullscreen: bool = false) -> bool:
	if not CUTINS.has(hid):
		return false
	var cfg: Dictionary = CUTINS[hid]
	var sheet_tex: Texture2D = _load_tex(str(cfg["sheet"]))
	if sheet_tex == null:
		return false

	_active_cfg = cfg
	_active_hid = hid
	_fullscreen = fullscreen
	var cols: int = int(cfg["cols"])
	var rows: int = int(cfg["rows"])
	var frames: int = int(cfg["frames"])
	var fps: float = float(cfg["fps"])
	_frame_w = float(sheet_tex.get_width()) / float(maxi(cols, 1))
	_frame_h = float(sheet_tex.get_height()) / float(maxi(rows, 1))
	var anim_dur: float = float(frames) / maxf(fps, 1.0)
	_total_dur = anim_dur + (FULL_HOLD if fullscreen else SLIDE_OUT_DUR)

	_atlas_tex.atlas = sheet_tex
	_atlas_tex.region = Rect2(0.0, 0.0, _frame_w, _frame_h)
	tex_rect.texture = _atlas_tex

	var accent: Color = cfg.get("accent", Color("#38bdf8"))
	_panel_style.border_color = accent
	title_lbl.text = str(cfg["title"])
	sub_lbl.text = str(cfg["subtitle"])

	_elapsed = 0.0
	_playing = true
	if fullscreen:
		panel.visible = false
		full_accent_line.color = accent
		full_title_lbl.text = str(cfg["title"])
		full_sub_lbl.text = str(cfg["subtitle"])
		full_root.modulate.a = 0.0
		full_root.visible = true
		_fit_full_root()
		move_to_front()
	else:
		full_root.visible = false
		panel.position = Vector2(_hidden_x, _card_y)
		panel.modulate.a = 0.0
		panel.visible = true

	var sfx_stream: AudioStream = _load_audio(str(cfg.get("audio", "")))
	if sfx_stream != null and is_instance_valid(audio_player):
		audio_player.stop()
		audio_player.stream = sfx_stream
		audio_player.play()
	return true


func tick(real_delta: float) -> void:
	if not _playing:
		return
	_elapsed += real_delta
	if _fullscreen:
		_tick_fullscreen()
		return
	if _elapsed >= _total_dur:
		_playing = false
		panel.visible = false
		panel.position = Vector2(_hidden_x, _card_y)
		panel.modulate.a = 0.0
		if is_instance_valid(audio_player):
			audio_player.stop()
		return

	var cols: int = int(_active_cfg.get("cols", 6))
	var frames: int = int(_active_cfg.get("frames", 30))
	var fps: float = float(_active_cfg.get("fps", 18.0))
	var idx: int = clampi(int(_elapsed * fps), 0, frames - 1)
	var col_i: int = idx % cols
	var row_i: int = int(idx / cols)
	_atlas_tex.region = Rect2(float(col_i) * _frame_w, float(row_i) * _frame_h, _frame_w, _frame_h)

	var hold_end: float = _total_dur - SLIDE_OUT_DUR
	if _elapsed < SLIDE_IN_DUR:
		var t_in: float = clampf(_elapsed / SLIDE_IN_DUR, 0.0, 1.0)
		var ease_in: float = 1.0 - pow(1.0 - t_in, 3.0)
		panel.position = Vector2(lerpf(_hidden_x, _target_x, ease_in), _card_y)
		panel.modulate.a = ease_in
	elif _elapsed > hold_end:
		var t_out: float = clampf((_elapsed - hold_end) / SLIDE_OUT_DUR, 0.0, 1.0)
		var ease_out: float = t_out * t_out
		panel.position = Vector2(lerpf(_target_x, _hidden_x, ease_out), _card_y)
		panel.modulate.a = 1.0 - t_out
	else:
		panel.position = Vector2(_target_x, _card_y)
		panel.modulate.a = 1.0


func _set_frame_for_elapsed():
	var cols: int = int(_active_cfg.get("cols", 6))
	var frames: int = int(_active_cfg.get("frames", 30))
	var fps: float = float(_active_cfg.get("fps", 18.0))
	var idx: int = clampi(int(_elapsed * fps), 0, frames - 1)
	_atlas_tex.region = Rect2(float(idx % cols) * _frame_w, float(int(idx / cols)) * _frame_h, _frame_w, _frame_h)


func _fit_full_root():
	# Parent is a CanvasLayer, so anchors have no rect to resolve against;
	# pin to the live viewport (also follows iPhone/iPad rotation mid-clip).
	var vp_size: Vector2 = get_viewport_rect().size
	position = Vector2.ZERO
	size = vp_size
	full_root.position = Vector2.ZERO
	full_root.size = vp_size


func _tick_fullscreen():
	_fit_full_root()
	if _elapsed >= _total_dur:
		_finish_fullscreen()
		return
	_set_frame_for_elapsed()
	var fade_out_start: float = _total_dur - FULL_FADE_OUT
	var alpha: float = 1.0
	if _elapsed < FULL_FADE_IN:
		alpha = clampf(_elapsed / FULL_FADE_IN, 0.0, 1.0)
	elif _elapsed > fade_out_start:
		alpha = 1.0 - clampf((_elapsed - fade_out_start) / FULL_FADE_OUT, 0.0, 1.0)
	full_root.modulate.a = alpha
	# Small zoom-punch on entry sells the impact of the clip.
	var punch: float = 1.0 + 0.08 * (1.0 - clampf(_elapsed / 0.35, 0.0, 1.0))
	full_fg_tex.pivot_offset = full_fg_tex.size * 0.5
	full_fg_tex.scale = Vector2(punch, punch)
	full_skip_lbl.visible = _elapsed >= FULL_SKIP_GUARD


func _finish_fullscreen():
	var hid := _active_hid
	_playing = false
	_fullscreen = false
	full_root.visible = false
	full_root.modulate.a = 0.0
	full_fg_tex.scale = Vector2.ONE
	if is_instance_valid(audio_player):
		audio_player.stop()
	fullscreen_finished.emit(hid)


func skip() -> void:
	if _playing and _fullscreen:
		_finish_fullscreen()


func is_fullscreen_playing() -> bool:
	return _playing and _fullscreen


func get_full_root() -> Control:
	return full_root


func is_playing() -> bool:
	return _playing


func get_slowmo_scale() -> float:
	if _playing and not _fullscreen and _elapsed < SLOWMO_DUR:
		return SLOWMO_SCALE
	return 1.0


func get_card_panel() -> PanelContainer:
	return panel
