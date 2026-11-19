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


static func _make_add_mat() -> CanvasItemMaterial:
	var m := CanvasItemMaterial.new()
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	return m


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
	parent.add_child(root)
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
	parent.add_child(root)
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
	floor_parent.add_child(seal)

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
	fx_parent.add_child(spikes)
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
	floor_parent.add_child(root)
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
	floor_parent.add_child(seal)
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
	fx_parent.add_child(pillar)

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
	fx_parent.add_child(blade)

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
