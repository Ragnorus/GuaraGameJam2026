class_name Sergeant
extends CharacterBody2D

signal speech(text: String, duration: float)
signal acid_escaped
signal defeated

enum State { IDLE, LEAP, CHARGE, PUNCH, SCREAM, HURT, TRANSFORM, DEAD, FALL }

const FRAMES := preload("res://assets/sergeant_frames.tres")
const BODY := Vector2(70, 128)
const SPRITE_SCALE := 1.0
const BASE_HEALTH := 12
const EDGE_MARGIN := 32.0
const CHARGE_SPEED := 430.0
const WALK_SPEED := 95.0
const GRAVITY := 1500.0
const PUNCH_REACH := 115.0
const RAGE_MULT := 1.25
const PLAYER_HALF := Vector2(21, 36)
const RAGE_LINE := "ROID RAGE!!! NO PAIN, NO GAIN!"

class AcidSplash extends Node2D:
	const LIFE := 0.7
	var life := LIFE
	var drops: Array[Vector2] = []
	var speeds: Array[Vector2] = []

	func _ready() -> void:
		z_index = 4
		for i in range(12):
			drops.append(Vector2.ZERO)
			speeds.append(Vector2(-200.0 + i * 36.0, -420.0 + absf(i - 5.5) * 30.0))

	func _process(delta: float) -> void:
		life -= delta
		for i in range(drops.size()):
			speeds[i].y += 1100.0 * delta
			drops[i] += speeds[i] * delta
		queue_redraw()
		if life <= 0.0:
			queue_free()

	func _draw() -> void:
		var alpha := clampf(life / LIFE, 0.0, 1.0)
		draw_arc(Vector2.ZERO, 70.0 * (1.0 - alpha) + 20.0, PI, TAU, 16, Color(0.7, 1.0, 0.2, alpha), 5.0)
		for drop in drops:
			draw_circle(drop, 6.0, Color(0.05, 0.15, 0.02, alpha))
			draw_circle(drop, 4.0, Color(0.55, 1.0, 0.15, alpha))

var target: Node2D
var platforms: Array[Rect2] = []
# The acid surface the sergeant may fall into; it never hurts him, it only launches his recovery jump.
var acid_rect := Rect2()
# Solid banks around the acid: he can land on them (then hops back) and can't fall through their sides.
var banks: Array[Rect2] = []
var ai_enabled := true
var platform_index := 1
var max_health := BASE_HEALTH
var health := BASE_HEALTH
var points := 5
var dead := false
var raged := false
var pending_rage := false
var state := State.IDLE
var state_time := 0.0
var cooldown := 1.0
var facing := -1
var walk_dir := -1
var attack_count := 0
var acid_escapes := 0
var hit_landed := false
var leap_from := Vector2.ZERO
var leap_to := Vector2.ZERO
var leap_duration := 0.75
var leap_apex := 170.0
var flash := 0.0
var _airborne_dead := false
var sprite: AnimatedSprite2D

func _ready() -> void:
	add_to_group("enemies")
	max_health = GameSettings.scale_health(BASE_HEALTH)
	health = max_health
	# Own layer, no mask: shots/minions still hit him, but the player isn't physically blocked by a body
	# that is placed directly every frame.
	collision_layer = 16
	collision_mask = 0
	var shape := RectangleShape2D.new()
	shape.size = BODY
	var cs := CollisionShape2D.new()
	cs.shape = shape
	add_child(cs)
	sprite = AnimatedSprite2D.new()
	sprite.sprite_frames = FRAMES
	sprite.centered = false
	sprite.offset = Vector2(-224, -244)
	sprite.scale = Vector2(SPRITE_SCALE, SPRITE_SCALE)
	sprite.position.y = BODY.y / 2.0
	add_child(sprite)
	sprite.play(&"idle")

func standing_y(index: int) -> float:
	return platforms[index].position.y - BODY.y / 2.0

func _anim(base: StringName) -> StringName:
	return StringName("rage_" + base) if raged and FRAMES.has_animation("rage_" + base) else base

func _rate() -> float:
	return (RAGE_MULT if raged else 1.0) * GameSettings.aggro()

func _bonus() -> int:
	return 1 if raged else 0

func _set_state(next: State, animation: StringName) -> void:
	state = next
	state_time = 0.0
	hit_landed = false
	sprite.speed_scale = _rate()
	sprite.play(_anim(animation))

func _target_alive() -> bool:
	return is_instance_valid(target) and not (target is Player and (target.dead or target.controls_locked))

