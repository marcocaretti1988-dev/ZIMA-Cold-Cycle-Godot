extends Chapter
## CAPITOLO I · IL CORTILE — «Qualcuno è uscito prima di te»
## Ti risvegli sul pavimento della cucina, l'appartamento sbarrato dall'interno, le 23:40
## ferme sull'orologio. Stufa, quaderno verde, radio, chiave del garage n. 4. Poi il cortile:
## la cabina ТП-4, il cancello, le impronte identiche ai tuoi stivali. E un foglio datato domani.

const AX := 60.0
const APT_FLOOR := 0.05
const A := {"x0": -20.0, "x1": 24.0, "z0": -22.0, "z1": -11.0}
const B := {"x0": -32.0, "x1": -21.0, "z0": -8.0, "z1": 14.0}
const TUN := {"x0": -16.62, "x1": -13.23}
const GAR := {"x0": 0.0, "x1": 19.2, "z0": 10.0, "z1": 16.0, "open": 3, "n": 6}
const TP := {"x0": 15.5, "x1": 19.5, "z0": -5.5, "z1": -2.0}
const CAR := Vector2(8.0, -8.6)
const CAR2 := Vector2(13.4, -8.3)
const DRIVE_Z := -8.5
const BARREL := Vector2(-9.2, -1.6)
const ARRIVE := Vector2(2.0, -9.3)
const GATE_Z := -11.3
const FAR_LAMP := Vector2(-11.5, 13.5)
const TRAILG := [[-14.9, -11.0], [-14.2, -8.6], [-11.5, -5.6], [-7.4, -3.4], [-3.0, -3.6],
	[0.4, -6.0], [1.7, -8.4], [2.0, -10.1]]
const APT_BOUNDS := [AX - 5.85, AX + 5.85, -4.33, 6.4]
const YARD_BOUNDS := [-20.4, 23.2, -21.5, 21.0]

var stove: Dictionary
var barrel_fire: Dictionary
var tv_light: OmniLight3D
var far_light: SpotLight3D
var far_on := false
var far_off_t := 0.0
var fig: MeshInstance3D
var fig_pos := Vector2(FAR_LAMP.x + 1.3, FAR_LAMP.y - 0.9)
var fig_shown := false
var gate: MeshInstance3D
var gate_box: Dictionary
var gate_open := 0.0
var gate_lamp: StandardMaterial3D
var tp_lamp: StandardMaterial3D
var tp := {"sw": [0, 0, 0], "blown": false}
var cabinet: MeshInstance3D
var cab_box: Dictionary
var cab_box2: Dictionary
var hatch_box: Dictionary
var cab_move := 0.0
var wet: MeshInstance3D
var plank: MeshInstance3D
var paper: MeshInstance3D
var logs: MeshInstance3D
var hook_key: MeshInstance3D
var battery_mesh: MeshInstance3D
var swing_seat: Node3D
var swing_stop := 0.0
var gar_door: MeshInstance3D
var gar_door_box: Dictionary
var gar_roof: MeshInstance3D
var gar_open := 0.0
var gar_x := 0.0
var forming := []
var form_t := 0.0
var gate_msg_t := 0.0

func _init() -> void:
	id = 1
	roman = "I"
	title = "Il Cortile"
	clue_count = 4
	cold = 0.2
	start = {"x": AX + 4.3, "z": -0.9, "heading": -PI * 0.5}
	bounds = APT_BOUNDS
	gar_x = GAR["x0"] + (GAR["open"] + 0.5) * 3.2
	docs = {
		"quaderno": "Quaderno verde · «Не включай свет.» «Если услышишь стук — не отвечай.» «Если вернётся свет, вернутся и они. — В.»",
		"specchio": "Specchio del bagno · «НЕ ВЕРЬ ЕМУ» — non credergli. Scritto con un dito sul vetro appannato.",
		"impronte": "Impronte nel cortile · stivali da lavoro, tacco consumato a sinistra, taglio obliquo. Identiche alle mie.",
		"foglio": "Foglio nel garage n. 4 · «ЕСЛИ ТЫ ЧИТАЕШЬ ЭТО, ЗНАЧИТ, Я НЕ УСПЕЛ.» — Д. ВОРОНИН · 13.02.1991",
	}

# ------------------------------------------------------------------ terreno

static func s01(v: float) -> float:
	v = clamp(v, 0.0, 1.0)
	return v * v * (3.0 - 2.0 * v)

func ground_h(x: float, z: float) -> float:
	if x > 40.0:
		return APT_FLOOR
	var h := 0.07 * sin(x * 0.21 + z * 0.13) + 0.045 * sin(x * 0.53 - z * 0.37) + 0.03 * sin(z * 0.9 + x * 0.2)
	var drive := s01(1.0 - abs(z - DRIVE_Z) / 2.6)
	h *= 1.0 - drive * 0.85
	if x > A["x0"] - 0.5:
		h += s01((z - (A["z1"] + 1.1)) / -1.1) * 0.38 * (1.0 - drive * 0.5)
	if z > B["z0"] - 0.5:
		h += s01((x - (B["x1"] + 1.1)) / -1.1) * 0.36
	if x > GAR["x0"] - 0.6 and x < GAR["x1"] + 0.6 and z < GAR["z0"] + 0.2:
		h += s01((z - (GAR["z0"] - 1.0)) / 1.0) * 0.32
	return h

func ground_tint(_x: float, z: float) -> float:
	return 1.0 - 0.16 * s01(1.0 - abs(z - DRIVE_Z) / 2.3)

func shelter(x: float, _z: float) -> bool:
	return x > 40.0

func current_bounds(x: float, _z: float) -> Array:
	return APT_BOUNDS if x > 40.0 else YARD_BOUNDS

# ------------------------------------------------------------------ costruzione

func build() -> void:
	snow = SnowField.new()
	add_child(snow)
	snow.build(-62.0, 40.0, -46.0, 34.0, ground_h, ground_tint)
	_build_apartment()
	_build_yard()
	# vecchie tracce, quasi coperte: la neve qui è rimasta intatta per mesi
	for p in [[[-20.3, -2.5], [-15.0, -4.0], [-8.0, -6.2]], [[12.2, -10.3], [12.0, -7.0]],
			[[-20.3, 8.5], [-10.0, 13.0], [0.0, 18.0], [10.0, 19.0], [21.0, 18.5]]]:
		snow.stamp(snow.trail(p, 0.66, 0.28, 0.12))

func _label3(text: String, pos: Vector3, size := 48, col := Color(0.9, 0.88, 0.8), rot_y := 0.0) -> Label3D:
	var l := Label3D.new()
	l.text = text
	l.font_size = size
	l.pixel_size = 0.008
	l.modulate = col
	l.outline_size = 0
	l.shaded = true
	l.double_sided = false
	l.position = pos
	l.rotation.y = rot_y
	add_child(l)
	return l

func _wall(b: Batch, x0: float, x1: float, z0: float, z1: float, h: float, col: Color) -> void:
	b.box(AX + x0, AX + x1, APT_FLOOR, APT_FLOOR + h, z0, z1, col)
	add_box(AX + x0, AX + x1, z0, z1)

func _furn(b: Batch, x0: float, x1: float, y1: float, z0: float, z1: float, col: Color, solid := true) -> void:
	b.box(AX + x0, AX + x1, APT_FLOOR, APT_FLOOR + y1, z0, z1, col)
	if solid:
		add_box(AX + x0, AX + x1, z0, z1)

