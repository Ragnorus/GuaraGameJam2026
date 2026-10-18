extends SceneTree

# Run: Godot --headless --path . --fixed-fps 60 --script res://tests/bichema_background.gd
func _initialize() -> void:
	_run.call_deferred()

func _frames(count: int) -> void:
	for i in range(count):
		await physics_frame
		await process_frame

func _clear(route: BichemaRoute, area: int) -> void:
	for enemy in route.room_enemies[area]:
		if is_instance_valid(enemy) and not enemy.dead:
			enemy.take_damage(10000)

func _check_view(stage: Node, expected_index: int) -> Rect2:
	var index: int = stage.get("bichema_background_index")
	assert(index == expected_index, "The active complete painting must follow the player")
	var room: Dictionary = stage.get("bichema_rooms")[index]
	var panorama := stage.get("bichema_background") as Sprite2D
	var texture_size := panorama.texture.get_size()
	assert(panorama.get_rect().size.is_equal_approx(texture_size), "Use the complete supplied painting")
	var painted: Rect2 = panorama.get_global_transform_with_canvas() * panorama.get_rect()
	var viewport := panorama.get_viewport().get_visible_rect()
	var backstop := stage.get_node("BichemaBackgroundBackstop") as Polygon2D
	var coverage := Rect2(backstop.polygon[0], backstop.polygon[2] - backstop.polygon[0])
	var world_view: Rect2 = panorama.get_viewport().get_canvas_transform().affine_inverse() * viewport
	assert(coverage.grow(1.1).encloses(world_view), "The route backstop must cover the viewport while adjacent paintings crossfade")
	assert(is_equal_approx(painted.size.x / painted.size.y, texture_size.x / texture_size.y), "Preserve source aspect ratio")
	var painted_ground := panorama.to_global(Vector2(0, float(room["ground"]))).y
	assert(absf(painted_ground - 600.0) < 1.1, "Every complete painting must meet the same route ground")
	return panorama.get_viewport().get_canvas_transform().affine_inverse() * viewport

func _set_view(stage: Node, area: int, x: float, y: float, expected_room: int) -> void:
	var route := stage.get("bichema_route") as BichemaRoute
	var player := stage.get("player") as Player
	route._set_area(area)
	player.position = Vector2(x, y)
	player.velocity = Vector2.ZERO
	await _frames(3)
	var left_view := _check_view(stage, expected_room)
	assert(left_view.position.x >= -1.1 and left_view.end.x <= route.AREAS[5].end.x + 1.1, "Camera stays within the continuous route")
	var room: Dictionary = stage.get("bichema_rooms")[expected_room]
	var end_x: float = (room["rect"] as Rect2).end.x - 40.0
	var end_area := 0
	for i in range(route.AREAS.size()):
		if end_x >= route.AREAS[i].position.x and end_x < route.AREAS[i].end.x:
			end_area = i
			break
	route._set_area(end_area)
	player.position = Vector2(end_x, 564.0)
	await _frames(3)
	var right_view := _check_view(stage, expected_room)
	assert(right_view.position.x >= -1.1 and right_view.end.x <= route.AREAS[5].end.x + 1.1)

func _jump_to(player: Player, target_x: float, double_jump := false) -> void:
	var direction := &"move_right" if target_x > player.position.x else &"move_left"
	Input.action_press(direction)
	Input.action_press(&"jump")
	await _frames(24)
	Input.action_release(&"jump")
	for i in range(160):
		if double_jump and i == 3:
			Input.action_press(&"jump")
		if i == 20:
			Input.action_release(&"jump")
		if absf(player.position.x - target_x) < 6.0:
			Input.action_release(direction)
		await _frames(1)
		if player.is_on_floor() and i > 15:
			break
	Input.action_release(direction)
	Input.action_release(&"jump")
	assert(not player.dead and player.is_on_floor(),
			"Jump toward %.1f ended at %.1f, %.1f (dead=%s)" % [target_x, player.position.x, player.position.y, str(player.dead)])

func _walk_to(player: Player, target_x: float) -> void:
	var direction := signf(target_x - player.position.x)
	var action: StringName = &"move_right" if direction > 0.0 else &"move_left"
	var limit := ceili(absf(target_x - player.position.x) / Player.SPEED * 60.0) + 120
	Input.action_press(action)
	for i in range(limit):
		await _frames(1)
		if (player.position.x - target_x) * direction >= 0.0:
			break
	Input.action_release(action)
	await _frames(2)
	assert(absf(player.position.x - target_x) <= Player.SPEED / 60.0 + 1.0,
			"Walk stopped at %.1f; expected %.1f" % [player.position.x, target_x])

func _feet_y(player: Player) -> float:
	return player.global_position.y + 36.0

