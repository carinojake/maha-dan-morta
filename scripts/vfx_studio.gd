extends RefCounted

# ==============================================================================
# DAIYOOO-Style 4-Layer Procedural VFX Studio Engine for Godot 4 (2D Top-Down)
# Implements the 4-layer recipe system from https://game-vfx.daiyooo.com/:
# 1. Azure Star Rings (รอยดาบวงดาวคราม - 6 concentric crescent arcs + outer glow + 4-pt stars + dust)
# 2. Critical Star Burst (คริติคอลระเบิดดาว - 12-pt inner star + outer spike ring + 4-pt sparks)
# 3. Frostbound / Spikes (ผลึกน้ำแข็งหุ้ม / หนามมาร - spiked floor seal + 8 jagged crystal shards)
# 4. Galaxy Vortex / Smoldering Burn (ลูกพลังกาแล็กซี / เปลวลามตัว - 5 spiral arms + flame tongues)
# 5. Summoning Circle Pillar & Sky Volley (วงเวทอัญเชิญเสาแสง + ฝนกระบี่/หอกสวรรค์)
# ==============================================================================


static var fx_intensity: float = 1.0
static var _active_roots: int = 0


static func set_fx_reduced(reduced: bool) -> void:
	fx_intensity = 0.52 if reduced else 1.0


static func _make_add_mat() -> CanvasItemMaterial:
	var m := CanvasItemMaterial.new()
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	return m


static func _mount_role(parent: Node2D, node: Node2D, role: String) -> void:
	if not is_instance_valid(parent):
		node.queue_free()
		return
	var cap := 14 if fx_intensity < 0.8 else 30
	var crowd_damp := 0.55 if _active_roots >= cap else 1.0
	if role == "floor":
		node.z_index = 1
		node.modulate.a = 0.34 * fx_intensity * crowd_damp
	elif role == "impact":
		node.z_index = 3
		node.modulate.a = 0.88 * fx_intensity
	elif role == "slash":
		node.z_index = 2
		node.modulate.a = 0.74 * fx_intensity * crowd_damp
	elif role == "ult_fx":
		node.z_index = 2
		node.modulate.a = 0.64 * fx_intensity * crowd_damp
	else:
		node.z_index = 2
		node.modulate.a = 0.68 * fx_intensity * crowd_damp
	_active_roots += 1
	node.tree_exited.connect(func(): _active_roots = maxi(0, _active_roots - 1))
	parent.add_child(node)


static func _make_star_poly(outer_r: float, inner_r: float, points_cnt: int) -> PackedVector2Array:
	var arr := PackedVector2Array()
	var total := points_cnt * 2
	for i in range(total):
		var a := (float(i) / float(total)) * TAU - PI * 0.5
		var r := outer_r if (i % 2 == 0) else inner_r
		arr.append(Vector2(cos(a) * r, sin(a) * r))
	return arr


static func _make_ellipse(rx: float, ry: float, pts: int) -> PackedVector2Array:
	var arr := PackedVector2Array()
	for i in range(pts):
		var a := (float(i) / float(pts)) * TAU
		arr.append(Vector2(cos(a) * rx, sin(a) * ry))
	return arr


# 1. รอยดาบวงดาวคราม (Azure Star Rings — 4-Layer Multi-Arc Slash)
static func spawn_azure_star_slash(parent: Node2D, pos: Vector2, angle: float, col: Color, scale_mult: float = 1.0) -> void:
	var root := Node2D.new()
	root.position = pos
	root.rotation = angle
	root.scale = Vector2(scale_mult, scale_mult)
	_mount_role(parent, root, "slash")
	var add_mat := _make_add_mat()
	var bright := col.lightened(0.55)

	# Layer 1 & 2: 6 Concentric Crescent Sword Arcs + Bright Outer Rim
	for ring_i in range(6):
		var radius := 38.0 + float(ring_i) * 11.5
		var arc := Line2D.new()
		arc.material = add_mat
		var pts := PackedVector2Array()
		var span := PI * (0.78 - float(ring_i) * 0.04)
		var steps := 22
		for s in range(steps + 1):
			var t := float(s) / float(steps) - 0.5
			var a := t * span
			pts.append(Vector2(cos(a) * radius, sin(a) * radius * 0.86))
		arc.points = pts
		arc.width = 4.2 if ring_i == 5 else (2.4 - float(ring_i) * 0.2)
		arc.default_color = bright if ring_i == 5 else Color(col.r, col.g, col.b, 0.85 - float(ring_i) * 0.08)
		root.add_child(arc)

	# Layer 3: 4-Pointed Star Glints along the leading edge
	for s_i in range(5):
		var st := Polygon2D.new()
		st.material = add_mat
		st.polygon = _make_star_poly(9.0, 2.5, 4)
		st.color = bright
		var sa := randf_range(-PI * 0.36, PI * 0.36)
		var sr := randf_range(55.0, 102.0)
		st.position = Vector2(cos(sa) * sr, sin(sa) * sr * 0.86)
		root.add_child(st)

	# Layer 4: Stardust Particles
	for d_i in range(8):
		var dot := Polygon2D.new()
		dot.material = add_mat
		dot.polygon = _make_star_poly(4.0, 1.5, 4)
		dot.color = Color(bright.r, bright.g, bright.b, 0.9)
		var da := randf_range(-PI * 0.42, PI * 0.42)
		var dr := randf_range(40.0, 110.0)
		dot.position = Vector2(cos(da) * dr, sin(da) * dr * 0.86)
		root.add_child(dot)

	var tw := root.create_tween()
	tw.tween_property(root, "scale", Vector2(scale_mult * 1.28, scale_mult * 1.28), 0.22).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(root, "modulate:a", 0.0, 0.22)
	tw.tween_callback(root.queue_free)


# 2. คริติคอลระเบิดดาว (Critical Star Burst)
static func spawn_critical_star_burst(parent: Node2D, pos: Vector2, col: Color, scale_mult: float = 1.0) -> void:
	var root := Node2D.new()
	root.position = pos
	root.scale = Vector2(0.35 * scale_mult, 0.35 * scale_mult)
	_mount_role(parent, root, "impact")
	var add_mat := _make_add_mat()

	# Outer 12-spike sunburst ring
	var outer_star := Polygon2D.new()
	outer_star.material = add_mat
	outer_star.polygon = _make_star_poly(58.0, 26.0, 12)
	outer_star.color = Color(col.r, col.g, col.b, 0.85)
	root.add_child(outer_star)

	# Halo circle
	var halo := Line2D.new()
	halo.material = add_mat
	var hpts := _make_ellipse(36.0, 36.0, 24)
	hpts.append(hpts[0])
	halo.points = hpts
	halo.width = 3.5
	halo.default_color = col.lightened(0.35)
	root.add_child(halo)

	# Inner 10-point bright core star
	var inner_star := Polygon2D.new()
	inner_star.material = add_mat
	inner_star.polygon = _make_star_poly(34.0, 14.0, 10)
	inner_star.color = Color("#fef08a")
	root.add_child(inner_star)

	var tw := root.create_tween()
	tw.tween_property(root, "scale", Vector2(scale_mult * 1.15, scale_mult * 1.15), 0.24).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(root, "rotation", 0.45, 0.24)
	tw.parallel().tween_property(root, "modulate:a", 0.0, 0.26)
	tw.tween_callback(root.queue_free)