func _build_apartment() -> void:
	var b := Batch.new()
	var g := Batch.new()
	var F := APT_FLOOR
	var paper_c := Color(0.60, 0.55, 0.40)
	var green := Color(0.30, 0.37, 0.32)
	var low := 0.95
	var wc := Color(0.50, 0.47, 0.38)
	# il buio intorno
	b.box(AX - 45, AX + 45, -0.3, -0.02, -45, 45, Color(0.02, 0.025, 0.035))
	# pavimenti: linoleum, parquet, piastrelle
	b.box(AX + 0, AX + 6, 0, F, -4.5, 0.5, Color(0.47, 0.41, 0.32))
	b.box(AX - 6, AX + 0, 0, F, -4.5, 0.5, Color(0.36, 0.25, 0.16))
	b.box(AX - 6, AX + 6, 0, F, 0.5, 2.0, Color(0.33, 0.23, 0.15))
	b.box(AX - 6, AX - 3, 0, F, 2.0, 4.5, Color(0.60, 0.66, 0.64))
	b.box(AX - 3, AX + 2, 0, F, 2.0, 4.5, Color(0.36, 0.25, 0.16))
	b.box(AX + 2, AX + 6, 0, F, 2.0, 6.5, Color(0.30, 0.29, 0.28))
	for i in 12:                                           # righe del parquet
		b.box(AX - 6, AX + 0, F, F + 0.004, -4.5 + i * 0.42, -4.48 + i * 0.42, Color(0.2, 0.14, 0.09))
	# muri esterni alti a nord e a ovest, bassi (spaccato) verso la camera
	b.box(AX - 6.16, AX + 6.16, 0, 2.7, -4.66, -4.5, paper_c)
	add_box(AX - 6.2, AX + 6.2, -4.8, -4.5)
	b.box(AX + 0, AX + 6.16, 0.9, 2.7, -4.5, -4.47, green)             # pittura verde della cucina
	b.box(AX - 6.16, AX - 6, 0, 2.7, -4.5, 4.66, paper_c)
	add_box(AX - 6.3, AX - 6, -4.5, 4.7)
	b.box(AX - 6, AX - 5.97, 0, 2.7, 2.0, 4.5, Color(0.62, 0.68, 0.66))  # piastrelle del bagno
	_wall(b, 6.0, 6.16, -4.5, 0.75, low, wc)
	_wall(b, 6.0, 6.16, 1.75, 6.56, low, wc)
	_wall(b, -6.0, 2.0, 4.5, 4.66, low, wc)
	_wall(b, 2.0, 6.0, 6.4, 6.56, low, wc)
	_wall(b, 2.0, 2.16, 4.66, 6.4, low, wc)
	# porta d'ingresso (in fondo al corridoio, a est)
	b.box(AX + 5.98, AX + 6.1, F, 2.15, 0.75, 1.75, Color(0.28, 0.17, 0.11))
	b.box(AX + 5.93, AX + 5.98, 1.0, 1.08, 0.95, 1.1, Color(0.7, 0.66, 0.5))
	add_box(AX + 5.95, AX + 6.2, 0.75, 1.75)
	# tramezzi bassi con i varchi delle porte
	_wall(b, -6.0, -3.4, 0.42, 0.58, low, wc)
	_wall(b, -2.4, 2.6, 0.42, 0.58, low, wc)
	_wall(b, 3.6, 6.0, 0.42, 0.58, low, wc)
	_wall(b, -0.08, 0.08, -4.5, 0.42, low, wc)
	_wall(b, -6.0, -5.0, 1.92, 2.08, low, wc)
	_wall(b, -4.0, -1.0, 1.92, 2.08, low, wc)
	_wall(b, 0.0, 3.5, 1.92, 2.08, low, wc)
	_wall(b, 4.5, 6.0, 1.92, 2.08, low, wc)
	_wall(b, -3.08, -2.92, 2.08, 4.5, low, wc)
	_wall(b, 1.92, 2.08, 2.08, 4.5, low, wc)
	_wall(b, 2.08, 4.55, 4.42, 4.58, low, wc)
	_wall(b, 5.55, 6.0, 4.42, 4.58, low, wc)
	hatch_box = add_box(AX + 4.55, AX + 5.55, 4.42, 4.58)
	# ---- cucina
	_furn(b, 0.4, 3.3, 0.9, -4.45, -3.85, Color(0.55, 0.53, 0.46))
	b.box(AX + 0.4, AX + 3.3, F + 0.9, F + 0.94, -4.45, -3.8, Color(0.25, 0.24, 0.22))
	b.box(AX + 2.3, AX + 3.0, F + 0.94, F + 0.98, -4.35, -3.95, Color(0.75, 0.76, 0.74))     # lavello
	b.box(AX + 0.5, AX + 3.2, F + 1.55, F + 2.2, -4.45, -4.15, Color(0.55, 0.53, 0.46))      # pensili
	_furn(b, 4.35, 5.45, 1.05, -4.45, -3.6, Color(0.13, 0.12, 0.12))                         # stufa
	b.box(AX + 4.75, AX + 5.05, F + 1.05, 2.7, -4.4, -4.1, Color(0.1, 0.1, 0.1))             # canna fumaria
	b.box(AX + 4.6, AX + 5.2, F + 0.25, F + 0.6, -3.61, -3.58, Color(0.05, 0.04, 0.04))      # sportello
	_furn(b, 1.5, 2.9, 0.74, -2.0, -1.1, Color(0.45, 0.34, 0.22))                             # tavolo
	b.box(AX + 1.45, AX + 2.95, F + 0.74, F + 0.78, -2.05, -1.05, Color(0.62, 0.58, 0.46))
	_furn(b, 0.9, 1.3, 0.45, -1.75, -1.35, Color(0.4, 0.3, 0.2))                              # sgabello
	# orologio a muro, fermo alle 23:40
	g.cyl(Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(AX + 1.2, 2.25, -4.49)), 0.2, 0.2, 0.03,
		Color(0.55, 0.53, 0.45), 14)
	_label3("23:40", Vector3(AX + 1.2, 1.92, -4.46), 26, Color(0.75, 0.7, 0.55))
	# ---- soggiorno
	_furn(b, -5.95, -5.25, 0.55, -2.2, -1.0, Color(0.33, 0.24, 0.16))                         # mobile tv
	b.box(AX - 5.85, AX - 5.35, F + 0.55, F + 1.1, -1.95, -1.25, Color(0.08, 0.08, 0.09))
	g.box(AX - 5.345, AX - 5.34, F + 0.62, F + 1.03, -1.88, -1.32, Color(0.55, 0.62, 0.75))
	_furn(b, -5.95, -5.3, 0.85, -4.3, -3.0, Color(0.36, 0.26, 0.17))                          # mobile con la foto
	b.box(AX - 5.7, AX - 5.66, F + 0.85, F + 1.1, -3.65, -3.4, Color(0.75, 0.72, 0.62))
	_furn(b, -2.3, -0.3, 0.42, -4.4, -3.55, Color(0.33, 0.2, 0.2))                            # divano
	b.box(AX - 2.3, AX - 0.3, F + 0.42, F + 0.9, -4.4, -4.15, Color(0.3, 0.18, 0.18))
	b.box(AX - 4.6, AX - 1.4, F, F + 0.012, -2.9, -0.6, Color(0.42, 0.16, 0.14))              # tappeto
	# finestra sbarrata dall'interno
	g.box(AX - 3.9, AX - 2.1, 0.95, 2.3, -4.5, -4.47, Color(0.16, 0.2, 0.28))
	for i in 5:
		b.box_xf(Transform3D(Basis(Vector3.BACK, (i - 2) * 0.05), Vector3(AX - 3.0, 1.1 + i * 0.27, -4.43)),
			Vector3(2.1, 0.16, 0.035), Color(0.35 + 0.02 * i, 0.25, 0.15))
	# ---- corridoio: telefono, attaccapanni
	_furn(b, -0.85, -0.2, 0.75, 0.58, 0.9, Color(0.36, 0.26, 0.17), false)
	b.box(AX - 0.68, AX - 0.38, F + 0.75, F + 0.85, 0.62, 0.84, Color(0.5, 0.08, 0.07))
	# ---- bagno: specchio sul muro ovest, lavandino, vasca
	g.box(AX - 5.97, AX - 5.95, 1.25, 2.0, 2.6, 3.4, Color(0.42, 0.47, 0.5))
	_furn(b, -5.95, -5.5, 0.85, 2.7, 3.3, Color(0.8, 0.82, 0.8))
	_furn(b, -5.9, -4.2, 0.55, 3.75, 4.42, Color(0.82, 0.84, 0.82))
	b.box(AX - 5.8, AX - 4.3, F + 0.3, F + 0.56, 3.85, 4.32, Color(0.5, 0.55, 0.56))
	_label3("НЕ ВЕРЬ\nЕМУ", Vector3(AX - 5.94, 1.62, 3.0), 30, Color(0.8, 0.86, 0.9), PI * 0.5)
	# ---- camera: letto, armadio
	_furn(b, 0.1, 1.85, 0.45, 2.75, 4.4, Color(0.42, 0.44, 0.5))
	b.box(AX + 0.1, AX + 1.85, F + 0.45, F + 0.6, 3.9, 4.4, Color(0.75, 0.74, 0.7))
	_furn(b, -2.85, -1.55, 1.95, 2.1, 2.62, Color(0.3, 0.2, 0.13))
	b.box(AX - 2.2, AX - 1.56, F + 0.05, F + 1.9, 2.62, 2.66, Color(0.24, 0.16, 0.1))          # anta aperta
	var wb := Batch.new()
	for i in 6:
		var k := i / 5.0
		wb.box_at(Vector3(AX + lerp(-0.6, -1.75, k) + (0.09 if i % 2 == 0 else -0.09), F + 0.006,
			lerp(2.25, 3.0, k)), Vector3(0.12, 0.004, 0.27), Color(0.12, 0.13, 0.15), 0.9)
	wet = wb.instance(self, null, false)
	wet.visible = false
	# ---- ripostiglio: cassa della legna, mobile davanti all'apertura
	_furn(b, 2.7, 3.55, 0.5, 3.0, 3.65, Color(0.35, 0.27, 0.18))
	var lg := Batch.new()
	for i in 5:
		lg.box_at(Vector3(AX + 2.85 + i * 0.14, F + 0.55 + (i % 2) * 0.07, 3.32), Vector3(0.1, 0.1, 0.55),
			Color(0.45, 0.33, 0.2), 0.1 * i)
	logs = lg.instance(self)
	var cb := Batch.new()
	cb.box(-0.6, 0.6, 0, 1.8, -0.28, 0.28, Color(0.32, 0.22, 0.14))
	cb.box(-0.56, -0.02, 0.1, 1.7, 0.28, 0.3, Color(0.26, 0.18, 0.11))
	cb.box(0.02, 0.56, 0.1, 1.7, 0.28, 0.3, Color(0.26, 0.18, 0.11))
	cabinet = cb.instance(self)
	cabinet.position = Vector3(AX + 5.05, F, 4.1)
	cab_box = add_box(AX + 4.42, AX + 5.68, 3.8, 4.42)
	cab_box2 = add_box(AX + 3.6, AX + 4.5, 3.8, 4.42)
	cab_box2["off"] = true
	# ---- vano tecnico: gancio con la chiave, scala di servizio
	b.box(AX + 3.05, AX + 3.15, 1.3, 1.36, 6.38, 6.42, Color(0.2, 0.2, 0.2))
	var hk := Batch.new()
	hk.box(AX + 3.07, AX + 3.13, 1.08, 1.3, 6.35, 6.37, Color(0.7, 0.62, 0.4))
	hk.box(AX + 3.02, AX + 3.18, 0.96, 1.08, 6.35, 6.36, Color(0.6, 0.5, 0.35))
	hook_key = hk.instance(self, null, false)
	b.box(AX + 4.6, AX + 5.7, 0.0, F + 0.006, 4.9, 5.9, Color(0.0, 0.0, 0.0))                  # la botola
	for sx in [4.7, 5.6]:
		b.box(AX + sx - 0.03, AX + sx + 0.03, F, F + 1.1, 5.85, 5.91, Color(0.25, 0.25, 0.27))
	for i in 4:
		b.box(AX + 4.7, AX + 5.6, F + 0.2 + i * 0.26, F + 0.24 + i * 0.26, 5.86, 5.9, Color(0.25, 0.25, 0.27))
	# tubi lungo il muro del vano
	b.rod(Vector3(AX + 2.3, 0.3, 6.3), Vector3(AX + 2.3, 2.4, 6.3), 0.06, Color(0.3, 0.2, 0.15))
	b.rod(Vector3(AX + 2.55, 0.3, 6.3), Vector3(AX + 2.55, 2.4, 6.3), 0.04, Color(0.25, 0.27, 0.3))
	# blocca la fascia a sud del muro, fuori dal vano
	add_box(AX - 6.2, AX + 2.0, 4.6, 6.6)
	b.instance(self)
	g.instance(self, Batch.glow(1.0), false)
	# tavola del pavimento sollevata, giornali
	var pk := Batch.new()
	pk.box_xf(Transform3D(Basis(Vector3.BACK, 0.06), Vector3(AX + 4.3, F + 0.02, -2.0)), Vector3(0.9, 0.03, 0.16),
		Color(0.4, 0.3, 0.2))
	plank = pk.instance(self, null, false)
	var pp := Batch.new()
	pp.box(-0.2, 0.2, 0, 0.32, -0.15, 0.15, Color(0.72, 0.68, 0.55), Color(0.8, 0.77, 0.66))
	paper = pp.instance(self)
	paper.position = Vector3(AX + 3.85, F, -3.72)
	# luci: televisore, stufa
	tv_light = OmniLight3D.new()
	tv_light.light_color = Color(0.55, 0.68, 1.0)
	tv_light.omni_range = 7.5
	tv_light.light_energy = 1.4
	tv_light.shadow_enabled = Gfx.pc
	tv_light.position = Vector3(AX - 4.9, 1.0, -1.6)
	add_child(tv_light)
	stove = make_fire(AX + 4.9, 0.5, -3.5, false, 2.6)
	stove["x"] = AX + 4.85
	stove["z"] = -3.0
	var room := OmniLight3D.new()                           # chiarore debole dalla finestra del corridoio
	room.light_color = Color(0.5, 0.6, 0.8)
	room.omni_range = 9.0
	room.light_energy = 0.9
	room.position = Vector3(AX + 1.0, 2.2, 2.0)
	add_child(room)

