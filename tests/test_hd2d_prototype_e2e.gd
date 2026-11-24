extends SceneTree

const HeroData = preload("res://scripts/hero_data.gd")

var _tick: int = 0
var _scene: Node3D


func _initialize() -> void:
	var packed := load("res://scenes/test_hd2d_prototype.tscn") as PackedScene
	assert(packed != null, "scenes/test_hd2d_prototype.tscn must load cleanly")
	_scene = packed.instantiate() as Node3D
	assert(_scene != null, "TestHd2dPrototype root must be Node3D")
	root.add_child(_scene)


func _process(delta: float) -> bool:
	_tick += 1
	if _tick == 2:
		# Verify core HD-2D nodes exist
		assert(_scene.player != null and _scene.player is CharacterBody3D, "Player3D must exist")
		assert(_scene.player_sprite != null and _scene.player_sprite is Sprite3D, "HeroSprite3D must exist")
		assert(_scene.camera != null and _scene.camera is Camera3D, "Camera3D must exist")
		assert(is_equal_approx(_scene.camera.fov, 40.0), "Camera3D FOV must be 40.0")
		assert(_scene.enemy != null and _scene.enemy is CharacterBody3D, "DummyEnemy3D must exist")
		assert(_scene.enemy_bar_root != null, "enemy_bar_root must exist")
		assert(_scene.mobile_controls != null, "MobileControlsLandscape must be instantiated in hud_layer")
		assert(_scene.fx_toggle_btn != null, "FX toggle button must exist on HUD")
		assert(_scene.hero_switch_btn != null, "Hero switch button must exist on HUD")

		# Simulate touch joystick WALK state & verify walk texture + frame stepping
		var start_pos: Vector3 = _scene.player.global_position
		_scene.mobile_controls.joy_vector = Vector2(0.85, -0.35)
		_scene._physics_process(0.08)
		assert(_scene.player.global_position.x > start_pos.x, "mobile_controls.joy_vector.x > 0 must move Player3D right")
		assert(_scene.player.global_position.z < start_pos.z, "mobile_controls.joy_vector.y < 0 must move Player3D up (-Z)")
		assert(_scene.anim_state == _scene.AnimState.WALK, "Moving must switch anim_state to WALK")
		assert(_scene.player_sprite.texture == _scene._hero_walk_textures[_scene.active_hero_id], "WALK state must bind _hero_walk_textures")
		assert(_scene.player_sprite.hframes == 4, "WALK texture must use hframes = 4")
		var frame_before: int = _scene.player_sprite.frame
		_scene._physics_process(0.15)
		assert(_scene.player_sprite.frame != frame_before, "WALK state must advance frame across 0..3")
		_scene.mobile_controls.joy_vector = Vector2.ZERO

		# Simulate DASH via mobile_controls signal & verify 3 Afterimages
		_scene.mobile_controls.dash_pressed.emit()
		assert(_scene._afterimages.size() == 3, "DASH must spawn 3 translucent hero-colored afterimages")
		_scene._physics_process(0.05)
		assert(_scene.hero_z > 0.0, "dash_pressed signal must lift Sprite3D above shadow via hero_z")
		assert(_scene.player_sprite.position.y > 0.0, "player_sprite.position.y must reflect hero_z")

	elif _tick == 4:
		# Move player within melee range of enemy and test ATTACK state + Lunge + skill signals
		_scene.player.global_position = _scene.enemy.global_position + Vector3(-1.8, 0.0, 0.0)
		_scene.facing_dir = Vector3.RIGHT
		var hp_before: float = _scene.enemy_hp
		_scene.mobile_controls.attack_pressed.emit()
		assert(_scene.anim_state == _scene.AnimState.ATTACK, "attack_pressed must enter AnimState.ATTACK")
		assert(_scene.player_sprite.texture == _scene._hero_attack_textures[_scene.active_hero_id], "ATTACK state must bind _hero_attack_textures")
		assert(_scene._attack_lunge_offset.length() > 0.05, "ATTACK state must lunge forward along facing_dir")
		assert(_scene.enemy_hp < hp_before, "mobile_controls.attack_pressed in range must damage DummyEnemy3D")
		assert(_scene._floating_texts.size() > 0, "Slash hit must spawn 3D->2D floating damage text")

		var vfx_before: int = _scene._active_vfx.size()
		_scene.mobile_controls.skill_e_pressed.emit()
		assert(_scene._active_vfx.size() > vfx_before, "mobile_controls.skill_e_pressed must spawn IceDomainVFX3D")

		var vfx_before_r: int = _scene._active_vfx.size()
		_scene.mobile_controls.skill_r_pressed.emit()
		assert(_scene._active_vfx.size() >= vfx_before_r + 2, "mobile_controls.skill_r_pressed must trigger domain + slash burst")

	elif _tick == 6:
		# Verify all 7 heroes have dedicated Idle, Walk (4-frame), and Attack HD-2D textures
		var seen_heroes: Dictionary = {}
		for i in range(HeroData.HERO_ORDER.size()):
			_scene.cycle_hero()
			var hid: String = _scene.active_hero_id
			seen_heroes[hid] = true
			for suffix in ["idle", "walk", "attack"]:
				var p := "res://assets/hd2d/%s_hd_%s.png" % [hid, suffix]
				assert(ResourceLoader.exists(p), "Missing HD-2D texture: %s" % p)
			assert(_scene.player_sprite.texture == _scene._hero_textures[hid], "set_hero must bind idle texture for %s" % hid)
			var hdata: Dictionary = HeroData.HEROES[hid]
			assert(_scene.hero_switch_btn.text.find(String(hdata["name"])) >= 0, "hero_switch_btn must display active hero name")
			var ring_mat := _scene.player_ring.material_override as StandardMaterial3D
			var expected_tint: Color = (hdata["color"] as Color).lightened(0.28)
			assert(absf(ring_mat.albedo_color.r - expected_tint.r) < 0.05, "player_ring color must match HeroData color for %s" % hid)
		assert(seen_heroes.size() == 7, "Must cycle through all 7 heroes in HeroData.HERO_ORDER")

		# Verify FX Toggle (Glow + Fog) for WebGL2 benchmarking
		assert(_scene.world_env.environment.glow_enabled and _scene.world_env.environment.fog_enabled, "FX must start enabled")
		_scene.toggle_fx()
		assert(not _scene.world_env.environment.glow_enabled and not _scene.world_env.environment.fog_enabled, "toggle_fx() must disable Glow and Fog")
		_scene.toggle_fx()
		assert(_scene.world_env.environment.glow_enabled and _scene.world_env.environment.fog_enabled, "second toggle_fx() must re-enable Glow and Fog")

		# Verify unproject_position updates enemy_bar_root cleanly
		_scene._update_hud(delta)
		var projected: Vector2 = _scene.camera.unproject_position(_scene.enemy.global_position + _scene.ENEMY_BAR_OFFSET)
		assert(_scene.enemy_bar_root.visible, "enemy_bar_root must be visible in front of Camera3D")
		assert(_scene.enemy_bar_root.position.distance_to(projected - Vector2(66.0, 24.0)) < 1.0, "enemy_bar_root position must match camera.unproject_position()")
		print("HD2D_PROTOTYPE_E2E_PASSED: 7-Hero Walk(4f)/Attack/Dash Afterimage + MobileControls + FX Toggle verified!")
		quit(0)
		return true

	return false
