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
	player.position = Vector2(2200, 576)
	await _frames(3)
	for enemy in get_nodes_in_group("enemies"):
		if enemy is BossYeral or enemy is BossEma:
			return enemy
	return null

func _check_phases(boss: Node) -> void:
	var max_health: int = boss.get("max_health")
	var one_third := floori(max_health / 3.0)
	var two_thirds := floori(max_health * 2.0 / 3.0)
	for boundary in [[two_thirds + 1, 1], [two_thirds, 2], [one_third + 1, 2], [one_third, 3]]:
		boss.take_damage(boss.health - boundary[0])
		assert(boss.phase == boundary[1], "Boss phases must change at the one-third and two-thirds boundaries")

func _run() -> void:
	assert(change_scene_to_file("res://scenes/main.tscn") == OK)
	await _frames(2)
	var old_stage := current_scene
	(old_stage.get("player") as Player).position = Vector2(2200, 576)
	Input.action_press(&"restart")
	await _frames(1)
	Input.action_release(&"restart")
	await _frames(3)
	assert(current_scene != old_stage and not current_scene.get("boss_started"))
	assert((current_scene.get("player") as Player).position.x == 100.0)
	var yeral_stage := current_scene
	var yeral := await _enter_boss(yeral_stage)
	assert(yeral is BossYeral)
	_check_phases(yeral)
	yeral.take_damage(yeral.health)
	await _frames(240)
	assert(current_scene != yeral_stage, "Yeral's clear must open Ema rather than leave a dead-end stage")
	assert(current_scene.scene_file_path == "res://scenes/ema_level.tscn")

	var ema_stage := current_scene
	var ema := await _enter_boss(ema_stage)
	assert(ema is BossEma)
	_check_phases(ema)
	ema.take_damage(ema.health)
	await _frames(240)
	assert(current_scene.scene_file_path == "res://scenes/level_select.tscn", "The last available stage must return to level selection")

	assert(change_scene_to_file("res://scenes/ema_level.tscn") == OK)
	await _frames(2)
	var dead_stage := current_scene
	var dead_boss := await _enter_boss(dead_stage)
	var dead_player := dead_stage.get("player") as Player
	dead_player.invuln = 0.0
	dead_player.take_damage(dead_player.health)
	dead_boss.take_damage(dead_boss.health)
	await _frames(240)
	assert(current_scene == dead_stage and not dead_stage.get("finished"), "Death before a boss defeat must not advance the level")
	Input.action_press(&"restart")
	await _frames(1)
	Input.action_release(&"restart")
	await _frames(3)
	assert(current_scene != dead_stage and current_scene.scene_file_path == "res://scenes/ema_level.tscn")
	assert(not (current_scene.get("player") as Player).dead)
	print("PASS: boss-entrance restart; phase boundaries; Yeral -> Ema -> level select; death blocks victory; stage restart")
	quit()
