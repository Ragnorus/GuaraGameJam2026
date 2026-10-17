class_name BossEvilGenius
extends CharacterBody2D

signal defeated
signal health_changed(current: int, maximum: int)
signal speech(text: String, duration: float)

const GRAVITY := 1500.0
const SCALE := 0.55
const BODY := Vector2(120, 220)
const MAX_MINIONS := 5
const LINES_BLAST := ["Citation needed.", "I have the data on that.", "Actually... you're wrong.", "Let me fact-check you."]
const LINES_SUMMON := ["Meet my research assistants.", "Peer review, activate!", "I'm the alpha AND the omega."]
const LINES_CHARGE := ["My ego is bulletproof.", "You can't out-argue me."]

var max_health := 60
var health := 60
var phase := 1
var target: Node2D
var attack_cd := 2.0
var charge_time := 0.0
var charge_windup := 0.0
var charge_dir := 1
var pose_time := 0.0
var pose := &""
var active := false
var dying := false
var flash := 0.0
var sprite: AnimatedSprite2D

func _ready() -> void:
	add_to_group("enemies")
	var shape := RectangleShape2D.new()
	shape.size = BODY
	var cs := CollisionShape2D.new()
	cs.shape = shape
	add_child(cs)
	var frames := SpriteLib.build("evil_genius", {
		"idle": [["idle", "staff"], 2.0, true],
		"run": [["run"], 1.0, true],
		"jump": [["jump"], 1.0, true],
		"point": [["point"], 1.0, true],
		"blast": [["blast"], 1.0, true],
		"shield": [["shield"], 1.0, true],
		"hurt": [["hurt"], 1.0, true],
	})
	sprite = SpriteLib.make_sprite(frames, 0.0)
	sprite.scale = Vector2(SCALE, SCALE)
	# Canvas is 662x439 with the boots 4px above its bottom edge.
	sprite.position.y = BODY.y / 2.0 + 4.0 * SCALE - 439.0 * SCALE / 2.0
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(sprite)
	sprite.play(&"idle")

func activate() -> void:
	active = true
	health_changed.emit(health, max_health)

func _say(lines: Array) -> void:
	speech.emit(lines[randi() % lines.size()], 2.0)

func _physics_process(delta: float) -> void:
	flash = maxf(0.0, flash - delta)
	pose_time = maxf(0.0, pose_time - delta)
	if not is_on_floor():
		velocity.y += GRAVITY * delta
	if not active or dying or not is_instance_valid(target):
		velocity.x = move_toward(velocity.x, 0.0, 1200.0 * delta)
		move_and_slide()
		_update_art()
		return
	var mult := 1.0 + 0.5 * (phase - 1)
	if charge_windup > 0.0:
		charge_windup -= delta
		velocity.x = 0.0
		if charge_windup <= 0.0:
			charge_time = 0.8
	elif charge_time > 0.0:
		charge_time -= delta
		velocity.x = charge_dir * 520.0 * mult
		if is_on_wall():
			charge_time = 0.0
	else:
		velocity.x = move_toward(velocity.x, 0.0, 1200.0 * delta)
		attack_cd -= delta
		if attack_cd <= 0.0:
			_pick_attack()
			attack_cd = 2.2 / mult
	move_and_slide()
	if target.has_method("take_damage") \
			and absf(target.global_position.x - global_position.x) < 95.0 \
			and absf(target.global_position.y - global_position.y) < 125.0:
		target.take_damage(2)
	_update_art()

func _update_art() -> void:
	var next := &"idle"
	if dying or (pose_time > 0.0 and pose == &"hurt"):
		next = &"hurt"
	elif charge_windup > 0.0:
		next = &"shield"
	elif charge_time > 0.0:
		next = &"run"
	elif pose_time > 0.0:
		next = pose
	elif not is_on_floor():
		next = &"jump"
	if is_instance_valid(target) and not dying:
		sprite.flip_h = target.global_position.x < global_position.x
	if sprite.animation != next:
		sprite.play(next)
	sprite.modulate = Color(1.0, 0.45, 0.45) if flash > 0.0 else Color.WHITE

func _pick_attack() -> void:
	var r := randi() % 3
	if r == 0:
		_blast()
	elif r == 1:
		_summon()
	else:
		charge_dir = 1 if target.global_position.x > global_position.x else -1
		charge_windup = 0.35
		_say(LINES_CHARGE)

func _blast() -> void:
	pose = &"blast"
	pose_time = 0.5
	_say(LINES_BLAST)
	var count := 1 + phase
	var dir := 1.0 if target.global_position.x > global_position.x else -1.0
	for i in range(count):
		var p := Projectile.new()
		p.target_group = "player"
		p.color = Color(1.0, 0.2, 0.15)
		p.radius = 12.0
		p.position = global_position + Vector2(dir * 70.0, -40.0)
		var aim := (target.global_position - p.position).normalized()
		p.velocity = aim.rotated((i - (count - 1) / 2.0) * 0.25) * 340.0
		get_parent().add_child(p)

func _summon() -> void:
	pose = &"point"
	pose_time = 0.6
	_say(LINES_SUMMON)
	var alive := 0
	for e in get_tree().get_nodes_in_group("enemies"):
		if e is TruffleAndroid:
			alive += 1
	for i in range(mini(phase + 1, MAX_MINIONS - alive)):
		var b := TruffleAndroid.new()
		b.target = target
		b.health = 1
		b.patrol = 300.0
		b.position = global_position + Vector2(randf_range(-120, 120), -30)
		get_parent().add_child(b)

func take_damage(amount: int) -> void:
	if not active or dying:
		return
	var old_phase := phase
	health = maxi(0, health - amount)
	flash = 0.1
	phase = 1 if health > max_health * 2.0 / 3.0 else (2 if health > max_health / 3.0 else 3)
	health_changed.emit(health, max_health)
	if health <= 0:
		_die()
	elif phase != old_phase:
		pose = &"hurt"
		pose_time = 0.5
		attack_cd = maxf(attack_cd, 1.0)

# His only weakness: a girl boss lawyer objects, and the Evil Genius collapses.
func _die() -> void:
	dying = true
	active = false
	charge_time = 0.0
	charge_windup = 0.0
	remove_from_group("enemies")
	velocity = Vector2.ZERO
	speech.emit("Objection! ...Sustained?!", 2.0)
	var lawyer := Sprite2D.new()
	lawyer.texture = SpriteLib.texture("evil_genius_fx", "lawyer")
	lawyer.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	lawyer.scale = Vector2(0.5, 0.5)
	var side := -1.0 if sprite.flip_h else 1.0
	lawyer.position = Vector2(side * 170.0, BODY.y / 2.0 - lawyer.texture.get_height() * 0.25)
	lawyer.flip_h = side < 0.0
	lawyer.modulate.a = 0.0
	add_child(lawyer)
	create_tween().tween_property(lawyer, "modulate:a", 1.0, 0.3)
	_update_art()
	await get_tree().create_timer(0.6).timeout
	defeated.emit()
	queue_free()
