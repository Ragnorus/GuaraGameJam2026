extends SceneTree

func _initialize() -> void:
	_run.call_deferred()

func _frames(count: int) -> void:
	for i in range(count):
		await physics_frame
		await process_frame

func _run() -> void:
	GameSettings.loaded = true
	GameSettings.music_on = false
	GameSettings.sfx_on = false
	YeralRoute.checkpoint = 0
	assert(change_scene_to_file("res://scenes/main.tscn") == OK)
	await _frames(3)
	var stage := current_scene
	stage.set_process(false)
	var player := stage.player as Player
	player.set_physics_process(false)
	for child in stage.get_children():
		if child is Pickup or child.is_in_group("enemies"):
			child.queue_free()
	await _frames(3)
	# Exercise creation from a real physics signal, not a direct damage call.
	var trigger := Area2D.new()
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 40.0
	shape.shape = circle
	trigger.add_child(shape)
	trigger.position = player.position
	trigger.collision_mask = 1
	var source := Node2D.new()
	source.position = Vector2(500, 550)
	stage.add_child(source)
	var callbacks := [0]
	trigger.body_entered.connect(func(body: Node2D) -> void:
		if body == player:
			callbacks[0] += 1
			for i in range(12):
				Pickup.drop_loot(source, player)
	)
	seed(20261018)
	stage.add_child(trigger)
	await _frames(4)
	assert(callbacks[0] == 1)
	var signal_drops := 0
	for child in stage.get_children():
		if child is Pickup:
			assert(child.is_inside_tree() and child.lifetime > 0.0 and child.lifetime <= Pickup.DROP_LIFETIME)
			signal_drops += 1
	assert(signal_drops > 0, "Real physics signal produces deferred loot")
	trigger.queue_free()
	source.queue_free()
	for child in stage.get_children():
		if child is Pickup:
			child.queue_free()
	await _frames(2)
	seed(20261018)
	for i in range(12):
		var robot := Robot.new()
		robot.target = player
		robot.position = Vector2(550 + i * 50, 562)
		stage.add_child(robot)
		robot.set_physics_process(false)
		robot.health = 1
		var shot := Projectile.new()
		shot.owner_player = player
		shot.target_group = "enemies"
		shot.damage = 10
		shot.position = robot.position
		stage.add_child(shot)
		await _frames(3)
		assert(robot.dead, "Real projectile collision kills the robot")
	var drops := 0
	for child in stage.get_children():
		if child is Pickup and child.lifetime > 0.0:
			drops += 1
	assert(drops > 0, "Projectile kills create real enemy loot")
	await preload("res://tests/test_cleanup.gd").finish(self)
	print("LOOT PHYSICS OK: deferred creation from actual collision signals and projectile kills")
	quit()
