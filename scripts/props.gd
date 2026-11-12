class_name Props
extends RefCounted
## Oggetti di scena sovietici costruiti con il Batch (scatole colorate).

const SNOW := Color(0.86, 0.89, 0.94)
const SNOW_SH := Color(0.70, 0.75, 0.84)
const CONCRETE := Color(0.50, 0.51, 0.52)
const CONCRETE_D := Color(0.36, 0.37, 0.39)
const PANEL := Color(0.56, 0.55, 0.52)
const GLASS := Color(0.07, 0.09, 0.12)
const FRAME := Color(0.62, 0.60, 0.55)
const RUST := Color(0.36, 0.20, 0.13)
const IRON := Color(0.16, 0.17, 0.19)
const WOOD := Color(0.30, 0.21, 0.14)
const WARM := Color(1.0, 0.72, 0.38)

static func lb(b: Batch, xf: Transform3D, c: Vector3, s: Vector3, col: Color, top = null) -> void:
	b.box_xf(xf * Transform3D(Basis(), c), s, col, top)

static func at(pos: Vector3, rot := 0.0) -> Transform3D:
	return Transform3D(Basis(Vector3.UP, rot), pos)

# ------------------------------------------------------------------ palazzi

## Palazzo a pannelli (хрущёвка). gap = [x0, x1, altezza] per un sottopasso lungo X.
static func building(b: Batch, g: Batch, x0: float, x1: float, z0: float, z1: float,
		floors: int, rng: RandomNumberGenerator, gap = null, lit_chance := 0.05) -> void:
	var fh := 2.8
	var base := 0.9
	var h := base + floors * fh
	var tint := rng.randf_range(-0.03, 0.03)
	var wall := Color(PANEL.r + tint, PANEL.g + tint, PANEL.b + tint * 0.5)
	if gap == null:
		b.box(x0, x1, 0, h, z0, z1, wall)
	else:
		b.box(x0, gap[0], 0, h, z0, z1, wall)
		b.box(gap[1], x1, 0, h, z0, z1, wall)
		b.box(gap[0], gap[1], gap[2], h, z0, z1, wall)
	# zoccolo, cornicione, neve sul tetto
	if gap == null:
		b.box(x0 - 0.05, x1 + 0.05, 0, base, z0 - 0.05, z1 + 0.05, CONCRETE_D)
	else:
		b.box(x0 - 0.05, gap[0], 0, base, z0 - 0.05, z1 + 0.05, CONCRETE_D)
		b.box(gap[1], x1 + 0.05, 0, base, z0 - 0.05, z1 + 0.05, CONCRETE_D)
	b.box(x0 - 0.25, x1 + 0.25, h, h + 0.35, z0 - 0.25, z1 + 0.25, CONCRETE_D, SNOW)
	b.box(x0 + 0.4, x1 - 0.4, h + 0.35, h + 0.62, z0 + 0.4, z1 - 0.4, SNOW)
	# giunti dei pannelli
	for f in floors + 1:
		var y := base + f * fh
		b.box(x0 - 0.02, x1 + 0.02, y - 0.04, y + 0.04, z0 - 0.02, z1 + 0.02, CONCRETE_D)
	# finestre sulle quattro facciate
	_face_windows(b, g, x0, x1, z1, true, 1.0, floors, base, fh, rng, gap, lit_chance)
	_face_windows(b, g, x0, x1, z0, true, -1.0, floors, base, fh, rng, gap, lit_chance)
	_face_windows(b, g, z0, z1, x1, false, 1.0, floors, base, fh, rng, null, lit_chance)
	_face_windows(b, g, z0, z1, x0, false, -1.0, floors, base, fh, rng, null, lit_chance)

static func _face_windows(b: Batch, g: Batch, a0: float, a1: float, c: float, along_x: bool,
		side: float, floors: int, base: float, fh: float, rng: RandomNumberGenerator,
		gap, lit_chance: float) -> void:
	var bay := 3.1
	var count := int(floor((a1 - a0) / bay))
	if count < 1:
		return
	var off := (a1 - a0 - count * bay) * 0.5
	for i in count:
		var ca := a0 + off + (i + 0.5) * bay
		# giunto verticale
		_fbox(b, along_x, ca - bay * 0.5, c, side, 0.05, base, base + floors * fh, 0.04, CONCRETE_D)
		for f in floors:
			var y0 := base + f * fh + 0.95
			if gap != null and along_x and ca > gap[0] - 0.9 and ca < gap[1] + 0.9 and y0 < gap[2] + 0.4:
				continue
			var lit := rng.randf() < lit_chance
			var w := 1.5
			var hh := 1.35
			_fbox(b, along_x, ca, c, side, w + 0.16, y0 - 0.08, y0 + hh + 0.08, 0.05, FRAME)
			if lit:
				var k := rng.randf_range(0.7, 1.0)
				_fbox(g, along_x, ca, c, side, w, y0, y0 + hh, 0.08, Color(1.0 * k, 0.66 * k, 0.30 * k))
			else:
				var gl := GLASS
				if rng.randf() < 0.3:
					gl = Color(0.16, 0.15, 0.13)      # tende tirate
				_fbox(b, along_x, ca, c, side, w, y0, y0 + hh, 0.08, gl)
			# montante e davanzale con la neve
			_fbox(b, along_x, ca + 0.2, c, side, 0.06, y0, y0 + hh, 0.1, FRAME)
			_fbox(b, along_x, ca, c, side, w + 0.3, y0 - 0.16, y0 - 0.08, 0.2, CONCRETE_D, SNOW)
			# balcone ogni tanto
			if (i % 3) == 1 and f > 0:
				_fbox(b, along_x, ca, c, side, 2.4, y0 - 0.95, y0 - 0.8, 0.9, CONCRETE_D, SNOW)
				_fbox(b, along_x, ca, c + side * 0.42, side, 2.4, y0 - 0.8, y0 + 0.1, 0.06,
					Color(0.33, 0.40, 0.42))

