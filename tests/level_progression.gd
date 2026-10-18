extends SceneTree

# Run: Godot --headless --path . --fixed-fps 60 --script res://tests/level_progression.gd
func _initialize() -> void:
	_run.call_deferred()

func _frames(count: int) -> void:
	for i in range(count):
		await physics_frame
		await process_frame

func _enter_boss(stage: Node) -> Node:
	var player := stage.get("player") as Player
	player.health = 1000
	var route := stage.get("yeral_route") as YeralRoute
	if route != null:
		route._set_area(5)
		player.position = Vector2(route.AREAS[5].position.x + 120.0, 564)
		route.start_boss_intro()
		await _frames(350)
	else:
		var bichema_route := stage.get("bichema_route") as BichemaRoute
		if bichema_route != null:
			bichema_route._set_area(5)
		player.position = Vector2(float(stage.get("boss_trigger_x")) + 100.0, 576)
	await _frames(3)
	for enemy in get_nodes_in_group("enemies"):
		if enemy is BossYeral or enemy is BossEvilGenius:
			return enemy
	return null

func _check_phases(boss: Node) -> void:
	var max_health: int = boss.get("max_health")
	var one_third := floori(max_health / 3.0)
	var two_thirds := floori(max_health * 2.0 / 3.0)
	for boundary in [[two_thirds + 1, 1], [two_thirds, 2], [one_third + 1, 2], [one_third, 3]]:
		boss.take_damage(boss.health - boundary[0])
		assert(boss.phase == boundary[1], "Boss phases must change at the one-third and two-thirds boundaries")

func _restart() -> void:
	Input.action_press(&"restart")
	await _frames(1)
	Input.action_release(&"restart")
	await _frames(3)

func _transform(boss: BossYeral, stage: Node) -> void:
	boss.take_damage(boss.health)
	assert(boss.glizzy and boss.transforming and boss.active)
	assert(boss.health == boss.max_health and boss.phase == 1, "First depletion must refill a new health pool")
	assert(not stage.get("finished") and current_scene == stage, "Transformation is not a stage clear")
	var health := boss.health
	boss.take_damage(health)
	assert(boss.health == health and not boss.dying, "Transformation must ignore damage")

func _wait_for_transform(boss: BossYeral) -> void:
	for i in range(240):
		if not boss.transforming:
			break
		await _frames(1)
	assert(not boss.transforming and boss.is_in_group("enemies"), "The real transformation animation must resume combat")

func _transform_ema(boss: BossEvilGenius, stage: Node) -> void:
	var score := GameSettings.score
	boss.take_damage(boss.health)
	assert(boss.costume_form and boss.transforming and boss.active)
	assert(boss.health == GameSettings.scale_health(72) and boss.phase == 1, "Ema's first depletion must refill the difficulty-scaled costume pool")
	assert(not stage.get("finished") and current_scene == stage and GameSettings.score == score, "Ema transformation must not award boss points or clear the stage")
	var health := boss.health
	boss.take_damage(health)
	assert(boss.health == health and not boss.dying, "Ema's actual transformation must ignore damage")

func _wait_for_ema_transform(boss: BossEvilGenius) -> void:
	for i in range(240):
		if not boss.transforming:
			break
		await _frames(1)
	assert(not boss.transforming and boss.is_in_group("enemies"), "Ema's nonlooping transformation must return to combat")