func _build_yard() -> void:
	var b := Batch.new()
	var g := Batch.new()
	# palazzi: il lungo A a nord con il sottopasso, il B a ovest, uno più lontano a est
	Props.building(b, g, A["x0"], A["x1"], A["z0"], A["z1"], 5, rng, [TUN["x0"], TUN["x1"], 3.4], 0.03)
	Props.building(b, g, B["x0"], B["x1"], B["z0"], B["z1"], 5, rng, null, 0.03)
	Props.building(b, g, 31.0, 42.0, -24.0, -2.0, 5, rng, null, 0.04)
	Props.building(b, g, -30.0, 6.0, -46.0, -35.0, 9, rng, null, 0.04)
	add_box(A["x0"], TUN["x0"], A["z0"], A["z1"])
	add_box(TUN["x1"], A["x1"], A["z0"], A["z1"])
	add_box(B["x0"], B["x1"], B["z0"], B["z1"])
	for ex in [-8.0, 2.0, 12.0, 20.5]:
		Props.entrance(b, ex, A["z1"], Color(0.2, 0.22, 0.25) if ex == 2.0 else Color(0.30, 0.20, 0.16))
		add_box(ex - 1.3, ex + 1.3, A["z1"], A["z1"] + 0.3)
	_label3("ЦОЙ ЖИВ", Vector3(-4.2, 1.5, A["z1"] + 0.03), 56, Color(0.12, 0.12, 0.14))
	_label3("КИНО", Vector3(16.0, 1.3, A["z1"] + 0.03), 44, Color(0.5, 0.1, 0.08))
	# ciminiera della ТЭЦ, persa nella nebbia
	for i in 9:
		b.cyl_at(Vector3(-52.0, i * 5.0, -52.0), 2.6 - i * 0.12, 2.48 - i * 0.12, 5.0,
			Color(0.6, 0.6, 0.6) if i % 2 == 0 else Color(0.45, 0.12, 0.1), 10)
	# sottopasso: pareti interne scure e cancello elettrico
	b.box(TUN["x0"], TUN["x1"], 3.38, 3.42, A["z0"], A["z1"], Color(0.12, 0.12, 0.13))
	var gb := Batch.new()
	var w: float = TUN["x1"] - TUN["x0"]
	for i in 12:
		gb.box(-w * 0.5 + 0.1 + i * (w - 0.2) / 11.0 - 0.03, -w * 0.5 + 0.1 + i * (w - 0.2) / 11.0 + 0.03,
			0.1, 2.5, -0.03, 0.03, Props.IRON)
	gb.box(-w * 0.5, w * 0.5, 0.1, 0.2, -0.04, 0.04, Props.IRON)
	gb.box(-w * 0.5, w * 0.5, 2.4, 2.5, -0.04, 0.04, Props.IRON)
	gb.box(-w * 0.5, w * 0.5, 1.2, 1.28, -0.04, 0.04, Props.IRON)
	gate = gb.instance(self)
	gate.position = Vector3((TUN["x0"] + TUN["x1"]) * 0.5, 0.2, GATE_Z)
	gate_box = add_box(TUN["x0"], TUN["x1"], GATE_Z - 0.2, GATE_Z + 0.2)
	gate_lamp = StandardMaterial3D.new()
	gate_lamp.albedo_color = Color(0.25, 0.03, 0.03)
	gate_lamp.emission_enabled = true
	gate_lamp.emission = Color(0.6, 0.05, 0.05)
	gate_lamp.emission_energy_multiplier = 0.3
	var gl := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.09
	sm.height = 0.18
	gl.mesh = sm
	gl.material_override = gate_lamp
	gl.position = Vector3(TUN["x1"] + 0.35, 2.3, A["z1"] + 0.08)
	add_child(gl)
	b.box(TUN["x1"] + 0.2, TUN["x1"] + 0.5, 1.9, 2.5, A["z1"], A["z1"] + 0.1, Props.IRON)
	# garage: sei box in fila, saracinesche a sud. Il n. 4 si apre.
	_build_garages(b)
	# cabina elettrica ТП-4
	b.box(TP["x0"], TP["x1"], 0, 3.0, TP["z0"], TP["z1"], Color(0.58, 0.57, 0.52))
	b.box(TP["x0"] - 0.15, TP["x1"] + 0.15, 3.0, 3.2, TP["z0"] - 0.15, TP["z1"] + 0.15, Props.CONCRETE_D, Props.SNOW)
	b.box(17.0, 18.0, 0.05, 2.1, TP["z1"], TP["z1"] + 0.06, Color(0.25, 0.27, 0.28))
	b.box(16.0, 16.6, 1.5, 2.0, TP["z1"], TP["z1"] + 0.05, Color(0.75, 0.68, 0.2))
	add_box(TP["x0"], TP["x1"], TP["z0"], TP["z1"])
	_label3("ТП-4", Vector3(17.5, 2.5, TP["z1"] + 0.04), 60, Color(0.12, 0.12, 0.12))
	_label3("НЕ\nВКЛЮЧАТЬ!", Vector3(16.3, 1.75, TP["z1"] + 0.07), 14, Color(0.1, 0.1, 0.1))
	tp_lamp = StandardMaterial3D.new()
	tp_lamp.albedo_color = Color(0.3, 0.25, 0.1)
	tp_lamp.emission_enabled = true
	tp_lamp.emission = Color(1.0, 0.75, 0.3)
	tp_lamp.emission_energy_multiplier = 0.0
	var tl := MeshInstance3D.new()
	var sm2 := SphereMesh.new()
	sm2.radius = 0.12
	sm2.height = 0.24
	tl.mesh = sm2
	tl.material_override = tp_lamp
	tl.position = Vector3(17.5, 2.85, TP["z1"] + 0.15)
	add_child(tl)
	# auto sepolte
	Props.car(b, Vector3(CAR.x, ground_h(CAR.x, CAR.y), CAR.y), 0.06, Color(0.55, 0.16, 0.13), 0.3)
	add_box(CAR.x - 2.0, CAR.x + 2.0, CAR.y - 0.85, CAR.y + 0.85)
	Props.car(b, Vector3(CAR2.x, ground_h(CAR2.x, CAR2.y), CAR2.y), -0.1, Color(0.62, 0.62, 0.55), 0.22)
	add_box(CAR2.x - 2.0, CAR2.x + 2.0, CAR2.y - 0.85, CAR2.y + 0.85)
	Props.car(b, Vector3(-17.5, ground_h(-17.5, -4.6), -4.6), 1.5, Color(0.22, 0.33, 0.42), 0.35)
	add_box(-18.4, -16.6, -6.6, -2.6)
	# bidone del fuoco e panchine
	Props.barrel(b, Vector3(BARREL.x, ground_h(BARREL.x, BARREL.y), BARREL.y))
	add_circle(BARREL.x, BARREL.y, 0.4)
	barrel_fire = make_fire(BARREL.x, ground_h(BARREL.x, BARREL.y) + 0.85, BARREL.y, false, 3.6)
	for bp in [[-11.2, -0.2, 0.4], [-17.2, 5.75, 0.0], [-6.9, 0.3, -0.5], [4.6, 8.3, 0.0]]:
		Props.bench(b, Vector3(bp[0], ground_h(bp[0], bp[1]), bp[1]), bp[2])
		add_box(bp[0] - 0.9, bp[0] + 0.9, bp[1] - 0.3, bp[1] + 0.3)
	var bt := Batch.new()
	bt.box(-0.04, 0.04, 0, 0.09, -0.03, 0.03, Color(0.15, 0.3, 0.6), Color(0.75, 0.6, 0.2))
	battery_mesh = bt.instance(self, null, false)
	battery_mesh.position = Vector3(-17.2, ground_h(-17.2, 5.2) + 0.01, 5.3)
	# parco giochi: altalena, giostra, sabbiera, scivolo
	_build_playground(b)
	# alberi
	for tpos in [[-13.0, 5.5], [-5.5, 9.2], [9.5, 3.2], [20.5, 5.5], [-18.2, 1.2], [21.5, -3.4], [-3.0, -4.4],
			[15.0, 7.2], [-15.5, 16.5], [6.0, 19.5], [22.0, 13.0]]:
		Props.tree(b, Vector3(tpos[0], ground_h(tpos[0], tpos[1]) - 0.05, tpos[1]), rng, rng.randf_range(5.0, 7.5))
		add_circle(tpos[0], tpos[1], 0.32)
	# lampioni: spenti dal 12 febbraio. Quello in fondo si accenderà da solo.
	for lp in [[-6.0, -10.3, PI * 1.5], [10.5, -10.3, PI * 1.5], [22.0, 0.5, PI], [-19.5, 9.0, 0.0]]:
		Props.lamp_post(b, Vector3(lp[0], ground_h(lp[0], lp[1]), lp[1]), lp[2])
		add_circle(lp[0], lp[1], 0.18)
	var head := Props.lamp_post(b, Vector3(FAR_LAMP.x, ground_h(FAR_LAMP.x, FAR_LAMP.y), FAR_LAMP.y), 0.0)
	add_circle(FAR_LAMP.x, FAR_LAMP.y, 0.18)
	far_light = lamp_light(head + Vector3(0, -0.15, 0), 0.0, 14.0)
	# recinzioni, cassonetti
	Props.fence(b, Vector3(23.7, 0, -10.8), Vector3(23.7, 0, 21.6))
	Props.fence(b, Vector3(-20.6, 0, 21.6), Vector3(23.7, 0, 21.6), 1.1)
	Props.fence(b, Vector3(-20.9, 0, 14.2), Vector3(-20.9, 0, 21.6), 1.1)
	Props.dumpster(b, Vector3(-19.4, ground_h(-19.4, -9.5), -9.6), 0.1)
	Props.dumpster(b, Vector3(-17.6, ground_h(-17.6, -9.5), -9.8), -0.05)
	add_box(-20.3, -16.7, -10.4, -9.0)
	b.instance(self)
	g.instance(self, Batch.glow(1.5), false)
	# la sagoma sotto il lampione
	var fb := Batch.new()
	Props.silhouette(fb, Vector3.ZERO, 0.0)
	fig = fb.instance(self)
	fig.position = Vector3(fig_pos.x, ground_h(fig_pos.x, fig_pos.y), fig_pos.y)
	fig.rotation.y = atan2(ARRIVE.x - fig_pos.x, ARRIVE.y - fig_pos.y)
	fig.visible = false

