class_name BossYeral
extends CharacterBody2D

signal defeated
signal health_changed(current: int, maximum: int)
signal speech(text: String, duration: float)

const GRAVITY := 1500.0
const HINT_COOLDOWN := 3.0

# Trap column: shows a warning, then becomes deadly for a moment.
class TrapZone extends Node2D:
	var width := 90.0
	var height := 400.0
	var warn := 1.0
	var live := 0.6
	var target: Node2D

	func _process(delta: float) -> void:
		if warn > 0.0:
			warn -= delta
		else:
			live -= delta
			if is_instance_valid(target) and target.has_method("take_damage") \
					and absf(target.global_position.x - global_position.x) < width / 2.0 + 14.0 \
					and target.global_position.y > global_position.y - height:
				target.take_damage(2)
			if live <= 0.0:
				queue_free()
		queue_redraw()

	func _draw() -> void:
		var c := Color(0.85, 0.6, 0.16, 0.25) if warn > 0.0 else Color(0.6, 1.0, 0.1, 0.7)
		draw_rect(Rect2(-width / 2.0, -height, width, height), c)

var max_health := 40
var health := 40
var phase := 1
var target: Node2D
var active := false
var flash := 0.0
var attack_cd := 2.5
var pending := ""
var pending_time := 0.0
var charge_time := 0.0
var charge_dir := 1
var hint_cd := 0.0
var hint_index := 0
var hints: Array = []
var floor_y := 600.0
var sprite: AnimatedSprite2D
var anim_lock := 0.0

func _ready() -> void:
	add_to_group("enemies")
	var shape := RectangleShape2D.new()
	shape.size = Vector2(56, 100)
	var cs := CollisionShape2D.new()
	cs.shape = shape
	add_child(cs)
	sprite = SpriteLib.make_sprite(SpriteLib.build("yeral", {
		"idle": [["idle_0", "idle_1"], 3.0, true],
		"run": [["run"], 1.0, true],
		"announce": [["announce"], 1.0, true],
		"point": [["point"], 1.0, true],
		"swing": [["swing"], 1.0, false],
		"cast": [["cast"], 1.0, false],
		"taunt": [["taunt"], 1.0, false],
		"summon": [["summon"], 1.0, false],
		"dash": [["dash"], 1.0, true],
	}), 50.0)
	add_child(sprite)
	sprite.play("idle")
	hints = YeralHints.all_hints()
	hints.shuffle()

func activate() -> void:
	active = true
	health_changed.emit(health, max_health)

func _physics_process(delta: float) -> void:
	flash = maxf(0.0, flash - delta)
	hint_cd = maxf(0.0, hint_cd - delta)
	if not is_on_floor():
		velocity.y += GRAVITY * delta
	if not active or not is_instance_valid(target):
		move_and_slide()
		_update_sprite(delta)
		return
	var mult := 1.0 + 0.4 * (phase - 1)
	if charge_time > 0.0:
		charge_time -= delta
		velocity.x = charge_dir * 480.0 * mult
		if is_on_wall():
			charge_time = 0.0
	else:
		velocity.x = move_toward(velocity.x, 0.0, 1200.0 * delta)
	if pending != "":
		pending_time -= delta
		if pending_time <= 0.0:
			var a := pending
			pending = ""
			_execute(a)
	else:
		attack_cd -= delta
		if attack_cd <= 0.0:
			_announce()
			attack_cd = 2.8 / mult
	move_and_slide()
	if target.has_method("take_damage") \
			and absf(target.global_position.x - global_position.x) < 45.0 \
			and absf(target.global_position.y - global_position.y) < 65.0:
		target.take_damage(2)
	_update_sprite(delta)

# Each attack has an announcement; it may be honest, fake, or swapped for another.
func _announce() -> void:
	var attacks := ["volley", "charge", "trap"]
	var real: String = attacks[randi() % attacks.size()]
	var lie_chance := 0.2 + 0.2 * (phase - 1)
	var roll := randf()
	var done := real
	if roll < lie_chance * 0.5:
		done = "nothing"
	elif roll < lie_chance:
		done = attacks[(attacks.find(real) + 1 + randi() % 2) % attacks.size()]
	var lines := {
		"volley": ["I'll throw three orbs at you!", "Orbs incoming. Duck. Or don't."],
		"charge": ["Next, I charge. Straight at you!", "Spoiler: I'm about to ram you."],
		"trap": ["The floor beneath you will explode!", "Spoiler: don't stand there."],
	}
	var l: Array = lines[real]
	speech.emit(l[randi() % l.size()], 2.0)
	pending = done
	pending_time = 1.0 if done != "nothing" else 1.2

func _execute(a: String) -> void:
	match a:
		"volley":
			_volley()
		"charge":
			charge_dir = 1 if target.global_position.x > global_position.x else -1
			charge_time = 0.7
		"trap":
			_trap()
		"nothing":
			_play_lock("taunt", 0.8)
			if randf() < 0.5:
				speech.emit("Hah! Nothing happened. Or did it?", 1.5)

func _volley() -> void:
	_play_lock("cast", 0.5)
	var count := 2 + phase
	for i in range(count):
		var p := Projectile.new()
		p.target_group = "player"
		p.color = Color(0.6, 1.0, 0.2)
		p.radius = 9.0
		p.texture = SpriteLib.texture("yeral_fx", "orb")
		p.position = global_position + Vector2(0, -20)
		var dir := (target.global_position - p.position).normalized()
		p.velocity = dir.rotated((i - (count - 1) / 2.0) * 0.3) * 300.0
		get_parent().add_child(p)

func _trap() -> void:
	_play_lock("summon", 0.6)
	var xs := [target.global_position.x]
	if phase >= 2:
		xs.append(target.global_position.x + 160.0 * (1 if randf() < 0.5 else -1))
	if phase >= 3:
		xs.append(target.global_position.x - 220.0)
	for x in xs:
		var z := TrapZone.new()
		z.target = target
		z.position = Vector2(x, floor_y)
		get_parent().add_child(z)

func take_damage(amount: int) -> void:
	if not active:
		return
	health = maxi(0, health - amount)
	flash = 0.1
	phase = 1 if health > max_health * 2 / 3 else (2 if health > max_health / 3 else 3)
	health_changed.emit(health, max_health)
	if health <= 0:
		active = false
		defeated.emit()
		queue_free()
		return
	if hint_cd <= 0.0 and not hints.is_empty():
		hint_cd = HINT_COOLDOWN
		speech.emit("Yeral: " + hints[hint_index % hints.size()], 3.5)
		hint_index += 1

func _play_lock(anim: String, time: float) -> void:
	anim_lock = time
	sprite.play(anim)

func _update_sprite(delta: float) -> void:
	anim_lock = maxf(0.0, anim_lock - delta)
	if is_instance_valid(target):
		sprite.flip_h = target.global_position.x < global_position.x
	sprite.modulate = Color(2.5, 2.5, 2.5) if flash > 0.0 else Color.WHITE
	if anim_lock > 0.0:
		return
	var want := "idle"
	if charge_time > 0.0:
		want = "dash"
	elif pending != "":
		want = "announce"
	elif absf(velocity.x) > 40.0:
		want = "run"
	if sprite.animation != want:
		sprite.play(want)
