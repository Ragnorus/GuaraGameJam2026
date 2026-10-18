extends SceneTree

var stat_updates := 0

func _initialize() -> void:
	_run.call_deferred()

func _frames(count: int) -> void:
	for i in range(count):
		await physics_frame
		await process_frame

func _release_inputs() -> void:
	for action in [&"move_left", &"move_right", &"jump", &"shoot", &"dash", &"summon", &"recall", &"ultimate", &"shield"]:
		Input.action_release(action)

func _reset_settings() -> void:
	# Keep deaths/unlocks from saving over the user's progress.
	GameSettings.loaded = false
	GameSettings.music_on = false
	GameSettings.sfx_on = false
	GameSettings.difficulty = 1
	GameSettings.dash_unlocked = false
	GameSettings.shield_unlocked = false
	GameSettings.begin_run()

func _load_stage(path: String) -> Node:
	_release_inputs()
	_reset_settings()
	assert(change_scene_to_file(path) == OK)
	await _frames(3)
	for enemy in get_nodes_in_group("enemies"):
		enemy.set_physics_process(false)
		if enemy is CollisionObject2D:
			enemy.collision_layer = 0
			enemy.collision_mask = 0
	var player := current_scene.get("player") as Player
	player.position = Vector2(180, 564)
	player.velocity = Vector2.ZERO
	await _frames(3)
	return current_scene

func _chest(stage: Node, near_x: float) -> Pickup:
	for child in stage.get_children():
		if child is Pickup and child.kind == Pickup.Kind.MECHA and absf(child.position.x - near_x) < 2.0:
			return child
	return null

func _finish_transition(player: Player) -> void:
	for i in range(240):
		if player.mecha_transition == &"":
			return
		await _frames(1)
	assert(false, "Mecha transition failed to finish: %s, animation %s frame %d" % [player.mecha_transition, player.player_sprite.animation, player.player_sprite.frame])

func _walk_to_chest(stage: Node) -> Player:
	var player := stage.get("player") as Player
	var chest := _chest(stage, 260.0)
	assert(chest != null, "Each stage needs its reachable starting mecha chest")
	Input.action_press(&"move_right")
	for i in range(50):
		await _frames(1)
		if player.mecha_transition == &"transform":
			break
	Input.action_release(&"move_right")
	assert(player.mecha_transition == &"transform", "Walking into the chest must begin transformation; position=%s" % player.position)
	await _frames(1)
	assert(not is_instance_valid(chest), "Successful physical chest collection consumes it")
	return player

func _shot_hit(stage: Node, player: Player, direction: int, damage: int) -> void:
	player.clear_attacks()
	player.clear_status()
	player.action_time = 0.0
	player.shoot_cd = 0.0
	player.facing = direction
	var enemy := Robot.new()
	enemy.position = player.position + Vector2(direction * 140.0, 0)
	stage.add_child(enemy)
	enemy.set_physics_process(false)
	enemy.health = 20
	Input.action_press(&"shoot")
	await _frames(1)
	Input.action_release(&"shoot")
	var shots := get_nodes_in_group("player_shots")
	assert(shots.size() == 1, "A shoot input produces exactly one projectile")
	var shot := shots[0] as Projectile
	assert(signf(shot.velocity.x) == direction, "Projectile must follow player facing")
	assert(is_equal_approx(absf(shot.velocity.x), 850.0 if damage == 3 else 650.0), "Powered and normal projectile speeds must differ")
	assert(player.shoot_cd > (0.16 if damage == 3 else 0.21) and player.shoot_cd <= (0.2 if damage == 3 else 0.25), "Shot starts the correct cooldown: %s" % player.shoot_cd)
	for i in range(24):
		await _frames(1)
		if enemy.health != 20:
			break
	assert(enemy.health == 20 - damage, "Real projectile collision must deal exactly %d damage facing %d; health=%d" % [damage, direction, enemy.health])
	enemy.queue_free()
	await _frames(1)

func _denied_chest(stage: Node, player: Player) -> void:
	var chest := Pickup.new()
	chest.kind = Pickup.Kind.MECHA
	chest.position = player.position + Vector2(100, 0)
	stage.add_child(chest)
	await _frames(2)
	player.position.x += 100.0
	await _frames(2)
	assert(is_instance_valid(chest) and player.mecha_time == 0.0, "Rejected collection preserves the chest and normal form")
	chest.queue_free()
	player.position.x -= 100.0
	await _frames(2)

