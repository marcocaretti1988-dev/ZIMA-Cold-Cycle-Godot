extends Node
## Audio sintetizzato all'avvio: nessun file, tranne la musica del menu.

const RATE := 22050

var sounds := {}
var pool: Array[AudioStreamPlayer] = []
var wind: AudioStreamPlayer
var fire: AudioStreamPlayer
var hum: AudioStreamPlayer
var music: AudioStreamPlayer
var rng := RandomNumberGenerator.new()

func _ready() -> void:
	rng.seed = 417
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i in 8:
		var p := AudioStreamPlayer.new()
		add_child(p)
		pool.append(p)
	sounds["step"] = _noise(0.11, 0.55, 0.5, 9.0)
	sounds["step2"] = _noise(0.13, 0.5, 0.42, 8.0)
	sounds["floor"] = _noise(0.06, 0.25, 0.2, 14.0)
	sounds["click"] = _noise(0.03, 0.5, 0.9, 30.0)
	sounds["pick"] = _tone(0.12, 620.0, 880.0, 0.25, 10.0)
	sounds["clunk"] = _mix(_tone(0.35, 90.0, 45.0, 0.9, 7.0), _noise(0.2, 0.4, 0.25, 12.0))
	sounds["thud"] = _tone(0.45, 70.0, 38.0, 0.9, 5.0)
	sounds["knock"] = _mix(_tone(0.16, 180.0, 120.0, 0.9, 16.0), _noise(0.08, 0.3, 0.3, 25.0))
	sounds["ignite"] = _noise(0.9, 0.5, 0.35, 2.2)
	sounds["zap"] = _zap(0.4)
	sounds["sting"] = _sting(2.6)
	sounds["radio"] = _radio(1.3)
	sounds["creak"] = _creak(1.1)
	sounds["eat"] = _noise(0.25, 0.3, 0.3, 6.0)
	wind = _loop_player(_wind(6.0), -60.0)
	fire = _loop_player(_fire(3.0), -60.0)
	hum = _loop_player(_hum(2.0), -60.0)
	music = AudioStreamPlayer.new()
	add_child(music)
	if ResourceLoader.exists("res://assets/menu.mp3"):
		var st = load("res://assets/menu.mp3")
		if st is AudioStreamMP3:
			st.loop = true
			music.stream = st
	music.volume_db = -9.0

func play(name: String, vol := 0.0, pitch := 1.0) -> void:
	if not sounds.has(name):
		return
	for p in pool:
		if not p.playing:
			p.stream = sounds[name]
			p.volume_db = vol
			p.pitch_scale = pitch
			p.play()
			return

func step(indoor: bool) -> void:
	if indoor:
		play("floor", -14.0, rng.randf_range(0.85, 1.2))
	else:
		play("step" if rng.randf() < 0.5 else "step2", -9.0, rng.randf_range(0.85, 1.15))

func knocks(n := 3) -> void:
	for i in n:
		get_tree().create_timer(0.38 * i).timeout.connect(func(): play("knock", -4.0))

func set_wind(v: float) -> void:
	wind.volume_db = lerp(wind.volume_db, linear_to_db(clamp(v, 0.0005, 1.0)), 0.05)

func set_fire(v: float) -> void:
	fire.volume_db = lerp(fire.volume_db, linear_to_db(clamp(v, 0.0005, 1.0)), 0.1)

func set_hum(v: float) -> void:
	hum.volume_db = linear_to_db(clamp(v, 0.0005, 1.0))

func menu_music(on: bool) -> void:
	if music.stream == null:
		return
	if on and not music.playing:
		music.play()
	elif not on and music.playing:
		var tw := create_tween()
		tw.tween_property(music, "volume_db", -50.0, 1.5)
		tw.tween_callback(func():
			music.stop()
			music.volume_db = -9.0)

# ---------------------------------------------------------------- sintesi

