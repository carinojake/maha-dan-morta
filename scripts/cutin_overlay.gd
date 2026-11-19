extends Control

const CARD_W := 240.0
const CARD_H := 426.0
const TARGET_X := 18.0
const HIDDEN_X := -290.0
const CARD_Y := 142.0

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
	panel.position = Vector2(HIDDEN_X, CARD_Y)
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


func _exit_tree():
	_playing = false
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


func play(hid: String) -> bool:
	if not CUTINS.has(hid):
		return false
	var cfg: Dictionary = CUTINS[hid]
	var sheet_tex: Texture2D = _load_tex(str(cfg["sheet"]))
	if sheet_tex == null:
		return false

	_active_cfg = cfg
	var cols: int = int(cfg["cols"])
	var rows: int = int(cfg["rows"])
	var frames: int = int(cfg["frames"])
	var fps: float = float(cfg["fps"])
	_frame_w = float(sheet_tex.get_width()) / float(maxi(cols, 1))
	_frame_h = float(sheet_tex.get_height()) / float(maxi(rows, 1))
	_total_dur = float(frames) / maxf(fps, 1.0) + SLIDE_OUT_DUR

	_atlas_tex.atlas = sheet_tex
	_atlas_tex.region = Rect2(0.0, 0.0, _frame_w, _frame_h)
	tex_rect.texture = _atlas_tex

	var accent: Color = cfg.get("accent", Color("#38bdf8"))
	_panel_style.border_color = accent
	title_lbl.text = str(cfg["title"])
	sub_lbl.text = str(cfg["subtitle"])

	_elapsed = 0.0
	_playing = true
	panel.position = Vector2(HIDDEN_X, CARD_Y)
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
	if _elapsed >= _total_dur:
		_playing = false
		panel.visible = false
		panel.position = Vector2(HIDDEN_X, CARD_Y)
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
		panel.position = Vector2(lerpf(HIDDEN_X, TARGET_X, ease_in), CARD_Y)
		panel.modulate.a = ease_in
	elif _elapsed > hold_end:
		var t_out: float = clampf((_elapsed - hold_end) / SLIDE_OUT_DUR, 0.0, 1.0)
		var ease_out: float = t_out * t_out
		panel.position = Vector2(lerpf(TARGET_X, HIDDEN_X, ease_out), CARD_Y)
		panel.modulate.a = 1.0 - t_out
	else:
		panel.position = Vector2(TARGET_X, CARD_Y)
		panel.modulate.a = 1.0


func is_playing() -> bool:
	return _playing


func get_slowmo_scale() -> float:
	if _playing and _elapsed < SLOWMO_DUR:
		return SLOWMO_SCALE
	return 1.0


func get_card_panel() -> PanelContainer:
	return panel
