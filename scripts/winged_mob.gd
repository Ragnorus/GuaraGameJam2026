class_name WingedMob
extends Bug

# Flying mob: a winged robot in Yeral's level or a helicopter money minion in Bichema's World.
# Hovers above its post, then telegraphs and swoops at the player.

const ROBOT_FRAMES := preload("res://assets/robot_frames.tres")
const MONEY_FRAMES := preload("res://assets/money_minion_frames.tres")
const HOVER_HEIGHT := 210.0
const SWOOP_SPEED := 430.0
const RETURN_SPEED := 170.0
# Right wing outline relative to the shoulder; the left wing is mirrored.
const WING := [Vector2(0, 0), Vector2(14, -20), Vector2(34, -34), Vector2(58, -36), Vector2(54, -24),
		Vector2(48, -10), Vector2(40, -16), Vector2(34, -2), Vector2(24, -8), Vector2(16, 6)]
const WING_RIBS := [2, 3, 5, 7]
const WING_SCALE := 1.3

var bichema := false
var hover_y := 0.0
var time := randf() * TAU
var state := "hover"
var state_time := 0.0
var swoop_dir := Vector2.ZERO
var dying := false
var fall_speed := 0.0
var membrane: Color
var rib: Color
var glow: Color
var tip: Color
const OUTLINE := Color8(8, 13, 10)

func _ready() -> void:
	super._ready()
	health = GameSettings.scale_health(2)
	speed = 90.0
	patrol = 170.0
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	# Layer 2 only: shots and minions still hit it, but it ignores walls/gates and never body-blocks the player.
	collision_layer = 2
	collision_mask = 0
	(cs.shape as RectangleShape2D).size = Vector2(44, 40)
	hover_y = position.y
	if bichema:
		sprite = AnimatedSprite2D.new()
		sprite.sprite_frames = MONEY_FRAMES
		sprite.scale = Vector2(0.32, 0.32)
		sprite.centered = false
		sprite.offset = Vector2(-192, -240)
		sprite.position.y = 20.0
		sprite.play(&"fly")
	else:
		membrane = Color8(41, 68, 42, 235)
		rib = Color8(112, 237, 24)
		glow = Color8(156, 255, 34, 55)
		tip = Color8(217, 154, 40)
		sprite = AnimatedSprite2D.new()
		sprite.sprite_frames = ROBOT_FRAMES
		sprite.scale = Vector2(0.21, 0.21)
		sprite.centered = false
		sprite.offset = Vector2(-128, -240)
		sprite.position.y = 30.0
		sprite.play(&"idle")
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(sprite)

func _physics_process(delta: float) -> void:
	time += delta
	if dying:
		fall_speed += GRAVITY * 0.6 * delta
		position.y += fall_speed * delta
		rotation += delta * 4.0 * signf(swoop_dir.x if swoop_dir.x != 0.0 else 1.0)
		modulate.a = maxf(0.0, modulate.a - delta * 1.4)
		queue_redraw()
		if modulate.a <= 0.0:
			queue_free()
		return
	var aggro := GameSettings.aggro()
	state_time -= delta
	match state:
		"hover":
			if _at_zone_edge(dir):
				dir = -dir
			elif absf(position.x - origin_x) > patrol:
				dir = 1 if position.x < origin_x else -1
			position.x += dir * speed * aggro * delta
			position.y = hover_y + sin(time * 2.4) * 12.0
			shoot_cd -= delta * aggro
			if shoot_cd <= 0.0 and is_instance_valid(target) and not target.get("dead") \
					and absf(target.global_position.x - global_position.x) < 320.0:
				state = "warn"
				state_time = 0.55 / aggro
				sprite.play(&"fly_warn" if bichema else &"hurt")
		"warn":
			position.y = hover_y + sin(time * 30.0) * 3.0
			if state_time <= 0.0:
				state = "swoop"
				state_time = 1.4
				var aim: Vector2 = (target.global_position if is_instance_valid(target) else global_position + Vector2(0, 200))
				swoop_dir = (aim - global_position).normalized()
				if bichema:
					sprite.play(&"fly")
		"swoop":
			position += swoop_dir * SWOOP_SPEED * aggro * delta
			if state_time <= 0.0 or position.y > target_floor_y() - 30.0:
				state = "return"
		"return":
			position.y = move_toward(position.y, hover_y, RETURN_SPEED * aggro * delta)
			position.x = move_toward(position.x, origin_x, RETURN_SPEED * 0.5 * delta)
			if absf(position.y - hover_y) < 2.0:
				state = "hover"
				shoot_cd = randf_range(1.6, 2.6)
				sprite.play(&"fly" if bichema else &"idle")
	_clamp_to_zone()
	sprite.flip_h = (swoop_dir.x if state == "swoop" else float(dir)) < 0.0
	_touch_damage()
	queue_redraw()

func target_floor_y() -> float:
	return hover_y + HOVER_HEIGHT

func take_damage(amount: int) -> void:
	if dying:
		return
	health -= amount
	if health <= 0:
		dying = true
		dead = true
		_award_points()
		remove_from_group("enemies")
		collision_layer = 0
		cs.set_deferred("disabled", true)
		return
	modulate = Color(2.5, 2.5, 2.5)
	create_tween().tween_property(self, "modulate", Color.WHITE, 0.15)

func _wing_points(side: float, flap: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var shoulder := Vector2(side * 10.0, -8.0)
	for p in WING:
		pts.append(shoulder + Vector2(p.x * side, p.y).rotated(flap * side) * WING_SCALE)
	return pts

func _draw() -> void:
	if bichema:
		return
	var beat := 30.0 if state == "swoop" else 16.0
	var flap := sin(time * beat) * 0.55 - (0.5 if state == "swoop" else 0.0)
	for side in [-1.0, 1.0]:
		var pts := _wing_points(side, flap)
		var halo := PackedVector2Array()
		var c := pts[0]
		for p in pts:
			halo.append(c + (p - c) * 1.12)
		draw_colored_polygon(halo, glow)
		draw_colored_polygon(pts, membrane)
		for i in WING_RIBS:
			draw_line(pts[0], pts[i], rib, 1.6, true)
		var closed := pts.duplicate()
		closed.append(pts[0])
		draw_polyline(closed, OUTLINE, 2.4, true)
		draw_circle(pts[3], 2.6, tip)
		draw_circle(pts[0], 4.0, OUTLINE)
		draw_circle(pts[0], 2.4, rib)
