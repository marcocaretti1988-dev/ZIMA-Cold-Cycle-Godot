class_name Player
extends Node3D
## Dmitri «Volk» Voronin: modello rigato di Ludo (GLB) con la sua camminata.

const WALK := 2.3
const RUN := 4.4
const RADIUS := 0.34

var x := 0.0
var z := 0.0
var heading := 0.0          # atan2(dx, dz)
var speed := 0.0
var idle := 0.0
var model: Node3D
var anim: AnimationPlayer
var anim_name := ""
var idle_time := 0.0
var torch: SpotLight3D
var breath: CPUParticles3D
var step_acc := 0.0
var left := true
var lean := 0.0
var fallen := 0.0           # > 0: a terra (vuoto di memoria)

func _ready() -> void:
	_load_model()
	torch = SpotLight3D.new()
	torch.light_color = Color(1.0, 0.86, 0.62)
	torch.light_energy = 0.0
	torch.spot_range = 17.0
	torch.spot_angle = 26.0
	torch.spot_attenuation = 0.9
	torch.shadow_enabled = Gfx.pc
	torch.position = Vector3(0.22, 1.25, 0.2)
	torch.rotation = Vector3(deg_to_rad(-8.0), PI, 0)
	add_child(torch)
	breath = CPUParticles3D.new()
	breath.amount = 5
	breath.lifetime = 1.3
	breath.position = Vector3(0, 1.58, 0.2)
	breath.direction = Vector3(0, 0.25, 1)
	breath.spread = 14.0
	breath.initial_velocity_min = 0.25
	breath.initial_velocity_max = 0.45
	breath.gravity = Vector3(0, 0.12, 0)
	breath.scale_amount_min = 0.5
	breath.scale_amount_max = 1.2
	var q := QuadMesh.new()
	q.size = Vector2(0.22, 0.22)
	var qm := StandardMaterial3D.new()
	qm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	qm.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	qm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	qm.albedo_color = Color(0.85, 0.9, 1.0, 0.16)
	qm.albedo_texture = _puff_tex()
	q.material = qm
	breath.mesh = q
	add_child(breath)

func _puff_tex() -> ImageTexture:
	var img := Image.create(32, 32, false, Image.FORMAT_RGBA8)
	for py in 32:
		for px in 32:
			var d := Vector2(px - 15.5, py - 15.5).length() / 16.0
			img.set_pixel(px, py, Color(1, 1, 1, clamp(1.0 - d, 0.0, 1.0) ** 2.0))
	return ImageTexture.create_from_image(img)

func _load_model() -> void:
	var path := "res://assets/dmitri.glb"
	if ResourceLoader.exists(path):
		var ps = load(path)
		if ps is PackedScene:
			model = ps.instantiate()
	if model == null:
		model = _fallback()
		add_child(model)
		return
	add_child(model)
	# porta il modello a 1,82 m con i piedi a terra
	var box := _bounds(model)
	var h: float = max(0.01, box.size.y)
	var k := 1.82 / h
	model.scale = Vector3(k, k, k)
	model.position = Vector3(-box.get_center().x * k, -box.position.y * k, -box.get_center().z * k)
	anim = _find_anim(model)
	if anim != null:
		var names := anim.get_animation_list()
		for nm in names:
			if nm != "RESET":
				anim_name = nm
		if anim_name != "":
			var a := anim.get_animation(anim_name)
			a.loop_mode = Animation.LOOP_LINEAR
			anim.play(anim_name)
			anim.speed_scale = 0.0
			idle_time = _feet_together(a.length)
			anim.seek(idle_time, true)

## Cerca nel ciclo di camminata l'istante con i piedi vicini: è la posa da fermo.
func _feet_together(length: float) -> float:
	var sk: Skeleton3D = null
	for c in model.find_children("*", "Skeleton3D", true, false):
		sk = c as Skeleton3D
	if sk == null:
		return length * 0.25
	var l := sk.find_bone("L_Foot")
	var r := sk.find_bone("R_Foot")
	if l < 0 or r < 0:
		return length * 0.25
	var best := length * 0.25
	var best_d := 1e9
	for i in 32:
		var t := length * i / 32.0
		anim.seek(t, true)
		var d := sk.get_bone_global_pose(l).origin.distance_to(sk.get_bone_global_pose(r).origin)
		if d < best_d:
			best_d = d
			best = t
	return best

