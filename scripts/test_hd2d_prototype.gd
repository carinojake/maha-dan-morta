extends Node3D

const HeroData = preload("res://scripts/hero_data.gd")
const MobileControlsScript = preload("res://scripts/mobile_controls_landscape.gd")

const TILE_M := 2.0
const ROOM_W := 12
const ROOM_H := 8
const ENEMY_BAR_OFFSET := Vector3(0.0, 3.15, 0.0)
const WALK_FPS := 9.0

enum AnimState { IDLE, WALK, DASH, ATTACK }

var world_env: WorldEnvironment
var fx_enabled: bool = true

var player: CharacterBody3D
var player_sprite: Sprite3D
var player_shadow: MeshInstance3D
var player_ring: Sprite3D
var player_slash_aura: Sprite3D

var camera_rig: Node3D
var camera: Camera3D

var enemy: CharacterBody3D
var enemy_sprite: Sprite3D
var enemy_shadow: MeshInstance3D
var enemy_hp: float = 300.0
var enemy_max_hp: float = 300.0
var _enemy_base_pos := Vector3(3.3, 0.0, 0.35)
var _enemy_hit_timer: float = 0.0

var hud_layer: CanvasLayer
var mobile_controls: Control
var help_label: Label
var watermark_label: Label
var fps_label: Label
var fx_toggle_btn: Button
var hero_switch_btn: Button
var enemy_bar_root: Control
var enemy_bar_fill: ColorRect
var enemy_hp_label: Label

var active_hero_idx: int = 0
var active_hero_id: String = "bai_yueling"
var _hero_textures: Dictionary = {}
var _hero_walk_textures: Dictionary = {}
var _hero_attack_textures: Dictionary = {}

var anim_state: int = AnimState.IDLE
var walk_frame_timer: float = 0.0
var _attack_lunge_offset: Vector3 = Vector3.ZERO
var _afterimages: Array[Dictionary] = []

var hero_z: float = 0.0
var hero_z_vel: float = 0.0
var dash_timer: float = 0.0
var dash_dir: Vector3 = Vector3.RIGHT
var facing_dir: Vector3 = Vector3.RIGHT
var _anim_time: float = 0.0
var _attack_pose_timer: float = 0.0

var _tex_bai_idle: Texture2D
var _tex_bai_attack: Texture2D
var _tex_ye_idle: Texture2D
var _tex_slash_crescent: Texture2D
var _tex_domain_ring: Texture2D

var _corner_flames: Array[Sprite3D] = []
var _active_vfx: Array[Dictionary] = []
var _floating_texts: Array[Dictionary] = []


func _ready() -> void:
	_preload_textures()
	_build_environment()
	_build_room_geometry()
	_build_room_props_and_lights()
	_build_player()
	_build_camera()
	_build_dummy_enemy()
	_build_hud()
	set_hero(HeroData.HERO_ORDER[active_hero_idx])
	_on_viewport_resized()
	get_viewport().size_changed.connect(_on_viewport_resized)
	_update_hud(0.0)


func _preload_textures() -> void:
	for hid in HeroData.HERO_ORDER:
		var hd_idle_path := "res://assets/hd2d/%s_hd_idle.png" % hid
		var fallback_path := "res://assets/heroes/%s/stride_0.png" % hid
		var idle_tex: Texture2D = null
		if ResourceLoader.exists(hd_idle_path):
			idle_tex = load(hd_idle_path)
		elif ResourceLoader.exists(fallback_path):
			idle_tex = load(fallback_path)
		_hero_textures[hid] = idle_tex

		var hd_walk_path := "res://assets/hd2d/%s_hd_walk.png" % hid
		if ResourceLoader.exists(hd_walk_path):
			_hero_walk_textures[hid] = load(hd_walk_path)
		else:
			_hero_walk_textures[hid] = idle_tex

		var hd_atk_path := "res://assets/hd2d/%s_hd_attack.png" % hid
		if ResourceLoader.exists(hd_atk_path):
			_hero_attack_textures[hid] = load(hd_atk_path)
		else:
			_hero_attack_textures[hid] = idle_tex

	_tex_bai_idle = _hero_textures.get("bai_yueling", null)
	_tex_bai_attack = _hero_attack_textures.get("bai_yueling", _tex_bai_idle)

	if ResourceLoader.exists("res://assets/hd2d/ye_shangye_hd_idle.png"):
		_tex_ye_idle = load("res://assets/hd2d/ye_shangye_hd_idle.png")
	else:
		_tex_ye_idle = load("res://assets/monsters/jade_golem.png")

	if ResourceLoader.exists("res://assets/hd2d/slash_crescent_cyan.png"):
		_tex_slash_crescent = load("res://assets/hd2d/slash_crescent_cyan.png")
	else:
		_tex_slash_crescent = load("res://assets/vfx/vfx_slash_ice_sword.png")

	if ResourceLoader.exists("res://assets/hd2d/domain_ring_cyan.png"):
		_tex_domain_ring = load("res://assets/hd2d/domain_ring_cyan.png")
	else:
		_tex_domain_ring = load("res://assets/vfx/vfx_ice_domain.png")


func _build_environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("#080d14")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("#46627f")
	env.ambient_light_energy = 0.92
	env.fog_enabled = fx_enabled
	env.fog_light_color = Color("#122230")
	env.fog_density = 0.014
	env.glow_enabled = fx_enabled
	env.glow_intensity = 0.85
	env.glow_bloom = 0.22

	world_env = WorldEnvironment.new()
	world_env.name = "WorldEnvironment"
	world_env.environment = env
	add_child(world_env)

	var dir_light := DirectionalLight3D.new()
	dir_light.name = "DirectionalLight3D"
	dir_light.rotation_degrees = Vector3(-52.0, -28.0, 0.0)
	dir_light.light_color = Color("#c8e2ff")
	dir_light.light_energy = 1.05
	dir_light.shadow_enabled = true
	add_child(dir_light)


