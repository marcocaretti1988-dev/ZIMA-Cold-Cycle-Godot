extends Node3D
## ЗИМА · Cold Cycle — motore: camera isometrica, luci, sopravvivenza,
## interazioni, aiuti progressivi, vuoti di memoria, fine capitolo.

const CHAPTER_SCRIPTS := {
	1: "res://scripts/chapters/chapter1.gd",
}
const FOG := Color(0.36, 0.41, 0.49)
const HINT_THOUGHT := 70.0
const HINT_ARROW := 140.0
const VIEW_H := 24.0

var hud: Hud
var env: Environment
var sun: DirectionalLight3D
var cam: Camera3D
var ch: Chapter
var player: Player
var t := 0.0
var cam_target := Vector3.ZERO
var az := PI * 0.25
var az_target := PI * 0.25
var zoom := 1.6
var zoom_target := 1.6
var near_item = null
var help_t := 0.0
var help_stage := 0
var last_obj := ""
var arrow: MeshInstance3D
var arrow_on := false
var sparks := []
var spark_tex: ImageTexture
var fade := 0.0
var fade_target := 0.0
var flash := 0.0
var dread := 0.0
var shake := 0.0
var end_t := -1.0
var testing := false
var indoor_mix := 0.0          # 0 = fuori nella nebbia, 1 = al chiuso
var fog_base := 0.0105

func _ready() -> void:
	_inputs()
	_world()
	hud = Hud.new()
	add_child(hud)
	hud.chapter_picked.connect(start_chapter)
	hud.menu_requested.connect(to_menu)
	hud.eat_requested.connect(eat)
	Gfx.changed.connect(apply_gfx)
	apply_gfx()
	spark_tex = _spark_texture()
	to_menu()
	if OS.get_environment("ZIMA_TEST") != "":
		testing = true
		_autotest()
	elif OS.get_environment("ZIMA_SHOT") != "":
		testing = true
		_shots(OS.get_environment("ZIMA_SHOT"))

# ------------------------------------------------------------------ impostazione

func _inputs() -> void:
	var keys := {
		"move_left": [KEY_A, KEY_LEFT], "move_right": [KEY_D, KEY_RIGHT],
		"move_up": [KEY_W, KEY_UP], "move_down": [KEY_S, KEY_DOWN],
		"run": [KEY_SHIFT], "interact": [KEY_E, KEY_SPACE, KEY_ENTER],
		"torch": [KEY_T], "bag": [KEY_I, KEY_TAB], "help": [KEY_H],
		"rot_l": [KEY_Z, KEY_Q], "rot_r": [KEY_X, KEY_R], "pause": [KEY_ESCAPE],
		"run_toggle": [],
	}
	for a in keys:
		if not InputMap.has_action(a):
			InputMap.add_action(a)
		for k in keys[a]:
			var ev := InputEventKey.new()
			ev.physical_keycode = k
			InputMap.action_add_event(a, ev)

func _world() -> void:
	env = Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = FOG
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.42, 0.49, 0.62)
	env.ambient_light_energy = 0.55
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.fog_enabled = true
	env.fog_light_color = FOG
	env.fog_light_energy = 1.0
	env.fog_density = 0.0105
	env.glow_enabled = true
	env.glow_intensity = 0.7
	env.glow_bloom = 0.08
	env.glow_hdr_threshold = 0.95
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	sun = DirectionalLight3D.new()
	sun.light_color = Color(0.60, 0.70, 0.84)
	sun.light_energy = 1.25
	add_child(sun)
	set_sun(21.0, -0.6, 0.8)
	cam = Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.near = 0.5
	cam.far = 160.0
	cam.size = VIEW_H / zoom
	add_child(cam)
	cam.make_current()
	var b := Batch.new()
	var col := Color(1.0, 0.72, 0.38)
	b.box(-0.07, 0.07, 0, 0.02, -0.5, 0.2, col)
	b.box_at(Vector3(-0.13, 0.01, -0.38), Vector3(0.4, 0.02, 0.1), col, PI * 0.25)
	b.box_at(Vector3(0.13, 0.01, -0.38), Vector3(0.4, 0.02, 0.1), col, -PI * 0.25)
	arrow = b.instance(self, Batch.glow(1.6), false)
	arrow.visible = false

