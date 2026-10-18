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
	assert(not is_instance_valid(menu_music) and GameAudio._music.stream is AudioStreamWAV, "The story restores gameplay music without overlapping the menu song")
	assert(GameSettings.score == 0 and GameSettings.level_start_score == 0)
	assert(get_nodes_in_group("enemies").is_empty(), "Gameplay must not run behind the intro")
	var intro := current_scene as StoryIntro
	assert(intro.crawl_height > 2000.0, "The full story must be laid out, not clipped")
	assert(intro.STORY.contains("Laravel 13^3+"))
	assert(intro.STORY.contains("ARAM God") and intro.STORY.contains("Penema"))
	assert(intro.STORY.ends_with("the erection of a monument to his new rule."))
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
	MenuKit.go(current_scene, "res://scenes/level_select.tscn")
	await _frames(3)
	current_scene._open_level(StoryIntro.NEXT_SCENE)
	await _frames(3)
	assert(current_scene.scene_file_path == StoryIntro.NEXT_SCENE, "Level Select must bypass the crawl")
	print("PASS: full story layout, scrolling, resize, keyboard/controller/button skip, automatic completion, replay and level-select bypass")
	quit()

func _new_intro() -> StoryIntro:
	var intro := preload("res://scenes/story_intro.tscn").instantiate() as StoryIntro
	root.add_child(intro)
	return intro
