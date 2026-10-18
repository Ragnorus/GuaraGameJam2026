class_name TacomaBro
extends Bug

const LUDO_FRAMES := preload("res://assets/tacoma_ludo_frames.tres")
const CAPI_FRAMES := preload("res://assets/tacoma_capi_frames.tres")
const TOYOTA_PROJECTILE := preload("res://assets/tacoma_toyota_projectile.png")

var bro_name: StringName = &"ludo"
var sergeant := false
var attack_fired := false

func _ready() -> void:
	robot = false
	super._ready()
	robot = true
	var body := cs.shape as RectangleShape2D
	body.size = Vector2(60, 84) if sergeant else Vector2(48, 68)
	health = GameSettings.scale_health(12 if sergeant else 7)
	speed = 72.0 if sergeant else 86.0
	sprite = AnimatedSprite2D.new()
	sprite.sprite_frames = CAPI_FRAMES if bro_name == &"capi" else LUDO_FRAMES
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var scale_factor := 0.52 if bro_name == &"capi" else 0.48
	sprite.scale = Vector2.ONE * scale_factor
	sprite.position.y = body.size.y / 2.0 - 112.0 * scale_factor
	add_child(sprite)
	sprite.play(&"idle")

func _robot_update(delta: float) -> void:
	anim_lock = maxf(0.0, anim_lock - delta)
	sprite.flip_h = dir < 0
	shoot_cd -= delta
	if anim_lock > 0.0:
		velocity.x = 0.0
		if sprite.animation == &"attack" and sprite.frame >= 1 and not attack_fired:
			_shoot()
		return
	if shoot_cd <= 0.0 and is_instance_valid(target) \
			and absf(target.global_position.x - global_position.x) < 380.0:
		dir = 1 if target.global_position.x > global_position.x else -1
		anim_lock = 0.55
		attack_fired = false
		sprite.play(&"attack")
		return
	var want: StringName = &"run" if absf(velocity.x) > 1.0 else &"idle"
	if sprite.animation != want:
		sprite.play(want)

func _shoot() -> void:
	attack_fired = true
	shoot_cd = 3.0 / GameSettings.aggro()
	var shot := Projectile.new()
	shot.target_group = "player"
	shot.texture = TOYOTA_PROJECTILE
	shot.texture_scale = Vector2.ONE * 0.2
	shot.radius = 7.0
	shot.position = global_position + Vector2(dir * 32.0, -14.0)
	shot.velocity = Vector2(dir * 320.0, 0.0)
	get_parent().add_child(shot)

func take_damage(amount: int) -> void:
	if dead:
		return
	health -= amount
	if health <= 0:
		_die()

func _die() -> void:
	dead = true
	remove_from_group("enemies")
	collision_layer = 0
	collision_mask = 0
	cs.set_deferred("disabled", true)
	_award_points()
	queue_free()
