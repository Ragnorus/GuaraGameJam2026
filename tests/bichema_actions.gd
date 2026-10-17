extends SceneTree

class DamageTarget extends Node2D:
	var health := 1000

	func take_damage(amount: int) -> void:
		health -= amount

class ProjectileTarget extends StaticBody2D:
	var health := 10

	func take_damage(amount: int) -> void:
		health -= amount


# Run: Godot --headless --path . --fixed-fps 60 --script res://tests/bichema_actions.gd
func _initialize() -> void:
	_run.call_deferred()

func _frames(count: int) -> void:
	for i in range(count):
		await physics_frame
		await process_frame

func _run() -> void:
	var world := Node2D.new()
	root.add_child(world)
	var floor_body := StaticBody2D.new()
	var floor_shape := CollisionShape2D.new()
	var rectangle := RectangleShape2D.new()
	rectangle.size = Vector2(4000, 40)
	floor_shape.shape = rectangle
	floor_body.position.y = 130.0
	floor_body.add_child(floor_shape)
	world.add_child(floor_body)
	var target := DamageTarget.new()
	target.position = Vector2(400, 0)
	world.add_child(target)

	var cash_target := ProjectileTarget.new()
	cash_target.add_to_group("player")
	cash_target.position = Vector2(90, -16)
	var cash_shape := CircleShape2D.new()
	cash_shape.radius = 10.0
	var cash_collision := CollisionShape2D.new()
	cash_collision.shape = cash_shape
	cash_target.add_child(cash_collision)
	world.add_child(cash_target)
	var shooter := TruffleAndroid.new()
	shooter.position = Vector2(0, -8)
	shooter.dir = 1
	shooter.target = cash_target
	world.add_child(shooter)
	shooter.sprite.play(&"warn")
	shooter._fire()
	var cash_shot: Projectile
	for child in world.get_children():
		if child is Projectile and child.target_group == "player":
			cash_shot = child
	assert(cash_shot != null
			and cash_shot.texture == TruffleAndroid.FRAMES.get_frame_texture(&"money_bolt", 0)
			and cash_shot.texture_scale == Vector2(0.25, 0.25)
			and cash_shot.radius == 8.0 and cash_shot.damage == 1
			and cash_shot.velocity == Vector2(320.0, 0.0) and cash_shot.coin_pop,
			"Ground minions fire the supplied, scaled cash projectile without changing hit balance")
	var cash_outline := cash_shot.material as ShaderMaterial
	assert(cash_outline != null and cash_outline.shader == Projectile.OUTLINE_SHADER
			and cash_outline.get_shader_parameter("outline_color") == Projectile.GOLD_OUTLINE_COLOR,
			"Minion cash bills use a gold outline")
	for i in range(20):
		if cash_target.health < 10:
			break
		await _frames(1)
	assert(cash_target.health == 9, "The cash projectile still damages its target once")
	var saw_coin_pop := false
	for child in world.get_children():
		if child is Label and child.text == "$":
			saw_coin_pop = true
	assert(saw_coin_pop, "A cash hit must show a gold dollar pop")
	await _frames(20)
	for child in world.get_children():
		assert(not (child is Label and child.text == "$"), "The coin pop must clean itself up")
	shooter.queue_free()
	cash_target.queue_free()
	await _frames(1)

	var boss := BossEvilGenius.new()
	boss.target = target
	world.add_child(boss)
	boss.activate()
	boss.attack_cd = 1000.0
	var shadow := Minion.new()
	shadow.owner_player = target
	world.add_child(shadow)
	shadow.set_physics_process(false)
	var defeats := [0]
	var transforms := [0]
	boss.transformed.connect(func() -> void:
		transforms[0] += 1
		assert(boss.transforming and boss.costume_form and boss.sprite.animation == &"transform")
	)
	boss.defeated.connect(func() -> void:
		assert(boss.sprite.animation == &"dead" and not boss.sprite.is_playing(), "Defeat must wait for the actual collapse to finish")
		defeats[0] += 1
	)
	boss._blast()

	var cash_fan_count := 0
	for attack in get_nodes_in_group("evil_genius_attacks"):
		if attack is Projectile:
			cash_fan_count += 1
			assert(attack.texture == TruffleAndroid.FRAMES.get_frame_texture(&"money_bolt", 0))
			assert(attack.texture_scale == Vector2(0.35, 0.35) and attack.radius == 12.0
					and attack.target_group == "player" and attack.damage == 1
					and attack.velocity.length() > 300.0 and attack.coin_pop)
			var fan_outline := attack.material as ShaderMaterial
			assert(fan_outline != null and fan_outline.shader == Projectile.OUTLINE_SHADER
					and fan_outline.get_shader_parameter("outline_color") == Projectile.GOLD_OUTLINE_COLOR,
					"Ema's money fan uses a gold outline")
	assert(cash_fan_count == 1 + boss.phase, "Normal Ema must fire the unchanged fan with scaled cash projectiles")

	boss._summon()
	var summoned: TruffleAndroid
	for attack in get_nodes_in_group("evil_genius_attacks"):
		if attack is TruffleAndroid:
			summoned = attack
	assert(summoned != null and shadow._nearest_enemy() != null)
	summoned.sprite.play(&"warn")
	summoned._fire()
	var prior_attacks := get_nodes_in_group("evil_genius_attacks")
	boss.charge_dir = -1
	boss.charge_time = 0.8
	boss.charge_windup = 0.35
	boss.take_damage(boss.health)
	assert(boss.costume_form and boss.transforming and boss.active and not boss.dying)
	assert(boss.health == GameSettings.scale_health(72) and boss.phase == 1 and defeats[0] == 0 and transforms[0] == 1)
	assert(boss.sprite.sprite_frames == BossEvilGenius.COSTUME_FRAMES)
	assert(boss.sprite.position.y == 110.0 and boss.sprite.offset == Vector2(-256, -240) and boss.sprite.scale == Vector2(1.5, 1.5))
	assert(boss.charge_time == 0.0 and boss.charge_windup == 0.0 and not boss.is_in_group("enemies"))
	assert(shadow._nearest_enemy() == null, "Transformation and dismissed summons must immediately stop being targetable")
	for attack in prior_attacks:
		assert(attack.is_queued_for_deletion() and attack.process_mode == Node.PROCESS_MODE_DISABLED)
	target.position = boss.position
	var protected_health := target.health
	var boss_health := boss.health
	boss.take_damage(999)
	boss._blast()
	boss._summon()
	boss._pick_attack()
	boss._die()
	await _frames(30)
	assert(boss.transforming and boss.sprite.animation == &"transform" and defeats[0] == 0)
	assert(target.health == protected_health and boss.health == boss_health, "Actual transformation must block incoming/contact damage and spawned-hostile danger")
	assert(get_nodes_in_group("evil_genius_attacks").is_empty(), "Transition must clear fans, summons and their lingering shots")
	target.position.x = 400.0
	for i in range(240):
		if not boss.transforming:
			break
		await _frames(1)
	assert(not boss.transforming and boss.is_in_group("enemies") and transforms[0] == 1 and defeats[0] == 0)
	boss.attack_cd = 1000.0
	boss._blast()
	boss._update_art()
	assert(boss.sprite.animation == &"blast")
	var fan_count := 0
	for attack in get_nodes_in_group("evil_genius_attacks"):
		if attack is Projectile:
			fan_count += 1
			assert(attack.texture == BossEvilGenius.COSTUME_FRAMES.get_frame_texture(&"pink_bolt", 0))
			assert(attack.target_group == "player" and attack.damage == 1 and attack.velocity.length() > 300.0)
	assert(fan_count == 2, "Costume form must retain phase-one fan combat with supplied pink-green projectile art")
	boss._summon()
	boss._update_art()
	assert(boss.sprite.animation == &"point")
	assert(get_nodes_in_group("enemies").size() == 3, "Costume summon must retain its two research assistants")
	boss.pose_time = 0.0
	boss.charge_dir = -1
	boss.charge_windup = 0.35
	boss._update_art()
	assert(boss.sprite.animation == &"shield")
	await _frames(25)
	assert(boss.charge_time > 0.0 and boss.sprite.animation == &"run" and boss.velocity.x < -520.0)
	boss.take_damage(boss.health)
	assert(boss.dying and boss.sprite.animation == &"dead" and defeats[0] == 0)
	assert(boss.charge_time == 0.0 and boss.charge_windup == 0.0 and not boss.is_in_group("enemies"))
	boss.take_damage(99)
	boss._die()
	boss._blast()
	boss._summon()
	await _frames(2)
	assert(is_instance_valid(boss) and boss.sprite.animation == &"dead" and defeats[0] == 0, "An interrupted attack must not replace or skip the costume collapse")
	assert(get_nodes_in_group("evil_genius_attacks").is_empty())
	for i in range(240):
		if not is_instance_valid(boss):
			break
		await _frames(1)
	assert(not is_instance_valid(boss) and defeats[0] == 1 and transforms[0] == 1, "Only final costume collapse must emit exactly one defeat")

	var mob := TruffleAndroid.new()
	mob.health = 100
	mob.shoot_cd = 1000.0
	world.add_child(mob)
	mob.take_damage(1)
	assert(mob.sprite.animation == &"hurt")
	await _frames(2)
	assert(mob.sprite.animation == &"hurt", "Locomotion must not interrupt the new hurt animation")
	await _frames(60)
	assert(mob.sprite.animation == &"run" or mob.sprite.animation == &"idle", "Nonlooping hurt must hand back to locomotion")
	mob.take_damage(mob.health)
	assert(mob.dying and mob.sprite.animation == &"dead" and not mob.is_in_group("enemies"))
	mob.take_damage(99)
	await _frames(2)
	assert(is_instance_valid(mob) and mob.sprite.animation == &"dead", "A dead minion must retain its animation instead of disappearing immediately")
	for i in range(240):
		if not is_instance_valid(mob):
			break
		await _frames(1)
	assert(not is_instance_valid(mob), "The minion must despawn after the supplied death animation")
	world.queue_free()
	await _frames(1)
	print("PASS: Ema two forms, protected transition/targeting/attack cleanup, costume attacks, single final collapse; minion hurt/death")
	quit()
