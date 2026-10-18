class_name Player
extends CharacterBody2D

signal died
signal stats_changed

const SPEED := 260.0
const JUMP_VELOCITY := -590.0
const GRAVITY := 1500.0
const MAX_JUMPS := 2
const DASH_SPEED := 700.0
const DASH_DURATION := 0.16
const DASH_COOLDOWN := 0.7
const JUMP_CUT := 0.45
const JUMP_BUFFER := 0.12
const HIT_KNOCKBACK := 170.0
const HIT_KNOCKBACK_TIME := 0.14
const SHIELD_COOLDOWN := 6.0
const MAX_MINIONS := 4
const CHARACTER_FRAMES := preload("res://assets/character_frames.tres")
const OUTLINE_SHADER := preload("res://scripts/player_outline.gdshader")
const MECHA_FRAMES := preload("res://assets/mecha_frames.tres")
const MECHA_BOLT := preload("res://assets/mecha_bolt.png")
const MECHA_DURATION := 20.0
const MECHA_OUTLINE_COLOR := Color(1.0, 0.92, 0.2, 1.0)

var player_sprite: AnimatedSprite2D
var ultimate_beam: AnimatedSprite2D
var army_effect: AnimatedSprite2D
var action_animation: StringName = &""
var action_time := 0.0
var air_animation: StringName = &"jump"

var max_health := 10
var health := 10
var facing := 1
var shoot_cd := 0.0
var invuln := 0.0
var summon_cd := 0.0
var meter := 0.0
var meter_max := 100.0
var minions: Array = []
var max_minions := MAX_MINIONS
var dead := false
var controls_locked := false
var jumps_remaining := MAX_JUMPS
var dash_time := 0.0
var dash_cooldown := 0.0
var dash_direction := 1
var dash_vector := Vector2.RIGHT
# Enemy hits can shove the player (no steering while airborne from the shove) or stun them in place.
var knockback_time := 0.0
var stun_time := 0.0
var stun_guard := 0.0
var stun_fx: Node2D
var stun_spin := 0.0
var jump_buffer := 0.0
var shield_cd := 0.0
var mecha_time := 0.0
var mecha_transition: StringName = &""
func _ready() -> void:
	player_sprite = AnimatedSprite2D.new()
	player_sprite.sprite_frames = CHARACTER_FRAMES
	player_sprite.scale = Vector2(0.5, 0.5)
	player_sprite.offset = Vector2(0, -72)
	player_sprite.position.y = 36.0
	var outline := ShaderMaterial.new()
	outline.shader = OUTLINE_SHADER
	player_sprite.material = outline
	player_sprite.frame_changed.connect(_update_outline_frame)
	player_sprite.animation_changed.connect(_update_outline_frame)
	add_child(player_sprite)
	player_sprite.play(&"idle")
	_update_outline_frame()
	ultimate_beam = AnimatedSprite2D.new()
	ultimate_beam.sprite_frames = CHARACTER_FRAMES
	ultimate_beam.centered = false
	ultimate_beam.hide()
	add_child(ultimate_beam)
	ultimate_beam.animation_finished.connect(ultimate_beam.hide)
	army_effect = AnimatedSprite2D.new()
	army_effect.sprite_frames = CHARACTER_FRAMES
	army_effect.position.y = -36.0
	army_effect.scale = Vector2(0.5, 0.5)
	army_effect.hide()
	add_child(army_effect)
	army_effect.animation_finished.connect(army_effect.hide)
	stun_fx = Node2D.new()
	stun_fx.position.y = -50.0
	stun_fx.z_index = 5
	stun_fx.hide()
	stun_fx.draw.connect(_draw_stun)
	add_child(stun_fx)
	add_to_group("player")
	var shape := RectangleShape2D.new()
	shape.size = Vector2(42, 72)
	var cs := CollisionShape2D.new()
	cs.shape = shape
	add_child(cs)

func _update_outline_frame() -> void:
	# animation_changed can arrive before the previous animation's frame is reset.
	var frames := player_sprite.sprite_frames
	var frame := mini(player_sprite.frame, frames.get_frame_count(player_sprite.animation) - 1)
	var texture := frames.get_frame_texture(player_sprite.animation, frame) as AtlasTexture
	var atlas_size := texture.atlas.get_size()
	var start := (texture.region.position + Vector2(0.5, 0.5)) / atlas_size
	var end := (texture.region.end - Vector2(0.5, 0.5)) / atlas_size
	(player_sprite.material as ShaderMaterial).set_shader_parameter("frame_uv", Vector4(start.x, start.y, end.x, end.y))

