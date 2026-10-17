extends SceneTree

# Run: Godot --headless --path . --fixed-fps 60 --script res://tests/bichema_background.gd
var _floor_y := 0.0

func _initialize() -> void:
	_run.call_deferred()

func _frames(count: int) -> void:
	for i in range(count):
		await physics_frame
		await process_frame

func _feet_y(player: Player) -> float:
	for child in player.get_children():
		if child is CollisionShape2D and not child.disabled:
			return child.to_global(child.shape.get_rect().end).y
	assert(false, "The player must have a physical foot position")
	return 0.0

func _check_view(stage: Node, expected_index: int = -1) -> Rect2:
	var index: int = stage.get("bichema_background_index")
	if expected_index >= 0:
		assert(index == expected_index, "Crossing a room boundary must show that room's painting")
	var room: Dictionary = stage.get("bichema_rooms")[index]
	var panorama := stage.get("bichema_background") as Sprite2D
	var texture_size := panorama.texture.get_size()
	assert(panorama.get_rect().size.is_equal_approx(texture_size), "The complete painting must remain visible, not a cropped region")
	var painted: Rect2 = panorama.get_global_transform_with_canvas() * panorama.get_rect()
	var viewport := panorama.get_viewport().get_visible_rect()
	assert(painted.grow(1.1).encloses(viewport), "Actual camera viewport must be entirely covered by the painting, without blank or filler bands")
	assert(is_equal_approx(painted.size.x / painted.size.y, texture_size.x / texture_size.y), "The painting must retain its original aspect ratio")
	var painted_ground := panorama.to_global(panorama.get_rect().position + Vector2(0.0, float(room["ground"]))).y
	assert(absf(painted_ground - _floor_y) < 1.1, "The painted ground must stay aligned with the actual walking floor")
	return panorama.get_viewport().get_canvas_transform().affine_inverse() * viewport

func _check_image_edge(stage: Node, left: bool) -> void:
	var panorama := stage.get("bichema_background") as Sprite2D
	var painted: Rect2 = panorama.get_global_transform_with_canvas() * panorama.get_rect()
	var viewport := panorama.get_viewport().get_visible_rect()
	var edge := painted.position.x - viewport.position.x if left else painted.end.x - viewport.end.x
	assert(absf(edge) < 2.1, "The actual painting's outer edge must reach the screen so no source details remain cropped away")

func _walk_to(stage: Node, x: float) -> void:
	var player := stage.get("player") as Player
	var direction := signf(x - player.global_position.x)
	var action: StringName = &"move_right" if direction > 0.0 else &"move_left"
	var frame_limit := ceili(absf(x - player.global_position.x) / Player.SPEED * 60.0) + 120
	Input.action_press(action)
	for i in range(frame_limit):
		await _frames(1)
		_check_view(stage)
		for enemy in get_nodes_in_group("enemies"):
			if enemy is BossEvilGenius:
				enemy.set_physics_process(false)
		if (player.global_position.x - x) * direction >= 0.0:
			break
	Input.action_release(action)
	await _frames(2)
	assert(absf(player.global_position.x - x) <= Player.SPEED / 60.0 + 1.0, "Walking target %.2f, actual %.2f, velocity %s, room %d" % [x, player.global_position.x, player.velocity, stage.get("bichema_background_index")])

func _check_jump(stage: Node, index: int) -> void:
	var player := stage.get("player") as Player
	var initial_feet := _feet_y(player)
	var highest_feet := initial_feet
	var camera_y := _check_view(stage, index).get_center().y
	for i in range(110):
		if i == 0 or i == 24:
			Input.action_press(&"jump")
		if i == 1 or i == 25:
			Input.action_release(&"jump")
		await _frames(1)
		highest_feet = minf(highest_feet, _feet_y(player))
		var view := _check_view(stage, index)
		assert(absf(view.get_center().y - camera_y) < 1.1, "Jumping and double-jumping must not pan beyond the full-height painting")
	assert(highest_feet < initial_feet - 100.0 and player.is_on_floor(), "Coverage must be exercised through an actual airborne jump and landing")

func _check_pub_landing(stage: Node, feet_offset: float) -> void:
	var pub: Dictionary = stage.get("bichema_rooms")[1]
	var platforms: Array = pub["platforms"]
	assert(not platforms.is_empty(), "The pub's painted ledges must be playable")
	var ledge: Rect2 = platforms[0]
	assert(ledge.position.y < _floor_y - 2.0, "The pub landing must exercise a raised painted ledge, not the ground")
	var player := stage.get("player") as Player
	player.global_position = Vector2(ledge.get_center().x, ledge.position.y - feet_offset - 100.0)
	player.velocity = Vector2.ZERO
	var landed := false
	for i in range(120):
		await _frames(1)
		_check_view(stage, 1)
		if player.is_on_floor():
			landed = true
			break
	assert(landed and absf(_feet_y(player) - ledge.position.y) < 1.1, "The real player must land with feet on the pub's painted platform top")
	assert(player.global_position.x > ledge.position.x and player.global_position.x < ledge.end.x)

