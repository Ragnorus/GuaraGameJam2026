extends SceneTree

func _initialize() -> void:
	_run.call_deferred()

func _frames(count: int) -> void:
	for i in range(count):
		await physics_frame
		await process_frame

func _clear(route: YeralRoute, area: int) -> void:
	for enemy in route.room_enemies[area]:
		if is_instance_valid(enemy) and not enemy.dead:
			enemy.take_damage(10000)

func _jump_to(player: Player, target_x: float, double_jump := false) -> void:
	var direction := &"move_right" if target_x > player.position.x else &"move_left"
	Input.action_press(direction)
	Input.action_press(&"jump")
	await _frames(16)
	Input.action_release(&"jump")
	for i in range(160):
		if double_jump and i == 3:
			Input.action_press(&"jump")
		if i > 3 and player.velocity.y >= 0.0:
			Input.action_release(&"jump")
		if absf(player.position.x - target_x) < 6.0:
			Input.action_release(direction)
		await _frames(1)
		if player.is_on_floor() and i > 5:
			break
	Input.action_release(direction)
	Input.action_release(&"jump")
	assert(not player.dead and player.is_on_floor(), "Jump to %s failed at %s hp %d" % [target_x, player.position, player.health])

func _run() -> void:
	GameSettings.loaded = true
	GameSettings.music_on = false
	GameSettings.sfx_on = false
	assert(change_scene_to_file("res://scenes/main.tscn") == OK)
	await _frames(3)
	var stage := current_scene
	var route := stage.get("yeral_route") as YeralRoute
	var player := stage.get("player") as Player
	assert(route != null and route.AREAS.size() == 6)
	assert(route.moving_blocks.size() == 2)
	for i in range(6):
		route._set_area(i)
		for j in range(6):
			assert(route.backgrounds[j].visible == (j == i), "Only the active area's scenery may be shown")
		var city_textures := 0
		for child in route.backgrounds[i].get_children():
			if child is Sprite2D and child.texture.resource_path.contains("city_bg"):
				city_textures += 1
		assert(city_textures > 0 if i in [0, 4] else city_textures == 0, "City art belongs only in Areas 1 and 5")
		if i == 5:
			var painting := route.backgrounds[i].get_child(0) as Sprite2D
			assert(painting.texture.resource_path == "res://assets/backgrounds/yeral/taco_bell_headquarters.png")
			assert(painting.texture_filter == CanvasItem.TEXTURE_FILTER_LINEAR)
			assert(is_equal_approx(painting.scale.x, painting.scale.y), "Boss painting preserves its proportions")
			var painted_size := painting.texture.get_size() * painting.scale
			assert(painted_size.x <= route.AREAS[i].size.x + 0.01 and painted_size.y <= route.AREAS[i].size.y + 0.01, "Whole painting fits without cropping")
			assert(painting.position.is_equal_approx((route.AREAS[i].size - painted_size) * 0.5), "Boss painting matches the centered approved preview")
		var screen := stage.get("camera") as Camera2D
		assert(screen.limit_top == int(route.AREAS[i].position.y))
		assert(screen.limit_bottom == int(route.AREAS[i].end.y))
	route._set_area(0)
	player.position = Vector2(100, 540)
	await _frames(60)
	assert(player.is_on_floor())
	# A living guard must prevent leaving the starting city.
	player.position.x = 1200
	await _frames(2)
	assert(route.area_index == 0 and not route.transitioning)
	for area in range(2):
		_clear(route, area)
		player.position.x = route.AREAS[area].end.x - 80
		player.player_sprite.hide()
		route.update(0.0)
		assert(player.player_sprite.visible and player.controls_locked, "Entering a cinematic must not preserve an invisible invulnerability blink")
		await _frames(85)
		assert(route.area_index == area + 1 and not route.transitioning)
		assert(not player.controls_locked)
	assert(route.area_index == 2 and is_instance_valid(route.sergeant))
	assert(route.sergeant.health == GameSettings.scale_health(12))
	# The three survival platforms are fixed StaticBody2Ds and identical between runs.
	var fixed_positions: Array[Vector2] = []
	var fixed_bodies: Array[StaticBody2D] = []
	for rect in route.SERGEANT_PLATFORMS:
		var found := false
		for node in stage.get_children():
			if node is StaticBody2D and not node is MovingPlatform and node.position.is_equal_approx(rect.get_center()):
				fixed_positions.append(node.position)
				fixed_bodies.append(node)
				found = true
		assert(found)
	_clear(route, 2)
	# Real jumps, not teleport-only checks: entrance -> fixed blocks -> far bank.
	player.position = Vector2(2680, 1284)
	player.velocity = Vector2.ZERO
	await _frames(3)
	await _jump_to(player, 2880.0, true)
	await _jump_to(player, 3240.0, true)
	await _jump_to(player, 3600.0, true)
	await _jump_to(player, 3980.0, true)
	assert(absf(player.position.y + 36.0 - 1200.0) < 2.0)
	player.position.x = route.AREAS[2].end.x - 80
	await _frames(85)
	assert(route.area_index == 3)
	_clear(route, 3)
	var moving := route.moving_blocks[0]
	player.position = Vector2(4250, 1284)
	player.velocity = Vector2.ZERO
	await _frames(4)
	moving.elapsed = 0.0
	await _frames(2)
	await _jump_to(player, 4560.0, true)
	assert(player.is_on_floor(), "Moving-block landing: player %s, block %s" % [player.position, moving.position])
	var before := player.position
	await _frames(35)
	assert(player.position.x > before.x + 20.0 and player.is_on_floor(), "Moving block must carry a standing player")
	assert(not moving.position.is_equal_approx(moving.start))
	await _jump_to(player, 4820.0, true)
	assert(absf(player.position.y + 36.0 - 1080.0) < 2.0, "The first moving block must connect to the middle rest ledge")
	var elevator := route.moving_blocks[1]
	for i in range(300):
		if elevator.position.y > 1090.0:
			break
		await _frames(1)
	await _jump_to(player, 5045.0, true)
	for i in range(300):
		if elevator.position.y < 960.0:
			break
		await _frames(1)
	await _jump_to(player, 5300.0, true)
	assert(absf(player.position.y + 36.0 - 850.0) < 2.0, "The moving elevator must lead to the upper sewer exit")
	assert(route.area_index == 3, "Climbing must not skip the city exit animation")
	# All landing/collider positions in the sergeant room remain unchanged while blocks move.
	for i in range(fixed_positions.size()):
		assert(fixed_bodies[i].position.is_equal_approx(fixed_positions[i]))
		assert(fixed_bodies[i].position.is_equal_approx(route.SERGEANT_PLATFORMS[i].get_center()))
	# A low exit approach must not bypass the ascent.
	player.position = Vector2(5350, 1284)
	route.update(0.0)
	assert(route.area_index == 3 and not route.transitioning)
	player.position = Vector2(5350, 814)
	route.update(0.0)
	assert(route.transitioning and player.controls_locked)
	await _frames(85)
	assert(route.area_index == 4 and not player.controls_locked)
	_clear(route, 4)
	player.position.x = route.AREAS[4].end.x - 80
	await _frames(80)
	assert(route.area_index == 5 and stage.get("boss_started"))
	assert(route.transitioning and player.controls_locked and route.speech.visible)
	assert(route.speech_label.text == route.INTRO_TEXT and route.voice.playing)
	var elapsed := route.cinematic.get_total_elapsed_time()
	paused = true
	await _frames(30)
	assert(is_equal_approx(route.cinematic.get_total_elapsed_time(), elapsed), "Pausing must freeze the introduction")
	paused = false
	assert(not route.boss.active and not route.boss.is_in_group("enemies"))
	var health := player.health
	var boss_health := route.boss.health
	route.boss.take_damage(999)
	player.take_damage(999)
	player._shoot()
	player._summon()
	player.meter = player.meter_max
	player._ultimate()
	assert(player.health == health and route.boss.health == boss_health)
	assert(get_nodes_in_group("player_summons").is_empty() and get_nodes_in_group("player_shots").is_empty())
	var position_before := player.position
	for action in [&"move_right", &"jump", &"dash", &"shoot", &"summon", &"recall", &"ultimate"]:
		Input.action_press(action)
	await _frames(20)
	for action in [&"move_right", &"jump", &"dash", &"shoot", &"summon", &"recall", &"ultimate"]:
		Input.action_release(action)
	assert(player.position.is_equal_approx(position_before), "All controls must be locked during the boss introduction")
	await _frames(340)
	assert(route.intro_complete and route.boss.active and not player.controls_locked and not route.speech.visible)
	assert(route.boss.is_in_group("enemies"))
	print("PASS: ordered five-area route, exclusive city/sewer scenery, fixed acid-platform jumps, moving-block carry, raised sewer exit, locked warehouse intro/audio and boss activation")
	# Acid kills even during damage invulnerability and with high health.
	route._set_area(2)
	player.health = 1000
	player.invuln = 20.0
	player.position = Vector2(3060, 1350)
	route.update(0.0)
	assert(player.dead and player.health == 0)
	print("PASS: green acid is lethal, including during invulnerability")
	assert(change_scene_to_file("res://scenes/main.tscn") == OK)
	await _frames(3)
	stage = current_scene
	route = stage.get("yeral_route") as YeralRoute
	player = stage.get("player") as Player
	route._set_area(5)
	player.position = Vector2(7160, 564)
	route.start_boss_intro()
	player.die()
	assert(not route.voice.playing and not route.speech.visible)
	await _frames(350)
	assert(not route.boss.active and player.dead, "Death must cancel delayed boss activation")
	YeralRoute.checkpoint = 0
	Input.action_press(&"restart")
	await _frames(1)
	Input.action_release(&"restart")
	await _frames(3)
	assert(current_scene != stage)
	route = current_scene.get("yeral_route") as YeralRoute
	assert(route.area_index == 0 and not route.voice.playing and not route.transitioning)
	print("PASS: death cancels intro activation/audio; restart resets the route and cinematic")
	current_scene.free()
	await _frames(3)
	await preload("res://tests/test_cleanup.gd").finish(self)
	quit()
