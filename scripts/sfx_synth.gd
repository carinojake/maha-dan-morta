extends Node

const MIX_RATE := 22050

var _streams: Dictionary = {}
var _players: Array[AudioStreamPlayer] = []
var _bgm_player: AudioStreamPlayer
var _bgm_normal: AudioStreamWAV
var _bgm_boss: AudioStreamWAV
var _bgm_is_boss: bool = false
var _next_idx: int = 0


func _ready():
	for i in range(10):
		var p := AudioStreamPlayer.new()
		p.volume_db = -6.0
		add_child(p)
		_players.append(p)

	_streams["slash"] = _make_sweep(680.0, 180.0, 0.13, 0.45, true)
	_streams["talisman"] = _make_sweep(980.0, 1450.0, 0.11, 0.35, false)
	_streams["hit"] = _make_sweep(210.0, 75.0, 0.10, 0.55, true)
	_streams["crit"] = _make_chord([523.25, 783.99, 1046.5], 0.22, 0.50)
	_streams["dash"] = _make_sweep(420.0, 920.0, 0.14, 0.30, true)
	_streams["switch"] = _make_chord([440.0, 659.25], 0.18, 0.35)
	_streams["skill_q"] = _make_sweep(520.0, 1180.0, 0.20, 0.45, false)
	_streams["skill_e"] = _make_chord([293.66, 440.0, 587.33], 0.38, 0.50)
	_streams["ultimate"] = _make_ultimate_boom()
	_streams["boss_warn"] = _make_chord([330.0, 349.23], 0.32, 0.40)
	_streams["boss_slam"] = _make_sweep(160.0, 42.0, 0.35, 0.75, true)
	_streams["dodge"] = _make_sweep(660.0, 1320.0, 0.12, 0.30, false)
	_streams["victory"] = _make_chord([523.25, 659.25, 783.99, 1046.5], 0.65, 0.50)
	_streams["resonance"] = _make_chord([587.33, 880.0, 1174.66, 1479.98], 0.35, 0.55)
	_streams["shield_break"] = _make_sweep(980.0, 190.0, 0.25, 0.65, true)
	_streams["laser_warn"] = _make_sweep(440.0, 880.0, 0.22, 0.35, false)
	_streams["perfect_dodge"] = _make_chord([783.99, 1174.66, 1567.98, 2093.0], 0.42, 0.55)
	_streams["reaction"] = _make_chord([392.0, 587.33, 880.0, 1318.5], 0.30, 0.55)

	_bgm_normal = _make_xianxia_bgm_loop()
	_bgm_boss = _make_boss_bgm_loop()
	_bgm_player = AudioStreamPlayer.new()
	_bgm_player.stream = _bgm_normal
	_bgm_player.volume_db = -17.0
	add_child(_bgm_player)
	_bgm_player.play()


func set_bgm_mode(is_boss: bool):
	if _bgm_is_boss == is_boss or not is_instance_valid(_bgm_player):
		return
	_bgm_is_boss = is_boss
	_bgm_player.stream = _bgm_boss if is_boss else _bgm_normal
	_bgm_player.volume_db = -14.5 if is_boss else -17.0
	_bgm_player.play()


func resume_audio():
	if is_instance_valid(_bgm_player):
		_bgm_player.stream = _bgm_boss if _bgm_is_boss else _bgm_normal
		if not _bgm_player.playing:
			_bgm_player.play()
	play_sfx("dodge")


func _exit_tree():
	# Release active AudioStreamPlaybackWAV & AudioStreamWAV references on scene exit.
	for p in _players:
		if is_instance_valid(p):
			p.stop()
			p.stream = null
	if is_instance_valid(_bgm_player):
		_bgm_player.stop()
		_bgm_player.stream = null
	_bgm_normal = null
	_bgm_boss = null
	_players.clear()
	_streams.clear()


func play_sfx(key: String, pitch_jitter: float = 0.06):
	if not _streams.has(key):
		return
	var p := _players[_next_idx]
	_next_idx = (_next_idx + 1) % _players.size()
	p.stream = _streams[key]
	p.pitch_scale = randf_range(1.0 - pitch_jitter, 1.0 + pitch_jitter)
	p.play()


func _pack_wav(samples: PackedFloat32Array, loop: bool = false) -> AudioStreamWAV:
	var bytes := PackedByteArray()
	bytes.resize(samples.size() * 2)
	for i in range(samples.size()):
		var v := clampi(int(samples[i] * 32767.0), -32768, 32767)
		bytes[i * 2] = v & 0xFF
		bytes[i * 2 + 1] = (v >> 8) & 0xFF
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = MIX_RATE
	wav.stereo = false
	wav.data = bytes
	if loop:
		wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
		wav.loop_begin = 0
		wav.loop_end = samples.size()
	return wav


