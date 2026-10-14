extends Node
## Synthesized audio: SFX, wind, birdsong and background music. No audio files are loaded.
## Everything is rendered into small AudioStreamWAVs on worker threads at startup.

const RATE := 22050
const MUSIC_RATE := 16000
const SFX_POOL := 10

var _streams := {}           # name -> AudioStreamWAV (or Array of variants)
var _pool: Array[AudioStreamPlayer] = []
var _pool_next := 0
var _music: AudioStreamPlayer
var _wind: AudioStreamPlayer
var _birds: AudioStreamPlayer
var _bird_timer := 2.0
var _wind_target_db := -60.0
var _wind_target_pitch := 1.0
var _music_wanted := false
var birds_enabled := true


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_make_buses()
	Settings.apply_volumes()
	for i in SFX_POOL:
		var p := AudioStreamPlayer.new()
		p.bus = "SFX"
		add_child(p)
		_pool.append(p)
	_music = AudioStreamPlayer.new()
	_music.bus = "Music"
	_music.volume_db = -6.0
	add_child(_music)
	_wind = AudioStreamPlayer.new()
	_wind.bus = "Ambience"
	_wind.volume_db = -60.0
	add_child(_wind)
	_birds = AudioStreamPlayer.new()
	_birds.bus = "Ambience"
	_birds.volume_db = -14.0
	add_child(_birds)
	WorkerThreadPool.add_task(_synth_sfx, false, "synth sfx")
	WorkerThreadPool.add_task(_synth_music, false, "synth music")


func _make_buses() -> void:
	for bus_name in ["Music", "SFX", "Ambience"]:
		if AudioServer.get_bus_index(bus_name) == -1:
			var idx := AudioServer.bus_count
			AudioServer.add_bus(idx)
			AudioServer.set_bus_name(idx, bus_name)
			AudioServer.set_bus_send(idx, "Master")
	# A gentle reverb on SFX makes the chimes feel airy.
	var sfx := AudioServer.get_bus_index("SFX")
	if AudioServer.get_bus_effect_count(sfx) == 0:
		var rv := AudioEffectReverb.new()
		rv.room_size = 0.45
		rv.wet = 0.12
		rv.dry = 1.0
		AudioServer.add_bus_effect(sfx, rv)


func _process(delta: float) -> void:
	var k := 1.0 - exp(-4.0 * delta)
	_wind.volume_db = lerpf(_wind.volume_db, _wind_target_db, k)
	_wind.pitch_scale = lerpf(_wind.pitch_scale, _wind_target_pitch, k)
	if birds_enabled and _streams.has("birds"):
		_bird_timer -= delta
		if _bird_timer <= 0.0:
			_bird_timer = randf_range(1.5, 4.5)
			var variants: Array = _streams["birds"]
			_birds.stream = variants[randi() % variants.size()]
			_birds.pitch_scale = randf_range(0.9, 1.15)
			_birds.volume_db = randf_range(-18.0, -11.0)
			_birds.play()


## Plays a one-shot sound effect by name.
func play(sound: String, volume_db := 0.0, pitch := 1.0) -> void:
	if not _streams.has(sound):
		return
	var p := _pool[_pool_next]
	_pool_next = (_pool_next + 1) % _pool.size()
	p.stream = _streams[sound]
	p.volume_db = volume_db
	p.pitch_scale = pitch
	p.play()


## Wind follows the plane speed. Pass active=false to fade it out.
func set_wind(speed: float, active: bool) -> void:
	if not active:
		_wind_target_db = -50.0
		_wind_target_pitch = 0.8
		return
	var t := clampf((speed - 3.0) / 18.0, 0.0, 1.0)
	_wind_target_db = lerpf(-24.0, -5.0, t)
	_wind_target_pitch = lerpf(0.7, 1.65, t)


func play_music() -> void:
	_music_wanted = true
	if _streams.has("music") and not _music.playing:
		_music.stream = _streams["music"]
		_music.play()


func stop_music() -> void:
	_music_wanted = false
	_music.stop()


