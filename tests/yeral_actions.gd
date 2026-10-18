extends SceneTree

# Run: Godot --headless --path . --fixed-fps 60 --script res://tests/yeral_actions.gd
func _initialize() -> void:
	_run.call_deferred()

func _frames(count: int) -> void:
	for i in range(count):
		await physics_frame
		await process_frame

func _run() -> void:
	var stage := preload("res://scenes/main.tscn").instantiate()
	root.add_child(stage)
	var player := stage.get("player") as Player
	player.health = 1000
	var route := stage.get("yeral_route") as YeralRoute
	route._set_area(5)
	player.position = Vector2(7240, 576)
	route.start_boss_intro()
	await _frames(350)
	await _frames(3)
	var boss: BossYeral
	for enemy in get_nodes_in_group("enemies"):
		if enemy is BossYeral:
			boss = enemy
		else:
			enemy.queue_free()
	assert(boss != null, "The actual stage must spawn Yeral")
	boss.attack_cd = 1000.0
	player.set_physics_process(false)
	await _frames(30)
	assert(boss.is_on_floor() and boss.sprite.animation == &"idle")
	assert(boss.sprite.flip_h, "Yeral must face the player, not the source sheet's default direction")

	# A fake warning must be visually indistinguishable from a real warning.
	for attack in ["volley", "charge", "trap", "nothing"]:
		boss.pending = attack
		boss.pending_time = 2.0
		await _frames(2)
		assert(boss.sprite.animation == &"announce", "Art must not spoil the actual queued attack")
	boss.pending_time = 0.01
	await _frames(2)
	assert(boss.sprite.animation == &"taunt")
	await _frames(40)
	assert(boss.sprite.animation == &"idle", "A fake-out must recover instead of sticking on its last pose")

	boss._execute("charge")
	await _frames(2)
	assert(boss.velocity.x < 0.0 and boss.sprite.animation == &"charge" and boss.sprite.flip_h)
	player.position.x = boss.position.x + 400.0
	await _frames(12)
	assert(boss.sprite.flip_h and boss.sprite.frame == 1, "Charge must keep facing its committed direction and reach the dash pose")
	for i in range(15):
		await _frames(1)
		assert(boss.sprite.frame == 1, "Charge must hold the dash pose, not restart its run-up")
	await _frames(25)
	assert(boss.sprite.animation == &"idle" and not boss.sprite.flip_h)

	boss._execute("volley")
	await _frames(2)
	assert(boss.sprite.animation == &"volley")
	var shot: Projectile
	for child in stage.get_children():
		if child is Projectile:
			if shot == null:
				shot = child
			else:
				child.queue_free()
	# The art must leave enemy projectile collision/damage intact.
	shot.position = player.position + Vector2(-60, -6)
	shot.velocity = Vector2(300, 0)
	player.invuln = 0.0
	var health := player.health
	await _frames(24)
	assert(player.health == health - 1 and not is_instance_valid(shot), "Yeral's art-backed orbs must still hit and despawn")
	await _frames(16)
	assert(boss.sprite.animation == &"idle")

	boss._execute("trap")
	await _frames(2)
	assert(boss.sprite.animation == &"trap")
	boss.take_damage(1)
	await _frames(1)
	assert(boss.sprite.modulate.r > 1.0)
	await _frames(10)
	assert(boss.sprite.modulate == Color.WHITE, "Damage highlight must expire even during a held attack pose")
	await _frames(30)
	assert(boss.sprite.animation == &"idle")
	await _second_form(boss, player)
	print("PASS: both forms' fake tells, charge/contact, real orbs/condiments, phase boundaries, safe warnings, jumpable sauce, transform immunity and final collapse")
	stage.queue_free()
	await _frames(1)
	quit()