func activate_mecha() -> bool:
	if dead or controls_locked or stun_time > 0.0 or knockback_time > 0.0 or mecha_transition != &"":
		return false
	mecha_time = MECHA_DURATION
	if player_sprite.sprite_frames != MECHA_FRAMES:
		_set_mecha_visuals(true)
		_start_mecha_transition(&"transform")
	stats_changed.emit()
	return true

func _set_mecha_visuals(powered: bool) -> void:
	player_sprite.stop()
	player_sprite.animation = &"idle"
	player_sprite.sprite_frames = MECHA_FRAMES if powered else CHARACTER_FRAMES
	player_sprite.centered = not powered
	player_sprite.scale = Vector2.ONE * (0.8 if powered else 0.5)
	player_sprite.offset = Vector2(-128, -232) if powered else Vector2(0, -72)
	(player_sprite.material as ShaderMaterial).set_shader_parameter("outline_color",
			MECHA_OUTLINE_COLOR if powered else Color(1.0, 0.85, 0.48, 0.95))
	player_sprite.play(&"idle")
	_update_outline_frame()

func _start_mecha_transition(animation: StringName) -> void:
	mecha_transition = animation
	dash_time = 0.0
	jump_buffer = 0.0
	action_time = 0.0
	_play_action(animation)
	_update_animation()

func _physics_process(delta: float) -> void:
	if controls_locked:
		velocity = Vector2.ZERO
		return
	action_time = maxf(0.0, action_time - delta)
	if dead:
		velocity.x = 0.0
		velocity.y += GRAVITY * delta
		move_and_slide()
		_update_animation()
		return
	if mecha_transition == &"" and mecha_time > 0.0:
		var before := mecha_time
		mecha_time = maxf(0.0, mecha_time - delta)
		if mecha_time <= 0.0:
			_start_mecha_transition(&"revert")
		if mecha_time <= 0.0 or ceilf(mecha_time) != ceilf(before):
			stats_changed.emit()
	if mecha_transition != &"":
		velocity.x = 0.0
		if not is_on_floor():
			velocity.y += GRAVITY * delta
		move_and_slide()
		if action_time <= 0.0:
			var reverting := mecha_transition == &"revert"
			mecha_transition = &""
			if reverting:
				_set_mecha_visuals(false)
		_update_animation()
		return
	shoot_cd = maxf(0.0, shoot_cd - delta)
	summon_cd = maxf(0.0, summon_cd - delta)
	invuln = maxf(0.0, invuln - delta)
	dash_cooldown = maxf(0.0, dash_cooldown - delta)
	dash_time = maxf(0.0, dash_time - delta)
	if shield_cd > 0.0:
		var before := shield_cd
		shield_cd = maxf(0.0, shield_cd - delta)
		# Refresh the HUD countdown once per whole second and when the shield is ready again.
		if shield_cd <= 0.0 or ceilf(shield_cd) != ceilf(before):
			stats_changed.emit()
	jump_buffer = maxf(0.0, jump_buffer - delta)
	knockback_time = maxf(0.0, knockback_time - delta)
	stun_time = maxf(0.0, stun_time - delta)
	stun_guard = maxf(0.0, stun_guard - delta)
	stun_fx.visible = stun_time > 0.0
	if stun_fx.visible:
		stun_spin += delta * 7.0
		stun_fx.queue_redraw()
	if is_on_floor():
		jumps_remaining = MAX_JUMPS
	if not is_on_floor():
		velocity.y += GRAVITY * delta
	if stun_time > 0.0 or knockback_time > 0.0:
		dash_time = 0.0
		if knockback_time <= 0.0 and is_on_floor():
			velocity.x = move_toward(velocity.x, 0.0, 2400.0 * delta)
		move_and_slide()
		_update_animation()
		return
	var dir := Input.get_axis("move_left", "move_right")
	if dir != 0.0:
		facing = 1 if dir > 0.0 else -1
	if Input.is_action_just_pressed("dash") and dash_cooldown <= 0.0 and (GameSettings.dash_unlocked or mecha_time > 0.0):
		dash_time = DASH_DURATION
		dash_cooldown = DASH_COOLDOWN
		dash_direction = facing
		dash_vector = Vector2(dash_direction, 0.0)
	# Jump can redirect an active forward dash vertically, so the inputs needn't be simultaneous.
	if dash_time > 0.0 and Input.is_action_just_pressed("jump"):
		dash_vector = Vector2.UP
	if dash_time > 0.0:
		velocity = dash_vector * DASH_SPEED
	else:
		velocity.x = dir * SPEED
	if Input.is_action_just_pressed("jump"):
		jump_buffer = JUMP_BUFFER
	if jump_buffer > 0.0 and dash_time <= 0.0 and jumps_remaining > 0:
		jump_buffer = 0.0
		air_animation = &"jump" if jumps_remaining == MAX_JUMPS else &"double_jump"
		velocity.y = JUMP_VELOCITY
		jumps_remaining -= 1
	# Releasing jump early cuts the rise, so jump height is controlled by how long the button is held.
	if Input.is_action_just_released("jump") and not Input.is_action_just_pressed("jump") \
			and velocity.y < JUMP_VELOCITY * 0.35 and dash_time <= 0.0:
		velocity.y *= JUMP_CUT
	var was_on_floor := is_on_floor()
	move_and_slide()
	if not was_on_floor and is_on_floor() and action_time <= 0.0:
		_play_action(&"land")
	if Input.is_action_pressed("shoot") and shoot_cd <= 0.0:
		_shoot()
	if Input.is_action_just_pressed("summon"):
		_summon()
	if Input.is_action_just_pressed("recall"):
		_play_action(&"recall")
		for m in minions:
			if is_instance_valid(m):
				m.recall()
	if Input.is_action_just_pressed("ultimate") and meter >= meter_max:
		_ultimate()
	if Input.is_action_just_pressed("shield"):
		shield_burst()
	_update_animation()