## Sole basso: elevazione in gradi, direzione orizzontale (x, z) verso il sole.
func set_sun(elev_deg: float, dx: float, dz: float) -> void:
	var e := deg_to_rad(elev_deg)
	var d := Vector3(dx * cos(e), sin(e), dz * cos(e)).normalized()
	sun.look_at_from_position(d * 60.0, Vector3.ZERO, Vector3.UP)

func apply_gfx() -> void:
	var full := Gfx.full_fx()
	# La nebbia volumetrica di Godot non è affidabile con la camera ortogonale (isometrica):
	# resta spenta finché non la proviamo su un PC con Forward+.
	env.volumetric_fog_enabled = false
	env.volumetric_fog_density = 0.016
	env.volumetric_fog_albedo = Color(0.80, 0.86, 0.96)
	env.volumetric_fog_emission = Color(0.05, 0.06, 0.09)
	env.volumetric_fog_length = 90.0
	env.volumetric_fog_anisotropy = 0.35
	env.ssao_enabled = full
	env.ssao_intensity = 2.2
	env.ssao_radius = 1.2
	fog_base = 0.0105
	env.fog_density = fog_base
	sun.shadow_enabled = Gfx.shadows()
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS if Gfx.pc \
		else DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	sun.directional_shadow_max_distance = 95.0
	sun.shadow_blur = 1.6 if Gfx.pc else 1.0
	sun.shadow_bias = 0.06
	sun.shadow_normal_bias = 1.5
	get_viewport().scaling_3d_scale = Gfx.render_scale()
	get_viewport().msaa_3d = Viewport.MSAA_2X if Gfx.pc else Viewport.MSAA_DISABLED

func _spark_texture() -> ImageTexture:
	var n := 64
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	for py in n:
		for px in n:
			var p := Vector2(px - 31.5, py - 31.5) / 32.0
			var a: float = max(0.0, 1.0 - p.length())
			var ray: float = max(exp(-abs(p.x) * 26.0), exp(-abs(p.y) * 26.0)) * a
			var core := exp(-p.length() * 9.0)
			img.set_pixel(px, py, Color(1, 1, 1, clamp(ray * 0.9 + core, 0.0, 1.0)))
	return ImageTexture.create_from_image(img)

# ------------------------------------------------------------------ flusso

func to_menu() -> void:
	_free_chapter()
	Game.reset_chapter()
	hud.end_screen.visible = false
	hud.clear_dialog()
	hud.panel.visible = false
	hud.bag.visible = false
	hud.show_title(true)
	fade = 0.0
	fade_target = 0.0
	Sfx.menu_music(true)
	Sfx.set_hum(0.0)

func _free_chapter() -> void:
	for s in sparks:
		if is_instance_valid(s["n"]):
			s["n"].queue_free()
	sparks.clear()
	if ch != null:
		ch.queue_free()
		ch = null
	player = null
	near_item = null
	arrow.visible = false

func start_chapter(id: int) -> void:
	if not CHAPTER_SCRIPTS.has(id):
		return
	_free_chapter()
	Game.reset_chapter()
	hud.end_screen.visible = false
	hud.clear_dialog()
	hud.show_title(false)
	Sfx.menu_music(false)
	ch = load(CHAPTER_SCRIPTS[id]).new()
	ch.main = self
	ch.hud = hud
	ch.rng.seed = 1991 + id
	add_child(ch)
	player = Player.new()
	ch.add_child(player)
	ch.player = player
	ch.build()
	ch.interactables = ch.items()
	player.place(ch.start["x"], ch.start["z"], ch.start["heading"])
	player.move(0.0, Vector2.ZERO, false, ch)
	cam_target = player.position
	for it in ch.interactables:
		if it.get("marker", true):
			var sp := Sprite3D.new()
			sp.texture = spark_tex
			sp.billboard = BaseMaterial3D.BILLBOARD_ENABLED
			sp.shaded = false
			sp.no_depth_test = true
			sp.pixel_size = 0.007
			sp.modulate = Color(1.0, 0.9, 0.7, 0.0)
			sp.position = Vector3(it["x"], ch.ground_y(it["x"], it["z"]) + float(it.get("my", 0.9)), it["z"])
			ch.add_child(sp)
			sparks.append({"n": sp, "it": it, "ph": randf() * TAU})
	Game.started = true
	Game.last = id
	t = 0.0
	help_t = 0.0
	help_stage = 0
	arrow_on = false
	last_obj = ""
	end_t = -1.0
	dread = 0.0
	fade = 1.0
	fade_target = 0.0
	ch.intro()

