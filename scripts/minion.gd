class_name Minion
extends Node2D

const SPEED := 280.0
const CHARACTER_FRAMES := preload("res://assets/character_frames.tres")

var owner_player: Node2D
var lifetime := 0.0
var recalled := 0.0
var attack_cd := 0.0
var bob := randf() * TAU
var sprite: AnimatedSprite2D

func _ready() -> void:
	sprite = AnimatedSprite2D.new()
	sprite.sprite_frames = CHARACTER_FRAMES
	sprite.scale = Vector2(0.34, 0.34)
	sprite.animation_finished.connect(_on_animation_finished)
	add_child(sprite)
	sprite.play(&"shadow_spawn")

func recall() -> void:
	recalled = 2.0

func _physics_process(delta: float) -> void:
	if not is_instance_valid(owner_player):
		queue_free()
		return
	bob += delta * 6.0
	attack_cd = maxf(0.0, attack_cd - delta)
	recalled = maxf(0.0, recalled - delta)
	if recalled > 0.0:
		sprite.play(&"shadow_recall")
	elif sprite.animation == &"shadow_recall":
		sprite.play(&"shadow_fly")
	if lifetime > 0.0:
		lifetime -= delta
		if lifetime <= 0.0:
			queue_free()
			return
	var target := _nearest_enemy()
	var dest: Vector2
	if target and recalled <= 0.0:
		dest = target.global_position
	else:
		dest = owner_player.global_position + Vector2(randf_range(-1, 1) * 0.0 + sin(bob) * 30.0, -50.0)
	var to := dest - global_position
	if to.x != 0.0:
		sprite.flip_h = to.x < 0.0
	if to.length() > 4.0:
		global_position += to.normalized() * minf(SPEED * delta, to.length())
	if target and recalled <= 0.0 and attack_cd <= 0.0 \
			and global_position.distance_to(target.global_position) < 40.0:
		attack_cd = 0.5
		if sprite.animation != &"shadow_spawn":
			sprite.play(&"shadow_attack")
		target.take_damage(1)
		if owner_player.has_method("add_meter"):
			owner_player.add_meter(2.0)

func _nearest_enemy() -> Node2D:
	var best: Node2D = null
	var best_d := 500.0
	for e in get_tree().get_nodes_in_group("enemies"):
		var d := global_position.distance_to(e.global_position)
		if d < best_d:
			best_d = d
			best = e
	return best

func _on_animation_finished() -> void:
	sprite.play(&"shadow_recall" if recalled > 0.0 else &"shadow_fly")