func _build_garages(b: Batch) -> void:
	var z0: float = GAR["z0"]
	var z1: float = GAR["z1"]
	var hh := 2.5
	var wall := Color(0.42, 0.40, 0.38)
	for i in GAR["n"]:
		var x0: float = GAR["x0"] + i * 3.2
		var x1 := x0 + 3.2
		var open: bool = i == GAR["open"]
		b.box(x0, x1, 0, hh, z0, z0 + 0.2, wall)
		b.box(x0, x0 + 0.12, 0, hh, z0, z1, wall)
		b.box(x1 - 0.12, x1, 0, hh, z0, z1, wall)
		b.box(x0, x1, 2.2, hh, z1 - 0.12, z1, wall)
		_label3("№%d" % (i + 1), Vector3(x0 + 1.6, 2.36, z1 + 0.02), 28, Color(0.85, 0.82, 0.7))
		if not open:
			b.box(x0 - 0.1, x1 + 0.1, hh, hh + 0.14, z0 - 0.15, z1 + 0.25, Props.CONCRETE_D, Props.SNOW)
			var dc := Color(0.30, 0.20, 0.16) if i % 2 == 0 else Color(0.22, 0.28, 0.26)
			b.box(x0 + 0.12, x1 - 0.12, 0, 2.2, z1 - 0.1, z1 - 0.04, dc)
			for k in 5:
				b.box(x0 + 0.12, x1 - 0.12, 0.3 + k * 0.42, 0.33 + k * 0.42, z1 - 0.04, z1 - 0.02, Color(0.1, 0.1, 0.1))
	add_box(GAR["x0"], GAR["x0"] + 9.6, z0, z1)
	add_box(GAR["x0"] + 12.8, GAR["x1"], z0, z1)
	var gx0: float = GAR["x0"] + 9.6
	add_box(gx0, gx0 + 3.2, z0, z0 + 0.3)
	add_box(gx0, gx0 + 0.16, z0, z1)
	add_box(gx0 + 3.04, gx0 + 3.2, z0, z1)
	gar_door_box = add_box(gx0, gx0 + 3.2, z1 - 0.2, z1 + 0.05)
	# tetto e saracinesca del n. 4: pezzi a parte
	var rb := Batch.new()
	rb.box(gx0 - 0.1, gx0 + 3.3, hh, hh + 0.14, z0 - 0.15, z1 + 0.25, Props.CONCRETE_D, Props.SNOW)
	gar_roof = rb.instance(self)
	var db := Batch.new()
	db.box(-1.48, 1.48, 0, 2.2, -0.03, 0.03, Color(0.26, 0.2, 0.17))
	for k in 5:
		db.box(-1.48, 1.48, 0.3 + k * 0.42, 0.33 + k * 0.42, 0.03, 0.05, Color(0.1, 0.1, 0.1))
	db.box(-0.08, 0.08, 0.95, 1.12, 0.05, 0.1, Color(0.5, 0.45, 0.3))           # lucchetto
	gar_door = db.instance(self)
	gar_door.position = Vector3(gar_x, 0, z1 - 0.07)
	# dentro: pavimento, auto sotto il telo, calendario, armadietto
	b.box(gx0 + 0.12, gx0 + 3.08, 0, 0.04, z0 + 0.2, z1, Color(0.2, 0.2, 0.2))
	b.box(gar_x - 0.95, gar_x + 0.6, 0.04, 1.15, z0 + 0.5, z0 + 3.9, Color(0.33, 0.36, 0.33))
	b.box(gar_x - 0.75, gar_x + 0.4, 1.15, 1.5, z0 + 1.2, z0 + 3.0, Color(0.33, 0.36, 0.33))
	add_box(gar_x - 0.95, gar_x + 0.6, z0 + 0.3, z0 + 3.9)
	b.box(gar_x + 0.95, gar_x + 1.42, 0.04, 1.9, z1 - 1.5, z1 - 0.8, Color(0.3, 0.36, 0.38))
	add_box(gar_x + 0.95, gar_x + 1.45, z1 - 1.5, z1 - 0.8)
	b.box(gar_x - 1.47, gar_x - 1.45, 1.3, 1.8, z1 - 1.2, z1 - 0.85, Color(0.8, 0.76, 0.65))

func _build_playground(b: Batch) -> void:
	var sx := 2.0
	var sz := 5.2
	var gy := ground_h(sx, sz)
	var red := Color(0.5, 0.14, 0.1)
	for s in [-1.0, 1.0]:
		b.rod(Vector3(sx + s * 1.3, gy, sz - 0.7), Vector3(sx + s * 1.3, gy + 2.3, sz), 0.04, red)
		b.rod(Vector3(sx + s * 1.3, gy, sz + 0.7), Vector3(sx + s * 1.3, gy + 2.3, sz), 0.04, red)
	b.rod(Vector3(sx - 1.3, gy + 2.3, sz), Vector3(sx + 1.3, gy + 2.3, sz), 0.04, red)
	add_circle(sx - 1.3, sz, 0.3)
	add_circle(sx + 1.3, sz, 0.3)
	swing_seat = Node3D.new()
	swing_seat.position = Vector3(sx, gy + 2.3, sz)
	add_child(swing_seat)
	var sb := Batch.new()
	sb.rod(Vector3(-0.22, 0, 0), Vector3(-0.22, -1.75, 0), 0.012, Props.IRON)
	sb.rod(Vector3(0.22, 0, 0), Vector3(0.22, -1.75, 0), 0.012, Props.IRON)
	sb.box(-0.28, 0.28, -1.8, -1.75, -0.1, 0.1, Props.WOOD)
	sb.instance(swing_seat)
	# giostra
	var cx := 7.2
	var cz := 2.2
	var cy := ground_h(cx, cz)
	b.cyl_at(Vector3(cx, cy, cz), 0.08, 0.08, 0.9, Props.IRON, 6)
	b.cyl_at(Vector3(cx, cy + 0.3, cz), 1.3, 1.3, 0.07, Color(0.2, 0.35, 0.4), 12)
	b.cyl_at(Vector3(cx, cy + 0.37, cz), 1.25, 1.25, 0.04, Props.SNOW, 12)
	for i in 4:
		var a := TAU * i / 4.0
		b.rod(Vector3(cx, cy + 0.9, cz), Vector3(cx + cos(a) * 1.2, cy + 0.75, cz + sin(a) * 1.2), 0.025, Color(0.6, 0.5, 0.1))
	add_circle(cx, cz, 1.3)
	# sabbiera
	var bx := -2.6
	var bz := 6.8
	var by := ground_h(bx, bz)
	b.box(bx - 1.3, bx + 1.3, by, by + 0.28, bz - 1.3, bz - 1.15, Color(0.4, 0.3, 0.14), Props.SNOW)
	b.box(bx - 1.3, bx + 1.3, by, by + 0.28, bz + 1.15, bz + 1.3, Color(0.4, 0.3, 0.14), Props.SNOW)
	b.box(bx - 1.3, bx - 1.15, by, by + 0.28, bz - 1.3, bz + 1.3, Color(0.2, 0.3, 0.42), Props.SNOW)
	b.box(bx + 1.15, bx + 1.3, by, by + 0.28, bz - 1.3, bz + 1.3, Color(0.2, 0.3, 0.42), Props.SNOW)
	# scivolo
	var lx := -8.0
	var lz := 7.6
	var ly := ground_h(lx, lz)
	b.box(lx - 0.35, lx + 0.35, ly + 1.5, ly + 1.56, lz - 0.4, lz + 0.4, Color(0.6, 0.5, 0.1), Props.SNOW)
	for s in [-0.3, 0.3]:
		b.rod(Vector3(lx + s, ly, lz - 0.35), Vector3(lx + s, ly + 1.5, lz - 0.35), 0.03, red)
		b.rod(Vector3(lx + s, ly, lz + 0.35), Vector3(lx + s, ly + 1.5, lz + 0.35), 0.03, red)
	b.box_xf(Transform3D(Basis(Vector3.RIGHT, 0.52), Vector3(lx, ly + 0.78, lz + 1.6)), Vector3(0.6, 0.05, 2.9),
		Color(0.55, 0.57, 0.6))
	add_box(lx - 0.5, lx + 0.5, lz - 0.5, lz + 2.9)

