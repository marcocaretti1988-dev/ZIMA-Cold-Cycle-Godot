class_name Chapter
extends Node3D
## Base di ogni capitolo: mondo, collisioni, interazioni, obiettivi, aiuti.

var main                      # Main
var hud: Hud
var player: Player
var snow: SnowField
var id := 0
var roman := ""
var title := ""
var clue_count := 3
var cold := 0.2
var docs := {}
var start := {"x": 0.0, "z": 0.0, "heading": 0.0}
var bounds := [-20.0, 20.0, -20.0, 20.0]
var boxes := []               # {x0,x1,z0,z1,off}
var circles := []             # {x,z,r,off}
var fires := []               # {x,z,lit,light,parts,r}
var interactables := []
var rng := RandomNumberGenerator.new()

func build() -> void:
	pass

func items() -> Array:
	return []

func ground_h(_x: float, _z: float) -> float:
	return 0.0

func ground_tint(_x: float, _z: float) -> float:
	return 1.0

func ground_y(x: float, z: float) -> float:
	return ground_h(x, z)

func shelter(_x: float, _z: float) -> bool:
	return false

func objective() -> String:
	return ""

func target():
	return null

func thought() -> String:
	return ""

func hint() -> String:
	return ""

func cold_tip() -> String:
	return "Il freddo mi entra nelle ossa. Torno al fuoco a scaldarmi."

func intro() -> void:
	pass

func update(_dt: float, _t: float) -> void:
	pass

func on_step(_x: float, _z: float) -> void:
	pass

func ending() -> Dictionary:
	return {"text": "", "next": 0, "next_label": ""}

func camera_bounds() -> Array:
	return bounds

# ------------------------------------------------------------------ aiuti per i capitoli

func by(item_id: String):
	for it in interactables:
		if it["id"] == item_id:
			return it
	return null

func add_box(x0: float, x1: float, z0: float, z1: float) -> Dictionary:
	var b := {"x0": min(x0, x1), "x1": max(x0, x1), "z0": min(z0, z1), "z1": max(z0, z1), "off": false}
	boxes.append(b)
	return b

func add_circle(x: float, z: float, r: float) -> Dictionary:
	var c := {"x": x, "z": z, "r": r, "off": false}
	circles.append(c)
	return c

## Spinge il personaggio fuori dagli ostacoli e dentro i confini.
func resolve(x: float, z: float, r: float) -> Vector2:
	for pass_i in 2:
		for b in boxes:
			if b["off"]:
				continue
			var cx: float = clamp(x, b["x0"], b["x1"])
			var cz: float = clamp(z, b["z0"], b["z1"])
			var dx := x - cx
			var dz := z - cz
			var d2 := dx * dx + dz * dz
			if d2 >= r * r:
				continue
			if d2 > 1e-8:
				var d := sqrt(d2)
				x = cx + dx / d * r
				z = cz + dz / d * r
			else:
				# dentro la scatola: esce dal lato più vicino
				var l: float = x - b["x0"]
				var rr: float = b["x1"] - x
				var t: float = z - b["z0"]
				var bt: float = b["z1"] - z
				var m: float = min(min(l, rr), min(t, bt))
				if m == l:
					x = b["x0"] - r
				elif m == rr:
					x = b["x1"] + r
				elif m == t:
					z = b["z0"] - r
				else:
					z = b["z1"] + r
		for c in circles:
			if c["off"]:
				continue
			var dx2: float = x - c["x"]
			var dz2: float = z - c["z"]
			var dd := sqrt(dx2 * dx2 + dz2 * dz2)
			var rr2: float = r + c["r"]
			if dd < rr2 and dd > 1e-5:
				x = c["x"] + dx2 / dd * rr2
				z = c["z"] + dz2 / dd * rr2
	var bd: Array = current_bounds(x, z)
	x = clamp(x, bd[0], bd[1])
	z = clamp(z, bd[2], bd[3])
	return Vector2(x, z)

func current_bounds(_x: float, _z: float) -> Array:
	return bounds

## Fuoco: luce tremolante + fiamme. Ritorna il dizionario del fuoco.
func make_fire(x: float, y: float, z: float, lit := false, energy := 3.2) -> Dictionary:
	var l := OmniLight3D.new()
	l.light_color = Color(1.0, 0.56, 0.22)
	l.omni_range = 9.0
	l.omni_attenuation = 1.4
	l.shadow_enabled = Gfx.pc
	l.position = Vector3(x, y + 0.5, z)
	l.light_energy = 0.0
	add_child(l)
	var p := CPUParticles3D.new()
	p.amount = 26 if Gfx.pc else 12
	p.lifetime = 0.7
	p.position = Vector3(x, y, z)
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 0.16
	p.direction = Vector3(0, 1, 0)
	p.spread = 12.0
	p.initial_velocity_min = 0.7
	p.initial_velocity_max = 1.5
	p.gravity = Vector3(0, 1.2, 0)
	p.scale_amount_min = 0.5
	p.scale_amount_max = 1.2
	var grad := Gradient.new()
	grad.set_color(0, Color(1.0, 0.85, 0.4, 0.95))
	grad.set_color(1, Color(0.9, 0.2, 0.05, 0.0))
	p.color_ramp = grad
	var q := QuadMesh.new()
	q.size = Vector2(0.26, 0.26)
	var qm := StandardMaterial3D.new()
	qm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	qm.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	qm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	qm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	qm.vertex_color_use_as_albedo = true
	qm.albedo_texture = soft_tex()
	q.material = qm
	p.mesh = q
	p.emitting = false
	add_child(p)
	var f := {"x": x, "z": z, "lit": false, "light": l, "parts": p, "energy": energy}
	fires.append(f)
	if lit:
		light_fire(f)
	return f

static var _soft: GradientTexture2D

## Dischetto sfumato per fiamme e fumo.
static func soft_tex() -> GradientTexture2D:
	if _soft == null:
		var gr := Gradient.new()
		gr.set_color(0, Color(1, 1, 1, 1))
		gr.set_color(1, Color(1, 1, 1, 0))
		_soft = GradientTexture2D.new()
		_soft.gradient = gr
		_soft.fill = GradientTexture2D.FILL_RADIAL
		_soft.fill_from = Vector2(0.5, 0.5)
		_soft.fill_to = Vector2(1.0, 0.5)
		_soft.width = 48
		_soft.height = 48
	return _soft

func light_fire(f: Dictionary) -> void:
	f["lit"] = true
	f["parts"].emitting = true

func update_fires(t: float) -> void:
	for f in fires:
		if f["lit"]:
			var fl := 0.82 + 0.18 * sin(t * 11.0 + f["x"]) * sin(t * 7.3) + 0.08 * sin(t * 23.0)
			f["light"].light_energy = f["energy"] * fl

func lamp_light(pos: Vector3, energy := 0.0, rng_m := 15.0, col := Color(1.0, 0.78, 0.48)) -> SpotLight3D:
	var s := SpotLight3D.new()
	s.light_color = col
	s.spot_range = rng_m
	s.spot_angle = 52.0
	s.spot_attenuation = 0.7
	s.light_energy = energy
	s.shadow_enabled = Gfx.pc
	s.position = pos
	s.rotation = Vector3(-PI * 0.5, 0, 0)
	add_child(s)
	return s

func after(sec: float, fn: Callable) -> void:
	get_tree().create_timer(sec, false).timeout.connect(fn)