## Scatola appoggiata a una facciata: a = posizione lungo la facciata, c = piano della facciata.
static func _fbox(b: Batch, along_x: bool, a: float, c: float, side: float, w: float,
		y0: float, y1: float, depth: float, col: Color, top = null) -> void:
	var d0 := c
	var d1 := c + side * depth
	if along_x:
		b.box(a - w * 0.5, a + w * 0.5, y0, y1, min(d0, d1), max(d0, d1), col, top)
	else:
		b.box(min(d0, d1), max(d0, d1), y0, y1, a - w * 0.5, a + w * 0.5, col, top)

## Pensilina d'ingresso sul lato sud (z1) di un palazzo.
static func entrance(b: Batch, x: float, z: float, door_col := Color(0.30, 0.20, 0.16)) -> void:
	b.box(x - 1.3, x + 1.3, 2.5, 2.7, z, z + 1.5, CONCRETE_D, SNOW)
	b.box(x - 1.25, x - 1.1, 0, 2.5, z + 1.3, z + 1.45, CONCRETE_D)
	b.box(x + 1.1, x + 1.25, 0, 2.5, z + 1.3, z + 1.45, CONCRETE_D)
	b.box(x - 0.55, x + 0.55, 0, 2.1, z - 0.02, z + 0.08, door_col)
	b.box(x - 1.3, x + 1.3, 0, 0.18, z, z + 1.6, CONCRETE, SNOW)

# ------------------------------------------------------------------ arredi

static func lamp_post(b: Batch, pos: Vector3, rot := 0.0, h := 6.0) -> Vector3:
	var xf := at(pos, rot)
	b.cyl(xf, 0.14, 0.09, 1.0, CONCRETE_D, 6)
	b.cyl(xf * Transform3D(Basis(), Vector3(0, 1.0, 0)), 0.07, 0.05, h - 1.0, IRON, 6)
	var arm_a := xf * Vector3(0, h, 0)
	var arm_b := xf * Vector3(1.3, h + 0.25, 0)
	b.rod(arm_a, arm_b, 0.04, IRON)
	lb(b, xf, Vector3(1.45, h + 0.2, 0), Vector3(0.6, 0.14, 0.26), IRON, SNOW)
	return xf * Vector3(1.45, h + 0.1, 0)

static func bench(b: Batch, pos: Vector3, rot := 0.0) -> void:
	var xf := at(pos, rot)
	for sx in [-0.8, 0.8]:
		lb(b, xf, Vector3(sx, 0.25, 0), Vector3(0.08, 0.5, 0.5), IRON)
		lb(b, xf, Vector3(sx, 0.7, -0.24), Vector3(0.08, 0.5, 0.07), IRON)
	for k in 3:
		lb(b, xf, Vector3(0, 0.5, -0.16 + k * 0.16), Vector3(1.9, 0.05, 0.13), WOOD, SNOW)
	for k in 2:
		lb(b, xf, Vector3(0, 0.72 + k * 0.17, -0.27), Vector3(1.9, 0.12, 0.04), WOOD)

static func barrel(b: Batch, pos: Vector3) -> void:
	var xf := at(pos)
	b.cyl(xf, 0.36, 0.36, 0.95, RUST, 12, false)
	b.cyl(xf * Transform3D(Basis(), Vector3(0, 0.3, 0)), 0.375, 0.375, 0.05, Color(0.22, 0.13, 0.09), 12, false)
	b.cyl(xf * Transform3D(Basis(), Vector3(0, 0.62, 0)), 0.375, 0.375, 0.05, Color(0.22, 0.13, 0.09), 12, false)
	b.cyl(xf, 0.34, 0.34, 0.6, Color(0.05, 0.04, 0.04), 12)

