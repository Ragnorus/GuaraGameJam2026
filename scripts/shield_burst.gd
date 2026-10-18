class_name ShieldBurst
extends Node2D

const RADIUS := 190.0
const DAMAGE := 3
const LIFE := 0.45

var age := 0.0

static func apply(origin: Vector2, tree: SceneTree) -> int:
	var hits := 0
	for enemy in tree.get_nodes_in_group("enemies"):
		if not is_instance_valid(enemy) or enemy.is_queued_for_deletion() or not enemy.can_process() \
				or enemy.get("dead") == true or not enemy.has_method("take_damage"):
			continue
		if enemy.global_position.distance_to(origin) <= RADIUS:
			enemy.take_damage(DAMAGE)
			hits += 1
	for shot in tree.get_nodes_in_group("enemy_shots"):
		if is_instance_valid(shot) and shot.global_position.distance_to(origin) <= RADIUS:
			shot.queue_free()
	for wave in tree.get_nodes_in_group("sergeant_attacks"):
		if is_instance_valid(wave) and wave.global_position.distance_to(origin) <= RADIUS:
			wave.queue_free()
	return hits

func _process(delta: float) -> void:
	age += delta
	if age >= LIFE:
		queue_free()
		return
	queue_redraw()

func _draw() -> void:
	var t := clampf(age / LIFE, 0.0, 1.0)
	var radius := lerpf(30.0, RADIUS, 1.0 - pow(1.0 - t, 3.0))
	var alpha := 1.0 - t
	draw_circle(Vector2.ZERO, radius, Color(0.35, 0.9, 1.0, 0.12 * alpha))
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 48, Color(0.75, 1.0, 1.0, alpha), 5.0, true)
	draw_arc(Vector2.ZERO, radius * 0.82, 0.0, TAU, 48, Color(0.3, 0.85, 1.0, alpha * 0.7), 3.0, true)
