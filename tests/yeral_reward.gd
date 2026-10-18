extends SceneTree

func _initialize() -> void:
	_run.call_deferred()

func _frames(count: int) -> void:
	for i in range(count):
		await physics_frame
		await process_frame

func _start_reward() -> Node:
	assert(change_scene_to_file("res://scenes/main.tscn") == OK)
	await _frames(3)
	current_scene._on_boss_defeated()
	await _frames(2)
	return current_scene

func _toggle_pause() -> void:
	var event := InputEventAction.new()
	event.action = &"ui_cancel"
	event.pressed = true
	Input.parse_input_event(event)
	await _frames(2)
	event = InputEventAction.new()
	event.action = &"ui_cancel"
	event.pressed = false
	Input.parse_input_event(event)
	await _frames(1)

func _run() -> void:
	GameSettings.loaded = true
	GameSettings.music_on = false
	GameSettings.sfx_on = false
	GameSettings.dash_unlocked = false
	var stage := await _start_reward()
	var reward := stage.get("yeral_reward") as YeralReward
	var player := stage.get("player") as Player
	assert(reward != null and stage.get("finished") and player.controls_locked)
	assert(not GameSettings.dash_unlocked and not stage.get("ending_transition"))
	assert((stage.get("message_timer") as Timer).is_stopped(), "The old banner timer cannot interrupt the acquisition")
	assert(reward.hero.sprite_frames == Player.CHARACTER_FRAMES and reward.hero.animation == &"summon")
	assert(not reward.bubble.visible and reward.fade.color.a > 0.8)
	var hp := player.health
	var position := player.position
	player.take_damage(100)
	player._shoot()
	player._summon()
	Input.action_press("move_right")
	Input.action_press("jump")
	await _frames(30)
	Input.action_release("move_right")
	Input.action_release("jump")
	assert(player.health == hp and player.position == position)
	assert(get_nodes_in_group("player_shots").is_empty() and get_nodes_in_group("player_summons").is_empty())
	await _toggle_pause()
	assert(paused, "The pause action remains available during acquisition")
	var before := reward.elapsed
	await _frames(10)
	assert(reward.elapsed == before, "Acquisition must obey pause despite the frozen gameplay parent")
	await _toggle_pause()
	assert(not paused)
	while reward.elapsed < YeralReward.ABSORB_TIME + 0.1:
		await _frames(1)
	assert(current_scene == stage and reward.bubble.visible and reward.speaking)
	assert((reward.bubble.get_child(0) as Label).text == "Dime a vel!")
	assert(reward.hero.animation == &"recall" and reward.voice.playing)
	assert(reward.voice.stream == YeralReward.VOICE and reward.voice.bus == "SFX")
	assert(AudioServer.is_bus_mute(AudioServer.get_bus_index("SFX")))
	assert(reward.power.modulate.a > 0.5 and reward.fade.color.a == 0.0)
	var expected_duration := reward.duration()
	while reward.elapsed < expected_duration - 0.2:
		await _frames(1)
	assert(current_scene == stage and not GameSettings.dash_unlocked, "Wait for the complete line, even when muted")
	assert(reward.fade.color.a > 0.5)
	await _frames(30)
	assert(current_scene.scene_file_path == "res://scenes/bichema_level.tscn")
	assert(GameSettings.dash_unlocked and (current_scene.get("player") as Player).controls_locked == false)
	assert(not is_instance_valid(reward), "Stage handoff frees the portrait, effects and voice")

	GameSettings.sfx_on = true
	GameSettings.dash_unlocked = false
	stage = await _start_reward()
	reward = stage.get("yeral_reward") as YeralReward
	assert(is_equal_approx(reward.duration(), expected_duration), "Mute must not change cinematic timing")
	while not reward.speaking:
		await _frames(1)
	var voice := reward.voice
	(stage.get("player") as Player).die()
	await _frames(2)
	assert(reward.cancelled and not voice.playing and not reward.visible)
	await _frames(420)
	assert(current_scene == stage and not stage.get("ending_transition"), "Death cancels the pending stage handoff")
	assert(not GameSettings.dash_unlocked, "A cancelled acquisition cannot grant the reward")
	assert(reload_current_scene() == OK)
	await _frames(3)
	assert(not is_instance_valid(voice) and current_scene.get("yeral_reward") == null)

	stage = await _start_reward()
	reward = stage.get("yeral_reward") as YeralReward
	while not reward.speaking:
		await _frames(1)
	voice = reward.voice
	assert(reload_current_scene() == OK)
	await _frames(3)
	assert(not is_instance_valid(reward) and not is_instance_valid(voice), "Reload during speech must leave no audio behind")
	current_scene.free()
	GameAudio.stop_music()
	await _frames(3)
	print("YERAL REWARD OK: original sprite, energy phases, exact bubble/voice, locks, mute timing, pause, dash handoff, death and reload cleanup")
	quit()
