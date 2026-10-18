extends SceneTree

class Target:
	extends Node2D
	var dead := false

func _initialize() -> void:
	_run.call_deferred()

func _frames(count: int) -> void:
	for i in range(count):
		await physics_frame
		await process_frame

func _run() -> void:
	GameSettings.loaded = true
	GameSettings.difficulty = 1
	GameSettings.music_on = false
	GameSettings.sfx_on = false
	var arena := Node2D.new()
	root.add_child(arena)
	current_scene = arena
	var target := Target.new()
	arena.add_child(target)
	for script in [Bug, Robot, Hopper, TruffleAndroid, WingedMob, Turret]:
		var mob = script.new()
		mob.target = target
		arena.add_child(mob)
		mob.set_physics_process(false)
		var voice: MobVoice = mob.voice
		assert(voice.bus == &"SFX" and voice.max_distance == MobVoice.RANGE)
		voice.cue(&"attack", target)
		assert(voice.playing and MobVoice.GRUNTS.has(voice.stream), "Attack uses supplied grunts")
		var first := voice.stream
		voice.cue(&"attack", target)
		assert(voice.stream == first, "An active voice cannot pile up new grunts")
		voice.stop()
		mob.health = 3
		mob.take_damage(1)
		assert(voice.playing and MobVoice.PAIN.has(voice.stream), "Every mob damage override plays pain")
		voice.stop()
		mob.process_mode = Node.PROCESS_MODE_DISABLED
		voice.cue(&"attack", target)
		assert(not voice.playing, "Inactive rooms cannot start mob voices")
		mob.process_mode = Node.PROCESS_MODE_INHERIT
		mob.hide()
		voice.cue(&"attack", target)
		assert(not voice.playing, "Hidden enemies stay silent")
		mob.show()
		target.position.x = MobVoice.RANGE + 1.0
		voice.cue(&"attack", target)
		assert(not voice.playing, "Distant enemies stay silent")
		target.position.x = 0.0
		target.dead = true
		voice.cue(&"hurt", target)
		assert(not voice.playing, "A dead player cannot trigger new cries")
		target.dead = false
		mob.take_damage(999)
		assert(voice.defeated and voice.playing and MobVoice.DEATH.has(voice.stream))
		assert(voice.get_parent() == arena, "Death audio survives corpse removal within the level")
		var death_clip := voice.stream
		voice.cue(&"attack", target)
		assert(voice.stream == death_clip, "Death rejects queued attack cues")
		paused = true
		await _frames(2)
		assert(not voice.can_process(), "Death tails inherit gameplay pause")
		paused = false
		if is_instance_valid(mob):
			mob.queue_free()
		await _frames(2)
		assert(is_instance_valid(voice), "Short corpse lifetimes must not cut off death audio")
		voice.finished.emit()
		await _frames(2)
		assert(not is_instance_valid(voice), "Finished death voices free themselves")
	GameSettings.sfx_on = true
	GameSettings.sfx_volume = 0.4
	GameAudio.apply()
	var bus := AudioServer.get_bus_index("SFX")
	assert(not AudioServer.is_bus_mute(bus))
	assert(is_equal_approx(db_to_linear(AudioServer.get_bus_volume_db(bus)), 0.4))
	GameSettings.sfx_on = false
	GameAudio.apply()
	assert(AudioServer.is_bus_mute(bus))
	var truck := TacomaTruck.new()
	truck.target = target
	arena.add_child(truck)
	truck.voice.cue(&"attack", target)
	assert(not truck.voice.playing, "The Tacoma mini-boss retains its own audio")
	var survivor := Robot.new()
	survivor.target = target
	arena.add_child(survivor)
	survivor.set_physics_process(false)
	var tail := survivor.voice
	survivor.take_damage(999)
	arena.queue_free()
	await _frames(3)
	assert(not is_instance_valid(tail), "Scene exit frees detached death voices")
	GameAudio.stop_music()
	await create_timer(0.3).timeout
	if DisplayServer.get_name() != "headless":
		await _check_output()
	print("MOB AUDIO OK: all mob damage/death paths, spatial limits, inactive/dead guards, pause, SFX controls and cleanup")
	quit()

func _check_output() -> void:
	var arena := Node2D.new()
	root.add_child(arena)
	var target := Target.new()
	arena.add_child(target)
	var mob := Robot.new()
	mob.target = target
	arena.add_child(mob)
	mob.set_physics_process(false)
	var camera := Camera2D.new()
	arena.add_child(camera)
	camera.make_current()
	await _frames(3)
	var capture := AudioEffectCapture.new()
	var master := AudioServer.get_bus_index("Master")
	var slot := AudioServer.get_bus_effect_count(master)
	AudioServer.add_bus_effect(master, capture)
	for muted in [false, true]:
		GameSettings.sfx_on = not muted
		GameAudio.apply()
		mob.voice.stop()
		capture.clear_buffer()
		mob.voice.cue(&"attack", target)
		await create_timer(0.25).timeout
		var samples := capture.get_buffer(capture.get_frames_available())
		assert(not samples.is_empty(), "The audio mixer must supply real samples")
		var peak := 0.0
		for sample in samples:
			peak = maxf(peak, maxf(absf(sample.x), absf(sample.y)))
		assert(peak < 0.00001 if muted else peak > 0.0001, "Mob audio must be audible only when SFX is enabled")
		print("MOB AUDIO OUTPUT: muted=%s peak=%f" % [muted, peak])
		if not muted:
			paused = true
			await create_timer(0.1).timeout
			var position := mob.voice.get_playback_position()
			capture.clear_buffer()
			await create_timer(0.15).timeout
			var paused_samples := capture.get_buffer(capture.get_frames_available())
			var paused_peak := 0.0
			for sample in paused_samples:
				paused_peak = maxf(paused_peak, maxf(absf(sample.x), absf(sample.y)))
			assert(paused_peak < 0.00001, "Gameplay pause must silence mob voices")
			assert(absf(mob.voice.get_playback_position() - position) < 0.03, "Pause freezes the clip instead of silently consuming it")
			paused = false
		mob.voice.stop()
		await create_timer(0.15).timeout
	AudioServer.remove_bus_effect(master, slot)
	arena.queue_free()
	await create_timer(0.3).timeout
