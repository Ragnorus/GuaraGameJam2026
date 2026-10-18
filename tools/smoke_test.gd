extends SceneTree

# Headless scene smoke: godot --headless --path . -s tools/smoke_test.gd -- <scene>
func _initialize() -> void:
	_run.call_deferred()

func _fail(reason: String) -> void:
	push_error("SMOKE FAILED: " + reason)
	quit(1)

func _run() -> void:
	# Also bound failures that leave an awaited scene or animation stuck.
	create_timer(35.0).timeout.connect(func() -> void: _fail("Boss did not finish within 35 seconds"))
	var path := "res://scenes/main.tscn"
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		path = args[0]
	var packed := load(path) as PackedScene
	if packed == null:
		_fail("Could not load scene " + path)
		return
	var scene := packed.instantiate()
	root.add_child(scene)
	await create_timer(0.5).timeout
	var player := scene.get("player") as Player
	if player == null:
		_fail("No player in " + path)
		return
	player.health = 10000
	var route := scene.get("yeral_route") as YeralRoute
	if route != null:
		route._set_area(5)
		player.position = Vector2(route.AREAS[5].position.x + 120.0, 564)
		route.start_boss_intro()
		await create_timer(route.INTRO_AUDIO.get_length() + 0.5).timeout
	else:
		player.global_position.x = float(scene.get("boss_trigger_x")) + 100.0
	await create_timer(1.0).timeout
	var boss: Node
	for enemy in get_nodes_in_group("enemies"):
		if enemy is BossYeral or enemy is BossEvilGenius:
			boss = enemy
			break
	if boss == null:
		_fail("No boss spawned in " + path)
		return
	print("SMOKE boss: ", boss)
	var defeats := [0]
	var transforms := [0]
	boss.defeated.connect(func() -> void: defeats[0] += 1)
	boss.transformed.connect(func() -> void:
		transforms[0] += 1
		var second_form: bool = boss.glizzy if boss is BossYeral else boss.costume_form
		if not second_form or not boss.transforming or boss.health != boss.max_health or scene.get("finished"):
			_fail("First health pool did not enter a protected, refilled second form")
			return
		var health: int = boss.health
		boss.take_damage(health)
		if boss.health != health or boss.dying:
			_fail("Transformation did not protect the second health pool")
	)
	for i in range(600):
		if defeats[0] > 0:
			break
		if not is_instance_valid(boss):
			_fail("Boss disappeared without emitting defeated")
			return
		boss.take_damage(1)
		await create_timer(0.05).timeout
	if defeats[0] != 1 or not scene.get("finished") or player.dead:
		_fail("Boss did not produce exactly one live-player stage clear")
		return
	if transforms[0] != 1:
		_fail("Boss did not transform exactly once before the final defeat")
		return
	print("SMOKE PASS: ", path, " defeated; forms=2")
	quit(0)