func _build_room_geometry() -> void:
	var half_w := (ROOM_W * TILE_M) * 0.5
	var half_h := (ROOM_H * TILE_M) * 0.5

	var floor_tex_path := "res://assets/hd2d/floor_slate_hd.png"
	if not ResourceLoader.exists(floor_tex_path):
		floor_tex_path = "res://assets/env/floor_slate.png"

	var floor_mesh := PlaneMesh.new()
	floor_mesh.size = Vector2(TILE_M, TILE_M)
	var floor_mat := StandardMaterial3D.new()
	floor_mat.albedo_texture = load(floor_tex_path)
	floor_mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	floor_mat.roughness = 0.88
	floor_mesh.material = floor_mat

	var floor_mm := MultiMesh.new()
	floor_mm.transform_format = MultiMesh.TRANSFORM_3D
	floor_mm.mesh = floor_mesh
	floor_mm.instance_count = ROOM_W * ROOM_H

	var idx := 0
	for gz in range(ROOM_H):
		for gx in range(ROOM_W):
			var px := -half_w + (gx + 0.5) * TILE_M
			var pz := -half_h + (gz + 0.5) * TILE_M
			floor_mm.set_instance_transform(idx, Transform3D(Basis.IDENTITY, Vector3(px, 0.0, pz)))
			idx += 1

	var floor_mmi := MultiMeshInstance3D.new()
	floor_mmi.name = "FloorMultiMesh"
	floor_mmi.multimesh = floor_mm
	add_child(floor_mmi)

	# Perimeter walls (with front doorway gap in bottom wall matching reference image)
	var wall_positions: Array[Vector3] = []
	var wall_heights: Array[float] = []
	var back_wall_h := TILE_M * 1.85
	var front_wall_h := TILE_M * 0.65

	for gx in range(-1, ROOM_W + 1):
		var px := -half_w + (gx + 0.5) * TILE_M
		wall_positions.append(Vector3(px, back_wall_h * 0.5, -half_h - TILE_M * 0.5))
		wall_heights.append(back_wall_h)
		if gx < 4 or gx > 7:
			wall_positions.append(Vector3(px, front_wall_h * 0.5, half_h + TILE_M * 0.5))
			wall_heights.append(front_wall_h)

	for gz in range(ROOM_H):
		var pz := -half_h + (gz + 0.5) * TILE_M
		wall_positions.append(Vector3(-half_w - TILE_M * 0.5, back_wall_h * 0.5, pz))
		wall_heights.append(back_wall_h)
		wall_positions.append(Vector3(half_w + TILE_M * 0.5, back_wall_h * 0.5, pz))
		wall_heights.append(back_wall_h)

	var wall_tex_path := "res://assets/hd2d/wall_stone_hd.png"
	if not ResourceLoader.exists(wall_tex_path):
		wall_tex_path = "res://assets/env/wall_stone.png"

	var wall_mesh := BoxMesh.new()
	wall_mesh.size = Vector3(TILE_M, 1.0, TILE_M)
	var wall_mat := StandardMaterial3D.new()
	wall_mat.albedo_texture = load(wall_tex_path)
	wall_mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	wall_mat.roughness = 0.85
	wall_mesh.material = wall_mat

	var wall_mm := MultiMesh.new()
	wall_mm.transform_format = MultiMesh.TRANSFORM_3D
	wall_mm.mesh = wall_mesh
	wall_mm.instance_count = wall_positions.size()
	for i in range(wall_positions.size()):
		var b := Basis.IDENTITY.scaled(Vector3(1.0, wall_heights[i], 1.0))
		wall_mm.set_instance_transform(i, Transform3D(b, wall_positions[i]))

	var wall_mmi := MultiMeshInstance3D.new()
	wall_mmi.name = "WallMultiMesh"
	wall_mmi.multimesh = wall_mm
	add_child(wall_mmi)

	var static_body := StaticBody3D.new()
	static_body.name = "RoomColliders"
	add_child(static_body)

	_add_box_collider(static_body, Vector3(ROOM_W * TILE_M + 4.0, 0.4, ROOM_H * TILE_M + 4.0), Vector3(0.0, -0.2, 0.0))
	_add_box_collider(static_body, Vector3(ROOM_W * TILE_M + 4.0, back_wall_h, TILE_M), Vector3(0.0, back_wall_h * 0.5, -half_h - TILE_M * 0.5))
	_add_box_collider(static_body, Vector3(ROOM_W * TILE_M + 4.0, back_wall_h, TILE_M), Vector3(0.0, back_wall_h * 0.5, half_h + TILE_M * 0.5))
	_add_box_collider(static_body, Vector3(TILE_M, back_wall_h, ROOM_H * TILE_M), Vector3(-half_w - TILE_M * 0.5, back_wall_h * 0.5, 0.0))
	_add_box_collider(static_body, Vector3(TILE_M, back_wall_h, ROOM_H * TILE_M), Vector3(half_w + TILE_M * 0.5, back_wall_h * 0.5, 0.0))


func _add_box_collider(parent: StaticBody3D, box_size: Vector3, pos: Vector3) -> void:
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = box_size
	col.shape = shape
	col.position = pos
	parent.add_child(col)


func _make_additive_decal_material(tex: Texture2D, tint: Color = Color.WHITE) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_texture = tex
	mat.albedo_color = tint
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	return mat


