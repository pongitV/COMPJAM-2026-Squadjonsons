# Sfx (autoload): every sound and song is synthesized in code at startup.
# The music bus gets muffled and detuned as the player's stress rises.
extends Node

const Pen = preload("res://scripts/pen.gd")

const RATE := 22050
const MRATE := 16000

var sounds := {}
var tracks := {}
var pool: Array[AudioStreamPlayer] = []
var next := 0
var music_player: AudioStreamPlayer
var current_track := ""
var lowpass: AudioEffectLowPassFilter
var t := 0.0

const SONGS := {
	"title": {"bpm": 84.0, "meter": 4, "inst": "musicbox", "lead": "bell", "seed": 3, "vol": -8.0,
		"chords": [[60, 64, 67, 71], [57, 60, 64, 67], [65, 69, 72, 76], [67, 71, 74, 77]]},
	"l0": {"bpm": 104.0, "meter": 4, "inst": "epiano", "lead": "flute", "seed": 7, "vol": -9.0,
		"chords": [[62, 65, 69, 72], [67, 71, 74, 77], [60, 64, 67, 71], [57, 60, 64, 67]]},
	"l1": {"bpm": 132.0, "meter": 3, "inst": "musicbox", "lead": "flute", "seed": 11, "vol": -9.0,
		"chords": [[65, 69, 72], [62, 65, 69], [58, 62, 65, 70], [60, 64, 67, 70]]},
	"l2": {"bpm": 76.0, "meter": 4, "inst": "organ", "lead": "bell", "seed": 5, "vol": -10.0,
		"chords": [[60, 64, 67], [65, 69, 72], [67, 71, 74], [57, 60, 64]]},
}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	AudioServer.add_bus()
	var bus := AudioServer.bus_count - 1
	AudioServer.set_bus_name(bus, "Music")
	AudioServer.set_bus_send(bus, "Master")
	lowpass = AudioEffectLowPassFilter.new()
	lowpass.cutoff_hz = 18000.0
	AudioServer.add_bus_effect(bus, lowpass)
	for i in 12:
		var p := AudioStreamPlayer.new()
		add_child(p)
		pool.append(p)
	music_player = AudioStreamPlayer.new()
	music_player.bus = "Music"
	add_child(music_player)
	_make_sounds()


func _process(delta: float) -> void:
	t += delta
	var s := Pen.stress
	lowpass.cutoff_hz = lerpf(18000.0, 700.0, s * s)
	if music_player.playing:
		music_player.pitch_scale = 1.0 + sin(t * 4.7) * 0.012 * s + sin(t * 1.1) * 0.03 * s * s


func play(name: String, vol_db := 0.0, pitch := 1.0) -> void:
	if not sounds.has(name):
		return
	var p := pool[next]
	next = (next + 1) % pool.size()
	p.stream = sounds[name]
	p.volume_db = vol_db
	p.pitch_scale = pitch
	p.play()


func blip(voice: float) -> void:
	play("blip", -16.0, voice * randf_range(0.85, 1.2))


func music(name: String) -> void:
	if name == current_track:
		return
	current_track = name
	if not tracks.has(name):
		tracks[name] = _render_song(SONGS[name])
	music_player.stream = tracks[name]
	music_player.volume_db = SONGS[name]["vol"]
	music_player.play()


# ---------------------------------------------------------------- synthesis