func _on_synth_done(result: Dictionary) -> void:
	for k in result:
		_streams[k] = result[k]
	if result.has("wind") and not _wind.playing:
		_wind.stream = result["wind"]
		_wind.play()
	if result.has("music") and _music_wanted:
		play_music()


# --- Synthesis (runs on worker threads) -------------------------------------

func _synth_sfx() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var out := {}
	out["throw"] = _wav(_whoosh(rng, 0.55, 0.05, 0.45, 0.9))
	out["gust"] = _wav(_whoosh(rng, 0.7, 0.08, 0.6, 0.8))
	out["star"] = _wav(_mix([_bell([1318.5, 1975.5], 0.7, 5.0, 0.35), _delay(_bell([1975.5, 2637.0], 0.6, 6.0, 0.25), 0.07)]))
	out["ring"] = _wav(_mix([
		_bell([784.0, 1568.0], 0.5, 6.0, 0.3),
		_delay(_bell([987.8, 1975.5], 0.5, 6.0, 0.28), 0.07),
		_delay(_bell([1174.7, 2349.3], 0.6, 5.0, 0.28), 0.14),
	]))
	out["bonus"] = _wav(_mix([
		_bell([784.0], 0.9, 3.0, 0.3), _delay(_bell([987.8], 0.9, 3.0, 0.3), 0.08),
		_delay(_bell([1174.7], 0.9, 3.0, 0.3), 0.16), _delay(_bell([1568.0, 3136.0], 1.2, 2.5, 0.32), 0.24),
	]))
	out["stall"] = _wav(_mix([_beep(523.0, 0.1), _delay(_beep(523.0, 0.1), 0.17)]))
	out["rising"] = _wav(_rising())
	out["crumple"] = _wav(_crumple(rng))
	out["splash"] = _wav(_splash(rng))
	out["land"] = _wav(_chord([392.0, 493.9, 587.3, 784.0], 2.2))
	out["click"] = _wav(_bell([1760.0], 0.08, 40.0, 0.18))
	out["roll"] = _wav(_whoosh(rng, 0.45, 0.1, 0.5, 0.55))
	out["wind"] = _wav(_wind_loop(rng), true)
	var birds := []
	for i in 4:
		birds.append(_wav(_bird(rng)))
	out["birds"] = birds
	call_deferred("_on_synth_done", out)


func _synth_music() -> void:
	var data := _music_loop()
	var w := _wav(data, true, MUSIC_RATE)
	call_deferred("_on_synth_done", {"music": w})


