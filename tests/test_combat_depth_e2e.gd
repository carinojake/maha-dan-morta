extends SceneTree

const CombatSystem = preload("res://scripts/combat_system.gd")
const HeroData = preload("res://scripts/hero_data.gd")

var _tick: int = 0
var _scene: Node2D


func _initialize():
	var test_save := "user://test_combat_depth_save.json"
	if FileAccess.file_exists(test_save):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(test_save))
	var globals := root.get_node("Globals")
	globals.set_meta("save_path", test_save)
	globals.set_meta("chapter", 1)
	_scene = load("res://scenes/dark_jade_dungeon.tscn").instantiate()
	root.add_child(_scene)


func _verify_unit_logic():
	for hid in HeroData.HERO_ORDER:
		var elem := CombatSystem.get_hero_element(hid)
		assert(CombatSystem.ELEMENT_INFO.has(elem), "Hero %s must map to valid element" % hid)

	assert(CombatSystem.lookup_reaction("ice", "pyro")["id"] == "melt", "Ice+Pyro must be melt")
	assert(CombatSystem.lookup_reaction("pyro", "ice")["id"] == "melt", "Pyro+Ice must be order-independent")
	assert(CombatSystem.lookup_reaction("lightning", "pyro")["id"] == "overload", "Lightning+Pyro must be overload")
	assert(CombatSystem.lookup_reaction("ice", "lightning")["id"] == "superconduct", "Ice+Lightning must be superconduct")
	assert(CombatSystem.lookup_reaction("nature", "pyro")["id"] == "burning", "Nature+Pyro must be burning")
	assert(CombatSystem.lookup_reaction("nature", "lightning")["id"] == "quicken", "Nature+Lightning must be quicken")
	assert(CombatSystem.lookup_reaction("nature", "ice")["id"] == "frostbind", "Nature+Ice must be frostbind")
	assert(CombatSystem.lookup_reaction("ice", "ice").is_empty(), "Same element must not react")

	var cs := CombatSystem.new()
	assert(cs.get_rank_data()["id"] == "D", "Initial rank must be D")
	cs.add_combo(350.0, true)
	assert(cs.get_rank_data()["id"] == "SSS", "350 score must reach SSS")
	assert(is_equal_approx(cs.get_damage_multiplier(), 1.35), "SSS dmg mult must be 1.35")
	assert(is_equal_approx(cs.get_jade_multiplier(), 1.50), "SSS jade mult must be 1.50")
	cs.on_player_damaged()
	assert(cs.get_rank_data()["id"] == "SS", "Damage must drop SSS -> SS")
	cs.tick(4.2)
	assert(cs.get_rank_data()["id"] == "S", "Decay >4s must drop SS -> S")


func _spawn_dummy_enemy() -> CharacterBody2D:
	var pos: Vector2 = _scene.player.global_position + Vector2(90, 0)
	_scene._spawn_enemy("golem", pos)
	var e: CharacterBody2D = _scene.enemies.back()
	e.set_meta("hp", 5000.0)
	e.set_meta("max_hp", 5000.0)
	e.set_meta("shield", 0.0)
	return e


