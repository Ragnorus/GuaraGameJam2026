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
	assert(ProjectSettings.get_setting("application/config/name") == "El Señor De La Noche")
	assert(StoryIntro.STORY.begins_with("BANSHEE: THE MOVIE IS OVER"))
	assert(StoryIntro.STORY.contains('"El Señor de la Noche."'))
	assert(not StoryIntro.STORY.to_lower().contains("night unc"))
	var menu := load("res://scenes/main_menu.tscn").instantiate() as Control
	root.add_child(menu)
	current_scene = menu
	await _frames(2)
	var menu_music := GameAudio._music
	var recording := menu_music.stream as AudioStreamMP3
	assert(recording != null and recording.data == GameAudio.MENU_MUSIC.data)
	assert(GameAudio.MENU_MUSIC.resource_path == "res://assets/audio/lord_of_the_night.mp3")
	assert(recording.loop and not GameAudio.MENU_MUSIC.loop, "Menu loops a private copy of the supplied Lord of the Night recording")
	assert(menu_music.playing and menu_music.bus == "Music")
	assert(AudioServer.is_bus_mute(AudioServer.get_bus_index("Music")))
	GameAudio.start_music(self, true)
	assert(GameAudio._music == menu_music, "Repeated menu visits must preserve one music player")
	GameSettings.score = 42
	GameSettings.level_start_score = 20
	menu._start_game()
	await _frames(3)
	assert(current_scene is StoryIntro, "Start Game must open the story, not the level")
	assert(not is_instance_valid(menu_music), "The story replaces the menu song without overlap")
	var story_music := GameAudio._music
	var story_recording := story_music.stream as AudioStreamMP3
	assert(story_recording != null and story_recording.data == GameAudio.STORY_MUSIC.data)
	assert(story_recording.loop and not GameAudio.STORY_MUSIC.loop, "Story loops a private orchestral recording")
	assert(story_music.playing and story_music.bus == &"Music")
	assert(AudioServer.is_bus_mute(AudioServer.get_bus_index("Music")), "Story respects Music mute")
	GameAudio.start_music(self)
	assert(GameAudio._music == story_music, "Repeated story requests preserve playback")
	if DisplayServer.get_name() != "headless":
		await _capture_story()
	assert(GameSettings.score == 0 and GameSettings.level_start_score == 0)
	assert(get_nodes_in_group("enemies").is_empty(), "Gameplay must not run behind the intro")
	var intro := current_scene as StoryIntro
	assert(intro.crawl_height > 2000.0, "The full story must be laid out, not clipped")
	var story_label := intro.get_child(0).get_child(0) as Label
	assert(story_label.text == StoryIntro.STORY, "Render the supplied story without the previous title or lore")
	assert(intro.STORY.contains("Emanuel Vega") and intro.STORY.contains("El Bichotema"))
	assert(intro.STORY.contains("La Metrocity") and intro.STORY.replace("\r", "").contains("\n\nBANSHEE.\n\n"))
	assert(not intro.STORY.contains("Penema") and not intro.STORY.contains("The Super Intelligence"))
	assert(intro.STORY.ends_with("Every movie must eventually end, and when the lights come on, everyone must face reality."))
	var before := intro.scroll_position
	intro._process(1.0)
	assert(is_equal_approx(intro.scroll_position - before, StoryIntro.SCROLL_SPEED))
	assert(is_equal_approx(float(intro.crawl_material.get_shader_parameter("scroll_position")), intro.scroll_position))
	intro.size = Vector2(1920.0, 1080.0)
	await _frames(2)
	assert(intro.skip_button.get_global_rect().end.x <= intro.size.x)
	assert(intro.skip_button.get_global_rect().end.y <= intro.size.y)
	for key in [KEY_ENTER, KEY_SPACE, KEY_ESCAPE]:
		var probe := _new_intro()
		var event := InputEventKey.new()
		event.keycode = key
		event.pressed = true
		probe._unhandled_input(event)
		assert(probe.finishing, "Keyboard skip must work")
		probe.free()
	for button in [JOY_BUTTON_A, JOY_BUTTON_B]:
		var controller_intro := _new_intro()
		var controller := InputEventJoypadButton.new()
		controller.button_index = button
		controller.pressed = true
		controller_intro._unhandled_input(controller)
		assert(controller_intro.finishing, "Controller accept/cancel must skip")
		controller_intro.free()
	var button_intro := _new_intro()
	button_intro.skip_button.pressed.emit()
	assert(button_intro.finishing, "The visible skip button must work")
	button_intro.free()
	intro.scroll_position = intro.crawl_height + StoryIntro.HORIZON_DISTANCE
	intro._process(0.0)
	assert(intro.finishing, "The crawl must finish automatically after its last line")
	intro._finish()
	var timer := create_timer(0.8)
	await timer.timeout
	await _frames(3)
	assert(current_scene.scene_file_path == StoryIntro.NEXT_SCENE, "Completion must open Yeral's stage")
	assert(not is_instance_valid(story_music) and GameAudio._music_level == 1, "Completion releases story music and starts Level 1 music")
	assert(GameSettings.score == 0)
	# A second Start Game must replay the intro, regardless of title_seen.
	MenuKit.go(current_scene, "res://scenes/main_menu.tscn")
	await _frames(3)
	current_scene._start_game()
	await _frames(3)
	assert(current_scene is StoryIntro)
	var skipped := current_scene as StoryIntro
	skipped.skip_button.pressed.emit()
	await create_timer(0.8).timeout
	await _frames(3)
	assert(current_scene.scene_file_path == StoryIntro.NEXT_SCENE)
	assert(GameAudio._music_level == 1, "Skipping replaces story music with Level 1 music")
	MenuKit.go(current_scene, "res://scenes/level_select.tscn")
	await _frames(3)
	current_scene._open_level(StoryIntro.NEXT_SCENE)
	await _frames(3)
	assert(current_scene.scene_file_path == StoryIntro.NEXT_SCENE, "Level Select must bypass the crawl")
	current_scene.queue_free()
	GameAudio.stop_music()
	await create_timer(0.3).timeout
	print("PASS: full story layout, scrolling, resize, keyboard/controller/button skip, automatic completion, replay and level-select bypass")
	await preload("res://tests/test_cleanup.gd").finish(self)
	quit()

