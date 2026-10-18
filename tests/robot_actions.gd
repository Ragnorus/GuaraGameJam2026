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
	GameSettings.loaded = true
	GameSettings.difficulty = 1
	GameSettings.music_on = false
	GameSettings.sfx_on = false
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
		if enemy is Sergeant or enemy is Turret:
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
	player.clear_status()
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
	var tacoma_count := 0
	var truck: TacomaTruck
	for enemy in get_nodes_in_group("enemies"):
		assert(enemy is WingedMob or (enemy is TruffleAndroid and not enemy is Robot) or enemy is TacomaTruck,
				"Bichema ground enemies are truffles plus the Tacoma")
		if enemy is TacomaTruck:
			truck = enemy
			tacoma_count += 1
	assert(tacoma_count == 1)
	var bichema_route := ema_stage.get("bichema_route") as BichemaRoute
	assert(truck == bichema_route.truck and bichema_route.room_enemies[2].size() == 1
			and truck.health == GameSettings.scale_health(19),
			"The Bros stay in one damageable Tacoma")
	var normal_music := GameAudio._music
	assert(not truck.music.playing, "Tacoma music must not play outside the fight")
	var bichema_player := ema_stage.get("player") as Player
	bichema_player.invuln = 0.0
	var intro_health := bichema_player.health
	var waiting_truck_health := truck.health
	truck.take_damage(1)
	assert(truck.health == waiting_truck_health, "The cinematic Tacoma must not take combat damage")
	bichema_player.position = Vector2(2480.0, 564.0)
	bichema_route._set_area(1)
	bichema_route._transition(2)
	for i in range(180):
		await _frames(1)
		assert(bichema_player.health == intro_health, "The Tacoma entrance must preserve player HP")
		if bichema_player.controls_locked:
			assert(not truck.music.playing, "Tacoma music must wait until the entrance finishes")
		if bichema_route.area_index == 2 and truck.visible:
			assert(truck.position.x - bichema_player.position.x > TacomaTruck.HALF_WIDTH + Bug.PLAYER_HALF.x,
					"The entrance must stop clear instead of crossing through the player")
		if i == 90:
			var paused_at := truck.position
			var paused_frame := truck.truck_sprite.frame
			paused = true
			await _frames(12)
			assert(truck.position == paused_at and truck.truck_sprite.frame == paused_frame
					and bichema_player.controls_locked, "Pause must freeze the animated entrance")
			paused = false
		if not bichema_route.transitioning:
			break
	assert(not bichema_route.transitioning and bichema_route.tacoma_arrived
			and truck.visible and bichema_route.room_enemies[2].size() == 1
			and bichema_route.room_enemies[2][0] == truck,
			"The Tacoma must enter the pub and remain as the single enemy")
	assert(truck.music.playing and (truck.music.stream as AudioStreamMP3).loop
			and GameAudio._music == null and not is_instance_valid(normal_music),
			"The fight must loop its recording without overlapping normal music")
	paused = true
	await _frames(2)
	assert(truck.music.stream_paused, "Pausing combat must pause its music")
	paused = false
	await _frames(60)
	assert(bichema_player.health == intro_health and truck.drive_state == TacomaTruck.DriveState.WINDUP,
			"The player must get a full warning after regaining control")
	truck.position = Vector2(3200.0, 600.0)
	bichema_player.position = Vector2(3440.0, 564.0)
	truck.velocity = Vector2.ZERO
	truck.drive_state = TacomaTruck.DriveState.RECOVER
	truck.state_time = TacomaTruck.RECOVER_TIME
	await _frames(2)
	assert(truck.is_on_floor(), "The Tacoma must stay grounded on the pub floor")
	var health_before_charge := bichema_player.health
	truck.drive_state = TacomaTruck.DriveState.WINDUP
	truck.state_time = 0.001
	truck.hit_this_charge = false
	await _frames(1)
	assert(truck.drive_state == TacomaTruck.DriveState.CHARGE
			and truck.velocity.y < 0.0 and truck.position.y < 600.0,
			"A real Tacoma charge must start with a jump")
	assert(truck.truck_sprite.animation == &"charge", "Airborne charges must show the supplied charge art")
	var charge_start := truck.position.x
	await _frames(6)
	assert(truck.position.x - charge_start >= 47.0 and truck.position.y < 560.0
			and bichema_player.health == health_before_charge,
			"The Tacoma must make a fast jump before reaching the player")
	for i in range(30):
		await _frames(1)
		if bichema_player.health < health_before_charge:
			break
	assert(truck.position.x > charge_start
			and bichema_player.health == health_before_charge - GameSettings.incoming_damage(2)
			and bichema_player.knockback_time > 0.0,
			"A Tacoma charge must ram and knock back a grounded player")

	bichema_player.clear_status()
	bichema_player.invuln = 0.0
	bichema_player.velocity = Vector2.ZERO
	bichema_player.position = Vector2(3500.0, 564.0)
	truck.position = Vector2(3200.0, 600.0)
	truck.velocity = Vector2.ZERO
	truck.drive_state = TacomaTruck.DriveState.CHARGE
	truck.charge_direction = 1
	truck.state_time = TacomaTruck.CHARGE_TIME
	truck.hit_this_charge = false
	var health_before_jump := bichema_player.health
	for i in range(75):
		if i == 9 or i == 39:
			Input.action_press(&"jump")
		if i == 33 or i == 63:
			Input.action_release(&"jump")
		await _frames(1)
	Input.action_release(&"jump")
	assert(bichema_player.health == health_before_jump,
			"A timed double jump must clear the Tacoma's charge")
	assert(truck.drive_state == TacomaTruck.DriveState.RECOVER and truck.truck_sprite.animation == &"spin",
			"A completed charge must land and drift into a donut recovery")
	var spin_frame := truck.truck_sprite.frame
	var spin_facing := truck.truck_sprite.flip_h
	var spin_advanced := false
	var spin_turned := false
	bichema_player.position = truck.position - Vector2(0.0, 36.0)
	bichema_player.velocity = Vector2.ZERO
	bichema_player.invuln = 0.0
	for i in range(35):
		await _frames(1)
		spin_advanced = spin_advanced or truck.truck_sprite.frame != spin_frame
		spin_turned = spin_turned or truck.truck_sprite.flip_h != spin_facing
	assert(spin_advanced and spin_turned and bichema_player.health == health_before_jump,
			"The donut must animate through both facings without dealing recovery contact damage")

	truck.set_physics_process(false)
	truck.position = Vector2(3200.0, 600.0)
	truck.velocity = Vector2.ZERO
	bichema_player.clear_status()
	bichema_player.invuln = 0.0
	bichema_player.velocity = Vector2.ZERO
	bichema_player.position = Vector2(3500.0, 564.0)
	bichema_player.facing = -1
	await _frames(2)
	var truck_health := truck.health
	bichema_player._shoot()
	await _frames(30)
	assert(truck.health == truck_health - 1,
			"A real player projectile must damage the Tacoma")
	truck.take_damage(truck.health)
	await _frames(2)
	assert(not is_instance_valid(truck) and is_instance_valid(GameAudio._music)
			and GameAudio._music_level == 2
			and (GameAudio._music.stream as AudioStreamWAV).data == GameAudio.LEVEL2_MUSIC.data,
			"Defeating the Tacoma must stop its song and restore normal music")
	ema_stage.queue_free()
	await _frames(1)
	GameAudio.stop_music()
	await create_timer(0.3).timeout
	print("PASS: robot movement/combat/death; Tacoma entrance, pause, warning, charge, recovery, dodge, damage and fight-only music")
	quit()
