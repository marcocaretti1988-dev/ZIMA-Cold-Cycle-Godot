class_name Hud
extends Node
## Interfaccia: effetto VHS, barre, obiettivo, testi a macchina da scrivere,
## zaino, pannelli degli enigmi, menu, comandi touch.

signal chapter_picked(id: int)
signal menu_requested
signal eat_requested

const INK := Color(0.87, 0.90, 0.93)
const DIM := Color(0.87, 0.90, 0.93, 0.55)
const WARM := Color(1.0, 0.72, 0.40)
const RU := "#ffb766"

var post: ColorRect
var post_mat: ShaderMaterial
var root: Control
var bars: Control
var objective: Label
var prompt: Label
var msg: Label
var msg_t := 0.0
var dlg: PanelContainer
var dlg_speaker: Label
var dlg_text: RichTextLabel
var dlg_more: Label
var queue := []
var typing := false
var chars := 0.0
var last_adv := 0.0
var panel: PanelContainer
var panel_title: Label
var panel_schema: RichTextLabel
var panel_msg: RichTextLabel
var panel_btns: HBoxContainer
var bag: PanelContainer
var bag_box: VBoxContainer
var title: Control
var title_grid: GridContainer
var gfx_btn: Button
var end_screen: Control
var end_box: VBoxContainer
var touch_root: Control
var joy := Vector2.ZERO
var joy_id := -1
var joy_origin := Vector2.ZERO
var joy_draw: Control
var run_toggle := false
var tbuttons := []
var help_pulse := 0.0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var l0 := CanvasLayer.new()
	l0.layer = 1
	add_child(l0)
	post = ColorRect.new()
	post.set_anchors_preset(Control.PRESET_FULL_RECT)
	post.mouse_filter = Control.MOUSE_FILTER_IGNORE
	post_mat = ShaderMaterial.new()
	post_mat.shader = load("res://shaders/post.gdshader")
	post.material = post_mat
	l0.add_child(post)
	var l1 := CanvasLayer.new()
	l1.layer = 2
	add_child(l1)
	root = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l1.add_child(root)
	_build_status()
	_build_dialog()
	_build_touch()
	_build_panel()
	_build_bag()
	_build_end()
	_build_title()
	get_viewport().size_changed.connect(_layout_touch)
	_layout_touch()

# ------------------------------------------------------------------ utilità

func _label(text: String, size: int, col := INK) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.7))
	l.add_theme_constant_override("shadow_offset_x", 1)
	l.add_theme_constant_override("shadow_offset_y", 2)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l

func _style(bg: Color, border := Color(1, 1, 1, 0.25), pad := 16) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(1)
	s.set_content_margin_all(pad)
	return s

func _button(text: String, size := 20) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", size)
	b.add_theme_color_override("font_color", INK)
	b.add_theme_color_override("font_disabled_color", Color(1, 1, 1, 0.28))
	b.add_theme_stylebox_override("normal", _style(Color(0.05, 0.07, 0.10, 0.82), Color(1, 1, 1, 0.3), 10))
	b.add_theme_stylebox_override("hover", _style(Color(0.12, 0.15, 0.20, 0.9), WARM, 10))
	b.add_theme_stylebox_override("pressed", _style(Color(0.2, 0.16, 0.10, 0.95), WARM, 10))
	b.add_theme_stylebox_override("disabled", _style(Color(0.04, 0.05, 0.07, 0.6), Color(1, 1, 1, 0.1), 10))
	return b

static func q(text: String) -> String:
	return "[color=%s]%s[/color]" % [RU, text]

# ------------------------------------------------------------------ stato

func _build_status() -> void:
	bars = Control.new()
	bars.position = Vector2(22, 16)
	bars.size = Vector2(330, 96)
	bars.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bars.draw.connect(_draw_bars)
	root.add_child(bars)
	objective = _label("", 19, INK)
	objective.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	objective.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	objective.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	objective.offset_left = -470
	objective.offset_right = -22
	objective.offset_top = 16
	objective.offset_bottom = 90
	root.add_child(objective)
	msg = _label("", 22, INK)
	msg.set_anchors_preset(Control.PRESET_CENTER_TOP)
	msg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	msg.offset_left = -400
	msg.offset_right = 400
	msg.offset_top = 110
	msg.offset_bottom = 180
	msg.modulate.a = 0.0
	root.add_child(msg)
	prompt = _label("", 22, WARM)
	prompt.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt.offset_left = -400
	prompt.offset_right = 400
	prompt.offset_top = -222
	prompt.offset_bottom = -190
	root.add_child(prompt)