func end_chapter() -> void:
	if Game.ended:
		return
	Game.ended = true
	Game.torch = false
	fade_target = 1.0
	Sfx.play("sting", -4.0)
	var e := ch.ending()
	Game.chapter_done(ch.id, int(e.get("next", 0)))
	get_tree().create_timer(2.6).timeout.connect(func():
		if ch != null:
			hud.show_end(ch, e))

func eat() -> void:
	if Game.cans <= 0:
		return
	Game.cans -= 1
	Game.heat = min(100.0, Game.heat + 30.0)
	Game.food_warm = 10.0
	Sfx.play("eat", -8.0)
	hud.say("Apro una scatoletta con il coltello. Carne fredda, grassa. Il calore torna piano nello stomaco.")

func memory_gap() -> void:
	if Game.gap or Game.ended:
		return
	Game.gap = true
	Game.torch = false
	player.fallen = 1.0
	fade_target = 1.0
	Sfx.play("thud", -6.0)
	hud.clear_dialog()
	get_tree().create_timer(2.8, false).timeout.connect(_wake)

func _wake() -> void:
	if ch == null:
		return
	var cp: Vector2 = Game.checkpoint
	var has_cp := cp != Vector2.ZERO
	if not has_cp:
		cp = Vector2(ch.start["x"], ch.start["z"])
	player.place(cp.x, cp.y, player.heading)
	player.fallen = 0.0
	Game.heat = max(Game.heat, 60.0)
	Game.gap = false
	fade_target = 0.0
	if not ch.shelter(cp.x, cp.y):
		for i in 14:
			var a := TAU * i / 14.0
			ch.snow.add_print(cp.x + cos(a) * 1.15, cp.y + sin(a) * 1.15, atan2(-sin(a), cos(a)), 1.0)
		hud.say(["Il freddo mi spegne come una lampadina.",
			"Riapro gli occhi accanto al fuoco. Intorno a me, nella neve, un cerchio di impronte.",
			"Sono le mie. Non ricordo di averle fatte."])
	else:
		hud.say(["Il freddo mi spegne come una lampadina.",
			"Riapro gli occhi sul pavimento. Non ricordo di essermi mosso."])

# ------------------------------------------------------------------ ciclo

func _unhandled_input(ev: InputEvent) -> void:
	if ev is InputEventMouseButton and ev.pressed:
		if ev.button_index == MOUSE_BUTTON_WHEEL_UP:
			zoom_target = clamp(zoom_target * 1.1, 0.9, 2.6)
		elif ev.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			zoom_target = clamp(zoom_target / 1.1, 0.9, 2.6)
	elif ev is InputEventMagnifyGesture:
		zoom_target = clamp(zoom_target * ev.factor, 0.9, 2.6)

