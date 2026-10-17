class_name Projectile
extends Area2D

const CHARACTER_FRAMES := preload("res://assets/character_frames.tres")

var velocity := Vector2.ZERO
var damage := 1
var target_group := "enemies"
var color := Color(0.4, 0.9, 1.0)
var radius := 8.0
var life := 3.0
var texture: Texture2D
var character_art := false
var sprite: AnimatedSprite2D

func _ready() -> void:
	collision_layer = 0
	collision_mask = 0xFFFFFFFF
	var shape := CircleShape2D.new()
	shape.radius = radius
	var cs := CollisionShape2D.new()
	cs.shape = shape
	add_child(cs)
	body_entered.connect(_on_body_entered)
	if character_art and target_group != "player":
		sprite = AnimatedSprite2D.new()
		sprite.sprite_frames = CHARACTER_FRAMES
		sprite.scale = Vector2(0.34, 0.34)
		sprite.flip_h = velocity.x < 0.0
		add_child(sprite)
		sprite.play(&"projectile")

func _physics_process(delta: float) -> void:
	if sprite != null and velocity.x != 0.0:
		sprite.flip_h = velocity.x < 0.0
	position += velocity * delta
	life -= delta
	if life <= 0.0:
		queue_free()

func _draw() -> void:
	if texture != null:
		draw_set_transform(Vector2.ZERO, velocity.angle())
		draw_texture(texture, -texture.get_size() / 2.0)
		return
	if sprite == null:
		draw_circle(Vector2.ZERO, radius, color)

func _on_body_entered(body: Node) -> void:
	if body.is_in_group(target_group) and body.has_method("take_damage"):
		body.take_damage(damage)
		queue_free()
	elif body is StaticBody2D:
		queue_free()