func _draw_bars() -> void:
	if not Game.started:
		return
	var f := ThemeDB.fallback_font
	var blink := fmod(Time.get_ticks_msec() / 1000.0, 1.2) < 0.7
	if blink:
		bars.draw_circle(Vector2(8, 10), 6, Color(0.9, 0.15, 0.12))
	bars.draw_string(f, Vector2(22, 16), "REC   12.02.1991   23:40", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, DIM)
	_bar(f, 40, "CALORE", Game.heat, Color(1.0, 0.55, 0.25) if Game.heat > 25.0 else Color(0.55, 0.8, 1.0))
	_bar(f, 68, "TORCIA", Game.battery, WARM if Game.torch else Color(0.7, 0.72, 0.75))

func _bar(f: Font, y: float, name: String, val: float, col: Color) -> void:
	bars.draw_string(f, Vector2(0, y + 14), name, HORIZONTAL_ALIGNMENT_LEFT, -1, 17, INK)
	var n := 10
	var k := int(round(clamp(val, 0.0, 100.0) / 100.0 * n))
	for i in n:
		var r := Rect2(88 + i * 19, y, 15, 15)
		if i < k:
			bars.draw_rect(r, col)
		else:
			bars.draw_rect(r, Color(1, 1, 1, 0.28), false, 1.5)

# ------------------------------------------------------------------ dialoghi

func _build_dialog() -> void:
	dlg = PanelContainer.new()
	dlg.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	dlg.offset_left = 150
	dlg.offset_right = -150
	dlg.offset_top = -178
	dlg.offset_bottom = -22
	dlg.add_theme_stylebox_override("panel", _style(Color(0.02, 0.03, 0.05, 0.86), Color(1, 1, 1, 0.22), 18))
	dlg.visible = false
	dlg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(dlg)
	var vb := VBoxContainer.new()
	vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dlg.add_child(vb)
	dlg_speaker = _label("", 16, WARM)
	vb.add_child(dlg_speaker)
	dlg_text = RichTextLabel.new()
	dlg_text.bbcode_enabled = true
	dlg_text.scroll_active = false
	dlg_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	dlg_text.add_theme_font_size_override("normal_font_size", 23)
	dlg_text.add_theme_color_override("default_color", INK)
	dlg_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.add_child(dlg_text)
	dlg_more = _label("▼", 16, DIM)
	dlg_more.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	vb.add_child(dlg_more)

func say(lines, speaker := "") -> void:
	if lines is String:
		lines = [lines]
	for l in lines:
		queue.append({"t": str(l), "s": speaker})
	if not dlg.visible:
		_next()

func act(fn: Callable) -> void:
	queue.append({"fn": fn})
	if not dlg.visible:
		_next()

func tell(key: String, lines, speaker := "") -> void:
	if Game.told.has(key):
		return
	Game.told[key] = true
	say(lines, speaker)

func reading() -> bool:
	return dlg.visible

func _next() -> void:
	while not queue.is_empty() and queue[0].has("fn"):
		var e = queue.pop_front()
		e["fn"].call()
	if queue.is_empty():
		dlg.visible = false
		return
	var e2 = queue.pop_front()
	dlg.visible = true
	dlg_speaker.text = e2["s"]
	dlg_speaker.visible = e2["s"] != ""
	dlg_text.text = e2["t"]
	dlg_text.visible_characters = 0
	chars = 0.0
	typing = true
	dlg_more.visible = false

func advance() -> void:
	var now := Time.get_ticks_msec() / 1000.0
	if now - last_adv < 0.16 or not dlg.visible:
		return
	last_adv = now
	if typing:
		typing = false
		dlg_text.visible_characters = -1
		dlg_more.visible = true
	else:
		Sfx.play("click", -18.0)
		_next()

func clear_dialog() -> void:
	queue.clear()
	dlg.visible = false

func show_msg(text: String, sec := 2.6) -> void:
	msg.text = text
	msg_t = sec

# ------------------------------------------------------------------ pannello enigmi

