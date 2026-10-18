class_name GameAudio
extends RefCounted

# Recorded menu music and procedural gameplay music/effects use the settings buses.

const RATE := 22050
const MENU_MUSIC := preload("res://assets/audio/lord_of_the_night.mp3")

static var _cache := {}
static var _music: AudioStreamPlayer
static var _buses_ready := false
static var _menu_music := false

static func apply() -> void:
	for bus in ["Music", "SFX"]:
		if AudioServer.get_bus_index(bus) == -1:
			AudioServer.add_bus()
			var created := AudioServer.bus_count - 1
			AudioServer.set_bus_name(created, bus)
			AudioServer.set_bus_send(created, "Master")
	_set_bus("Music", GameSettings.music_on, GameSettings.music_volume)
	_set_bus("SFX", GameSettings.sfx_on, GameSettings.sfx_volume)
	_buses_ready = true

static func _set_bus(bus: String, on: bool, volume: float) -> void:
	var i := AudioServer.get_bus_index(bus)
	AudioServer.set_bus_mute(i, not on or volume <= 0.001)
	AudioServer.set_bus_volume_db(i, linear_to_db(maxf(volume, 0.001)))

static func start_music(tree: SceneTree, menu := false) -> void:
	if is_instance_valid(_music) and _menu_music == menu:
		return
	stop_music()
	if not _buses_ready:
		apply()
	_menu_music = menu
	_music = AudioStreamPlayer.new()
	if menu:
		var recording := MENU_MUSIC.duplicate() as AudioStreamMP3
		recording.loop = true
		_music.stream = recording
	else:
		_music.stream = _music_stream()
	_music.bus = "Music"
	_music.playback_type = AudioServer.PLAYBACK_TYPE_STREAM
	_music.volume_db = 0.0 if menu else -8.0
	_music.process_mode = Node.PROCESS_MODE_ALWAYS
	_music.autoplay = true
	tree.root.add_child.call_deferred(_music)

static func stop_music() -> void:
	if is_instance_valid(_music):
		_music.autoplay = false
		_music.stop()
		_music.stream = null
		_music.queue_free()
	_music = null

# kind: click, kill, hurt or boss
static func play(tree: SceneTree, kind: String) -> void:
	if tree == null:
		return
	if not _buses_ready:
		apply()
	var player := AudioStreamPlayer.new()
	player.stream = _sfx_stream(kind)
	player.bus = "SFX"
	player.playback_type = AudioServer.PLAYBACK_TYPE_STREAM
	player.process_mode = Node.PROCESS_MODE_ALWAYS
	player.autoplay = true
	player.finished.connect(player.queue_free)
	tree.root.add_child.call_deferred(player)

static func _sfx_stream(kind: String) -> AudioStreamWAV:
	if not _cache.has(kind):
		match kind:
			"kill":
				_cache[kind] = _tone(500.0, 1100.0, 0.12, 0.5)
			"hurt":
				_cache[kind] = _tone(220.0, 90.0, 0.18, 0.6)
			"boss":
				_cache[kind] = _tone(900.0, 100.0, 0.7, 0.6)
			"squeak":
				_cache[kind] = _tone(1900.0, 700.0, 0.12, 0.45)
			_:
				_cache[kind] = _tone(900.0, 900.0, 0.04, 0.4)
	return _cache[kind]

static func _wav(samples: PackedFloat32Array, looped := false) -> AudioStreamWAV:
	var data := PackedByteArray()
	data.resize(samples.size() * 2)
	for i in range(samples.size()):
		data.encode_s16(i * 2, int(clampf(samples[i], -1.0, 1.0) * 32767.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = RATE
	wav.stereo = false
	wav.data = data
	if looped:
		wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
		wav.loop_begin = 0
		wav.loop_end = samples.size()
	return wav

# Square-wave blip sweeping from f0 to f1 with a short attack and a linear fade-out.
static func _tone(f0: float, f1: float, duration: float, volume: float) -> AudioStreamWAV:
	var n := int(RATE * duration)
	var samples := PackedFloat32Array()
	samples.resize(n)
	var phase := 0.0
	for i in range(n):
		var k := float(i) / n
		phase += lerpf(f0, f1, k) / RATE
		var s := 1.0 if fmod(phase, 1.0) < 0.5 else -1.0
		samples[i] = s * volume * (1.0 - k) * minf(1.0, i / 40.0)
	return _wav(samples)

# Four-chord (Am F C G) arpeggio over a square bass, looped. Semitone offsets are relative to A3 (220 Hz).
# Oscillator phases run continuously and each note has a short attack so notes do not click.
@warning_ignore("integer_division")
static func _music_stream() -> AudioStreamWAV:
	var chords := [[0, 3, 7], [-4, 0, 3], [3, 7, 10], [-2, 2, 5]]
	var step_len := int(RATE * 0.2)
	var steps_per_chord := 8
	var steps := steps_per_chord * chords.size()
	var samples := PackedFloat32Array()
	samples.resize(step_len * steps)
	var lead_phase := 0.0
	var bass_phase := 0.0
	for step in range(steps):
		var chord: Array = chords[step / steps_per_chord]
		var lead_freq := 220.0 * pow(2.0, (int(chord[step % 3]) + 12) / 12.0)
		var bass_freq := 220.0 * pow(2.0, (int(chord[0]) - 12) / 12.0)
		for j in range(step_len):
			lead_phase = fmod(lead_phase + lead_freq / RATE, 1.0)
			bass_phase = fmod(bass_phase + bass_freq / RATE, 1.0)
			var local := float(j) / step_len
			var attack := minf(1.0, j / 60.0)
			var lead := (1.0 if lead_phase < 0.5 else -1.0) * 0.2 * (1.0 - local * 0.85) * attack
			var bass := (1.0 if bass_phase < 0.5 else -1.0) * 0.14
			samples[step * step_len + j] = lead + bass
	return _wav(samples, true)
