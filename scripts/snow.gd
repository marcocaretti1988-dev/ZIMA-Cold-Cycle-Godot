class_name SnowField
extends Node3D
## Terreno innevato, impronte permanenti («la neve ricorda tutto») e nevicata.

var ground_fn: Callable
var prints: MultiMesh
var count := 0
var cap := 2000
var fall: GPUParticles3D
var mat: ShaderMaterial

func build(x0: float, x1: float, z0: float, z1: float, hfn: Callable, tint_fn: Callable) -> void:
	ground_fn = hfn
	var step := 1.0
	var nx := int((x1 - x0) / step)
	var nz := int((z1 - z0) / step)
	var v := PackedVector3Array()
	var nrm := PackedVector3Array()
	var col := PackedColorArray()
	var idx := PackedInt32Array()
	for j in nz + 1:
		for i in nx + 1:
			var x := x0 + i * step
			var z := z0 + j * step
			var h: float = hfn.call(x, z)
			v.append(Vector3(x, h, z))
			var e := 0.5
			var dx: float = hfn.call(x + e, z) - hfn.call(x - e, z)
			var dz: float = hfn.call(x, z + e) - hfn.call(x, z - e)
			nrm.append(Vector3(-dx, 2.0 * e, -dz).normalized())
			var t: float = tint_fn.call(x, z)
			col.append(Color(t, t, t))
	for j in nz:
		for i in nx:
			var a := j * (nx + 1) + i
			var b := a + 1
			var c := a + nx + 1
			var d := c + 1
			idx.append_array([a, b, c, b, d, c])
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = v
	arr[Mesh.ARRAY_NORMAL] = nrm
	arr[Mesh.ARRAY_COLOR] = col
	arr[Mesh.ARRAY_INDEX] = idx
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	mat = ShaderMaterial.new()
	mat.shader = load("res://shaders/snow.gdshader")
	mat.set_shader_parameter("detail", 1.0 if Gfx.pc else 0.0)
	var mi := MeshInstance3D.new()
	mi.mesh = m
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	# piano scuro lontano, perso nella nebbia
	var far := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(600, 600)
	far.mesh = pm
	var fm := StandardMaterial3D.new()
	fm.albedo_color = Color(0.42, 0.47, 0.56)
	fm.roughness = 1.0
	far.material_override = fm
	far.position = Vector3((x0 + x1) * 0.5, -0.25, (z0 + z1) * 0.5)
	add_child(far)
	_build_prints()
	_build_fall()

func _build_prints() -> void:
	cap = Gfx.print_cap()
	prints = MultiMesh.new()
	prints.transform_format = MultiMesh.TRANSFORM_3D
	prints.use_custom_data = true
	var q := QuadMesh.new()
	q.size = Vector2(0.17, 0.36)
	q.orientation = PlaneMesh.FACE_Y
	prints.mesh = q
	prints.instance_count = cap
	prints.visible_instance_count = 0
	var sm := ShaderMaterial.new()
	sm.shader = load("res://shaders/footprint.gdshader")
	sm.render_priority = 1
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = prints
	mmi.material_override = sm
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mmi.custom_aabb = AABB(Vector3(-200, -5, -200), Vector3(400, 30, 400))
	add_child(mmi)

func _build_fall() -> void:
	fall = GPUParticles3D.new()
	fall.amount = Gfx.snow_amount()
	fall.lifetime = 9.0
	fall.preprocess = 9.0
	fall.visibility_aabb = AABB(Vector3(-40, -30, -40), Vector3(80, 50, 80))
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(26, 0.5, 26)
	pm.direction = Vector3(-0.35, -1, 0.15)
	pm.spread = 12.0
	pm.initial_velocity_min = 1.6
	pm.initial_velocity_max = 2.8
	pm.gravity = Vector3(-0.25, -0.35, 0.1)
	pm.scale_min = 0.6
	pm.scale_max = 1.5
	if Gfx.full_fx():
		pm.turbulence_enabled = true
		pm.turbulence_noise_strength = 0.6
		pm.turbulence_noise_scale = 3.0
	fall.process_material = pm
	var q := QuadMesh.new()
	q.size = Vector2(0.07, 0.07)
	var qm := StandardMaterial3D.new()
	qm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	qm.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	qm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	qm.albedo_color = Color(0.9, 0.93, 1.0, 0.75)
	q.material = qm
	fall.draw_pass_1 = q
	fall.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(fall)

func follow(p: Vector3, emitting: bool) -> void:
	fall.position = Vector3(p.x, 17.0, p.z)
	fall.emitting = emitting

## Aggiunge un'impronta. heading = direzione di marcia (atan2(dx, dz)).
func add_print(x: float, z: float, heading: float, strength := 1.0, scale := 1.0) -> void:
	var i := count % cap
	var y: float = ground_fn.call(x, z) + 0.014
	var b := Basis(Vector3.UP, heading + PI).scaled(Vector3(scale, 1.0, scale))
	prints.set_instance_transform(i, Transform3D(b, Vector3(x, y, z)))
	prints.set_instance_custom_data(i, Color(strength, 0, 0, 0))
	count += 1
	prints.visible_instance_count = min(count, cap)

## Scia di impronte lungo una spezzata [[x, z], ...].
func trail(pts: Array, stride := 0.62, strength := 1.0, half_gap := 0.11, limp := 0.0) -> Array:
	var out := []
	var left := true
	for k in pts.size() - 1:
		var a := Vector2(pts[k][0], pts[k][1])
		var b := Vector2(pts[k + 1][0], pts[k + 1][1])
		var d := b - a
		var l := d.length()
		var dir := d / l
		var side := Vector2(dir.y, -dir.x)
		var hd := atan2(dir.x, dir.y)
		var s := 0.0
		while s < l:
			var p := a + dir * s + side * (half_gap if left else -half_gap)
			out.append([p.x, p.y, hd, strength])
			left = not left
			s += stride * (1.0 - limp if left else 1.0 + limp)
	return out

func stamp(list: Array) -> void:
	for e in list:
		add_print(e[0], e[1], e[2], e[3])
