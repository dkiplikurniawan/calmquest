class_name SoundSynth
extends RefCounted
## Generates the game's original, gentle sound effects and ambient pad at startup.
## No audio files are needed, so there are no licensing questions and no missing assets.
##
## 0.4.0 refresh: softer attacks (8-15 ms, no clicks), fewer high partials, a
## warm low-passed noise for rustles and splashes, new sounds for gathering,
## crafting, cooking, placing, quest steps and fishing, and quiet footsteps for
## six surfaces (two variations each). AudioManager adds a small random pitch
## change to every play, so repeats never sound mechanical.

const SFX_RATE := 22050
const PAD_RATE := 11025
const PAD_SECONDS := 8.0
## Footstep surfaces (see Footsteps.surface_for).
const SURFACES: PackedStringArray = ["grass", "path", "wood", "sand", "snow", "stone"]


static func build_library() -> Dictionary:
	var lib := {
		&"collect": _bell([987.8, 1480.0], [1.0, 0.22], 0.7, 5.5, 0.26),
		&"bonus": _sequence([[1046.5, 0.0], [1318.5, 0.09], [1568.0, 0.18]], 0.9, 5.0, 0.2),
		&"lantern": _bell([659.3, 988.0], [1.0, 0.35], 1.0, 4.0, 0.26),
		&"discover": _sequence([[987.8, 0.0], [1318.5, 0.14]], 0.9, 5.0, 0.2),
		&"restore": _mix([_sequence([[523.3, 0.0], [659.3, 0.2], [784.0, 0.4], [1046.5, 0.6], [1318.5, 0.8]], 2.6, 1.8, 0.16), _bell([261.6, 392.0], [1.0, 0.5], 2.6, 1.2, 0.09)]),
		&"bloom": _sequence([[784.0, 0.0], [1046.5, 0.12]], 1.0, 4.0, 0.19),
		&"ui_hover": _bell([1046.5], [1.0], 0.06, 45.0, 0.045),
		&"ui_click": _bell([659.3, 988.0], [1.0, 0.25], 0.14, 24.0, 0.12),
		&"soft_deny": _bell([349.2], [1.0], 0.24, 13.0, 0.13),
		&"night": _bell([196.0, 293.7, 392.0], [1.0, 0.6, 0.4], 2.5, 1.4, 0.16),
		# New in 0.4.0.
		&"gather": _mix([_pluck(523.3, 0.4, 0.17), _noise(0.09, 1300.0, 0.0, 22.0, 0.07, 11)]),
		&"craft": _mix([_knock(196.0, 0.12, 0.2), _delay(_sequence([[784.0, 0.0], [1174.7, 0.08]], 0.8, 5.5, 0.16), 0.1)]),
		&"cook": _mix([_bubbles(0.32, 0.09, 21), _delay(_sequence([[659.3, 0.0], [987.8, 0.1]], 0.9, 4.5, 0.16), 0.24)]),
		&"place": _mix([_knock(146.8, 0.1, 0.22), _noise(0.06, 900.0, 0.0, 40.0, 0.06, 31), _delay(_bell([1046.5], [1.0], 0.35, 9.0, 0.06), 0.05)]),
		&"quest_step": _sequence([[659.3, 0.0], [880.0, 0.12]], 0.9, 4.0, 0.17),
		&"splash": _mix([_noise(0.5, 950.0, 0.0, 8.0, 0.16, 41), _glide(440.0, 250.0, 0.18, 0.08)]),
		&"catch": _mix([_noise(0.35, 900.0, 0.0, 10.0, 0.08, 51), _delay(_sequence([[784.0, 0.0], [1046.5, 0.1], [1318.5, 0.2]], 1.1, 3.8, 0.17), 0.08)]),
		&"swell": _swell(),
	}
	for surface in SURFACES:
		for variant in [1, 2]:
			lib[StringName("step_%s_%d" % [surface, variant])] = _footstep(surface, variant)
	return lib


## A softly decaying chord of partials.
static func _bell(freqs: Array, gains: Array, seconds: float, decay: float, volume: float) -> PackedFloat32Array:
	var n := int(seconds * SFX_RATE)
	var samples := PackedFloat32Array()
	samples.resize(n)
	var attack := int(0.01 * SFX_RATE)
	for i in n:
		var t := float(i) / SFX_RATE
		var env := exp(-decay * t)
		if i < attack:
			env *= float(i) / attack
		var v := 0.0
		for k in freqs.size():
			v += float(gains[k]) * sin(TAU * float(freqs[k]) * t)
		samples[i] = v * env * volume
	return samples