func _build_panel() -> void:
	panel = PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.custom_minimum_size = Vector2(760, 420)
	panel.offset_left = -380
	panel.offset_right = 380
	panel.offset_top = -230
	panel.offset_bottom = 190
	panel.add_theme_stylebox_override("panel", _style(Color(0.03, 0.04, 0.06, 0.95), WARM, 22))
	panel.visible = false
	root.add_child(panel)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 12)
	panel.add_child(vb)
	panel_title = _label("", 28, WARM)
	vb.add_child(panel_title)
	panel_schema = RichTextLabel.new()
	panel_schema.bbcode_enabled = true
	panel_schema.fit_content = true
	panel_schema.scroll_active = false
	panel_schema.add_theme_font_size_override("normal_font_size", 19)
	panel_schema.add_theme_color_override("default_color", DIM)
	vb.add_child(panel_schema)
	panel_msg = RichTextLabel.new()
	panel_msg.bbcode_enabled = true
	panel_msg.scroll_active = false
	panel_msg.custom_minimum_size = Vector2(0, 110)
	panel_msg.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel_msg.add_theme_font_size_override("normal_font_size", 21)
	panel_msg.add_theme_color_override("default_color", INK)
	vb.add_child(panel_msg)
	panel_btns = HBoxContainer.new()
	panel_btns.add_theme_constant_override("separation", 10)
	panel_btns.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.add_child(panel_btns)

## buttons = [{label, fn, on(bool opz.)}]
func panel_open(ptitle: String, schema: String, text: String, buttons: Array) -> void:
	Game.paused = true
	panel.visible = true
	panel_title.text = ptitle
	panel_schema.text = schema
	panel_schema.visible = schema != ""
	panel_set(text, buttons)

func panel_set(text: String, buttons: Array) -> void:
	panel_msg.text = text
	for c in panel_btns.get_children():
		c.queue_free()
	for b in buttons:
		var bt := _button(b["label"], 19)
		bt.custom_minimum_size = Vector2(120, 64)
		if b.get("on", false):
			bt.add_theme_stylebox_override("normal", _style(Color(0.25, 0.18, 0.08, 0.95), WARM, 10))
		bt.pressed.connect(b["fn"])
		panel_btns.add_child(bt)

func panel_close() -> void:
	panel.visible = false
	Game.paused = false

# ------------------------------------------------------------------ zaino

func _build_bag() -> void:
	bag = PanelContainer.new()
	bag.set_anchors_preset(Control.PRESET_CENTER)
	bag.offset_left = -400
	bag.offset_right = 400
	bag.offset_top = -280
	bag.offset_bottom = 250
	bag.add_theme_stylebox_override("panel", _style(Color(0.03, 0.04, 0.06, 0.95), Color(1, 1, 1, 0.35), 22))
	bag.visible = false
	root.add_child(bag)
	var sc := ScrollContainer.new()
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	bag.add_child(sc)
	bag_box = VBoxContainer.new()
	bag_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bag_box.add_theme_constant_override("separation", 8)
	sc.add_child(bag_box)

func toggle_bag(ch: Chapter) -> void:
	if bag.visible:
		bag.visible = false
		Game.paused = false
		return
	if panel.visible or reading() or not Game.started or Game.ended:
		return
	for c in bag_box.get_children():
		c.queue_free()
	bag_box.add_child(_label("ZAINO · РЮКЗАК", 26, WARM))
	var row := HBoxContainer.new()
	row.add_child(_label("Scatolette «Тушёнка»: %d     " % Game.cans, 20))
	var eat := _button("MANGIA (+calore)", 18)
	eat.disabled = Game.cans <= 0
	eat.pressed.connect(func():
		eat_requested.emit()
		bag.visible = false
		Game.paused = false)
	row.add_child(eat)
	bag_box.add_child(row)
	bag_box.add_child(_label("OGGETTI", 17, DIM))
	if Game.items.is_empty():
		bag_box.add_child(_label("— niente —", 19, DIM))
	for k in Game.items.keys():
		bag_box.add_child(_label("· " + str(Game.ITEM_NAMES.get(k, k)), 20))
	bag_box.add_child(_label("INDIZI  %d / %d" % [Game.clues.size(), ch.clue_count], 17, DIM))
	for k in Game.clues.keys():
		var r := RichTextLabel.new()
		r.bbcode_enabled = true
		r.fit_content = true
		r.scroll_active = false
		r.add_theme_font_size_override("normal_font_size", 18)
		r.add_theme_color_override("default_color", INK)
		r.text = "· " + str(ch.docs.get(k, k))
		bag_box.add_child(r)
	var close := _button("CHIUDI", 18)
	close.pressed.connect(func(): toggle_bag(ch))
	bag_box.add_child(close)
	bag.visible = true
	Game.paused = true

# ------------------------------------------------------------------ menu iniziale

