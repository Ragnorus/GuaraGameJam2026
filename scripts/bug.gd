class_name Bug
extends CharacterBody2D

const GRAVITY := 1500.0

var health := 3
var speed := 70.0
var dir := -1
var origin_x := 0.0
var patrol := 150.0
var target: Node2D

func _ready() -> void:
	add_to_group("enemies")
	origin_x = position.x
	var shape := RectangleShape2D.new()
	shape.size = Vector2(32, 20)
	var cs := CollisionShape2D.new()
	cs.shape = shape
	add_child(cs)

func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y += GRAVITY * delta
	if is_instance_valid(target) and absf(target.global_position.x - global_position.x) < 250.0:
		dir = 1 if target.global_position.x > global_position.x else -1
	elif absf(position.x - origin_x) > patrol or is_on_wall():
		dir = -dir
	velocity.x = dir * speed
	move_and_slide()
	if is_instance_valid(target) and target.has_method("take_damage") \
			and absf(target.global_position.x - global_position.x) < 28.0 \
			and absf(target.global_position.y - global_position.y) < 34.0:
		target.take_damage(1)
	queue_redraw()

func take_damage(amount: int) -> void:
	health -= amount
	if health <= 0:
		queue_free()

func _draw() -> void:
	draw_rect(Rect2(-16, -10, 32, 20), Color(0.3, 0.7, 0.2))
	draw_circle(Vector2(dir * 10, -3), 3.0, Color.RED)