func _wav(samples: PackedFloat32Array, loop := false, rate := RATE) -> AudioStreamWAV:
	var bytes := PackedByteArray()
	bytes.resize(samples.size() * 2)
	for i in samples.size():
		bytes.encode_s16(i * 2, int(clampf(samples[i], -1.0, 1.0) * 32000.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = rate
	w.stereo = false
	w.data = bytes
	if loop:
		w.loop_mode = AudioStreamWAV.LOOP_FORWARD
		w.loop_begin = 0
		w.loop_end = samples.size()
	return w


func _buf(seconds: float, rate := RATE) -> PackedFloat32Array:
	var b := PackedFloat32Array()
	b.resize(int(seconds * rate))
	return b


func _mix(parts: Array) -> PackedFloat32Array:
	var n := 0
	for p in parts:
		n = maxi(n, p.size())
	var out := PackedFloat32Array()
	out.resize(n)
	for p in parts:
		for i in p.size():
			out[i] += p[i]
	return out


func _delay(s: PackedFloat32Array, seconds: float) -> PackedFloat32Array:
	var pad := int(seconds * RATE)
	var out := PackedFloat32Array()
	out.resize(s.size() + pad)
	for i in s.size():
		out[i + pad] = s[i]
	return out


func _whoosh(rng: RandomNumberGenerator, dur: float, a0: float, a1: float, amp: float) -> PackedFloat32Array:
	var out := _buf(dur)
	var n := out.size()
	var lp := 0.0
	var lp2 := 0.0
	for i in n:
		var t := float(i) / n
		var a := lerpf(a0, a1, sin(t * PI))
		lp += (rng.randf_range(-1.0, 1.0) - lp) * a
		lp2 += (lp - lp2) * a * 0.35
		var env := pow(sin(PI * pow(t, 0.7)), 1.6)
		out[i] = (lp - lp2 * 0.7) * env * amp * 2.2
	return out


func _bell(freqs: Array, dur: float, decay: float, amp: float) -> PackedFloat32Array:
	var out := _buf(dur)
	for i in out.size():
		var t := float(i) / RATE
		var env := minf(1.0, t * 300.0) * exp(-decay * t)
		var v := 0.0
		for j in freqs.size():
			v += sin(TAU * freqs[j] * t) / (1.0 + j * 1.5)
		out[i] = v * env * amp
	return out


func _beep(f: float, dur: float) -> PackedFloat32Array:
	var out := _buf(dur)
	var n := out.size()
	for i in n:
		var t := float(i) / RATE
		var env := minf(1.0, t * 200.0) * minf(1.0, (dur - t) * 120.0)
		var ph := TAU * f * t
		out[i] = (sin(ph) + 0.33 * sin(3.0 * ph) + 0.2 * sin(5.0 * ph)) * env * 0.22
	return out


func _rising() -> PackedFloat32Array:
	var dur := 1.1
	var out := _buf(dur)
	var ph1 := 0.0
	var ph2 := 0.0
	for i in out.size():
		var t := float(i) / RATE
		var f := lerpf(440.0, 660.0, smoothstep(0.0, 0.8, t))
		ph1 += TAU * f / RATE
		ph2 += TAU * f * 1.5 / RATE
		var env := smoothstep(0.0, 0.15, t) * (1.0 - smoothstep(0.6, dur, t))
		var trem := 0.8 + 0.2 * sin(TAU * 7.0 * t)
		out[i] = (sin(ph1) * 0.6 + sin(ph2) * 0.25) * env * trem * 0.28
	return out


func _crumple(rng: RandomNumberGenerator) -> PackedFloat32Array:
	var dur := 0.75
	var out := _buf(dur)
	var lp := 0.0
	var burst := 0.0
	for i in out.size():
		var t := float(i) / RATE
		var density := 0.012 * (1.0 - t / dur) + 0.002
		if rng.randf() < density:
			burst = rng.randf_range(0.4, 1.0)
		burst *= 0.993
		var x := rng.randf_range(-1.0, 1.0)
		lp += (x - lp) * 0.25
		out[i] = (x - lp) * burst * 0.75 * (1.0 - t / dur)
	return out


func _splash(rng: RandomNumberGenerator) -> PackedFloat32Array:
	var dur := 1.2
	var out := _buf(dur)
	var lp := 0.0
	var bub_f := 0.0
	var bub_t := 1.0
	var ph := 0.0
	for i in out.size():
		var t := float(i) / RATE
		var a := lerpf(0.6, 0.08, minf(1.0, t * 2.0))
		lp += (rng.randf_range(-1.0, 1.0) - lp) * a
		var env := minf(1.0, t * 80.0) * exp(-3.5 * t)
		var v := lp * env * 0.9
		if t > 0.15 and rng.randf() < 0.0009:
			bub_f = rng.randf_range(500.0, 1100.0)
			bub_t = 0.0
		if bub_t < 0.08:
			ph += TAU * bub_f * (1.0 + bub_t * 8.0) / RATE
			v += sin(ph) * (1.0 - bub_t / 0.08) * 0.15
			bub_t += 1.0 / RATE
		out[i] = v
	return out


func _chord(freqs: Array, dur: float) -> PackedFloat32Array:
	var out := _buf(dur)
	for i in out.size():
		var t := float(i) / RATE
		var v := 0.0
		for j in freqs.size():
			var tj := t - j * 0.06
			if tj <= 0.0:
				continue
			var ph := fposmod(freqs[j] * tj, 1.0)
			var tri := 4.0 * absf(ph - 0.5) - 1.0
			v += (tri * 0.7 + sin(TAU * freqs[j] * tj) * 0.3) * minf(1.0, tj * 60.0) * exp(-1.6 * tj)
		out[i] = v * 0.16
	return out


func _bird(rng: RandomNumberGenerator) -> PackedFloat32Array:
	var syllables := rng.randi_range(2, 5)
	var parts := []
	var start := 0.0
	var base := rng.randf_range(2600.0, 3800.0)
	for s in syllables:
		var dur := rng.randf_range(0.05, 0.12)
		var sweep := rng.randf_range(-900.0, 1400.0)
		var buf := _buf(dur)
		var ph := 0.0
		for i in buf.size():
			var t := float(i) / RATE
			var f := base + sweep * (t / dur) + 250.0 * sin(TAU * 38.0 * t)
			ph += TAU * f / RATE
			buf[i] = sin(ph) * sin(PI * t / dur) * 0.22
		parts.append(_delay(buf, start))
		start += dur + rng.randf_range(0.02, 0.09)
	return _mix(parts)


func _wind_loop(rng: RandomNumberGenerator) -> PackedFloat32Array:
	var dur := 3.0
	var fade := int(0.4 * RATE)
	var raw := _buf(dur + 0.4)
	var lp := 0.0
	var lp2 := 0.0
	for i in raw.size():
		var t := float(i) / RATE
		lp += (rng.randf_range(-1.0, 1.0) - lp) * 0.08
		lp2 += (lp - lp2) * 0.05
		raw[i] = (lp * 0.6 + lp2 * 1.4) * (0.8 + 0.2 * sin(TAU * 0.67 * t)) * 1.4
	var n := int(dur * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	for i in n:
		out[i] = raw[i]
	# Crossfade the tail into the head so the loop is seamless.
	for i in fade:
		var w := float(i) / fade
		out[i] = raw[n + i] * (1.0 - w) + raw[i] * w
	return out


func _music_loop() -> PackedFloat32Array:
	var bpm := 84.0
	var beat := 60.0 / bpm
	var chord_len := beat * 4.0
	var chords := [
		[196.0, 246.9, 293.7, 98.0],   # G
		[164.8, 196.0, 246.9, 82.4],   # Em
		[196.0, 261.6, 329.6, 65.4],   # C
		[220.0, 293.7, 370.0, 73.4],   # D
	]
	var pent := [392.0, 440.0, 493.9, 587.3, 659.3, 784.0]
	var total := chord_len * 8.0
	var n := int(total * MUSIC_RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	# Melody: eighth notes on a seeded walk over the G pentatonic scale.
	var rng := RandomNumberGenerator.new()
	rng.seed = 20261013
	var mel_notes := []
	var step := beat * 0.5
	var idx := 2
	var count := int(total / step)
	for k in count:
		if rng.randf() < 0.32 or k % 16 == 15:
			mel_notes.append(0.0)
		else:
			idx = clampi(idx + rng.randi_range(-2, 2), 0, pent.size() - 1)
			mel_notes.append(pent[idx])
	for i in n:
		var t := float(i) / MUSIC_RATE
		var ci := int(t / chord_len) % 4
		var ct := fmod(t, chord_len)
		var cenv := smoothstep(0.0, 0.35, ct) * (1.0 - smoothstep(chord_len - 0.45, chord_len, ct))
		var c: Array = chords[ci]
		var v := 0.0
		for j in 3:
			var ph := fposmod(c[j] * t, 1.0)
			v += (4.0 * absf(ph - 0.5) - 1.0) * 0.075
		v *= cenv
		# Soft plucked bass on beats 1 and 3.
		var bt := fmod(ct, beat * 2.0)
		v += sin(TAU * c[3] * t) * exp(-2.2 * bt) * 0.16 * cenv
		# Melody.
		var mk := int(t / step)
		var mf: float = mel_notes[mk % mel_notes.size()]
		if mf > 0.0:
			var mt := fmod(t, step)
			var mph := fposmod(mf * t, 1.0)
			var mtri := 4.0 * absf(mph - 0.5) - 1.0
			v += mtri * minf(1.0, mt * 80.0) * exp(-3.2 * mt) * 0.09
		out[i] = v
	return out
