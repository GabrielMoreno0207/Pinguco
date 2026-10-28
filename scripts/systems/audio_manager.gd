extends Node
## AudioManager (autoload): registro de sons por nome, buses e reprodução 2D/3D.
## Se existir res://assets/audio/<nome>.ogg ou .wav, ele é usado; senão um placeholder
## é sintetizado em runtime (o jogo nunca espera por assets de áudio).
## Música: uma faixa por vez (play_music), trocada com crossfade.

const AUDIO_DIR := "res://assets/audio"
const RATE := 22050
const BUSES := ["Music", "SFX", "Voice", "Ambience"]
const POOL_SIZE := 14
## Sons que tocam em loop (vale também para os arquivos carregados).
const LOOPING := ["pour", "ambience", "music", "music_menu"]
const MUSIC_FADE := 1.5

## nome -> [bus, gerador]
const SOUNDS := {
	"clink": ["SFX", "_gen_clink"],
	"bottle": ["SFX", "_gen_bottle"],
	"pour": ["SFX", "_gen_pour"],
	"correct": ["SFX", "_gen_correct"],
	"wrong": ["SFX", "_gen_wrong"],
	"late": ["SFX", "_gen_late"],
	"coin": ["SFX", "_gen_coin"],
	"thud": ["SFX", "_gen_thud"],
	"doorbell": ["SFX", "_gen_doorbell"],
	"glass_break": ["SFX", "_gen_glass_break"],
	"step": ["SFX", "_gen_step"],
	"snore": ["Voice", "_gen_snore"],
	"voice_a": ["Voice", "_gen_voice_a"],
	"voice_o": ["Voice", "_gen_voice_o"],
	"voice_e": ["Voice", "_gen_voice_e"],
	"ambience": ["Ambience", "_gen_ambience"],
	"music": ["Music", "_gen_music"],
	"music_menu": ["Music", "_gen_music"],
	"ui_click": ["SFX", "_gen_ui_click"],
}

var _streams: Dictionary = {}
var _pool_3d: Array[AudioStreamPlayer3D] = []
var _pool_2d: Array[AudioStreamPlayer] = []
var _loops: Dictionary = {}
var _music: AudioStreamPlayer
var _music_name := ""
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_setup_buses()
	for sound_name: String in SOUNDS:
		_streams[sound_name] = _load_or_generate(sound_name)
	for i in POOL_SIZE:
		var p3 := AudioStreamPlayer3D.new()
		p3.unit_size = 4.0
		p3.max_distance = 30.0
		add_child(p3)
		_pool_3d.append(p3)
		var p2 := AudioStreamPlayer.new()
		add_child(p2)
		_pool_2d.append(p2)


func register_stream(sound_name: String, stream: AudioStream) -> void:
	_streams[sound_name] = stream


func play(sound_name: String, pitch := 1.0, volume_db := 0.0) -> void:
	var p := _free_player(_pool_2d) as AudioStreamPlayer
	if p == null or not _streams.has(sound_name):
		return
	p.stream = _streams[sound_name]
	p.bus = SOUNDS.get(sound_name, ["SFX"])[0]
	p.pitch_scale = pitch * _rng.randf_range(0.96, 1.04)
	p.volume_db = volume_db
	p.play()


func play_at(sound_name: String, pos: Vector3, pitch := 1.0, volume_db := 0.0) -> void:
	var p := _free_player(_pool_3d) as AudioStreamPlayer3D
	if p == null or not _streams.has(sound_name):
		return
	p.stream = _streams[sound_name]
	p.bus = SOUNDS.get(sound_name, ["SFX"])[0]
	p.global_position = pos
	p.pitch_scale = pitch * _rng.randf_range(0.95, 1.05)
	p.volume_db = volume_db
	p.play()


## Fala cartunesca: sílabas aleatórias com o tom do perfil; bêbado = mais grave e arrastado.
func speak(pos: Vector3, pitch: float, syllables: int, drunk_stage := 0) -> void:
	var slow := 1.0 + drunk_stage * 0.25
	for i in syllables:
		var v: String = ["voice_a", "voice_o", "voice_e"][_rng.randi_range(0, 2)]
		var wobble := _rng.randf_range(0.88, 1.15) - drunk_stage * 0.05
		play_at(v, pos, pitch * wobble, -4.0)
		await get_tree().create_timer(0.075 * slow + _rng.randf_range(0.0, 0.04), false).timeout


func laugh(pos: Vector3, pitch: float) -> void:
	for i in 5:
		play_at("voice_a", pos, pitch * (1.35 - i * 0.06), -3.0)
		await get_tree().create_timer(0.11, false).timeout


func grumble(pos: Vector3, pitch: float) -> void:
	for i in 4:
		play_at("voice_o", pos, pitch * _rng.randf_range(0.55, 0.7), -2.0)
		await get_tree().create_timer(0.13, false).timeout


