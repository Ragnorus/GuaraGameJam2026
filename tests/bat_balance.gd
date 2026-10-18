extends SceneTree

# Run: Godot --headless --path . --fixed-fps 60 --script res://tests/bat_balance.gd
func _initialize() -> void:
	_run.call_deferred()

func _frames(count: int) -> void:
	for i in range(count):
		await physics_frame
		await process_frame

func _bat(world: Node2D, player: Player, enemy: Node2D) -> Minion:
	var bat := Minion.new()
	bat.owner_player = player
	bat.position = enemy.position
	world.add_child(bat)
	bat.set_physics_process(false)
	return bat

func _step(bat: Minion, count: int) -> void:
	for i in range(count):
		bat._physics_process(1.0 / 60.0)

func _cap(world: Node2D, player: Player, enemy: Node2D) -> void:
	enemy.position = Vector2(100, 0)
	world.add_child(enemy)
	enemy.set_physics_process(false)
	enemy.set("health", 10)
	if enemy is TacomaTruck:
		enemy.drive_state = TacomaTruck.DriveState.RECOVER
	if enemy is Sergeant:
		enemy.raged = true
	if enemy is BossYeral or enemy is BossEvilGenius:
		enemy.activate()
	player.meter = 0.0
	var bat := _bat(world, player, enemy)
	_step(bat, 1)
	assert(enemy.get("health") == 9 and bat.successful_hits == 1 and player.meter == 2.0,
			"First overlap must accept exactly one hit: %s" % enemy.get_class())
	_step(bat, 29)
	assert(enemy.get("health") == 9 and bat.successful_hits == 1,
			"Continuous overlap must retain the original half-second cooldown")
	_step(bat, 2)
	assert(enemy.get("health") == 8 and bat.successful_hits == Minion.MAX_BAT_HITS
			and bat.is_queued_for_deletion() and player.meter == 4.0)
	# A queued callback must not spend another hit before deferred deletion.
	bat.attack_cd = 0.0
	_step(bat, 1)
	assert(enemy.get("health") == 8 and player.meter == 4.0)
	enemy.queue_free()
	await _frames(1)

func _ignored(world: Node2D, player: Player, enemy: Node2D) -> void:
	enemy.position = Vector2(100, 0)
	world.add_child(enemy)
	enemy.set_physics_process(false)
	if enemy is Sergeant:
		enemy.state = Sergeant.State.TRANSFORM
		enemy.raged = true
	var hp: int = enemy.get("health")
	player.meter = 0.0
	var bat := _bat(world, player, enemy)
	_step(bat, 65)
	assert(enemy.get("health") == hp and bat.successful_hits == 0 and player.meter == 0.0,
			"Protected Tacoma INTRO / Sergeant TRANSFORM must spend no hit or meter")
	if enemy is TacomaTruck:
		enemy.drive_state = TacomaTruck.DriveState.RECOVER
	else:
		enemy.state = Sergeant.State.IDLE
	_step(bat, 65)
	assert(enemy.get("health") == hp - 2 and bat.is_queued_for_deletion() and player.meter == 4.0,
			"Previously ignored hits must leave both accepted hits available")
	enemy.queue_free()
	await _frames(1)

func _recall_and_independence(world: Node2D, player: Player) -> void:
	var enemy := Robot.new()
	enemy.position = Vector2(100, 0)
	world.add_child(enemy)
	enemy.set_physics_process(false)
	enemy.health = 10
	var first := _bat(world, player, enemy)
	_step(first, 1)
	first.recall()
	_step(first, 60)
	assert(first.successful_hits == 1 and enemy.health == 9 and first.sprite.animation == &"shadow_recall")
	var second := _bat(world, player, enemy)
	_step(second, 32)
	assert(second.is_queued_for_deletion() and enemy.health == 7 and first.successful_hits == 1,
			"Each bat has its own cap; another bat and recall cannot reset the first")
	_step(first, 62)
	first.position = enemy.position
	_step(first, 1)
	assert(first.is_queued_for_deletion() and enemy.health == 6 and first.successful_hits == 2)
	enemy.queue_free()
	await _frames(1)

