class_name Player
extends CharacterBody2D

signal died
signal stats_changed

const SPEED := 260.0
const JUMP_VELOCITY := -520.0
const GRAVITY := 1500.0
const MAX_JUMPS := 2
const DASH_SPEED := 700.0
const DASH_DURATION := 0.16
const DASH_COOLDOWN := 0.7
const MAX_MINIONS := 4
const CHARACTER_FRAMES := preload("res://assets/character_frames.tres")

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
var jumps_remaining := MAX_JUMPS
var dash_time := 0.0
var dash_cooldown := 0.0
var dash_direction := 1

func _ready() -> void:
	player_sprite = AnimatedSprite2D.new()
	player_sprite.sprite_frames = CHARACTER_FRAMES
	player_sprite.scale = Vector2(0.34, 0.34)
	player_sprite.offset = Vector2(0, -72)
	player_sprite.position.y = 24.0
	add_child(player_sprite)
	player_sprite.play(&"idle")
	ultimate_beam = AnimatedSprite2D.new()
	ultimate_beam.sprite_frames = CHARACTER_FRAMES
	ultimate_beam.centered = false
	ultimate_beam.hide()
	add_child(ultimate_beam)
	ultimate_beam.animation_finished.connect(ultimate_beam.hide)
	army_effect = AnimatedSprite2D.new()
	army_effect.sprite_frames = CHARACTER_FRAMES
	army_effect.position.y = -24.0
	army_effect.scale = Vector2(0.34, 0.34)
	army_effect.hide()
	add_child(army_effect)
	army_effect.animation_finished.connect(army_effect.hide)
	add_to_group("player")
	var shape := RectangleShape2D.new()
	shape.size = Vector2(28, 48)
	var cs := CollisionShape2D.new()
	cs.shape = shape
	add_child(cs)

func _physics_process(delta: float) -> void:
	action_time = maxf(0.0, action_time - delta)
	if dead:
		velocity.x = 0.0
		velocity.y += GRAVITY * delta
		move_and_slide()
		_update_animation()
		return
	shoot_cd = maxf(0.0, shoot_cd - delta)
	summon_cd = maxf(0.0, summon_cd - delta)
	invuln = maxf(0.0, invuln - delta)
	dash_cooldown = maxf(0.0, dash_cooldown - delta)
	dash_time = maxf(0.0, dash_time - delta)
	if is_on_floor():
		jumps_remaining = MAX_JUMPS
	if not is_on_floor():
		velocity.y += GRAVITY * delta
	var dir := Input.get_axis("move_left", "move_right")
	if dir != 0.0:
		facing = 1 if dir > 0.0 else -1
	if Input.is_action_just_pressed("dash") and dash_cooldown <= 0.0:
		dash_time = DASH_DURATION
		dash_cooldown = DASH_COOLDOWN
		dash_direction = facing
	if dash_time > 0.0:
		velocity.x = dash_direction * DASH_SPEED
	else:
		velocity.x = dir * SPEED
	if Input.is_action_just_pressed("jump") and jumps_remaining > 0:
		air_animation = &"jump" if jumps_remaining == MAX_JUMPS else &"double_jump"
		velocity.y = JUMP_VELOCITY
		jumps_remaining -= 1
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
	_update_animation()

func _play_action(animation: StringName) -> void:
	if action_time > 0.0 and action_animation == &"hurt" and animation != &"hurt" and animation != &"death":
		return
	action_animation = animation
	action_time = CHARACTER_FRAMES.get_frame_count(animation) / CHARACTER_FRAMES.get_animation_speed(animation)
	player_sprite.stop()
	player_sprite.play(animation)

func _update_animation() -> void:
	var animation: StringName
	if dead:
		animation = &"death"
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
	player_sprite.flip_h = (dash_direction if dash_time > 0.0 else facing) < 0
	player_sprite.visible = dead or animation == &"hurt" or invuln <= 0.0 or int(invuln * 20) % 2 != 0
	if player_sprite.animation != animation:
		player_sprite.play(animation)

func _shoot() -> void:
	shoot_cd = 0.25
	if action_time <= 0.0 or action_animation == &"shoot" or action_animation == &"land":
		_play_action(&"shoot")
	var p := Projectile.new()
	p.character_art = true
	p.position = global_position + Vector2(facing * 22, -6)
	p.velocity = Vector2(facing * 650, 0)
	p.damage = 1
	get_parent().add_child(p)

func _clean_minions() -> void:
	minions = minions.filter(func(m): return is_instance_valid(m))

func _spawn_minion() -> void:
	var m := Minion.new()
	m.owner_player = self
	m.global_position = global_position + Vector2(-facing * 30, -20)
	get_parent().add_child(m)
	minions.append(m)

func _summon() -> void:
	_clean_minions()
	if summon_cd > 0.0 or minions.size() >= max_minions:
		return
	summon_cd = 0.6
	_spawn_minion()
	_play_action(&"summon")

func _ultimate() -> void:
	meter = 0.0
	_play_action(&"ultimate")
	ultimate_beam.position = Vector2(facing * 22, -6)
	ultimate_beam.position.y -= CHARACTER_FRAMES.get_frame_texture(&"beam", 0).get_height() * 0.34 / 2.0
	ultimate_beam.scale = Vector2(facing * 0.34, 0.34)
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
	meter = minf(meter_max, meter + amount)
	stats_changed.emit()

func take_damage(amount: int) -> void:
	if invuln > 0.0 or dead:
		return
	health -= amount
	invuln = 1.0
	velocity.y = -250.0
	_play_action(&"hurt")
	stats_changed.emit()
	if health <= 0:
		dead = true
		_play_action(&"death")
		ultimate_beam.hide()
		army_effect.hide()
		died.emit()
	_update_animation()