func start_loop(sound_name: String, volume_db := 0.0) -> void:
	if _loops.has(sound_name) or not _streams.has(sound_name):
		return
	var p := AudioStreamPlayer.new()
	p.stream = _streams[sound_name]
	p.bus = SOUNDS.get(sound_name, ["SFX"])[0]
	p.volume_db = volume_db
	add_child(p)
	p.play()
	_loops[sound_name] = p


func stop_loop(sound_name: String) -> void:
	if _loops.has(sound_name):
		_loops[sound_name].queue_free()
		_loops.erase(sound_name)


## Troca a música de fundo com crossfade; pedir a que já toca não reinicia.
func play_music(sound_name: String, volume_db := 0.0) -> void:
	if sound_name == _music_name or not _streams.has(sound_name):
		return
	_music_name = sound_name
	if _music != null:
		var old := _music
		var tw_out := old.create_tween()
		tw_out.tween_property(old, "volume_db", -60.0, MUSIC_FADE)
		tw_out.tween_callback(old.queue_free)
	_music = AudioStreamPlayer.new()
	_music.stream = _streams[sound_name]
	_music.bus = "Music"
	_music.volume_db = -60.0
	add_child(_music)
	_music.play()
	_music.create_tween().tween_property(_music, "volume_db", volume_db, MUSIC_FADE)


## Loop posicional controlado pelo chamador (ex.: som de servir enquanto segura E).
func make_loop_player_3d(sound_name: String, parent: Node3D) -> AudioStreamPlayer3D:
	var p := AudioStreamPlayer3D.new()
	p.stream = _streams.get(sound_name)
	p.bus = SOUNDS.get(sound_name, ["SFX"])[0]
	p.unit_size = 4.0
	parent.add_child(p)
	return p


func _free_player(pool: Array) -> Node:
	for p in pool:
		if not p.playing:
			return p
	return pool[0]


func _setup_buses() -> void:
	for bus_name: String in BUSES:
		if AudioServer.get_bus_index(bus_name) == -1:
			AudioServer.add_bus()
			var idx := AudioServer.bus_count - 1
			AudioServer.set_bus_name(idx, bus_name)
			AudioServer.set_bus_send(idx, "Master")
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Music"), -10.0)
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Ambience"), -8.0)
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Voice"), -3.0)
	var master := AudioServer.get_bus_index("Master")
	if AudioServer.get_bus_effect_count(master) == 0:
		AudioServer.add_bus_effect(master, AudioEffectLimiter.new())


func _load_or_generate(sound_name: String) -> AudioStream:
	for ext in [".ogg", ".wav", ".mp3"]:
		var path := AUDIO_DIR.path_join(sound_name + ext)
		if ResourceLoader.exists(path):
			var stream: AudioStream = load(path)
			if sound_name in LOOPING and "loop" in stream:
				stream.loop = true
			return stream
	return call(SOUNDS[sound_name][1])


# --------------------------------------------------------------------------
# Síntese de placeholders
# --------------------------------------------------------------------------