func _run() -> void:
	assert(change_scene_to_file("res://scenes/main.tscn") == OK)
	await _frames(2)
	var old_stage := current_scene
	(old_stage.get("player") as Player).position = Vector2(float(old_stage.get("boss_trigger_x")) + 100.0, 576)
	await _restart()
	assert(current_scene != old_stage and not current_scene.get("boss_started"))
	assert((current_scene.get("player") as Player).position.x == 100.0)
	var yeral_stage := current_scene
	var yeral := await _enter_boss(yeral_stage) as BossYeral
	assert(yeral != null)
	_check_phases(yeral)
	_transform(yeral, yeral_stage)
	await _restart()
	assert(current_scene != yeral_stage, "Restart during transformation must reset the encounter")
	yeral_stage = current_scene
	yeral = await _enter_boss(yeral_stage) as BossYeral
	assert(yeral != null and not yeral.glizzy and yeral.health == yeral.max_health)
	_transform(yeral, yeral_stage)
	await _wait_for_transform(yeral)
	assert(current_scene == yeral_stage and not yeral_stage.get("finished"))
	_check_phases(yeral)
	await _restart()
	assert(current_scene != yeral_stage, "Restart in the second form must restore Yeral")
	yeral_stage = current_scene
	yeral = await _enter_boss(yeral_stage) as BossYeral
	assert(yeral != null and not yeral.glizzy and yeral.phase == 1)
	_transform(yeral, yeral_stage)
	await _wait_for_transform(yeral)
	yeral.take_damage(yeral.health)
	assert(yeral.dying and not yeral_stage.get("finished"), "The second depletion must wait for the collapse")
	await _frames(1)
	assert(current_scene == yeral_stage and not yeral_stage.get("finished"))
	await _frames(360)
	assert(current_scene != yeral_stage, "The final collapse must open Bichema's World rather than leave a dead-end stage")
	assert(current_scene.scene_file_path == "res://scenes/bichema_level.tscn")

	var ema_stage := current_scene
	var ema := await _enter_boss(ema_stage) as BossEvilGenius
	assert(ema != null and not ema.costume_form and ema.health == GameSettings.scale_health(60))
	_check_phases(ema)
	_transform_ema(ema, ema_stage)
	await _restart()
	assert(current_scene != ema_stage and current_scene.scene_file_path == "res://scenes/bichema_level.tscn", "Restart during Ema transformation must reset the encounter")
	ema_stage = current_scene
	ema = await _enter_boss(ema_stage) as BossEvilGenius
	assert(ema != null and not ema.costume_form and not ema.transforming and ema.phase == 1 and ema.health == ema.max_health)
	_transform_ema(ema, ema_stage)
	await _wait_for_ema_transform(ema)
	assert(current_scene == ema_stage and not ema_stage.get("finished"))
	_check_phases(ema)
	await _restart()
	assert(current_scene != ema_stage, "Restart in Ema costume form must restore the original form")
	ema_stage = current_scene
	ema = await _enter_boss(ema_stage) as BossEvilGenius
	assert(ema != null and not ema.costume_form and ema.phase == 1 and ema.health == GameSettings.scale_health(60))
	_transform_ema(ema, ema_stage)
	await _wait_for_ema_transform(ema)
	var final_score := GameSettings.score
	ema.take_damage(ema.health)
	assert(ema.dying and not ema_stage.get("finished") and GameSettings.score == final_score, "Ema must complete the final collapse before score or stage clear")
	await _frames(1)
	assert(current_scene == ema_stage and not ema_stage.get("finished"))
	var saw_ending_fade := false
	for i in range(480):
		if current_scene != ema_stage:
			break
		if ema_stage.get("ending_transition"):
			assert((ema_stage.get("player") as Player).controls_locked)
			for child in ema_stage.get_children():
				if child is CanvasLayer and child.layer == 100:
					var fade := child.get_child(0) as ColorRect
					saw_ending_fade = saw_ending_fade or (fade.color.a > 0.0 and fade.color.a < 1.0)
		await _frames(1)
	await _frames(2)
	assert(saw_ending_fade, "The frozen final-stage victory must visibly fade before the credits")
	assert(current_scene.scene_file_path == "res://scenes/end_credits.tscn", "The final costume collapse must fade into the end credits")

	assert(change_scene_to_file("res://scenes/main.tscn") == OK)
	await _frames(2)
	var dead_yeral_stage := current_scene
	var dead_yeral := await _enter_boss(dead_yeral_stage) as BossYeral
	_transform(dead_yeral, dead_yeral_stage)
	await _wait_for_transform(dead_yeral)
	dead_yeral.take_damage(dead_yeral.health)
	var dead_yeral_player := dead_yeral_stage.get("player") as Player
	dead_yeral_player.invuln = 0.0
	dead_yeral_player.take_damage(dead_yeral_player.health)
	await _frames(360)
	assert(current_scene == dead_yeral_stage and not dead_yeral_stage.get("finished"), "Player death during the final collapse must block advancement")
	await _restart()
	assert(current_scene != dead_yeral_stage)
	assert(not (current_scene.get("player") as Player).dead)

	assert(change_scene_to_file("res://scenes/bichema_level.tscn") == OK)
	await _frames(2)
	var dead_stage := current_scene
	var dead_boss := await _enter_boss(dead_stage) as BossEvilGenius
	_transform_ema(dead_boss, dead_stage)
	await _wait_for_ema_transform(dead_boss)
	dead_boss.take_damage(dead_boss.health)
	assert(dead_boss.dying and not dead_stage.get("finished"))
	var dead_player := dead_stage.get("player") as Player
	dead_player.invuln = 0.0
	dead_player.take_damage(dead_player.health)
	await _frames(360)
	assert(current_scene == dead_stage and not dead_stage.get("finished"), "Player death during Ema's costume collapse must block final-stage clear")
	await _restart()
	assert(current_scene != dead_stage and current_scene.scene_file_path == "res://scenes/bichema_level.tscn")
	assert(not (current_scene.get("player") as Player).dead)
	print("PASS: entrance/transform/second-form restart; both health pools and phases; final collapse -> Bichema's World -> credits; player death blocks victory")
	quit()