func _build_room_props_and_lights() -> void:
	var bagua_path := "res://assets/hd2d/bagua_neon_cyan.png"
	if not ResourceLoader.exists(bagua_path):
		bagua_path = "res://assets/env/prop_bagua_floor.png"
	var bagua_tex: Texture2D = load(bagua_path)

	var bagua := Sprite3D.new()
	bagua.name = "BaguaFloor"
	bagua.texture = bagua_tex
	bagua.pixel_size = 5.4 / maxf(float(bagua_tex.get_width()), 1.0)
	bagua.rotation_degrees.x = -90.0
	bagua.position = Vector3(0.0, 0.015, 0.55)
	bagua.material_override = _make_additive_decal_material(bagua_tex, Color(0.6, 0.98, 1.0, 0.92))
	add_child(bagua)

	var half_w := (ROOM_W * TILE_M) * 0.5 - 1.55
	var half_h := (ROOM_H * TILE_M) * 0.5 - 1.45
	var corners := [
		Vector3(-half_w, 0.0, -half_h),
		Vector3(half_w, 0.0, -half_h),
		Vector3(-half_w, 0.0, half_h),
		Vector3(half_w, 0.0, half_h),
	]

	var pedestal_mesh := BoxMesh.new()
	pedestal_mesh.size = Vector3(0.95, 0.42, 0.95)
	var ped_mat := StandardMaterial3D.new()
	ped_mat.albedo_color = Color("#1d2b38")
	ped_mat.roughness = 0.85
	pedestal_mesh.material = ped_mat

	var flame_tex: Texture2D = null
	if ResourceLoader.exists("res://assets/hd2d/cyan_flame.png"):
		flame_tex = load("res://assets/hd2d/cyan_flame.png")

	for i in range(corners.size()):
		var cpos: Vector3 = corners[i]

		var ped := MeshInstance3D.new()
		ped.name = "CornerBrazier_%d" % i
		ped.mesh = pedestal_mesh
		ped.position = cpos + Vector3(0.0, 0.21, 0.0)
		add_child(ped)

		if flame_tex != null:
			var flame := Sprite3D.new()
			flame.name = "CornerFlame_%d" % i
			flame.texture = flame_tex
			flame.pixel_size = 0.011
			flame.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
			flame.position = cpos + Vector3(0.0, 0.82, 0.0)
			flame.material_override = _make_additive_decal_material(flame_tex, Color(0.65, 1.0, 1.0, 0.96))
			add_child(flame)
			_corner_flames.append(flame)

		var omni := OmniLight3D.new()
		omni.name = "CornerLight_%d" % i
		omni.position = cpos + Vector3(0.0, 1.25, 0.0)
		omni.light_color = Color("#24ecff")
		omni.light_energy = 2.15
		omni.omni_range = 9.0
		omni.shadow_enabled = false
		add_child(omni)


func _create_blob_shadow(radius: float = 1.6) -> MeshInstance3D:
	var quad := QuadMesh.new()
	quad.size = Vector2(radius, radius * 0.62)
	var mat := StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(0.0, 0.0, 0.0, 0.56)
	if ResourceLoader.exists("res://assets/env/light_radial.png"):
		mat.albedo_texture = load("res://assets/env/light_radial.png")
	quad.material = mat

	var shadow := MeshInstance3D.new()
	shadow.name = "BlobShadow"
	shadow.mesh = quad
	shadow.rotation_degrees.x = -90.0
	shadow.position = Vector3(0.0, 0.02, 0.0)
	return shadow


func _build_player() -> void:
	player = CharacterBody3D.new()
	player.name = "Player3D"
	player.position = Vector3(-3.3, 0.0, 0.55)
	add_child(player)

	var col := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.5
	cap.height = 2.4
	col.shape = cap
	col.position = Vector3(0.0, 1.2, 0.0)
	player.add_child(col)

	player_shadow = _create_blob_shadow(1.85)
	player.add_child(player_shadow)

	player_ring = Sprite3D.new()
	player_ring.name = "HeroDomainRing3D"
	player_ring.texture = _tex_domain_ring
	var ring_w := float(_tex_domain_ring.get_width()) if _tex_domain_ring else 512.0
	player_ring.pixel_size = 3.9 / maxf(ring_w, 1.0)
	player_ring.rotation_degrees.x = -90.0
	player_ring.position = Vector3(0.0, 0.026, 0.15)
	player_ring.material_override = _make_additive_decal_material(_tex_domain_ring, Color(0.55, 0.98, 1.0, 0.92))
	player.add_child(player_ring)

	player_sprite = Sprite3D.new()
	player_sprite.name = "HeroSprite3D"
	player_sprite.texture = _tex_bai_idle
	var tex_h := float(_tex_bai_idle.get_height()) if _tex_bai_idle else 548.0
	player_sprite.pixel_size = 3.25 / maxf(tex_h, 1.0)
	player_sprite.offset = Vector2(0.0, tex_h * 0.49)
	player_sprite.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	player_sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	player_sprite.alpha_scissor_threshold = 0.35
	player_sprite.shaded = true
	player_sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	player.add_child(player_sprite)

	player_slash_aura = Sprite3D.new()
	player_slash_aura.name = "HeroSlashAura3D"
	player_slash_aura.texture = _tex_slash_crescent
	var slash_h := float(_tex_slash_crescent.get_height()) if _tex_slash_crescent else 512.0
	player_slash_aura.pixel_size = 2.85 / maxf(slash_h, 1.0)
	player_slash_aura.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	player_slash_aura.position = Vector3(0.85, 1.55, 0.08)
	player_slash_aura.material_override = _make_additive_decal_material(_tex_slash_crescent, Color(0.75, 1.0, 1.0, 0.92))
	player.add_child(player_slash_aura)


func _build_camera() -> void:
	camera_rig = Node3D.new()
	camera_rig.name = "CameraRig"
	camera_rig.top_level = true
	add_child(camera_rig)
	camera_rig.global_position = Vector3(0.0, 0.0, 0.25)

	camera = Camera3D.new()
	camera.name = "Camera3D"
	camera.fov = 40.0
	camera.position = Vector3(0.0, 11.0, 13.8)
	camera.rotation_degrees.x = -38.0
	camera.current = true
	camera_rig.add_child(camera)


