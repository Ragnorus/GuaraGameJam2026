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
	player.position = Vector2(2200, 576)
	await _frames(3)
	var boss: BossYeral
	for enemy in get_nodes_in_group("enemies"):
		if enemy is BossYeral:
			boss = enemy
		else:
			enemy.queue_free()
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
	shot.position = player.position + Vector2(60, -6)
	shot.velocity = Vector2(-300, 0)
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
	print("PASS: Yeral facing, indistinguishable fake tells, charge direction/pose, attack recovery, orb damage, hit highlight")
	stage.queue_free()
	await _frames(1)
	quit()