## Notes as [frequency, start_seconds] pairs, each with a bell envelope.
static func _sequence(notes: Array, seconds: float, decay: float, volume: float) -> PackedFloat32Array:
	var n := int(seconds * SFX_RATE)
	var samples := PackedFloat32Array()
	samples.resize(n)
	var attack := int(0.012 * SFX_RATE)
	for note: Array in notes:
		var freq := float(note[0])
		var start := int(float(note[1]) * SFX_RATE)
		for i in range(start, n):
			var local := i - start
			var t := float(local) / SFX_RATE
			var env := exp(-decay * t)
			if local < attack:
				env *= float(local) / attack
			samples[i] += (sin(TAU * freq * t) + 0.18 * sin(TAU * freq * 2.0 * t)) * env * volume
	return samples


## A soft plucked note: a quick, warm decay with a faint octave.
static func _pluck(freq: float, seconds: float, volume: float) -> PackedFloat32Array:
	var n := int(seconds * SFX_RATE)
	var samples := PackedFloat32Array()
	samples.resize(n)
	var attack := int(0.006 * SFX_RATE)
	for i in n:
		var t := float(i) / SFX_RATE
		var env := exp(-11.0 * t)
		if i < attack:
			env *= float(i) / attack
		samples[i] = (sin(TAU * freq * t) + 0.3 * sin(TAU * freq * 1.5 * t) * exp(-20.0 * t)) * env * volume
	return samples


## A low wooden knock (two damped partials).
static func _knock(freq: float, seconds: float, volume: float) -> PackedFloat32Array:
	var n := int(seconds * SFX_RATE)
	var samples := PackedFloat32Array()
	samples.resize(n)
	var attack := int(0.004 * SFX_RATE)
	for i in n:
		var t := float(i) / SFX_RATE
		var env := exp(-30.0 * t)
		if i < attack:
			env *= float(i) / attack
		samples[i] = (sin(TAU * freq * t) + 0.45 * sin(TAU * freq * 2.03 * t) * exp(-15.0 * t)) * env * volume
	return samples


## Warm noise: white noise through a one-pole low-pass filter (and optionally
## a gentle high-pass), with a soft attack and an exponential decay.
static func _noise(seconds: float, lowpass_hz: float, highpass_hz: float, decay: float, volume: float, seed_value: int, attack_s: float = 0.008) -> PackedFloat32Array:
	var n := int(seconds * SFX_RATE)
	var samples := PackedFloat32Array()
	samples.resize(n)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var a := 1.0 - exp(-TAU * lowpass_hz / SFX_RATE)
	var b := 1.0 - exp(-TAU * maxf(highpass_hz, 1.0) / SFX_RATE)
	var lp := 0.0
	var hp_state := 0.0
	var attack := maxi(1, int(attack_s * SFX_RATE))
	for i in n:
		lp += a * (rng.randf_range(-1.0, 1.0) - lp)
		var v := lp
		if highpass_hz > 0.0:
			hp_state += b * (lp - hp_state)
			v = lp - hp_state
		var t := float(i) / SFX_RATE
		var env := exp(-decay * t)
		if i < attack:
			env *= float(i) / attack
		samples[i] = v * env * volume * 2.5
	return samples


## A short pitch glide (the "bloop" of something touching water).
static func _glide(from_hz: float, to_hz: float, seconds: float, volume: float) -> PackedFloat32Array:
	var n := int(seconds * SFX_RATE)
	var samples := PackedFloat32Array()
	samples.resize(n)
	var phase := 0.0
	var attack := int(0.01 * SFX_RATE)
	for i in n:
		var k := float(i) / n
		phase += TAU * lerpf(from_hz, to_hz, k) / SFX_RATE
		var env := (1.0 - k) * (float(i) / attack if i < attack else 1.0)
		samples[i] = sin(phase) * env * volume
	return samples


## A few small, low bubbles.
static func _bubbles(seconds: float, volume: float, seed_value: int) -> PackedFloat32Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var out := PackedFloat32Array()
	out.resize(int(seconds * SFX_RATE))
	for k in 4:
		var bubble := _glide(rng.randf_range(300.0, 420.0), rng.randf_range(480.0, 620.0), 0.07, volume)
		out = _mix([out, _delay(bubble, rng.randf_range(0.0, seconds - 0.08))])
	return out