func _wav(buf: PackedFloat32Array, rate := RATE, loop := false) -> AudioStreamWAV:
	var data := PackedByteArray()
	data.resize(buf.size() * 2)
	for i in buf.size():
		data.encode_s16(i * 2, int(clampf(buf[i], -1.0, 1.0) * 32000.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = rate
	w.stereo = false
	w.data = data
	if loop:
		w.loop_mode = AudioStreamWAV.LOOP_FORWARD
		w.loop_begin = 0
		w.loop_end = buf.size()
	return w


func _buf(seconds: float) -> PackedFloat32Array:
	var b := PackedFloat32Array()
	b.resize(int(seconds * RATE))
	return b


func _make_sounds() -> void:
	var b: PackedFloat32Array
	var ph := 0.0

	# pop: a piece clicks back into place
	b = _buf(0.14)
	ph = 0.0
	for i in b.size():
		var x := float(i) / RATE
		ph += TAU * (380.0 + 700.0 * x / 0.14) / RATE
		b[i] = sin(ph) * exp(-x * 28.0) * minf(1.0, x * 400.0) * 0.8
	sounds["pop"] = _wav(b)

	# grab
	b = _buf(0.06)
	for i in b.size():
		var x := float(i) / RATE
		b[i] = sin(TAU * 900.0 * x) * exp(-x * 70.0) * 0.5
	sounds["grab"] = _wav(b)

	# boing: a piece flies off
	b = _buf(0.4)
	ph = 0.0
	for i in b.size():
		var x := float(i) / RATE
		ph += TAU * (170.0 + 320.0 * exp(-x * 9.0) + sin(TAU * 14.0 * x) * 25.0) / RATE
		b[i] = (sin(ph) + 0.3 * sin(ph * 2.0)) * exp(-x * 7.0) * 0.55
	sounds["boing"] = _wav(b)

	# tape: rrrrip
	b = _buf(0.38)
	var lp := 0.0
	for i in b.size():
		var x := float(i) / RATE
		lp += 0.35 * (randf_range(-1.0, 1.0) - lp)
		b[i] = lp * (0.55 + 0.45 * sin(TAU * 42.0 * x)) * minf(1.0, x * 50.0) * exp(-x * 3.0) * 1.3
	sounds["tape"] = _wav(b)

	# wipe
	b = _buf(0.16)
	lp = 0.0
	for i in b.size():
		var x := float(i) / RATE
		lp += 0.12 * (randf_range(-1.0, 1.0) - lp)
		b[i] = lp * sin(PI * x / 0.16) * 1.8
	sounds["wipe"] = _wav(b)

	# held: two rising notes
	b = _buf(0.3)
	for i in b.size():
		var x := float(i) / RATE
		var f := 660.0 if x < 0.1 else 990.0
		b[i] = sin(TAU * f * x) * exp(-fmod(x, 0.1) * 25.0) * 0.4
	sounds["held"] = _wav(b)

	# tick: someone is about to look
	b = _buf(0.08)
	for i in b.size():
		var x := float(i) / RATE
		b[i] = sin(TAU * 1760.0 * x) * exp(-x * 60.0) * 0.35
	sounds["tick"] = _wav(b)

	# look: low ominous thump
	b = _buf(0.4)
	for i in b.size():
		var x := float(i) / RATE
		b[i] = (sin(TAU * 98.0 * x) + 0.5 * sin(TAU * 147.0 * x)) * exp(-x * 7.0) * 0.5
	sounds["look"] = _wav(b)

	# heartbeat: lub-dub
	b = _buf(0.45)
	for i in b.size():
		var x := float(i) / RATE
		var v := sin(TAU * 58.0 * x) * exp(-x * 22.0)
		if x > 0.17:
			var y := x - 0.17
			v += sin(TAU * 48.0 * y) * exp(-y * 20.0) * 0.8
		b[i] = v * 0.9
	sounds["heart"] = _wav(b)

	# blip: speech babble
	b = _buf(0.06)
	for i in b.size():
		var x := float(i) / RATE
		var sq := 1.0 if fmod(x * 330.0, 1.0) < 0.5 else -1.0
		b[i] = (sq * 0.3 + sin(TAU * 330.0 * x) * 0.5) * sin(PI * x / 0.06) * 0.5
	sounds["blip"] = _wav(b)

	# inhale / exhale
	b = _buf(1.3)
	lp = 0.0
	for i in b.size():
		var x := float(i) / RATE
		lp += (0.05 + 0.1 * x) * (randf_range(-1.0, 1.0) - lp)
		b[i] = lp * minf(1.0, x * 1.5) * minf(1.0, (1.3 - x) * 8.0) * 2.0
	sounds["inhale"] = _wav(b)
	b = _buf(1.2)
	lp = 0.0
	for i in b.size():
		var x := float(i) / RATE
		lp += 0.08 * (randf_range(-1.0, 1.0) - lp)
		b[i] = lp * exp(-x * 2.2) * minf(1.0, x * 30.0) * 2.4
	sounds["exhale"] = _wav(b)

	# sneeze: ah... ah... TCHIM
	b = _buf(0.95)
	ph = 0.0
	lp = 0.0
	for i in b.size():
		var x := float(i) / RATE
		var v := 0.0
		if x < 0.55:
			var seg := fmod(x, 0.27)
			ph += TAU * (220.0 + seg * 500.0 + floor(x / 0.27) * 60.0) / RATE
			v = (sin(ph) + 0.4 * sin(ph * 3.0)) * sin(PI * seg / 0.27) * 0.35
		else:
			var y := x - 0.55
			lp += 0.5 * (randf_range(-1.0, 1.0) - lp)
			v = lp * exp(-y * 9.0) * minf(1.0, y * 200.0) * 1.4
		b[i] = v
	sounds["sneeze"] = _wav(b)

	# microphone feedback
	b = _buf(1.1)
	for i in b.size():
		var x := float(i) / RATE
		var f := 2300.0 + sin(TAU * 6.0 * x) * 60.0
		b[i] = sin(TAU * f * x) * minf(1.0, x * 3.0) * minf(1.0, (1.1 - x) * 10.0) * 0.28
	sounds["feedback"] = _wav(b)

	# crash: everything falls apart
	b = _buf(1.6)
	ph = 0.0
	lp = 0.0
	for i in b.size():
		var x := float(i) / RATE
		lp += 0.3 * (randf_range(-1.0, 1.0) - lp)
		ph += TAU * (400.0 * exp(-x * 2.0) + 50.0) / RATE
		b[i] = lp * exp(-x * 3.0) * 0.9 + sin(ph) * exp(-x * 1.5) * 0.5
	sounds["crash"] = _wav(b)

	# bubble pop
	b = _buf(0.12)
	ph = 0.0
	for i in b.size():
		var x := float(i) / RATE
		ph += TAU * (500.0 + 1400.0 * x / 0.12) / RATE
		b[i] = sin(ph) * exp(-x * 30.0) * 0.6
	sounds["bubble"] = _wav(b)

	# ui click
	b = _buf(0.05)
	for i in b.size():
		var x := float(i) / RATE
		b[i] = (sin(TAU * 1200.0 * x) + randf_range(-0.3, 0.3)) * exp(-x * 90.0) * 0.5
	sounds["click"] = _wav(b)

	# nope: out of tape
	b = _buf(0.22)
	for i in b.size():
		var x := float(i) / RATE
		var sq := 1.0 if fmod(x * 110.0, 1.0) < 0.5 else -1.0
		b[i] = sq * 0.25 * minf(1.0, (0.22 - x) * 20.0)
	sounds["nope"] = _wav(b)

	# stamp: heavy rubber stamp
	b = _buf(0.3)
	lp = 0.0
	for i in b.size():
		var x := float(i) / RATE
		lp += 0.2 * (randf_range(-1.0, 1.0) - lp)
		b[i] = (sin(TAU * 70.0 * x) * 0.8 + lp) * exp(-x * 16.0)
	sounds["stamp"] = _wav(b)

	# murmur: crowd reacting
	b = _buf(1.4)
	lp = 0.0
	for i in b.size():
		var x := float(i) / RATE
		lp += 0.18 * (randf_range(-1.0, 1.0) - lp)
		var am := 0.5 + 0.5 * sin(TAU * 5.5 * x + sin(TAU * 1.3 * x) * 2.0)
		b[i] = lp * am * sin(PI * x / 1.4) * 1.6
	sounds["murmur"] = _wav(b)

	# chime: level cleared
	b = _buf(1.2)
	var notes := [523.25, 659.25, 783.99, 1046.5]
	for i in b.size():
		var x := float(i) / RATE
		var v := 0.0
		for k in 4:
			var y := x - k * 0.12
			if y > 0.0:
				v += sin(TAU * notes[k] * y) * exp(-y * 4.0)
		b[i] = v * 0.25
	sounds["chime"] = _wav(b)


# Renders a looping song: bass, chords in the instrument style and a
# light random melody, all from chord lists.
func _render_song(spec: Dictionary) -> AudioStreamWAV:
	var bpm: float = spec["bpm"]
	var meter: int = spec["meter"]
	var chords: Array = spec["chords"]
	var inst: String = spec["inst"]
	var lead: String = spec["lead"]
	var rng := RandomNumberGenerator.new()
	rng.seed = spec["seed"]
	var beat := 60.0 / bpm
	var bar := beat * meter
	var buf := PackedFloat32Array()
	buf.resize(int(bar * chords.size() * 2 * MRATE))
	for rep in 2:
		for ci in chords.size():
			var ch: Array = chords[ci]
			var t0 := (rep * chords.size() + ci) * bar
			_note(buf, t0, bar * 0.95, ch[0] - 24, "bass", 0.32)
			match inst:
				"epiano":
					for b in [0.0, 1.5, 2.5, 3.5]:
						for m in ch:
							_note(buf, t0 + b * beat, beat * 0.7, m, "epiano", 0.075)
				"musicbox":
					for k in meter * 2:
						var m: int = ch[k % ch.size()] + 12
						_note(buf, t0 + k * beat * 0.5, beat, m, "musicbox", 0.12)
				"organ":
					for m in ch:
						_note(buf, t0, bar, m, "organ", 0.07)
			for b in meter:
				if rng.randf() < 0.55:
					var off := beat * 0.5 if rng.randf() < 0.3 else 0.0
					var m: int = ch[rng.randi() % ch.size()] + 12
					_note(buf, t0 + b * beat + off, beat * 0.9, m, lead, 0.1)
	var peak := 0.001
	for v in buf:
		peak = maxf(peak, absf(v))
	var g := 0.8 / peak
	for i in buf.size():
		buf[i] *= g
	return _wav(buf, MRATE, true)


func _note(buf: PackedFloat32Array, start: float, dur: float, midi: int, inst: String, amp: float) -> void:
	var f := 440.0 * pow(2.0, (midi - 69) / 12.0)
	var n := buf.size()
	var s0 := int(start * MRATE)
	var tail := 0.25
	var length := int((dur + tail) * MRATE)
	var w := TAU * f / MRATE
	match inst:
		"bass":
			for i in length:
				var x := float(i) / MRATE
				var env := minf(1.0, x * 80.0) * exp(-x * 2.5) * _rel(x, dur, tail)
				buf[(s0 + i) % n] += sin(w * i) * env * amp
		"epiano":
			for i in length:
				var x := float(i) / MRATE
				var env := minf(1.0, x * 200.0) * exp(-x * 2.8) * _rel(x, dur, tail)
				buf[(s0 + i) % n] += (sin(w * i) + 0.35 * sin(2.0 * w * i) * exp(-x * 6.0)) * env * amp
		"musicbox":
			for i in length:
				var x := float(i) / MRATE
				var env := minf(1.0, x * 300.0) * exp(-x * 4.5)
				buf[(s0 + i) % n] += (sin(w * i) + 0.25 * sin(4.0 * w * i)) * env * amp
		"organ":
			for i in length:
				var x := float(i) / MRATE
				var env := minf(1.0, x * 12.0) * _rel(x, dur, tail)
				buf[(s0 + i) % n] += (sin(w * i) + 0.5 * sin(2.0 * w * i) + 0.25 * sin(3.0 * w * i)) * env * amp
		"bell":
			for i in length:
				var x := float(i) / MRATE
				var env := minf(1.0, x * 300.0) * exp(-x * 3.0)
				buf[(s0 + i) % n] += (sin(w * i) + 0.4 * sin(2.76 * w * i) * exp(-x * 4.0)) * env * amp
		"flute":
			var ph := 0.0
			for i in length:
				var x := float(i) / MRATE
				var env := minf(1.0, x * 14.0) * _rel(x, dur, tail)
				ph += w * (1.0 + sin(TAU * 5.0 * x) * 0.004 * minf(1.0, x * 3.0))
				buf[(s0 + i) % n] += sin(ph) * env * amp


func _rel(x: float, dur: float, tail: float) -> float:
	if x < dur:
		return 1.0
	return maxf(0.0, 1.0 - (x - dur) / tail)