func _check_jump(stage: Node, index: int) -> void:
	var player := stage.get("player") as Player
	var initial_feet := _feet_y(player)
	var highest_feet := initial_feet
	var camera_y := _check_view(stage, index).get_center().y
	for i in range(110):
		if i == 0 or i == 24:
			Input.action_press(&"jump")
		if i == 18 or i == 42:
			Input.action_release(&"jump")
		await _frames(1)
		highest_feet = minf(highest_feet, _feet_y(player))
		var view := _check_view(stage, index)
		assert(absf(view.get_center().y - camera_y) < 1.1, "Jumping and double-jumping must not pan beyond the full-height painting")
	assert(highest_feet < initial_feet - 100.0 and player.is_on_floor(), "Coverage must be exercised through an actual airborne jump and landing")

func _transition(route: BichemaRoute, player: Player, area: int, next_area: int, exit_x: float) -> void:
	var truck_start_x := route.truck.position.x if is_instance_valid(route.truck) else 0.0
	var health_before := player.health
	player.position = Vector2(exit_x, 564.0)
	route.update(0.0)
	assert(route.transitioning and player.controls_locked, "Area exits must use the locked fade transition")
	if next_area == 2:
		await _frames(80)
		assert(route.truck.visible and absf(route.truck.position.x - truck_start_x) > 1.0
				and route.truck.position.x > player.position.x + TacomaTruck.HALF_WIDTH,
				"The Tacoma must drive in without crossing the player's spawn")
		await _frames(130)
	else:
		await _frames(75)
	assert(route.area_index == next_area and not route.transitioning and not player.controls_locked)
	if next_area == 2:
		assert(route.tacoma_arrived and route.truck.visible
				and route.room_enemies[2].size() == 1 and route.room_enemies[2][0] == route.truck,
				"The Tacoma must stay in the pub as the single encounter")
		var truck_screen_x: float = route.truck.get_global_transform_with_canvas().origin.x
		var view: Rect2 = player.get_viewport().get_visible_rect()
		assert(truck_screen_x >= view.position.x + 24.0 and truck_screen_x <= view.end.x - 24.0,
				"The Tacoma must fit in camera")
		assert(player.health == health_before, "The drive-in and first warning must not cost player HP")

