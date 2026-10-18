class_name Turret
extends StaticBody2D

# Stationary sentry: telegraphs with a glowing barrel, then fires a slow bolt. Optional, so it never gates a room exit.

const RANGE := 520.0
const WARN := 0.6
const FIRE_INTERVAL := 2.2
const BOLT_SPEED := 300.0
const SIZE := Vector2(54, 44)

var health := 3
var dead := false
var optional := true
var points := 2
var facing := -1
var target: Node2D
var zone_min := -INF
var zone_max := INF
var cooldown := 1.2
var warn_time := 0.0
var flash := 0.0

func _ready() -> void:
	add_to_group("enemies")
	health = GameSettings.scale_health(health)
	# Layer 2 only: shots and minions hit it, but it never blocks the player.
	collision_layer = 2
	collision_mask = 0
	var cs := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = SIZE
	cs.shape = shape
	add_child(cs)

func _physics_process(delta: float) -> void:
	if dead:
		return
	flash = maxf(0.0, flash - delta)
	if is_instance_valid(target) and not target.get("dead"):
		var dx: float = target.global_position.x - global_position.x
		if absf(dx) < RANGE and absf(target.global_position.y - global_position.y) < 260.0:
			facing = 1 if dx > 0.0 else -1
			if warn_time > 0.0:
				warn_time -= delta
				if warn_time <= 0.0:
					_fire()
			else:
				cooldown -= delta * GameSettings.aggro()
				if cooldown <= 0.0:
					warn_time = WARN
		else:
			warn_time = 0.0
	queue_redraw()

func _fire() -> void:
	cooldown = FIRE_INTERVAL
	var p := Projectile.new()
	p.target_group = "player"
	p.color = Color(1.0, 0.55, 0.2)
	p.texture = SpriteLib.texture("robot_fx", "bolt")
	p.position = global_position + Vector2(facing * 36, -10)
	p.velocity = Vector2(facing * BOLT_SPEED, 0.0)
	get_parent().add_child(p)

func take_damage(amount: int) -> void:
	if dead:
		return
	health -= amount
	flash = 0.12
	queue_redraw()
	if health > 0:
		return
	dead = true
	remove_from_group("enemies")
	collision_layer = 0
	GameSettings.add_score(points)
	GameAudio.play(get_tree(), "kill")
	Pickup.drop_loot(self, target)
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.4)
	tween.tween_callback(queue_free)

func _draw() -> void:
	var body := Color(0.78, 0.9, 1.0) if flash > 0.0 else Color8(70, 82, 78)
	draw_rect(Rect2(-27, -4, 54, 26), body)
	draw_rect(Rect2(-27, -4, 54, 26), Color8(8, 13, 10), false, 3.0)
	draw_rect(Rect2(-16, -22, 32, 20), body.lightened(0.1))
	draw_rect(Rect2(-16, -22, 32, 20), Color8(8, 13, 10), false, 3.0)
	var tip := Vector2(facing * 34.0, -12.0)
	draw_line(Vector2(0, -12), tip, Color8(8, 13, 10), 10.0)
	draw_line(Vector2(0, -12), tip, Color8(112, 128, 120), 6.0)
	var glow := Color(1.0, 0.3, 0.15) if warn_time > 0.0 else Color8(112, 237, 24)
	draw_circle(Vector2(0, -12), 5.0, glow)
	if warn_time > 0.0:
		draw_circle(tip, 8.0 + sin(warn_time * 40.0) * 2.0, Color(1.0, 0.45, 0.15, 0.6))
	if not dead:
		draw_rect(Rect2(-20, -34, 40.0 * health / maxf(1.0, float(GameSettings.scale_health(3))), 4), Color8(156, 255, 34))