# ------------------------------------------------------------------ interazioni

func items() -> Array:
	var G := Game
	var say := hud.say
	var gz1: float = GAR["z1"]
	return [
		# ---- appartamento
		{"id": "orologio", "x": AX + 1.2, "z": -3.5, "r": 1.3, "marker": false, "label": "Orologio da parete",
			"use": func(): say.call("Le 23:40. La lancetta dei secondi non si muove.")},
		{"id": "tv", "x": AX - 4.9, "z": -1.6, "r": 1.4, "marker": false, "label": "Televisore",
			"use": func(): say.call("Nessun canale. Solo interferenze. Il volume cambia da solo.")},
		{"id": "telefono", "x": AX - 0.5, "z": 1.0, "r": 1.2, "marker": false,
			"label": func(): return "Solleva il ricevitore" if G.fl("phone") else "Telefono", "use": _use_phone},
		{"id": "porta", "x": AX + 5.4, "z": 1.25, "r": 1.3, "my": 1.2, "label": "Porta d'ingresso",
			"done": func(): return G.fl("door"), "use": _use_door},
		{"id": "finestra", "x": AX - 3.0, "z": -3.7, "r": 1.4, "my": 1.5, "label": "Finestra",
			"done": func(): return G.fl("window"), "use": func():
				G.flags["window"] = true
				say.call("Le assi sono state inchiodate dall'interno. I chiodi sono vecchi, alcuni arrugginiti.")},
		{"id": "foto", "x": AX - 4.9, "z": -3.5, "r": 1.3, "marker": false, "label": "Fotografia sul mobile",
			"use": func(): say.call(["Io, davanti alla centrale ТЭЦ. La fotografia è piegata, con un taglio netto sul bordo.",
				"Sul retro non c'è nessuna data."])},
		{"id": "specchio", "x": AX - 5.0, "z": 3.0, "r": 1.3, "my": 1.6, "clue": true, "label": "Specchio del bagno",
			"done": func(): return G.clues.has("specchio"), "use": func():
				G.flags["bath"] = true
				say.call(["Il vetro è appannato. Qualcuno ci ha scritto sopra con un dito:", Hud.q("«НЕ ВЕРЬ ЕМУ»"), "Non credergli."])},
		{"id": "cassetto", "x": AX + 1.3, "z": -3.4, "r": 1.3, "pick": true, "label": "Apri i cassetti",
			"gone": func(): return G.have("fiammiferi"), "use": func():
				G.items["fiammiferi"] = true
				say.call("Nel cassetto, tra posate e tappi di sughero, una scatola di fiammiferi «Пламя».")},
		{"id": "giornale", "x": AX + 3.9, "z": -3.3, "r": 1.2, "pick": true, "label": "Prendi i giornali",
			"gone": func(): return G.have("giornale") or stove["lit"], "use": func():
				G.items["giornale"] = true
				paper.scale.y = 0.3
				say.call("Una pila di «Правда» ingiallita. L'ultima è del 12 febbraio.")},
		{"id": "legna", "x": AX + 3.15, "z": 2.7, "r": 1.3, "pick": true, "label": "Prendi la legna",
			"gone": func(): return G.have("legna") or stove["lit"], "use": func():
				G.items["legna"] = true
				logs.scale = Vector3(1, 0.4, 1)
				say.call("Pezzi di legna piccoli, secchi. Abbastanza per la stufa.")},
		{"id": "stufa", "x": AX + 4.85, "z": -3.0, "r": 1.4, "my": 1.2,
			"label": func(): return "Scaldati alla stufa" if stove["lit"] else "Stufa",
			"done": func(): return stove["lit"], "use": _use_stove},
		{"id": "armadio", "x": AX - 1.9, "z": 3.1, "r": 1.3, "marker": false, "label": "Armadio", "use": func():
			if G.fl("steps"):
				say.call(["La porta della camera era socchiusa. L'armadio è aperto.",
					"Sul pavimento ci sono impronte bagnate. Nessuna finestra è aperta. Finiscono davanti all'armadio.",
					"Dentro non c'è nessuno."])
			else:
				say.call("Cappotti, una camicia da lavoro, l'odore della naftalina. Dentro non c'è nessuno.")},
		{"id": "tavola", "x": AX + 4.3, "z": -2.0, "r": 1.3, "my": 0.4, "label": "Solleva la tavola",
			"needs": func(): return stove["lit"], "gone": func(): return G.fl("cavity"), "use": _open_cavity},
		{"id": "mobile", "x": AX + 5.0, "z": 3.4, "r": 1.3, "label": "Sposta il mobile",
			"gone": func(): return G.fl("moved"), "use": _use_cabinet},
		{"id": "gancio", "x": AX + 3.1, "z": 5.8, "r": 1.2, "my": 1.2, "pick": true, "label": "Prendi la chiave dal gancio",
			"gone": func(): return G.have("chiave"), "use": func():
				G.items["chiave"] = true
				hook_key.visible = false
				say.call("Una chiave da manutenzione, appesa al gancio. Sull'etichetta di cartone: " + Hud.q("«ТП-4»") + ".")},
		{"id": "scala", "x": AX + 5.1, "z": 5.3, "r": 1.2, "my": 0.4, "label": "Scendi la scala di servizio", "use": func():
			if not G.have("chiave"):
				say.call("Sul gancio, accanto alla scala, c'è appesa una chiave. Prima la prendo.")
			else:
				_go_outside()},
		# ---- cortile
		{"id": "fuoco", "x": BARREL.x + 0.9, "z": BARREL.y + 0.6, "r": 1.7, "my": 1.3,
			"label": func(): return "Scaldati al fuoco" if barrel_fire["lit"] else "Bidone del fuoco",
			"done": func(): return barrel_fire["lit"], "use": _use_barrel},
		{"id": "portone", "x": ARRIVE.x, "z": ARRIVE.y - 0.5, "r": 1.4, "marker": false, "label": "Porta di servizio",
			"use": func(): say.call("La porta di ferro della scala di servizio. Dall'esterno non ha maniglia.")},
		{"id": "auto", "x": CAR.x - 0.3, "z": CAR.y + 1.6, "r": 1.8, "marker": false, "pick": true,
			"label": "Fruga nell'auto", "use": func():
				if not G.fl("car"):
					G.flags["car"] = true
					G.cans += 2
					G.items["mappa"] = true
					say.call(["ВАЗ-2101, sepolta fino ai finestrini. Nel bagagliaio: due scatolette di «Тушёнка».",
						"Sul sedile, una mappa dello ЗАТО-42. Qualcuno ha cerchiato in rosso la centrale termoelettrica. La mia centrale."])
				else:
					say.call("Il motore non dà segni di vita.")},
		{"id": "batteria", "x": -17.2, "z": 5.2, "r": 1.5, "my": 0.5, "marker": false, "pick": true,
			"label": "Raccogli la pila", "gone": func(): return G.fl("bat1"), "use": func():
				G.flags["bat1"] = true
				battery_mesh.visible = false
				G.battery = min(100.0, G.battery + 45.0)
				say.call("Una pila quadrata da 4,5 volt, caduta sotto la panchina. Per la torcia.")},
		{"id": "altalena", "x": 2.0, "z": 5.2, "r": 1.5, "marker": false, "label": "Ferma l'altalena", "use": func():
			swing_stop = 4.0
			say.call("La fermo con la mano. Il ferro è così freddo che brucia. Appena la lascio, riprende a dondolare.")},
		{"id": "tp", "x": 17.5, "z": -1.3, "r": 1.7, "my": 1.4, "label": "Cabina elettrica ТП-4",
			"done": func(): return G.fl("power"), "use": _use_tp},
		{"id": "cancello", "x": (TUN["x0"] + TUN["x1"]) * 0.5, "z": GATE_Z + 1.1, "r": 1.7, "my": 1.3,
			"label": func(): return "Il cancello" if G.fl("gate") else "Apri il cancello",
			"done": func(): return G.fl("gate"), "use": _use_gate},
		{"id": "impronte", "x": -14.3, "z": -8.9, "r": 1.5, "my": 0.3, "clue": true, "label": "Esamina le impronte",
			"needs": func(): return G.fl("gate"), "done": func(): return G.clues.has("impronte"), "use": func():
				say.call(["Passo regolare. Tacco consumato sul lato sinistro. Qualcuno indossava stivali da lavoro.",
					"Guardo i miei stivali.", "La suola è identica. Il taglio obliquo sul tacco coincide perfettamente."])
				say.call("«Non è possibile…»", "DMITRI")},
		{"id": "garage", "x": gar_x, "z": gz1 + 0.9, "r": 1.6, "my": 1.2,
			"label": func(): return "Garage n. 4" if G.fl("garage") else "Apri il garage n. 4",
			"done": func(): return G.fl("garage"), "use": _use_garage},
		{"id": "telo", "x": gar_x - 0.15, "z": gz1 - 1.3, "r": 1.2, "marker": false, "label": "Il telo",
			"needs": func(): return G.fl("garage"), "use": func():
				say.call("Un'automobile sotto un telo. Lo sollevo di un palmo: la carrozzeria è gelata. Lo lascio ricadere.")},
		{"id": "calendario", "x": gar_x - 1.0, "z": gz1 - 1.0, "r": 1.0, "marker": false, "label": "Calendario",
			"needs": func(): return G.fl("garage"), "use": func(): say.call("Un vecchio calendario. Fermo al 12 febbraio 1991.")},
		{"id": "foglio", "x": gar_x + 0.75, "z": gz1 - 1.15, "r": 1.1, "my": 1.2, "clue": true, "label": "Apri l'armadietto",
			"needs": func(): return G.fl("garage"), "gone": func(): return G.fl("finale"), "use": _finale},
	]

