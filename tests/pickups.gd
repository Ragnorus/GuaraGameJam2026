extends SceneTree

func _initialize() -> void:
	_run.call_deferred()

func _frames(count: int) -> void:
	for i in range(count):
		await physics_frame
		await process_frame

func _pickup_count(stage: Node) -> int:
	var count := 0
	for child in stage.get_children():
		if child is Pickup:
			count += 1
	return count

func _find_pickup(stage: Node, kind: int) -> Pickup:
	for child in stage.get_children():
		if child is Pickup and child.kind == kind:
			return child
	return null

func _run() -> void:
	GameSettings.begin_run()
	var yeral := preload("res://scenes/main.tscn").instantiate()
	root.add_child(yeral)
	await _frames(2)
	assert(_pickup_count(yeral) == 8, "Yeral must place six coins and two medalla cans")
	var player := yeral.get("player") as Player
	var can := _find_pickup(yeral, Pickup.Kind.MEDALLA)
	assert(can != null)
	player.health = 6
	can.global_position = player.global_position
	await _frames(2)
	var hud_label := yeral.get("hud_label") as Label
	assert(player.health == 10 and not is_instance_valid(can), "A medalla can restores four health")
	assert(hud_label.text == "HP 10/10", "Healing refreshes the health HUD")

	var full_can := _find_pickup(yeral, Pickup.Kind.MEDALLA)
	assert(full_can != null)
	full_can.global_position = player.global_position
	await _frames(2)
	assert(player.health == player.max_health and is_instance_valid(full_can), "A full-health player must not consume a medalla can")
	player.health = 6
	player.position.x += 150.0
	await _frames(3)
	player.position.x -= 150.0
	await _frames(3)
	assert(player.health == 10 and not is_instance_valid(full_can), "A preserved medalla can heals after the player is hurt")

	var coin := _find_pickup(yeral, Pickup.Kind.COIN)
	assert(coin != null)
	coin.global_position = player.global_position
	await _frames(2)
	await _frames(1)
	var score_label := yeral.get("score_label") as Label
	assert(GameSettings.score == 5 and not is_instance_valid(coin), "A coin awards five points once")
	assert(score_label.text.begins_with("SCORE 5"), "Collecting a coin updates the score HUD: %s" % score_label.text)

	yeral.queue_free()
	await _frames(1)
	var bichema := preload("res://scenes/bichema_level.tscn").instantiate()
	root.add_child(bichema)
	await _frames(2)
	assert(_pickup_count(bichema) == 11, "Bichema must place eight coins and three medalla cans")
	bichema.queue_free()
	print("PASS: both stages place pickups; medalla healing, health HUD, full-health preservation, and coin score/HUD")
	quit()