func _bounds(n: Node) -> AABB:
	var out := AABB()
	var first := true
	for c in n.find_children("*", "MeshInstance3D", true, false):
		var mi := c as MeshInstance3D
		var bb: AABB = _rel_xf(mi, n) * mi.get_aabb()
		if first:
			out = bb
			first = false
		else:
			out = out.merge(bb)
	if first:
		out = AABB(Vector3(-0.3, 0, -0.2), Vector3(0.6, 1.8, 0.4))
	return out

func _rel_xf(node: Node3D, root: Node) -> Transform3D:
	var xf := Transform3D()
	var cur: Node = node
	while cur != null and cur != root:
		if cur is Node3D:
			xf = (cur as Node3D).transform * xf
		cur = cur.get_parent()
	return xf

func _find_anim(n: Node) -> AnimationPlayer:
	for c in n.find_children("*", "AnimationPlayer", true, false):
		return c as AnimationPlayer
	return null

func _fallback() -> Node3D:
	var b := Batch.new()
	var coat := Color(0.16, 0.22, 0.33)
	b.box(-0.27, 0.27, 0.75, 1.45, -0.16, 0.16, coat)
	b.box(-0.24, -0.04, 0, 0.78, -0.12, 0.12, Color(0.12, 0.12, 0.14))
	b.box(0.04, 0.24, 0, 0.78, -0.12, 0.12, Color(0.12, 0.12, 0.14))
	b.box(-0.14, 0.14, 1.47, 1.74, -0.13, 0.13, Color(0.78, 0.62, 0.52))
	b.box(-0.17, 0.17, 1.68, 1.84, -0.16, 0.16, Color(0.3, 0.2, 0.13))
	var root := Node3D.new()
	b.instance(root)
	return root

func place(px: float, pz: float, hd: float) -> void:
	x = px
	z = pz
	heading = hd
	speed = 0.0

## dir = direzione di marcia nel mondo (x, z), lunghezza 0..1.
func move(dt: float, dir: Vector2, run: bool, ch) -> void:
	var sn: SnowField = ch.snow
	if fallen > 0.0:
		dir = Vector2.ZERO
	var target := 0.0
	if dir.length() > 0.08:
		target = (RUN if run else WALK) * min(1.0, dir.length())
		var want := atan2(dir.x, dir.y)
		heading = lerp_angle(heading, want, 1.0 - exp(-12.0 * dt))
	speed = lerp(speed, target, 1.0 - exp(-10.0 * dt))
	if speed > 0.05:
		var nx := x + sin(heading) * speed * dt
		var nz := z + cos(heading) * speed * dt
		var res: Vector2 = ch.resolve(nx, nz, RADIUS)
		var moved := Vector2(res.x - x, res.y - z).length()
		x = res.x
		z = res.y
		idle = 0.0
		step_acc += moved
		var stride := 0.36 if speed < 3.0 else 0.52
		if step_acc >= stride:
			step_acc = 0.0
			left = not left
			var indoor: bool = ch.shelter(x, z)
			Sfx.step(indoor)
			if not indoor:
				var sx := cos(heading) * (0.1 if left else -0.1)
				var sz := -sin(heading) * (0.1 if left else -0.1)
				sn.add_print(x + sx, z + sz, heading, 1.0)
				ch.on_step(x, z)
	else:
		idle += dt
	position = Vector3(x, ch.ground_y(x, z), z)
	rotation.y = heading
	# animazione
	if anim != null and anim_name != "":
		if speed > 0.15:
			anim.speed_scale = clamp(speed / 1.45, 0.4, 3.2)
		else:
			anim.speed_scale = 0.0
			if abs(anim.current_animation_position - idle_time) > 0.02:
				anim.seek(lerp(anim.current_animation_position, idle_time, 1.0 - exp(-8.0 * dt)), true)
	lean = lerp(lean, 0.16 if speed > 3.0 else 0.0, 1.0 - exp(-6.0 * dt))
	if model != null:
		if fallen > 0.0:
			model.rotation.x = lerp(model.rotation.x, -PI * 0.47, 1.0 - exp(-5.0 * dt))
		else:
			model.rotation.x = lerp(model.rotation.x, lean, 1.0 - exp(-6.0 * dt))
	breath.emitting = fallen <= 0.0

func set_torch(on: bool, level := 1.0) -> void:
	torch.light_energy = (5.5 if Gfx.pc else 4.0) * level if on else 0.0