func _use_phone() -> void:
	if not Game.fl("phone"):
		Game.flags["phone"] = true
		hud.say("La linea è morta.")
		return
	hud.say(["Resto in ascolto. Niente segnale… poi un respiro. Lento. Qualcuno, dall'altra parte, respira nel ricevitore.",
		"Riappoggio la cornetta."])
	hud.say("Il respiro continua ancora per un istante. Poi il silenzio.")

func _use_door() -> void:
	Game.flags["door"] = true
	if Game.fl("cavity"):
		hud.say(["Sotto la porta c'è un sottile strato di neve.",
			"Ma la neve non entra dal pianerottolo. Sembra venire da dentro l'appartamento."])
	else:
		hud.say("Tre mandate, chiuse dall'interno. La chiave non c'è. La porta non si apre.")

func _use_stove() -> void:
	if stove["lit"]:
		hud.say("Il calore della stufa mi entra nelle mani. Fuori, il vento.")
		return
	var miss := []
	if not Game.have("fiammiferi"):
		miss.append("i fiammiferi")
	if not Game.have("giornale"):
		miss.append("della carta")
	if not Game.have("legna"):
		miss.append("la legna")
	if not miss.is_empty():
		var txt := ""
		for i in miss.size():
			txt += miss[i]
			if i < miss.size() - 2:
				txt += ", "
			elif i == miss.size() - 2:
				txt += " e "
		hud.say(["La canna fumaria sembra libera. Non posso restare qui senza accenderla.", "Mi servono " + txt + "."])
		return
	light_fire(stove)
	Game.items.erase("giornale")
	Game.items.erase("legna")
	paper.visible = false
	Sfx.play("ignite", -6.0)
	Game.checkpoint = Vector2(AX + 4.6, -2.4)
	hud.say("La carta prende subito, poi la legna. La stufa comincia a ticchettare scaldandosi.")
	after(2.6, func():
		Sfx.play("floor", -4.0, 0.7)
		after(0.52, func(): Sfx.play("floor", -4.0, 0.7))
		after(1.04, func(): Sfx.play("floor", -4.0, 0.7))
		Game.flags["steps"] = true
		wet.visible = true
		main.dread = 1.0)
	after(4.2, func(): hud.tell("stepsHeard", ["Dalla camera da letto. Tre passi.", "Poi silenzio."]))
	after(9.0, func(): hud.tell("board",
		"Alla luce del fuoco noto una tavola del pavimento, vicino al muro. È leggermente sollevata."))

func _open_cavity() -> void:
	Game.flags["cavity"] = true
	Game.clues["quaderno"] = true
	Game.items["quaderno"] = true
	Game.items["radio"] = true
	Game.items["chiaveGarage"] = true
	Game.items["piantina"] = true
	plank.rotation.z = 0.5
	plank.position.y += 0.12
	Sfx.play("creak", -8.0)
	hud.say(["Sotto la tavola c'è una piccola cavità. Dentro: un quaderno verde, una radio da campo, una chiave e un foglietto piegato.",
		"Il quaderno è pieno di appunti tecnici, numeri, schemi elettrici. Alcune pagine sono strappate. Tre frasi sono leggibili:",
		Hud.q("«Не включай свет.»") + " — Non accendere la luce.",
		Hud.q("«Если услышишь стук — не отвечай.»") + " — Se senti bussare, non rispondere.",
		Hud.q("«Если вернётся свет, вернутся и они. — В.»") + " — Se torna la luce, torneranno anche loro."], "QUADERNO VERDE")
	hud.act(func(): Sfx.play("radio", -6.0))
	hud.say(["La radio non ha batterie. Il selettore è bloccato su una frequenza che non conosco. Giro la manopola…",
		Hud.q("«…Воронин…»"), "Poi silenzio."], "RADIO DA CAMPO")
	hud.say(["La chiave è fredda, macchiata di ruggine. Sulla targhetta: " + Hud.q("«ГАРАЖ №4»") + ". Sul retro, inciso: 0417.",
		"Il foglietto è una piantina del cortile, incompleta. Un segno sulla cabina elettrica " + Hud.q("«ТП-4»") + ". Manca un pezzo del foglio."])

func _use_cabinet() -> void:
	if not Game.fl("cavity"):
		hud.say(["Il mobile è pesante. Dietro, dal basso, arriva uno spiffero gelido.",
			"Prima voglio capire cosa è successo qui dentro."])
		return
	Game.flags["moved"] = true
	Sfx.play("thud", -6.0)
	cab_move = 0.001
	cab_box["off"] = true
	hatch_box["off"] = true
	cab_box2["off"] = false
	hud.say("Lo trascino di lato. Dietro c'è un'apertura di manutenzione, bassa, nel muro. Il vano tecnico del palazzo.")

func _go_outside() -> void:
	Game.flags["outside"] = true
	Sfx.play("clunk", -6.0)
	main.fade = 1.0
	main.fade_target = 0.0
	player.place(ARRIVE.x, ARRIVE.y + 0.4, 0.0)
	Game.checkpoint = Vector2(ARRIVE.x, ARRIVE.y + 1.0)
	main.cam_target = Vector3(ARRIVE.x, 1.0, ARRIVE.y)
	after(0.9, func(): hud.say([
		"Il vano tecnico, poi una scala di servizio che scende al buio. In fondo, una porta di ferro.",
		"Il cortile. Meno ventotto. La neve non cade come dovrebbe: resta sospesa, poi si muove a scatti, come se il vento cambiasse idea."]))

func _use_barrel() -> void:
	if barrel_fire["lit"]:
		hud.say("Allungo le mani sopra il bidone. Il calore fa male, poi fa bene.")
		return
	light_fire(barrel_fire)
	Sfx.play("ignite", -5.0)
	Game.checkpoint = Vector2(BARREL.x + 1.2, BARREL.y + 0.8)
	hud.say(["Qualcuno ha lasciato delle braci. Posso riaccenderlo.",
		"Il cartone prende al secondo fiammifero. Se perdo i sensi per il freddo… è qui che mi ritroverò."])

# ---- cabina ТП-4: tre leve. Il cancello prende corrente solo attraverso la riserva;
#      l'illuminazione è in sovraccarico e fa saltare il fusibile.

func _use_tp() -> void:
	if Game.fl("power"):
		hud.say("Il trasformatore ronza. La spia del cancello è accesa.")
		return
	if not Game.have("chiave"):
		hud.say(["Cabina di trasformazione ТП-4. Porta di ferro, chiusa a chiave.",
			"Sul cartello: " + Hud.q("«НЕ ВКЛЮЧАТЬ!» — non accendere.")])
		return
	if not Game.fl("tpOpen"):
		Game.flags["tpOpen"] = true
		Sfx.play("clunk", -6.0)
		hud.say("La chiave di manutenzione gira a fatica. Dentro, il quadro è coperto di brina: tre interruttori, fusibili ceramici, uno schema elettrico mezzo cancellato.")
		hud.act(_open_tp)
		return
	_open_tp()

const TP_SCHEMA := "[color=#8fa0b0]СХЕМА · schema (mezzo cancellato dalla brina)[/color]\n" \
	+ "  ОСВЕЩЕНИЕ [illuminazione]  ──╳──  [color=#ff7060]ПЕРЕГРУЗКА · sovraccarico[/color]\n" \
	+ "  РЕЗЕРВ [riserva]  ───────►  ВОРОТА [cancello]  ───►  ???"

func _open_tp() -> void:
	hud.panel_open("ТП-4 · ЩИТ", TP_SCHEMA, _tp_text(""), _tp_buttons())

func _tp_text(m: String) -> String:
	if m != "":
		return m
	if tp["blown"]:
		return "Il fusibile è saltato. Il quadro è morto."
	return "Sotto ogni leva, un cavo con la sua etichetta di cartone. I numeri sullo schema sono coperti di brina."

func _tp_buttons() -> Array:
	var tags := [["ВОРОТА", "cancello"], ["ОСВЕЩЕНИЕ", "illuminazione"], ["РЕЗЕРВ", "riserva"]]
	var out := []
	for k in 3:
		out.append({"label": "%s  %d\n%s\n%s" % ["▲" if tp["sw"][k] else "▼", k + 1, tags[k][0], tags[k][1]],
			"on": tp["sw"][k] == 1, "fn": _press_sw.bind(k)})
	out.append({"label": "CASSETTO\nfusibili", "fn": _tp_drawer})
	out.append({"label": "CHIUDI", "fn": hud.panel_close})
	return out

