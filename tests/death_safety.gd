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
	for path in ["res://scenes/main.tscn", "res://scenes/bichema_level.tscn"]:
		var stage: Node2D = load(path).instantiate()
		root.add_child(stage)
		await _frames(3)
		var player: Player = stage.player
		player._summon()
		player.meter = player.meter_max
		player._ultimate()
		player._shoot()
		assert(get_nodes_in_group("player_summons").size() == 9, "Include untracked ultimate summons")
		var shot := get_nodes_in_group("player_shots")[0] as Projectile
		var target: Node2D
		for enemy in get_nodes_in_group("enemies"):
			if enemy is Bug:
				target = enemy
				break
		assert(target != null)
		var health: int = target.health
		player.invuln = 0.0
		player.take_damage(10000)
		assert(player.dead and player.minions.is_empty())
		assert(not player.army_effect.visible and not player.ultimate_beam.visible)
		# A queued physics callback in the same frame must not damage or award score.
		shot._on_body_entered(target)
		assert(target.health == health)
		var score := GameSettings.score
		var meter := player.meter
		player._shoot()
		player._summon()
		player._ultimate()
		player.add_meter(10)
		await _frames(5)
		assert(get_nodes_in_group("player_summons").is_empty())
		assert(get_nodes_in_group("player_shots").is_empty())
		assert(GameSettings.score == score and player.meter == meter and target.health == health)
		stage.free()
		await _frames(1)
	print("PASS: both stages despawn normal/ultimate summons and shots on death; queued hits, dead actions, meter and score cannot advance")
	quit()
