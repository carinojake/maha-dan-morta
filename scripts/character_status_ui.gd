extends RefCounted

const HeroData = preload("res://scripts/hero_data.gd")
const EquipData = preload("res://scripts/equip_data.gd")
const SaveManager = preload("res://scripts/save_manager.gd")
const CombatSystem = preload("res://scripts/combat_system.gd")


static func _compute_hero_stats(save_data: Dictionary, hid: String, override_slot: String = "", override_item_id: String = "") -> Dictionary:
	var base: Dictionary = HeroData.HEROES[hid]
	var cu: Dictionary = save_data.get("core_upgrades", {})
	var hg: Dictionary = save_data.get("hero_gear", {}).duplicate(true)
	if not override_slot.is_empty():
		var slots: Dictionary = hg.get(hid, {}).duplicate()
		if override_item_id.is_empty():
			slots.erase(override_slot)
		else:
			slots[override_slot] = override_item_id
		hg[hid] = slots
	var gear := EquipData.get_bonuses_for_hero(hg, hid, save_data.get("gear_levels", {}))
	var max_hp := (float(base["max_hp"]) + float(cu.get("hp_lv", 0)) * 25.0 + float(gear["max_hp"])) * (1.0 + float(gear.get("max_hp_pct", 0.0)))
	var max_sp := (float(base["max_sp"]) + float(cu.get("sp_lv", 0)) * 15.0 + float(gear["max_sp"])) * (1.0 + float(gear.get("max_sp_pct", 0.0)))
	var atk := (float(base["atk"]) + float(cu.get("atk_lv", 0)) * 6.0 + float(gear["atk"])) * (1.0 + float(gear.get("atk_pct", 0.0)))
	var crit := (float(base["crit"]) + float(gear["crit"])) * 100.0
	var dmg_red := float(gear.get("dmg_red", 0.0)) * 100.0
	var speed := float(base["speed"])
	return {
		"max_hp": int(round(max_hp)),
		"max_sp": int(round(max_sp)),
		"atk": int(round(atk)),
		"crit": crit,
		"dmg_red": dmg_red,
		"speed": int(round(speed)),
		"set_realm": str(gear.get("set_realm", "")),
	}