func _play_action(animation: StringName) -> void:
	if mecha_transition != &"" and animation != mecha_transition and animation != &"death":
		return
	if action_time > 0.0 and action_animation == &"hurt" and animation != &"hurt" and animation != &"death":
		return
	action_animation = animation
	var frames := player_sprite.sprite_frames
	action_time = frames.get_frame_count(animation) / frames.get_animation_speed(animation)
	player_sprite.stop()
	player_sprite.play(animation)

func _update_animation() -> void:
	var animation: StringName
	if dead:
		animation = &"death"
	elif mecha_transition != &"":
		animation = mecha_transition
	elif action_time > 0.0 and action_animation == &"hurt":
		animation = &"hurt"
	elif dash_time > 0.0:
		animation = &"dash"
	elif action_time > 0.0:
		animation = action_animation
	elif not is_on_floor():
		animation = &"fall" if velocity.y > 40.0 else air_animation
	else:
		animation = &"run" if absf(velocity.x) > 1.0 else &"idle"
	player_sprite.flip_h = (dash_direction if dash_time > 0.0 and dash_vector.x != 0.0 else facing) < 0
	player_sprite.visible = dead or mecha_transition != &"" or animation == &"hurt" or invuln <= 0.0 or int(invuln * 20) % 2 != 0
	# Red flash right after a hit, fading out as the blink starts.
	var flash := clampf((invuln - 0.8) / 0.2, 0.0, 1.0) if not dead else 0.0
	player_sprite.modulate = Color(1.0, 1.0 - 0.6 * flash, 1.0 - 0.6 * flash)
	if player_sprite.animation != animation:
		player_sprite.play(animation)

func _shoot() -> void:
	if dead or controls_locked or mecha_transition != &"":
		return
	var powered := mecha_time > 0.0
	shoot_cd = 0.2 if powered else 0.25
	if action_time <= 0.0 or action_animation == &"shoot" or action_animation == &"land":
		_play_action(&"shoot")
	var p := Projectile.new()
	p.character_art = not powered
	if powered:
		p.texture = MECHA_BOLT
		p.texture_scale = Vector2.ONE * 0.8
	p.owner_player = self
	p.position = global_position + Vector2(facing * (42 if powered else 22), 3 if powered else -6)
	p.velocity = Vector2(facing * (850 if powered else 650), 0)
	p.damage = 3 if powered else 1
	get_parent().add_child(p)

func shield_burst() -> bool:
	if dead or controls_locked or mecha_transition != &"" or stun_time > 0.0 or not GameSettings.shield_unlocked or shield_cd > 0.0:
		return false
	shield_cd = SHIELD_COOLDOWN
	invuln = maxf(invuln, 0.6)
	_play_action(&"recall")
	var ring := ShieldBurst.new()
	ring.position = global_position
	ring.z_index = 20
	get_parent().add_child(ring)
	ShieldBurst.apply(global_position, get_tree())
	GameAudio.play(get_tree(), "boss")
	stats_changed.emit()
	return true

func _clean_minions() -> void:
	minions = minions.filter(func(m): return is_instance_valid(m))

func _spawn_minion() -> void:
	if dead or controls_locked or mecha_transition != &"":
		return
	var m := Minion.new()
	m.owner_player = self
	m.global_position = global_position + Vector2(-facing * 30, -20)
	get_parent().add_child(m)
	minions.append(m)

func _summon() -> void:
	if dead or controls_locked or mecha_transition != &"":
		return
	_clean_minions()
	if summon_cd > 0.0 or minions.size() >= max_minions:
		return
	summon_cd = 0.6
	_spawn_minion()
	_play_action(&"summon")

