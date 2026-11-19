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


# 7. คลื่นกระบี่จันทร์เสี้ยวเหมันต์ (Phase 1 — Bai Yueling Skill [Q])
static func spawn_ice_crescent_wave(fx_parent: Node2D, pos: Vector2, angle: float, col: Color) -> void:
	var add_mat := _make_add_mat()
	var bright := col.lightened(0.55)
	var root := Node2D.new()
	root.position = pos
	root.rotation = angle
	fx_parent.add_child(root)

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
	floor_parent.add_child(lotus)

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
	fx_parent.add_child(halo)
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
	floor_parent.add_child(array_node)

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
	atw.tween_property(array_node, "rotation", 0.55, 1.25)
	atw.tween_property(array_node, "modulate:a", 0.0, 0.25)
	atw.tween_callback(array_node.queue_free)

	# 10 Perimeter Jagged Ice Crystal Pillars
	var pillars := Node2D.new()
	pillars.position = pos
	fx_parent.add_child(pillars)
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
	ftw.tween_interval(0.95)
	ftw.tween_property(pillars, "modulate:a", 0.0, 0.35)
	ftw.tween_callback(pillars.queue_free)