static func build_view(container: VBoxContainer, state: Dictionary, callbacks: Dictionary):
	if not container:
		return
	for ch in container.get_children():
		ch.queue_free()

	var save_data: Dictionary = state.get("save_data", {})
	var active_party: Array = state.get("active_party", [])
	var selected_hid: String = str(state.get("selected_hid", active_party[0] if active_party.size() > 0 else "bai_yueling"))
	if not HeroData.HEROES.has(selected_hid):
		selected_hid = "bai_yueling"
	var drawer_slot: String = str(state.get("drawer_slot", ""))
	var preview_item_id: String = str(state.get("preview_item_id", ""))
	var is_portrait: bool = bool(state.get("is_portrait", false))

	# Top Hero Selector Bar (7 Heroes)
	var hero_bar: Container = HFlowContainer.new() if is_portrait else HBoxContainer.new()
	if is_portrait:
		(hero_bar as HFlowContainer).alignment = FlowContainer.ALIGNMENT_CENTER
		(hero_bar as HFlowContainer).add_theme_constant_override("h_separation", 4)
		(hero_bar as HFlowContainer).add_theme_constant_override("v_separation", 4)
	else:
		(hero_bar as HBoxContainer).alignment = BoxContainer.ALIGNMENT_CENTER
		(hero_bar as HBoxContainer).add_theme_constant_override("separation", 4)
	container.add_child(hero_bar)

	for hid in HeroData.HERO_ORDER:
		var hinfo: Dictionary = HeroData.HEROES[hid]
		var in_party: bool = active_party.has(hid)
		var is_sel: bool = (str(hid) == selected_hid)
		var hb := Button.new()
		hb.custom_minimum_size = Vector2(92 if is_portrait else 96, 36 if is_portrait else 32)
		hb.add_theme_font_size_override("font_size", 11)
		hb.text = ("%s%s" % [("★ " if in_party else ""), str(hinfo["name"]).split(" ")[0]])
		if is_sel:
			hb.add_theme_color_override("font_color", Color("#fde047"))
		elif in_party:
			hb.add_theme_color_override("font_color", Color("#4ade80"))
		hb.pressed.connect(callbacks["select_hero"].bind(hid))
		hero_bar.add_child(hb)

	var hdata: Dictionary = HeroData.HEROES[selected_hid]
	var cur_slots: Dictionary = save_data.get("hero_gear", {}).get(selected_hid, {})
	var gl: Dictionary = save_data.get("gear_levels", {})
	var owned_gear: Array = save_data.get("owned_gear", [])
	var jade := int(save_data.get("spirit_jade", 0))

	# Stat computation + real-time Stat Preview delta
	var cur_stats := _compute_hero_stats(save_data, selected_hid)
	var prev_stats := cur_stats
	if not drawer_slot.is_empty() and not preview_item_id.is_empty():
		var eq_id := str(cur_slots.get(drawer_slot, ""))
		var target_id := "" if eq_id == preview_item_id else preview_item_id
		prev_stats = _compute_hero_stats(save_data, selected_hid, drawer_slot, target_id)

	var body_root: Control
	var left_col := VBoxContainer.new()
	left_col.add_theme_constant_override("separation", 6)
	var center_col := VBoxContainer.new()
	center_col.add_theme_constant_override("separation", 6)
	center_col.alignment = BoxContainer.ALIGNMENT_CENTER
	var right_col := VBoxContainer.new()
	right_col.add_theme_constant_override("separation", 5)

	if is_portrait:
		var root_vb := VBoxContainer.new()
		root_vb.add_theme_constant_override("separation", 8)
		root_vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		container.add_child(root_vb)
		var top_hb := HBoxContainer.new()
		top_hb.add_theme_constant_override("separation", 10)
		root_vb.add_child(top_hb)
		center_col.custom_minimum_size = Vector2(150, 175)
		right_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		left_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		top_hb.add_child(center_col)
		top_hb.add_child(right_col)
		root_vb.add_child(left_col)
		body_root = root_vb
	else:
		var root_hb := HBoxContainer.new()
		root_hb.add_theme_constant_override("separation", 12)
		root_hb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		container.add_child(root_hb)
		center_col.custom_minimum_size = Vector2(180, 310)
		left_col.custom_minimum_size = Vector2(332, 310)
		right_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		root_hb.add_child(center_col)
		root_hb.add_child(left_col)
		root_hb.add_child(right_col)
		body_root = root_hb

	# --- LEFT / CENTER COLUMN: Full-Proportion HD-2D Hero on Bagua Pedestal ---
	var ped := PanelContainer.new()
	var ped_sb := StyleBoxFlat.new()
	ped_sb.bg_color = Color(0.05, 0.08, 0.13, 0.94)
	ped_sb.border_color = Color("#d6ad4f")
	ped_sb.set_border_width_all(2)
	ped_sb.set_corner_radius_all(12)
	ped_sb.content_margin_left = 8
	ped_sb.content_margin_right = 8
	ped_sb.content_margin_top = 8
	ped_sb.content_margin_bottom = 8
	ped.add_theme_stylebox_override("panel", ped_sb)
	center_col.add_child(ped)

	var ped_vb := VBoxContainer.new()
	ped_vb.alignment = BoxContainer.ALIGNMENT_CENTER
	ped_vb.add_theme_constant_override("separation", 4)
	ped.add_child(ped_vb)

	var portrait_rect := TextureRect.new()
	portrait_rect.name = "HeroFullPortrait"
	portrait_rect.custom_minimum_size = Vector2(124 if is_portrait else 156, 140 if is_portrait else 210)
	portrait_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	var hd_idle_path := "res://assets/hd2d/%s_hd_idle.png" % selected_hid
	if ResourceLoader.exists(hd_idle_path):
		portrait_rect.texture = load(hd_idle_path)
	elif callbacks.has("get_portrait"):
		portrait_rect.texture = callbacks["get_portrait"].call(selected_hid)
	ped_vb.add_child(portrait_rect)

	var bagua_lbl := Label.new()
	bagua_lbl.text = "☯ แท่นปราณแปดทิศ"
	bagua_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bagua_lbl.add_theme_font_size_override("font_size", 11)
	bagua_lbl.add_theme_color_override("font_color", Color("#d6ad4f"))
	ped_vb.add_child(bagua_lbl)

	# --- RIGHT COLUMN: Identity, Element, 5 Stats + Live Delta, Q/E/R ---
	var elem_id := CombatSystem.get_hero_element(selected_hid)
	var elem_info := CombatSystem.get_element_info(elem_id)
	var title_lbl := Label.new()
	title_lbl.text = "%s (%s) · %s %s" % [str(hdata["name"]), str(hdata["title"]), str(elem_info["icon"]), str(elem_info["name"])]
	title_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title_lbl.add_theme_font_size_override("font_size", 13)
	title_lbl.add_theme_color_override("font_color", Color(elem_info["color"]))
	right_col.add_child(title_lbl)

	var stat_defs := [
		["HP", "max_hp", false],
		["ปราณ", "max_sp", false],
		["ATK", "atk", false],
		["CRIT", "crit", true],
		["ลดดาเมจ", "dmg_red", true],
		["SPD", "speed", false],
	]
	var delta_labels: Dictionary = {}
	for sd in stat_defs:
		var s_label: String = sd[0]
		var s_key: String = sd[1]
		var is_pct: bool = sd[2]
		var v_cur := float(cur_stats[s_key])

		var srow := HBoxContainer.new()
		srow.add_theme_constant_override("separation", 6)
		right_col.add_child(srow)

		var k_lbl := Label.new()
		k_lbl.custom_minimum_size = Vector2(56, 20)
		k_lbl.text = s_label
		k_lbl.add_theme_font_size_override("font_size", 12)
		k_lbl.add_theme_color_override("font_color", Color("#94a3b8"))
		srow.add_child(k_lbl)

		var v_lbl := Label.new()
		v_lbl.text = ("%.1f%%" % v_cur) if is_pct else str(int(round(v_cur)))
		v_lbl.add_theme_font_size_override("font_size", 12)
		v_lbl.add_theme_color_override("font_color", Color("#f8fafc"))
		srow.add_child(v_lbl)

		var d_lbl := Label.new()
		d_lbl.add_theme_font_size_override("font_size", 12)
		d_lbl.visible = false
		srow.add_child(d_lbl)
		delta_labels[s_key] = d_lbl

	update_stat_preview(delta_labels, save_data, selected_hid, drawer_slot, preview_item_id)

	var skill_lbl := Label.new()
	skill_lbl.text = "Q: %s (%d) | E: %s (%d)\nR: %s (%d)" % [
		str(hdata["q_name"]), int(hdata["q_cost"]),
		str(hdata["e_name"]), int(hdata["e_cost"]),
		str(hdata["r_name"]), int(hdata["r_cost"]),
	]
	skill_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	skill_lbl.add_theme_font_size_override("font_size", 11)
	skill_lbl.add_theme_color_override("font_color", Color("#cbd5e1"))
	right_col.add_child(skill_lbl)

	# --- LEFT COLUMN: Slots Grid OR Quick Drawer ---
	if drawer_slot.is_empty():
		var grid := GridContainer.new()
		grid.name = "SlotsGrid"
		grid.columns = 2
		grid.add_theme_constant_override("h_separation", 6)
		grid.add_theme_constant_override("v_separation", 6)
		left_col.add_child(grid)

		for slot_def in [
			["weapon", "⚔️ ศาสตราวุธ"],
			["relic", "🔮 เครื่องราง"],
		]:
			var sk: String = slot_def[0]
			var sname: String = slot_def[1]
			var eq_id := str(cur_slots.get(sk, ""))
			var eq_name := str(EquipData.get_item(eq_id).get("name", "ว่าง (แตะใส่)"))
			var eq_lv := int(gl.get(eq_id, 0))
			var lv_s := (" +%d" % eq_lv) if (not eq_id.is_empty() and eq_lv > 0) else ""
			var sb_btn := Button.new()
			sb_btn.name = "Slot_" + sk
			sb_btn.custom_minimum_size = Vector2(130, 54)
			sb_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			sb_btn.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			sb_btn.add_theme_font_size_override("font_size", 11)
			sb_btn.text = "%s\n%s%s" % [sname, eq_name, lv_s]
			if not eq_id.is_empty():
				sb_btn.add_theme_color_override("font_color", Color("#fde047"))
			sb_btn.pressed.connect(callbacks["open_drawer"].bind(sk))
			grid.add_child(sb_btn)

		var cos_mode := str(save_data.get("costumes", {}).get(selected_hid, "default"))
		var cos_name := str(hdata.get("alt_name", "ชุดทางเลือก")) if cos_mode == "alt" else "ชุดเดิม"
		var cos_btn := Button.new()
		cos_btn.name = "Slot_costume"
		cos_btn.custom_minimum_size = Vector2(130, 54)
		cos_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		cos_btn.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		cos_btn.add_theme_font_size_override("font_size", 11)
		cos_btn.text = "👘 อาภรณ์\n%s (สลับ)" % cos_name
		cos_btn.pressed.connect(callbacks["toggle_costume"].bind(selected_hid))
		grid.add_child(cos_btn)

		var pas_owned := int(save_data.get("hero_passives", {}).get(selected_hid, 0)) > 0
		var pcost := SaveManager.get_passive_cost()
		var pas_btn := Button.new()
		pas_btn.name = "Slot_passive"
		pas_btn.custom_minimum_size = Vector2(130, 54)
		pas_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		pas_btn.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		pas_btn.add_theme_font_size_override("font_size", 11)
		pas_btn.text = "📖 คัมภีร์ปราณ\n%s" % ("ปลดล็อกแล้ว ✓" if pas_owned else ("ปลดล็อก %d 💎" % pcost))
		pas_btn.disabled = pas_owned or jade < pcost
		if pas_owned:
			pas_btn.add_theme_color_override("font_color", Color("#4ade80"))
		pas_btn.pressed.connect(callbacks["buy_passive"].bind(selected_hid))
		grid.add_child(pas_btn)

		var ar_id := str(cur_slots.get("armor", ""))
		var ar_name := str(EquipData.get_item(ar_id).get("name", "ว่าง (แตะใส่)"))
		var ar_lv := int(gl.get(ar_id, 0))
		var ar_lv_s := (" +%d" % ar_lv) if (not ar_id.is_empty() and ar_lv > 0) else ""
		var ar_btn := Button.new()
		ar_btn.name = "Slot_armor"
		ar_btn.custom_minimum_size = Vector2(266, 40)
		ar_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		ar_btn.add_theme_font_size_override("font_size", 11)
		ar_btn.text = "🛡️ เครื่องป้องกัน: %s%s" % [ar_name, ar_lv_s]
		if not ar_id.is_empty():
			ar_btn.add_theme_color_override("font_color", Color("#fde047"))
		ar_btn.pressed.connect(callbacks["open_drawer"].bind("armor"))
		left_col.add_child(ar_btn)

		var rprog := EquipData.get_realm_progress(save_data.get("hero_gear", {}), selected_hid)
		var realm := str(rprog.get("active_realm", ""))
		var set_lbl := Label.new()
		set_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		set_lbl.add_theme_font_size_override("font_size", 11)
		if not realm.is_empty() and EquipData.REALM_SET_BONUSES.has(realm):
			var set_def: Dictionary = EquipData.REALM_SET_BONUSES[realm]
			set_lbl.text = "✨ เปิดใช้งาน (3/3) %s\n%s" % [str(set_def["name"]), str(set_def["desc"])]
			set_lbl.add_theme_color_override("font_color", Color("#4ade80"))
		else:
			var b_rm := str(rprog.get("best_realm", ""))
			var b_cnt := int(rprog.get("best_count", 0))
			if b_cnt > 0 and EquipData.REALM_SET_BONUSES.has(b_rm):
				var p_def: Dictionary = EquipData.REALM_SET_BONUSES[b_rm]
				set_lbl.text = "☯ เงื่อนไขโบนัสเซ็ตภพ%s (%d/3 ชิ้น)\nสวมครบ 3 ช่องภพ%sเพื่อปลดล็อก: %s" % [b_rm, b_cnt, b_rm, str(p_def["desc"])]
			else:
				set_lbl.text = "☯ โบนัสเซ็ต 4 ภพ (0/3 ชิ้น)\nสวมอาวุธ + เกราะ + เครื่องรางภพเดียวกันครบ 3 ช่องเพื่อปลดล็อกโบนัสเซ็ต"
			set_lbl.add_theme_color_override("font_color", Color("#93c5fd"))
		left_col.add_child(set_lbl)
	else:
		# Quick Drawer Mode
		var d_hdr := HBoxContainer.new()
		d_hdr.add_theme_constant_override("separation", 6)
		left_col.add_child(d_hdr)

		var back_btn := Button.new()
		back_btn.name = "DrawerBackBtn"
		back_btn.text = "✕ กลับ"
		back_btn.custom_minimum_size = Vector2(76, 36)
		back_btn.add_theme_font_size_override("font_size", 11)
		back_btn.pressed.connect(callbacks["close_drawer"])
		d_hdr.add_child(back_btn)

		var slot_title := "⚔️ เลือกศาสตราวุธ" if drawer_slot == "weapon" else ("🛡️ เลือกเครื่องป้องกัน" if drawer_slot == "armor" else "🔮 เลือกเครื่องราง")
		var d_lbl := Label.new()
		d_lbl.text = slot_title
		d_lbl.add_theme_font_size_override("font_size", 12)
		d_lbl.add_theme_color_override("font_color", Color("#fde047"))
		d_hdr.add_child(d_lbl)

		var d_scroll := ScrollContainer.new()
		d_scroll.custom_minimum_size = Vector2(260, 200 if is_portrait else 255)
		d_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
		left_col.add_child(d_scroll)

		var d_list := VBoxContainer.new()
		d_list.name = "DrawerItemList"
		d_list.add_theme_constant_override("separation", 5)
		d_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		d_scroll.add_child(d_list)

		for item_id in EquipData.ITEM_ORDER:
			var it := EquipData.get_item(item_id)
			if str(it.get("slot", "")) != drawer_slot:
				continue
			var is_owned: bool = owned_gear.has(item_id)
			var is_eq: bool = str(cur_slots.get(drawer_slot, "")) == str(item_id)
			var lv := int(gl.get(item_id, 0))
			var lv_tag := (" +%d" % lv) if lv > 0 else ""

			var holder_hid := EquipData.find_item_holder(save_data.get("hero_gear", {}), str(item_id))
			var held_other: bool = (not holder_hid.is_empty() and holder_hid != selected_hid)
			var holder_name := str(HeroData.HEROES.get(holder_hid, {}).get("name", holder_hid)).split(" ")[0] if held_other else ""

			var irow := HBoxContainer.new()
			irow.add_theme_constant_override("separation", 4)
			d_list.add_child(irow)

			var inspect_b := Button.new()
			inspect_b.name = "InspectBtn_" + str(item_id)
			inspect_b.text = "ดู"
			inspect_b.tooltip_text = "ดูเปรียบเทียบค่าสถานะและเงื่อนไขเซ็ต"
			inspect_b.custom_minimum_size = Vector2(36, 42)
			inspect_b.add_theme_font_size_override("font_size", 10)
			if preview_item_id == str(item_id):
				inspect_b.add_theme_color_override("font_color", Color("#fde047"))
			inspect_b.pressed.connect(func():
				update_stat_preview(delta_labels, save_data, selected_hid, drawer_slot, str(item_id))
				if callbacks.has("preview_item"):
					callbacks["preview_item"].call(str(item_id))
			)
			irow.add_child(inspect_b)

			var pick := Button.new()
			pick.name = "ItemBtn_" + str(item_id)
			pick.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			pick.custom_minimum_size = Vector2(124, 42)
			pick.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			pick.add_theme_font_size_override("font_size", 11)
			if is_eq:
				pick.text = "✓ %s%s (ถอดออก)" % [str(it["name"]), lv_tag]
				pick.add_theme_color_override("font_color", Color("#4ade80"))
			elif is_owned and held_other:
				pick.text = "%s%s (ย้าย: %s)" % [str(it["name"]), lv_tag, holder_name]
				pick.add_theme_color_override("font_color", Color("#fbbf24"))
			elif is_owned:
				pick.text = "%s%s (สวมใส่)" % [str(it["name"]), lv_tag]
			else:
				var fcost := int(it.get("cost", 50))
				pick.text = "%s (หลอม %d💎)" % [str(it["name"]), fcost]
				if jade < fcost:
					pick.add_theme_color_override("font_color", Color("#94a3b8"))
			pick.mouse_entered.connect(func(): update_stat_preview(delta_labels, save_data, selected_hid, drawer_slot, str(item_id)))
			pick.mouse_exited.connect(func(): update_stat_preview(delta_labels, save_data, selected_hid, drawer_slot, preview_item_id))
			pick.button_down.connect(func(): update_stat_preview(delta_labels, save_data, selected_hid, drawer_slot, str(item_id)))
			if is_owned:
				pick.pressed.connect(callbacks["equip_item"].bind(selected_hid, item_id))
			else:
				pick.pressed.connect(func():
					update_stat_preview(delta_labels, save_data, selected_hid, drawer_slot, str(item_id))
					if jade >= int(it.get("cost", 50)):
						callbacks["forge_item"].call(item_id)
					elif callbacks.has("preview_item"):
						callbacks["preview_item"].call(str(item_id))
				)
			irow.add_child(pick)

			if is_owned:
				var eb := Button.new()
				eb.name = "EnhanceBtn_" + str(item_id)
				eb.custom_minimum_size = Vector2(72, 42)
				eb.add_theme_font_size_override("font_size", 10)
				if lv >= EquipData.MAX_ENHANCE_LV:
					eb.text = "MAX"
					eb.disabled = true
				else:
					var ec := EquipData.get_enhance_cost(item_id, lv)
					eb.text = "+%d\n%d💎" % [lv + 1, ec]
					eb.disabled = jade < ec
				eb.pressed.connect(callbacks["enhance_item"].bind(item_id))
				irow.add_child(eb)

	container.set_meta("delta_labels", delta_labels)