func _build_title() -> void:
	title = ColorRect.new()
	(title as ColorRect).color = Color(0.015, 0.02, 0.03, 0.93)
	title.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(title)
	var cc := CenterContainer.new()
	cc.set_anchors_preset(Control.PRESET_FULL_RECT)
	title.add_child(cc)
	var vb := VBoxContainer.new()
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.add_theme_constant_override("separation", 8)
	cc.add_child(vb)
	var big := _label("ЗИМА", 120, INK)
	big.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(big)
	var sub := _label("C O L D   C Y C L E", 30, WARM)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(sub)
	var story := _label("ЗАТО-42 · 12 febbraio 1991 · −28 °C\nLa neve ricorda tutto. Ogni passo resta.\nE qualcosa, nella nebbia, segue i tuoi.", 19, DIM)
	story.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(story)
	var sp := Control.new()
	sp.custom_minimum_size = Vector2(0, 14)
	vb.add_child(sp)
	title_grid = GridContainer.new()
	title_grid.columns = 5
	title_grid.add_theme_constant_override("h_separation", 8)
	title_grid.add_theme_constant_override("v_separation", 8)
	vb.add_child(title_grid)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 10)
	vb.add_child(row)
	gfx_btn = _button(Gfx.label(), 17)
	gfx_btn.pressed.connect(func():
		Gfx.cycle()
		gfx_btn.text = Gfx.label())
	row.add_child(gfx_btn)
	if not OS.has_feature("mobile") and not OS.has_feature("web"):
		var quit := _button("ESCI", 17)
		quit.pressed.connect(func(): get_tree().quit())
		row.add_child(quit)
	var foot := _label("WASD muovi · SHIFT corri · E esamina · T torcia · I zaino · H aiuto · Z/X ruota · rotella zoom", 14, DIM)
	foot.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(foot)
	refresh_title()

func refresh_title() -> void:
	for c in title_grid.get_children():
		c.queue_free()
	for ch in Game.CHAPTERS:
		var id: int = ch["id"]
		var ready: bool = Game.READY.has(id)
		var txt := "%s\n%s" % [ch["roman"], ch["name"]]
		if not ready:
			txt += "\n(in arrivo)"
		elif Game.done.has(id):
			txt += "\n✓"
		var b := _button(txt, 15)
		b.custom_minimum_size = Vector2(176, 76)
		b.disabled = not ready or id > Game.unlocked
		b.pressed.connect(func(): chapter_picked.emit(id))
		title_grid.add_child(b)

func show_title(on: bool) -> void:
	title.visible = on
	if on:
		refresh_title()
		gfx_btn.text = Gfx.label()

# ------------------------------------------------------------------ fine capitolo

func _build_end() -> void:
	end_screen = ColorRect.new()
	(end_screen as ColorRect).color = Color(0, 0, 0, 0.88)
	end_screen.set_anchors_preset(Control.PRESET_FULL_RECT)
	end_screen.visible = false
	root.add_child(end_screen)
	var cc := CenterContainer.new()
	cc.set_anchors_preset(Control.PRESET_FULL_RECT)
	end_screen.add_child(cc)
	end_box = VBoxContainer.new()
	end_box.custom_minimum_size = Vector2(760, 0)
	end_box.add_theme_constant_override("separation", 14)
	cc.add_child(end_box)

func show_end(ch: Chapter, e: Dictionary) -> void:
	for c in end_box.get_children():
		c.queue_free()
	var a := _label("FINE DEL CAPITOLO %s" % ch.roman, 22, WARM)
	a.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	end_box.add_child(a)
	var b := _label(ch.title.to_upper(), 54, INK)
	b.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	end_box.add_child(b)
	var t := _label(str(e["text"]) + "\n\nIndizi trovati: %d/%d" % [Game.clues.size(), ch.clue_count], 21, INK)
	t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	end_box.add_child(t)
	var nx := _label("PROSSIMO · " + str(e.get("next_label", "")), 18, DIM)
	nx.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	end_box.add_child(nx)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 12)
	end_box.add_child(row)
	var next_id := int(e.get("next", 0))
	if next_id > 0 and Game.READY.has(next_id):
		var go := _button("CONTINUA", 20)
		go.pressed.connect(func(): chapter_picked.emit(next_id))
		row.add_child(go)
	var mn := _button("MENU", 20)
	mn.pressed.connect(func(): menu_requested.emit())
	row.add_child(mn)
	end_screen.visible = true

# ------------------------------------------------------------------ comandi touch