func _run() -> void:
	assert(change_scene_to_file("res://scenes/bichema_level.tscn") == OK)
	await _frames(3)
	var stage := current_scene
	var player := stage.get("player") as Player
	player.health = 10000
	for enemy in get_nodes_in_group("enemies"):
		enemy.set_physics_process(false)
	await _frames(60)
	assert(player.is_on_floor())
	_floor_y = _feet_y(player)
	var feet_offset := _floor_y - player.global_position.y
	var rooms: Array = stage.get("bichema_rooms")
	assert(rooms.size() == 3, "Stage two must contain plaza, pub and factory, not separate level-select stages")
	for i in range(rooms.size()):
		var room: Dictionary = rooms[i]
		var texture: Texture2D = room["texture"]
		assert(texture.get_image().detect_alpha() == Image.ALPHA_NONE, "The full paintings must be opaque, not expose a backstop through transparent bands")
		if i > 0:
			var previous: Rect2 = rooms[i - 1]["rect"]
			var rect: Rect2 = room["rect"]
			assert(is_equal_approx(previous.end.x, rect.position.x), "Rooms must meet without a world-space gap")

	var gates: Array = stage.get("gates").duplicate()
	assert(not gates.is_empty(), "The longer stage must retain mob gates")
	for gate in gates:
		var gate_x: float = gate["x"]
		var living: Array = []
		for enemy in gate["bugs"]:
			if is_instance_valid(enemy) and not enemy.dead:
				living.append(enemy)
		assert(not living.is_empty(), "Each closed gate must protect a live mob encounter")
		# Leaving one survivor distinguishes an all-mobs gate from a first-kill gate.
		for i in range(living.size() - 1):
			living[i].take_damage(10000)
		player.global_position = Vector2(gate_x - 70.0, _floor_y - feet_offset)
		player.velocity = Vector2.ZERO
		await _frames(90)
		var blocked_index: int = stage.get("bichema_background_index")
		Input.action_press(&"move_right")
		await _frames(30)
		Input.action_release(&"move_right")
		assert(player.global_position.x < gate_x, "A surviving mob must still physically block the player at its gate")
		var blocked_view := _check_view(stage, blocked_index)
		var room_rect: Rect2 = rooms[blocked_index]["rect"]
		assert(blocked_view.end.x <= maxf(gate_x, room_rect.position.x + blocked_view.size.x) + 1.1, "An uncleared gate must also clamp the camera's forward view")
		living.back().take_damage(10000)
		await _frames(5)
		await _walk_to(stage, gate_x + 1.0)
	assert(stage.get("gates").is_empty() and not stage.get("boss_started"), "Clearing mob gates must unlock traversal, not prematurely start the factory boss")

	for i in range(rooms.size()):
		var rect: Rect2 = rooms[i]["rect"]
		if i == 0:
			player.global_position = Vector2(rect.position.x + 40.0, _floor_y - feet_offset)
			player.velocity = Vector2.ZERO
			await _frames(90)
		else:
			await _walk_to(stage, rect.position.x + 40.0)
			_check_view(stage, i)
			await _walk_to(stage, rect.position.x - 40.0)
			_check_view(stage, i - 1)
			await _walk_to(stage, rect.position.x + 40.0)
		var left_view := _check_view(stage, i)
		_check_image_edge(stage, true)
		assert(absf(left_view.position.x - rect.position.x) < 2.1, "Walking to the room's left end must reveal the painting's leftmost details")
		await _check_jump(stage, i)
		if i == 1:
			await _check_pub_landing(stage, feet_offset)
			await _check_jump(stage, i)
			player.global_position = Vector2(rect.position.x + 40.0, _floor_y - feet_offset)
			player.velocity = Vector2.ZERO
			await _frames(90)
		var end_x := rect.end.x - 40.0
		if i == rooms.size() - 1:
			# The arena reveals the right edge before Ema's solid body blocks further walking.
			end_x = float(stage.get("boss_trigger_x")) + 100.0
		await _walk_to(stage, end_x)
		var right_view := _check_view(stage, i)
		_check_image_edge(stage, false)
		assert(absf(right_view.end.x - rect.end.x) < 2.1, "Walking to the room's right end must reveal the painting's rightmost details")
		assert(right_view.position.x > left_view.position.x + 1.0, "The camera must scroll across the painting, not hold a fixed cropped background")
		await _check_jump(stage, i)

	var factory: Rect2 = rooms.back()["rect"]
	var trigger: float = stage.get("boss_trigger_x")
	assert(trigger > factory.position.x and trigger < factory.end.x and is_equal_approx(float(stage.get("arena_right")), factory.end.x), "The boss entrance and final playable boundary must be inside the complete factory")
	assert(player.global_position.x > trigger and stage.get("boss_started"), "Traversing the full stage must reach and trigger the relocated factory boss")
	var boss: BossEvilGenius
	for enemy in get_nodes_in_group("enemies"):
		if enemy is BossEvilGenius:
			boss = enemy
	assert(boss != null and not boss.costume_form and boss.global_position.x > trigger and boss.global_position.x < factory.end.x, "The full factory must lead to the original first-form Ema encounter")
	print("PASS: three complete opaque paintings; actual viewport coverage/aspect/floor at both ends and double-jump extremes; world scrolling; bidirectional room crossings; all-mob gates; real pub landing; final-factory boss entrance")
	quit()
