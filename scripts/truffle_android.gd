class_name TruffleAndroid
extends Bug

const SCALE := 0.42
const SIZE := Vector2(48, 80)
const FRAMES := preload("res://assets/money_minion_frames.tres")

var dying := false

func _ready() -> void:
	super._ready()
	speed = 75.0
	(cs.shape as RectangleShape2D).size = SIZE
	sprite = AnimatedSprite2D.new()
	sprite.sprite_frames = FRAMES
	sprite.scale = Vector2(SCALE, SCALE)
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.centered = false
	sprite.offset = Vector2(-192, -240)
	sprite.position.y = SIZE.y / 2.0
	add_child(sprite)
	sprite.animation_finished.connect(_on_animation_finished)
	sprite.play(&"run")

func _physics_process(delta: float) -> void:
	if dying:
		return
	super._physics_process(delta)
	anim_lock = maxf(0.0, anim_lock - delta)
	sprite.flip_h = dir < 0
	shoot_cd -= delta
	if anim_lock > 0.0 or (sprite.animation == &"hurt" and sprite.is_playing()):
		velocity.x = 0.0
		return
	if shoot_cd <= 0.0 and is_instance_valid(target) \
			and absf(target.global_position.x - global_position.x) < 400.0:
		anim_lock = 0.7
		sprite.play(&"warn")
		get_tree().create_timer(0.5).timeout.connect(_fire)
		return
	var want := &"run" if absf(velocity.x) > 1.0 else &"idle"
	if sprite.animation != want:
		sprite.play(want)

func _fire() -> void:
	if dying or not is_inside_tree() or sprite.animation != &"warn":
		return
	shoot_cd = 3.0 / GameSettings.aggro()
	sprite.play(&"shoot")
	anim_lock = 0.3
	var p := Projectile.new()
	p.target_group = "player"
	p.texture = FRAMES.get_frame_texture(&"money_bolt", 0)
	p.texture_scale = Vector2(0.25, 0.25)
	p.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	p.radius = 8.0
	p.coin_pop = true
	p.texture_outline_color = Projectile.GOLD_OUTLINE_COLOR
	p.position = global_position + Vector2(dir * 34, -8)
	p.velocity = Vector2(dir * 320.0, 0.0)
	if is_in_group("evil_genius_attacks"):
		p.add_to_group("evil_genius_attacks")
	get_parent().add_child(p)

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
		cs.set_deferred("disabled", true)
		sprite.play(&"dead")
	elif anim_lock <= 0.0:
		anim_lock = 0.25
		sprite.play(&"hurt")
	return true

func _on_animation_finished() -> void:
	if dying and sprite.animation == &"dead":
		queue_free()
	elif sprite.animation == &"hurt":
		anim_lock = 0.0
		sprite.play(&"run" if absf(velocity.x) > 1.0 else &"idle")

func _draw() -> void:
	pass