func _process(_delta: float) -> bool:
	_tick += 1
	if _tick == 3:
		_verify_unit_logic()

		# --- Live Perfect Dodge E2E ---
		var dummy := _spawn_dummy_enemy()
		_scene.hero_sp[_scene.active_hero_id] = 40.0
		_scene.combat.on_dash_started()
		assert(_scene._has_incoming_threat(), "Nearby enemy must register as incoming threat")
		assert(_scene._activate_perfect_dodge(), "Perfect dodge must activate within window")
		assert(is_equal_approx(Engine.time_scale, CombatSystem.PERFECT_DODGE_SLOWMO_SCALE), "Slow-mo time_scale must be 0.35")
		assert(is_equal_approx(_scene.hero_sp[_scene.active_hero_id], 70.0), "Perfect dodge must restore +30 SP")
		assert(_scene.combat.perfect_dodge_crit_ready, "Perfect dodge must arm 100% crit")
		assert(_scene.dodge_ready_label.visible, "Dodge ready HUD label must be visible")

		# Consume guaranteed crit on next attack
		var hp_before: float = float(dummy.get_meta("hp"))
		_scene._damage_enemy(dummy, 100, Vector2.RIGHT, Color.WHITE, 0.0, false)
		assert(not _scene.combat.perfect_dodge_crit_ready, "Next hit must consume perfect dodge crit")
		assert(hp_before - float(dummy.get_meta("hp")) >= 175.0, "Counter crit must deal >=1.8x damage")

		# Restore time_scale after slowmo elapses
		_scene.combat.tick(1.0)
		_scene.hitstop_timer = 0.0
		assert(is_equal_approx(_scene.combat.get_desired_time_scale(0.0), 1.0), "Time scale must restore to 1.0 after slow-mo")
		Engine.time_scale = 1.0

		# --- Live Elemental Reactions E2E (All 6 pairs) ---
		# 1. Ice + Pyro -> Melt
		_scene._switch_hero("bai_yueling", false)
		_scene._damage_enemy(dummy, 30, Vector2.RIGHT, Color.CYAN, 0.0, true)
		assert(str(dummy.get_meta("elem_mark", "")) == "ice", "Bai Yueling skill must apply ice mark")
		_scene._switch_hero("ye_shangye", false)
		var r_before: int = _scene.combat.reaction_count
		_scene._damage_enemy(dummy, 30, Vector2.RIGHT, Color.RED, 0.0, false)
		assert(_scene.combat.reaction_count == r_before + 1, "Ice+Pyro must trigger Melt reaction")
		assert(str(dummy.get_meta("elem_mark", "")) == "", "Reaction must clear elem_mark")

		# 2. Nature + Pyro -> Burning
		_scene._switch_hero("hei_shan", false)
		_scene._damage_enemy(dummy, 30, Vector2.RIGHT, Color.GREEN, 0.0, true)
		_scene._switch_hero("ye_shangye", false)
		_scene._damage_enemy(dummy, 30, Vector2.RIGHT, Color.RED, 0.0, false)
		assert(float(dummy.get_meta("burn_timer", 0.0)) > 0.0, "Nature+Pyro must apply burn_timer")

		# 3. Ice + Lightning -> Superconduct
		_scene._switch_hero("bai_yueling", false)
		_scene._damage_enemy(dummy, 30, Vector2.RIGHT, Color.CYAN, 0.0, true)
		_scene._switch_hero("song_ren", false)
		_scene._damage_enemy(dummy, 30, Vector2.RIGHT, Color.YELLOW, 0.0, false)
		assert(float(dummy.get_meta("vuln_timer", 0.0)) > 0.0, "Ice+Lightning must apply vuln_timer")

		# 4. Nature + Ice -> Frostbind
		_scene._switch_hero("hei_shan", false)
		_scene._damage_enemy(dummy, 30, Vector2.RIGHT, Color.GREEN, 0.0, true)
		_scene._switch_hero("bai_yueling", false)
		_scene._damage_enemy(dummy, 30, Vector2.RIGHT, Color.CYAN, 0.0, false)
		assert(float(dummy.get_meta("frostbind_timer", 0.0)) > 0.0, "Nature+Ice must apply frostbind_timer")

		# 5. Nature + Lightning -> Quicken
		_scene._switch_hero("hei_shan", false)
		_scene._damage_enemy(dummy, 30, Vector2.RIGHT, Color.GREEN, 0.0, true)
		_scene._switch_hero("song_ren", false)
		_scene._damage_enemy(dummy, 30, Vector2.RIGHT, Color.YELLOW, 0.0, false)
		assert(float(dummy.get_meta("quicken_timer", 0.0)) > 0.0, "Nature+Lightning must apply quicken_timer")

		# 6. Lightning + Pyro -> Overload
		_scene._switch_hero("song_ren", false)
		_scene._damage_enemy(dummy, 30, Vector2.RIGHT, Color.YELLOW, 0.0, true)
		_scene._switch_hero("ye_shangye", false)
		_scene._damage_enemy(dummy, 30, Vector2.RIGHT, Color.RED, 0.0, false)
		assert(float(dummy.get_meta("stun", 0.0)) >= 0.79, "Lightning+Pyro must stun enemy via Overload")

		# --- Live SSS Spirit Jade Bonus E2E ---
		_scene.combat.add_combo(400.0, false)
		assert(_scene.combat.get_rank_data()["id"] == "SSS", "Combo rank must reach SSS")
		_scene.save_data["difficulty"] = "normal"
		var jade_before: int = int(_scene.save_data.get("spirit_jade", 0))
		_scene._award_spirit_jade(10)
		var jade_after: int = int(_scene.save_data.get("spirit_jade", 0))
		assert(jade_after - jade_before == 15, "SSS rank must grant +50% Spirit Jade (10 -> 15)")

		_scene.queue_free()
		print("COMBAT_DEPTH_E2E_PASSED: Perfect Dodge, Combo Rank D->SSS, and all 6 Elemental Reactions verified!")
		quit(0)
		return true
	return false
