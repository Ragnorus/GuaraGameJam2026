extends SceneTree

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	GameSettings.loaded = true
	GameSettings.music_on = false
	GameSettings.sfx_on = false
	assert(change_scene_to_file("res://scenes/bichema_level.tscn") == OK)
	await physics_frame
	await process_frame
	await physics_frame
	await process_frame
	var stage := current_scene
	var route := stage.get("bichema_route") as BichemaRoute
	var player := stage.get("player") as Player
	var rooms: Array = stage.get("bichema_rooms")
	var panels: Array = stage.get("bichema_background_sprites")
	var blends: Array = stage.get("bichema_background_blends")
	var bleeds: Array = stage.get("bichema_background_bleeds")
	var backstop := stage.get_node("BichemaBackgroundBackstop") as Polygon2D
	assert(rooms.size() == 4 and panels.size() == rooms.size() and blends.size() == 3)
	assert(is_equal_approx(backstop.polygon[1].x, route.AREAS[5].end.x)
			and backstop.polygon[2].y >= 720.0,
			"The dark backstop must cover the entire route behind the art")
	var vertical_top: float = (rooms[0]["rect"] as Rect2).position.y
	var vertical_bottom: float = (rooms[0]["rect"] as Rect2).end.y
	for room in rooms:
		var rect: Rect2 = room["rect"]
		vertical_top = minf(vertical_top, rect.position.y)
		vertical_bottom = maxf(vertical_bottom, rect.end.y)
	for room in rooms:
		var rect: Rect2 = room["rect"]
		var top_covered := rect.position.y - vertical_top <= 0.5
		var bottom_covered := vertical_bottom - rect.end.y <= 0.5
		for bleed in bleeds:
			var edge := bleed as Sprite2D
			if edge.texture != room["texture"] or not edge.region_enabled:
				continue
			if not is_equal_approx(edge.position.x, rect.position.x):
				continue
			var edge_height := edge.region_rect.size.y * edge.scale.y
			top_covered = top_covered or (
				is_equal_approx(edge.position.y, vertical_top)
				and is_equal_approx(edge_height, rect.position.y - vertical_top))
			bottom_covered = bottom_covered or (
				is_equal_approx(edge.position.y, rect.end.y)
				and is_equal_approx(edge_height, vertical_bottom - rect.end.y))
		assert(top_covered and bottom_covered,
				"Every painting's vertical gaps must be filled with its own edge pixels")
	for i in range(rooms.size()):
		var room: Dictionary = rooms[i]
		var panel := panels[i] as Sprite2D
		var rect: Rect2 = room["rect"]
		assert(panel.visible and panel.texture == room["texture"]
				and panel.position.is_equal_approx(rect.position)
				and is_equal_approx(panel.scale.x, float(room["scale"]))
				and (room["texture"] as Texture2D).get_image().detect_alpha() == Image.ALPHA_NONE,
				"Keep every complete opaque painting visible at its mapped scale")
		if i > 0:
			assert(is_equal_approx((rooms[i - 1]["rect"] as Rect2).end.x, rect.position.x),
					"Adjacent paintings must meet without a gray gap")

	for next_room in range(1, rooms.size()):
		var boundary: float = (rooms[next_room]["rect"] as Rect2).position.x
		var left_rect: Rect2 = rooms[next_room - 1]["rect"]
		var right_rect: Rect2 = rooms[next_room]["rect"]
		var blend := blends[next_room - 1] as ColorRect
		var area := 0
		for i in range(route.AREAS.size()):
			if boundary >= route.AREAS[i].position.x and boundary < route.AREAS[i].end.x:
				area = i
				break
		assert(blend.visible and blend.material is ShaderMaterial
				and is_equal_approx(blend.position.x + blend.size.x / 2.0, boundary),
				"Every painting join needs an aligned spatial crossfade")
		route._set_area(area)
		player.position = Vector2(boundary - blend.size.x / 2.0, 564.0)
		player.velocity = Vector2.ZERO
		stage._update_bichema_background()
		assert(stage.get("bichema_background_index") == next_room - 1
				and stage.camera.limit_top == roundi(left_rect.position.y),
				"The camera starts at the previous painting's framing")
		player.position.x = boundary
		stage._update_bichema_background()
		var expected_middle := roundi(lerpf(left_rect.position.y, right_rect.position.y, 0.5))
		assert(stage.camera.limit_top == expected_middle,
				"The camera framing must blend across the join")
		player.position.x = boundary + blend.size.x / 2.0
		stage._update_bichema_background()
		assert(stage.get("bichema_background_index") == next_room
				and stage.camera.limit_top == roundi(right_rect.position.y)
				and not player.controls_locked,
				"The next painting and camera framing must be settled past the join")
		for panel in panels:
			assert((panel as Sprite2D).visible, "Neighboring paintings stay drawn through the crossfade")

	stage.queue_free()
	await process_frame
	print("PASS: Bichema paintings cover the route and crossfade smoothly at every join")
	await preload("res://tests/test_cleanup.gd").finish(self)
	quit()