func _build_touch() -> void:
	touch_root = Control.new()
	touch_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	touch_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	touch_root.visible = Gfx.touch
	root.add_child(touch_root)
	joy_draw = Control.new()
	joy_draw.set_anchors_preset(Control.PRESET_FULL_RECT)
	joy_draw.mouse_filter = Control.MOUSE_FILTER_IGNORE
	joy_draw.draw.connect(_draw_joy)
	touch_root.add_child(joy_draw)
	var defs := [
		["interact", "ESAMINA", 0, 0, 118],
		["torch", "TORCIA", 1, 0, 84],
		["run_toggle", "CORRI", 0, 1, 84],
		["bag", "ZAINO", 1, 1, 84],
		["help", "AIUTO", 2, 1, 70],
		["rot_l", "⟲", 2, 0, 60],
		["rot_r", "⟳", 3, 0, 60],
		["pause", "MENU", 3, 1, 60],
	]
	for d in defs:
		var holder := Panel.new()
		holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var sb := _style(Color(0.05, 0.07, 0.10, 0.45), Color(1, 1, 1, 0.35), 0)
		sb.set_corner_radius_all(int(d[4] / 2))
		holder.add_theme_stylebox_override("panel", sb)
		holder.size = Vector2(d[4], d[4])
		var lb := _label(d[1], 15 if str(d[1]).length() > 2 else 26, INK)
		lb.set_anchors_preset(Control.PRESET_FULL_RECT)
		lb.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lb.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		holder.add_child(lb)
		touch_root.add_child(holder)
		var tb := TouchScreenButton.new()
		var sh := CircleShape2D.new()
		sh.radius = d[4] * 0.56
		tb.shape = sh
		tb.action = d[0]
		tb.position = Vector2(d[4], d[4]) * 0.5
		holder.add_child(tb)
		tbuttons.append({"n": holder, "col": d[2], "row": d[3], "size": d[4], "act": d[0]})

func _layout_touch() -> void:
	var vs := root.get_viewport_rect().size
	for t in tbuttons:
		var n: Panel = t["n"]
		var s: float = t["size"]
		var cx: float = vs.x - 92.0 - t["col"] * 108.0
		var cy: float = vs.y - 96.0 - t["row"] * 124.0
		n.position = Vector2(cx - s * 0.5, cy - s * 0.5)

func _draw_joy() -> void:
	if joy_id < 0:
		var vs := root.get_viewport_rect().size
		joy_draw.draw_arc(Vector2(150, vs.y - 290), 62, 0, TAU, 40, Color(1, 1, 1, 0.14), 2.0)
		return
	joy_draw.draw_arc(joy_origin, 66, 0, TAU, 40, Color(1, 1, 1, 0.35), 2.0)
	joy_draw.draw_circle(joy_origin + joy * 66.0, 26, Color(1, 1, 1, 0.3))

func _input(ev: InputEvent) -> void:
	if ev is InputEventScreenTouch:
		var vs := root.get_viewport_rect().size
		if ev.pressed:
			if reading():
				advance()
			elif joy_id < 0 and ev.position.x < vs.x * 0.45 and ev.position.y > vs.y * 0.3 \
					and not panel.visible and not bag.visible and not title.visible:
				joy_id = ev.index
				joy_origin = ev.position
				joy = Vector2.ZERO
		elif ev.index == joy_id:
			joy_id = -1
			joy = Vector2.ZERO
		joy_draw.queue_redraw()
	elif ev is InputEventScreenDrag and ev.index == joy_id:
		joy = ((ev.position - joy_origin) / 66.0).limit_length(1.0)
		joy_draw.queue_redraw()
	elif ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
		if reading():
			advance()

# ------------------------------------------------------------------ aggiornamento

func update(dt: float, frost: float, dread: float, flash: float, fade: float) -> void:
	bars.queue_redraw()
	bars.visible = Game.started and not title.visible
	objective.visible = bars.visible and not Game.ended
	if typing:
		chars += dt * 52.0
		dlg_text.visible_characters = int(chars)
		if int(chars) >= dlg_text.get_total_character_count():
			typing = false
			dlg_text.visible_characters = -1
			dlg_more.visible = true
	if msg_t > 0.0:
		msg_t -= dt
		msg.modulate.a = min(1.0, msg.modulate.a + dt * 5.0)
	else:
		msg.modulate.a = max(0.0, msg.modulate.a - dt * 2.5)
	touch_root.visible = Gfx.touch and Game.started and not Game.ended and not title.visible
	post_mat.set_shader_parameter("frost", frost)
	post_mat.set_shader_parameter("dread", dread)
	post_mat.set_shader_parameter("flash", flash)
	post_mat.set_shader_parameter("fade", fade)