func _run() -> void:
	InputSetup.setup()
	var stage := await _load_stage("res://scenes/main.tscn")
	var player := await _walk_to_chest(stage)
	assert(_chest(stage, 6700.0) != null, "Yeral route needs its later replenishment chest")
	assert(not player.controls_locked, "Transformation must not commandeer the external cinematic lock")
	var hp := player.health
	var start_x := player.position.x
	var remaining := player.mecha_time
	player.invuln = 0.0
	player.take_damage(1)
	assert(player.health == hp and not player.hit_by(1, Vector2(100, -100), 1.0), "Transformation blocks damage and status hits")
	Input.action_press(&"move_right")
	Input.action_press(&"jump")
	Input.action_press(&"shoot")
	Input.action_press(&"dash")
	await _frames(2)
	assert(not player.activate_mecha(), "An in-progress transform rejects another activation")
	_release_inputs()
	assert(is_equal_approx(player.position.x, start_x) and player.jumps_remaining == Player.MAX_JUMPS and get_nodes_in_group("player_shots").is_empty(), "Transformation blocks movement, jumping, dash and shots")
	assert(is_equal_approx(player.mecha_time, remaining), "Transformation must not spend powered lifetime")
	await _finish_transition(player)
	assert(player.player_sprite.sprite_frames == Player.MECHA_FRAMES, "Completed transform uses supplied mecha movement art")
	player.stats_changed.connect(func() -> void: stat_updates += 1)
	var before := player.mecha_time
	await _frames(70)
	assert(player.mecha_time < before - 1.0 and stat_updates > 0, "Powered lifetime advances and emits countdown updates")
	before = player.mecha_time
	paused = true
	for i in range(6):
		await process_frame
	assert(player.mecha_time == before, "Pause freezes the mecha clock")
	paused = false
	player.controls_locked = true
	await _frames(12)
	assert(player.mecha_time == before, "External cinematics freeze the mecha clock")
	player.controls_locked = false

	start_x = player.position.x
	Input.action_press(&"move_right")
	await _frames(10)
	Input.action_release(&"move_right")
	assert(player.position.x > start_x + 35 and is_equal_approx(player.velocity.x, Player.SPEED), "Powered form must physically run at normal speed")
	assert(player.player_sprite.animation == &"run", "Powered running selects its movement animation")
	Input.action_press(&"jump")
	await _frames(2)
	assert(player.velocity.y < -400 and player.jumps_remaining == 1, "Powered first jump leaves the floor")
	Input.action_release(&"jump")
	await _frames(3)
	Input.action_press(&"jump")
	await _frames(2)
	assert(player.velocity.y < -400 and player.jumps_remaining == 0 and player.player_sprite.animation == &"double_jump", "Powered air jump resets upward velocity and uses double-jump art")
	Input.action_release(&"jump")
	for i in range(120):
		await _frames(1)
		if player.is_on_floor():
			break
	assert(player.is_on_floor(), "Powered double jump lands on the real floor")
	player.position = Vector2(600, 564)
	player.velocity = Vector2.ZERO
	await _frames(4)
	await _shot_hit(stage, player, 1, 3)
	await _shot_hit(stage, player, -1, 3)
	player.action_time = 0.0
	player.facing = 1
	start_x = player.position.x
	Input.action_press(&"dash")
	await _frames(4)
	Input.action_release(&"dash")
	assert(player.position.x > start_x + 35 and player.dash_time > 0.0 and not GameSettings.dash_unlocked, "Mecha grants a real temporary dash without permanent unlock")
	await _frames(15)

	player.mecha_time = 2.0
	var refresh := Pickup.new()
	refresh.kind = Pickup.Kind.MECHA
	refresh.position = player.position + Vector2(90, 0)
	stage.add_child(refresh)
	Input.action_press(&"move_right")
	for i in range(30):
		await _frames(1)
		if not is_instance_valid(refresh):
			break
	Input.action_release(&"move_right")
	assert(not is_instance_valid(refresh) and player.mecha_time > 19.0 and player.mecha_transition == &"", "Active chest collection refreshes to twenty seconds without transforming again")
	player.mecha_time = 0.03
	await _frames(3)
	assert(player.mecha_transition == &"revert", "Expired power begins protected revert")
	player.invuln = 0.0
	player.take_damage(1)
	assert(player.health == hp, "Revert blocks damage")
	start_x = player.position.x
	Input.action_press(&"move_left")
	Input.action_press(&"shoot")
	await _frames(2)
	_release_inputs()
	assert(is_equal_approx(player.position.x, start_x) and get_nodes_in_group("player_shots").is_empty(), "Revert blocks steering and shooting")
	await _finish_transition(player)
	assert(player.mecha_time == 0.0 and player.player_sprite.sprite_frames == Player.CHARACTER_FRAMES and not player.controls_locked, "Revert restores normal art and controls")
	await _shot_hit(stage, player, 1, 1)
	player.action_time = 0.0
	Input.action_press(&"move_left")
	await _frames(3)
	Input.action_release(&"move_left")
	assert(player.player_sprite.animation == &"run" and player.player_sprite.sprite_frames == Player.CHARACTER_FRAMES, "Normal movement art works after revert")
	player.dash_cooldown = 0.0
	Input.action_press(&"dash")
	await _frames(2)
	Input.action_release(&"dash")
	assert(player.dash_time == 0.0 and not GameSettings.dash_unlocked, "Temporary dash disappears on expiry")

	for status in [&"locked", &"stunned", &"knockback"]:
		player.controls_locked = status == &"locked"
		player.stun_time = 1.0 if status == &"stunned" else 0.0
		player.knockback_time = 1.0 if status == &"knockback" else 0.0
		assert(not player.activate_mecha(), "Activation rejects %s" % status)
		await _denied_chest(stage, player)
		player.controls_locked = false
		player.clear_status()

	assert(player.activate_mecha())
	await _finish_transition(player)
	player._summon()
	player.meter = player.meter_max
	player._ultimate()
	player._shoot()
	assert(not get_nodes_in_group("player_summons").is_empty() and not get_nodes_in_group("player_shots").is_empty(), "Powered summon, army and shooting remain available before death")
	var route := stage.get("yeral_route") as YeralRoute
	route._set_area(2)
	player.position = Vector2(2800, 1350)
	player.velocity = Vector2(0, 200)
	await _frames(3)
	assert(player.dead and player.mecha_time == 0.0 and player.mecha_transition == &"", "Lethal acid clears powered state immediately")
	assert(player.player_sprite.sprite_frames == Player.CHARACTER_FRAMES and player.player_sprite.animation == &"death", "Powered death uses the original character death art")
	assert(get_nodes_in_group("player_shots").is_empty() and get_nodes_in_group("player_summons").is_empty(), "Powered death cleans all owned attacks and summons")
	assert(not player.activate_mecha(), "Dead players reject activation")
	await _denied_chest(stage, player)
	YeralRoute.checkpoint = 0
	assert(reload_current_scene() == OK)
	await _frames(3)
	player = current_scene.get("player") as Player
	assert(not player.dead and player.mecha_time == 0.0 and player.player_sprite.sprite_frames == Player.CHARACTER_FRAMES, "Restart starts alive in normal form")

	stage = await _load_stage("res://scenes/bichema_level.tscn")
	player = await _walk_to_chest(stage)
	assert(_chest(stage, 6680.0) != null, "Bichema route needs its later replenishment chest")
	player.position = Vector2(600, 350)
	player.velocity = Vector2.ZERO
	await _frames(3)
	assert(player.mecha_transition == &"transform" and player.position.y > 350 and player.velocity.y > 0.0, "Transformation preserves gravity in mid-air")
	await _finish_transition(player)
	assert(player.mecha_time > 19.0 and player.player_sprite.sprite_frames == Player.MECHA_FRAMES, "Bichema chest physically grants the complete powered form")
	_release_inputs()
	current_scene.queue_free()
	await _frames(2)
	_reset_settings()
	print("PASS: both-stage physical mecha collection; protected transitions, movement/double jump, bidirectional collision damage, temporary dash, refresh/expiry, clock freeze, denied collection, acid cleanup and restart")
	quit()
