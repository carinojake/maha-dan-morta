extends RefCounted

const HeroData = preload("res://scripts/hero_data.gd")
const SaveManager = preload("res://scripts/save_manager.gd")
const ChapterData = preload("res://scripts/chapter_data.gd")


static func build_modal(hud: CanvasLayer, sb: StyleBoxFlat, chapter: int, callbacks: Dictionary) -> Dictionary:
	var overlay := ColorRect.new()
	overlay.color = Color(0.02, 0.03, 0.05, 0.88)
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.visible = false
	hud.add_child(overlay)

	var upg_panel := PanelContainer.new()
	upg_panel.set_anchors_preset(Control.PRESET_CENTER)
	upg_panel.position = Vector2(-380, -280)
	upg_panel.custom_minimum_size = Vector2(760, 560)
	upg_panel.add_theme_stylebox_override("panel", sb)
	overlay.add_child(upg_panel)

	var upg_root := VBoxContainer.new()
	upg_root.add_theme_constant_override("separation", 8)
	upg_panel.add_child(upg_root)

	var upg_title := Label.new()
	upg_title.text = "📜 หอคัมภีร์เซียน & จัดทัพ 10 บท (100 ชั้น)"
	upg_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	upg_title.add_theme_font_size_override("font_size", 19)
	upg_title.add_theme_color_override("font_color", Color("#fde047"))
	upg_root.add_child(upg_title)

	var jade_lbl := Label.new()
	jade_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	jade_lbl.add_theme_font_size_override("font_size", 14)
	jade_lbl.add_theme_color_override("font_color", Color("#5eead4"))
	upg_root.add_child(jade_lbl)

	var tab_row := HBoxContainer.new()
	tab_row.alignment = BoxContainer.ALIGNMENT_CENTER
	tab_row.add_theme_constant_override("separation", 10)
	upg_root.add_child(tab_row)
	var tab_btns: Array = []
	for t_item in [[0, "⚔️ อัปเกรดคัมภีร์"], [1, "👥 จัดทีม 7 จอมยุทธ์"], [2, "🗺️ เลือกด่าน 100 ชั้น"], [3, "🎒 ศาสตราวุธ"]]:
		var tb := Button.new()
		tb.text = str(t_item[1])
		tb.custom_minimum_size = Vector2(168, 34)
		tb.add_theme_font_size_override("font_size", 12)
		tb.pressed.connect(callbacks["set_tab"].bind(int(t_item[0])))
		tab_row.add_child(tb)
		tab_btns.append(tb)

	var upg_scroll := ScrollContainer.new()
	upg_scroll.custom_minimum_size = Vector2(720, 385)
	upg_root.add_child(upg_scroll)

	var upg_list := VBoxContainer.new()
	upg_list.add_theme_constant_override("separation", 5)
	upg_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	upg_scroll.add_child(upg_list)

	var party_scroll := ScrollContainer.new()
	party_scroll.custom_minimum_size = Vector2(720, 385)
	party_scroll.visible = false
	upg_root.add_child(party_scroll)

	var party_box := VBoxContainer.new()
	party_box.add_theme_constant_override("separation", 6)
	party_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	party_scroll.add_child(party_box)

	var chapters_box := VBoxContainer.new()
	chapters_box.custom_minimum_size = Vector2(720, 385)
	chapters_box.add_theme_constant_override("separation", 8)
	chapters_box.visible = false
	upg_root.add_child(chapters_box)

	var chapter_btns: Array = []
	for row_i in range(5):
		var ch_row := HBoxContainer.new()
		ch_row.alignment = BoxContainer.ALIGNMENT_CENTER
		ch_row.add_theme_constant_override("separation", 10)
		chapters_box.add_child(ch_row)
		for col_i in range(2):
			var ch_idx := row_i * 2 + col_i + 1
			var cinfo := ChapterData.get_chapter(ch_idx)
			var f_start := (ch_idx - 1) * 10 + 1
			var f_end := ch_idx * 10
			var cb := Button.new()
			var full_t := "บท %d: %s (ชั้น %d–%d)" % [ch_idx, str(cinfo["title"]), f_start, f_end]
			cb.text = ("★ " + full_t) if ch_idx == chapter else full_t
			if ch_idx == chapter:
				cb.add_theme_color_override("font_color", Color("#fde047"))
			cb.custom_minimum_size = Vector2(345, 42)
			cb.add_theme_font_size_override("font_size", 12)
			cb.pressed.connect(callbacks["jump_chapter"].bind(ch_idx))
			ch_row.add_child(cb)
			chapter_btns.append(cb)

	var zone_row := HBoxContainer.new()
	zone_row.alignment = BoxContainer.ALIGNMENT_CENTER
	zone_row.add_theme_constant_override("separation", 10)
	chapters_box.add_child(zone_row)
	for z_item in [[0, "⏩ โซน 1 (ห้อง 1)"], [4, "🛡️ โซน 2 (มินิบอส ห้อง 5)"], [9, "☠️ โซน 3 (บอสใหญ่ ห้อง 10)"]]:
		var zb := Button.new()
		zb.text = z_item[1]
		zb.custom_minimum_size = Vector2(226, 34)
		zb.add_theme_font_size_override("font_size", 12)
		zb.pressed.connect(callbacks["warp_room"].bind(int(z_item[0])))
		zone_row.add_child(zb)

	if callbacks.has("boss_rush"):
		var br_btn := Button.new()
		br_btn.text = "🔥 โหมด Boss Rush (ท้าทายบอส 10 บทต่อเนื่อง · โบนัส +150 💎)"
		br_btn.custom_minimum_size = Vector2(698, 34)
		br_btn.add_theme_font_size_override("font_size", 12)
		br_btn.add_theme_color_override("font_color", Color("#fb923c"))
		br_btn.pressed.connect(callbacks["boss_rush"])
		chapters_box.add_child(br_btn)

	var gear_scroll := ScrollContainer.new()
	gear_scroll.custom_minimum_size = Vector2(720, 385)
	gear_scroll.visible = false
	upg_root.add_child(gear_scroll)

	var gear_box := VBoxContainer.new()
	gear_box.add_theme_constant_override("separation", 6)
	gear_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	gear_scroll.add_child(gear_box)

	var tip_lbl := Label.new()
	tip_lbl.text = "ทริค: กด [E]/[R] ติดตรา -> สลับตัว [1/2/3/Tab] ใน 2.5 วิ เพื่อจุดระเบิดผสานปราณ!"
	tip_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tip_lbl.add_theme_font_size_override("font_size", 12)
	tip_lbl.add_theme_color_override("font_color", Color("#94a3b8"))
	upg_root.add_child(tip_lbl)

	var save_row := HBoxContainer.new()
	save_row.alignment = BoxContainer.ALIGNMENT_CENTER
	save_row.add_theme_constant_override("separation", 6)
	upg_root.add_child(save_row)

	var save_code_input := LineEdit.new()
	save_code_input.placeholder_text = "วางรหัสย้ายเซฟ MDM1:... ที่นี่"
	save_code_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	save_code_input.custom_minimum_size = Vector2(340, 32)
	save_code_input.add_theme_font_size_override("font_size", 12)
	save_row.add_child(save_code_input)

	var copy_save_btn := Button.new()
	copy_save_btn.text = "📤 คัดลอกเซฟ"
	copy_save_btn.custom_minimum_size = Vector2(130, 32)
	copy_save_btn.add_theme_font_size_override("font_size", 12)
	copy_save_btn.add_theme_color_override("font_color", Color("#93c5fd"))
	if callbacks.has("export_save"):
		copy_save_btn.pressed.connect(callbacks["export_save"])
	save_row.add_child(copy_save_btn)

	var import_save_btn := Button.new()
	import_save_btn.text = "📥 นำเข้าเซฟ"
	import_save_btn.custom_minimum_size = Vector2(130, 32)
	import_save_btn.add_theme_font_size_override("font_size", 12)
	import_save_btn.add_theme_color_override("font_color", Color("#4ade80"))
	if callbacks.has("import_save"):
		import_save_btn.pressed.connect(callbacks["import_save"])
	save_row.add_child(import_save_btn)

	var footer_row := HBoxContainer.new()
	footer_row.alignment = BoxContainer.ALIGNMENT_CENTER
	footer_row.add_theme_constant_override("separation", 14)
	upg_root.add_child(footer_row)

	var cutin_btn := Button.new()
	cutin_btn.text = "★ คัตอิน: เต็มจอ"
	cutin_btn.custom_minimum_size = Vector2(180, 32)
	cutin_btn.add_theme_font_size_override("font_size", 12)
	if callbacks.has("toggle_cutin"):
		cutin_btn.pressed.connect(callbacks["toggle_cutin"])
	footer_row.add_child(cutin_btn)

	var bgm_btn := Button.new()
	bgm_btn.text = "🎵 เพลง: เปิด"
	bgm_btn.custom_minimum_size = Vector2(140, 32)
	bgm_btn.add_theme_font_size_override("font_size", 12)
	if callbacks.has("toggle_bgm"):
		bgm_btn.pressed.connect(callbacks["toggle_bgm"])
	footer_row.add_child(bgm_btn)

	var close_upg := Button.new()
	close_upg.text = "ปิด [U]"
	close_upg.custom_minimum_size = Vector2(120, 32)
	close_upg.pressed.connect(callbacks["toggle"])
	footer_row.add_child(close_upg)

	return {
		"overlay": overlay,
		"jade_lbl": jade_lbl,
		"tab_btns": tab_btns,
		"upg_scroll": upg_scroll,
		"upg_list": upg_list,
		"party_scroll": party_scroll,
		"party_box": party_box,
		"chapters_box": chapters_box,
		"gear_scroll": gear_scroll,
		"gear_box": gear_box,
		"chapter_btns": chapter_btns,
		"cutin_btn": cutin_btn,
		"bgm_btn": bgm_btn,
		"save_code_input": save_code_input,
	}


