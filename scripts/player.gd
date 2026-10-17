class_name Player
extends CharacterBody2D

signal died
signal stats_changed

const SPEED := 260.0
const JUMP_VELOCITY := -520.0
const GRAVITY := 1500.0
const MAX_MINIONS := 4

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

func _ready() -> void:
	add_to_group("player")
	var shape := RectangleShape2D.new()
	shape.size = Vector2(28, 48)
	var cs := CollisionShape2D.new()
	cs.shape = shape
	add_child(cs)

func _physics_process(delta: float) -> void:
	if dead:
		return
	shoot_cd = maxf(0.0, shoot_cd - delta)
	summon_cd = maxf(0.0, summon_cd - delta)
	invuln = maxf(0.0, invuln - delta)
	if not is_on_floor():
		velocity.y += GRAVITY * delta
	var dir := Input.get_axis("move_left", "move_right")
	velocity.x = dir * SPEED
	if dir != 0.0:
		facing = 1 if dir > 0.0 else -1
	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = JUMP_VELOCITY
	move_and_slide()
	if Input.is_action_pressed("shoot") and shoot_cd <= 0.0:
		_shoot()
	if Input.is_action_just_pressed("summon"):
		_summon()
	if Input.is_action_just_pressed("recall"):
		for m in minions:
			if is_instance_valid(m):
				m.recall()
	if Input.is_action_just_pressed("ultimate") and meter >= meter_max:
		_ultimate()
	queue_redraw()

func _shoot() -> void:
	shoot_cd = 0.25
	var p := Projectile.new()
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

func _ultimate() -> void:
	meter = 0.0
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
	stats_changed.emit()
	if health <= 0:
		dead = true
		died.emit()

func _draw() -> void:
	if invuln > 0.0 and int(invuln * 20) % 2 == 0:
		return
	draw_rect(Rect2(-14, -24, 28, 48), Color(0.25, 0.25, 0.4))
	draw_rect(Rect2(-12, -22, 24, 14), Color(0.9, 0.75, 0.6))
	draw_rect(Rect2(-12 + (6 if facing > 0 else -6), -18, 18, 6), Color(0.1, 0.1, 0.1))
	draw_rect(Rect2(facing * 10 - 5, 2, 10, 6), Color(0.6, 0.2, 0.9))