func _process(dt: float) -> void:
	dt = min(dt, 0.05)
	fade = move_toward(fade, fade_target, dt * 0.9)
	flash = max(0.0, flash - dt * 2.5)
	shake = max(0.0, shake - dt * 1.6)
	if ch == null or not Game.started:
		hud.update(dt, 0.0, 0.0, 0.0, 0.0)
		return
	t += dt
	var frozen: bool = hud.reading() or Game.paused or Game.gap or Game.ended
	_actions(frozen)
	var dir := Vector2.ZERO
	if not frozen:
		var iv := Vector2(Input.get_axis("move_left", "move_right"), Input.get_axis("move_down", "move_up"))
		iv += Vector2(hud.joy.x, -hud.joy.y)
		iv = iv.limit_length(1.0)
		var fwd := Vector2(-sin(az), -cos(az))
		var right := Vector2(cos(az), -sin(az))
		dir = right * iv.x + fwd * iv.y
	var run := Input.is_action_pressed("run") or hud.run_toggle
	player.move(dt, dir, run, ch)
	player.set_torch(Game.torch, 0.5 + 0.5 * clamp(Game.battery / 15.0, 0.0, 1.0))
	_camera(dt)
	if not Game.paused:
		_survival(dt, frozen)
		_interact_scan()
		_help(dt, frozen)
		ch.update(dt, t)
	ch.update_fires(t)
	_sparks(dt)
	var indoor: bool = ch.shelter(player.x, player.z)
	ch.snow.follow(cam_target, not indoor)
	Sfx.set_wind(0.05 if indoor else 0.22 + 0.08 * sin(t * 0.23))
	var fv := 0.0
	for f in ch.fires:
		if f["lit"]:
			fv = max(fv, clamp(1.0 - Vector2(f["x"] - player.x, f["z"] - player.z).length() / 9.0, 0.0, 1.0))
	Sfx.set_fire(fv * 0.5)
	dread = max(0.0, dread - dt * 0.25)
	var bg := FOG.lerp(Color(0.02, 0.025, 0.035), indoor_mix)
	env.background_color = bg
	env.fog_light_color = bg
	env.fog_density = fog_base * (1.0 - indoor_mix * 0.93)
	var frost: float = clamp((35.0 - Game.heat) / 35.0, 0.0, 1.0)
	hud.update(dt, frost, dread, flash, fade)
	if end_t > 0.0 and not hud.reading():
		end_t -= dt
		if end_t <= 0.0:
			end_t = -1.0
			end_chapter()

func _actions(frozen: bool) -> void:
	if Input.is_action_just_pressed("interact"):
		if hud.reading():
			hud.advance()
		elif not frozen and near_item != null:
			use_item(near_item)
	if Input.is_action_just_pressed("pause") and Game.started and not Game.ended:
		if hud.panel.visible:
			hud.panel_close()
		elif hud.bag.visible:
			hud.toggle_bag(ch)
		else:
			hud.panel_open("ПАУЗА · PAUSA", "", "ЗАТО-42 · 12 febbraio 1991 · 23:40",
				[{"label": "RIPRENDI", "fn": hud.panel_close},
				{"label": "TORNA AL MENU", "fn": func():
					hud.panel_close()
					to_menu()}])
	if Game.ended or Game.gap:
		return
	if Input.is_action_just_pressed("bag"):
		hud.toggle_bag(ch)
	if frozen:
		return
	if Input.is_action_just_pressed("torch"):
		toggle_torch()
	if Input.is_action_just_pressed("run_toggle"):
		hud.run_toggle = not hud.run_toggle
		hud.show_msg("Corsa: " + ("sì" if hud.run_toggle else "no"), 1.0)
	if Input.is_action_just_pressed("help"):
		hud.say([ch.hint(), "Segui la freccia sulla neve."], "AIUTO")
		arrow_on = true
		help_stage = 2
	if Input.is_action_just_pressed("rot_l"):
		az_target += PI * 0.5
	if Input.is_action_just_pressed("rot_r"):
		az_target -= PI * 0.5

func toggle_torch() -> void:
	if not Game.torch and Game.battery <= 0.5:
		hud.show_msg("La torcia è scarica.")
		return
	Game.torch = not Game.torch
	Sfx.play("click", -8.0)

func use_item(it: Dictionary) -> void:
	if it.get("clue", false) and not Game.clues.has(it["id"]):
		Game.clues[it["id"]] = true
		Sfx.play("pick", -10.0)
	elif it.get("pick", false):
		Sfx.play("pick", -12.0)
	it["use"].call()