func _physics_process(delta: float) -> void:
	flash = maxf(0.0, flash - delta)
	sprite.modulate = Color(1.6, 1.6, 1.6) if flash > 0.0 else Color.WHITE
	queue_redraw()
	if state == State.DEAD:
		if _airborne_dead:
			_update_fall(delta)
		return
	state_time += delta
	sprite.flip_h = facing < 0
	match state:
		State.IDLE:
			_update_idle(delta)
		State.LEAP:
			_update_leap()
		State.FALL:
			_update_fall(delta)
		State.CHARGE:
			_update_charge(delta)
		State.PUNCH:
			_update_punch()
		State.SCREAM:
			_update_scream()
		State.HURT:
			if state_time >= 0.2:
				_set_state(State.IDLE, &"idle")
		State.TRANSFORM:
			if not sprite.is_playing() and state_time >= 1.2:
				raged = true
				cooldown = 0.5
				_set_state(State.IDLE, &"idle")
	if state != State.LEAP and state != State.TRANSFORM:
		_touch_damage()

func _player_platform() -> int:
	if not (target is Player) or not target.is_on_floor():
		return -1
	for i in range(platforms.size()):
		var rect := platforms[i]
		if target.position.x >= rect.position.x - 4.0 and target.position.x <= rect.end.x + 4.0 \
				and absf(target.position.y + PLAYER_HALF.y - rect.position.y) < 6.0:
			return i
	return -1

func _edge_clamp(index: int, x: float) -> float:
	return clampf(x, platforms[index].position.x + EDGE_MARGIN, platforms[index].end.x - EDGE_MARGIN)

# Between attacks he never stands still: he stalks the player on his block, or paces while they're elsewhere.
func _update_idle(delta: float) -> void:
	if not _target_alive() or not ai_enabled:
		sprite.speed_scale = 0.6
		return
	var on := _player_platform()
	var dx: float = target.global_position.x - global_position.x
	var step := 0.0
	if on == platform_index:
		facing = 1 if dx > 0.0 else -1
		if absf(dx) > PUNCH_REACH * 0.8:
			step = facing
	else:
		var rect := platforms[platform_index]
		if position.x <= rect.position.x + EDGE_MARGIN + 1.0:
			walk_dir = 1
		elif position.x >= rect.end.x - EDGE_MARGIN - 1.0:
			walk_dir = -1
		step = walk_dir
		facing = walk_dir
	position.x = _edge_clamp(platform_index, position.x + step * WALK_SPEED * _rate() * delta)
	sprite.speed_scale = (1.3 if step != 0.0 else 0.6) * _rate()
	var close := on == platform_index and absf(dx) <= PUNCH_REACH * 0.8
	cooldown -= delta * _rate() * (2.0 if close else 1.0)
	if cooldown > 0.0 or absf(dx) > 1000.0:
		return
	attack_count += 1
	if on >= 0 and on != platform_index:
		start_leap(on)
	elif on == platform_index and absf(dx) < PUNCH_REACH:
		start_punch()
	elif on == platform_index and attack_count % 3 != 0:
		start_charge()
	else:
		start_scream()

func start_leap(index: int, land_x := NAN) -> void:
	var rect := platforms[index]
	if is_nan(land_x):
		# Land on the far side of the platform from the player, so the follow-up charge drives them to the edge.
		land_x = rect.position.x + EDGE_MARGIN if target.global_position.x > rect.get_center().x else rect.end.x - EDGE_MARGIN
	leap_from = position
	leap_to = Vector2(_edge_clamp(index, land_x), standing_y(index))
	leap_duration = 0.75 / _rate()
	leap_apex = 170.0
	platform_index = index
	facing = 1 if leap_to.x > leap_from.x else -1
	_set_state(State.LEAP, &"jump")

func _update_leap() -> void:
	var t := clampf(state_time / leap_duration, 0.0, 1.0)
	position = leap_from.lerp(leap_to, t) + Vector2(0, -leap_apex * 4.0 * t * (1.0 - t))
	if t >= 1.0:
		_land(0.3)

func _land(next_cooldown: float) -> void:
	cooldown = next_cooldown
	var squash := create_tween()
	sprite.scale = Vector2(SPRITE_SCALE * 1.12, SPRITE_SCALE * 0.88)
	squash.tween_property(sprite, "scale", Vector2(SPRITE_SCALE, SPRITE_SCALE), 0.18)
	if pending_rage:
		pending_rage = false
		_start_transform()
	else:
		_set_state(State.IDLE, &"idle")