func _lethal(world: Node2D, player: Player, enemy: Node2D) -> void:
	enemy.position = Vector2(100, 0)
	world.add_child(enemy)
	enemy.set_physics_process(false)
	if enemy is TacomaTruck:
		enemy.drive_state = TacomaTruck.DriveState.RECOVER
	if enemy is Sergeant:
		enemy.raged = true
	if enemy is BossYeral or enemy is BossEvilGenius:
		enemy.activate()
	enemy.set("health", 2)
	player.meter = 0.0
	var bat := _bat(world, player, enemy)
	_step(bat, 32)
	assert(bat.successful_hits == 2 and bat.is_queued_for_deletion() and player.meter == 4.0,
			"Lethal hits, including first boss-form depletion, must count as accepted")
	assert(not enemy.take_damage(1), "Dead / transforming enemies must reject a queued extra hit")
	if enemy is BossYeral or enemy is BossEvilGenius:
		assert(enemy.transforming and enemy.get("health") == enemy.get("max_health"))
		for i in range(600):
			await _frames(1)
			if not enemy.transforming:
				break
		assert(not enemy.transforming, "The real boss animation must finish its form transition")
		enemy.set("health", 2)
		var final_bat := _bat(world, player, enemy)
		_step(final_bat, 32)
		assert(final_bat.successful_hits == 2 and final_bat.is_queued_for_deletion()
				and enemy.dying and player.meter == 8.0,
				"Both final boss forms must count their lethal hit and exhaust the bat")
		assert(not enemy.take_damage(1))
	enemy.queue_free()
	await _frames(1)

func _ultimate_cap(world: Node2D, player: Player) -> void:
	var enemy := Robot.new()
	enemy.position = Vector2(100, 0)
	world.add_child(enemy)
	enemy.set_physics_process(false)
	enemy.health = 100
	player.meter = player.meter_max
	player._ultimate()
	var army := get_nodes_in_group("player_summons")
	assert(army.size() == player.max_minions * 2)
	for bat: Minion in army:
		bat.set_physics_process(false)
		bat.position = enemy.position
		_step(bat, 32)
		assert(bat.successful_hits == 2 and bat.is_queued_for_deletion()
				and bat.lifetime > 7.0, "Ultimate bats obey the cap before their eight-second expiry")
	assert(enemy.health == 100 - army.size() * Minion.MAX_BAT_HITS)
	enemy.queue_free()
	await _frames(1)

func _lifetimes_and_owner(world: Node2D, player: Player) -> void:
	player._spawn_minion()
	var normal := player.minions[0] as Minion
	normal.set_physics_process(false)
	player.meter = player.meter_max
	player._ultimate()
	var army: Array[Minion] = []
	for summon in get_nodes_in_group("player_summons"):
		if summon != normal:
			army.append(summon as Minion)
			summon.set_physics_process(false)
	assert(army.size() == player.max_minions * 2 and normal.lifetime == 0.0)
	for bat in army:
		assert(bat.lifetime == 8.0)
		bat._physics_process(7.9)
		assert(not bat.is_queued_for_deletion())
		bat._physics_process(0.2)
		assert(bat.is_queued_for_deletion())
	normal._physics_process(9.0)
	assert(not normal.is_queued_for_deletion(), "Normal summons have no timed expiry")
	await _frames(1)
	player.meter = player.meter_max
	player._ultimate()
	player.controls_locked = true
	normal._physics_process(1.0 / 60.0)
	assert(normal.is_queued_for_deletion(), "Cinematic locks must still clean up bats")
	player.controls_locked = false
	player.die()
	await _frames(1)
	assert(get_nodes_in_group("player_summons").is_empty() and player.minions.is_empty(),
			"Owner death must clean up ordinary and untracked ultimate summons")

