class_name SoundSynth
extends RefCounted
## Generates the game's original, gentle sound effects and ambient pad at startup.
## No audio files are needed, so there are no licensing questions and no missing assets.

const SFX_RATE := 22050
const PAD_RATE := 11025
const PAD_SECONDS := 8.0


static func build_library() -> Dictionary:
	return {
		&"collect": _bell([1046.5, 1568.0], [1.0, 0.35], 0.7, 6.0, 0.30),
		&"bonus": _sequence([[1174.7, 0.0], [1568.0, 0.09], [2093.0, 0.18]], 0.9, 5.0, 0.24),
		&"lantern": _bell([659.3, 988.0], [1.0, 0.4], 1.0, 4.0, 0.30),
		&"discover": _sequence([[1318.5, 0.0], [1760.0, 0.14]], 0.9, 5.0, 0.24),
		&"restore": _sequence([[523.3, 0.0], [659.3, 0.2], [784.0, 0.4], [1046.5, 0.6], [1318.5, 0.8]], 2.6, 1.8, 0.26),
		&"bloom": _sequence([[784.0, 0.0], [1046.5, 0.12]], 1.0, 4.0, 0.22),
		&"ui_hover": _bell([1318.5], [1.0], 0.07, 40.0, 0.07),
		&"ui_click": _bell([784.0, 1174.7], [1.0, 0.3], 0.16, 22.0, 0.20),
		&"soft_deny": _bell([392.0], [1.0], 0.22, 14.0, 0.16),
		&"night": _bell([196.0, 293.7, 392.0], [1.0, 0.6, 0.4], 2.5, 1.4, 0.18),
	}


## A softly decaying chord of partials.
static func _bell(freqs: Array, gains: Array, seconds: float, decay: float, volume: float) -> AudioStreamWAV:
	var n := int(seconds * SFX_RATE)
	var samples := PackedFloat32Array()
	samples.resize(n)
	var attack := int(0.008 * SFX_RATE)
	for i in n:
		var t := float(i) / SFX_RATE
		var env := exp(-decay * t)
		if i < attack:
			env *= float(i) / attack
		var v := 0.0
		for k in freqs.size():
			v += float(gains[k]) * sin(TAU * float(freqs[k]) * t)
		samples[i] = v * env * volume
	return _to_wav(samples, SFX_RATE, false)


## Notes as [frequency, start_seconds] pairs, each with a bell envelope.
static func _sequence(notes: Array, seconds: float, decay: float, volume: float) -> AudioStreamWAV:
	var n := int(seconds * SFX_RATE)
	var samples := PackedFloat32Array()
	samples.resize(n)
	var attack := int(0.01 * SFX_RATE)
	for note: Array in notes:
		var freq := float(note[0])
		var start := int(float(note[1]) * SFX_RATE)
		for i in range(start, n):
			var local := i - start
			var t := float(local) / SFX_RATE
			var env := exp(-decay * t)
			if local < attack:
				env *= float(local) / attack
			samples[i] += (sin(TAU * freq * t) + 0.25 * sin(TAU * freq * 2.0 * t)) * env * volume
	return _to_wav(samples, SFX_RATE, false)


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
	var wav := _to_wav(samples, PAD_RATE, true)
	return wav


static func _to_wav(samples: PackedFloat32Array, rate: int, loop: bool) -> AudioStreamWAV:
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
