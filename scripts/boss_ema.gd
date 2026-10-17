class_name BossEma
extends CharacterBody2D

signal defeated
signal health_changed(current: int, maximum: int)

const GRAVITY := 1500.0

var max_health := 60
var health := 60
var phase := 1
var target: Node2D
var attack_cd := 2.0
var charge_time := 0.0
var charge_dir := 1
var active := false
var flash := 0.0

func _ready() -> void:
	add_to_group("enemies")
	var shape := RectangleShape2D.new()
	shape.size = Vector2(110, 80)
	var cs := CollisionShape2D.new()
	cs.shape = shape
	add_child(cs)

func activate() -> void:
	active = true
	health_changed.emit(health, max_health)

func _physics_process(delta: float) -> void:
	flash = maxf(0.0, flash - delta)
	if not is_on_floor():
		velocity.y += GRAVITY * delta
	if not active or not is_instance_valid(target):
		move_and_slide()
		return
	var mult := 1.0 + 0.5 * (phase - 1)
	if charge_time > 0.0:
		charge_time -= delta
		velocity.x = charge_dir * 520.0 * mult
		if is_on_wall():
			charge_time = 0.0
	else:
		velocity.x = move_toward(velocity.x, 0.0, 1200.0 * delta)
		attack_cd -= delta
		if attack_cd <= 0.0:
			_pick_attack()
			attack_cd = 2.0 / mult
	move_and_slide()
	if target.has_method("take_damage") \
			and absf(target.global_position.x - global_position.x) < 70.0 \
			and absf(target.global_position.y - global_position.y) < 62.0:
		target.take_damage(2)
	queue_redraw()

func _pick_attack() -> void:
	var r := randi() % 3
	if r == 0:
		_acid()
	elif r == 1:
		_swarm()
	else:
		charge_dir = 1 if target.global_position.x > global_position.x else -1
		charge_time = 0.8

func _acid() -> void:
	var count := 1 + phase
	for i in range(count):
		var p := Projectile.new()
		p.target_group = "player"
		p.color = Color(0.5, 1.0, 0.1)
		p.radius = 10.0
		p.position = global_position + Vector2(0, -30)
		var dir := (target.global_position - p.position).normalized()
		p.velocity = dir.rotated((i - (count - 1) / 2.0) * 0.25) * 320.0
		get_parent().add_child(p)

func _swarm() -> void:
	for i in range(phase + 1):
		var b := Bug.new()
		b.target = target
		b.health = 1
		b.patrol = 300.0
		b.position = global_position + Vector2(randf_range(-80, 80), -60)
		get_parent().add_child(b)

func take_damage(amount: int) -> void:
	if not active:
		return
	health = maxi(0, health - amount)
	flash = 0.1
	var new_phase := 1 if health > max_health * 2 / 3 else (2 if health > max_health / 3 else 3)
	phase = new_phase
	health_changed.emit(health, max_health)
	if health <= 0:
		active = false
		defeated.emit()
		queue_free()

func _draw() -> void:
	var c := Color(0.6, 0.1, 0.1) if phase < 3 else Color(0.9, 0.1, 0.3)
	if flash > 0.0:
		c = Color.WHITE
	draw_rect(Rect2(-55, -40, 110, 80), c)
	draw_rect(Rect2(-40, -55, 80, 20), Color(0.35, 0.05, 0.05))
	draw_circle(Vector2(-18, -20), 7.0, Color.YELLOW)
	draw_circle(Vector2(18, -20), 7.0, Color.YELLOW)
	for i in range(4):
		draw_line(Vector2(-50 + i * 33, 40), Vector2(-60 + i * 40, 60), Color(0.2, 0.0, 0.0), 4.0)