func _new_intro() -> StoryIntro:
	var intro := preload("res://scenes/story_intro.tscn").instantiate() as StoryIntro
	root.add_child(intro)
	return intro

func _capture_story() -> void:
	var capture := AudioEffectCapture.new()
	var bus := AudioServer.get_bus_index("Master")
	var index := AudioServer.get_bus_effect_count(bus)
	AudioServer.add_bus_effect(bus, capture)
	GameSettings.music_on = true
	GameSettings.music_volume = 0.35
	GameAudio.apply()
	assert(is_equal_approx(db_to_linear(AudioServer.get_bus_volume_db(AudioServer.get_bus_index("Music"))), 0.35))
	GameAudio._music.seek(15.0)
	await create_timer(0.6).timeout
	assert(_peak(capture) > 0.0001, "Story recording produces actual mixer output")
	GameAudio._music.seek(GameAudio._music.stream.get_length() - 0.15)
	await create_timer(0.5).timeout
	assert(GameAudio._music.playing and GameAudio._music.get_playback_position() < 2.0, "Story music loops if needed")
	GameSettings.music_on = false
	GameAudio.apply()
	await create_timer(0.3).timeout
	capture.clear_buffer()
	await create_timer(0.3).timeout
	assert(_peak(capture) == 0.0, "Music mute silences actual story output")
	AudioServer.remove_bus_effect(bus, index)
	print("STORY MUSIC OUTPUT OK: audible recording, loop wrap, volume and mute")

func _peak(capture: AudioEffectCapture) -> float:
	var peak := 0.0
	for sample in capture.get_buffer(capture.get_frames_available()):
		peak = maxf(peak, maxf(absf(sample.x), absf(sample.y)))
	return peak