func _camera(dt: float) -> void:
	var k := 1.0 - exp(-5.0 * dt)
	cam_target = cam_target.lerp(player.position + Vector3(0, 0.9, 0), k)
	az = lerp(az, az_target, 1.0 - exp(-7.0 * dt))
	zoom = lerp(zoom, zoom_target, 1.0 - exp(-8.0 * dt))
	cam.size = VIEW_H / zoom
	var off := Vector3(sin(az) * 36.0, 30.0, cos(az) * 36.0)
	var sh := Vector3(randf_range(-1, 1), randf_range(-1, 1), 0) * shake * 0.35
	cam.look_at_from_position(cam_target + off + sh, cam_target + sh, Vector3.UP)

func _survival(dt: float, frozen: bool) -> void:
	if Game.ended or Game.gap:
		return
	var k := 0.55 if player.speed > 2.5 else (1.0 if player.speed > 0.15 else 1.5)
	var drain: float = ch.cold * k
	if hud.reading():
		drain *= 0.25
	if ch.shelter(player.x, player.z):
		drain *= 0.4
	if Game.gear.has("cappotto"):
		drain *= 0.6
	var warm := 0.0
	for f in ch.fires:
		if f["lit"]:
			var d := Vector2(f["x"] - player.x, f["z"] - player.z).length()
			if d < 3.4:
				warm += 10.0 * (1.0 - d / 3.4) + 2.0
	if Game.food_warm > 0.0:
		Game.food_warm -= dt
		warm += 2.5
	Game.heat = clamp(Game.heat + (warm - drain) * dt, 0.0, 100.0)
	if not frozen:
		if Game.heat < 62.0:
			hud.tell("cold1", ch.cold_tip())
		if Game.heat < 28.0:
			hud.tell("cold2", "Non sento più le dita. Devo scaldarmi, subito.")
		if Game.heat < 45.0 and Game.cans > 0:
			hud.tell("cans", ["Nello zaino ho delle scatolette. Mangiarne una mi scalderebbe.",
				"[color=#9fb0c0][apri lo ZAINO · tasto I][/color]"])
	if Game.heat <= 0.0:
		memory_gap()
	if Game.torch:
		Game.battery = max(0.0, Game.battery - 1.05 * dt)
		if Game.battery <= 0.0:
			Game.torch = false
			hud.show_msg("La torcia si è spenta. Batteria esaurita.", 3.0)

func item_active(it: Dictionary) -> bool:
	if it.has("gone") and it["gone"].call():
		return false
	if it.has("needs") and not it["needs"].call():
		return false
	return true

func _interact_scan() -> void:
	near_item = null
	var best := 1e9
	for it in ch.interactables:
		if not item_active(it):
			continue
		var d := Vector2(it["x"] - player.x, it["z"] - player.z).length()
		if d < float(it["r"]) and d < best:
			best = d
			near_item = it
	if near_item != null and not hud.reading() and not Game.paused and not Game.ended and not Game.gap:
		var lab = near_item["label"]
		if lab is Callable:
			lab = lab.call()
		hud.prompt.text = str(lab) if Gfx.touch else "[E]  " + str(lab)
	else:
		hud.prompt.text = ""
	var obj := ch.objective()
	hud.objective.text = "▸ " + obj if obj != "" else ""
	if obj != last_obj:
		last_obj = obj
		help_t = 0.0
		help_stage = 0
		arrow_on = false

func _help(dt: float, frozen: bool) -> void:
	if not frozen and not Game.ended:
		help_t += dt
	if help_stage == 0 and help_t > HINT_THOUGHT and not frozen:
		help_stage = 1
		var th := ch.thought()
		if th != "":
			hud.say(th)
	elif help_stage == 1 and help_t > HINT_ARROW:
		help_stage = 2
		arrow_on = true
	var tg = ch.target()
	var tp := Vector2.ZERO
	var ok := false
	if tg is Dictionary:
		tp = Vector2(tg["x"], tg["z"])
		ok = true
	elif tg is Vector2:
		tp = tg
		ok = true
	arrow.visible = arrow_on and ok and not Game.ended
	if arrow.visible:
		var d := tp - Vector2(player.x, player.z)
		if d.length() < 1.2:
			arrow.visible = false
		else:
			var n := d.normalized()
			var p := Vector2(player.x, player.z) + n * 1.5
			arrow.position = Vector3(p.x, ch.ground_y(p.x, p.y) + 0.06 + 0.03 * sin(t * 4.0), p.y)
			arrow.rotation.y = atan2(n.x, n.y) + PI
			arrow.scale = Vector3.ONE * 1.6

