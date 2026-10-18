extends SceneTree

class BurstTarget extends Node2D:
	var health := 10
	var dead := false

	func take_damage(amount: int) -> void:
		health -= amount

func _initialize() -> void:
	_run.call_deferred()

func _frames(count: int) -> void:
	for i in range(count):
		await physics_frame
		await process_frame

func _secret_jump(player: Player, x: float) -> void:
	var direction := &"move_right" if x > player.position.x else &"move_left"
	Input.action_press(direction)
	Input.action_press(&"jump")
	await _frames(16)
	Input.action_release(&"jump")
	for i in range(160):
		if i == 3:
			Input.action_press(&"jump")
		if i > 3 and player.velocity.y >= 0.0:
			Input.action_release(&"jump")
		if absf(player.position.x - x) < 6.0:
			Input.action_release(direction)
		await _frames(1)
		if i > 5 and player.is_on_floor():
			break
	Input.action_release(direction)
	Input.action_release(&"jump")
	assert(player.is_on_floor() and not player.dead, "Secret jump must land safely")

func _run() -> void:
	# Exercise unlocks and death without writing test progress to the user's settings.
	GameSettings.loaded = false
	GameSettings.music_on = false
	GameSettings.sfx_on = false
	GameSettings.shield_unlocked = false
	YeralRoute.checkpoint = 0
	# Drop rules are pure, so they are checked directly.
	assert(Pickup.roll_drop(0.1, true) == Pickup.Kind.SMALL_HEAL)
	assert(Pickup.roll_drop(0.1, false) == Pickup.Kind.COIN)
	assert(Pickup.roll_drop(0.4, true) == Pickup.Kind.COIN)
	assert(Pickup.roll_drop(Pickup.HEAL_DROP_CHANCE, true) == Pickup.Kind.COIN)
	assert(Pickup.roll_drop(Pickup.COIN_DROP_CHANCE, true) == -1)
	assert(Pickup.roll_drop(0.9, true) == -1)
	assert(change_scene_to_file("res://scenes/main.tscn") == OK)
	await _frames(3)
	var stage := current_scene
	var route := stage.get("yeral_route") as YeralRoute
	var player := stage.get("player") as Player
	# Keep these normal-form movement/shield scenarios separate from the mecha pickup regression.
	for child in stage.get_children():
		if child is Pickup and child.kind == Pickup.Kind.MECHA:
			child.queue_free()
	assert(route.room_enemies[0].any(func(e): return e is Turret), "Area 1 teaches the turret")
	assert(route.room_enemies[1].any(func(e): return e is Hopper), "Area 2 has a hopper")
	assert(route.room_enemies[3].any(func(e): return e is WingedMob) and route.room_enemies[3].any(func(e): return e is Turret))

	# Shield burst is locked until the sergeant falls.
	assert(not player.shield_burst(), "Shield is locked before the sergeant is beaten")
	var sergeant := route.sergeant
	sergeant.take_damage(10000)
	await _frames(2)
	assert(GameSettings.shield_unlocked, "Defeating the sergeant unlocks the shield")

	# Burst damages nearby enemies, clears enemy shots and starts the cooldown.
	route._set_area(0)
	player.position = Vector2(300, 564)
	await _frames(30)
	var robot := route.room_enemies[0][0] as Robot
	robot.position = player.position + Vector2(80, 0)
	var shot := Projectile.new()
	shot.target_group = "player"
	shot.position = player.position + Vector2(100, 0)
	stage.add_child(shot)
	assert(shot.is_in_group("enemy_shots"))
	var hp := robot.health
	assert(player.shield_burst())
	assert(robot.health < hp or robot.dead, "Burst damages nearby enemies")
	await _frames(2)
	assert(not is_instance_valid(shot) or shot.is_queued_for_deletion(), "Burst clears enemy projectiles")
	assert(player.shield_cd > 5.0 and player.invuln > 0.0)
	var protected_health := player.health
	player.take_damage(1)
	assert(player.health == protected_health, "Shield protection blocks damage")
	assert(not player.shield_burst(), "Shield has a cooldown")
	var paused_cd := player.shield_cd
	paused = true
	for i in range(4):
		await process_frame
	assert(player.shield_cd == paused_cd, "Shield cooldown respects pause")
	paused = false
	await _frames(365)
	assert(player.shield_cd == 0.0 and stage.hud_label.text.contains("READY"), "Shield recharges in six seconds and updates the HUD")
	player.dead = true
	assert(not player.shield_burst(), "No shield while dead")
	player.dead = false
	player.controls_locked = true
	assert(not player.shield_burst(), "No shield during cinematics")
	player.controls_locked = false
	player.stun_time = 1.0
	assert(not player.shield_burst(), "No shield while stunned")
	player.clear_status()
	var distant_shot := Projectile.new()
	distant_shot.target_group = "player"
	distant_shot.position = player.position + Vector2(ShieldBurst.RADIUS + 80.0, 0)
	stage.add_child(distant_shot)
	var wave := SergeantWave.new()
	wave.position = player.position + Vector2(70, 0)
	stage.add_child(wave)
	ShieldBurst.apply(player.position, self)
	await _frames(1)
	assert(not is_instance_valid(wave), "Burst clears scream waves")
	assert(is_instance_valid(distant_shot), "Burst leaves distant shots intact")
	distant_shot.queue_free()
	var at_edge := BurstTarget.new()
	var outside := BurstTarget.new()
	var inactive := BurstTarget.new()
	for enemy in [at_edge, outside, inactive]:
		stage.add_child(enemy)
		enemy.add_to_group("enemies")
	at_edge.position = player.position + Vector2(ShieldBurst.RADIUS, 0)
	outside.position = player.position + Vector2(ShieldBurst.RADIUS + 1.0, 0)
	inactive.position = player.position
	inactive.process_mode = Node.PROCESS_MODE_DISABLED
	ShieldBurst.apply(player.position, self)
	assert(at_edge.health == 10 - ShieldBurst.DAMAGE and outside.health == 10, "Damage stops at the exact shield radius")
	assert(inactive.health == 10, "Inactive-room enemies cannot be hit")
	for enemy in [at_edge, outside, inactive]:
		enemy.queue_free()

	# Variable jump: a tap is a hop, a hold is a full jump.
	player.invuln = 0.0
	player.position = Vector2(300, 564)
	player.velocity = Vector2.ZERO
	await _frames(20)
	var floor_y := player.position.y
	Input.action_press(&"jump")
	await _frames(1)
	Input.action_release(&"jump")
	var tap_top := player.position.y
	for i in range(60):
		await _frames(1)
		tap_top = minf(tap_top, player.position.y)
		if player.is_on_floor() and i > 3:
			break
	player.velocity = Vector2.ZERO
	await _frames(10)
	var hold_top := player.position.y
	Input.action_press(&"jump")
	for i in range(60):
		await _frames(1)
		hold_top = minf(hold_top, player.position.y)
		if player.velocity.y > 0.0:
			break
	Input.action_release(&"jump")
	assert(floor_y - tap_top < (floor_y - hold_top) * 0.75, "Tap jumps lower than a held jump: %s vs %s" % [floor_y - tap_top, floor_y - hold_top])
	for i in range(80):
		await _frames(1)
		if player.is_on_floor():
			break

	# With no air jumps left, a press just before landing fires on the next frame.
	player.position = Vector2(300, 520)
	player.velocity = Vector2(0, 300)
	await _frames(1)
	player.jumps_remaining = 0
	Input.action_press(&"jump")
	await _frames(1)
	Input.action_release(&"jump")
	var buffered := false
	for i in range(10):
		await _frames(1)
		if player.velocity.y < -100.0:
			buffered = true
			break
	assert(buffered, "A jump pressed within 0.12 seconds of landing is buffered")
	player.position = Vector2(300, 564)
	player.velocity = Vector2.ZERO
	await _frames(40)

	# Knockback and red flash on contact damage.
	player.invuln = 0.0
	player.knockback_time = 0.0
	player.facing = 1
	player.take_damage(1)
	assert(player.knockback_time > 0.0 and player.velocity.x < 0.0, "Hits shove the player back")
	await _frames(1)
	assert(player.player_sprite.modulate.g < 1.0, "Hits flash red")

	# Drops: heal only when hurt, and they expire.
	player.health = player.max_health - 3
	Pickup.drop_loot(player, player)
	var small_heal := stage._spawn_pickup(Pickup.Kind.SMALL_HEAL, Vector2(-500, -500), true) as Pickup
	var health_before := player.health
	small_heal._on_body_entered(player)
	assert(player.health == health_before + Pickup.SMALL_HEAL_AMOUNT, "Small drops heal two HP")
	assert(small_heal.is_queued_for_deletion())
	var dropped := Pickup.new()
	dropped.kind = Pickup.Kind.COIN
	dropped.lifetime = 0.2
	dropped.position = Vector2(-500, -500)
	stage.add_child(dropped)
	await _frames(30)
	assert(not is_instance_valid(dropped) or dropped.is_queued_for_deletion(), "Dropped pickups expire")

	# Turret: optional, telegraphs then fires, and drops/score on death.
	var turret := route.room_enemies[0].filter(func(e): return is_instance_valid(e) and e is Turret)[0] as Turret
	route._set_area(0)
	for e in route.room_enemies[0]:
		if e != turret and is_instance_valid(e):
			e.take_damage(10000)
	await _frames(5)
	assert(route._room_clear(), "An optional turret never gates the exit")
	player.position = turret.position + Vector2(-300, 0)
	player.invuln = 5.0
	turret.cooldown = 0.0
	await _frames(2)
	assert(turret.warn_time > 0.0 and get_nodes_in_group("enemy_shots").is_empty(), "Turret telegraphs before firing")
	var shots := 0
	for i in range(120):
		await _frames(1)
		shots = get_nodes_in_group("enemy_shots").size()
		if shots > 0:
			break
	assert(shots > 0, "Turret fires at the player")
	var score := GameSettings.score
	turret.take_damage(10000)
	assert(turret.dead and GameSettings.score > score)

	# Hopper: leaves the ground toward the player.
	route._set_area(1)
	var hopper := route.room_enemies[1].filter(func(e): return is_instance_valid(e) and e is Hopper)[0] as Hopper
	player.position = hopper.position + Vector2(-250, 0)
	await _frames(10)
	var airborne := false
	var saw_windup := false
	for i in range(160):
		await _frames(1)
		saw_windup = saw_windup or hopper.windup > 0.0
		if not hopper.is_on_floor() and hopper.velocity.y < -400.0:
			airborne = true
			break
	assert(airborne and saw_windup, "Hopper telegraphs, then launches upward")

	# Area 4 needs its flyer cleared; its turret does not matter.
	route._set_area(3)
	assert(not route._room_clear(), "The Area 4 flyer gates the exit")
	for e in route.room_enemies[3]:
		if is_instance_valid(e) and e is WingedMob:
			e.take_damage(10000)
	assert(route._room_clear())

	# Both coin ledges are reachable by actual jumps from the nearby route platforms.
	route._set_area(0)
	player.position = Vector2(430, 444)
	player.velocity = Vector2.ZERO
	player.clear_status()
	player.invuln = 10.0
	await _frames(5)
	await _secret_jump(player, 190.0)
	assert(absf(player.position.y + 36.0 - 360.0) < 2.0, "First city secret is reachable")
	route._set_area(4)
	for e in route.room_enemies[4]:
		if is_instance_valid(e):
			e.set_physics_process(false)
	player.position = Vector2(5990, 414)
	player.velocity = Vector2.ZERO
	await _frames(5)
	await _secret_jump(player, 6220.0)
	assert(absf(player.position.y + 36.0 - 320.0) < 2.0, "Final city secret is reachable")

	# Checkpoints record progress, survive a reload, and clear on a new run.
	YeralRoute.checkpoint = 0
	route._transition(2)
	await _frames(85)
	assert(YeralRoute.checkpoint == 2)
	player.die()
	Input.action_press(&"restart")
	await _frames(1)
	Input.action_release(&"restart")
	await _frames(5)
	route = current_scene.get("yeral_route") as YeralRoute
	player = current_scene.get("player") as Player
	assert(route.area_index == 2 and player.position.x > route.AREAS[2].position.x, "Reload resumes at the checkpoint")
	assert(route.room_enemies[0].is_empty() and route.room_enemies[1].is_empty(), "Skipped guards do not respawn")
	YeralRoute.checkpoint = 5
	assert(reload_current_scene() == OK)
	await _frames(5)
	route = current_scene.get("yeral_route") as YeralRoute
	player = current_scene.get("player") as Player
	assert(route.area_index == 5 and route.boss != null and not route.boss.active)
	assert(player.controls_locked and route.speech.visible, "Boss checkpoint replays the protected intro")
	player.die()
	assert(not route.voice.playing, "Death at the boss checkpoint stops the voice")
	await _frames(60)
	GameSettings.begin_run()
	assert(YeralRoute.checkpoint == 0)
	GameSettings.shield_unlocked = false
	print("LEVEL1 UPGRADES OK")
	current_scene.free()
	for child in root.get_children():
		if child is AudioStreamPlayer:
			child.stop()
			child.stream = null
			child.queue_free()
	await _frames(5)
	await create_timer(0.05).timeout
	await preload("res://tests/test_cleanup.gd").finish(self)
	quit()
