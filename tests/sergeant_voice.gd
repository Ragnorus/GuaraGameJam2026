extends SceneTree

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	GameSettings.loaded = true
	GameSettings.music_on = false
	GameSettings.sfx_on = false
	var arena := Node2D.new()
	root.add_child(arena)
	current_scene = arena
	var player := Player.new()
	arena.add_child(player)
	player.set_physics_process(false)
	player.position = Vector2(300, 0)
	var actor := Sergeant.new()
	actor.target = player
	actor.platforms = [Rect2(-500, 64, 1000, 20)]
	actor.platform_index = 0
	arena.add_child(actor)
	actor.set_physics_process(false)
	var voice := actor.voice
	assert(voice.bus == &"SFX" and voice.max_distance == SergeantVoice.RANGE)
	actor.start_punch()
	assert(not voice.playing, "Punch waits for its active frame")
	actor.sprite.frame = Sergeant.FRAMES.get_frame_count(actor.sprite.animation) - 2
	actor._update_punch()
	assert(voice.playing and voice.stream in SergeantVoice.GRUNTS)
	voice.stop()
	actor._update_punch()
	assert(not voice.playing, "One voice cue per punch")
	actor.start_charge()
	actor.state_time = 0.1
	actor._update_charge(0.0)
	assert(not voice.playing, "Charge waits for windup")
	actor.state_time = 0.5
	actor._update_charge(0.0)
	assert(voice.playing and voice.stream in SergeantVoice.GRUNTS)
	actor.start_scream()
	assert(voice.playing and voice.stream == SergeantVoice.SCREAM)
	actor._start_transform()
	assert(voice.stream == SergeantVoice.RAGE, "Rage overrides the prior cry")
	voice.stop()
	actor._set_state(Sergeant.State.IDLE, &"idle")
	actor.raged = true
	actor.take_damage(1)
	assert(voice.playing and voice.stream in SergeantVoice.GRUNTS)
	voice.stop()
	for blocked in [&"hidden", &"locked", &"dead", &"far", &"disabled"]:
		actor.visible = blocked != &"hidden"
		player.controls_locked = blocked == &"locked"
		player.dead = blocked == &"dead"
		player.position.x = 2000.0 if blocked == &"far" else 300.0
		actor.process_mode = Node.PROCESS_MODE_DISABLED if blocked == &"disabled" else Node.PROCESS_MODE_INHERIT
		voice.cue(&"attack")
		assert(not voice.playing, "Suppressed voice: %s" % blocked)
	actor.process_mode = Node.PROCESS_MODE_INHERIT
	player.position = Vector2(300, 0)
	voice.cue(&"scream")
	paused = true
	await create_timer(0.15).timeout
	var before := voice.get_playback_position()
	await create_timer(0.15).timeout
	assert(absf(voice.get_playback_position() - before) < 0.02, "Pause freezes voice playback")
	paused = false
	player.dead = true
	await process_frame
	await process_frame
	assert(not voice.playing, "Player death stops an ongoing cry")
	player.dead = false
	if DisplayServer.get_name() != "headless":
		await _capture(voice)
	actor.take_damage(999)
	assert(voice.playing and voice.stream == SergeantVoice.DEATH and voice.defeated)
	voice.stop()
	voice.cue(&"attack")
	assert(not voice.playing, "Defeated Sergeant cannot start new cries")
	arena.queue_free()
	await create_timer(0.4).timeout
	assert(not is_instance_valid(voice), "Scene exit frees the voice")
	print("SERGEANT VOICE OK: attack timing, scream/rage/pain/death, guards, pause, cleanup and SFX settings")
	quit()

func _capture(voice: SergeantVoice) -> void:
	await create_timer(0.4).timeout
	var capture := AudioEffectCapture.new()
	var bus := AudioServer.get_bus_index("Master")
	var index := AudioServer.get_bus_effect_count(bus)
	AudioServer.add_bus_effect(bus, capture)
	GameSettings.sfx_on = true
	GameAudio.apply()
	voice.cue(&"rage")
	await create_timer(0.6).timeout
	assert(_peak(capture) > 0.0001, "Sergeant voice produces mixer output")
	GameSettings.sfx_on = false
	GameAudio.apply()
	await create_timer(0.3).timeout
	capture.clear_buffer()
	await create_timer(0.3).timeout
	assert(_peak(capture) == 0.0, "SFX mute silences the voice")
	voice.stop()
	AudioServer.remove_bus_effect(bus, index)
	print("SERGEANT VOICE OUTPUT OK: audible unmuted, silent muted")

func _peak(capture: AudioEffectCapture) -> float:
	var peak := 0.0
	for sample in capture.get_buffer(capture.get_frames_available()):
		peak = maxf(peak, maxf(absf(sample.x), absf(sample.y)))
	return peak
