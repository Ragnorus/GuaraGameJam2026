extends SceneTree

var stage: Node
var route: YeralRoute
var player: Player
var sergeant: Sergeant

func _initialize() -> void:
	_run.call_deferred()

func _frames(count: int) -> void:
	for i in range(count):
		await physics_frame
		await process_frame

# Puts the player on a sergeant platform with full health and no lingering status.
func _place(index: int, x: float) -> void:
	var rect: Rect2 = route.SERGEANT_PLATFORMS[index]
	player.position = Vector2(x, rect.position.y - 36.0)
	player.velocity = Vector2.ZERO
	player.health = player.max_health
	player.invuln = 0.0
	player.clear_status()
	player.stun_guard = 0.0
	await _frames(3)
	assert(player.is_on_floor())

func _hold() -> void:
	sergeant.ai_enabled = false
	sergeant.cooldown = 1000.0
	sergeant.clear_attacks()
	sergeant._set_state(Sergeant.State.IDLE, &"idle")

func _stand(index: int, x: float) -> void:
	_hold()
	sergeant.platform_index = index
	sergeant.position = Vector2(x, sergeant.standing_y(index))
	sergeant.velocity = Vector2.ZERO

# Puts the player out of reach on a bank; invulnerable so every charge is a deliberate miss.
func _player_on_bank(left := true) -> void:
	player.position = Vector2(2620, 1320 - 36.0) if left else Vector2(4060, 1200 - 36.0)
	player.velocity = Vector2.ZERO
	player.health = player.max_health
	player.clear_status()
	player.invuln = 1000.0
	await _frames(3)

# Runs until the sergeant settles back to IDLE on a block; returns the visited states.
func _until_idle(max_frames: int) -> Array:
	var seen: Array = []
	for i in range(max_frames):
		await _frames(1)
		if not sergeant.state in seen:
			seen.append(sergeant.state)
		if sergeant.state == Sergeant.State.IDLE and i > 2:
			break
	return seen

func _on_block(index: int) -> bool:
	var rect: Rect2 = route.SERGEANT_PLATFORMS[index]
	return sergeant.platform_index == index and is_equal_approx(sergeant.position.y + Sergeant.BODY.y / 2.0, rect.position.y) \
			and sergeant.position.x >= rect.position.x and sergeant.position.x <= rect.end.x