func _press_sw(k: int) -> void:
	if Game.fl("power"):
		return
	if tp["blown"]:
		Sfx.play("click", -8.0)
		hud.panel_set("Niente. Il fusibile è saltato: devo sostituirlo. Nel cassetto inferiore del quadro.", _tp_buttons())
		return
	if tp["sw"][k]:
		tp["sw"][k] = 0
		Sfx.play("click", -8.0)
		hud.panel_set(_tp_text(""), _tp_buttons())
		return
	if k == 1:
		_tp_blow("Abbasso la leva dell'illuminazione. Il trasformatore geme sotto il carico.")
		return
	if k == 0 and not tp["sw"][2]:
		_tp_blow("Alzo la leva del cancello. Senza la linea di riserva il carico finisce tutto sul fusibile.")
		return
	tp["sw"][k] = 1
	Sfx.play("clunk", -6.0)
	if k == 2:
		hud.panel_set("La linea di riserva prende corrente. Un ronzio basso, regolare.", _tp_buttons())
		return
	hud.panel_set("Il motore del cancello riceve corrente. Fuori, una spia si accende.", _tp_buttons())
	after(1.6, func():
		hud.panel_close()
		_power_on())

func _tp_blow(why: String) -> void:
	tp["blown"] = true
	tp["sw"] = [0, 0, 0]
	Sfx.play("zap", -3.0)
	Sfx.play("clunk", -6.0)
	main.shake = max(main.shake, 0.4)
	main.flash = 0.6
	Game.heat = max(5.0, Game.heat - 12.0)
	hud.panel_set(why + " Un lampo, uno schiocco secco: il fusibile ceramico è saltato.", _tp_buttons())

func _tp_drawer() -> void:
	Sfx.play("click", -8.0)
	if not tp["blown"]:
		hud.panel_set("Nel cassetto inferiore: fusibili ceramici di ricambio, avvolti nella carta oleata. Per ora non servono.",
			_tp_buttons())
		return
	tp["blown"] = false
	hud.panel_set("Prendo un fusibile di ricambio dal cassetto inferiore e lo avvito al posto di quello bruciato.", _tp_buttons())

func _power_on() -> void:
	Game.flags["power"] = true
	Sfx.play("clunk", -4.0)
	Sfx.set_hum(0.03)
	tp_lamp.emission_energy_multiplier = 3.0
	gate_lamp.emission = Color(0.1, 1.0, 0.2)
	gate_lamp.albedo_color = Color(0.05, 0.4, 0.1)
	gate_lamp.emission_energy_multiplier = 2.5
	hud.say("Un tonfo nel trasformatore. Il cancello ha corrente.")
	after(2.6, func():
		far_on = true
		fig_shown = true
		fig.visible = true
		Sfx.play("zap", -12.0)
		Sfx.play("sting", -4.0)
		main.dread = 1.0
		hud.say(["In fondo al cortile, un lampione si accende da solo.",
			"La luce illumina una sagoma umana. È ferma, lontana. Un cappotto scuro."]))

func _use_gate() -> void:
	if Game.fl("gate"):
		hud.say("Il cancello è aperto. Le impronte vengono da lì.")
		return
	if not Game.fl("power"):
		hud.say(["Un cancello elettrico chiude il sottopasso. Il motore è senza corrente.",
			"La spia rossa è spenta. Serve la cabina ТП-4."])
		return
	Game.flags["gate"] = true
	gate_box["off"] = true
	gate_open = 0.001
	Sfx.play("clunk", -4.0)
	Sfx.play("creak", -5.0)
	main.dread = 1.0
	# le impronte profonde: dal cancello attraverso il cortile fino alla porta del palazzo. Nessuna che torna.
	snow.stamp(snow.trail(TRAILG, 0.72, 1.0, 0.1))
	hud.say(["Il cancello si apre con uno strattone.",
		"Ma davanti a me, nella neve, c'è una serie di impronte profonde. Partono dal cancello e attraversano il cortile, verso il palazzo."])

func _use_garage() -> void:
	if Game.fl("garage"):
		hud.say("Il garage n. 4. Dentro, buio e odore di benzina vecchia.")
		return
	if not Game.have("chiaveGarage"):
		hud.say("Il garage n. 4. Un lucchetto pesante.")
		return
	if not Game.fl("trailEnd"):
		hud.say("Il garage n. 4. La chiave ce l'ho. Ma prima voglio capire cosa sta succedendo in questo cortile.")
		return
	Game.flags["garage"] = true
	gar_door_box["off"] = true
	gar_open = 0.001
	Sfx.play("creak", -4.0)
	hud.say("La chiave del quaderno apre il lucchetto. La saracinesca sale con un lamento di ferro.")

func _finale() -> void:
	Game.flags["finale"] = true
	hud.say(["Nell'armadietto c'è solo un foglio piegato.", Hud.q("«ЕСЛИ ТЫ ЧИТАЕШЬ ЭТО, ЗНАЧИТ, Я НЕ УСПЕЛ.»"),
		"Se stai leggendo questo, significa che non ho fatto in tempo.",
		"In basso: " + Hud.q("«Д. ВОРОНИН»") + ". È la mia grafia.", "E una data: " + Hud.q("13.02.1991") + "."], "GARAGE N. 4")
	hud.say("«Domani…?»", "DMITRI")
	hud.act(func(): Sfx.play("radio", -5.0))
	hud.say("La radio nello zaino emette un breve segnale. Si accende da sola.")
	hud.say("«Volk… mi senti?»", "RADIO")
	hud.say("Avvicino la radio all'orecchio.")
	hud.say("«Non sei il primo.»", "RADIO")
	hud.act(func():
		Sfx.play("sting", -3.0)
		main.dread = 1.0)
	hud.say(["La trasmissione si interrompe.", "Guardo fuori dal garage."])
	hud.act(func():
		forming = snow.trail([[gar_x + 4.6, GAR["z1"] + 5.2], [gar_x + 0.4, GAR["z1"] + 1.1]], 0.7, 1.0, 0.1)
		form_t = 0.6)
	hud.say(["Sulla neve, davanti all'ingresso, compare un'impronta. Poi un'altra.",
		"Si stanno formando davanti ai miei occhi."])
	hud.act(func(): main.end_t = 3.2)

# ------------------------------------------------------------------ obiettivi e aiuti

func objective() -> String:
	var G := Game
	if not G.fl("outside"):
		if not G.fl("door") or not G.fl("window"):
			return "Capisci dove ti trovi e controlla le uscite"
		if not stove["lit"]:
			return "Trova il modo di scaldare l'appartamento"
		if not G.fl("cavity"):
			return "Esamina la tavola sollevata vicino alla stufa"
		return "Trova un'altra uscita dall'appartamento"
	if not barrel_fire["lit"]:
		return "Riaccendi il bidone del fuoco nel cortile"
	if not G.fl("power"):
		return "Riattiva il circuito del cancello nella cabina ТП-4"
	if not G.fl("figGone"):
		return "Avvicinati alla sagoma sotto il lampione"
	if not G.fl("gate"):
		return "Apri il cancello del cortile"
	if not G.clues.has("impronte"):
		return "Esamina le impronte nella neve"
	if not G.fl("trailEnd"):
		return "Segui le impronte"
	if not G.fl("garage"):
		return "Apri il garage n. 4"
	return "Fruga nel garage n. 4"

func target():
	var G := Game
	if not G.fl("outside"):
		if not G.fl("door"):
			return by("porta")
		if not G.fl("window"):
			return by("finestra")
		if not stove["lit"]:
			if not G.have("fiammiferi"):
				return by("cassetto")
			if not G.have("giornale"):
				return by("giornale")
			if not G.have("legna"):
				return by("legna")
			return by("stufa")
		if not G.fl("cavity"):
			return by("tavola")
		if not G.fl("moved"):
			return by("mobile")
		if not G.have("chiave"):
			return by("gancio")
		return by("scala")
	if not barrel_fire["lit"]:
		return by("fuoco")
	if not G.fl("power"):
		return by("tp")
	if not G.fl("figGone"):
		return fig_pos + Vector2(1.5, -1.5) if fig_shown else null
	if not G.fl("gate"):
		return by("cancello")
	if not G.clues.has("impronte"):
		return by("impronte")
	if not G.fl("trailEnd"):
		return Vector2(2.0, -9.4)
	if not G.fl("garage"):
		return by("garage")
	if not G.fl("finale"):
		return by("foglio")
	return null

func thought() -> String:
	var G := Game
	if not G.fl("outside"):
		if not G.fl("door") or not G.fl("window"):
			return "Sono chiuso dentro. Devo controllare la porta d'ingresso e le finestre."
		if not stove["lit"]:
			return "Fa sempre più freddo. La stufa in cucina: mi servono fiammiferi, carta, legna."
		if not G.fl("cavity"):
			return "Quella tavola sollevata, vicino alla stufa."
		return "La porta non si apre. Dal ripostiglio arrivava uno spiffero gelido, dietro il mobile."
	if not barrel_fire["lit"]:
		return "Il bidone del fuoco, vicino alle panchine. Prima di tutto il calore."
	if not G.fl("power"):
		return "La piantina segnava la cabina ТП-4. Il cancello è senza corrente."
	if not G.fl("figGone"):
		return "Qualcuno, sotto quel lampione. Non si muove."
	if not G.fl("gate"):
		return "Il cancello del sottopasso adesso ha corrente."
	if not G.clues.has("impronte"):
		return "Quelle impronte. Devo guardarle da vicino."
	if not G.fl("trailEnd"):
		return "Dove portano?"
	return "La chiave del garage n. 4. Era nel quaderno."

func hint() -> String:
	var G := Game
	if not G.fl("outside"):
		if not G.fl("door") or not G.fl("window"):
			return "Esamina la porta d'ingresso (a est, in fondo al corridoio) e la finestra sbarrata del soggiorno."
		if not stove["lit"]:
			return "Fiammiferi nei cassetti della cucina, giornali accanto alla stufa, legna nella cassa del ripostiglio (stanza a sud-est). Poi accendi la stufa."
		if not G.fl("cavity"):
			return "Dopo aver acceso la stufa, solleva la tavola del pavimento lì accanto."
		return "Nel ripostiglio sposta il mobile davanti al muro, prendi la chiave sul gancio del vano tecnico e scendi la scala di servizio."
	if not barrel_fire["lit"]:
		return "Il bidone è a ovest del parco giochi, vicino alle panchine."
	if not G.fl("power"):
		return "La cabina ТП-4 è all'angolo est del cortile. Sullo schema il cancello è alimentato solo attraverso la riserva, e l'illuminazione è in sovraccarico: guarda le etichette sotto le leve."
	if not G.fl("figGone"):
		return "Il lampione acceso è in fondo al cortile, a sud-ovest. Avvicinati o puntaci la torcia."
	if not G.fl("gate"):
		return "Il cancello è nel sottopasso del palazzo lungo, a nord-ovest."
	if not G.clues.has("impronte"):
		return "Esamina le impronte subito davanti al cancello."
	if not G.fl("trailEnd"):
		return "Seguile fino alla porta del palazzo da cui sei uscito."
	if not G.fl("garage"):
		return "Il garage n. 4 è nella fila di garage a sud."
	return "Dentro il garage, apri l'armadietto metallico a destra."

