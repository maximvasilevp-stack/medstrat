extends Node
## Autoload: tiny procedural sound effects (no audio files needed).

const RATE := 22050
var clips: Dictionary = {}
var players: Array = []
var _next := 0
var _last_played: Dictionary = {}


func _ready() -> void:
	clips["click"] = _tone(880.0, 660.0, 0.05, 0.35, 6.0)
	clips["error"] = _tone(180.0, 150.0, 0.14, 0.35, 3.0, true)
	clips["attack"] = _noise(0.28, 0.45, 5.0, 0.25)
	clips["capture"] = _tone(1320.0, 1500.0, 0.035, 0.12, 8.0)
	clips["build"] = _sequence([[660.0, 0.07], [990.0, 0.1]], 0.35)
	clips["ship"] = _tone(220.0, 260.0, 0.3, 0.3, 3.0)
	clips["launch"] = _tone(200.0, 1100.0, 0.7, 0.35, 1.5)
	clips["boom"] = _noise(1.1, 0.8, 3.0, 0.06)
	clips["start"] = _sequence([[523.0, 0.09], [659.0, 0.09], [784.0, 0.14]], 0.4)
	clips["win"] = _sequence([[523.0, 0.1], [659.0, 0.1], [784.0, 0.1], [1047.0, 0.3]], 0.45)
	clips["lose"] = _sequence([[440.0, 0.15], [349.0, 0.15], [262.0, 0.4]], 0.45)
	for i in 8:
		var p := AudioStreamPlayer.new()
		add_child(p)
		players.append(p)


func play(name: String, volume_db: float = 0.0, min_interval: float = 0.0) -> void:
	var settings = get_node_or_null("/root/Settings")
	if settings != null and settings.muted:
		return
	if not clips.has(name):
		return
	var now := Time.get_ticks_msec() / 1000.0
	if min_interval > 0.0 and now - float(_last_played.get(name, -100.0)) < min_interval:
		return
	_last_played[name] = now
	var p: AudioStreamPlayer = players[_next]
	_next = (_next + 1) % players.size()
	p.stream = clips[name]
	p.volume_db = volume_db - 6.0
	p.play()


func _wav(samples: PackedFloat32Array) -> AudioStreamWAV:
	var data := PackedByteArray()
	data.resize(samples.size() * 2)
	for i in samples.size():
		data.encode_s16(i * 2, int(clampf(samples[i], -1.0, 1.0) * 32767.0))
	var s := AudioStreamWAV.new()
	s.format = AudioStreamWAV.FORMAT_16_BITS
	s.mix_rate = RATE
	s.stereo = false
	s.data = data
	return s


func _tone(f0: float, f1: float, dur: float, gain: float, decay: float, square: bool = false) -> AudioStreamWAV:
	var n := int(dur * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	var phase := 0.0
	for i in n:
		var t := float(i) / n
		var f := lerpf(f0, f1, t)
		phase += TAU * f / RATE
		var v := sin(phase)
		if square:
			v = 1.0 if v > 0.0 else -1.0
		out[i] = v * gain * exp(-decay * t) * minf(1.0, i / 40.0)
	return _wav(out)


func _noise(dur: float, gain: float, decay: float, alpha: float) -> AudioStreamWAV:
	var n := int(dur * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var y := 0.0
	for i in n:
		var t := float(i) / n
		y += (rng.randf_range(-1.0, 1.0) - y) * alpha
		out[i] = y * gain * exp(-decay * t) * minf(1.0, i / 60.0) * 3.0
	return _wav(out)


func _sequence(notes: Array, gain: float) -> AudioStreamWAV:
	var out := PackedFloat32Array()
	for note in notes:
		var f: float = note[0]
		var n := int(note[1] * RATE)
		var phase := 0.0
		for i in n:
			var t := float(i) / n
			phase += TAU * f / RATE
			out.append(sin(phase) * gain * exp(-3.0 * t) * minf(1.0, i / 40.0))
	return _wav(out)
