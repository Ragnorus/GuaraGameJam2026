extends SceneTree

func _initialize() -> void:
	_run.call_deferred()

func _frames(count: int) -> void:
	for i in range(count):
		await physics_frame
		await process_frame

func _run() -> void:
	GameSettings.loaded = true
	GameSettings.music_on = false
	GameSettings.sfx_on = false
	GameAudio.start_music(self)
	await _frames(2)
	var previous_music := GameAudio._music
	assert(change_scene_to_file("res://scenes/end_credits.tscn") == OK)
	await _frames(3)
	var credits := current_scene as EndCredits
	assert(credits != null and credits.song.playing)
	assert(not is_instance_valid(previous_music), "Credits replace the gameplay music, never layer over it")
	assert(credits.song.stream == EndCredits.MUSIC and credits.song.bus == "Music")
	assert(credits.song.stream.get_length() >= EndCredits.TOTAL_DURATION, "The supplied song covers the whole sequence")
	assert(AudioServer.is_bus_mute(AudioServer.get_bus_index("Music")), "The song respects music mute")
	GameSettings.music_on = true
	GameSettings.music_volume = 0.35
	GameAudio.apply()
	assert(not AudioServer.is_bus_mute(AudioServer.get_bus_index("Music")))
	assert(is_equal_approx(db_to_linear(AudioServer.get_bus_volume_db(AudioServer.get_bus_index("Music"))), 0.35))
	GameSettings.music_on = false
	GameAudio.apply()
	assert(credits.opening.text == "To Be Continued....." and credits.opening.visible)
	assert(credits.opening.size.y < credits.size.y * 0.5, "Opening text fits on screen rather than wrapping offscreen")
	assert(credits.roll.size.y < credits.size.y * 1.5, "Team roll fits its intended readable height")
	assert(not credits.roll.visible and not credits.closing.visible)
	assert(credits.roll.get_child_count() == 7)
	assert((credits.roll.get_child(0) as Label).text == "Team members:")
	for i in range(EndCredits.MEMBERS.size()):
		assert((credits.roll.get_child(i + 1) as Label).text == EndCredits.MEMBERS[i])
		assert((credits.roll.get_child(i + 1) as Label).horizontal_alignment == HORIZONTAL_ALIGNMENT_CENTER)
	credits.rng.seed = 2026
	for i in range(12):
		credits._spawn_cameo()
	await _frames(2)
	for child in credits.cameos.get_children():
		var sprite := child as AnimatedSprite2D
		assert(EndCredits.CAST.has(sprite.sprite_frames) and sprite.animation == &"idle")
		assert(sprite.position.x < credits.size.x * 0.22 or sprite.position.x > credits.size.x * 0.78, "Sprites stay out of the centered text column")
		assert(sprite.scale.x > 0 and sprite.modulate.a > 0)
	paused = true
	var before := credits.elapsed
	await process_frame
	await process_frame
	assert(credits.elapsed == before, "Credits obey SceneTree pause")
	paused = false
	while credits.elapsed < EndCredits.INTRO_DURATION + 0.5:
		await _frames(1)
	assert(not credits.opening.visible and credits.roll.visible)
	var roll_y := credits.roll.position.y
	await _frames(60)
	assert(credits.roll.position.y < roll_y, "Credits scroll upward")
	root.size = Vector2i(960, 540)
	await _frames(3)
	assert(is_equal_approx(credits.roll.position.x + credits.roll.size.x / 2.0, credits.size.x / 2.0), "Roll stays centered on resize")
	root.size = Vector2i(1280, 720)
	while credits.elapsed < EndCredits.INTRO_DURATION + EndCredits.ROLL_DURATION + 2.0:
		await _frames(1)
	assert(credits.closing.visible and credits.closing.text == "Guaras Game Jam 2026")
	assert(not credits.roll.visible and credits.cameos.get_child_count() == 0, "Cameos leave before the final title")
	while credits.elapsed < EndCredits.TOTAL_DURATION - 0.5:
		await _frames(1)
	assert(credits.fade.color.a > 0.5 and credits.song.volume_db < -8.0, "Picture and music fade out together")
	await _frames(60)
	assert(current_scene.scene_file_path == "res://scenes/main_menu.tscn", "The complete sequence returns to the main menu")
	assert(GameAudio._music != null and is_instance_valid(GameAudio._music), "Menu music resumes")
	var menu_recording := GameAudio._music.stream as AudioStreamMP3
	assert(menu_recording != null and menu_recording.data == GameAudio.MENU_MUSIC.data)
	assert(EndCredits.MUSIC.resource_path == "res://assets/audio/seal_kiss_from_a_rose.mp3")
	assert(menu_recording.data != EndCredits.MUSIC.data, "Menu and credits must use their separate songs")
	assert(menu_recording.loop and not EndCredits.MUSIC.loop, "Returning to the menu loops its own copy without changing credits")
	menu_recording = null
	# Re-entering credits must not leave a second song or stale scene running.
	assert(change_scene_to_file("res://scenes/end_credits.tscn") == OK)
	await _frames(3)
	credits = current_scene as EndCredits
	assert(credits.elapsed < 1.0 and credits.song.playing and GameAudio._music == null)
	credits._finish()
	await _frames(3)
	assert(current_scene.scene_file_path == "res://scenes/main_menu.tscn")
	current_scene.free()
	GameAudio.stop_music()
	await _frames(5)
	print("END CREDITS OK: exact text/order, centered roll, random cast gutters, supplied music/settings, fades, replay and menu return")
	quit()
