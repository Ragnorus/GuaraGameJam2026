extends SceneTree

# Run: Godot --headless --path . --fixed-fps 60 --script res://tests/player_actions.gd
func _initialize() -> void:
	_run.call_deferred()

func _frames(count: int) -> void:
	for i in range(count):
		await physics_frame
		await process_frame

func _tap(action: StringName) -> void:
	Input.action_press(action)
	await _frames(1)
	Input.action_release(action)
	await _frames(1)

func _hold_jump() -> void:
	Input.action_press(&"jump")
	await _frames(14)
	Input.action_release(&"jump")
	await _frames(1)

func _run() -> void:
	GameSettings.dash_unlocked = true
	var stage := preload("res://scenes/main.tscn").instantiate()
	root.add_child(stage)
	var player := stage.get("player") as Player
	GameSettings.dash_unlocked = false
	for enemy in get_nodes_in_group("enemies"):
		enemy.queue_free()
	await _frames(60)
	assert(player.is_on_floor() and player.player_sprite.animation == &"idle")
	var outline := player.player_sprite.material as ShaderMaterial
	assert(outline != null and outline.shader == Player.OUTLINE_SHADER)
	for animation in [&"idle", &"run", &"jump", &"dash", &"shoot", &"hurt", &"death"]:
		player.player_sprite.animation = animation
		for frame in range(Player.CHARACTER_FRAMES.get_frame_count(animation)):
			player.player_sprite.frame = frame
			var texture := Player.CHARACTER_FRAMES.get_frame_texture(animation, frame) as AtlasTexture
			var bounds: Vector4 = outline.get_shader_parameter("frame_uv")
			assert(is_equal_approx(bounds.x, (texture.region.position.x + 0.5) / texture.atlas.get_width()))
			assert(is_equal_approx(bounds.w, (texture.region.end.y - 0.5) / texture.atlas.get_height()))
	player.player_sprite.play(&"idle")
	var idle_frame := player.player_sprite.frame
	await _frames(12)
	assert(player.player_sprite.frame != idle_frame, "Idle must actually animate")

	Input.action_press(&"move_left")
	await _frames(12)
	assert(player.velocity.x < 0.0 and player.player_sprite.flip_h)
	assert(player.player_sprite.animation == &"run")
	Input.action_release(&"move_left")
	Input.action_press(&"move_right")
	await _frames(12)
	assert(player.velocity.x > 0.0 and not player.player_sprite.flip_h)
	Input.action_release(&"move_right")
	await _frames(2)
	await _tap(&"dash")
	assert(player.dash_time == 0.0, "Dash must remain locked until Yeral is defeated")
	GameSettings.dash_unlocked = true

	await _tap(&"jump")
	assert(player.velocity.y < 0.0 and player.player_sprite.animation == &"jump")
	await _hold_jump()
	assert(player.jumps_remaining == 0 and player.player_sprite.animation == &"double_jump")
	await _tap(&"shoot")
	assert(player.player_sprite.animation == &"shoot" and not player.is_on_floor())
	var shot: Projectile
	for child in stage.get_children():
		if child is Projectile:
			shot = child
	assert(shot != null and shot.sprite != null and shot.sprite.animation == &"projectile")
	await _frames(25)
	assert(player.player_sprite.animation == &"fall")
	var saw_landing := false
	for i in range(60):
		await _frames(1)
		if player.player_sprite.animation == &"land":
			saw_landing = true
	assert(saw_landing and player.is_on_floor(), "Falling must transition through landing")
	await _frames(20)
	assert(player.player_sprite.animation == &"idle")

	Input.action_press(&"shoot")
	var finished_shot := false
	for i in range(30):
		await _frames(1)
		if player.player_sprite.animation == &"shoot":
			finished_shot = finished_shot or player.player_sprite.frame == player.CHARACTER_FRAMES.get_frame_count(&"shoot") - 1
	Input.action_release(&"shoot")
	assert(finished_shot, "Held shooting must reach the final firing pose before the next shot")
	await _frames(20)
	await _tap(&"dash")
	assert(player.dash_time > 0.0 and player.player_sprite.animation == &"dash")
	var finished_dash := false
	for i in range(20):
		await _frames(1)
		if player.player_sprite.animation == &"dash":
			finished_dash = finished_dash or player.player_sprite.frame == player.CHARACTER_FRAMES.get_frame_count(&"dash") - 1
	assert(finished_dash, "Dash must display its final frame before movement ends")
	assert(player.player_sprite.animation == &"idle")
	await _frames(45)
	Input.action_press(&"dash")
	await _frames(1)
	Input.action_release(&"dash")
	Input.action_press(&"jump")
	await _frames(1)
	assert(player.dash_vector == Vector2.UP and player.velocity.y < -Player.DASH_SPEED,
			"Pressing jump during a forward dash must redirect it straight up")
	Input.action_release(&"jump")
	await _frames(20)
	await _tap(&"summon")
	assert(player.minions.size() == 1 and player.player_sprite.animation == &"summon")
	var shadow := player.minions[0] as Minion
	assert(shadow.sprite.animation == &"shadow_spawn")
	await _frames(40)
	var enemy := Bug.new()
	enemy.position = shadow.position + Vector2(15, 0)
	stage.add_child(enemy)
	enemy.set_physics_process(false)
	await _frames(1)
	assert(enemy.health == 2 and shadow.sprite.animation == &"shadow_attack")
	enemy.queue_free()
	await _frames(20)
	await _tap(&"recall")
	assert(player.player_sprite.animation == &"recall" and shadow.recalled > 0.0)
	assert(shadow.sprite.animation == &"shadow_recall")
	await _frames(130)
	assert(shadow.sprite.animation != &"shadow_recall")

	player.meter = player.meter_max
	await _tap(&"ultimate")
	assert(player.meter == 0.0 and player.player_sprite.animation == &"ultimate")
	assert(player.ultimate_beam.visible and player.army_effect.visible)
	await _frames(60)
	assert(not player.ultimate_beam.visible and not player.army_effect.visible)

	player.take_damage(1)
	assert(player.player_sprite.animation == &"hurt" and player.player_sprite.visible)
	var health := player.health
	player.take_damage(1)
	assert(player.health == health, "Invulnerability must still reject repeat damage")
	await _tap(&"shoot")
	assert(player.player_sprite.animation == &"hurt", "Shooting must not cancel the hurt reaction")
	await _frames(65)
	player.take_damage(player.health)
	assert(player.dead and player.player_sprite.animation == &"death")
	await _frames(120)
	assert(player.is_on_floor() and player.player_sprite.visible)
	assert(player.player_sprite.animation == &"death" and not player.player_sprite.is_playing())
	assert(player.player_sprite.frame == player.CHARACTER_FRAMES.get_frame_count(&"death") - 1)
	print("PASS: movement, jump/double-jump, air shooting, fall/landing, dash, shadows, ultimate, hurt, death")
	stage.queue_free()
	await _frames(1)
	quit()