func _ultimate() -> void:
	if dead or controls_locked or mecha_transition != &"":
		return
	meter = 0.0
	_play_action(&"ultimate")
	ultimate_beam.position = Vector2(facing * 32, -9)
	ultimate_beam.position.y -= CHARACTER_FRAMES.get_frame_texture(&"beam", 0).get_height() * 0.5 / 2.0
	ultimate_beam.scale = Vector2(facing * 0.5, 0.5)
	ultimate_beam.show()
	ultimate_beam.stop()
	ultimate_beam.play(&"beam")
	army_effect.show()
	army_effect.stop()
	army_effect.play(&"army")
	_clean_minions()
	for i in range(max_minions * 2):
		var m := Minion.new()
		m.owner_player = self
		m.lifetime = 8.0
		m.global_position = global_position + Vector2(randf_range(-40, 40), -30)
		get_parent().add_child(m)
	stats_changed.emit()

func add_meter(amount: float) -> void:
	if dead or controls_locked:
		return
	meter = minf(meter_max, meter + amount)
	stats_changed.emit()

func heal(amount: int) -> int:
	if dead:
		return 0
	var restored := mini(amount, max_health - health)
	if restored <= 0:
		return 0
	health += restored
	stats_changed.emit()
	return restored

func take_damage(amount: int) -> void:
	if invuln > 0.0 or dead or controls_locked or mecha_transition != &"":
		return
	amount = GameSettings.incoming_damage(amount)
	GameAudio.play(get_tree(), "hurt")
	health -= amount
	invuln = 1.0
	velocity.y = -250.0
	# A short shove away from where the player faces, so contact hits read clearly.
	velocity.x = -facing * HIT_KNOCKBACK
	knockback_time = HIT_KNOCKBACK_TIME
	dash_time = 0.0
	_play_action(&"hurt")
	stats_changed.emit()
	if health <= 0:
		die()
	_update_animation()

# Damage plus optional shove/stun. Returns false when the hit is ignored (invulnerable, dead or in a cinematic).
func hit_by(amount: int, knockback := Vector2.ZERO, stun := 0.0) -> bool:
	if invuln > 0.0 or dead or controls_locked or mecha_transition != &"":
		return false
	var vx := velocity.x
	take_damage(amount)
	if dead:
		return true
	if knockback == Vector2.ZERO:
		velocity.x = vx
		knockback_time = 0.0
	else:
		velocity = knockback
		knockback_time = 0.35
	if stun > 0.0 and stun_guard <= 0.0:
		stun_time = stun
		stun_guard = stun + 1.5
		velocity.x = 0.0 if knockback == Vector2.ZERO else velocity.x
	dash_time = 0.0
	return true

func clear_status() -> void:
	jump_buffer = 0.0
	knockback_time = 0.0
	stun_time = 0.0
	stun_guard = 0.0
	if is_instance_valid(stun_fx):
		stun_fx.hide()

func _draw_stun() -> void:
	# Three gold stars orbit the head while stunned.
	stun_fx.draw_arc(Vector2.ZERO, 22.0, 0.0, TAU, 32, Color(1.0, 0.86, 0.3, 0.35), 2.0)
	for i in range(3):
		var angle := stun_spin + i * TAU / 3.0
		var at := Vector2(cos(angle) * 22.0, sin(angle) * 7.0)
		var points := PackedVector2Array()
		for p in range(10):
			var r := 7.0 if p % 2 == 0 else 3.0
			var a := -PI / 2.0 + p * PI / 5.0 + stun_spin
			points.append(at + Vector2(cos(a), sin(a)) * r)
		stun_fx.draw_colored_polygon(points, Color(1.0, 0.86, 0.25))
		points.append(points[0])
		stun_fx.draw_polyline(points, Color(0.03, 0.05, 0.04), 1.5)

func clear_attacks() -> void:
	for minion in get_tree().get_nodes_in_group("player_summons"):
		if minion.owner_player == self:
			minion.set_physics_process(false)
			minion.hide()
			minion.queue_free()
	for projectile in get_tree().get_nodes_in_group("player_shots"):
		if projectile.owner_player == self:
			projectile.set_physics_process(false)
			projectile.hide()
			projectile.queue_free()
	minions.clear()
	ultimate_beam.hide()
	army_effect.hide()

func die() -> void:
	if dead:
		return
	dead = true
	controls_locked = false
	health = 0
	mecha_time = 0.0
	mecha_transition = &""
	if player_sprite.sprite_frames == MECHA_FRAMES:
		_set_mecha_visuals(false)
	dash_time = 0.0
	clear_status()
	clear_attacks()
	_play_action(&"death")
	stats_changed.emit()
	died.emit()