func _build_dummy_enemy() -> void:
	enemy = CharacterBody3D.new()
	enemy.name = "DummyEnemy3D"
	enemy.position = _enemy_base_pos
	add_child(enemy)

	var col := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.6
	cap.height = 2.5
	col.shape = cap
	col.position = Vector3(0.0, 1.25, 0.0)
	enemy.add_child(col)

	enemy_shadow = _create_blob_shadow(2.15)
	enemy.add_child(enemy_shadow)

	enemy_sprite = Sprite3D.new()
	enemy_sprite.name = "EnemySprite3D"
	enemy_sprite.texture = _tex_ye_idle
	var tex_h := float(_tex_ye_idle.get_height()) if _tex_ye_idle else 568.0
	enemy_sprite.pixel_size = 3.35 / maxf(tex_h, 1.0)
	enemy_sprite.offset = Vector2(0.0, tex_h * 0.49)
	enemy_sprite.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	enemy_sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	enemy_sprite.alpha_scissor_threshold = 0.35
	enemy_sprite.shaded = true
	enemy_sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	enemy.add_child(enemy_sprite)


func _style_hud_pill_button(btn: Button, border_col: Color) -> void:
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.05, 0.08, 0.13, 0.90)
	normal.border_color = border_col
	normal.set_border_width_all(2)
	normal.set_corner_radius_all(10)

	var pressed := normal.duplicate()
	pressed.bg_color = normal.bg_color.lightened(0.22)
	pressed.border_color = Color.WHITE

	btn.add_theme_stylebox_override("normal", normal)
	btn.add_theme_stylebox_override("hover", normal)
	btn.add_theme_stylebox_override("pressed", pressed)


func _build_hud() -> void:
	hud_layer = CanvasLayer.new()
	hud_layer.name = "HudOverlay3D"
	add_child(hud_layer)

	mobile_controls = MobileControlsScript.new()
	mobile_controls.name = "MobileControls"
	hud_layer.add_child(mobile_controls)
	if is_instance_valid(mobile_controls.btn_auto):
		mobile_controls.btn_auto.visible = false
	if is_instance_valid(mobile_controls.btn_speed):
		mobile_controls.btn_speed.visible = false
	if is_instance_valid(mobile_controls.btn_codex):
		mobile_controls.btn_codex.visible = false

	mobile_controls.attack_pressed.connect(trigger_slash)
	mobile_controls.skill_q_pressed.connect(trigger_slash)
	mobile_controls.dash_pressed.connect(trigger_dash)
	mobile_controls.skill_e_pressed.connect(trigger_domain)
	mobile_controls.skill_r_pressed.connect(trigger_burst)

	var cmd_bar := Control.new()
	cmd_bar.name = "CommandBar"
	cmd_bar.position = Vector2(18.0, 18.0)
	cmd_bar.size = Vector2(690.0, 44.0)
	hud_layer.add_child(cmd_bar)

	var cmd_bg := ColorRect.new()
	cmd_bg.color = Color(0.04, 0.06, 0.09, 0.84)
	cmd_bg.size = Vector2(690.0, 44.0)
	cmd_bar.add_child(cmd_bg)

	var gold_strip := ColorRect.new()
	gold_strip.color = Color("#f5b82e")
	gold_strip.size = Vector2(4.0, 44.0)
	cmd_bar.add_child(gold_strip)

	var rich_help := RichTextLabel.new()
	rich_help.name = "RichHelpLabel"
	rich_help.bbcode_enabled = true
	rich_help.scroll_active = false
	rich_help.position = Vector2(16.0, 8.0)
	rich_help.size = Vector2(668.0, 32.0)
	rich_help.add_theme_font_size_override("normal_font_size", 19)
	rich_help.text = "[color=#f6c444][WASD][/color] [color=#eef6ff]Move[/color] [color=#6c7f93]|[/color] [color=#f6c444][Space][/color] [color=#eef6ff]Dash[/color] [color=#6c7f93]|[/color] [color=#f6c444][F][/color] [color=#eef6ff]Slash[/color] [color=#6c7f93]|[/color] [color=#f6c444][E][/color] [color=#eef6ff]Domain[/color] [color=#6c7f93]|[/color] [color=#f6c444][Tab][/color] [color=#eef6ff]Hero[/color]"
	cmd_bar.add_child(rich_help)

	help_label = Label.new()
	help_label.name = "HelpLabel"
	help_label.text = "[WASD] Move | [Space] Dash | [F] Slash | [E] Domain | [Tab] Hero"
	help_label.visible = false
	cmd_bar.add_child(help_label)

	watermark_label = Label.new()
	watermark_label.name = "WatermarkLabel"
	watermark_label.text = "test_hd2d_prototype"
	watermark_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	watermark_label.position = Vector2(1040.0, 12.0)
	watermark_label.size = Vector2(220.0, 24.0)
	watermark_label.add_theme_font_size_override("font_size", 16)
	watermark_label.modulate = Color(0.62, 0.72, 0.82, 0.65)
	hud_layer.add_child(watermark_label)

	fps_label = Label.new()
	fps_label.name = "FpsLabel"
	fps_label.text = "FPS: 60"
	fps_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	fps_label.position = Vector2(1040.0, 34.0)
	fps_label.size = Vector2(220.0, 24.0)
	fps_label.add_theme_font_size_override("font_size", 16)
	fps_label.modulate = Color(0.62, 0.72, 0.82, 0.65)
	hud_layer.add_child(fps_label)

	fx_toggle_btn = Button.new()
	fx_toggle_btn.name = "FxToggleButton"
	fx_toggle_btn.text = "FX: Glow+Fog"
	fx_toggle_btn.position = Vector2(1060.0, 62.0)
	fx_toggle_btn.size = Vector2(200.0, 34.0)
	fx_toggle_btn.custom_minimum_size = Vector2(200.0, 34.0)
	fx_toggle_btn.focus_mode = Control.FOCUS_NONE
	fx_toggle_btn.add_theme_font_size_override("font_size", 14)
	fx_toggle_btn.add_theme_color_override("font_color", Color("#e2f1ff"))
	_style_hud_pill_button(fx_toggle_btn, Color("#38bdf8"))
	fx_toggle_btn.pressed.connect(toggle_fx)
	hud_layer.add_child(fx_toggle_btn)

	hero_switch_btn = Button.new()
	hero_switch_btn.name = "HeroSwitchButton"
	hero_switch_btn.text = "Hero: ไป๋เยว่หลิง"
	hero_switch_btn.position = Vector2(1060.0, 102.0)
	hero_switch_btn.size = Vector2(200.0, 34.0)
	hero_switch_btn.custom_minimum_size = Vector2(200.0, 34.0)
	hero_switch_btn.focus_mode = Control.FOCUS_NONE
	hero_switch_btn.add_theme_font_size_override("font_size", 14)
	hero_switch_btn.add_theme_color_override("font_color", Color("#fef08a"))
	_style_hud_pill_button(hero_switch_btn, Color("#facc15"))
	hero_switch_btn.pressed.connect(cycle_hero)
	hud_layer.add_child(hero_switch_btn)

	enemy_bar_root = Control.new()
	enemy_bar_root.name = "EnemyBarRoot"
	enemy_bar_root.size = Vector2(132.0, 18.0)
	hud_layer.add_child(enemy_bar_root)

	var border_rect := ColorRect.new()
	border_rect.color = Color(0.55, 0.62, 0.70, 0.92)
	border_rect.size = Vector2(132.0, 18.0)
	enemy_bar_root.add_child(border_rect)

	var inner_bg := ColorRect.new()
	inner_bg.color = Color(0.12, 0.15, 0.19, 0.96)
	inner_bg.position = Vector2(2.0, 2.0)
	inner_bg.size = Vector2(128.0, 14.0)
	enemy_bar_root.add_child(inner_bg)

	enemy_bar_fill = ColorRect.new()
	enemy_bar_fill.name = "EnemyBarFill"
	enemy_bar_fill.color = Color("#e62e2d")
	enemy_bar_fill.position = Vector2(3.0, 3.0)
	enemy_bar_fill.size = Vector2(108.0, 12.0)
	enemy_bar_root.add_child(enemy_bar_fill)

	enemy_hp_label = Label.new()
	enemy_hp_label.name = "EnemyHpLabel"
	enemy_hp_label.visible = false
	enemy_bar_root.add_child(enemy_hp_label)

	enemy_hp = 238.0
	_spawn_floating_damage(62, enemy.global_position + Vector3(-0.35, 2.05, 0.0), 3.5)