func _to_wav(samples: PackedFloat32Array, loop := false) -> AudioStreamWAV:
	var data := PackedByteArray()
	data.resize(samples.size() * 2)
	for i in samples.size():
		data.encode_s16(i * 2, int(clampf(samples[i], -1.0, 1.0) * 32000.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = RATE
	wav.stereo = false
	wav.data = data
	if loop:
		wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
		wav.loop_begin = 0
		wav.loop_end = samples.size()
	return wav


func _buf(seconds: float) -> PackedFloat32Array:
	var b := PackedFloat32Array()
	b.resize(int(seconds * RATE))
	return b


func _gen_clink() -> AudioStream:
	var b := _buf(0.35)
	for i in b.size():
		var t := float(i) / RATE
		var env := exp(-t * 14.0)
		b[i] = env * 0.35 * (sin(TAU * 2350.0 * t) + 0.6 * sin(TAU * 3720.0 * t) + 0.4 * sin(TAU * 5210.0 * t))
	return _to_wav(b)


func _gen_bottle() -> AudioStream:
	var b := _buf(0.25)
	for i in b.size():
		var t := float(i) / RATE
		b[i] = exp(-t * 30.0) * 0.6 * sin(TAU * 180.0 * t) + exp(-t * 20.0) * 0.2 * sin(TAU * 1650.0 * t)
	return _to_wav(b)


func _gen_pour() -> AudioStream:
	var b := _buf(1.2)
	var lp := 0.0
	for i in b.size():
		var t := float(i) / RATE
		lp = lerpf(lp, _rng.randf_range(-1.0, 1.0), 0.25)
		var gurgle := 0.6 + 0.4 * sin(TAU * 7.0 * t + sin(TAU * 1.3 * t) * 2.0)
		b[i] = lp * 0.5 * gurgle + 0.08 * sin(TAU * (500.0 + 120.0 * sin(TAU * 9.0 * t)) * t) * gurgle
	return _to_wav(b, true)


func _tone_seq(notes: Array, note_len: float, wave := "tri", vol := 0.35) -> PackedFloat32Array:
	var b := _buf(note_len * notes.size() + 0.15)
	for n in notes.size():
		var f: float = notes[n]
		var start := int(n * note_len * RATE)
		var length := int((note_len + 0.15) * RATE)
		for i in length:
			var idx := start + i
			if idx >= b.size():
				break
			var t := float(i) / RATE
			var ph := fmod(f * t, 1.0)
			var s := 0.0
			match wave:
				"tri": s = 4.0 * absf(ph - 0.5) - 1.0
				"sq": s = 1.0 if ph < 0.5 else -1.0
				"saw": s = 2.0 * ph - 1.0
				_: s = sin(TAU * ph)
			b[idx] += s * vol * exp(-t * 7.0) * minf(1.0, t * 200.0)
	return b


func _gen_correct() -> AudioStream:
	return _to_wav(_tone_seq([523.25, 659.25, 783.99, 1046.5], 0.07, "sq", 0.18))


func _gen_coin() -> AudioStream:
	return _to_wav(_tone_seq([987.77, 1318.5], 0.06, "sq", 0.15))


func _gen_wrong() -> AudioStream:
	var b := _buf(0.45)
	for i in b.size():
		var t := float(i) / RATE
		var f := 150.0 + 6.0 * sin(TAU * 22.0 * t)
		b[i] = (2.0 * fmod(f * t, 1.0) - 1.0) * 0.3 * minf(1.0, (0.45 - t) * 20.0)
	return _to_wav(b)


func _gen_late() -> AudioStream:
	var b := _buf(0.6)
	var ph := 0.0
	for i in b.size():
		var t := float(i) / RATE
		ph += (520.0 - 380.0 * t / 0.6) / RATE
		b[i] = (4.0 * absf(fmod(ph, 1.0) - 0.5) - 1.0) * 0.3 * exp(-t * 2.0)
	return _to_wav(b)


func _gen_thud() -> AudioStream:
	var b := _buf(0.4)
	for i in b.size():
		var t := float(i) / RATE
		b[i] = exp(-t * 12.0) * 0.8 * sin(TAU * (90.0 - 50.0 * t) * t) + exp(-t * 40.0) * _rng.randf_range(-0.2, 0.2)
	return _to_wav(b)


func _gen_doorbell() -> AudioStream:
	var b := _tone_seq([1318.5, 1046.5], 0.32, "sine", 0.3)
	return _to_wav(b)


func _gen_glass_break() -> AudioStream:
	var b := _buf(0.5)
	for i in b.size():
		var t := float(i) / RATE
		var crack := _rng.randf_range(-1.0, 1.0) * exp(-t * 9.0) * 0.4
		var ring := 0.0
		for f in [3100.0, 4470.0, 6020.0]:
			ring += sin(TAU * f * t + _rng.randf() * 0.2) * exp(-t * (10.0 + f / 800.0))
		b[i] = crack + ring * 0.12
	return _to_wav(b)


func _gen_step() -> AudioStream:
	var b := _buf(0.12)
	var lp := 0.0
	for i in b.size():
		var t := float(i) / RATE
		lp = lerpf(lp, _rng.randf_range(-1.0, 1.0), 0.15)
		b[i] = lp * exp(-t * 45.0) * 0.6
	return _to_wav(b)


func _gen_ui_click() -> AudioStream:
	return _to_wav(_tone_seq([880.0], 0.04, "sine", 0.3))


func _gen_voice(formants: Array) -> AudioStream:
	var b := _buf(0.11)
	for i in b.size():
		var t := float(i) / RATE
		var f0 := 210.0 * (1.0 + 0.15 * sin(TAU * 9.0 * t))
		var env := sin(PI * t / 0.11)
		var s := 0.0
		for h in range(1, 12):
			var hf := f0 * h
			var amp := 0.0
			for fm: float in formants:
				amp += exp(-pow((hf - fm) / 260.0, 2.0))
			s += sin(TAU * hf * t) * amp / h * 1.6
		b[i] = s * env * 0.35
	return _to_wav(b)


func _gen_voice_a() -> AudioStream:
	return _gen_voice([800.0, 1200.0])


func _gen_voice_o() -> AudioStream:
	return _gen_voice([500.0, 850.0])


func _gen_voice_e() -> AudioStream:
	return _gen_voice([450.0, 2000.0])


func _gen_snore() -> AudioStream:
	var b := _buf(2.2)
	var lp := 0.0
	for i in b.size():
		var t := float(i) / RATE
		lp = lerpf(lp, _rng.randf_range(-1.0, 1.0), 0.08)
		var inhale := clampf(sin(PI * t / 1.1), 0.0, 1.0) if t < 1.1 else 0.0
		var exhale := clampf(sin(PI * (t - 1.2) / 0.9), 0.0, 1.0) if t > 1.2 else 0.0
		var rumble := sin(TAU * 38.0 * t) * 0.6 + sin(TAU * 76.0 * t) * 0.3
		b[i] = inhale * (lp * 0.7 + rumble * lp * 0.8) * 0.8 + exhale * sin(TAU * (900.0 - 300.0 * (t - 1.2)) * t) * 0.06
	return _to_wav(b)


func _gen_ambience() -> AudioStream:
	# Burburinho: ruído marrom + "vozes" distantes, 6 s em loop.
	var b := _buf(6.0)
	var brown := 0.0
	for i in b.size():
		brown = clampf(brown + _rng.randf_range(-0.02, 0.02), -1.0, 1.0) * 0.998
		b[i] = brown * 0.5
	var voices := [_gen_voice_a(), _gen_voice_o(), _gen_voice_e()]
	for k in 70:
		var src: AudioStreamWAV = voices[k % 3]
		var start := _rng.randi_range(0, b.size() - 3000)
		var pitch := _rng.randf_range(0.5, 1.1)
		var gain := _rng.randf_range(0.05, 0.14)
		var n := int(src.data.size() / 2.0 / pitch)
		for i in n:
			var si := int(i * pitch) * 2
			if si + 1 >= src.data.size() or start + i >= b.size():
				break
			b[start + i] += src.data.decode_s16(si) / 32000.0 * gain
	# suaviza a costura do loop
	var fade := 2000
	for i in fade:
		var a := float(i) / fade
		b[i] = b[i] * a + b[b.size() - fade + i] * (1.0 - a)
	return _to_wav(b, true)


func _gen_music() -> AudioStream:
	# "Rádio de pagode": surdo, pandeiro, tamborim e cavaquinho (Karplus-Strong).
	var bpm := 104.0
	var beat := 60.0 / bpm
	var bars := 4
	var b := _buf(beat * 4.0 * bars)
	var sixteenth := beat / 4.0
	# Progressão: C  A7  Dm  G7
	var chords := [[261.6, 329.6, 392.0, 523.3], [220.0, 277.2, 329.6, 392.0],
		[293.7, 349.2, 440.0, 587.3], [196.0, 246.9, 293.7, 349.2]]
	var tamborim := [1, 0, 1, 1, 0, 1, 0, 1, 1, 0, 1, 0, 1, 1, 0, 1]
	var cavaco := [1, 0, 0, 1, 0, 0, 1, 0, 1, 0, 0, 1, 0, 1, 0, 0]
	for bar in bars:
		for step in 16:
			var t0 := int((bar * 4.0 * beat + step * sixteenth) * RATE)
			# surdo no 2º tempo, marcação leve no 1º
			if step == 4:
				_add_drum(b, t0, 62.0, 0.7, 7.0)
			elif step == 0:
				_add_drum(b, t0, 75.0, 0.35, 10.0)
			# pandeiro: semicolcheias com acento
			_add_noise(b, t0, 0.05, 0.12 if step % 4 == 0 else 0.05)
			if tamborim[step] == 1:
				_add_drum(b, t0, 900.0, 0.12, 40.0)
			if cavaco[step] == 1:
				for f: float in chords[bar % 4]:
					_add_pluck(b, t0 + _rng.randi_range(0, 200), f * 2.0, 0.07)
	return _to_wav(b, true)


func _add_drum(b: PackedFloat32Array, start: int, freq: float, vol: float, decay: float) -> void:
	var n := int(0.35 * RATE)
	for i in n:
		if start + i >= b.size():
			return
		var t := float(i) / RATE
		b[start + i] += sin(TAU * freq * t * (1.0 + 0.5 * exp(-t * 30.0))) * vol * exp(-t * decay)


func _add_noise(b: PackedFloat32Array, start: int, length: float, vol: float) -> void:
	var n := int(length * RATE)
	for i in n:
		if start + i >= b.size():
			return
		var t := float(i) / RATE
		b[start + i] += _rng.randf_range(-1.0, 1.0) * vol * exp(-t * 60.0)


func _add_pluck(b: PackedFloat32Array, start: int, freq: float, vol: float) -> void:
	var period := maxi(2, int(RATE / freq))
	var ring := PackedFloat32Array()
	ring.resize(period)
	for i in period:
		ring[i] = _rng.randf_range(-1.0, 1.0)
	var n := int(0.5 * RATE)
	for i in n:
		if start + i >= b.size():
			return
		var idx := i % period
		var nxt := (i + 1) % period
		var v := ring[idx]
		ring[idx] = (v + ring[nxt]) * 0.497
		b[start + i] += v * vol