static func refresh_chapters(chapter_btns: Array, current_chapter: int, cleared_chapters: Array):
	for i in range(chapter_btns.size()):
		var ch_idx := i + 1
		var cb: Button = chapter_btns[i]
		var cinfo := ChapterData.get_chapter(ch_idx)
		var f_start := (ch_idx - 1) * 10 + 1
		var f_end := ch_idx * 10
		var cleared := cleared_chapters.has(ch_idx)
		var prefix := "★ " if ch_idx == current_chapter else ("✓ " if cleared else "")
		var suffix := " · ผ่านแล้ว" if cleared else ""
		cb.text = "%sบท %d: %s (%d–%d)%s" % [prefix, ch_idx, str(cinfo["title"]), f_start, f_end, suffix]
		if ch_idx == current_chapter:
			cb.add_theme_color_override("font_color", Color("#fde047"))
		elif cleared:
			cb.add_theme_color_override("font_color", Color("#4ade80"))
		else:
			cb.remove_theme_color_override("font_color")


static func build_help_overlay(hud: CanvasLayer, sb: StyleBoxFlat, on_close: Callable, extra_callbacks: Dictionary = {}) -> ColorRect:
	var overlay := ColorRect.new()
	overlay.color = Color(0.02, 0.03, 0.05, 0.86)
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.visible = false
	hud.add_child(overlay)

	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.position = Vector2(-330, -230)
	panel.custom_minimum_size = Vector2(660, 460)
	panel.add_theme_stylebox_override("panel", sb)
	overlay.add_child(panel)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 10)
	panel.add_child(root)

	var title := Label.new()
	title.text = "⚔️ มหาแดนพันภพ: ศึกผนึกกระบี่สะบั้นสวรรค์"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", Color("#fde047"))
	root.add_child(title)

	var sub := Label.new()
	sub.text = "คู่มือจอมยุทธ์ฉบับย่อ · พิชิต 10 บท (100 ชั้น) พร้อมปาร์ตี้ 7 จอมยุทธ์"
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_font_size_override("font_size", 13)
	sub.add_theme_color_override("font_color", Color("#5eead4"))
	root.add_child(sub)

	var lines := [
		"[W A S D] หรือ [ลูกศร] — เคลื่อนที่ (เดินเข้าประตูขวาเมื่อเคลียร์ห้อง)",
		"[Space] — วิชาตัวเบา (หลบพริบตาจังหวะศัตรูตี → Slow-mo +30 ปราณ · คริ 100%)",
		"[F] / [C] — โจมตีปกติ / เปิด-ปิดโหมดตีอัตโนมัติ",
		"[Q] [E] [R] — วรยุทธ์ 3 ท่า แปะตราธาตุ (เหมันต์ · อัสนี · เพลิงโลหิต · พฤกษา)",
		"[1] [2] [3] / [Tab] — สลับตัวละครผสานปราณ & ระเบิดปฏิกิริยาธาตุ 6 คู่",
		"Combo Rank (D→SSS) — ตีต่อเนื่อง/หลบพริบตา เพิ่มดาเมจสูงสุด +35% · หยก +50%",
		"[U] คัมภีร์เซียน (อัปเกรด · จัดทีม 7 จอมยุทธ์ · เลือกบท)  |  [H] เปิด/ปิดคู่มือ",
	]
	for line in lines:
		var lbl := Label.new()
		lbl.text = "•  " + line
		lbl.add_theme_font_size_override("font_size", 13)
		lbl.add_theme_color_override("font_color", Color("#e2e8f0"))
		root.add_child(lbl)

	if extra_callbacks.has("open_party") or extra_callbacks.has("open_chapters"):
		var lobby_row := HBoxContainer.new()
		lobby_row.alignment = BoxContainer.ALIGNMENT_CENTER
		lobby_row.add_theme_constant_override("separation", 12)
		root.add_child(lobby_row)

		if extra_callbacks.has("open_party"):
			var party_quick_btn := Button.new()
			party_quick_btn.text = "👥 จัดทีม 3 จอมยุทธ์"
			party_quick_btn.custom_minimum_size = Vector2(220, 38)
			party_quick_btn.add_theme_font_size_override("font_size", 13)
			party_quick_btn.add_theme_color_override("font_color", Color("#93c5fd"))
			party_quick_btn.pressed.connect(extra_callbacks["open_party"])
			lobby_row.add_child(party_quick_btn)

		if extra_callbacks.has("open_chapters"):
			var chap_quick_btn := Button.new()
			chap_quick_btn.text = "🗺️ เลือกบท / 100 ชั้น"
			chap_quick_btn.custom_minimum_size = Vector2(220, 38)
			chap_quick_btn.add_theme_font_size_override("font_size", 13)
			chap_quick_btn.add_theme_color_override("font_color", Color("#86efac"))
			chap_quick_btn.pressed.connect(extra_callbacks["open_chapters"])
			lobby_row.add_child(chap_quick_btn)

	var start_btn := Button.new()
	start_btn.text = "⚔️ เริ่มผจญภัยทันที [Enter / H]"
	start_btn.custom_minimum_size = Vector2(280, 42)
	start_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	start_btn.add_theme_font_size_override("font_size", 14)
	start_btn.add_theme_color_override("font_color", Color("#fde047"))
	start_btn.pressed.connect(on_close)
	root.add_child(start_btn)

	return overlay


