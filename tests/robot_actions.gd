extends SceneTree

# Run: Godot --headless --path . --fixed-fps 60 --script res://tests/robot_actions.gd
func _initialize() -> void:
	_run.call_deferred()

func _frames(count: int) -> void:
	for i in range(count):
		await physics_frame
		await process_frame

func _assert_ground_contact(robot: Robot, floor_y: float) -> void:
	assert(robot.is_on_floor(), "Robot must settle on the floor")
	var image := robot.sprite.sprite_frames.get_frame_texture(robot.sprite.animation, robot.sprite.frame).get_image()
	var origin := robot.sprite.offset - Vector2(image.get_size()) / 2.0 if robot.sprite.centered else robot.sprite.offset
	for y in range(image.get_height() - 1, -1, -1):
		for x in range(image.get_width()):
			if image.get_pixel(x, y).a >= 0.5:
				var feet := robot.sprite.to_global(origin + Vector2(x, y + 1))
				assert(absf(feet.y - floor_y) < 1.0, "Visible robot feet must meet the floor")
				return

func _run() -> void:
	var stage := preload("res://scenes/main.tscn").instantiate()
	root.add_child(stage)
	var player := stage.get("player") as Player
	var robot: Robot
	var fliers := 0
	for enemy in get_nodes_in_group("enemies"):
		if enemy is WingedMob:
			fliers += 1
			enemy.queue_free()
			continue
		assert(enemy is Robot, "Every first-stage ground mob must use robot art")
		if robot == null:
			robot = enemy as Robot
		else:
			enemy.queue_free()
	assert(fliers > 0, "The first stage must include winged flying mobs")
	player.collision_layer = 0
	player.collision_mask = 0
	robot.position = Vector2(780, stage.FLOOR_Y - 10)
	robot.origin_x = robot.position.x
	player.position = robot.position + Vector2(180, 0)
	await _frames(12)
	assert(robot.get_position_delta().x > 0.0 and not robot.sprite.flip_h)
	assert(robot.sprite.animation == &"walk")
	_assert_ground_contact(robot, stage.FLOOR_Y)
	player.position = robot.position - Vector2(180, 0)
	await _frames(12)
	assert(robot.get_position_delta().x < 0.0 and robot.sprite.flip_h)
	assert(robot.sprite.animation == &"walk")
	var shape := robot.get_child(0) as CollisionShape2D

	var wall := StaticBody2D.new()
	var wall_shape := CollisionShape2D.new()
	var rectangle := RectangleShape2D.new()
	rectangle.size = Vector2(10, 100)
	wall_shape.shape = rectangle
	wall.add_child(wall_shape)
	wall.position = robot.position + Vector2(21, 0)
	stage.add_child(wall)
	player.position = robot.position + Vector2(150, 0)
	await _frames(8)
	assert(robot.sprite.animation == &"idle", "A robot pushing into a wall must idle rather than walk in place")
	_assert_ground_contact(robot, stage.FLOOR_Y)
	wall.queue_free()
	await _frames(1)

	player.invuln = 0.0
	var player_health := player.health
	player.position = robot.position
	await _frames(1)
	assert(player.health == player_health - 1, "Robot must retain Bug contact damage")
	player.position = robot.position - Vector2(100, 0)
	player.facing = 1
	Input.action_press(&"shoot")
	player.set_physics_process(true)
	await _frames(1)
	Input.action_release(&"shoot")
	player.set_physics_process(false)
	for i in range(20):
		if robot.health < 3:
			break
		await _frames(1)
	assert(robot.health == 2 and robot.sprite.animation == &"hurt", "A real player projectile must damage the robot and start hurt")
	await _frames(3)
	assert(robot.sprite.animation == &"hurt", "Locomotion must not interrupt hurt")
	await _frames(16)
	assert(robot.sprite.animation == &"walk" or robot.sprite.animation == &"idle", "Hurt must return to locomotion")

	player._spawn_minion()
	var shadow := player.minions[0] as Minion
	shadow.position = robot.position
	await _frames(1)
	assert(robot.health == 1, "Existing summoned shadows must damage robots")
	shadow.set_physics_process(false)
	player.position = robot.position
	player.invuln = 0.0
	player_health = player.health
	robot.take_damage(1)
	assert(robot.dying and robot.sprite.animation == &"death")
	assert(not robot.is_in_group("enemies") and shadow._nearest_enemy() == null, "A corpse must immediately stop being targetable")
	assert(robot.collision_layer == 0 and robot.collision_mask == 0 and not robot.is_physics_processing())
	robot.take_damage(99)
	assert(robot.health == 0 and robot.sprite.frame == 0, "Repeated damage must neither change health nor restart death")
	await _frames(2)
	assert(is_instance_valid(robot) and shape.disabled and player.health == player_health, "Death must remove collision and contact damage while retaining the art")
	await _frames(12)
	assert(is_instance_valid(robot) and robot.sprite.animation == &"death", "Death art must remain until its animation finishes")
	await _frames(40)
	assert(not is_instance_valid(robot), "Death animation completion must despawn the robot")
	stage.queue_free()
	await _frames(1)

	var ema_stage := preload("res://scenes/bichema_level.tscn").instantiate()
	root.add_child(ema_stage)
	for enemy in get_nodes_in_group("enemies"):
		assert(enemy is WingedMob or (enemy is TruffleAndroid and not enemy is Robot), "Bichema's World ground mobs must be truffle androids")
	ema_stage.queue_free()
	await _frames(1)
	print("PASS: first-stage robots, locomotion/facing, blocked idle, contact/projectile/shadow damage, hurt recovery, corpse safety, death completion, truffle androids")
	quit()