func _run() -> void:
	GameSettings.loaded = true
	GameSettings.music_on = false
	GameSettings.sfx_on = false
	assert(change_scene_to_file("res://scenes/main.tscn") == OK)
	await _frames(3)
	stage = current_scene
	route = stage.get("yeral_route") as YeralRoute
	player = stage.get("player") as Player
	sergeant = route.sergeant
	assert(sergeant is Sergeant and sergeant in route.room_enemies[2])
	assert(sergeant.health == GameSettings.scale_health(12) and sergeant.is_in_group("enemies"))
	route._set_area(2)
	route._warn_new_enemy()
	await _frames(130)
	var message = stage.get("message")
	assert(message.text == route.NEW_ENEMY_TEXT, "Area 3 warns about the new enemy")
	await _frames(170)
	assert(message.text == "", "The warning clears like other stage messages")
	var p2: Rect2 = route.SERGEANT_PLATFORMS[1]
	assert(is_equal_approx(sergeant.position.y + Sergeant.BODY.y / 2.0, p2.position.y), "Sergeant stands on the middle fixed block")
	for name in ["idle", "charge", "punch", "scream", "transform", "rage_idle", "rage_charge", "rage_punch", "rage_scream", "wave", "rage_wave", "death", "jump", "rage_jump"]:
		assert(Sergeant.FRAMES.has_animation(name), name)

	# Football charge: shoves the player off the block towards the acid.
	_hold()
	sergeant.position.x = p2.end.x - 40.0
	await _place(1, p2.position.x + 50.0)
	sergeant.start_charge()
	var hit := false
	for i in range(90):
		await _frames(1)
		if player.knockback_time > 0.0:
			hit = true
			break
	assert(hit and player.velocity.x < -500.0 and player.velocity.y < 0.0, "Charge knocks the player back and up")
	assert(player.health < player.max_health)
	var input_free_x := player.position.x
	Input.action_press(&"move_right")
	await _frames(12)
	Input.action_release(&"move_right")
	assert(player.position.x < input_free_x and player.position.x < p2.position.x, "Knockback overrides input and pushes past the block edge")

	# Punch: launches the player upward (a bounce).
	_hold()
	sergeant.position.x = p2.get_center().x
	await _place(1, sergeant.position.x + 80.0)
	sergeant.start_punch()
	hit = false
	for i in range(60):
		await _frames(1)
		if player.knockback_time > 0.0:
			hit = true
			break
	assert(hit and player.velocity.y < -500.0 and player.velocity.x > 400.0, "Punch bounces the player up and away")

	# Scream: damage plus stun, no shove; stun stars show and input is ignored.
	_hold()
	sergeant.position.x = p2.position.x + 40.0
	await _place(1, p2.end.x - 30.0)
	sergeant.start_scream()
	var stunned := false
	for i in range(120):
		await _frames(1)
		if player.stun_time > 0.0:
			stunned = true
			break
	assert(stunned and player.knockback_time == 0.0 and player.health < player.max_health)
	assert(absf(player.velocity.x) < 1.0, "The scream never shoves")
	assert(get_nodes_in_group("sergeant_attacks").is_empty(), "A wave that lands is consumed")
	await _frames(1)
	assert(player.stun_fx.visible, "Stun stars appear over the player's head")
	var stun_x := player.position.x
	Input.action_press(&"move_left")
	Input.action_press(&"shoot")
	await _frames(10)
	Input.action_release(&"move_left")
	Input.action_release(&"shoot")
	assert(absf(player.position.x - stun_x) < 2.0 and player.shoot_cd == 0.0, "Stunned players cannot move or shoot")
	# A second stun right after recovering is blocked by the guard window.
	player.stun_time = 0.0
	player.invuln = 0.0
	assert(player.hit_by(1, Vector2.ZERO, 1.0) and player.stun_time == 0.0, "Stun guard prevents stun-lock")
	await _frames(2)
	assert(not player.stun_fx.visible)

	# Missed charge off P1's inner edge: he falls into the acid, survives, splashes and jumps
	# (jump pose) back onto the nearest block, then resumes his AI.
	var p1: Rect2 = route.SERGEANT_PLATFORMS[0]
	var p3: Rect2 = route.SERGEANT_PLATFORMS[2]
	await _player_on_bank(false)
	_stand(0, p1.end.x - 120.0)
	var health_before := sergeant.health
	var escapes_before := sergeant.acid_escapes
	sergeant.start_charge()
	assert(sergeant.facing == 1)
	var used_jump_pose := false
	var seen: Array = []
	var splashes := 0
	for i in range(240):
		await _frames(1)
		if not sergeant.state in seen:
			seen.append(sergeant.state)
		if sergeant.state == Sergeant.State.LEAP and sergeant.sprite.animation == &"jump":
			used_jump_pose = true
		for node in sergeant.get_parent().get_children():
			if node is Sergeant.AcidSplash:
				splashes += 1
		if sergeant.state == Sergeant.State.IDLE:
			break
	assert(Sergeant.State.FALL in seen and Sergeant.State.LEAP in seen, "Missed charge falls, then leaps out: %s" % [seen])
	assert(used_jump_pose, "The escape uses the jump pose")
	assert(sergeant.acid_escapes == escapes_before + 1 and not sergeant.dead and sergeant.health == health_before, "Acid never hurts the sergeant")
	assert(_on_block(1), "Recovers onto the nearest block (P2 above the gap): %s" % sergeant.position)
	assert(splashes >= 1, "Touching the acid splashes")

	# Missed charge off P3's outer edge: the far bank's wall stops him, he drops into the acid and hops back to P3.
	escapes_before = sergeant.acid_escapes
	_stand(2, p3.position.x + 120.0)
	sergeant.start_charge()
	seen = await _until_idle(240)
	assert(sergeant.acid_escapes == escapes_before + 1 and _on_block(2), "Far-side miss: %s %s" % [seen, sergeant.position])

	# Missed charge off P1's outer edge lands on the entrance bank (not a block), so he hops straight back.
	await _player_on_bank(true)
	escapes_before = sergeant.acid_escapes
	_stand(0, p1.position.x + 120.0)
	sergeant.start_charge()
	assert(sergeant.facing == -1)
	seen = await _until_idle(240)
	assert(Sergeant.State.FALL in seen and Sergeant.State.LEAP in seen and sergeant.acid_escapes == escapes_before, "Bank landing: %s" % [seen])
	assert(_on_block(0), "Hops from the bank back onto P1: %s" % sergeant.position)

	# Missed charge from the middle block carries him onto a side block without touching the acid.
	await _player_on_bank(false)
	escapes_before = sergeant.acid_escapes
	_stand(1, p2.position.x + 60.0)
	sergeant.start_charge()
	assert(sergeant.facing == 1)
	seen = await _until_idle(240)
	assert(Sergeant.State.FALL in seen and sergeant.acid_escapes == escapes_before, "Lands on a block below without the acid")
	assert(_on_block(2), "Charge momentum carries him onto P3: %s" % sergeant.position)

	# Crossing 50% while falling defers the rage until he is back on a block.
	_stand(0, p1.end.x - 120.0)
	sergeant.start_charge()
	for i in range(120):
		await _frames(1)
		if sergeant.state == Sergeant.State.FALL:
			break
	assert(sergeant.state == Sergeant.State.FALL)
	sergeant.take_damage(sergeant.health - sergeant.max_health / 2)
	assert(sergeant.pending_rage and sergeant.state == Sergeant.State.FALL, "No mid-air transform")
	for i in range(240):
		await _frames(1)
		if sergeant.state == Sergeant.State.TRANSFORM:
			break
	assert(sergeant.state == Sergeant.State.TRANSFORM and (_on_block(0) or _on_block(1)), "Transforms after landing")
	route.speech.hide()
	# Undo the rage so the dedicated rage checks below start from normal form.
	sergeant.raged = false
	sergeant.pending_rage = false
	sergeant.health = sergeant.max_health
	await _frames(3)

	# Autonomous: with AI on he keeps moving and attacking without ever standing idle for long.
	_stand(1, p2.get_center().x)
	sergeant.ai_enabled = true
	sergeant.cooldown = 0.0
	await _place(0, p1.get_center().x)
	player.invuln = 1000.0
	var attacks_before := sergeant.attack_count
	var still_frames := 0
	var longest_still := 0
	var last_pos := sergeant.position
	for i in range(480):
		await _frames(1)
		if sergeant.position.is_equal_approx(last_pos) and sergeant.state == Sergeant.State.IDLE:
			still_frames += 1
			longest_still = maxi(longest_still, still_frames)
		else:
			still_frames = 0
		last_pos = sergeant.position
		assert(not sergeant.dead)
	assert(sergeant.attack_count - attacks_before >= 3, "Attacks repeatedly: %d" % (sergeant.attack_count - attacks_before))
	assert(longest_still < 30, "Never stands still while idle (longest %d frames)" % longest_still)
	player.invuln = 0.0
	player.clear_status()
	await _frames(1)

	# Roid rage at 50%: protected transform, then faster and stronger rage_* attacks.
	_stand(1, p2.get_center().x)
	await _place(0, route.SERGEANT_PLATFORMS[0].get_center().x)
	var base_speed := 380.0 * sergeant._rate()
	sergeant.take_damage(sergeant.max_health - sergeant.max_health / 2)
	assert(sergeant.state == Sergeant.State.TRANSFORM and not sergeant.raged)
	assert(route.speech.visible and route.speech_label.text == Sergeant.RAGE_LINE, "Rage line uses the comic bubble")
	var tail_tip: Vector2 = route.speech.position + route.BUBBLE_TAIL_TIP
	var head_screen: Vector2 = route.get_viewport().get_canvas_transform() * sergeant.global_position
	assert(absf(tail_tip.x - head_screen.x) < 60.0 and tail_tip.y < head_screen.y, "Bubble tail points at the sergeant")
	var protected_health := sergeant.health
	sergeant.take_damage(5)
	assert(sergeant.health == protected_health, "Transforming sergeant is invulnerable")
	for i in range(200):
		await _frames(1)
		if sergeant.raged:
			break
	assert(sergeant.raged and sergeant.sprite.animation == &"rage_idle")
	await _frames(100)
	assert(not route.speech.visible, "Rage bubble closes after a few seconds")
	_hold()
	sergeant.position.x = p2.position.x + 40.0
	sergeant.start_scream()
	assert(sergeant.sprite.animation == &"rage_scream")
	for i in range(90):
		await _frames(1)
		if not get_nodes_in_group("sergeant_attacks").is_empty():
			break
	var wave := get_nodes_in_group("sergeant_attacks")[0] as SergeantWave
	assert(wave.speed > base_speed and wave.damage == 2 and wave.stun > 1.1, "Rage scream is faster and stronger")
	sergeant.start_charge()
	assert(sergeant.sprite.animation == &"rage_charge")

	# Death clears his waves, removes him from targeting and opens the room.
	sergeant.take_damage(10000)
	assert(sergeant.dead and not sergeant.is_in_group("enemies"))
	await _frames(1)
	assert(get_nodes_in_group("sergeant_attacks").is_empty())
	assert(route._room_clear())
	await _frames(150)
	assert(not is_instance_valid(sergeant), "Defeated sergeant fades out")

	# Lethal damage before rage still kills a fresh sergeant outright.
	var fresh := Sergeant.new()
	fresh.platforms = route.SERGEANT_PLATFORMS
	fresh.position = Vector2(p2.get_center().x, p2.position.y - Sergeant.BODY.y / 2.0)
	stage.add_child(fresh)
	fresh.take_damage(10000)
	assert(fresh.dead and fresh.state == Sergeant.State.DEAD)
	print("SERGEANT ACTIONS OK")
	quit()