func cold_tip() -> String:
	if not Game.fl("outside"):
		return "Torno vicino alla stufa." if stove["lit"] else "L'appartamento è gelido. Devo accendere la stufa in cucina."
	if not barrel_fire["lit"]:
		return "Il freddo mi entra nelle ossa. Il bidone vicino alle panchine: devo riaccenderlo."
	return "Il freddo mi entra nelle ossa. Torno al fuoco a scaldarmi."

func intro() -> void:
	Sfx.knocks(3)
	after(2.2, func(): Sfx.knocks(3))
	after(4.3, func(): Sfx.play("radio", -10.0))
	hud.say(["Tre colpi metallici. Una pausa. Altri tre.",
		"Apro gli occhi. Sono disteso sul pavimento della cucina. La mano destra è sporca di fuliggine; sul palmo, un segno circolare rossastro.",
		"Il televisore è acceso: nessuna immagine, solo neve elettronica. L'orologio a muro segna le 23:40."])
	hud.say("«Che cazzo…»", "DMITRI")
	hud.act(func(): Sfx.play("creak", -8.0, 1.6))
	hud.say("Dalla porta d'ingresso, il rumore di una maniglia. Qualcuno prova ad aprire.")
	hud.say("«Dima… non aprire.»", "VOCE")
	hud.say("«Chi c'è?»", "DMITRI")
	var keys := "[CALORE e TORCIA sono in alto a sinistra · T accende la torcia · E esamina]"
	if Gfx.touch:
		keys = "[CALORE e TORCIA sono in alto a sinistra · joystick a sinistra · ESAMINA e TORCIA a destra]"
	hud.say(["Nessuna risposta. La maniglia torna immobile.", "[color=#9fb0c0]" + keys + "[/color]"])

func ending() -> Dictionary:
	return {"text": "La camera si abbassa verso i miei stivali. La suola è identica.\n\nNon ho trovato le tracce di qualcuno che mi precede. Ho trovato le tracce di qualcuno che sa esattamente dove andrò.",
		"next": 2, "next_label": "CAPITOLO II · LA FERMATA"}

# ------------------------------------------------------------------ aggiornamento

func update(dt: float, t: float) -> void:
	var indoor := shelter(player.x, player.z)
	# dentro: quasi buio, solo il televisore e la stufa
	main.sun.light_energy = lerp(main.sun.light_energy, 0.12 if indoor else 1.25, 1.0 - exp(-4.0 * dt))
	main.env.ambient_light_energy = lerp(main.env.ambient_light_energy, 0.42 if indoor else 0.55, 1.0 - exp(-4.0 * dt))
	main.indoor_mix = lerp(main.indoor_mix, 1.0 if indoor else 0.0, 1.0 - exp(-4.0 * dt))
	tv_light.light_energy = 1.1 + 0.5 * sin(t * 31.0) * sin(t * 7.7) + 0.25 * sin(t * 53.0)
	# il mobile che scorre di lato
	if cab_move > 0.0 and cab_move < 1.0:
		cab_move = min(1.0, cab_move + dt * 0.9)
		cabinet.position.x = AX + 5.05 - 1.0 * s01(cab_move)
	# altalena che dondola da sola
	swing_stop = max(0.0, swing_stop - dt)
	var amp: float = 0.32 * (1.0 - clamp(swing_stop / 1.0, 0.0, 1.0))
	swing_seat.rotation.x = sin(t * 1.9) * amp
	# cancello e saracinesca
	if gate_open > 0.0 and gate_open < 1.0:
		gate_open = min(1.0, gate_open + dt * 0.5)
		gate.position.x = (TUN["x0"] + TUN["x1"]) * 0.5 + (TUN["x1"] - TUN["x0"] - 0.15) * s01(gate_open)
	if gar_open > 0.0 and gar_open < 1.0:
		gar_open = min(1.0, gar_open + dt * 0.45)
		gar_door.position.y = 2.25 * s01(gar_open)
		gar_door.scale.y = 1.0 - 0.9 * s01(gar_open)
	var inside_gar: bool = abs(player.x - gar_x) < 1.6 and player.z < GAR["z1"] + 0.3 and player.z > GAR["z0"]
	gar_roof.visible = not inside_gar
	# il lampione in fondo e la sagoma
	var want := 5.5 if far_on else 0.0
	far_light.light_energy = lerp(far_light.light_energy, want * (0.9 + 0.1 * sin(t * 40.0)), 1.0 - exp(-6.0 * dt))
	if fig_shown and not Game.fl("figGone"):
		var to_fig := fig_pos - Vector2(player.x, player.z)
		var d := to_fig.length()
		var facing := Vector2(sin(player.heading), cos(player.heading)).dot(to_fig.normalized())
		if d < 4.5 or (Game.torch and d < 12.0 and facing > 0.82):
			Game.flags["figGone"] = true
			fig.visible = false
			main.dread = 1.0
			Sfx.play("sting", -8.0, 1.3)
			hud.say("È sparita. Dove stava, la neve è intatta: nessuna impronta.")
			far_off_t = 6.0
	if far_off_t > 0.0 and not hud.reading():
		far_off_t -= dt
		if far_off_t <= 0.0:
			far_on = false
			hud.tell("lampOff", "Mi volto verso il cancello. Quando torno a guardare, il lampione è di nuovo spento.")
	# non si entra nel sottopasso: le impronte vengono da lì
	gate_msg_t = max(0.0, gate_msg_t - dt)
	if not indoor and player.z < GATE_Z - 0.5 and Game.fl("gate"):
		player.place(player.x, GATE_Z - 0.5, player.heading)
		if gate_msg_t <= 0.0 and not hud.reading():
			gate_msg_t = 4.0
			hud.show_msg("Prima il garage n. 4." if Game.fl("trailEnd") else "Le impronte vengono da lì. Prima voglio capire dove portano.")
	# fine della scia
	if Game.clues.has("impronte") and not Game.fl("trailEnd") and not hud.reading():
		if Vector2(player.x - 2.0, player.z + 9.6).length() < 1.9:
			Game.flags["trailEnd"] = true
			hud.say(["Le tracce arrivano davanti alla porta del palazzo. Poi si interrompono.",
				"Non ci sono impronte di ritorno."])
	# le impronte che si formano da sole nel finale
	if not forming.is_empty():
		form_t -= dt
		if form_t <= 0.0:
			form_t = 0.42
			var e = forming.pop_front()
			snow.add_print(e[0], e[1], e[2], e[3])
			Sfx.step(false)

# ------------------------------------------------------------------ prove

func auto_panel() -> void:
	if hud.panel_title.text.begins_with("ТП"):
		if not tp["sw"][2]:
			_press_sw(2)
		elif not tp["sw"][0]:
			_press_sw(0)
	else:
		hud.panel_close()

func shot_points() -> Array:
	return [
		{"name": "cucina", "x": AX + 4.3, "z": -0.9, "h": -1.5, "zoom": 2.0},
		{"name": "stufa_accesa", "x": AX + 3.6, "z": -2.4, "h": 1.0, "zoom": 2.2, "fn": func():
			light_fire(stove)
			Game.flags["steps"] = true
			wet.visible = true},
		{"name": "soggiorno_tv", "x": AX - 3.2, "z": -1.6, "h": -1.6, "zoom": 2.0, "torch": true},
		{"name": "arrivo_cortile", "x": ARRIVE.x, "z": ARRIVE.y + 1.5, "h": 0.4, "zoom": 1.3, "fn": func():
			Game.flags["outside"] = true
			snow.stamp(snow.trail([[ARRIVE.x, ARRIVE.y + 0.3], [0.0, -5.0], [-6.0, -2.0], [-8.0, -1.2]], 0.5, 1.0, 0.1))},
		{"name": "bidone", "x": BARREL.x + 1.1, "z": BARREL.y + 0.8, "h": -2.2, "zoom": 2.0, "fn": func(): light_fire(barrel_fire)},
		{"name": "parco_giochi", "x": 3.0, "z": 3.0, "h": 0.2, "zoom": 1.2},
		{"name": "cabina_tp4", "x": 17.5, "z": -0.6, "h": PI, "zoom": 1.8, "torch": true},
		{"name": "sagoma_lampione", "x": -7.5, "z": 9.5, "h": -0.8, "zoom": 1.6, "fn": func():
			far_on = true
			fig_shown = true
			fig.visible = true
			Game.flags["figGone"] = true},
		{"name": "cancello_impronte", "x": -13.6, "z": -8.0, "h": PI, "zoom": 1.7, "torch": true, "fn": func():
			_power_on()
			_use_gate()},
		{"name": "garage4", "x": gar_x, "z": GAR["z1"] + 1.6, "h": PI, "zoom": 2.0, "torch": true, "fn": func():
			Game.flags["garage"] = true
			gar_door_box["off"] = true
			gar_open = 0.5},
		{"name": "passi_vicino", "x": 3.0, "z": -3.0, "h": 1.57, "zoom": 2.6, "walk": Vector2(1.0, 0.25)},
		{"name": "vista_larga", "x": 0.0, "z": 2.0, "h": 0.0, "zoom": 0.9},
	]
