extends SceneTree

func _initialize() -> void:
	_run.call_deferred()

func _frames(count: int) -> void:
	for i in range(count):
		await physics_frame
		await process_frame

func _run() -> void:
	GameSettings.loaded = true
	GameSettings.music_on = true
	GameSettings.sfx_on = true
	GameSettings.music_volume = 0.7
	GameSettings.sfx_volume = 0.7
	YeralRoute.checkpoint = 0
	assert(change_scene_to_file("res://scenes/main.tscn") == OK)
	await _frames(4)
	var stage := current_scene
	var route := stage.yeral_route as YeralRoute
	var player := stage.player as Player
	stage.set_process(false)
	route._set_area(5)
	player.position = Vector2(7160, 564)
	await _frames(3)
	var music := GameAudio._music
	var normal_volume := music.volume_db
	route.start_boss_intro()
	assert(route.voice.playing and route.voice.bus == &"SFX")
	assert(is_equal_approx(music.volume_db, normal_volume - YeralRoute.INTRO_MUSIC_DUCK_DB))
	if DisplayServer.get_name() != "headless":
		await _capture_voice(route)
	while not route.intro_complete:
		await _frames(1)
	assert(is_equal_approx(music.volume_db, normal_volume), "Music restores after the opening line")
	route.boss.set_physics_process(false)
	route.boss.active = false
	player.invuln = 1000.0
	for rect in YeralRoute.BOSS_PLATFORMS:
		var found := false
		for node in stage.get_children():
			if node is StaticBody2D and node.position.is_equal_approx(rect.get_center()):
				assert(node.collision_layer == stage.PLATFORM_LAYER)
				assert((node.get_child(0) as CollisionShape2D).one_way_collision)
				found = true
		assert(found, "Each boss platform has a one-way collider")
	# Real jump chain: floor -> left -> raised center -> right.
	player.position = Vector2(YeralRoute.BOSS_PLATFORMS[0].get_center().x, 564)
	player.velocity = Vector2.ZERO
	await _frames(4)
	for index in range(3):
		var rect := YeralRoute.BOSS_PLATFORMS[index]
		var action := &"move_right"
		if index > 0:
			Input.action_press(action)
		Input.action_press(&"jump")
		await _frames(24)
		Input.action_release(&"jump")
		await _frames(1)
		Input.action_press(&"jump")
		await _frames(2)
		Input.action_release(&"jump")
		for frame in range(150):
			if index > 0 and absf(player.position.x - rect.get_center().x) < 8.0:
				Input.action_release(action)
			await _frames(1)
			if player.is_on_floor():
				break
		Input.action_release(action)
		assert(player.is_on_floor() and absf(player.position.y + 36.0 - rect.position.y) < 2.0, "Real jump lands on boss platform %d at %s" % [index, player.position])
	# Cancel/death and scene exit must restore the music as well.
	route._duck_intro_music()
	route.cancel_intro()
	assert(is_equal_approx(music.volume_db, normal_volume))
	route._duck_intro_music()
	player.die()
	assert(not route.voice.playing and is_equal_approx(music.volume_db, normal_volume))
	route._duck_intro_music()
	stage.queue_free()
	await _frames(3)
	assert(is_equal_approx(music.volume_db, normal_volume))
	GameAudio.stop_music()
	await create_timer(0.4).timeout
	print("YERAL BOSS ROOM OK: intro music duck/restore, recorded voice, three real platform jumps, safe floor, one-way collision and cleanup")
	quit()

func _capture_voice(route: YeralRoute) -> void:
	var capture := AudioEffectCapture.new()
	var bus := AudioServer.get_bus_index("Master")
	var index := AudioServer.get_bus_effect_count(bus)
	AudioServer.add_bus_effect(bus, capture)
	GameSettings.music_on = false
	GameAudio.apply()
	await create_timer(0.8).timeout
	assert(_peak(capture) > 0.001, "Yeral's intro produces actual SFX mixer output")
	GameSettings.sfx_on = false
	GameAudio.apply()
	await create_timer(0.2).timeout
	capture.clear_buffer()
	await create_timer(0.3).timeout
	assert(_peak(capture) == 0.0, "Saved SFX mute remains respected")
	GameSettings.sfx_on = true
	GameAudio.apply()
	AudioServer.remove_bus_effect(bus, index)
	assert(route.voice.playing, "Mute does not shorten the cinematic recording")
	print("YERAL INTRO OUTPUT OK: actual recording output and mute")

func _peak(capture: AudioEffectCapture) -> float:
	var peak := 0.0
	for sample in capture.get_buffer(capture.get_frames_available()):
		peak = maxf(peak, maxf(absf(sample.x), absf(sample.y)))
	return peak
