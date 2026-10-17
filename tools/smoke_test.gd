extends SceneTree

# Headless smoke test: godot --headless --path . -s tools/smoke_test.gd -- <scene>
func _initialize() -> void:
	var path := "res://scenes/main.tscn"
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		path = args[0]
	var scene: Node = load(path).instantiate()
	root.add_child(scene)
	await create_timer(0.5).timeout
	var player: Node2D = scene.get("player")
	if player == null:
		print("SMOKE: no player in ", path)
		quit(1)
		return
	player.global_position.x = 2200.0
	await create_timer(1.0).timeout
	var boss: Node = null
	for e in get_nodes_in_group("enemies"):
		if e.has_method("activate"):
			boss = e
	print("SMOKE boss: ", boss)
	if boss != null:
		for i in range(40):
			boss.take_damage(1)
			await create_timer(0.25).timeout
			if not is_instance_valid(boss):
				break
	print("SMOKE done ", path)
	quit(0)