func _camping() -> void:
	var stage := preload("res://scenes/bichema_level.tscn").instantiate()
	root.add_child(stage)
	var player := stage.get("player") as Player
	var route := stage.get("bichema_route") as BichemaRoute
	var truck := route.truck
	for enemy in get_nodes_in_group("enemies"):
		if enemy != truck:
			enemy.queue_free()
	player.position = Vector2(2480.0, 564.0)
	route._set_area(1)
	route._transition(2)
	for i in range(240):
		await _frames(1)
		if not route.transitioning:
			break
	assert(route.tacoma_arrived and not route.transitioning and route.room_enemies[2].size() == 1)
	var ledge := Rect2()
	for rect: Rect2 in stage.get("bichema_rooms")[1]["platforms"]:
		if rect.get_center().x > 2700.0 and rect.get_center().x < 3900.0 and rect.position.y < 420.0:
			ledge = rect
			break
	assert(ledge.size.x > 0.0, "Camping must use an existing elevated pub platform")
	player.position = Vector2(ledge.get_center().x, ledge.position.y - 80.0)
	player.velocity = Vector2.ZERO
	player.invuln = 1000.0
	await _frames(45)
	assert(player.is_on_floor() and absf(player.position.y + 36.0 - ledge.position.y) < 2.0,
			"The real player must land and camp on the existing pub platform")
	for ultimate in [false, true]:
		truck.health = truck.max_health
		truck.position = Vector2(player.position.x, 600.0)
		truck.velocity = Vector2.ZERO
		truck.drive_state = TacomaTruck.DriveState.RECOVER
		truck.state_time = TacomaTruck.RECOVER_TIME
		var batch_size := player.max_minions * 2 if ultimate else player.max_minions
		if ultimate:
			player.meter = player.meter_max
			player._ultimate()
		else:
			for i in range(batch_size):
				player._spawn_minion()
		await _frames(1200)
		assert(is_instance_valid(truck) and not truck.dead and truck.health > 0,
				"Camping with one normal/ultimate batch cannot kill the Bros' shared Tacoma HP")
		assert(truck.health < truck.max_health and truck.max_health - truck.health <= batch_size * Minion.MAX_BAT_HITS,
				"Real encounter bats must engage but never exceed their batch damage budget")
		var hp := truck.health
		await _frames(180)
		assert(truck.health == hp, "Camping alone cannot replenish spent bat hits")
		player.clear_attacks()
		await _frames(1)
	stage.queue_free()
	await _frames(1)

func _run() -> void:
	GameSettings.loaded = true
	GameSettings.difficulty = 1
	GameSettings.music_on = false
	GameSettings.sfx_on = false
	InputSetup.setup()
	var world := Node2D.new()
	root.add_child(world)
	var player := Player.new()
	world.add_child(player)
	player.set_physics_process(false)
	for enemy in [Bug.new(), Robot.new(), TruffleAndroid.new(), Turret.new(), WingedMob.new(),
			Sergeant.new(), TacomaTruck.new(), BossYeral.new(), BossEvilGenius.new()]:
		await _cap(world, player, enemy)
	await _ignored(world, player, TacomaTruck.new())
	await _ignored(world, player, Sergeant.new())
	await _recall_and_independence(world, player)
	for enemy in [Bug.new(), Robot.new(), TruffleAndroid.new(), Turret.new(), WingedMob.new(),
			Sergeant.new(), TacomaTruck.new(), BossYeral.new(), BossEvilGenius.new()]:
		await _lethal(world, player, enemy)
	await _ultimate_cap(world, player)
	await _lifetimes_and_owner(world, player)
	world.queue_free()
	await _frames(1)
	await _camping()
	print("PASS: two accepted hits per bat, unchanged cooldown, protected/lethal hits, recall, lifetimes, owner cleanup and real pub camping")
	quit()