const BOON_DEFS := [
	{"id": "lightning_edge", "title": "⚡ คมศาสตราอัสนี", "desc": "พลังโจมตีพื้นฐานและสกิลของทั้งทีมแรงขึ้น +22%"},
	{"id": "swift_qi", "title": "🌀 ลมปราณไหลเวียน", "desc": "ลดคูลดาวน์สกิล [Q]/[E]/[R] ลง -20%"},
	{"id": "blood_lotus", "title": "🩸 บัวโลหิตกลืนวิญญาณ", "desc": "ฟื้นฟู +5 HP ทันทีทุกครั้งที่สังหารศัตรู"},
	{"id": "jade_aegis", "title": "🛡️ เกราะหยกนิรันดร์", "desc": "ฮีลทั้งทีม +25 HP ทันที และลดดาเมจที่ได้รับ -18%"},
	{"id": "crit_heaven", "title": "✨ เนตรสวรรค์ไร้พ่าย", "desc": "เพิ่มอัตราคริติคอล +18% ให้ทุกคนในทีม"},
	{"id": "thunder_dash", "title": "💨 ย่างก้าวสายฟ้า", "desc": "กดหลบวิชาตัวเบา ปล่อยคลื่นสายฟ้า 45 ดาเมจรอบตัว"},
	{"id": "qi_surge", "title": "🌊 วังวนปราณสวรรค์", "desc": "Max ปราณ +30 และฟื้นปราณเร็วขึ้น +35% ตลอดการต่อสู้"},
	{"id": "elemental_mastery", "title": "🔮 จอมปราณเบญจธาตุ", "desc": "ปฏิกิริยาธาตุและผสานปราณสลับตัวแรงขึ้น +35%"},
	{"id": "frost_bite", "title": "❄️ เหมันต์สะกดวิญญาณ", "desc": "ตีโดนศัตรูสร้างความเสียหายเพิ่ม +15% และหน่วงความเร็วศัตรู"},
	{"id": "swift_blade", "title": "⚔️ เพลงดาบไร้เงา", "desc": "ความเร็วเคลื่อนที่ +15% และฟันโจมตีปกติเร็วขึ้น +15%"},
	{"id": "jade_magnet", "title": "🧲 ดึงดูดโอสถหยก", "desc": "ดูดลูกแก้วฟื้นฟู HP/ปราณ จากระยะไกลและฮีลแรงขึ้น +35%"},
	{"id": "phoenix_rebirth", "title": "🔥 หงส์เพลิงคืนชีพ", "desc": "เมื่อจอมยุทธ์ถึงฆาต ฟื้นคืนชีพ 45% HP อัตโนมัติ 1 ครั้งต่อด่าน"},
]


