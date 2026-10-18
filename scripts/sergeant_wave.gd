class_name SergeantWave
extends Area2D

var direction := 1
var speed := 380.0
var damage := 1
var stun := 1.1
var life := 1.6
var texture: Texture2D

func _ready() -> void:
	add_to_group("sergeant_attacks")
	collision_layer = 0
	collision_mask = 1
	var shape := RectangleShape2D.new()
	shape.size = Vector2(110, 64)
	var cs := CollisionShape2D.new()
	cs.shape = shape
	add_child(cs)
	var sprite := Sprite2D.new()
	sprite.texture = texture
	sprite.scale = Vector2(0.5 * direction, 0.5)
	add_child(sprite)
	body_entered.connect(_on_body_entered)

func _physics_process(delta: float) -> void:
	position.x += direction * speed * delta
	life -= delta
	modulate.a = clampf(life / 0.3, 0.0, 1.0)
	if life <= 0.0:
		queue_free()

func _on_body_entered(body: Node) -> void:
	if is_queued_for_deletion() or not body is Player:
		return
	# The scream only damages and stuns; it never shoves.
	if (body as Player).hit_by(damage, Vector2.ZERO, stun):
		queue_free()
