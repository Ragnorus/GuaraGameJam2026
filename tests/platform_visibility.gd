extends SceneTree

func _initialize() -> void:
	_run.call_deferred()

func _frames(count: int) -> void:
	for i in range(count):
		await physics_frame
		await process_frame

func _run() -> void:
	for path in ["res://scenes/main.tscn", "res://scenes/bichema_level.tscn"]:
		var stage: Node2D = load(path).instantiate()
		root.add_child(stage)
		await _frames(2)
		var platform_count := 0
		for child in stage.get_children():
			if not child is StaticBody2D or child.collision_layer != stage.PLATFORM_LAYER:
				continue
			platform_count += 1
			var body := child as StaticBody2D
			var collider := body.get_child(0) as CollisionShape2D
			assert(collider.one_way_collision, "Visibility must not change one-way jumping")
			var shape := collider.shape as RectangleShape2D
			var marker := body.get_node("LandingEdge") as Node2D
			assert(marker.is_in_group("landing_edges") and marker.z_index == 1)
			assert(body.z_index + marker.z_index < 0, "Platform markers render behind characters, not across boss sprites")
			assert(marker.get_child_count() == 2)
			var backing := marker.get_child(0) as Line2D
			var lip := marker.get_child(1) as Line2D
			assert(backing.width == 7.0 and lip.width == 3.0)
			assert(backing.points == lip.points)
			assert(lip.points[1].is_equal_approx(-shape.size / 2.0))
			assert(lip.points[2].is_equal_approx(Vector2(shape.size.x / 2.0, -shape.size.y / 2.0)))
			assert(lip.points[0].y > lip.points[1].y and lip.points[3].y > lip.points[2].y)
		assert(platform_count >= 5)
		assert(get_nodes_in_group("landing_edges").size() == platform_count, "Only real platforms may have landing markers")
		stage.free()
		await _frames(1)
	print("PASS: every jumpable platform in both stages has exact collision-aligned landing edges, end brackets and contrast backing; one-way collisions preserved")
	quit()