func _on_viewport_resized() -> void:
	if not is_inside_tree():
		return
	var vp := get_viewport().get_visible_rect().size
	if is_instance_valid(mobile_controls):
		mobile_controls.layout_for_viewport(vp)
		var hdata: Dictionary = HeroData.HEROES.get(active_hero_id, HeroData.HEROES["bai_yueling"])
		mobile_controls.update_state(hdata, 0.0, 0.0, 0.0, 0.0, 120.0, false, 1.0)

	var right_x := maxf(vp.x, 1280.0) - 240.0
	var btn_x := maxf(vp.x, 1280.0) - 220.0
	if is_instance_valid(watermark_label):
		watermark_label.position.x = right_x
	if is_instance_valid(fps_label):
		fps_label.position.x = right_x
	if is_instance_valid(fx_toggle_btn):
		fx_toggle_btn.position.x = btn_x
	if is_instance_valid(hero_switch_btn):
		hero_switch_btn.position.x = btn_x


func toggle_fx() -> void:
	fx_enabled = not fx_enabled
	if is_instance_valid(world_env) and world_env.environment != null:
		world_env.environment.glow_enabled = fx_enabled
		world_env.environment.fog_enabled = fx_enabled
	if is_instance_valid(fx_toggle_btn):
		fx_toggle_btn.text = "FX: Glow+Fog" if fx_enabled else "FX: OFF"
		_style_hud_pill_button(fx_toggle_btn, Color("#38bdf8") if fx_enabled else Color("#64748b"))


func cycle_hero() -> void:
	active_hero_idx = (active_hero_idx + 1) % HeroData.HERO_ORDER.size()
	set_hero(HeroData.HERO_ORDER[active_hero_idx])


func _apply_sprite_texture(tex: Texture2D, hframes_count: int = 1, frame_idx: int = 0) -> void:
	if not is_instance_valid(player_sprite) or tex == null:
		return
	player_sprite.texture = tex
	player_sprite.hframes = hframes_count
	player_sprite.vframes = 1
	player_sprite.frame = clampi(frame_idx, 0, max(0, hframes_count - 1))
	var tex_h := float(tex.get_height())
	player_sprite.pixel_size = 3.25 / maxf(tex_h, 1.0)
	player_sprite.offset = Vector2(0.0, tex_h * 0.49)
	_apply_hero_facing()


func set_hero(hero_id: String) -> void:
	if not HeroData.HEROES.has(hero_id):
		return
	active_hero_id = hero_id
	var idx := HeroData.HERO_ORDER.find(hero_id)
	if idx >= 0:
		active_hero_idx = idx

	var hdata: Dictionary = HeroData.HEROES[hero_id]
	var hcolor: Color = hdata.get("color", Color("#38bdf8"))
	var idle_tex: Texture2D = _hero_textures.get(hero_id, _tex_bai_idle)

	_attack_pose_timer = 0.0
	_attack_lunge_offset = Vector3.ZERO
	anim_state = AnimState.IDLE
	_apply_sprite_texture(idle_tex, 1, 0)

	var ring_tint := hcolor.lightened(0.28)
	ring_tint.a = 0.92
	if is_instance_valid(player_ring) and player_ring.material_override is StandardMaterial3D:
		(player_ring.material_override as StandardMaterial3D).albedo_color = ring_tint

	var aura_tint := hcolor.lightened(0.42)
	aura_tint.a = 0.92
	if is_instance_valid(player_slash_aura) and player_slash_aura.material_override is StandardMaterial3D:
		(player_slash_aura.material_override as StandardMaterial3D).albedo_color = aura_tint

	if is_instance_valid(hero_switch_btn):
		hero_switch_btn.text = "Hero: %s" % String(hdata.get("name", hero_id))
		_style_hud_pill_button(hero_switch_btn, hcolor)

	if is_instance_valid(mobile_controls):
		mobile_controls.update_state(hdata, 0.0, 0.0, 0.0, 0.0, 120.0, false, 1.0)


