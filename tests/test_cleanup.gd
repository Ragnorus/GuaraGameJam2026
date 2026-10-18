extends RefCounted

static func finish(tree: SceneTree) -> void:
	tree.paused = true
	GameAudio.stop_music()
	for child in tree.root.get_children():
		_silence(child)
		child.queue_free()
	# Fixed-FPS tests can finish before the real audio mixer releases its playbacks.
	var deadline := Time.get_ticks_msec() + 350
	while Time.get_ticks_msec() < deadline:
		OS.delay_msec(10)
		await tree.process_frame

static func _silence(node: Node) -> void:
	if node is AudioStreamPlayer or node is AudioStreamPlayer2D:
		node.stop()
		node.stream = null
	for child in node.get_children():
		_silence(child)
