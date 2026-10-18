extends SceneTree

func _initialize() -> void:
	_run.call_deferred()

func _frames(count: int) -> void:
	for i in range(count):
		await physics_frame
		await process_frame

func _audio(actor: Node) -> MeleeAudio:
	return actor.get_node_or_null("MeleeAudio") as MeleeAudio

func _run() -> void:
	GameSettings.loaded = true
	GameSettings.difficulty = 1
	GameSettings.music_on = false
	GameSettings.sfx_on = false
	var arena := Node2D.new()
	root.add_child(arena)
	current_scene = arena
	var player := Player.new()
	arena.add_child(player)
	player.set_physics_process(false)
	player.health = 100
	player.position = Vector2(50, 0)
	var robot := Robot.new()
	robot.target = player
	arena.add_child(robot)
	robot.set_physics_process(false)
	player.invuln = 1.0
	robot._touch_damage()
	assert(_audio(robot) == null, "Invulnerable contact cannot trigger impact sounds")
	player.invuln = 0.0
	robot._touch_damage()
	assert(_audio(robot).playing and player.health == 99)
	assert(player.knockback_time > 0.0, "Melee audio preserves the existing default hit recoil")
	var active := _audio(robot)
	MeleeAudio.strike(robot, player)
	assert(_audio(robot) == active, "Reuse one audio player rather than accumulating per-frame nodes")
	assert(active.bus == &"SFX" and active.max_distance == MeleeAudio.RANGE)
	active.stop()
	player.invuln = 1.0
	robot._touch_damage()
	assert(not active.playing, "Rejected contact cannot restart the sound")
	var sergeant := Sergeant.new()
	sergeant.target = player
	arena.add_child(sergeant)
	sergeant.set_physics_process(false)
	player.position = Vector2(300, 0)
	for rage in [false, true]:
		sergeant.raged = rage
		sergeant.start_punch()
		sergeant.sprite.speed_scale = 0.0
		sergeant.sprite.frame = Sergeant.FRAMES.get_frame_count(sergeant.sprite.animation) - 2
		sergeant._update_punch()
		assert(_audio(sergeant).playing, "Normal and rage punches sound even when they miss")
		assert(sergeant.melee_started)
		_audio(sergeant).stop()
		sergeant._update_punch()
		assert(not _audio(sergeant).playing, "Punch sounds once at its active frame, not each physics tick")
	var yeral := BossYeral.new()
	yeral.target = player
	arena.add_child(yeral)
	yeral.set_physics_process(false)
	yeral.set_process(false)
	yeral.active = true
	for glizzy in [false, true]:
		yeral.glizzy = glizzy
		yeral._execute("charge")
		assert(_audio(yeral).playing)
		assert(_audio(yeral).stream == (MeleeAudio.ANIMAL if glizzy else MeleeAudio.STRIKE))
		_audio(yeral).stop()
	yeral.dying = true
	yeral._execute("charge")
	assert(not _audio(yeral).playing, "Dead bosses cannot start new melee cues")
	var ema := BossEvilGenius.new()
	ema.target = player
	arena.add_child(ema)
	ema.set_physics_process(false)
	ema.active = true
	for costume in [false, true]:
		ema.costume_form = costume
		ema.charge_windup = 0.01
		ema._physics_process(0.02)
		assert(_audio(ema).playing, "Both Ema forms play charge audio at the end of the tell")
		_audio(ema).stop()
	var flyer := WingedMob.new()
	flyer.target = player
	arena.add_child(flyer)
	flyer.set_physics_process(false)
	flyer.state = "warn"
	flyer.state_time = 0.0
	flyer._physics_process(0.01)
	assert(_audio(flyer).playing and _audio(flyer).stream == MeleeAudio.ANIMAL)
	var hopper := Hopper.new()
	hopper.target = player
	arena.add_child(hopper)
	hopper.set_physics_process(false)
	hopper.windup = 0.01
	hopper._physics_process(0.02)
	assert(_audio(hopper).playing and _audio(hopper).stream == MeleeAudio.ANIMAL)
	var truck := TacomaTruck.new()
	truck.target = player
	arena.add_child(truck)
	truck.set_physics_process(false)
	truck.drive_state = TacomaTruck.DriveState.WINDUP
	truck.state_time = 0.01
	truck._physics_process(0.02)
	assert(_audio(truck).playing, "The Tacoma ram is a melee attack")
	var source := Node2D.new()
	arena.add_child(source)
	player.controls_locked = true
	MeleeAudio.strike(source, player)
	assert(_audio(source) == null, "Cinematics cannot trigger new melee cues")
	player.controls_locked = false
	source.process_mode = Node.PROCESS_MODE_DISABLED
	MeleeAudio.strike(source, player)
	assert(_audio(source) == null, "Inactive rooms cannot trigger melee cues")
	source.process_mode = Node.PROCESS_MODE_INHERIT
	source.hide()
	MeleeAudio.strike(source, player)
	assert(_audio(source) == null, "Hidden actors stay silent")
	source.show()
	if DisplayServer.get_name() != "headless":
		# Isolate the supplied recording from preceding combat and procedural hit SFX.
		for child in arena.get_children():
			if child != source and child != player:
				child.queue_free()
		await create_timer(0.4).timeout
		await _check_output(source, player)
	arena.queue_free()
	await _frames(3)
	assert(not is_instance_valid(active), "Scene exit frees actor-owned melee playback")
	GameAudio.stop_music()
	await create_timer(0.3).timeout
	print("MELEE AUDIO OK: mob contact, invulnerability/recoil, punch/miss/rage, boss forms, swoop/hop/ram, guards and cleanup")
	await preload("res://tests/test_cleanup.gd").finish(self)
	quit()

func _check_output(source: Node2D, player: Player) -> void:
	var camera := Camera2D.new()
	source.add_child(camera)
	camera.make_current()
	await _frames(3)
	var capture := AudioEffectCapture.new()
	var master := AudioServer.get_bus_index("Master")
	var slot := AudioServer.get_bus_effect_count(master)
	AudioServer.add_bus_effect(master, capture)
	for muted in [false, true]:
		GameSettings.sfx_on = not muted
		GameAudio.apply()
		capture.clear_buffer()
		MeleeAudio.strike(source, player)
		await create_timer(0.25).timeout
		var samples := capture.get_buffer(capture.get_frames_available())
		assert(not samples.is_empty())
		var peak := 0.0
		for sample in samples:
			peak = maxf(peak, maxf(absf(sample.x), absf(sample.y)))
		assert(peak < 0.00001 if muted else peak > 0.0001, "Melee recordings respect SFX mute")
		print("MELEE AUDIO OUTPUT: muted=%s peak=%f" % [muted, peak])
		if not muted:
			paused = true
			await create_timer(0.1).timeout
			var position := _audio(source).get_playback_position()
			await create_timer(0.15).timeout
			assert(absf(_audio(source).get_playback_position() - position) < 0.03)
			paused = false
		_audio(source).stop()
		await create_timer(0.15).timeout
	AudioServer.remove_bus_effect(master, slot)