func start_fall(launch: Vector2) -> void:
	velocity = launch
	_set_state(State.FALL, &"jump")

func _landing_platform(previous_feet: float, feet: float) -> int:
	for i in range(platforms.size()):
		var rect := platforms[i]
		if previous_feet <= rect.position.y and feet >= rect.position.y \
				and position.x >= rect.position.x and position.x <= rect.end.x:
			return i
	return -1

func _update_fall(delta: float) -> void:
	var previous := position
	var previous_feet := position.y + BODY.y / 2.0
	velocity.y += GRAVITY * delta
	position += velocity * delta
	var half := BODY.x / 2.0
	var feet := position.y + BODY.y / 2.0
	for bank in banks:
		var overlapping := position.x + half > bank.position.x and position.x - half < bank.end.x
		if velocity.y > 0.0 and overlapping and previous_feet <= bank.position.y and feet >= bank.position.y:
			position.y = bank.position.y - BODY.y / 2.0
			velocity = Vector2.ZERO
			if state == State.DEAD:
				_airborne_dead = false
			else:
				_recover(false)
			return
		if overlapping and feet > bank.position.y:
			position.x = bank.position.x - half if previous.x < bank.get_center().x else bank.end.x + half
			velocity.x = 0.0
	var landed := _landing_platform(previous_feet, feet) if velocity.y > 0.0 else -1
	if landed >= 0:
		position = Vector2(_edge_clamp(landed, position.x), standing_y(landed))
		velocity = Vector2.ZERO
		_airborne_dead = false
		if state != State.DEAD:
			platform_index = landed
			_land(0.5)
		return
	if acid_rect.has_area() and feet >= acid_rect.position.y + 16.0:
		velocity = Vector2.ZERO
		position.y = acid_rect.position.y + 16.0 - BODY.y / 2.0
		_splash()
		if state == State.DEAD:
			_airborne_dead = false
		else:
			_recover(true)

func _splash() -> void:
	var splash := AcidSplash.new()
	splash.position = Vector2(global_position.x, acid_rect.position.y)
	get_parent().add_child(splash)

# Off his blocks - in the acid (which can't hurt him) or on a bank - he jumps straight back onto the closest block.
func _recover(from_acid: bool) -> void:
	var best := 0
	var best_distance := INF
	for i in range(platforms.size()):
		var distance := absf(_edge_clamp(i, position.x) - position.x) + absf(standing_y(i) - position.y) * 0.25
		if distance < best_distance:
			best = i
			best_distance = distance
	if from_acid:
		acid_escapes += 1
		acid_escaped.emit()
	start_leap(best, position.x)
	leap_duration = 0.7 / _rate()
	leap_apex = 150.0

func start_charge() -> void:
	facing = 1 if target.global_position.x > global_position.x else -1
	_set_state(State.CHARGE, &"charge")
	sprite.pause()
	sprite.frame = 0

func _update_charge(delta: float) -> void:
	var windup := 0.4 / _rate()
	var count := FRAMES.get_frame_count(_anim(&"charge"))
	if state_time < windup:
		sprite.frame = 0 if state_time < windup / 2.0 else 1
		return
	sprite.frame = mini(count - 1, 2 + int((state_time - windup) * 10.0 * _rate()))
	var rect := platforms[platform_index]
	var speed := CHARGE_SPEED * _rate()
	position.x += facing * speed * delta
	if not hit_landed and _touching(14.0) and target is Player:
		hit_landed = (target as Player).hit_by(2 + _bonus(), Vector2(facing * (700.0 + 120.0 * _bonus()), -320.0))
	if hit_landed:
		position.x = _edge_clamp(platform_index, position.x)
		cooldown = 0.9
		_set_state(State.IDLE, &"idle")
	elif position.x < rect.position.x or position.x > rect.end.x:
		# A missed charge has too much momentum to stop: he runs straight off the block.
		start_fall(Vector2(facing * speed * 0.7, -80.0))
	elif state_time > windup + 1.2:
		cooldown = 0.9
		_set_state(State.IDLE, &"idle")

func start_punch() -> void:
	facing = 1 if target.global_position.x > global_position.x else -1
	_set_state(State.PUNCH, &"punch")

