extends SceneTree

func _initialize() -> void:
	_run.call_deferred()

func _frames(count: int) -> void:
	for i in range(count):
		await physics_frame
		await process_frame

func _jump_to(player: Player, rect: Rect2) -> void:
	var action := &"move_right" if rect.get_center().x > player.position.x else &"move_left"
	if absf(player.position.x - rect.get_center().x) > 8.0:
		Input.action_press(action)
	Input.action_press(&"jump")
	await _frames(24)
	Input.action_release(&"jump")
	await _frames(1)
	Input.action_press(&"jump")
	await _frames(2)
	Input.action_release(&"jump")
	for frame in range(150):
		if absf(player.position.x - rect.get_center().x) < 8.0:
			Input.action_release(action)
		await _frames(1)
		if player.is_on_floor():
			break
	Input.action_release(action)
	assert(player.is_on_floor() and absf(player.position.y + 36.0 - rect.position.y) < 2.0
			and player.position.x >= rect.position.x and player.position.x <= rect.end.x,
			"Real jump must land on Ema's platform %s; player at %s" % [rect, player.position])
	assert(player.health == player.max_health, "The platform route must clear Ema without contact damage")

func _run() -> void:
	GameSettings.loaded = true
	GameSettings.difficulty = 1
	GameSettings.music_on = false
	GameSettings.sfx_on = false
	assert(change_scene_to_file("res://scenes/bichema_level.tscn") == OK)
	await _frames(4)
	var stage := current_scene
	var player := stage.player as Player
	stage.bichema_route._set_area(5)
	player.position = Vector2(stage.boss_trigger_x + 20.0, 564.0)
	await _frames(4)
	var boss: BossEvilGenius
	for enemy in get_nodes_in_group("enemies"):
		if enemy is BossEvilGenius:
			boss = enemy
	assert(boss != null and boss.active)
	boss.position.x = BichemaRoute.AREAS[5].get_center().x
	boss.attack_cd = 1000.0
	for form in range(2):
		for direction in [1, -1]:
			var order := [0, 1, 2] if direction == 1 else [2, 1, 0]
			var first: Rect2 = YeralRoute.BOSS_PLATFORMS[order[0]]
			player.position = Vector2(first.get_center().x, 564.0)
			player.velocity = Vector2.ZERO
			player.health = player.max_health
			player.invuln = 0.0
			player.clear_status()
			await _frames(4)
			for index in order:
				await _jump_to(player, YeralRoute.BOSS_PLATFORMS[index])
			# The same real double jump must also clear the body from the safe floor.
			player.position = Vector2(boss.position.x - direction * 210.0, 564.0)
			player.velocity = Vector2.ZERO
			await _frames(4)
			var move := &"move_right" if direction == 1 else &"move_left"
			Input.action_press(move)
			Input.action_press(&"jump")
			await _frames(20)
			Input.action_release(&"jump")
			await _frames(1)
			Input.action_press(&"jump")
			await _frames(79)
			Input.action_release(&"jump")
			Input.action_release(move)
			assert((player.position.x - boss.position.x) * direction > 150.0
					and player.health == player.max_health,
					"The actual arena must leave room to double-jump over either Ema form in both directions")
		if form == 0:
			boss.take_damage(boss.health)
			for frame in range(240):
				await _frames(1)
				if not boss.transforming:
					break
			assert(boss.costume_form and not boss.transforming)
			boss.attack_cd = 1000.0
	stage.queue_free()
	await _frames(4)
	GameAudio.stop_music()
	await create_timer(0.1).timeout
	print("EMA BOSS ROOM OK: three reachable platforms matching Yeral, both-direction platform traversal and clean floor double-jumps over both boss forms")
	quit()
