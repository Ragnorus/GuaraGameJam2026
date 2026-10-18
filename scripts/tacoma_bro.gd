class_name TacomaBro
extends Bug

const LUDO_FRAMES := preload("res://assets/tacoma_ludo_frames.tres")
const CAPI_FRAMES := preload("res://assets/tacoma_capi_frames.tres")
const TOYOTA_PROJECTILE := preload("res://assets/tacoma_toyota_projectile.png")
const LUDO_TARGET_DEADZONE := 24.0

var bro_name: StringName = &"ludo"
var sergeant := false
var max_health := 1
var attack_fired := false
var ludo_movement_dir := -1

func _ready() -> void:
	robot = false
	super._ready()
	robot = true
	var body := cs.shape as RectangleShape2D
	body.size = Vector2(72, 100) if sergeant else Vector2(60, 84)
	health = GameSettings.scale_health(12 if sergeant else 7)
	max_health = health
	speed = 72.0 if sergeant else 86.0
	sprite = AnimatedSprite2D.new()
	sprite.sprite_frames = CAPI_FRAMES if bro_name == &"capi" else LUDO_FRAMES
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var scale_factor := 1.0 if bro_name == &"capi" else 0.95
	sprite.scale = Vector2.ONE * scale_factor
	sprite.position.y = body.size.y / 2.0 - 112.0 * scale_factor
	add_child(sprite)
	sprite.play(&"idle")
	queue_redraw()

func _robot_update(delta: float) -> void:
	anim_lock = maxf(0.0, anim_lock - delta)
	sprite.flip_h = dir < 0
	shoot_cd -= delta
	if anim_lock > 0.0:
		if bro_name == &"ludo":
			ludo_movement_dir = dir
		velocity.x = 0.0
		if sprite.animation == &"attack" and sprite.frame >= 1 and not attack_fired:
			_shoot()
		return
	if shoot_cd <= 0.0 and is_instance_valid(target) \
			and absf(target.global_position.x - global_position.x) < 380.0:
		dir = 1 if target.global_position.x > global_position.x else -1
		if bro_name == &"ludo":
			ludo_movement_dir = dir
		anim_lock = 0.55
		attack_fired = false
		sprite.play(&"attack")
		return
	if bro_name == &"ludo":
		var target_aligned := is_instance_valid(target) \
				and absf(target.global_position.x - global_position.x) < LUDO_TARGET_DEADZONE
		if target_aligned and not _at_zone_edge(ludo_movement_dir):
			dir = ludo_movement_dir
			velocity.x = dir * speed * GameSettings.aggro()
		else:
			ludo_movement_dir = dir
		sprite.flip_h = dir < 0
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
	queue_redraw()
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

func _draw() -> void:
	if dead:
		return
	var width := 84.0
	var top := Vector2(-width / 2.0, -88.0)
	draw_rect(Rect2(top - Vector2(2.0, 2.0), Vector2(width + 4.0, 10.0)), Color(0.03, 0.05, 0.04))
	draw_rect(Rect2(top, Vector2(width * health / float(max_health), 6.0)), Color(0.44, 0.93, 0.09))
