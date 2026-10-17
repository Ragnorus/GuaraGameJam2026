class_name TruffleAndroid
extends Bug

const SCALE := 0.42
const SIZE := Vector2(48, 80)

var dying := false

func _ready() -> void:
	super._ready()
	speed = 75.0
	(cs.shape as RectangleShape2D).size = SIZE
	reach_x = 40.0
	reach_y = 60.0
	sprite = SpriteLib.make_sprite(SpriteLib.build("truffle_android", {
		"idle": [["idle_0", "idle_1"], 4.0, true],
		"run": [["run_0", "run_1"], 6.0, true],
		"warn": [["warn_0"], 1.0, false],
		"shoot": [["shoot_0"], 1.0, false],
		"hurt": [["hurt_0"], 1.0, false],
		"dead": [["dead_0", "dead_1", "dead_2", "dead_3"], 8.0, false],
	}), 0.0)
	sprite.scale = Vector2(SCALE, SCALE)
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	# Canvas is 228x210 with the feet 4px above its bottom edge.
	sprite.position.y = SIZE.y / 2.0 + 4.0 * SCALE - 210.0 * SCALE / 2.0
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
	if anim_lock > 0.0:
		velocity.x = 0.0
		if shoot_cd <= 0.0 and sprite.animation == &"warn":
			_fire()
		return
	if shoot_cd <= 0.0 and is_instance_valid(target) \
			and absf(target.global_position.x - global_position.x) < 400.0:
		anim_lock = 0.7
		sprite.play(&"warn")
		get_tree().create_timer(0.5).timeout.connect(_fire)
		return
	var want := &"run" if absf(velocity.x) > 1.0 else &"idle"
	if sprite.animation != want and sprite.animation != &"hurt":
		sprite.play(want)

func _fire() -> void:
	if dying or not is_inside_tree() or sprite.animation != &"warn":
		return
	shoot_cd = 3.0 / GameSettings.aggro()
	sprite.play(&"shoot")
	anim_lock = 0.3
	var p := Projectile.new()
	p.target_group = "player"
	p.color = Color(1.0, 0.2, 0.15)
	p.radius = 8.0
	p.position = global_position + Vector2(dir * 34, -8)
	p.velocity = Vector2(dir * 320.0, 0.0)
	get_parent().add_child(p)

func take_damage(amount: int) -> void:
	if dying:
		return
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

func _on_animation_finished() -> void:
	if dying:
		queue_free()

func _draw() -> void:
	pass