func _make_sweep(f0: float, f1: float, dur: float, amp: float, add_noise: bool) -> AudioStreamWAV:
	var n := int(MIX_RATE * dur)
	var buf := PackedFloat32Array()
	buf.resize(n)
	var phase := 0.0
	for i in range(n):
		var t := float(i) / float(n)
		var env := (1.0 - t) * (1.0 - t)
		var freq := lerpf(f0, f1, t)
		phase += TAU * freq / float(MIX_RATE)
		var sig := sin(phase)
		if add_noise:
			sig = sig * 0.6 + randf_range(-1.0, 1.0) * 0.4
		buf[i] = sig * env * amp
	return _pack_wav(buf)


func _make_chord(freqs: Array, dur: float, amp: float) -> AudioStreamWAV:
	var n := int(MIX_RATE * dur)
	var buf := PackedFloat32Array()
	buf.resize(n)
	var inv_cnt := 1.0 / float(maxi(1, freqs.size()))
	for i in range(n):
		var t := float(i) / float(n)
		var env := sin(minf(1.0, t * 12.0) * PI * 0.5) * pow(1.0 - t, 1.4)
		var sum := 0.0
		for f in freqs:
			sum += sin(TAU * float(f) * (float(i) / float(MIX_RATE)))
		buf[i] = sum * inv_cnt * env * amp
	return _pack_wav(buf)


func _make_ultimate_boom() -> AudioStreamWAV:
	var dur := 0.65
	var n := int(MIX_RATE * dur)
	var buf := PackedFloat32Array()
	buf.resize(n)
	var phase := 0.0
	for i in range(n):
		var t := float(i) / float(n)
		var env := pow(1.0 - t, 1.2)
		var freq := lerpf(240.0, 48.0, t)
		phase += TAU * freq / float(MIX_RATE)
		var sub := sin(phase) * 0.65
		var shimmer := sin(TAU * 880.0 * float(i) / float(MIX_RATE)) * 0.18 * (1.0 - t)
		var crackle := randf_range(-1.0, 1.0) * 0.25 * pow(1.0 - t, 2.0)
		buf[i] = (sub + shimmer + crackle) * env * 0.72
	return _pack_wav(buf)


func _make_xianxia_bgm_loop() -> AudioStreamWAV:
	var dur := 16.0
	var n := int(MIX_RATE * dur)
	var buf := PackedFloat32Array()
	buf.resize(n)
	var notes := [
		293.66, 349.23, 392.00, 440.00, 523.25, 440.00, 392.00, 349.23,
		293.66, 349.23, 440.00, 587.33, 523.25, 440.00, 392.00, 349.23,
		440.00, 523.25, 587.33, 659.25, 587.33, 523.25, 440.00, 392.00,
		349.23, 440.00, 523.25, 440.00, 392.00, 349.23, 329.63, 293.66,
	]
	var step_len := dur / float(notes.size())
	for i in range(n):
		var t_sec := float(i) / float(MIX_RATE)
		var idx := mini(notes.size() - 1, int(t_sec / step_len))
		var local_t := (t_sec - float(idx) * step_len) / step_len
		var env := sin(minf(1.0, local_t * 16.0) * PI * 0.5) * pow(1.0 - local_t, 1.5)
		var freq: float = notes[idx]
		var pluck := sin(TAU * freq * t_sec) * 0.65 + sin(TAU * freq * 2.0 * t_sec) * 0.22 + sin(TAU * freq * 3.0 * t_sec) * 0.08
		var drone_f := 146.83 if idx < 16 else 130.81
		var drone := sin(TAU * drone_f * t_sec) * 0.16
		buf[i] = (pluck * env + drone) * 0.34
	return _pack_wav(buf, true)


func _make_boss_bgm_loop() -> AudioStreamWAV:
	var dur := 8.0
	var n := int(MIX_RATE * dur)
	var buf := PackedFloat32Array()
	buf.resize(n)
	var notes := [
		220.00, 261.63, 293.66, 329.63, 392.00, 329.63, 293.66, 261.63,
		220.00, 293.66, 329.63, 440.00, 392.00, 329.63, 293.66, 246.94,
		220.00, 261.63, 329.63, 392.00, 440.00, 523.25, 440.00, 392.00,
		329.63, 293.66, 261.63, 293.66, 329.63, 261.63, 246.94, 220.00,
	]
	var step_len := dur / float(notes.size())
	for i in range(n):
		var t_sec := float(i) / float(MIX_RATE)
		var idx := mini(notes.size() - 1, int(t_sec / step_len))
		var local_t := (t_sec - float(idx) * step_len) / step_len
		var env := sin(minf(1.0, local_t * 18.0) * PI * 0.5) * pow(1.0 - local_t, 1.35)
		var freq: float = notes[idx]
		var lead := sin(TAU * freq * t_sec) * 0.55 + sin(TAU * freq * 2.0 * t_sec) * 0.25
		# Taiko-style low war drum pulse on every 2 steps
		var beat_t := fmod(t_sec, step_len * 2.0) / (step_len * 2.0)
		var drum_env := pow(maxf(0.0, 1.0 - beat_t * 2.2), 2.5)
		var drum := sin(TAU * lerpf(110.0, 52.0, minf(1.0, beat_t * 2.0)) * t_sec) * drum_env * 0.48
		buf[i] = clampf((lead * env + drum) * 0.38, -0.95, 0.95)
	return _pack_wav(buf, true)