func _apply_hero_facing() -> void:
	if not is_instance_valid(player_sprite):
		return
	# ye_shangye_hd_idle.png faces 3/4 left by default; all walk/attack sheets & other heroes face 3/4 right
	var is_ye_idle: bool = (active_hero_id == "ye_shangye" and player_sprite.texture == _hero_textures.get("ye_shangye"))
	var want_left: bool = (facing_dir.x < 0.0)
	player_sprite.flip_h = (want_left != is_ye_idle)
	if is_instance_valid(player_slash_aura):
		player_slash_aura.flip_h = want_left
		player_slash_aura.position.x = -0.85 if want_left else 0.85


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		var key_event := event as InputEventKey
		if key_event.keycode == KEY_SPACE:
			trigger_dash()
		elif key_event.keycode == KEY_F:
			trigger_slash()
		elif key_event.keycode == KEY_E:
			trigger_domain()
		elif key_event.keycode == KEY_TAB:
			cycle_hero()


func trigger_dash(custom_dir: Vector3 = Vector3.ZERO) -> void:
	if custom_dir.length_squared() > 0.001:
		dash_dir = custom_dir.normalized()
	elif facing_dir.length_squared() > 0.001:
		dash_dir = facing_dir.normalized()
	else:
		dash_dir = Vector3.RIGHT
	dash_timer = 0.24
	hero_z_vel = 5.2
	hero_z = maxf(hero_z, 0.08)
	anim_state = AnimState.DASH
	_spawn_dash_afterimages()


func _spawn_dash_afterimages() -> void:
	if not is_instance_valid(player) or not is_instance_valid(player_sprite):
		return
	var hdata: Dictionary = HeroData.HEROES.get(active_hero_id, {})
	var hcolor: Color = hdata.get("color", Color("#38bdf8")).lightened(0.32)

	for i in range(3):
		var ghost := Sprite3D.new()
		ghost.name = "DashAfterimage_%d" % i
		ghost.texture = player_sprite.texture
		ghost.hframes = player_sprite.hframes
		ghost.vframes = player_sprite.vframes
		ghost.frame = player_sprite.frame
		ghost.pixel_size = player_sprite.pixel_size
		ghost.offset = player_sprite.offset
		ghost.flip_h = player_sprite.flip_h
		ghost.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
		ghost.shaded = false
		ghost.alpha_cut = SpriteBase3D.ALPHA_CUT_DISABLED

		var init_alpha := 0.58 - float(i) * 0.12
		var mat := StandardMaterial3D.new()
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.albedo_texture = player_sprite.texture
		mat.albedo_color = Color(hcolor.r, hcolor.g, hcolor.b, init_alpha)
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		ghost.material_override = mat

		var trail_offset := -dash_dir * (float(i) * 0.42)
		ghost.position = player.global_position + trail_offset + Vector3(0.0, hero_z, -0.04 * float(i + 1))
		add_child(ghost)
		_afterimages.append({
			"node": ghost,
			"mat": mat,
			"time": 0.0,
			"duration": 0.22,
			"init_alpha": init_alpha,
		})


func _current_hero_vfx_color(lighten_amount: float = 0.35, alpha_val: float = 0.96) -> Color:
	var hdata: Dictionary = HeroData.HEROES.get(active_hero_id, {})
	var base_col: Color = hdata.get("color", Color("#38bdf8"))
	var c := base_col.lightened(lighten_amount)
	c.a = alpha_val
	return c


func trigger_slash() -> void:
	_attack_pose_timer = 0.34
	anim_state = AnimState.ATTACK
	var atk_tex: Texture2D = _hero_attack_textures.get(active_hero_id, _hero_textures.get(active_hero_id, _tex_bai_attack))
	_apply_sprite_texture(atk_tex, 1, 0)
	_attack_lunge_offset = facing_dir.normalized() * 0.45
	if is_instance_valid(player_sprite):
		player_sprite.position.x = _attack_lunge_offset.x
		player_sprite.position.z = _attack_lunge_offset.z

	var slash := Sprite3D.new()
	slash.name = "SlashVFX3D"
	slash.texture = _tex_slash_crescent
	var sh := float(_tex_slash_crescent.get_height()) if _tex_slash_crescent else 512.0
	slash.pixel_size = 3.1 / maxf(sh, 1.0)
	slash.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	slash.flip_h = facing_dir.x < 0.0
	slash.position = player.global_position + facing_dir.normalized() * 1.45 + Vector3(0.0, 1.55 + hero_z, 0.1)
	slash.material_override = _make_additive_decal_material(_tex_slash_crescent, _current_hero_vfx_color(0.45, 0.98))
	add_child(slash)
	_active_vfx.append({"node": slash, "time": 0.0, "duration": 0.32, "spin": 0.0, "vel": facing_dir.normalized() * 3.8})

	if is_instance_valid(enemy):
		var dist := player.global_position.distance_to(enemy.global_position)
		if dist <= 8.0:
			_apply_enemy_damage(62.0)


