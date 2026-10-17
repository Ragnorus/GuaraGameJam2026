class_name Bug
extends CharacterBody2D

const GRAVITY := 1500.0

var health := 3
var speed := 70.0
var dir := -1
var origin_x := 0.0
var patrol := 150.0
var target: Node2D
var robot := false
var dead := false
var shoot_cd := 2.0
var anim_lock := 0.0
var sprite: AnimatedSprite2D
var cs: CollisionShape2D
var reach_x := 30.0
var reach_y := 46.0

func _ready() -> void:
	add_to_group("enemies")
	origin_x = position.x
	var shape := RectangleShape2D.new()
	shape.size = Vector2(44, 72) if robot else Vector2(36, 48)
	cs = CollisionShape2D.new()
	cs.shape = shape
	add_child(cs)
	if robot:
		speed = 80.0
		sprite = SpriteLib.make_sprite(SpriteLib.build("robot", {
			"idle": [["idle_0", "idle_1", "idle_2", "idle_3", "idle_4", "idle_5", "idle_6"], 8.0, true],
			"run": [["run_0", "run_1", "run_2", "run_3", "run_4", "run_5", "run_6", "run_7", "run_8"], 12.0, true],
			"warn": [["warn_0", "warn_1", "warn_2", "warn_3"], 10.0, false],
			"shoot": [["shoot_0", "shoot_1"], 10.0, false],
			"hurt": [["hurt_0", "hurt_1", "hurt_2", "hurt_3"], 16.0, false],
			"dead": [["dead_0", "dead_1", "dead_2", "dead_3", "dead_4"], 10.0, false],
		}), 36.0)
		add_child(sprite)
		sprite.play("run")

func _physics_process(delta: float) -> void:
	if dead:
		return
	if not is_on_floor():
		velocity.y += GRAVITY * delta
	if is_instance_valid(target) and absf(target.global_position.x - global_position.x) < 250.0:
		dir = 1 if target.global_position.x > global_position.x else -1
	elif absf(position.x - origin_x) > patrol or is_on_wall():
		dir = -dir
	velocity.x = dir * speed
	if robot:
		_robot_update(delta)
	move_and_slide()
	var reach := reach_x if not robot else 36.0
	if is_instance_valid(target) and target.has_method("take_damage") \
			and absf(target.global_position.x - global_position.x) < reach \
			and absf(target.global_position.y - global_position.y) < (reach_y if not robot else 58.0):
		target.take_damage(1)
	if not robot:
		queue_redraw()

func _robot_update(delta: float) -> void:
	anim_lock = maxf(0.0, anim_lock - delta)
	sprite.flip_h = dir < 0
	shoot_cd -= delta
	if anim_lock > 0.0:
		velocity.x = 0.0
		if shoot_cd <= 0.0 and sprite.animation == "warn" and sprite.frame >= 3:
			_shoot()
		return
	if shoot_cd <= 0.0 and is_instance_valid(target) \
			and absf(target.global_position.x - global_position.x) < 400.0:
		anim_lock = 0.7
		sprite.play("warn")
		return
	var want := "run" if absf(velocity.x) > 1.0 else "idle"
	if sprite.animation != want:
		sprite.play(want)

func _shoot() -> void:
	shoot_cd = 3.0
	sprite.play("shoot")
	anim_lock = 0.3
	var p := Projectile.new()
	p.target_group = "player"
	p.color = Color(0.6, 1.0, 0.2)
	p.texture = SpriteLib.texture("robot_fx", "bolt")
	p.position = global_position + Vector2(dir * 30, -8)
	p.velocity = Vector2(dir * 320.0, 0.0)
	get_parent().add_child(p)

func take_damage(amount: int) -> void:
	if dead:
		return
	health -= amount
	if health <= 0:
		_die()
	elif robot and anim_lock <= 0.0:
		anim_lock = 0.25
		sprite.play("hurt")

func _die() -> void:
	if not robot:
		queue_free()
		return
	dead = true
	remove_from_group("enemies")
	cs.set_deferred("disabled", true)
	sprite.play("dead")
	await sprite.animation_finished
	var boom := SpriteLib.make_sprite(SpriteLib.build("robot_fx", {
		"boom": [["boom_0", "boom_1", "boom_2", "boom_3", "boom_4"], 14.0, false],
	}), 0.0)
	boom.position = sprite.position
	add_child(boom)
	sprite.visible = false
	boom.play("boom")
	await boom.animation_finished
	queue_free()

func _draw() -> void:
	if robot:
		return
	draw_rect(Rect2(-18, -24, 36, 48), Color(0.3, 0.7, 0.2))
	draw_rect(Rect2(-14, -30, 28, 8), Color(0.2, 0.5, 0.15))
	draw_circle(Vector2(dir * 10, -10), 4.0, Color.RED)
