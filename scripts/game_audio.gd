class_name GameAudio
extends RefCounted

# Procedurally generated chiptune music loop and sound effects (no audio files needed),
# routed through "Music" and "SFX" buses that the settings menu controls.

const RATE := 11025

static var _cache := {}
static var _music: AudioStreamPlayer
static var _buses_ready := false

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

static func start_music(tree: SceneTree) -> void:
	if is_instance_valid(_music):
		return
	if not _buses_ready:
		apply()
	_music = AudioStreamPlayer.new()
	_music.stream = _music_stream()
	_music.bus = "Music"
	_music.volume_db = -8.0
	_music.process_mode = Node.PROCESS_MODE_ALWAYS
	_music.autoplay = true
	tree.root.add_child.call_deferred(_music)

# kind: click, kill, hurt or boss
static func play(tree: SceneTree, kind: String) -> void:
	if tree == null:
		return
	if not _buses_ready:
		apply()
	var player := AudioStreamPlayer.new()
	player.stream = _sfx_stream(kind)
	player.bus = "SFX"
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
			_:
				_cache[kind] = _tone(900.0, 900.0, 0.04, 0.4)
	return _cache[kind]

static func _wav(data: PackedByteArray, looped := false) -> AudioStreamWAV:
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_8_BITS
	wav.mix_rate = RATE
	wav.stereo = false
	wav.data = data
	if looped:
		wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
		wav.loop_begin = 0
		wav.loop_end = data.size()
	return wav

# Square-wave blip sweeping from f0 to f1 with a linear fade-out. 8-bit samples are signed.
static func _tone(f0: float, f1: float, duration: float, volume: float) -> AudioStreamWAV:
	var n := int(RATE * duration)
	var data := PackedByteArray()
	data.resize(n)
	var phase := 0.0
	for i in range(n):
		var k := float(i) / n
		phase += lerpf(f0, f1, k) / RATE
		var s := 1.0 if fmod(phase, 1.0) < 0.5 else -1.0
		data[i] = int(clampf(s * volume * (1.0 - k), -1.0, 1.0) * 127.0) & 0xFF
	return _wav(data)

# Four-chord (Am F C G) arpeggio over a square bass, looped. Semitone offsets are relative to A3 (220 Hz).
@warning_ignore("integer_division")
static func _music_stream() -> AudioStreamWAV:
	var chords := [[0, 3, 7], [-4, 0, 3], [3, 7, 10], [-2, 2, 5]]
	var step_len := int(RATE * 0.2)
	var steps_per_chord := 8
	var total := step_len * steps_per_chord * chords.size()
	var data := PackedByteArray()
	data.resize(total)
	for i in range(total):
		var step := i / step_len
		var local := float(i % step_len) / step_len
		var chord: Array = chords[(step / steps_per_chord) % chords.size()]
		var lead_freq := 220.0 * pow(2.0, (int(chord[step % 3]) + 12) / 12.0)
		var bass_freq := 220.0 * pow(2.0, (int(chord[0]) - 12) / 12.0)
		var lead := 1.0 if fmod((i % step_len) / float(RATE) * lead_freq, 1.0) < 0.5 else -1.0
		var bass := 1.0 if fmod(i / float(RATE) * bass_freq, 1.0) < 0.5 else -1.0
		var s := 0.22 * lead * (1.0 - local * 0.85) + 0.18 * bass
		data[i] = int(clampf(s, -1.0, 1.0) * 127.0) & 0xFF
	return _wav(data, true)