static func build_boon_overlay(hud: CanvasLayer, sb: StyleBoxFlat, on_pick: Callable) -> Dictionary:
	var overlay := ColorRect.new()
	overlay.color = Color(0.02, 0.03, 0.06, 0.86)
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.visible = false
	hud.add_child(overlay)

	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.position = Vector2(-390, -180)
	panel.custom_minimum_size = Vector2(780, 360)
	panel.add_theme_stylebox_override("panel", sb)
	overlay.add_child(panel)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 12)
	panel.add_child(root)

	var title := Label.new()
	title.text = "⛩️ ศาลบรรพกาล — เลือกพรเซียน 1 อย่าง (กด [1] [2] [3] หรือคลิก)"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 18)
	title.add_theme_color_override("font_color", Color("#fde047"))
	root.add_child(title)

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 12)
	root.add_child(row)

	var btns: Array = []
	for i in range(3):
		var b := Button.new()
		b.custom_minimum_size = Vector2(236, 240)
		b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		b.add_theme_font_size_override("font_size", 14)
		b.pressed.connect(on_pick.bind(i))
		row.add_child(b)
		btns.append(b)

	return {"overlay": overlay, "btns": btns}


static func rebuild_lists(upg_list: VBoxContainer, party_box: VBoxContainer, jade_lbl: Label, save_data: Dictionary, active_party: Array, callbacks: Dictionary):
	for c in upg_list.get_children():
		c.queue_free()
	if party_box:
		for c in party_box.get_children():
			c.queue_free()

	var jade := int(save_data.get("spirit_jade", 0))
	jade_lbl.text = "💎 หยกปราณคงเหลือ: %d" % jade
	var cu: Dictionary = save_data.get("core_upgrades", {})
	var core_defs := [
		["hp_lv", "กายาเหล็ก (+25 Max HP ทุกคน)"],
		["sp_lv", "ทะเลปราณ (+15 Max SP ทุกคน)"],
		["atk_lv", "คมกระบี่ (+6 ATK ทุกคน)"],
		["orb_lv", "โอสถทิพย์ (+15 ฮีลจากลูกแก้ว)"],
	]
	for item in core_defs:
		var k: String = item[0]
		var title: String = item[1]
		var lv := int(cu.get(k, 0))
		var mx := SaveManager.get_core_max_lv(k)
		var cost := SaveManager.get_core_cost(k, lv)
		var b := Button.new()
		b.custom_minimum_size = Vector2(520, 32)
		b.text = "%s  [Lv.%d/%d] — %s" % [title, lv, mx, ("MAX" if lv >= mx else ("%d 💎" % cost))]
		b.disabled = lv >= mx or jade < cost
		b.pressed.connect(callbacks["buy_core"].bind(k))
		upg_list.add_child(b)

	var hp_passives: Dictionary = save_data.get("hero_passives", {})
	var p_defs := [
		["bai_yueling", "คัมภีร์ไป๋เยว่หลิง: คริติคอลแรงขึ้น 2.15x"],
		["ye_shangye", "คัมภีร์เยี่ยซางเยี่ย: ดูดเลือด R + ผสานปราณแรงขึ้น"],
		["song_ren", "คัมภีร์ซ่งเหริน: Switch-In ลดคูลดาวน์ + ฮีล 15 HP"],
		["chen_xi", "คัมภีร์เฉินซี: กระบี่โลหิตคริติคอล +10%"],
		["yu_han", "คัมภีร์อวี่หาน: หอกอัสนีแทงไกลและแรงขึ้น"],
		["zhao_yan", "คัมภีร์จ้าวเหยียน: เปลวโอสถฟื้นตนเอง +32 HP"],
		["hei_shan", "คัมภีร์เฮยซาน: พฤกษาฟื้นสำรองคนละ +22 HP"],
	]
	for pitem in p_defs:
		var hid: String = pitem[0]
		var ptitle: String = pitem[1]
		var owned := int(hp_passives.get(hid, 0)) > 0
		var pcost := SaveManager.get_passive_cost()
		var pb := Button.new()
		pb.custom_minimum_size = Vector2(520, 32)
		pb.text = "%s — %s" % [ptitle, ("ปลดล็อกแล้ว ✓" if owned else ("%d 💎" % pcost))]
		pb.disabled = owned or jade < pcost
		pb.pressed.connect(callbacks["buy_passive"].bind(hid))
		upg_list.add_child(pb)

	var party_target := party_box if party_box else upg_list
	var party_hdr := Label.new()
	party_hdr.text = "── จัดปาร์ตี้ 3 คน & สลับชุด (7 จอมยุทธ์) ──"
	party_hdr.add_theme_font_size_override("font_size", 14)
	party_hdr.add_theme_color_override("font_color", Color("#fde047"))
	party_hdr.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	party_target.add_child(party_hdr)

	var costumes: Dictionary = save_data.get("costumes", {})
	for hid in HeroData.HERO_ORDER:
		var hdata: Dictionary = HeroData.HEROES[hid]
		var slot_idx := active_party.find(hid)
		var in_party := slot_idx != -1
		var mode: String = str(costumes.get(hid, "default"))
		var row := HBoxContainer.new()
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		row.add_theme_constant_override("separation", 8)

		var pick_btn := Button.new()
		pick_btn.custom_minimum_size = Vector2(430, 38)
		var status_txt := ("ในทีม #%d (กดนำออก/สลับ)" % (slot_idx + 1)) if in_party else "นอกทีม (กดเข้าทีม)"
		pick_btn.text = "%s (%s) · %s" % [hdata["name"], hdata["title"], status_txt]
		if in_party:
			pick_btn.add_theme_color_override("font_color", Color("#fde047"))
		pick_btn.pressed.connect(callbacks["toggle_party"].bind(hid))
		row.add_child(pick_btn)

		var skin_btn := Button.new()
		skin_btn.custom_minimum_size = Vector2(250, 38)
		var alt_label: String = str(hdata.get("alt_name", "ชุดทางเลือก"))
		skin_btn.text = "ชุด: %s" % (alt_label if mode == "alt" else "ชุดเดิม")
		skin_btn.pressed.connect(callbacks["toggle_costume"].bind(hid))
		row.add_child(skin_btn)

		party_target.add_child(row)