func _wav(buf: PackedFloat32Array, loop := false) -> AudioStreamWAV:
	var data := PackedByteArray()
	data.resize(buf.size() * 2)
	for i in buf.size():
		data.encode_s16(i * 2, int(clamp(buf[i], -1.0, 1.0) * 32000.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.stereo = false
	w.data = data
	if loop:
		w.loop_mode = AudioStreamWAV.LOOP_FORWARD
		w.loop_begin = 0
		w.loop_end = buf.size()
	return w

func _loop_player(st: AudioStreamWAV, db: float) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.stream = st
	p.volume_db = db
	add_child(p)
	p.play()
	return p

func _buf(sec: float) -> PackedFloat32Array:
	var b := PackedFloat32Array()
	b.resize(int(sec * RATE))
	return b

## Rumore filtrato con inviluppo esponenziale.
func _noise(sec: float, vol: float, lp: float, decay: float) -> AudioStreamWAV:
	var b := _buf(sec)
	var y := 0.0
	for i in b.size():
		var t := float(i) / RATE
		y += (rng.randf_range(-1.0, 1.0) - y) * lp
		b[i] = y * vol * exp(-t * decay) * min(1.0, t * 400.0)
	return _wav(b)

func _tone(sec: float, f0: float, f1: float, vol: float, decay: float) -> AudioStreamWAV:
	var b := _buf(sec)
	var ph := 0.0
	for i in b.size():
		var t := float(i) / RATE
		ph += TAU * lerp(f0, f1, t / sec) / RATE
		b[i] = sin(ph) * vol * exp(-t * decay) * min(1.0, t * 300.0)
	return _wav(b)

func _mix(a: AudioStreamWAV, c: AudioStreamWAV) -> AudioStreamWAV:
	var n: int = max(a.data.size(), c.data.size()) / 2
	var b := PackedFloat32Array()
	b.resize(n)
	for i in n:
		var v := 0.0
		if i * 2 < a.data.size():
			v += a.data.decode_s16(i * 2) / 32000.0
		if i * 2 < c.data.size():
			v += c.data.decode_s16(i * 2) / 32000.0
		b[i] = v * 0.8
	return _wav(b)

func _zap(sec: float) -> AudioStreamWAV:
	var b := _buf(sec)
	for i in b.size():
		var t := float(i) / RATE
		var sq := 1.0 if fmod(t * 110.0, 1.0) < 0.5 else -1.0
		b[i] = (sq * 0.4 + rng.randf_range(-0.6, 0.6)) * exp(-t * 9.0) * 0.7
	return _wav(b)

func _sting(sec: float) -> AudioStreamWAV:
	var b := _buf(sec)
	for i in b.size():
		var t := float(i) / RATE
		var e: float = min(1.0, t * 3.0) * exp(-t * 1.1)
		b[i] = (sin(TAU * 55.0 * t) + sin(TAU * 58.3 * t) * 0.8 + sin(TAU * 82.0 * t) * 0.4) * e * 0.3
	return _wav(b)

func _radio(sec: float) -> AudioStreamWAV:
	var b := _buf(sec)
	var y := 0.0
	for i in b.size():
		var t := float(i) / RATE
		y += (rng.randf_range(-1.0, 1.0) - y) * 0.7
		var gate: float = 0.4 + 0.6 * abs(sin(t * 23.0)) * abs(sin(t * 7.0))
		var e: float = min(1.0, t * 20.0) * min(1.0, (sec - t) * 8.0)
		b[i] = (y * 0.35 + sin(TAU * 1300.0 * t + sin(t * 40.0) * 3.0) * 0.06) * gate * e
	return _wav(b)

func _creak(sec: float) -> AudioStreamWAV:
	var b := _buf(sec)
	var ph := 0.0
	for i in b.size():
		var t := float(i) / RATE
		ph += TAU * (220.0 + 90.0 * sin(t * 9.0) + 60.0 * t) / RATE
		var saw := fmod(ph / TAU, 1.0) * 2.0 - 1.0
		b[i] = saw * 0.16 * min(1.0, t * 10.0) * min(1.0, (sec - t) * 5.0) * (0.6 + 0.4 * sin(t * 31.0))
	return _wav(b)

func _wind(sec: float) -> AudioStreamWAV:
	var b := _buf(sec)
	var y := 0.0
	var z := 0.0
	for i in b.size():
		var t := float(i) / RATE
		y += (rng.randf_range(-1.0, 1.0) - y) * 0.035
		z += (y - z) * 0.2
		b[i] = z * 3.2 * (0.65 + 0.35 * sin(TAU * t / sec) * sin(TAU * 3.0 * t / sec))
	_xfade(b, 0.4)
	return _wav(b, true)

func _fire(sec: float) -> AudioStreamWAV:
	var b := _buf(sec)
	var y := 0.0
	var pop := 0.0
	for i in b.size():
		y += (rng.randf_range(-1.0, 1.0) - y) * 0.12
		if rng.randf() < 0.0012:
			pop = rng.randf_range(0.4, 1.0)
		pop *= 0.992
		b[i] = y * 0.5 + rng.randf_range(-1.0, 1.0) * pop * 0.35
	_xfade(b, 0.2)
	return _wav(b, true)

func _hum(sec: float) -> AudioStreamWAV:
	var b := _buf(sec)
	for i in b.size():
		var t := float(i) / RATE
		b[i] = (sin(TAU * 50.0 * t) * 0.5 + sin(TAU * 100.0 * t) * 0.25 + sin(TAU * 150.0 * t) * 0.1) * 0.6
	return _wav(b, true)

func _xfade(b: PackedFloat32Array, sec: float) -> void:
	var n := int(sec * RATE)
	var total := b.size()
	for i in n:
		var k := float(i) / n
		b[total - n + i] = b[total - n + i] * (1.0 - k) + b[i] * k
