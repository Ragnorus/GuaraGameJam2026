class_name Minion
extends Node2D

const SPEED := 280.0

var owner_player: Node2D
var lifetime := 0.0
var recalled := 0.0
var attack_cd := 0.0
var bob := randf() * TAU

func recall() -> void:
	recalled = 2.0

func _physics_process(delta: float) -> void:
	if not is_instance_valid(owner_player):
		queue_free()
		return
	bob += delta * 6.0
	attack_cd = maxf(0.0, attack_cd - delta)
	recalled = maxf(0.0, recalled - delta)
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
	if to.length() > 4.0:
		global_position += to.normalized() * minf(SPEED * delta, to.length())
	if target and recalled <= 0.0 and attack_cd <= 0.0 \
			and global_position.distance_to(target.global_position) < 40.0:
		attack_cd = 0.5
		target.take_damage(1)
		if owner_player.has_method("add_meter"):
			owner_player.add_meter(2.0)
	queue_redraw()

func _nearest_enemy() -> Node2D:
	var best: Node2D = null
	var best_d := 500.0
	for e in get_tree().get_nodes_in_group("enemies"):
		var d := global_position.distance_to(e.global_position)
		if d < best_d:
			best_d = d
			best = e
	return best

func _draw() -> void:
	draw_circle(Vector2.ZERO, 10.0, Color(0.1, 0.05, 0.2))
	draw_circle(Vector2(-3, -2), 2.0, Color(0.7, 0.3, 1.0))
	draw_circle(Vector2(3, -2), 2.0, Color(0.7, 0.3, 1.0))