func _run() -> void:
	GameSettings.loaded = true
	GameSettings.music_on = false
	GameSettings.sfx_on = false
	assert(change_scene_to_file("res://scenes/bichema_level.tscn") == OK)
	await _frames(4)
	var stage := current_scene
	var player := stage.get("player") as Player
	var route := stage.get("bichema_route") as BichemaRoute
	for child in stage.get_children():
		if child is Pickup and child.kind == Pickup.Kind.MECHA:
			child.queue_free()
	player.health = 10000
	for enemy in get_nodes_in_group("enemies"):
		enemy.set_physics_process(false)
	await _frames(30)
	assert(route.AREAS.size() == 6 and YeralRoute.AREAS.size() == 6)
	for i in range(5):
		assert(route.AREAS[i].position.x == YeralRoute.AREAS[i].position.x
				and route.AREAS[i].size.x == YeralRoute.AREAS[i].size.x
				and route.AREAS[i].position.y == 0.0,
				"The route must keep Yeral's horizontal gates while staying on the painted Bichema map")
	assert(route.AREAS[5].end.x == YeralRoute.AREAS[5].end.x and route.AREAS[5].position.y == 0.0)
	var rooms: Array = stage.get("bichema_rooms")
	assert(rooms.size() == 4, "The route reuses the complete factory painting once to match stage length")
	for i in range(rooms.size()):
		var room: Dictionary = rooms[i]
		var texture: Texture2D = room["texture"]
		assert(texture.get_image().detect_alpha() == Image.ALPHA_NONE, "Keep the supplied paintings opaque and complete")
		if i > 0:
			assert(is_equal_approx((rooms[i - 1]["rect"] as Rect2).end.x, (room["rect"] as Rect2).position.x),
					"Complete room paintings must meet without gaps")
	assert((rooms[2]["texture"] as Texture2D).resource_path == (rooms[3]["texture"] as Texture2D).resource_path)
	assert(route.AREAS[5].end.x == YeralRoute.AREAS[5].end.x
			and stage.get("arena_right") == YeralRoute.AREAS[5].end.x,
			"Bichema's route and boss arena must match Yeral's 8320 px length")
	assert(route.room_enemies[2].size() == 1)
	var truck := route.truck
	assert(truck.health == GameSettings.scale_health(19))
	assert(not route.tacoma_arrived and not truck.visible,
			"The Tacoma and its riders must wait hidden until their entrance begins")

	var boss_trigger_x := float(stage.get("boss_trigger_x"))
	stage.set("boss_trigger_x", INF)
	await _set_view(stage, 0, 40.0, 564.0, 0)
	await _set_view(stage, 1, 2206.0, 564.0, 1)
	await _set_view(stage, 2, 4011.0, 564.0, 2)
	await _set_view(stage, 4, 6177.0, 564.0, 3)
	stage.set("boss_trigger_x", boss_trigger_x)

	route._set_area(0)
	player.position = Vector2(100.0, 564.0)
	player.velocity = Vector2.ZERO
	await _frames(3)
	player.position.x = 1200.0
	route.update(0.0)
	assert(route.area_index == 0 and not route.transitioning, "Live plaza guards must hold the first exit")
	_clear(route, 0)
	player.position = Vector2(100.0, 564.0)
	player.velocity = Vector2.ZERO
	await _frames(3)
	await _walk_to(player, 1100.0)
	assert(player.is_on_floor() and absf(player.position.y - 564.0) < 1.0,
			"The plaza route must follow its painted ground without an unexplained drop")
	await _transition(route, player, 0, 1, 1200.0)
	assert(player.is_on_floor() and absf(player.position.y - 564.0) < 1.0)

	player.position.x = 2480.0
	route.update(0.0)
	assert(route.area_index == 1 and not route.transitioning, "Live pub guards must hold the second exit")
	player.position = Vector2(1370.0, 564.0)
	player.velocity = Vector2.ZERO
	await _frames(2)
	_clear(route, 1)
	var pub_ledge: Rect2 = stage.get("bichema_rooms")[1]["platforms"][2]
	var pub_landing_x := pub_ledge.position.x + 4.0
	await _walk_to(player, 2300.0)
	await _jump_to(player, pub_landing_x, true)
	assert(absf(player.position.y + 36.0 - pub_ledge.position.y) < 2.0,
			"Keep the reachable painted pub ledge aligned to the level map")
	await _walk_to(player, 2300.0)
	assert(player.is_on_floor() and absf(player.position.y - 564.0) < 1.0)
	await _transition(route, player, 1, 2, 2480.0)
	assert(player.is_on_floor() and absf(player.position.y - 564.0) < 1.0)

	player.position = Vector2(4080.0, 564.0)
	route.update(0.0)
	assert(route.area_index == 2 and not route.transitioning, "Both Tacoma Bros must block the Sergeant-room exit")
	player.position = Vector2(3800.0, 564.0)
	player.velocity = Vector2.ZERO
	await _frames(2)
	_clear(route, 2)
	await _walk_to(player, 4000.0)
	assert(player.is_on_floor() and absf(player.position.y - 564.0) < 1.0,
			"The pub-to-factory path must remain supported across the map seam")
	await _transition(route, player, 2, 3, 4080.0)
	assert(player.is_on_floor() and absf(player.position.y - 564.0) < 1.0)

	var factory_ledge: Rect2 = stage.get("bichema_rooms")[2]["platforms"][1]
	var factory_landing_x := factory_ledge.position.x + 20.0
	await _jump_to(player, factory_landing_x, true)
	assert(absf(player.position.y + 36.0 - factory_ledge.position.y) < 2.0,
			"Use the factory's painted upper walkway instead of an arbitrary pit")
	await _walk_to(player, 5300.0)
	assert(player.is_on_floor() and absf(player.position.y - 564.0) < 1.0,
			"The factory's mapped ground must catch the player after the ledge")
	await _transition(route, player, 3, 4, 5360.0)
	assert(player.is_on_floor() and absf(player.position.y - 564.0) < 1.0)

	player.position.x = 6900.0
	route.update(0.0)
	assert(route.area_index == 4 and not route.transitioning, "The final factory guards must hold the last approach")
	_clear(route, 4)
	await _transition(route, player, 4, 5, 6900.0)
	assert(not stage.get("boss_started"),
			"Ema started before the final trigger: x=%.1f trigger=%.1f area=%d" % [player.position.x, stage.get("boss_trigger_x"), route.area_index])
	player.position.x = float(stage.get("boss_trigger_x")) + 1.0
	await _frames(3)
	var factory: Rect2 = rooms.back()["rect"]
	assert(stage.get("boss_started") and factory.position.x < stage.get("boss_trigger_x")
			and stage.get("boss_trigger_x") < factory.end.x)
	var boss: BossEvilGenius
	for enemy in get_nodes_in_group("enemies"):
		if enemy is BossEvilGenius:
			boss = enemy
	assert(boss != null and boss.global_position.x > float(stage.get("boss_trigger_x"))
			and boss.global_position.x < factory.end.x)
	print("PASS: complete paintings align to one safe ground path; six stage-one gates; Tacoma drive-in/ramming; real pub/factory ledges; final factory boss entry")
	stage.queue_free()
	GameAudio.stop_music()
	await create_timer(0.4).timeout
	await preload("res://tests/test_cleanup.gd").finish(self)
	quit()
