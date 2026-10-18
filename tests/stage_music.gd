extends SceneTree

func _initialize() -> void:
	_run.call_deferred()

func _frames(count: int) -> void:
	for i in range(count):
		await process_frame

func _run() -> void:
	GameSettings.loaded = true
	GameSettings.music_on = false
	GameSettings.sfx_on = false
	for stage_path in ["res://scenes/main.tscn", "res://scenes/bichema_level.tscn"]:
		assert(change_scene_to_file(stage_path) == OK)
		await _frames(4)
		var level := 2 if current_scene.bichema_level else 1
		assert(GameAudio._music_level == level and GameAudio._music.playing)
		var original := GameAudio._music
		GameAudio.start_music(self, false, level)
		assert(GameAudio._music == original, "Same-level requests preserve playback")
		if level == 1:
			var stream := GameAudio._music.stream as AudioStreamOggVorbis
			assert(stream != null and stream.loop and not GameAudio.LEVEL1_MUSIC.loop)
			assert(stream.get_length() > 30.0)
		else:
			var stream := GameAudio._music.stream as AudioStreamWAV
			assert(stream != null and stream.data == GameAudio.LEVEL2_MUSIC.data)
			assert(stream.loop_mode == AudioStreamWAV.LOOP_FORWARD and stream.loop_end > 0)
			assert(GameAudio.LEVEL2_MUSIC.loop_mode == AudioStreamWAV.LOOP_DISABLED)
			var truck := current_scene.bichema_route.truck as TacomaTruck
			truck._stop_music()
			assert(GameAudio._music_level == 2)
		assert(AudioServer.is_bus_mute(AudioServer.get_bus_index("Music")))
		GameSettings.music_on = true
		GameSettings.music_volume = 0.35
		GameAudio.apply()
		assert(not AudioServer.is_bus_mute(AudioServer.get_bus_index("Music")) and GameAudio._music.bus == &"Music")
		if DisplayServer.get_name() != "headless":
			await _capture_loop()
		GameSettings.music_on = false
		GameAudio.apply()
	assert(change_scene_to_file("res://scenes/story_intro.tscn") == OK)
	await _frames(4)
	assert(GameAudio._music_level == 0 and (GameAudio._music.stream as AudioStreamMP3).data == GameAudio.STORY_MUSIC.data)
	assert(change_scene_to_file("res://scenes/main_menu.tscn") == OK)
	await _frames(4)
	assert(GameAudio._menu_music and (GameAudio._music.stream as AudioStreamMP3).data == GameAudio.MENU_MUSIC.data)
	current_scene.queue_free()
	GameAudio.stop_music()
	await create_timer(0.4).timeout
	print("STAGE MUSIC OK: actual level routing, private loops, same-track reuse, Tacoma restore, Music settings, story and menu isolation")
	quit()

func _capture_loop() -> void:
	var capture := AudioEffectCapture.new()
	var bus := AudioServer.get_bus_index("Music")
	var index := AudioServer.get_bus_effect_count(bus)
	AudioServer.add_bus_effect(bus, capture)
	GameAudio._music.seek(GameAudio._music.stream.get_length() - 0.15)
	await create_timer(0.4).timeout
	assert(GameAudio._music.playing and GameAudio._music.get_playback_position() < 2.0, "Recorded stage music wraps at its end")
	var samples := capture.get_buffer(capture.get_frames_available())
	var peak := 0.0
	for sample in samples:
		peak = maxf(peak, maxf(absf(sample.x), absf(sample.y)))
	assert(peak > 0.0001, "Selected music produces actual mixer output")
	print("STAGE MUSIC OUTPUT: level=%d peak=%f" % [GameAudio._music_level, peak])
	AudioServer.remove_bus_effect(bus, index)