func trigger_domain() -> void:
	var domain := Sprite3D.new()
	domain.name = "IceDomainVFX3D"
	domain.texture = _tex_domain_ring
	var tex_w := float(_tex_domain_ring.get_width()) if _tex_domain_ring else 512.0
	domain.pixel_size = 4.6 / maxf(tex_w, 1.0)
	domain.rotation_degrees.x = -90.0
	domain.position = Vector3(player.global_position.x, 0.03, player.global_position.z)
	domain.material_override = _make_additive_decal_material(_tex_domain_ring, _current_hero_vfx_color(0.30, 0.95))

	add_child(domain)
	_active_vfx.append({"node": domain, "time": 0.0, "duration": 1.6, "spin": 1.8})


func trigger_burst() -> void:
	trigger_domain()
	trigger_slash()


func _apply_enemy_damage(dmg: float) -> void:
	enemy_hp -= dmg
	if enemy_hp <= 30.0:
		enemy_hp = enemy_max_hp
	_enemy_hit_timer = 0.22
	_spawn_floating_damage(int(dmg), enemy.global_position + Vector3(-0.35, 2.05, 0.0), 0.85)


func _spawn_floating_damage(amount: int, world_pos: Vector3, duration: float = 0.85) -> void:
	var lbl := Label.new()
	lbl.text = "★ %d!" % amount
	lbl.add_theme_font_size_override("font_size", 34)
	lbl.add_theme_color_override("font_color", Color("#ffdf4a"))
	lbl.add_theme_color_override("font_outline_color", Color(0.08, 0.05, 0.02, 0.95))
	lbl.add_theme_constant_override("outline_size", 7)
	hud_layer.add_child(lbl)
	_floating_texts.append({
		"node": lbl,
		"world_pos": world_pos,
		"time": 0.0,
		"duration": duration,
	})
	_update_hud(0.0)


func _physics_process(delta: float) -> void:
	_anim_time += delta

	var input_vec := Vector2.ZERO
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		input_vec.x -= 1.0
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		input_vec.x += 1.0
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
		input_vec.y -= 1.0
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
		input_vec.y += 1.0

	if is_instance_valid(mobile_controls) and mobile_controls.joy_vector.length_squared() > 0.01:
		input_vec = mobile_controls.joy_vector

	var move_dir := Vector3(input_vec.x, 0.0, input_vec.y)
	if move_dir.length_squared() > 0.001:
		move_dir = move_dir.normalized()
		facing_dir = move_dir
		if absf(move_dir.x) > 0.05:
			_apply_hero_facing()

	var speed := 6.5
	if dash_timer > 0.0:
		dash_timer = maxf(0.0, dash_timer - delta)
		player.velocity.x = dash_dir.x * 14.5
		player.velocity.z = dash_dir.z * 14.5
	else:
		player.velocity.x = move_dir.x * speed
		player.velocity.z = move_dir.z * speed

	player.velocity.y = 0.0
	player.move_and_slide()
	player.position.y = 0.0

	var horiz_speed := Vector2(player.velocity.x, player.velocity.z).length()

	# Animation State Machine: ATTACK -> DASH -> WALK -> IDLE
	if _attack_pose_timer > 0.0:
		_attack_pose_timer = maxf(0.0, _attack_pose_timer - delta)
		anim_state = AnimState.ATTACK
		var atk_prog := 1.0 - (_attack_pose_timer / 0.34)
		var lunge_mag := 0.45 * sin(clampf(atk_prog, 0.0, 1.0) * PI)
		_attack_lunge_offset = facing_dir.normalized() * lunge_mag
		if _attack_pose_timer <= 0.0:
			_attack_lunge_offset = Vector3.ZERO
	elif dash_timer > 0.0:
		anim_state = AnimState.DASH
		_attack_lunge_offset = Vector3.ZERO
	elif horiz_speed > 0.2:
		var walk_tex: Texture2D = _hero_walk_textures.get(active_hero_id, _hero_textures.get(active_hero_id))
		var hcount := 4 if (walk_tex != null and walk_tex.get_width() > walk_tex.get_height() * 1.6) else 1
		if anim_state != AnimState.WALK or player_sprite.texture != walk_tex:
			anim_state = AnimState.WALK
			_apply_sprite_texture(walk_tex, hcount, int(walk_frame_timer) % max(1, hcount))
		walk_frame_timer += delta * WALK_FPS
		player_sprite.frame = int(walk_frame_timer) % max(1, player_sprite.hframes)
		_attack_lunge_offset = Vector3.ZERO
	else:
		var idle_tex: Texture2D = _hero_textures.get(active_hero_id, _tex_bai_idle)
		if anim_state != AnimState.IDLE or player_sprite.texture != idle_tex:
			anim_state = AnimState.IDLE
			_apply_sprite_texture(idle_tex, 1, 0)
		_attack_lunge_offset = Vector3.ZERO

	# Vertical hop / dash float + State-specific Procedural Motion (Tilt, Bounce, Squash & Stretch, Lunge)
	if hero_z > 0.0 or hero_z_vel != 0.0:
		hero_z += hero_z_vel * delta
		hero_z_vel -= 18.0 * delta
		if hero_z <= 0.0:
			hero_z = 0.0
			hero_z_vel = 0.0

	var breath_bob := sin(_anim_time * 3.2) * 0.045
	var step_bounce := 0.0
	var target_tilt_z := 0.0
	var target_scale := Vector3.ONE

	if anim_state == AnimState.WALK:
		step_bounce = absf(sin(walk_frame_timer * PI * 0.5)) * 0.09
		var dir_sign := -1.0 if facing_dir.x < 0.0 else 1.0
		target_tilt_z = -7.0 * dir_sign * clampf(horiz_speed / speed, 0.2, 1.0)
		var sq := sin(walk_frame_timer * PI) * 0.04
		target_scale = Vector3(1.0 - sq * 0.5, 1.0 + sq, 1.0)
	elif anim_state == AnimState.ATTACK:
		var dir_sign := -1.0 if facing_dir.x < 0.0 else 1.0
		target_tilt_z = -5.0 * dir_sign
		target_scale = Vector3(1.04, 0.97, 1.0)

	if is_instance_valid(player_sprite):
		player_sprite.position.x = _attack_lunge_offset.x
		player_sprite.position.z = _attack_lunge_offset.z
		player_sprite.position.y = hero_z + maxf(0.0, breath_bob) + step_bounce
		player_sprite.rotation_degrees.z = lerpf(player_sprite.rotation_degrees.z, target_tilt_z, clampf(delta * 14.0, 0.0, 1.0))
		player_sprite.scale = player_sprite.scale.lerp(target_scale, clampf(delta * 16.0, 0.0, 1.0))

	var shadow_scale := clampf(1.0 - hero_z * 0.35, 0.55, 1.0)
	player_shadow.scale = Vector3(shadow_scale, 1.0, shadow_scale)

	if is_instance_valid(player_ring):
		var ring_pulse := 1.0 + sin(_anim_time * 2.8) * 0.03
		player_ring.scale = Vector3(ring_pulse, ring_pulse, ring_pulse)
	if is_instance_valid(player_slash_aura):
		var aura_bob := sin(_anim_time * 4.0) * 0.06
		player_slash_aura.position.y = 1.55 + hero_z + aura_bob

	if is_instance_valid(enemy) and is_instance_valid(enemy_sprite):
		var enemy_breath := sin(_anim_time * 2.6 + 1.2) * 0.04
		enemy_sprite.position.y = maxf(0.0, enemy_breath)
		if _enemy_hit_timer > 0.0:
			_enemy_hit_timer = maxf(0.0, _enemy_hit_timer - delta)
			enemy_sprite.modulate = Color(1.6, 0.85, 0.9, 1.0)
			enemy_sprite.position.x = sin(_enemy_hit_timer * 65.0) * 0.14
		else:
			enemy_sprite.modulate = Color.WHITE
			enemy_sprite.position.x = 0.0

	for i in range(_corner_flames.size()):
		var fl := _corner_flames[i]
		if is_instance_valid(fl):
			var s := 1.0 + sin(_anim_time * 7.5 + float(i) * 1.7) * 0.09
			fl.scale = Vector3(s, 1.0 + (s - 1.0) * 1.4, 1.0)

	if is_instance_valid(camera_rig) and is_instance_valid(player):
		var target_cam := player.global_position * 0.35 + Vector3(0.0, 0.0, 0.25)
		camera_rig.global_position = camera_rig.global_position.lerp(target_cam, clampf(delta * 6.0, 0.0, 1.0))

	_update_afterimages(delta)
	_update_vfx(delta)
	_update_hud(delta)