static func update_stat_preview(delta_labels: Dictionary, save_data: Dictionary, hid: String, drawer_slot: String, preview_item_id: String):
	if delta_labels.is_empty():
		return
	if drawer_slot.is_empty() or preview_item_id.is_empty():
		for k in delta_labels.keys():
			var dl: Label = delta_labels[k]
			if is_instance_valid(dl):
				dl.visible = false
		return
	var cur_slots: Dictionary = save_data.get("hero_gear", {}).get(hid, {})
	var eq_id := str(cur_slots.get(drawer_slot, ""))
	var target_id := "" if eq_id == preview_item_id else preview_item_id
	var cur_stats := _compute_hero_stats(save_data, hid)
	var prev_stats := _compute_hero_stats(save_data, hid, drawer_slot, target_id)
	for sd in [["max_hp", false], ["max_sp", false], ["atk", false], ["crit", true], ["dmg_red", true], ["speed", false]]:
		var s_key: String = sd[0]
		var is_pct: bool = sd[1]
		if not delta_labels.has(s_key):
			continue
		var dl: Label = delta_labels[s_key]
		if not is_instance_valid(dl):
			continue
		var diff := float(prev_stats[s_key]) - float(cur_stats[s_key])
		if absf(diff) >= 0.05:
			var sign_str := "▲ +" if diff > 0.0 else "▼ "
			dl.text = ("%s%.1f%%" % [sign_str, diff]) if is_pct else ("%s%d" % [sign_str, int(round(diff))])
			dl.add_theme_color_override("font_color", Color("#4ade80") if diff > 0.0 else Color("#f87171"))
			dl.visible = true
		else:
			dl.visible = false