static func car(b: Batch, pos: Vector3, rot: float, col: Color, buried := 0.25) -> void:
	var xf := at(pos + Vector3(0, -buried, 0), rot)
	var dark := Color(0.05, 0.05, 0.06)
	lb(b, xf, Vector3(0, 0.62, 0), Vector3(4.0, 0.62, 1.6), col)
	lb(b, xf, Vector3(-0.15, 1.2, 0), Vector3(2.1, 0.56, 1.46), col, SNOW)
	lb(b, xf, Vector3(-0.15, 1.2, 0), Vector3(1.9, 0.4, 1.5), GLASS)
	lb(b, xf, Vector3(-0.15, 1.2, 0), Vector3(2.14, 0.38, 1.3), GLASS)
	lb(b, xf, Vector3(1.45, 0.95, 0), Vector3(1.05, 0.06, 1.5), SNOW)
	lb(b, xf, Vector3(-1.6, 0.95, 0), Vector3(0.75, 0.06, 1.5), SNOW)
	lb(b, xf, Vector3(-0.15, 1.52, 0), Vector3(2.0, 0.12, 1.4), SNOW)
	lb(b, xf, Vector3(2.02, 0.5, 0), Vector3(0.08, 0.14, 1.66), Color(0.6, 0.62, 0.64))
	lb(b, xf, Vector3(-2.02, 0.5, 0), Vector3(0.08, 0.14, 1.66), Color(0.6, 0.62, 0.64))
	for sx in [-1.25, 1.3]:
		for sz in [-0.78, 0.78]:
			lb(b, xf, Vector3(sx, 0.32, sz), Vector3(0.62, 0.62, 0.2), dark)
	for sz in [-0.55, 0.55]:
		lb(b, xf, Vector3(2.01, 0.72, sz), Vector3(0.05, 0.16, 0.26), Color(0.75, 0.74, 0.62))
		lb(b, xf, Vector3(-2.01, 0.72, sz), Vector3(0.05, 0.14, 0.3), Color(0.45, 0.08, 0.06))

static func tree(b: Batch, pos: Vector3, rng: RandomNumberGenerator, h := 6.0) -> void:
	var bark := Color(0.13, 0.11, 0.10)
	var xf := at(pos, rng.randf() * TAU)
	b.cyl(xf, 0.26, 0.15, h * 0.45, bark, 7, false)
	var top := xf * Vector3(0, h * 0.45, 0)
	for i in 6:
		var a := TAU * i / 6.0 + rng.randf_range(-0.4, 0.4)
		var l := rng.randf_range(1.6, 2.8)
		var e := top + Vector3(cos(a) * l * 0.75, l * rng.randf_range(0.5, 1.0), sin(a) * l * 0.75)
		b.rod(top + Vector3(0, rng.randf_range(-0.8, 0.2), 0), e, 0.07, bark, 5)
		b.box_at(e.lerp(top, 0.35) + Vector3(0, 0.09, 0), Vector3(0.7, 0.08, 0.16), SNOW, a)
		for j in 2:
			var a2 := a + rng.randf_range(-0.9, 0.9)
			var l2 := rng.randf_range(0.8, 1.5)
			var e2 := e + Vector3(cos(a2) * l2, l2 * 0.6, sin(a2) * l2)
			b.rod(e, e2, 0.035, bark, 4)

static func dumpster(b: Batch, pos: Vector3, rot := 0.0) -> void:
	var xf := at(pos, rot)
	lb(b, xf, Vector3(0, 0.6, 0), Vector3(1.6, 1.0, 1.0), Color(0.20, 0.30, 0.24))
	lb(b, xf, Vector3(0, 1.13, 0), Vector3(1.66, 0.08, 1.06), Color(0.16, 0.24, 0.2), SNOW)

static func fence(b: Batch, a: Vector3, c: Vector3, h := 1.3) -> void:
	var d := c - a
	var n := int(max(1.0, round(d.length() / 2.4)))
	for i in n:
		var p0 := a + d * (float(i) / n)
		var p1 := a + d * (float(i + 1) / n)
		var mid := (p0 + p1) * 0.5
		var rot := atan2(-(p1.z - p0.z), p1.x - p0.x)
		b.box_at(mid + Vector3(0, h * 0.5, 0), Vector3(p0.distance_to(p1) - 0.06, h, 0.12), CONCRETE, rot, SNOW)
		b.box_at(p0 + Vector3(0, h * 0.55, 0), Vector3(0.2, h * 1.1, 0.2), CONCRETE_D, rot, SNOW)

## Sagoma nera senza volto.
static func silhouette(b: Batch, pos: Vector3, rot := 0.0) -> void:
	var xf := at(pos, rot)
	var k := Color(0.015, 0.016, 0.02)
	lb(b, xf, Vector3(0, 0.95, 0), Vector3(0.52, 1.1, 0.3), k)
	lb(b, xf, Vector3(-0.13, 0.25, 0), Vector3(0.2, 0.5, 0.22), k)
	lb(b, xf, Vector3(0.13, 0.25, 0), Vector3(0.2, 0.5, 0.22), k)
	lb(b, xf, Vector3(-0.33, 1.02, 0), Vector3(0.14, 0.85, 0.2), k)
	lb(b, xf, Vector3(0.33, 1.02, 0), Vector3(0.14, 0.85, 0.2), k)
	lb(b, xf, Vector3(0, 1.68, 0), Vector3(0.26, 0.3, 0.26), k)
