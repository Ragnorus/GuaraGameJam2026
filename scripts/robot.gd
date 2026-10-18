class_name Robot
extends Bug

const ROBOT_FRAMES := preload("res://assets/robot_frames.tres")

var dying := false

func _ready() -> void:
	super._ready()
	(cs.shape as RectangleShape2D).size = Vector2(54, 72)
	sprite = AnimatedSprite2D.new()
	sprite.sprite_frames = ROBOT_FRAMES
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.scale = Vector2(0.24, 0.24)
	sprite.centered = false
	sprite.offset = Vector2(-128, -240)
	sprite.position.y = cs.position.y + (cs.shape as RectangleShape2D).size.y / 2.0
	add_child(sprite)
	sprite.animation_finished.connect(_on_animation_finished)
	sprite.play(&"idle")

func _physics_process(delta: float) -> void:
	if dying:
		return
	super._physics_process(delta)
	_update_locomotion()

func _update_locomotion() -> void:
	var moving := absf(get_position_delta().x) > 0.001
	if moving:
		sprite.flip_h = get_position_delta().x < 0.0
	if sprite.animation != &"hurt":
		sprite.play(&"walk" if moving else &"idle")

func take_damage(amount: int) -> bool:
	if dying:
		return false
	health -= amount
	if health <= 0:
		dying = true
		dead = true
		_award_points()
		remove_from_group("enemies")
		set_physics_process(false)
		velocity = Vector2.ZERO
		collision_layer = 0
		collision_mask = 0
		for child in get_children():
			if child is CollisionShape2D:
				child.set_deferred("disabled", true)
		sprite.play(&"death")
	else:
		voice.cue(&"hurt", target)
		sprite.stop()
		sprite.play(&"hurt")
	return true

func _on_animation_finished() -> void:
	if dying:
		queue_free()
	elif sprite.animation == &"hurt":
		sprite.play(&"idle")
		_update_locomotion()

func _draw() -> void:
	pass