func _sparks(dt: float) -> void:
	for s in sparks:
		var it: Dictionary = s["it"]
		var n: Sprite3D = s["n"]
		var show: bool = item_active(it) and not (it.has("done") and it["done"].call())
		if show:
			var d := Vector2(it["x"] - player.x, it["z"] - player.z).length()
			show = d < 6.5
		s["ph"] += dt * 2.2
		var pulse: float = 0.25 + 0.75 * pow(max(0.0, sin(s["ph"])), 6.0)
		var want := pulse * 0.9 if show else 0.0
		n.modulate.a = lerp(n.modulate.a, want, 1.0 - exp(-6.0 * dt))
		n.rotation.z += dt * 0.4

# ------------------------------------------------------------------ prove automatiche

func _autotest() -> void:
	await get_tree().create_timer(0.3).timeout
	Engine.time_scale = 12.0
	start_chapter(1)
	var steps := 0
	var log_obj := ""
	while not Game.ended and steps < 6000:
		await get_tree().process_frame
		steps += 1
		if hud.reading():
			hud.last_adv = 0.0
			hud.advance()
			continue
		if hud.panel.visible:
			ch.auto_panel()
			continue
		if Game.gap or Game.paused:
			continue
		var o := ch.objective()
		if o != log_obj:
			log_obj = o
			print("[obiettivo] ", o)
		var tg = ch.target()
		if tg is Dictionary:
			var res := ch.resolve(tg["x"], tg["z"], Player.RADIUS)
			player.place(res.x, res.y, player.heading)
			player.move(0.0, Vector2.ZERO, false, ch)
			_interact_scan()
			var d := Vector2(tg["x"] - player.x, tg["z"] - player.z).length()
			if d >= float(tg["r"]):
				print("ERRORE: non raggiungibile ", tg["id"], " dist ", d)
				get_tree().quit(1)
				return
			if item_active(tg):
				use_item(tg)
		elif tg is Vector2:
			player.place(tg.x, tg.y, player.heading)
	print("heat=", Game.heat, " clues=", Game.clues.keys(), " items=", Game.items.keys())
	if Game.ended:
		print("TEST OK: capitolo finito in ", steps, " frame")
		get_tree().quit(0)
	else:
		print("TEST FALLITO: fermo su «", ch.objective(), "»")
		get_tree().quit(1)

func _shots(dir: String) -> void:
	await get_tree().create_timer(0.5).timeout
	get_viewport().get_texture().get_image().save_png(dir + "/00_menu.png")
	start_chapter(1)
	hud.clear_dialog()
	var pts: Array = ch.shot_points()
	var i := 1
	for p in pts:
		if p.has("fn"):
			p["fn"].call()
		hud.clear_dialog()
		player.place(p["x"], p["z"], p.get("h", 0.6))
		zoom = p.get("zoom", 1.6)
		zoom_target = zoom
		az = p.get("az", PI * 0.25)
		az_target = az
		Game.torch = p.get("torch", false)
		Game.heat = 100.0
		player.move(0.0, Vector2.ZERO, false, ch)
		cam_target = player.position + Vector3(0, 0.9, 0)
		fade = 0.0
		fade_target = 0.0
		indoor_mix = 1.0 if ch.shelter(p["x"], p["z"]) else 0.0
		for k in 40:
			await get_tree().process_frame
			hud.clear_dialog()
			if p.has("walk"):
				player.move(1.0 / 60.0, p["walk"], false, ch)
				cam_target = player.position + Vector3(0, 0.9, 0)
		get_viewport().get_texture().get_image().save_png("%s/%02d_%s.png" % [dir, i, p.get("name", "shot")])
		i += 1
	get_tree().quit(0)
