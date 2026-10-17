extends SceneTree

# Run: Godot --headless --path . --fixed-fps 60 --script res://tests/difficulty_score.gd
func _initialize() -> void:
	_run.call_deferred()

func _frames(count: int) -> void:
	for i in range(count):
		await physics_frame
		await process_frame

func _run() -> void:
	assert(GameSettings.DIFFICULTIES.size() == 4)
	assert(GameSettings.DIFFICULTIES[0]["name"] == "Baby Guara" and GameSettings.DIFFICULTIES[3]["name"] == "OG Guara")
	for i in range(1, 4):
		var easier: Dictionary = GameSettings.DIFFICULTIES[i - 1]
		var harder: Dictionary = GameSettings.DIFFICULTIES[i]
		assert(harder["hp"] >= easier["hp"] and harder["damage"] >= easier["damage"] and harder["aggro"] >= easier["aggro"])

	GameSettings.difficulty = 0
	assert(GameSettings.scale_health(40) < 40 and GameSettings.incoming_damage(2) == 1)
	GameSettings.difficulty = 1
	assert(GameSettings.scale_health(40) == 40 and GameSettings.incoming_damage(2) == 2)
	GameSettings.difficulty = 3
	assert(GameSettings.scale_health(40) == 100 and GameSettings.incoming_damage(2) == 4)
	assert(GameSettings.scale_health(1) >= 1)

	# Mob kills score their points, and a restart reverts to the level's starting score.
	GameSettings.difficulty = 1
	GameSettings.begin_run()
	var stage := preload("res://scenes/main.tscn").instantiate()
	root.add_child(stage)
	await _frames(2)
	var mob: Bug = null
	for enemy in get_nodes_in_group("enemies"):
		if enemy is Bug:
			mob = enemy
			break
	assert(mob != null and mob.points >= 1 and mob.points <= 5)
	var expected := mob.points
	mob.take_damage(mob.health)
	assert(GameSettings.score == expected, "Killing a mob must award its points")
	assert(GameSettings.high_score() == expected)
	stage.queue_free()
	await _frames(1)

	GameSettings.begin_run()
	GameSettings.add_score(GameSettings.BOSS_POINTS)
	assert(GameSettings.score == 10)
	GameSettings.begin_level()
	assert(GameSettings.score == 0, "A level restart must drop points earned in that attempt")
	GameSettings.begin_run()
	print("PASS: four difficulties scale health/damage/aggression monotonically; mob and boss points; level restart score")
	quit()