# 3. ผลึกน้ำแข็งหุ้ม / หนามปะทุ (Frostbound / Spike Eruption Ring — Skill [E])
static func spawn_frostbound_eruption(floor_parent: Node2D, fx_parent: Node2D, pos: Vector2, col: Color) -> void:
	var add_mat := _make_add_mat()
	var seal := Node2D.new()
	seal.position = pos
	_mount_role(floor_parent, seal, "floor")

	# Spiked outer seal ring (16 teeth)
	var toothed := Line2D.new()
	toothed.material = add_mat
	var tpts := _make_star_poly(175.0, 142.0, 16)
	tpts.append(tpts[0])
	toothed.points = tpts
	toothed.width = 3.0
	toothed.default_color = Color(col.r, col.g, col.b, 0.85)
	seal.add_child(toothed)

	var inner_ring := Line2D.new()
	inner_ring.material = add_mat
	var ipts := _make_ellipse(125.0, 90.0, 28)
	ipts.append(ipts[0])
	inner_ring.points = ipts
	inner_ring.width = 2.5
	inner_ring.default_color = col.lightened(0.45)
	seal.add_child(inner_ring)

	var stw := seal.create_tween()
	stw.tween_property(seal, "rotation", 0.65, 0.55)
	stw.parallel().tween_property(seal, "modulate:a", 0.0, 0.55)
	stw.tween_callback(seal.queue_free)

	# 8 Upward Crystal Shards / Spikes around the ring
	var spikes := Node2D.new()
	spikes.position = pos
	_mount_role(fx_parent, spikes, "skill_fx")
	for i in range(8):
		var a := (float(i) / 8.0) * TAU
		var shard := Polygon2D.new()
		shard.material = add_mat
		shard.polygon = PackedVector2Array([
			Vector2(-10, 0), Vector2(-6, -42), Vector2(0, -64), Vector2(6, -38), Vector2(10, 0), Vector2(0, 8)
		])
		shard.color = col.lightened(0.35)
		shard.position = Vector2(cos(a) * 115.0, sin(a) * 82.0)
		shard.scale = Vector2(0.2, 0.2)
		spikes.add_child(shard)
		var ctw := shard.create_tween()
		ctw.tween_interval(float(i) * 0.02)
		ctw.tween_property(shard, "scale", Vector2(1.0, 1.0), 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	var ftw := spikes.create_tween()
	ftw.tween_interval(0.32)
	ftw.tween_property(spikes, "modulate:a", 0.0, 0.24)
	ftw.tween_callback(spikes.queue_free)


# 4. ลูกพลังกาแล็กซี / น้ำวนเพลิงทมิฬ (Galaxy Vortex — Skill [E] / Switch-In)
static func spawn_galaxy_vortex(floor_parent: Node2D, pos: Vector2, col: Color, radius: float = 185.0) -> void:
	var root := Node2D.new()
	root.position = pos
	_mount_role(floor_parent, root, "floor")
	var add_mat := _make_add_mat()
	var bright := col.lightened(0.45)

	# 5 Spiral Arms
	for arm_i in range(5):
		var base_a := (float(arm_i) / 5.0) * TAU
		var arm := Line2D.new()
		arm.material = add_mat
		var pts := PackedVector2Array()
		for s in range(18):
			var t := float(s) / 17.0
			var r := lerpf(16.0, radius, t)
			var a := base_a + t * 2.2
			pts.append(Vector2(cos(a) * r, sin(a) * r * 0.72))
		arm.points = pts
		arm.width = 4.0
		arm.default_color = bright if arm_i % 2 == 0 else col
		root.add_child(arm)

	var tw := root.create_tween()
	tw.tween_property(root, "rotation", -1.8, 0.50)
	tw.parallel().tween_property(root, "scale", Vector2(1.18, 1.18), 0.50)
	tw.parallel().tween_property(root, "modulate:a", 0.0, 0.50)
	tw.tween_callback(root.queue_free)


# 5. วงเวทอัญเชิญเสาแสง + ฝนศาสตราสวรรค์ (Summoning Circle Pillar & Sky Volley — Skill [R])
static func spawn_summoning_pillar(floor_parent: Node2D, fx_parent: Node2D, pos: Vector2, col: Color) -> void:
	var add_mat := _make_add_mat()
	var bright := col.lightened(0.50)

	# Double Concentric Summoning Seal on Floor
	var seal := Node2D.new()
	seal.position = pos
	_mount_role(floor_parent, seal, "floor")
	for r_val in [190.0, 155.0]:
		var ring := Line2D.new()
		ring.material = add_mat
		var pts := _make_ellipse(r_val, r_val * 0.72, 32)
		pts.append(pts[0])
		ring.points = pts
		ring.width = 3.5
		ring.default_color = bright if r_val == 155.0 else col
		seal.add_child(ring)

	var star_seal := Line2D.new()
	star_seal.material = add_mat
	var spts := _make_star_poly(155.0, 75.0, 8)
	spts.append(spts[0])
	star_seal.points = spts
	star_seal.width = 2.5
	star_seal.default_color = Color("#fde047")
	seal.add_child(star_seal)

	var stw := seal.create_tween()
	stw.tween_property(seal, "rotation", 1.2, 0.85)
	stw.parallel().tween_property(seal, "modulate:a", 0.0, 0.85)
	stw.tween_callback(seal.queue_free)

	# Vertical Light Pillar + Helical Spiral Ribbon
	var pillar := Node2D.new()
	pillar.position = pos
	_mount_role(fx_parent, pillar, "ult_fx")

	var beam := Polygon2D.new()
	beam.material = add_mat
	beam.polygon = PackedVector2Array([
		Vector2(-34, 10), Vector2(-24, -260), Vector2(24, -260), Vector2(34, 10)
	])
	beam.color = Color(col.r, col.g, col.b, 0.42)
	pillar.add_child(beam)

	var helix := Line2D.new()
	helix.material = add_mat
	var hpts := PackedVector2Array()
	for i in range(28):
		var t := float(i) / 27.0
		var y := lerpf(10.0, -250.0, t)
		var x := sin(t * TAU * 3.0) * 42.0
		hpts.append(Vector2(x, y))
	helix.points = hpts
	helix.width = 4.0
	helix.default_color = bright
	pillar.add_child(helix)

	var ptw := pillar.create_tween()
	ptw.tween_property(pillar, "scale:x", 1.35, 0.55)
	ptw.parallel().tween_property(pillar, "modulate:a", 0.0, 0.55)
	ptw.tween_callback(pillar.queue_free)


static func spawn_sky_sword_drop(fx_parent: Node2D, target_pos: Vector2, col: Color) -> void:
	var add_mat := _make_add_mat()
	var bright := col.lightened(0.55)
	var blade := Node2D.new()
	blade.position = target_pos + Vector2(0, -240)
	_mount_role(fx_parent, blade, "impact")

	var poly := Polygon2D.new()
	poly.material = add_mat
	poly.polygon = PackedVector2Array([
		Vector2(0, 22), Vector2(-7, -10), Vector2(-4, -78), Vector2(0, -92), Vector2(4, -78), Vector2(7, -10)
	])
	poly.color = bright
	blade.add_child(poly)

	var tw := blade.create_tween()
	tw.tween_property(blade, "position", target_pos, 0.11).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_callback(func():
		spawn_critical_star_burst(fx_parent, target_pos, col, 0.65)
	)
	tw.tween_interval(0.14)
	tw.tween_property(blade, "modulate:a", 0.0, 0.15)
	tw.tween_callback(blade.queue_free)


# 6. เอฟเฟกต์ท่าไม้ตายบอสประจำบทที่ 1–10 (Boss Signature Ultimates)
static func spawn_boss_ultimate_vfx(floor_parent: Node2D, fx_parent: Node2D, pos: Vector2, chapter: int, col: Color) -> void:
	if chapter in [1, 4, 7]:
		# Molten / Hellfire / Furnace Eruption
		spawn_summoning_pillar(floor_parent, fx_parent, pos, col)
		spawn_frostbound_eruption(floor_parent, fx_parent, pos, Color("#fb923c"))
	elif chapter == 2:
		# Ten-Thousand Poisons Vortex + Acid Needles
		spawn_galaxy_vortex(floor_parent, pos, Color("#4ade80"), 230.0)
		spawn_frostbound_eruption(floor_parent, fx_parent, pos, Color("#22c55e"))
	elif chapter == 3:
		# Blood-Clan 5-Way Sword Array
		spawn_galaxy_vortex(floor_parent, pos, Color("#f43f5e"), 220.0)
		for i in range(5):
			spawn_azure_star_slash(fx_parent, pos, (float(i) / 5.0) * TAU, Color("#f43f5e"), 1.45)
	elif chapter in [5, 8, 9]:
		# Sky-Sword Volley / Lightning Spears / Heaven Decree
		spawn_summoning_pillar(floor_parent, fx_parent, pos, col)
		for i in range(8):
			var a := (float(i) / 8.0) * TAU
			spawn_sky_sword_drop(fx_parent, pos + Vector2(cos(a) * 165.0, sin(a) * 110.0), col)
	elif chapter == 6:
		# Clockwork 8-Dir Laser Seal
		spawn_galaxy_vortex(floor_parent, pos, Color("#ef4444"), 240.0)
		spawn_critical_star_burst(fx_parent, pos, Color("#ef4444"), 1.6)
	else:
		# Chapter 10 Finale: 4-Realm Supreme Fate Wheel
		var realm_cols := [Color("#38bdf8"), Color("#f43f5e"), Color("#facc15"), Color("#c084fc")]
		for idx in range(4):
			var rc: Color = realm_cols[idx]
			spawn_galaxy_vortex(floor_parent, pos, rc, 150.0 + float(idx) * 35.0)
			spawn_sky_sword_drop(fx_parent, pos + Vector2(cos(float(idx) * PI * 0.5) * 140.0, sin(float(idx) * PI * 0.5) * 95.0), rc)
		spawn_summoning_pillar(floor_parent, fx_parent, pos, Color("#fde047"))
		spawn_critical_star_burst(fx_parent, pos, Color("#fde047"), 1.9)


# 7. คลื่นกระบี่จันทร์เสี้ยวเหมันต์ (Phase 1 — Bai Yueling Skill [Q])
static func spawn_ice_crescent_wave(fx_parent: Node2D, pos: Vector2, angle: float, col: Color) -> void:
	var add_mat := _make_add_mat()
	var bright := col.lightened(0.55)
	var root := Node2D.new()
	root.position = pos
	root.rotation = angle
	_mount_role(fx_parent, root, "slash")

	for spec in [[58.0, 7.0, Color(col.r, col.g, col.b, 0.92), 0.0], [46.0, 3.2, Color(0.92, 0.98, 1.0, 0.95), 6.0]]:
		var r: float = float(spec[0])
		var w: float = float(spec[1])
		var c: Color = spec[2]
		var xoff: float = float(spec[3])
		var arc := Line2D.new()
		arc.material = add_mat
		var pts := PackedVector2Array()
		for i in range(15):
			var t := lerpf(-1.05, 1.05, float(i) / 14.0)
			pts.append(Vector2(cos(t) * r * 0.72 + xoff, sin(t) * r))
		arc.points = pts
		arc.width = w
		arc.default_color = c
		root.add_child(arc)

	for i in range(6):
		var shard := Polygon2D.new()
		shard.material = add_mat
		shard.polygon = PackedVector2Array([
			Vector2(-7, 0), Vector2(0, -4), Vector2(10, 0), Vector2(0, 4)
		])
		shard.color = bright
		var spread := lerpf(-44.0, 44.0, float(i) / 5.0)
		shard.position = Vector2(randf_range(8.0, 26.0), spread)
		root.add_child(shard)
		var stw := shard.create_tween()
		stw.tween_property(shard, "position", shard.position + Vector2(randf_range(38.0, 70.0), spread * 0.25), 0.26)

	var fwd := Vector2(cos(angle), sin(angle)) * 95.0
	var tw := root.create_tween()
	tw.tween_property(root, "position", pos + fwd, 0.28).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(root, "scale", Vector2(1.38, 1.38), 0.28)
	tw.parallel().tween_property(root, "modulate:a", 0.0, 0.28)
	tw.tween_callback(root.queue_free)


# 8. ดอกบัวเหมันต์ + วงแหวน 12 กระบี่ (Phase 2 — Bai Yueling Skill [E])
static func spawn_ice_lotus_and_sword_halo(floor_parent: Node2D, fx_parent: Node2D, pos: Vector2, col: Color) -> void:
	var add_mat := _make_add_mat()
	var bright := col.lightened(0.55)

	# Blooming Ice Lotus on floor
	var lotus := Node2D.new()
	lotus.position = pos
	lotus.scale = Vector2(0.18, 0.18)
	_mount_role(floor_parent, lotus, "floor")

	for layer in [[8, 128.0, 28.0, 0.0, Color(col.r, col.g, col.b, 0.65)], [8, 92.0, 22.0, PI / 8.0, Color(0.86, 0.97, 1.0, 0.78)]]:
		var cnt: int = int(layer[0])
		var plen: float = float(layer[1])
		var pwid: float = float(layer[2])
		var aoff: float = float(layer[3])
		var pcol: Color = layer[4]
		for i in range(cnt):
			var a := (float(i) / float(cnt)) * TAU + aoff
			var petal := Polygon2D.new()
			petal.material = add_mat
			petal.polygon = PackedVector2Array([
				Vector2(0, 0),
				Vector2(plen * 0.45, -pwid),
				Vector2(plen, 0),
				Vector2(plen * 0.45, pwid),
			])
			petal.color = pcol
			petal.rotation = a
			petal.scale = Vector2(1.0, 0.72)
			lotus.add_child(petal)

	var ltw := lotus.create_tween()
	ltw.tween_property(lotus, "scale", Vector2(1.08, 0.78), 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	ltw.parallel().tween_property(lotus, "rotation", 0.35, 0.72)
	ltw.tween_property(lotus, "modulate:a", 0.0, 0.55)
	ltw.tween_callback(lotus.queue_free)

	# 12-Sword Celestial Halo on fx_parent
	var halo := Node2D.new()
	halo.position = pos + Vector2(0.0, -24.0)
	_mount_role(fx_parent, halo, "skill_fx")
	for i in range(12):
		var a := (float(i) / 12.0) * TAU
		var sword := Polygon2D.new()
		sword.material = add_mat
		sword.polygon = PackedVector2Array([
			Vector2(0, -34), Vector2(5, -14), Vector2(2, 12), Vector2(7, 14), Vector2(2, 17), Vector2(2, 26),
			Vector2(-2, 26), Vector2(-2, 17), Vector2(-7, 14), Vector2(-2, 12), Vector2(-5, -14)
		])
		sword.color = bright if i % 2 == 0 else col
		sword.position = Vector2(cos(a), sin(a) * 0.76) * 92.0
		sword.rotation = a + PI * 0.5
		halo.add_child(sword)

	var htw := halo.create_tween()
	htw.tween_property(halo, "rotation", 1.1, 0.62)
	htw.parallel().tween_property(halo, "scale", Vector2(1.22, 1.22), 0.62)
	htw.parallel().tween_property(halo, "modulate:a", 0.0, 0.62)
	htw.tween_callback(halo.queue_free)


# 9. แดนค่ายกลอักขระ + เสาน้ำแข็งหมื่นกระบี่ (Phases 3-4 — Bai Yueling Skill [R])
static func spawn_myriad_ice_domain(floor_parent: Node2D, fx_parent: Node2D, pos: Vector2, col: Color) -> void:
	var add_mat := _make_add_mat()
	var bright := col.lightened(0.58)

	# Celestial Rune Array on floor
	var array_node := Node2D.new()
	array_node.position = pos
	_mount_role(floor_parent, array_node, "floor")

	for spec in [[220.0, 155.0, 4.0, col], [165.0, 116.0, 2.5, bright]]:
		var ring := Line2D.new()
		ring.material = add_mat
		var rpts := _make_ellipse(float(spec[0]), float(spec[1]), 40)
		rpts.append(rpts[0])
		ring.points = rpts
		ring.width = float(spec[2])
		ring.default_color = spec[3]
		array_node.add_child(ring)

	var star := Line2D.new()
	star.material = add_mat
	var spts := _make_star_poly(165.0, 95.0, 8)
	for idx in range(spts.size()):
		spts[idx] = Vector2(spts[idx].x, spts[idx].y * 0.70)
	spts.append(spts[0])
	star.points = spts
	star.width = 2.4
	star.default_color = Color(0.92, 0.98, 1.0, 0.90)
	array_node.add_child(star)

	for i in range(16):
		var a := (float(i) / 16.0) * TAU
		var tick := Line2D.new()
		tick.material = add_mat
		tick.points = PackedVector2Array([
			Vector2(cos(a) * 168.0, sin(a) * 118.0),
			Vector2(cos(a) * 218.0, sin(a) * 153.0),
		])
		tick.width = 2.6
		tick.default_color = bright
		array_node.add_child(tick)

	var atw := array_node.create_tween()
	atw.tween_property(array_node, "rotation", 0.55, 0.65)
	atw.tween_property(array_node, "modulate:a", 0.0, 0.25)
	atw.tween_callback(array_node.queue_free)

	# 10 Perimeter Jagged Ice Crystal Pillars
	var pillars := Node2D.new()
	pillars.position = pos
	_mount_role(fx_parent, pillars, "ult_fx")
	for i in range(10):
		var a := (float(i) / 10.0) * TAU
		var spire := Polygon2D.new()
		spire.material = add_mat
		spire.polygon = PackedVector2Array([
			Vector2(-15, 6), Vector2(-11, -68), Vector2(-3, -115), Vector2(8, -82), Vector2(15, 6), Vector2(0, 12)
		])
		spire.color = Color(bright.r, bright.g, bright.b, 0.85) if i % 2 == 0 else Color(col.r, col.g, col.b, 0.88)
		spire.position = Vector2(cos(a) * 190.0, sin(a) * 132.0)
		spire.scale = Vector2(1.0, 0.08)
		pillars.add_child(spire)
		var ptw := spire.create_tween()
		ptw.tween_interval(float(i) * 0.03)
		ptw.tween_property(spire, "scale", Vector2(1.0, 1.0), 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	var ftw := pillars.create_tween()
	ftw.tween_interval(0.48)
	ftw.tween_property(pillars, "modulate:a", 0.0, 0.35)
	ftw.tween_callback(pillars.queue_free)


# 10. แพรแดง + เข็มปราณทอง (Hei Shan Skill [Q])
static func spawn_crimson_ribbon_needles(fx_parent: Node2D, pos: Vector2, angle: float, _col: Color) -> void:
	var add_mat := _make_add_mat()
	var root := Node2D.new()
	root.position = pos
	root.rotation = angle
	_mount_role(fx_parent, root, "slash")

	var ribbon := Line2D.new()
	ribbon.material = add_mat
	var rpts := PackedVector2Array()
	for i in range(16):
		var t := float(i) / 15.0
		var ang := lerpf(-1.15, 1.15, t)
		rpts.append(Vector2(cos(ang) * 44.0 + sin(t * TAU) * 8.0, sin(ang) * 58.0))
	ribbon.points = rpts
	ribbon.width = 8.0
	ribbon.default_color = Color("#e11d48")
	root.add_child(ribbon)

	for spread in [-0.28, 0.0, 0.28]:
		var needle := Polygon2D.new()
		needle.material = add_mat
		needle.polygon = PackedVector2Array([
			Vector2(-10, -2.5), Vector2(22, 0), Vector2(-10, 2.5), Vector2(-4, 0)
		])
		needle.color = Color("#fde047")
		needle.position = Vector2(18.0, float(spread) * 32.0)
		needle.rotation = float(spread)
		root.add_child(needle)
		var ntw := needle.create_tween()
		var ndir := Vector2(cos(float(spread)), sin(float(spread)))
		ntw.tween_property(needle, "position", needle.position + ndir * 130.0, 0.26).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

	var tw := root.create_tween()
	tw.tween_property(root, "scale", Vector2(1.22, 1.22), 0.28)
	tw.parallel().tween_property(root, "modulate:a", 0.0, 0.28)
	tw.tween_callback(root.queue_free)


# 11. โดมคุ้มกันอักขระทอง + เถาวัลย์พฤกษา (Hei Shan Skill [E])
static func spawn_golden_vine_sanctuary(floor_parent: Node2D, fx_parent: Node2D, pos: Vector2, _col: Color) -> void:
	var add_mat := _make_add_mat()
	var gold := Color("#fbbf24")
	var bright := Color("#fef08a")

	var seal := Node2D.new()
	seal.position = pos
	_mount_role(floor_parent, seal, "floor")

	var ring := Line2D.new()
	ring.material = add_mat
	var rpts := _make_ellipse(175.0, 125.0, 36)
	rpts.append(rpts[0])
	ring.points = rpts
	ring.width = 3.5
	ring.default_color = gold
	seal.add_child(ring)

	var stw := seal.create_tween()
	stw.tween_property(seal, "rotation", 0.45, 0.75)
	stw.parallel().tween_property(seal, "modulate:a", 0.0, 0.75)
	stw.tween_callback(seal.queue_free)

	var dome := Node2D.new()
	dome.position = pos
	_mount_role(fx_parent, dome, "ult_fx")

	var dome_fill := Polygon2D.new()
	dome_fill.material = add_mat
	var dpts := PackedVector2Array()
	for i in range(25):
		var a := lerpf(PI, TAU, float(i) / 24.0)
		dpts.append(Vector2(cos(a) * 145.0, sin(a) * 125.0 + 18.0))
	dpts.append(Vector2(145.0, 36.0))
	dpts.append(Vector2(-145.0, 36.0))
	dome_fill.polygon = dpts
	dome_fill.color = Color(gold.r, gold.g, gold.b, 0.24)
	dome.add_child(dome_fill)

	var rim := Line2D.new()
	rim.material = add_mat
	var rim_pts := PackedVector2Array()
	for i in range(25):
		var a := lerpf(PI, TAU, float(i) / 24.0)
		rim_pts.append(Vector2(cos(a) * 145.0, sin(a) * 125.0 + 18.0))
	rim.points = rim_pts
	rim.width = 3.2
	rim.default_color = bright
	dome.add_child(rim)

	for i in range(6):
		var side := -1.0 if i % 2 == 0 else 1.0
		var x_base := lerpf(-110.0, 110.0, float(i) / 5.0)
		var vine := Line2D.new()
		vine.material = add_mat
		var vpts := PackedVector2Array()
		for s in range(12):
			var t := float(s) / 11.0
			vpts.append(Vector2(x_base + sin(t * TAU * 1.5) * 18.0 * side, lerpf(16.0, -112.0, t)))
		vine.points = vpts
		vine.width = 3.6
		vine.default_color = gold if i % 2 == 0 else bright
		dome.add_child(vine)

	dome.scale = Vector2(0.45, 0.45)
	var dtw := dome.create_tween()
	dtw.tween_property(dome, "scale", Vector2(1.0, 1.0), 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	dtw.tween_interval(0.32)
	dtw.tween_property(dome, "modulate:a", 0.0, 0.24)
	dtw.tween_callback(dome.queue_free)


# 12. สวนสวรรค์ร้อยบุปผา + จิ้งจอกเก้าหาง (Hei Shan Skill [R])
static func spawn_ninetail_blossom_domain(floor_parent: Node2D, fx_parent: Node2D, pos: Vector2, _col: Color) -> void:
	var add_mat := _make_add_mat()
	var gold := Color("#fbbf24")
	var bright := Color("#fef08a")

	var domain := Node2D.new()
	domain.position = pos
	_mount_role(floor_parent, domain, "floor")

	for spec in [[225.0, 158.0, 4.0, gold], [168.0, 118.0, 2.5, bright]]:
		var ring := Line2D.new()
		ring.material = add_mat
		var rpts := _make_ellipse(float(spec[0]), float(spec[1]), 40)
		rpts.append(rpts[0])
		ring.points = rpts
		ring.width = float(spec[2])
		ring.default_color = spec[3]
		domain.add_child(ring)

	# Golden blooming spirit tree canopy at center
	for i in range(6):
		var a := (float(i) / 6.0) * TAU
		var bough := Polygon2D.new()
		bough.material = add_mat
		bough.polygon = PackedVector2Array([
			Vector2(0, 0), Vector2(46, -24), Vector2(88, 0), Vector2(46, 24)
		])
		bough.color = Color(bright.r, bright.g, bright.b, 0.34)
		bough.rotation = a
		bough.scale = Vector2(1.0, 0.72)
		domain.add_child(bough)

	var dom_tw := domain.create_tween()
	dom_tw.tween_property(domain, "rotation", 0.42, 1.15)
	dom_tw.tween_property(domain, "modulate:a", 0.0, 0.25)
	dom_tw.tween_callback(domain.queue_free)

	# Radiant 9-Tail Spirit Fan + 18 drifting golden petals
	var fan := Node2D.new()
	fan.position = pos + Vector2(0.0, -36.0)
	_mount_role(fx_parent, fan, "ult_fx")

	for i in range(9):
		var t := float(i) / 8.0
		var tail_ang := lerpf(-1.25, 1.25, t) - PI * 0.5
		var tail := Polygon2D.new()
		tail.material = add_mat
		tail.polygon = PackedVector2Array([
			Vector2(0, 0),
			Vector2(-14, -68),
			Vector2(-6, -138),
			Vector2(0, -162),
			Vector2(6, -138),
			Vector2(14, -68),
		])
		tail.color = Color(bright.r, bright.g, bright.b, 0.52) if i % 2 == 0 else Color(gold.r, gold.g, gold.b, 0.46)
		tail.rotation = tail_ang + PI * 0.5
		tail.scale = Vector2(0.2, 0.2)
		fan.add_child(tail)
		var ttw := tail.create_tween()
		ttw.tween_interval(float(abs(i - 4)) * 0.025)
		ttw.tween_property(tail, "scale", Vector2(1.0, 1.0), 0.24).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	for p_i in range(18):
		var pa := (float(p_i) / 18.0) * TAU
		var petal := Polygon2D.new()
		petal.material = add_mat
		petal.polygon = PackedVector2Array([
			Vector2(-5, 0), Vector2(0, -3), Vector2(6, 0), Vector2(0, 3)
		])
		petal.color = bright if p_i % 2 == 0 else gold
		petal.position = Vector2(cos(pa) * 32.0, sin(pa) * 22.0)
		petal.rotation = pa
		fan.add_child(petal)
		var ptw := petal.create_tween()
		ptw.tween_property(petal, "position", Vector2(cos(pa) * 215.0, sin(pa) * 145.0 - 24.0), 1.15).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

	var ftw := fan.create_tween()
	ftw.tween_interval(0.50)
	ftw.tween_property(fan, "modulate:a", 0.0, 0.35)
	ftw.tween_callback(fan.queue_free)


# 13. คลื่นยันต์สายฟ้า (Song Ren Skill [Q])
static func spawn_talisman_lightning_burst(fx_parent: Node2D, pos: Vector2, angle: float, _col: Color) -> void:
	var add_mat := _make_add_mat()
	var cyan := Color("#22d3ee")
	var gold := Color("#facc15")
	var root := Node2D.new()
	root.position = pos
	root.rotation = angle
	_mount_role(fx_parent, root, "slash")

	var shock := Line2D.new()
	shock.material = add_mat
	var spts := _make_ellipse(36.0, 48.0, 24)
	spts.append(spts[0])
	shock.points = spts
	shock.width = 4.5
	shock.default_color = cyan
	root.add_child(shock)

	for spread in [-0.36, -0.18, 0.0, 0.18, 0.36]:
		var sp_ang: float = float(spread)
		var tal := Polygon2D.new()
		tal.material = add_mat
		tal.polygon = PackedVector2Array([
			Vector2(-8, -4), Vector2(8, -4), Vector2(8, 4), Vector2(-8, 4)
		])
		tal.color = gold
		tal.rotation = sp_ang
		tal.position = Vector2(16.0, sp_ang * 24.0)
		root.add_child(tal)
		var ttw := tal.create_tween()
		var tdir := Vector2(cos(sp_ang), sin(sp_ang))
		ttw.tween_property(tal, "position", tal.position + tdir * 135.0, 0.28).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

		var zap := Line2D.new()
		zap.material = add_mat
		zap.points = PackedVector2Array([
			Vector2(10.0, sp_ang * 14.0),
			Vector2(62.0, sp_ang * 34.0 + randf_range(-8.0, 8.0)),
			Vector2(118.0, sp_ang * 56.0),
		])
		zap.width = 2.6
		zap.default_color = cyan
		root.add_child(zap)

	var tw := root.create_tween()
	tw.tween_property(root, "scale", Vector2(1.25, 1.25), 0.30)
	tw.parallel().tween_property(root, "modulate:a", 0.0, 0.30)
	tw.tween_callback(root.queue_free)


# 14. ค่ายกลแปดทิศ + โซ่วิญญาณ (Song Ren Skill [E])
static func spawn_bagua_binding_array(floor_parent: Node2D, fx_parent: Node2D, pos: Vector2, _col: Color) -> void:
	var add_mat := _make_add_mat()
	var cyan := Color("#22d3ee")
	var gold := Color("#facc15")

	var seal := Node2D.new()
	seal.position = pos
	_mount_role(floor_parent, seal, "floor")

	var oct := Line2D.new()
	oct.material = add_mat
	var opts := PackedVector2Array()
	for i in range(9):
		var a := (float(i % 8) / 8.0) * TAU + PI / 8.0
		opts.append(Vector2(cos(a) * 185.0, sin(a) * 130.0))
	oct.points = opts
	oct.width = 3.8
	oct.default_color = cyan
	seal.add_child(oct)

	var inner := Line2D.new()
	inner.material = add_mat
	var ipts := _make_ellipse(112.0, 78.0, 28)
	ipts.append(ipts[0])
	inner.points = ipts
	inner.width = 2.6
	inner.default_color = Color("#bae6fd")
	seal.add_child(inner)

	# 8 Trigram bars around the Bagua ring
	for i in range(8):
		var a := (float(i) / 8.0) * TAU
		var bar := Line2D.new()
		bar.material = add_mat
		var c := Vector2(cos(a) * 145.0, sin(a) * 102.0)
		var tang := Vector2(-sin(a), cos(a)) * 14.0
		bar.points = PackedVector2Array([c - tang, c + tang])
		bar.width = 3.5
		bar.default_color = cyan
		seal.add_child(bar)

	var stw := seal.create_tween()
	stw.tween_property(seal, "rotation", 0.55, 0.85)
	stw.parallel().tween_property(seal, "modulate:a", 0.0, 0.85)
	stw.tween_callback(seal.queue_free)

	# 4 Luminous Spirit Chains snapping across + central golden talisman flash
	var chains := Node2D.new()
	chains.position = pos
	_mount_role(fx_parent, chains, "skill_fx")
	for i in range(4):
		var a := (float(i) / 4.0) * TAU + PI * 0.25
		var chain := Line2D.new()
		chain.material = add_mat
		var cpts := PackedVector2Array()
		for s in range(9):
			var t := float(s) / 8.0
			var r := lerpf(190.0, 12.0, t)
			var perp := Vector2(-sin(a), cos(a)) * (8.0 if s % 2 == 0 else -8.0)
			cpts.append(Vector2(cos(a) * r, sin(a) * r * 0.72) + perp)
		chain.points = cpts
		chain.width = 3.4
		chain.default_color = cyan
		chains.add_child(chain)

	var tal_flash := Polygon2D.new()
	tal_flash.material = add_mat
	tal_flash.polygon = PackedVector2Array([
		Vector2(-10, -24), Vector2(10, -24), Vector2(10, 24), Vector2(-10, 24)
	])
	tal_flash.color = gold
	tal_flash.position = Vector2(0.0, -32.0)
	chains.add_child(tal_flash)

	var ctw := chains.create_tween()
	ctw.tween_property(chains, "scale", Vector2(1.08, 1.08), 0.35)
	ctw.tween_interval(0.25)
	ctw.tween_property(chains, "modulate:a", 0.0, 0.25)
	ctw.tween_callback(chains.queue_free)


# 15. โดมแปดทิศ + 8 เสาอัสนีบาตสวรรค์ (Song Ren Skill [R])
static func spawn_heavenly_bagua_dome(floor_parent: Node2D, fx_parent: Node2D, pos: Vector2, _col: Color) -> void:
	var add_mat := _make_add_mat()
	var cyan := Color("#22d3ee")
	var bright := Color("#e0f2fe")
	var gold := Color("#facc15")

	var array_node := Node2D.new()
	array_node.position = pos
	_mount_role(floor_parent, array_node, "floor")

	for spec in [[225.0, 158.0, 4.0, cyan], [166.0, 116.0, 2.5, bright]]:
		var ring := Line2D.new()
		ring.material = add_mat
		var rpts := _make_ellipse(float(spec[0]), float(spec[1]), 40)
		rpts.append(rpts[0])
		ring.points = rpts
		ring.width = float(spec[2])
		ring.default_color = spec[3]
		array_node.add_child(ring)

	var atw := array_node.create_tween()
	atw.tween_property(array_node, "rotation", -0.55, 1.15)
	atw.tween_property(array_node, "modulate:a", 0.0, 0.25)
	atw.tween_callback(array_node.queue_free)

	# Barrier dome + 8 orbiting talismans + 8 surging lightning pillars
	var dome := Node2D.new()
	dome.position = pos
	_mount_role(fx_parent, dome, "ult_fx")

	var dome_fill := Polygon2D.new()
	dome_fill.material = add_mat
	var dpts := PackedVector2Array()
	for i in range(25):
		var a := lerpf(PI, TAU, float(i) / 24.0)
		dpts.append(Vector2(cos(a) * 195.0, sin(a) * 155.0 + 18.0))
	dpts.append(Vector2(195.0, 38.0))
	dpts.append(Vector2(-195.0, 38.0))
	dome_fill.polygon = dpts
	dome_fill.color = Color(cyan.r, cyan.g, cyan.b, 0.20)
	dome.add_child(dome_fill)

	var rim := Line2D.new()
	rim.material = add_mat
	var rim_pts := PackedVector2Array()
	for i in range(25):
		var a := lerpf(PI, TAU, float(i) / 24.0)
		rim_pts.append(Vector2(cos(a) * 195.0, sin(a) * 155.0 + 18.0))
	rim.points = rim_pts
	rim.width = 3.5
	rim.default_color = bright
	dome.add_child(rim)

	for i in range(8):
		var a := (float(i) / 8.0) * TAU
		var p_pos := Vector2(cos(a) * 188.0, sin(a) * 130.0)

		var tal := Polygon2D.new()
		tal.material = add_mat
		tal.polygon = PackedVector2Array([
			Vector2(-6, -15), Vector2(6, -15), Vector2(6, 15), Vector2(-6, 15)
		])
		tal.color = gold
		tal.position = p_pos + Vector2(0.0, -34.0)
		dome.add_child(tal)

		var pillar := Polygon2D.new()
		pillar.material = add_mat
		pillar.polygon = PackedVector2Array([
			Vector2(-9, 8), Vector2(-6, -240), Vector2(6, -240), Vector2(9, 8)
		])
		pillar.color = Color(bright.r, bright.g, bright.b, 0.78) if i % 2 == 0 else Color(cyan.r, cyan.g, cyan.b, 0.72)
		pillar.position = p_pos
		pillar.scale = Vector2(1.0, 0.05)
		dome.add_child(pillar)
		var ptw := pillar.create_tween()
		ptw.tween_interval(float(i) * 0.03)
		ptw.tween_property(pillar, "scale", Vector2(1.0, 1.0), 0.16).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

	var ftw := dome.create_tween()
	ftw.tween_interval(0.50)
	ftw.tween_property(dome, "modulate:a", 0.0, 0.35)
	ftw.tween_callback(dome.queue_free)


# 16. แส้โซ่มารเพลิงม่วง (Ye Shangye Skill [Q])
static func spawn_demon_chain_lash(fx_parent: Node2D, pos: Vector2, angle: float, _col: Color) -> void:
	var add_mat := _make_add_mat()
	var violet := Color("#a855f7")
	var crimson := Color("#f43f5e")
	var spark_col := Color("#fb923c")
	var root := Node2D.new()
	root.position = pos
	root.rotation = angle
	_mount_role(fx_parent, root, "slash")

	var outer := Line2D.new()
	outer.material = add_mat
	var opts := PackedVector2Array()
	for i in range(18):
		var t := float(i) / 17.0
		var ang := lerpf(-1.25, 1.25, t)
		opts.append(Vector2(cos(ang) * 54.0, sin(ang) * 76.0))
	outer.points = opts
	outer.width = 9.0
	outer.default_color = violet
	root.add_child(outer)

	var core := Line2D.new()
	core.material = add_mat
	core.points = opts
	core.width = 3.5
	core.default_color = crimson
	root.add_child(core)

	# Iron chain link ticks along the arc
	for i in range(6):
		var t := lerpf(-1.05, 1.05, float(i) / 5.0)
		var tick := Line2D.new()
		var base_p := Vector2(cos(t) * 54.0, sin(t) * 76.0)
		var norm := Vector2(cos(t), sin(t)) * 10.0
		tick.points = PackedVector2Array([base_p - norm, base_p + norm])
		tick.width = 3.0
		tick.default_color = Color("#1e1b2e")
		root.add_child(tick)

	# Fiery orange spark flecks
	for i in range(6):
		var sp := Polygon2D.new()
		sp.material = add_mat
		sp.polygon = PackedVector2Array([
			Vector2(-4, 0), Vector2(0, -3), Vector2(6, 0), Vector2(0, 3)
		])
		sp.color = spark_col
		var y_off := lerpf(-48.0, 48.0, float(i) / 5.0)
		sp.position = Vector2(28.0, y_off)
		root.add_child(sp)
		var stw := sp.create_tween()
		stw.tween_property(sp, "position", sp.position + Vector2(randf_range(42.0, 82.0), y_off * 0.35), 0.28)

	var tw := root.create_tween()
	tw.tween_property(root, "scale", Vector2(1.26, 1.26), 0.30)
	tw.parallel().tween_property(root, "modulate:a", 0.0, 0.30)
	tw.tween_callback(root.queue_free)


# 17. คลื่นไฟโลกันตร์ + หินแตก (Ye Shangye Skill [E])
static func spawn_hellfire_wave_eruption(floor_parent: Node2D, fx_parent: Node2D, pos: Vector2, _col: Color) -> void:
	var add_mat := _make_add_mat()
	var violet := Color("#c084fc")
	var deep_purple := Color("#9333ea")

	var seal := Node2D.new()
	seal.position = pos
	_mount_role(floor_parent, seal, "floor")

	var ring := Line2D.new()
	ring.material = add_mat
	var rpts := _make_ellipse(185.0, 130.0, 36)
	rpts.append(rpts[0])
	ring.points = rpts
	ring.width = 4.0
	ring.default_color = deep_purple
	seal.add_child(ring)

	var stw := seal.create_tween()
	stw.tween_property(seal, "scale", Vector2(1.12, 1.12), 0.78)
	stw.parallel().tween_property(seal, "modulate:a", 0.0, 0.78)
	stw.tween_callback(seal.queue_free)

	var flames := Node2D.new()
	flames.position = pos
	_mount_role(fx_parent, flames, "skill_fx")
	for i in range(10):
		var a := (float(i) / 10.0) * TAU
		var f_pos := Vector2(cos(a) * 145.0, sin(a) * 102.0)
		var tongue := Polygon2D.new()
		tongue.material = add_mat
		tongue.polygon = PackedVector2Array([
			Vector2(-16, 4), Vector2(-10, -48), Vector2(0, -86), Vector2(11, -44), Vector2(16, 4)
		])
		tongue.color = violet if i % 2 == 0 else deep_purple
		tongue.position = f_pos
		tongue.scale = Vector2(0.4, 0.15)
		flames.add_child(tongue)
		var ftw := tongue.create_tween()
		ftw.tween_interval(float(i) * 0.025)
		ftw.tween_property(tongue, "scale", Vector2(1.0, 1.0), 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	for r_i in range(8):
		var ra := (float(r_i) / 8.0) * TAU + 0.2
		var shard := Polygon2D.new()
		shard.polygon = PackedVector2Array([
			Vector2(-6, -4), Vector2(4, -7), Vector2(8, 3), Vector2(-3, 7)
		])
		shard.color = Color("#1f1629")
		shard.position = Vector2(cos(ra) * 58.0, sin(ra) * 40.0)
		flames.add_child(shard)
		var rtw := shard.create_tween()
		rtw.tween_property(shard, "position", Vector2(cos(ra) * 180.0, sin(ra) * 120.0 - 48.0), 0.45).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

	var end_tw := flames.create_tween()
	end_tw.tween_interval(0.45)
	end_tw.tween_property(flames, "modulate:a", 0.0, 0.33)
	end_tw.tween_callback(flames.queue_free)


# 18. นรกโซ่โลหิตกลืนพิภพ (Ye Shangye Skill [R])
static func spawn_demon_king_chain_abyss(floor_parent: Node2D, fx_parent: Node2D, pos: Vector2, _col: Color) -> void:
	var add_mat := _make_add_mat()
	var violet := Color("#a855f7")
	var crimson := Color("#e11d48")
	var bright := Color("#e9d5ff")

	var abyss := Node2D.new()
	abyss.position = pos
	_mount_role(floor_parent, abyss, "floor")

	for spec in [[230.0, 162.0, 4.5, violet], [168.0, 118.0, 3.0, crimson]]:
		var ring := Line2D.new()
		ring.material = add_mat
		var rpts := _make_ellipse(float(spec[0]), float(spec[1]), 40)
		rpts.append(rpts[0])
		ring.points = rpts
		ring.width = float(spec[2])
		ring.default_color = spec[3]
		abyss.add_child(ring)

	for c_i in range(8):
		var ca := (float(c_i) / 8.0) * TAU
		var crack := Line2D.new()
		crack.material = add_mat
		crack.points = PackedVector2Array([
			Vector2.ZERO,
			Vector2(cos(ca + 0.12) * 115.0, sin(ca + 0.12) * 80.0),
			Vector2(cos(ca) * 222.0, sin(ca) * 155.0),
		])
		crack.width = 3.2
		crack.default_color = crimson if c_i % 2 == 0 else violet
		abyss.add_child(crack)

	var atw := abyss.create_tween()
	atw.tween_interval(0.50)
	atw.tween_property(abyss, "modulate:a", 0.0, 0.35)
	atw.tween_callback(abyss.queue_free)

	var inferno := Node2D.new()
	inferno.position = pos
	_mount_role(fx_parent, inferno, "ult_fx")

	for i in range(12):
		var a := (float(i) / 12.0) * TAU
		var flame := Polygon2D.new()
		flame.material = add_mat
		flame.polygon = PackedVector2Array([
			Vector2(-15, 6), Vector2(-8, -62), Vector2(0, -108), Vector2(9, -56), Vector2(15, 6)
		])
		flame.color = Color(violet.r, violet.g, violet.b, 0.80) if i % 2 == 0 else Color(crimson.r, crimson.g, crimson.b, 0.72)
		flame.position = Vector2(cos(a) * 188.0, sin(a) * 130.0)
		flame.scale = Vector2(1.0, 0.1)
		inferno.add_child(flame)
		var ftw := flame.create_tween()
		ftw.tween_interval(float(i) * 0.02)
		ftw.tween_property(flame, "scale", Vector2(1.0, 1.0), 0.18)

	# 6 massive diagonal dark-iron chains wrapped in blazing purple plasma
	for i in range(6):
		var t := float(i) / 5.0
		var x_off := lerpf(-165.0, 165.0, t)
		var tilt := lerpf(-55.0, 55.0, t)
		var chain_root := Node2D.new()
		chain_root.position = Vector2(x_off, 16.0)
		chain_root.scale = Vector2(1.0, 0.05)
		inferno.add_child(chain_root)

		var iron := Line2D.new()
		iron.points = PackedVector2Array([Vector2.ZERO, Vector2(tilt, -250.0)])
		iron.width = 7.5
		iron.default_color = Color("#181024")
		chain_root.add_child(iron)

		var plasma := Line2D.new()
		plasma.material = add_mat
		var ppts := PackedVector2Array()
		for s in range(12):
			var pt := float(s) / 11.0
			var px := lerpf(0.0, tilt, pt) + sin(pt * TAU * 2.5) * 14.0
			var py := lerpf(0.0, -250.0, pt)
			ppts.append(Vector2(px, py))
		plasma.points = ppts
		plasma.width = 3.8
		plasma.default_color = bright if i % 2 == 0 else violet
		chain_root.add_child(plasma)

		var ctw := chain_root.create_tween()
		ctw.tween_interval(float(i) * 0.03)
		ctw.tween_property(chain_root, "scale", Vector2(1.0, 1.0), 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	var itw := inferno.create_tween()
	itw.tween_interval(0.50)
	itw.tween_property(inferno, "modulate:a", 0.0, 0.35)
	itw.tween_callback(inferno.queue_free)


# 19. คมดาบหมึกดำผ่าเงา (Chen Xi Skill [Q])
static func spawn_ink_shadow_cleave(fx_parent: Node2D, pos: Vector2, angle: float, _col: Color) -> void:
	var root := Node2D.new()
	root.position = pos
	root.rotation = angle
	_mount_role(fx_parent, root, "slash")

	# Bold black-ink brush-stroke arc (normal blend so dark ink pops cleanly)
	var ink_arc := Line2D.new()
	var ipts := PackedVector2Array()
	for i in range(16):
		var t := lerpf(-1.18, 1.18, float(i) / 15.0)
		ipts.append(Vector2(cos(t) * 52.0, sin(t) * 74.0))
	ink_arc.points = ipts
	ink_arc.width = 12.0
	ink_arc.default_color = Color("#18181b")
	root.add_child(ink_arc)

	# Crisp silver-white blade highlight edge
	var edge := Line2D.new()
	var epts := PackedVector2Array()
	for i in range(16):
		var t := lerpf(-1.12, 1.12, float(i) / 15.0)
		epts.append(Vector2(cos(t) * 56.0 + 4.0, sin(t) * 74.0))
	edge.points = epts
	edge.width = 3.5
	edge.default_color = Color("#e2e8f0")
	root.add_child(edge)

	# 5 flying ink droplets
	for i in range(5):
		var drop := Polygon2D.new()
		drop.polygon = PackedVector2Array([
			Vector2(-5, 0), Vector2(0, -4), Vector2(7, 0), Vector2(0, 4)
		])
		drop.color = Color("#18181b") if i % 2 == 0 else Color("#cbd5e1")
		var y_off := lerpf(-44.0, 44.0, float(i) / 4.0)
		drop.position = Vector2(36.0, y_off)
		root.add_child(drop)
		var dtw := drop.create_tween()
		dtw.tween_property(drop, "position", drop.position + Vector2(randf_range(44.0, 88.0), y_off * 0.25), 0.28)

	var fwd := Vector2(cos(angle), sin(angle)) * 85.0
	var tw := root.create_tween()
	tw.tween_property(root, "position", pos + fwd, 0.30).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(root, "scale", Vector2(1.25, 1.25), 0.30)
	tw.parallel().tween_property(root, "modulate:a", 0.0, 0.30)
	tw.tween_callback(root.queue_free)


# 20. ระเบิดปราณขาว-ชาด (Chen Xi Skill [E])
static func spawn_blood_qi_ignition(floor_parent: Node2D, fx_parent: Node2D, pos: Vector2, _col: Color) -> void:
	var add_mat := _make_add_mat()
	var crimson := Color("#ef4444")
	var ice_white := Color("#e0f2fe")

	# Explosive icy-white initial starburst
	var burst := Polygon2D.new()
	burst.material = add_mat
	burst.polygon = _make_star_poly(95.0, 32.0, 12)
	burst.color = ice_white
	burst.position = pos + Vector2(0.0, -24.0)
	burst.scale = Vector2(0.25, 0.25)
	_mount_role(fx_parent, burst, "skill_fx")
	var btw := burst.create_tween()
	btw.tween_property(burst, "scale", Vector2(1.45, 1.45), 0.20).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	btw.parallel().tween_property(burst, "modulate:a", 0.0, 0.24)
	btw.tween_callback(burst.queue_free)

	# Glowing crimson blood-qi starburst on floor
	var floor_star := Node2D.new()
	floor_star.position = pos
	_mount_role(floor_parent, floor_star, "floor")

	var star_poly := Polygon2D.new()
	star_poly.material = add_mat
	var spts := _make_star_poly(175.0, 68.0, 10)
	for i in range(spts.size()):
		spts[i] = Vector2(spts[i].x, spts[i].y * 0.70)
	star_poly.polygon = spts
	star_poly.color = Color(crimson.r, crimson.g, crimson.b, 0.55)
	floor_star.add_child(star_poly)

	var ftw := floor_star.create_tween()
	ftw.tween_property(floor_star, "rotation", 0.45, 0.72)
	ftw.parallel().tween_property(floor_star, "modulate:a", 0.0, 0.75)
	ftw.tween_callback(floor_star.queue_free)

	# 3 swirling crimson energy ribbons curling around pos
	var ribbons := Node2D.new()
	ribbons.position = pos + Vector2(0.0, -24.0)
	_mount_role(fx_parent, ribbons, "skill_fx")
	for r_i in range(3):
		var base_a := (float(r_i) / 3.0) * TAU
		var rib := Line2D.new()
		rib.material = add_mat
		var rpts := PackedVector2Array()
		for s in range(18):
			var t := float(s) / 17.0
			var a := base_a + t * 3.2
			var rad := lerpf(36.0, 145.0, t)
			rpts.append(Vector2(cos(a) * rad, sin(a) * rad * 0.72 - t * 38.0))
		rib.points = rpts
		rib.width = 4.5
		rib.default_color = crimson if r_i != 1 else Color("#fca5a5")
		ribbons.add_child(rib)

	var rtw := ribbons.create_tween()
	rtw.tween_property(ribbons, "rotation", 1.9, 0.72)
	rtw.parallel().tween_property(ribbons, "modulate:a", 0.0, 0.75)
	rtw.tween_callback(ribbons.queue_free)


# 21. สังหารโลหิตสะบั้นฟ้า (Chen Xi Skill [R])
static func spawn_heaven_severing_blood_slash(floor_parent: Node2D, fx_parent: Node2D, pos: Vector2, _col: Color) -> void:
	var add_mat := _make_add_mat()
	var crimson := Color("#ef4444")
	var pale_red := Color("#fca5a5")
	var silver := Color("#cbd5e1")

	# Shattered crimson ground-impact starburst
	var impact := Node2D.new()
	impact.position = pos
	_mount_role(floor_parent, impact, "floor")

	var star := Polygon2D.new()
	star.material = add_mat
	var spts := _make_star_poly(220.0, 82.0, 14)
	for i in range(spts.size()):
		spts[i] = Vector2(spts[i].x, spts[i].y * 0.69)
	star.polygon = spts
	star.color = Color(crimson.r, crimson.g, crimson.b, 0.60)
	impact.add_child(star)

	var ring := Line2D.new()
	ring.material = add_mat
	var rpts := _make_ellipse(220.0, 152.0, 36)
	rpts.append(rpts[0])
	ring.points = rpts
	ring.width = 4.0
	ring.default_color = pale_red
	impact.add_child(ring)

	var itw := impact.create_tween()
	itw.tween_property(impact, "scale", Vector2(1.16, 1.16), 1.1)
	itw.tween_property(impact, "modulate:a", 0.0, 0.25)
	itw.tween_callback(impact.queue_free)

	# Twin spiraling crimson ribbons + 8 metallic broken-sword shards + Colossal Vertical Crimson Beam
	var slash_fx := Node2D.new()
	slash_fx.position = pos
	_mount_role(fx_parent, slash_fx, "ult_fx")

	for r_i in range(2):
		var sign_v := 1.0 if r_i == 0 else -1.0
		var rib := Line2D.new()
		rib.material = add_mat
		var bpts := PackedVector2Array()
		for s in range(20):
			var t := float(s) / 19.0
			var y := lerpf(12.0, -250.0, t)
			var x := sin(t * TAU * 1.8) * 92.0 * sign_v
			bpts.append(Vector2(x, y))
		rib.points = bpts
		rib.width = 5.5
		rib.default_color = crimson if r_i == 0 else pale_red
		slash_fx.add_child(rib)

	for s_i in range(8):
		var sa := (float(s_i) / 8.0) * TAU
		var shard := Polygon2D.new()
		shard.polygon = PackedVector2Array([
			Vector2(-5, -14), Vector2(6, -8), Vector2(4, 14), Vector2(-6, 9)
		])
		shard.color = silver
		shard.position = Vector2(cos(sa) * 72.0, sin(sa) * 45.0 - 24.0)
		shard.rotation = sa
		slash_fx.add_child(shard)
		var stw := shard.create_tween()
		stw.tween_property(shard, "position", Vector2(cos(sa) * 145.0, sin(sa) * 90.0 - 155.0), 0.75).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

	# Colossal Vertical Sky-Splitting Crimson Cleave Beam
	var beam := Node2D.new()
	beam.position = Vector2(0.0, -160.0)
	beam.scale = Vector2(1.0, 0.05)
	slash_fx.add_child(beam)

	var outer_beam := Polygon2D.new()
	outer_beam.material = add_mat
	outer_beam.polygon = PackedVector2Array([
		Vector2(-26, 170), Vector2(-18, -160), Vector2(0, -190), Vector2(18, -160), Vector2(26, 170)
	])
	outer_beam.color = Color(crimson.r, crimson.g, crimson.b, 0.78)
	beam.add_child(outer_beam)

	var inner_beam := Polygon2D.new()
	inner_beam.material = add_mat
	inner_beam.polygon = PackedVector2Array([
		Vector2(-10, 170), Vector2(-7, -155), Vector2(0, -182), Vector2(7, -155), Vector2(10, 170)
	])
	inner_beam.color = Color("#fff1f2")
	beam.add_child(inner_beam)

	var btw := beam.create_tween()
	btw.tween_property(beam, "position", Vector2.ZERO, 0.14).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	btw.parallel().tween_property(beam, "scale", Vector2(1.15, 1.0), 0.14)

	var ftw := slash_fx.create_tween()
	ftw.tween_interval(0.50)
	ftw.tween_property(slash_fx, "modulate:a", 0.0, 0.35)
	ftw.tween_callback(slash_fx.queue_free)


# 22. หอกทะลวงอัสนีสุริยัน (Yu Han Skill [Q])
static func spawn_thunder_spear_thrust(fx_parent: Node2D, pos: Vector2, angle: float, _col: Color) -> void:
	var add_mat := _make_add_mat()
	var gold := Color("#fbbf24")
	var bright := Color("#fef08a")
	var lightning_col := Color("#93c5fd")

	var root := Node2D.new()
	root.position = pos
	root.rotation = angle
	_mount_role(fx_parent, root, "slash")

	var outer_spear := Polygon2D.new()
	outer_spear.material = add_mat
	outer_spear.polygon = PackedVector2Array([
		Vector2(-16, -7), Vector2(128, -9), Vector2(165, 0), Vector2(128, 9), Vector2(-16, 7)
	])
	outer_spear.color = Color(gold.r, gold.g, gold.b, 0.85)
	root.add_child(outer_spear)

	var core_spear := Polygon2D.new()
	core_spear.material = add_mat
	core_spear.polygon = PackedVector2Array([
		Vector2(-10, -3), Vector2(124, -3.5), Vector2(158, 0), Vector2(124, 3.5), Vector2(-10, 3)
	])
	core_spear.color = bright
	root.add_child(core_spear)

	for s_i in range(2):
		var side := -1.0 if s_i == 0 else 1.0
		var arc := Line2D.new()
		arc.material = add_mat
		var apts := PackedVector2Array()
		for k in range(7):
			var t := float(k) / 6.0
			apts.append(Vector2(lerpf(0.0, 155.0, t), side * (10.0 + sin(t * TAU * 1.5) * 14.0)))
		arc.points = apts
		arc.width = 3.0
		arc.default_color = lightning_col
		root.add_child(arc)

	var fwd := Vector2(cos(angle), sin(angle)) * 70.0
	var tw := root.create_tween()
	tw.tween_property(root, "position", pos + fwd, 0.28).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(root, "modulate:a", 0.0, 0.28)
	tw.tween_callback(root.queue_free)


# 23. วงแหวนหอกอัสนีสุริยัน + สายฟ้าฟาด (Yu Han Skill [E])
static func spawn_solar_thunder_ring(floor_parent: Node2D, fx_parent: Node2D, pos: Vector2, _col: Color) -> void:
	var add_mat := _make_add_mat()
	var gold := Color("#fbbf24")
	var bright := Color("#fef08a")
	var sky_blue := Color("#93c5fd")

	var seal := Node2D.new()
	seal.position = pos
	_mount_role(floor_parent, seal, "floor")

	var ring := Line2D.new()
	ring.material = add_mat
	var rpts := _make_ellipse(185.0, 130.0, 36)
	rpts.append(rpts[0])
	ring.points = rpts
	ring.width = 4.2
	ring.default_color = gold
	seal.add_child(ring)

	for i in range(8):
		var a := (float(i) / 8.0) * TAU
		var crack := Line2D.new()
		crack.material = add_mat
		crack.points = PackedVector2Array([
			Vector2.ZERO,
			Vector2(cos(a) * 175.0, sin(a) * 122.0),
		])
		crack.width = 2.8
		crack.default_color = bright if i % 2 == 0 else gold
		seal.add_child(crack)

	var stw := seal.create_tween()
	stw.tween_property(seal, "scale", Vector2(1.12, 1.12), 0.78)
	stw.parallel().tween_property(seal, "modulate:a", 0.0, 0.78)
	stw.tween_callback(seal.queue_free)

	var fx := Node2D.new()
	fx.position = pos
	_mount_role(fx_parent, fx, "skill_fx")

	var arc := Line2D.new()
	arc.material = add_mat
	var apts := PackedVector2Array()
	for i in range(28):
		var t := lerpf(-0.4, TAU - 0.8, float(i) / 27.0)
		apts.append(Vector2(cos(t) * 150.0, sin(t) * 105.0 - 20.0))
	arc.points = apts
	arc.width = 6.5
	arc.default_color = bright
	fx.add_child(arc)

	# Vertical blue-white sky thunderbolt slamming into center
	var bolt := Line2D.new()
	bolt.material = add_mat
	var bpts := PackedVector2Array()
	for s in range(9):
		var t := float(s) / 8.0
		var x_j := 0.0 if (s == 0 or s == 8) else randf_range(-16.0, 16.0)
		bpts.append(Vector2(x_j, lerpf(-260.0, 0.0, t)))
	bolt.points = bpts
	bolt.width = 5.5
	bolt.default_color = sky_blue
	fx.add_child(bolt)

	var burst := Polygon2D.new()
	burst.material = add_mat
	burst.polygon = _make_star_poly(78.0, 26.0, 10)
	burst.color = bright
	burst.position = Vector2(0.0, -14.0)
	fx.add_child(burst)

	var ftw := fx.create_tween()
	ftw.tween_property(fx, "rotation", 0.65, 0.45)
	ftw.tween_property(fx, "modulate:a", 0.0, 0.33)
	ftw.tween_callback(fx.queue_free)


# 24. ทัณฑ์สวรรค์เก้าชั้นฟ้า + ฝนหอกสุริยัน (Yu Han Skill [R])
static func spawn_nine_heavens_spear_judgment(floor_parent: Node2D, fx_parent: Node2D, pos: Vector2, _col: Color) -> void:
	var add_mat := _make_add_mat()
	var gold := Color("#fbbf24")
	var bright := Color("#fef08a")
	var sky_blue := Color("#93c5fd")

	var halo := Node2D.new()
	halo.position = pos
	_mount_role(floor_parent, halo, "floor")

	for spec in [[228.0, 160.0, 4.5, gold], [168.0, 118.0, 3.0, bright]]:
		var ring := Line2D.new()
		ring.material = add_mat
		var rpts := _make_ellipse(float(spec[0]), float(spec[1]), 40)
		rpts.append(rpts[0])
		ring.points = rpts
		ring.width = float(spec[2])
		ring.default_color = spec[3]
		halo.add_child(ring)

	for i in range(12):
		var a := (float(i) / 12.0) * TAU
		var spoke := Line2D.new()
		spoke.material = add_mat
		spoke.points = PackedVector2Array([
			Vector2(cos(a) * 62.0, sin(a) * 43.0),
			Vector2(cos(a) * 224.0, sin(a) * 157.0),
		])
		spoke.width = 2.6
		spoke.default_color = bright if i % 2 == 0 else gold
		halo.add_child(spoke)

	var htw := halo.create_tween()
	htw.tween_property(halo, "rotation", 0.50, 1.15)
	htw.tween_property(halo, "modulate:a", 0.0, 0.22)
	htw.tween_callback(halo.queue_free)

	var volley := Node2D.new()
	volley.position = pos
	_mount_role(fx_parent, volley, "ult_fx")

	for b_i in range(4):
		var ba := (float(b_i) / 4.0) * TAU + 0.35
		var bx := cos(ba) * 145.0
		var by := sin(ba) * 100.0
		var bolt := Line2D.new()
		bolt.material = add_mat
		var bpts := PackedVector2Array()
		for s in range(7):
			var t := float(s) / 6.0
			bpts.append(Vector2(bx + randf_range(-14.0, 14.0), lerpf(by - 250.0, by, t)))
		bolt.points = bpts
		bolt.width = 4.0
		bolt.default_color = sky_blue if b_i % 2 == 0 else bright
		volley.add_child(bolt)

	# 10 radiant Golden Solar Spears raining diagonally into the arena
	for i in range(10):
		var a := (float(i) / 10.0) * TAU
		var dst := Vector2(cos(a) * 168.0, sin(a) * 114.0)
		var spear := Polygon2D.new()
		spear.material = add_mat
		spear.polygon = PackedVector2Array([
			Vector2(-4, -95), Vector2(0, -110), Vector2(4, -95), Vector2(5, 10), Vector2(0, 26), Vector2(-5, 10)
		])
		spear.color = bright if i % 2 == 0 else gold
		spear.position = dst + Vector2(-42.0, -230.0)
		spear.rotation = 0.18
		volley.add_child(spear)
		var stw := spear.create_tween()
		stw.tween_interval(float(i) * 0.03)
		stw.tween_property(spear, "position", dst, 0.13).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)

	var vtw := volley.create_tween()
	vtw.tween_interval(0.50)
	vtw.tween_property(volley, "modulate:a", 0.0, 0.35)
	vtw.tween_callback(volley.queue_free)


# 25. ลำแสงโอสถวิญญาณมรกต (Zhao Yan Skill [Q])
static func spawn_alchemy_soul_bolt(fx_parent: Node2D, pos: Vector2, angle: float, _col: Color) -> void:
	var add_mat := _make_add_mat()
	var emerald := Color("#4ade80")
	var pale := Color("#bbf7d0")

	var root := Node2D.new()
	root.position = pos
	root.rotation = angle
	_mount_role(fx_parent, root, "slash")

	var outer_beam := Polygon2D.new()
	outer_beam.material = add_mat
	outer_beam.polygon = PackedVector2Array([
		Vector2(-8, -7), Vector2(115, -5), Vector2(145, 0), Vector2(115, 5), Vector2(-8, 7)
	])
	outer_beam.color = Color(emerald.r, emerald.g, emerald.b, 0.85)
	root.add_child(outer_beam)

	var inner_beam := Polygon2D.new()
	inner_beam.material = add_mat
	inner_beam.polygon = PackedVector2Array([
		Vector2(-4, -2.5), Vector2(112, -2.5), Vector2(140, 0), Vector2(112, 2.5), Vector2(-4, 2.5)
	])
	inner_beam.color = pale
	root.add_child(inner_beam)

	for i in range(3):
		var side := float(i - 1)
		var tendril := Line2D.new()
		tendril.material = add_mat
		var tpts := PackedVector2Array()
		for k in range(7):
			var t := float(k) / 6.0
			tpts.append(Vector2(lerpf(0.0, 140.0, t), side * (8.0 + t * 22.0) + randf_range(-6.0, 6.0)))
		tendril.points = tpts
		tendril.width = 2.8
		tendril.default_color = emerald
		root.add_child(tendril)

	var fwd := Vector2(cos(angle), sin(angle)) * 65.0
	var tw := root.create_tween()
	tw.tween_property(root, "position", pos + fwd, 0.28).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(root, "modulate:a", 0.0, 0.28)
	tw.tween_callback(root.queue_free)


# 26. วงเตาโอสถดูดวิญญาณ (Zhao Yan Skill [E])
static func spawn_soul_siphon_cauldron_ring(floor_parent: Node2D, fx_parent: Node2D, pos: Vector2, _col: Color) -> void:
	var add_mat := _make_add_mat()
	var emerald := Color("#22c55e")
	var glow_green := Color("#4ade80")
	var amber := Color("#fb923c")

	var seal := Node2D.new()
	seal.position = pos
	_mount_role(floor_parent, seal, "floor")

	var ring := Line2D.new()
	ring.material = add_mat
	var rpts := _make_ellipse(182.0, 128.0, 36)
	rpts.append(rpts[0])
	ring.points = rpts
	ring.width = 4.0
	ring.default_color = emerald
	seal.add_child(ring)

	var stw := seal.create_tween()
	stw.tween_property(seal, "rotation", -0.55, 0.80)
	stw.parallel().tween_property(seal, "modulate:a", 0.0, 0.80)
	stw.tween_callback(seal.queue_free)

	var fx := Node2D.new()
	fx.position = pos
	_mount_role(fx_parent, fx, "skill_fx")

	for i in range(8):
		var a := (float(i) / 8.0) * TAU
		var flame := Polygon2D.new()
		flame.material = add_mat
		flame.polygon = PackedVector2Array([
			Vector2(-12, 4), Vector2(-6, -42), Vector2(0, -72), Vector2(6, -38), Vector2(12, 4)
		])
		flame.color = glow_green if i % 2 == 0 else amber
		flame.position = Vector2(cos(a) * 155.0, sin(a) * 108.0)
		flame.scale = Vector2(0.4, 0.15)
		fx.add_child(flame)
		var ftw := flame.create_tween()
		ftw.tween_interval(float(i) * 0.025)
		ftw.tween_property(flame, "scale", Vector2(1.0, 1.0), 0.20)

	# 6 glowing green spirit wisps spiraling inward toward pos
	for w_i in range(6):
		var wa := (float(w_i) / 6.0) * TAU
		var wisp := Polygon2D.new()
		wisp.material = add_mat
		wisp.polygon = _make_ellipse(9.0, 12.0, 10)
		wisp.color = Color("#bbf7d0")
		wisp.position = Vector2(cos(wa) * 185.0, sin(wa) * 130.0 - 22.0)
		fx.add_child(wisp)
		var wtw := wisp.create_tween()
		wtw.tween_property(wisp, "position", Vector2(0.0, -24.0), 0.55).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)

	var end_tw := fx.create_tween()
	end_tw.tween_interval(0.45)
	end_tw.tween_property(fx, "modulate:a", 0.0, 0.35)
	end_tw.tween_callback(fx.queue_free)


# 27. มหาเตาหลอมวิญญาณมรกต (Zhao Yan Skill [R])
static func spawn_primordial_cauldron_nova(floor_parent: Node2D, fx_parent: Node2D, pos: Vector2, _col: Color) -> void:
	var add_mat := _make_add_mat()
	var emerald := Color("#22c55e")
	var bright := Color("#86efac")
	var core_green := Color("#dcfce7")

	var circle := Node2D.new()
	circle.position = pos
	_mount_role(floor_parent, circle, "floor")

	for spec in [[225.0, 158.0, 4.5, emerald], [164.0, 115.0, 3.0, bright]]:
		var ring := Line2D.new()
		ring.material = add_mat
		var rpts := _make_ellipse(float(spec[0]), float(spec[1]), 40)
		rpts.append(rpts[0])
		ring.points = rpts
		ring.width = float(spec[2])
		ring.default_color = spec[3]
		circle.add_child(ring)

	var ctw := circle.create_tween()
	ctw.tween_property(circle, "rotation", 0.65, 1.15)
	ctw.tween_property(circle, "modulate:a", 0.0, 0.22)
	ctw.tween_callback(circle.queue_free)

	var nova := Node2D.new()
	nova.position = pos
	_mount_role(fx_parent, nova, "ult_fx")

	# Expanding Emerald Soul-Nova Starburst
	var star := Polygon2D.new()
	star.material = add_mat
	star.polygon = _make_star_poly(145.0, 54.0, 14)
	star.color = Color("#4ade80")
	star.position = Vector2(0.0, -32.0)
	star.scale = Vector2(0.25, 0.25)
	nova.add_child(star)
	var stw := star.create_tween()
	stw.tween_property(star, "scale", Vector2(1.35, 1.35), 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	var inner_star := Polygon2D.new()
	inner_star.material = add_mat
	inner_star.polygon = _make_star_poly(82.0, 30.0, 10)
	inner_star.color = core_green
	inner_star.position = Vector2(0.0, -32.0)
	nova.add_child(inner_star)

	# 6 crackling emerald lightning bolts
	for b_i in range(6):
		var ba := (float(b_i) / 6.0) * TAU
		var bolt := Line2D.new()
		bolt.material = add_mat
		var bpts := PackedVector2Array()
		for s in range(6):
			var t := float(s) / 5.0
			var rad := lerpf(24.0, 210.0, t)
			bpts.append(Vector2(cos(ba) * rad + randf_range(-10.0, 10.0), sin(ba) * rad * 0.72 - 32.0 + randf_range(-10.0, 10.0)))
		bolt.points = bpts
		bolt.width = 3.6
		bolt.default_color = bright if b_i % 2 == 0 else Color("#4ade80")
		nova.add_child(bolt)

	# 14 glowing green spirit wisps surging outward
	for p_i in range(14):
		var pa := (float(p_i) / 14.0) * TAU
		var wisp := Polygon2D.new()
		wisp.material = add_mat
		wisp.polygon = PackedVector2Array([
			Vector2(0, -16), Vector2(8, -4), Vector2(5, 12), Vector2(-5, 12), Vector2(-8, -4)
		])
		wisp.color = core_green if p_i % 2 == 0 else bright
		wisp.position = Vector2(cos(pa) * 36.0, sin(pa) * 24.0 - 24.0)
		nova.add_child(wisp)
		var ptw := wisp.create_tween()
		ptw.tween_property(wisp, "position", Vector2(cos(pa) * 215.0, sin(pa) * 148.0 - 48.0), 1.05).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

	var ntw := nova.create_tween()
	ntw.tween_interval(0.50)
	ntw.tween_property(nova, "modulate:a", 0.0, 0.35)
	ntw.tween_callback(nova.queue_free)