## The rest-spot / finale swell: a slow, warm chord that rises and fades.
static func _swell() -> PackedFloat32Array:
	var seconds := 4.0
	var n := int(seconds * SFX_RATE)
	var samples := PackedFloat32Array()
	samples.resize(n)
	var freqs := [261.6, 329.6, 392.0, 523.3]
	var gains := [1.0, 0.7, 0.6, 0.35]
	for i in n:
		var t := float(i) / SFX_RATE
		var env := sin(PI * minf(t / seconds, 1.0)) ** 2
		var v := 0.0
		for k in freqs.size():
			v += float(gains[k]) * sin(TAU * float(freqs[k]) * t)
		samples[i] = v * env * 0.07
	return samples


## Quiet footsteps for one surface; `variant` 1 or 2 changes the grain.
static func _footstep(surface: String, variant: int) -> PackedFloat32Array:
	var s := 100 + variant * 7 + SURFACES.find(surface) * 13
	match surface:
		"grass":
			return _noise(0.08, 1500.0, 120.0, 38.0, 0.09, s)
		"path":
			return _mix([_noise(0.07, 2200.0, 200.0, 45.0, 0.08, s), _knock(105.0 + variant * 8.0, 0.06, 0.07)])
		"wood":
			return _mix([_knock(150.0 + variant * 12.0, 0.1, 0.13), _noise(0.05, 1800.0, 300.0, 60.0, 0.03, s)])
		"sand":
			return _noise(0.12, 900.0, 80.0, 24.0, 0.08, s, 0.018)
		"snow":
			return _mix([_noise(0.12, 2600.0, 600.0, 22.0, 0.07, s, 0.012), _noise(0.06, 900.0, 0.0, 40.0, 0.05, s + 1)])
		"stone":
			return _mix([_bell([620.0 + variant * 40.0], [1.0], 0.06, 70.0, 0.05), _noise(0.04, 3000.0, 800.0, 80.0, 0.04, s)])
	return _noise(0.08, 1500.0, 120.0, 38.0, 0.09, s)


## Sums sample arrays (the result is as long as the longest).
static func _mix(parts: Array) -> PackedFloat32Array:
	var n := 0
	for p: PackedFloat32Array in parts:
		n = maxi(n, p.size())
	var out := PackedFloat32Array()
	out.resize(n)
	for p: PackedFloat32Array in parts:
		for i in p.size():
			out[i] += p[i]
	return out


static func _delay(samples: PackedFloat32Array, seconds: float) -> PackedFloat32Array:
	var offset := int(seconds * SFX_RATE)
	var out := PackedFloat32Array()
	out.resize(samples.size() + offset)
	for i in samples.size():
		out[offset + i] = samples[i]
	return out


## Seamlessly looping ambient pad (Cmaj9 voicing). Each partial is snapped to a
## frequency that completes whole cycles in PAD_SECONDS so the loop has no click.
static func build_ambient_pad() -> AudioStreamWAV:
	var base_freqs := [130.81, 196.0, 246.94, 293.66, 329.63]
	var gains := [0.9, 0.6, 0.45, 0.4, 0.3]
	var freqs: Array[float] = []
	for f: float in base_freqs:
		freqs.append(roundf(f * PAD_SECONDS) / PAD_SECONDS)
	var n := int(PAD_SECONDS * PAD_RATE)
	var samples := PackedFloat32Array()
	samples.resize(n)
	for i in n:
		var t := float(i) / PAD_RATE
		var v := 0.0
		for k in freqs.size():
			# Slow, out-of-phase swells (whole cycles per loop) give gentle movement.
			var lfo := 0.6 + 0.4 * sin(TAU * t * float(k % 2 + 1) / PAD_SECONDS + k)
			v += float(gains[k]) * lfo * sin(TAU * freqs[k] * t)
		samples[i] = v * 0.11
	return to_wav(samples, PAD_RATE, true)


## Peak level of a sound (for tests: nothing should be loud or harsh).
static func peak(samples: PackedFloat32Array) -> float:
	var p := 0.0
	for v in samples:
		p = maxf(p, absf(v))
	return p


static func to_wav(samples: PackedFloat32Array, rate: int, loop: bool) -> AudioStreamWAV:
	var data := PackedByteArray()
	data.resize(samples.size() * 2)
	for i in samples.size():
		var s := clampi(int(samples[i] * 32767.0), -32768, 32767)
		data.encode_s16(i * 2, s)
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = rate
	wav.stereo = false
	wav.data = data
	if loop:
		wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
		wav.loop_begin = 0
		wav.loop_end = samples.size()
	return wav