func _update_afterimages(delta: float) -> void:
	for i in range(_afterimages.size() - 1, -1, -1):
		var item: Dictionary = _afterimages[i]
		item["time"] = float(item["time"]) + delta
		var t: float = float(item["time"])
		var dur: float = float(item["duration"])
		var node: Sprite3D = item["node"]
		if not is_instance_valid(node) or t >= dur:
			if is_instance_valid(node):
				node.queue_free()
			_afterimages.remove_at(i)
			continue
		var mat: StandardMaterial3D = item["mat"]
		var init_a: float = float(item["init_alpha"])
		if mat != null:
			mat.albedo_color.a = init_a * clampf(1.0 - (t / dur), 0.0, 1.0)


func _update_vfx(delta: float) -> void:
	for i in range(_active_vfx.size() - 1, -1, -1):
		var item: Dictionary = _active_vfx[i]
		item["time"] = float(item["time"]) + delta
		var t: float = float(item["time"])
		var dur: float = float(item["duration"])
		var node: Node3D = item["node"]
		if not is_instance_valid(node) or t >= dur:
			if is_instance_valid(node):
				node.queue_free()
			_active_vfx.remove_at(i)
			continue
		var spin: float = float(item.get("spin", 0.0))
		if spin != 0.0:
			node.rotate_y(spin * delta)
		if item.has("vel"):
			var v: Vector3 = item["vel"]
			node.global_position += v * delta


func _update_hud(delta: float) -> void:
	if is_instance_valid(fps_label):
		var fps := Engine.get_frames_per_second()
		fps_label.text = "FPS: %d" % (int(fps) if fps > 0 else 60)

	if is_instance_valid(camera) and is_instance_valid(enemy) and is_instance_valid(enemy_bar_root):
		var head_world := enemy.global_position + ENEMY_BAR_OFFSET
		if not camera.is_position_behind(head_world):
			var screen_pos := camera.unproject_position(head_world)
			enemy_bar_root.visible = true
			enemy_bar_root.position = screen_pos - Vector2(66.0, 24.0)
		else:
			enemy_bar_root.visible = false

		var ratio := clampf(enemy_hp / maxf(enemy_max_hp, 1.0), 0.0, 1.0)
		enemy_bar_fill.size.x = 126.0 * ratio
		enemy_hp_label.text = "Ye Shangye %d/%d" % [int(round(enemy_hp)), int(round(enemy_max_hp))]

	for i in range(_floating_texts.size() - 1, -1, -1):
		var item: Dictionary = _floating_texts[i]
		item["time"] = float(item["time"]) + delta
		var t: float = float(item["time"])
		var dur: float = float(item["duration"])
		var lbl: Label = item["node"]
		if not is_instance_valid(lbl) or t >= dur:
			if is_instance_valid(lbl):
				lbl.queue_free()
			_floating_texts.remove_at(i)
			continue
		var float_y := minf(t, 0.35) * 0.65
		var wpos: Vector3 = item["world_pos"] + Vector3(0.0, float_y, 0.0)
		if is_instance_valid(camera) and not camera.is_position_behind(wpos):
			lbl.position = camera.unproject_position(wpos) - Vector2(54.0, 18.0)
			if t > dur - 0.25:
				lbl.modulate.a = clampf((dur - t) / 0.25, 0.0, 1.0)