func _update_punch() -> void:
	var count := FRAMES.get_frame_count(sprite.animation)
	if not hit_landed and sprite.frame >= count - 2 and _target_alive() and target is Player:
		var d: Vector2 = target.global_position - global_position
		hit_landed = true
		if signf(d.x) == facing and absf(d.x) < PUNCH_REACH + 20.0 and absf(d.y) < 80.0:
			# The punch launches the player up and away - a bounce towards the acid.
			(target as Player).hit_by(2 + _bonus(), Vector2(facing * (480.0 + 80.0 * _bonus()), -560.0 - 60.0 * _bonus()))
	if not sprite.is_playing():
		cooldown = 0.8
		_set_state(State.IDLE, &"idle")

func start_scream() -> void:
	if _target_alive():
		facing = 1 if target.global_position.x > global_position.x else -1
	_set_state(State.SCREAM, &"scream")

func _update_scream() -> void:
	if not hit_landed and not sprite.is_playing():
		hit_landed = true
		var wave := SergeantWave.new()
		wave.direction = facing
		wave.speed = 380.0 * _rate()
		wave.damage = 1 + _bonus()
		wave.stun = 1.4 if raged else 1.1
		wave.texture = FRAMES.get_frame_texture(_anim(&"wave"), 0)
		wave.position = global_position + Vector2(facing * 80.0, -BODY.y / 2.0 + 40.0)
		get_parent().add_child(wave)
	if hit_landed and state_time >= 0.9 / _rate():
		cooldown = 0.9
		_set_state(State.IDLE, &"idle")

func _touching(margin: float) -> bool:
	if not _target_alive():
		return false
	var d := (target.global_position - global_position).abs()
	return d.x < BODY.x / 2.0 + PLAYER_HALF.x + margin and d.y < BODY.y / 2.0 + PLAYER_HALF.y

func _touch_damage() -> void:
	if state != State.CHARGE and _touching(4.0) and target is Player:
		var away := 1.0 if target.global_position.x > global_position.x else -1.0
		(target as Player).hit_by(1, Vector2(away * 300.0, -280.0))

func take_damage(amount: int) -> void:
	if dead or state == State.TRANSFORM:
		return
	health = maxi(0, health - amount)
	flash = 0.1
	if health <= 0:
		_die()
	elif not raged and not pending_rage and health * 2 <= max_health:
		# Never transform mid-air: the rage waits until he's back on a block.
		if state == State.LEAP or state == State.FALL:
			pending_rage = true
		else:
			_start_transform()
	elif state == State.IDLE:
		_set_state(State.HURT, &"hurt")

func _start_transform() -> void:
	clear_attacks()
	_set_state(State.TRANSFORM, &"transform")
	sprite.speed_scale = 1.0
	speech.emit(RAGE_LINE, 2.5)

func clear_attacks() -> void:
	for wave in get_tree().get_nodes_in_group("sergeant_attacks"):
		wave.queue_free()

func _die() -> void:
	dead = true
	_airborne_dead = state == State.LEAP or state == State.FALL
	if state == State.LEAP:
		velocity = Vector2.ZERO
	clear_attacks()
	remove_from_group("enemies")
	collision_layer = 0
	_set_state(State.DEAD, &"death")
	sprite.speed_scale = 1.0
	GameSettings.add_score(points)
	GameAudio.play(get_tree(), "kill")
	defeated.emit()
	var popup := Label.new()
	popup.text = "+%d" % points
	popup.add_theme_font_size_override("font_size", 22)
	popup.modulate = Color(1.0, 0.9, 0.3)
	popup.z_index = 50
	popup.position = global_position + Vector2(-12.0, -90.0)
	get_parent().add_child(popup)
	var tween := popup.create_tween()
	tween.tween_property(popup, "position:y", popup.position.y - 45.0, 0.8)
	tween.parallel().tween_property(popup, "modulate:a", 0.0, 0.8)
	tween.tween_callback(popup.queue_free)
	var fade := create_tween()
	fade.tween_interval(1.4)
	fade.tween_property(self, "modulate:a", 0.0, 0.6)
	fade.tween_callback(queue_free)

func _draw() -> void:
	if dead:
		return
	var width := 70.0
	var top := Vector2(-width / 2.0, -BODY.y / 2.0 - (40.0 if raged else 24.0))
	draw_rect(Rect2(top - Vector2(2, 2), Vector2(width + 4, 10)), Color(0.03, 0.05, 0.04))
	draw_rect(Rect2(top, Vector2(width * health / float(max_health), 6)),
			Color(0.93, 0.25, 0.15) if raged else Color(0.44, 0.93, 0.09))