func _second_form(boss: BossYeral, player: Player) -> void:
	var defeats := [0]
	boss.defeated.connect(func() -> void: defeats[0] += 1)
	player.position = Vector2(7240, 576)
	boss._execute("volley")
	boss._execute("trap")
	assert(not get_nodes_in_group("yeral_attacks").is_empty())
	boss.pending = "charge"
	boss.charge_time = 0.5
	boss.take_damage(boss.health)
	assert(boss.glizzy and boss.transforming and boss.active and defeats[0] == 0)
	assert(boss.health == boss.max_health and boss.phase == 1)
	assert(boss.pending.is_empty() and boss.charge_time == 0.0 and not boss.is_in_group("enemies"))
	player.position = boss.position + Vector2(0, 20)
	player.invuln = 0.0
	var health := player.health
	boss.take_damage(boss.health)
	await _frames(30)
	assert(boss.health == boss.max_health and player.health == health, "Transformation must disable incoming and contact damage")
	assert(get_nodes_in_group("yeral_attacks").is_empty(), "Transformation must remove the previous form's attacks")
	for i in range(240):
		if not boss.transforming:
			break
		await _frames(1)
	assert(not boss.transforming and boss.is_in_group("enemies") and defeats[0] == 0)
	boss.attack_cd = 1000.0
	player.position = Vector2(7240, 576)

	var one_third := floori(boss.max_health / 3.0)
	var two_thirds := floori(boss.max_health * 2.0 / 3.0)
	for boundary in [[two_thirds + 1, 1], [two_thirds, 2], [one_third + 1, 2], [one_third, 3]]:
		boss.take_damage(boss.health - boundary[0])
		assert(boss.phase == boundary[1], "Glizzy must retain the public health-based phase boundaries")
	for attack in ["volley", "charge", "trap", "nothing"]:
		boss.pending = attack
		boss.pending_time = 2.0
		await _frames(2)
		assert(boss.sprite.animation == &"announce", "Glizzy's fake warning must look like the real warning")
	boss.pending_time = 0.01
	await _frames(2)
	assert(boss.sprite.animation == &"taunt")
	await _frames(45)
	assert(boss.sprite.animation == &"idle")

	boss.position = Vector2(7690, 504)
	# Start just outside the solid bodies so depenetration is not mistaken for a charge.
	player.position = boss.position + Vector2(-90, 20)
	await _frames(2)
	player.invuln = 0.0
	health = player.health
	var charge_start := boss.position.x
	boss._execute("charge")
	await _frames(2)
	assert(boss.charge_dir < 0 and boss.position.x < charge_start,
		"Charge start %.2f -> %s, dir %d, velocity %s, wall %s, player %s" % [
			charge_start, boss.position, boss.charge_dir, boss.velocity, boss.is_on_wall(), player.position])
	assert(player.health == health - 2, "The second form's charge must really deal contact damage")
	player.position = boss.position + Vector2(400, 20)
	boss._execute("charge")
	await _frames(2)
	assert(boss.charge_time > 0.0 and boss.velocity.x > 0.0, "A charge away from the previous collision must not be cancelled by stale wall state")
	boss.charge_time = 0.0
	boss.velocity = Vector2.ZERO
	boss.position = Vector2(7690, 504)
	player.position = Vector2(7290, 576)

	var condiments: Array[StringName] = []
	for cast in range(2):
		boss._execute("volley")
		var shot: Projectile
		for attack in get_nodes_in_group("yeral_attacks"):
			if attack is Projectile and shot == null:
				shot = attack
			else:
				attack.queue_free()
		assert(shot != null and shot.target_group == "player")
		var damage := shot.damage
		condiments.append(shot.sprite.animation)
		shot.position = player.position + Vector2(-60, -6)
		shot.velocity = Vector2(300, 0)
		player.invuln = 0.0
		health = player.health
		await _frames(24)
		assert(player.health == health - damage, "Condiment damage must come from the real projectile collision")
		assert(not is_instance_valid(shot), "A real condiment projectile must damage the player and despawn")
	assert(&"ketchup" in condiments and &"mustard" in condiments, "Both supplied condiment effects must participate in combat")

	boss._execute("trap")
	var puddle: BossYeral.SaucePuddle
	for attack in get_nodes_in_group("yeral_attacks"):
		if attack is BossYeral.SaucePuddle and puddle == null:
			puddle = attack
		else:
			attack.queue_free()
	assert(puddle != null)
	player.position = Vector2(puddle.position.x, 576)
	player.invuln = 0.0
	health = player.health
	await _frames(20)
	assert(puddle.warn > 0.0 and player.health == health and not puddle.splash.visible, "A sauce warning must be harmless")
	player.set_physics_process(true)
	Input.action_press(&"jump")
	await _frames(1)
	Input.action_release(&"jump")
	await _frames(10)
	assert(player.position.y < puddle.position.y - 55.0, "The player's real jump must clear the sauce hit zone")
	player.set_physics_process(false)
	player.invuln = 0.0
	for i in range(90):
		if puddle.warn <= 0.0 and puddle.splash.visible:
			break
		await _frames(1)
	assert(puddle.splash.visible and player.health == health, "An airborne player must remain safe when the puddle activates")
	player.position.y = 576
	await _frames(2)
	assert(player.health == health - 2, "Active floor sauce must really damage a grounded player")
	player.position.y = puddle.position.y - 90.0
	player.invuln = 0.0
	health = player.health
	await _frames(5)
	assert(player.health == health, "Jump height must clear an already-active puddle too")

	player.position = boss.position + Vector2(0, 20)
	player.invuln = 0.0
	var health_events := [0]
	boss.health_changed.connect(func(_current: int, _maximum: int) -> void: health_events[0] += 1)
	boss.take_damage(boss.health)
	assert(boss.dying and not boss.active and not boss.is_in_group("enemies") and defeats[0] == 0)
	boss.take_damage(100)
	boss._execute("volley")
	assert(boss.health == 0 and health_events[0] == 1 and defeats[0] == 0, "Repeated damage must be ignored throughout the final collapse")
	health = player.health
	await _frames(2)
	assert(player.health == health and get_nodes_in_group("yeral_attacks").is_empty(), "The collapse must disable contact and clear hazards")
	assert(defeats[0] == 0 and is_instance_valid(boss))
	for i in range(240):
		if not is_instance_valid(boss):
			break
		await _frames(1)
	assert(not is_instance_valid(boss) and defeats[0] == 1, "Only animation completion may emit the one final defeat")
