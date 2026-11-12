class_name Batch
extends RefCounted
## Accumula scatole e cilindri colorati in una sola mesh (una draw call).

var v := PackedVector3Array()
var n := PackedVector3Array()
var c := PackedColorArray()

func _quad(p0: Vector3, p1: Vector3, p2: Vector3, p3: Vector3, nor: Vector3, col: Color) -> void:
	# p0..p3 in senso antiorario visti da fuori; Godot vuole triangoli orari.
	for p in [p0, p2, p1, p0, p3, p2]:
		v.append(p)
		n.append(nor)
		c.append(col)

## Scatola: xf = centro e orientamento, size = dimensioni complete.
func box_xf(xf: Transform3D, size: Vector3, col: Color, top_col = null) -> void:
	var h := size * 0.5
	var faces := [
		[Vector3(1, 0, 0), Vector3(0, 1, 0), Vector3(0, 0, 1)],
		[Vector3(-1, 0, 0), Vector3(0, 0, 1), Vector3(0, 1, 0)],
		[Vector3(0, 1, 0), Vector3(0, 0, 1), Vector3(1, 0, 0)],
		[Vector3(0, -1, 0), Vector3(1, 0, 0), Vector3(0, 0, 1)],
		[Vector3(0, 0, 1), Vector3(1, 0, 0), Vector3(0, 1, 0)],
		[Vector3(0, 0, -1), Vector3(0, 1, 0), Vector3(1, 0, 0)],
	]
	for f in faces:
		var nn: Vector3 = f[0]
		var u: Vector3 = f[1]
		var w: Vector3 = f[2]
		var o := nn * h
		var uu := u * h
		var ww := w * h
		var col2: Color = col
		if top_col != null and nn.y > 0.5:
			col2 = top_col
		_quad(xf * (o - uu - ww), xf * (o + uu - ww), xf * (o + uu + ww), xf * (o - uu + ww),
			(xf.basis * nn).normalized(), col2)

## Scatola allineata agli assi, data per estremi.
func box(x0: float, x1: float, y0: float, y1: float, z0: float, z1: float, col: Color, top_col = null) -> void:
	box_xf(Transform3D(Basis(), Vector3((x0 + x1) * 0.5, (y0 + y1) * 0.5, (z0 + z1) * 0.5)),
		Vector3(abs(x1 - x0), abs(y1 - y0), abs(z1 - z0)), col, top_col)

## Scatola centrata in (x, y, z) con rotazione attorno a Y.
func box_at(pos: Vector3, size: Vector3, col: Color, rot_y := 0.0, top_col = null) -> void:
	box_xf(Transform3D(Basis(Vector3.UP, rot_y), pos), size, col, top_col)

## Cilindro/tronco di cono lungo l'asse Y locale, base in xf.origin.
func cyl(xf: Transform3D, r0: float, r1: float, h: float, col: Color, sides := 8, cap := true) -> void:
	for i in sides:
		var a0 := TAU * i / sides
		var a1 := TAU * (i + 1) / sides
		var d0 := Vector3(cos(a0), 0, sin(a0))
		var d1 := Vector3(cos(a1), 0, sin(a1))
		var nor := ((d0 + d1) * 0.5).normalized()
		# visto da fuori: d1 è a sinistra di d0 (asse Y verso l'alto) -> antiorario = d1,d0 in basso
		_quad(xf * (d1 * r0), xf * (d0 * r0), xf * (d0 * r1 + Vector3(0, h, 0)),
			xf * (d1 * r1 + Vector3(0, h, 0)), (xf.basis * nor).normalized(), col)
		if cap:
			var up := (xf.basis * Vector3.UP).normalized()
			var top := Vector3(0, h, 0)
			for p in [xf * top, xf * (d0 * r1 + top), xf * (d1 * r1 + top)]:
				v.append(p)
				n.append(up)
				c.append(col)

func cyl_at(pos: Vector3, r0: float, r1: float, h: float, col: Color, sides := 8) -> void:
	cyl(Transform3D(Basis(), pos), r0, r1, h, col, sides)

## Asta tra due punti.
func rod(a: Vector3, b: Vector3, r: float, col: Color, sides := 6) -> void:
	var d := b - a
	var l := d.length()
	if l < 0.0001:
		return
	var y := d / l
	var x := y.cross(Vector3.RIGHT if abs(y.x) < 0.9 else Vector3.FORWARD).normalized()
	var z := x.cross(y).normalized()
	cyl(Transform3D(Basis(x, y, z), a), r, r, l, col, sides, false)

func empty() -> bool:
	return v.is_empty()

func mesh() -> ArrayMesh:
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = v
	arr[Mesh.ARRAY_NORMAL] = n
	arr[Mesh.ARRAY_COLOR] = c
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	return m

static func matte(rough := 0.9) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.roughness = rough
	m.metallic_specular = 0.25
	return m

static func glow(energy := 2.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = Color(energy, energy, energy)
	return m

func instance(parent: Node3D, mat: Material = null, shadows := true) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	if empty():
		parent.add_child(mi)
		return mi
	mi.mesh = mesh()
	mi.material_override = mat if mat != null else matte()
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if shadows \
		else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	return mi
