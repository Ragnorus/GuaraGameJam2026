class_name BossEvilGenius
extends CharacterBody2D

signal defeated
signal transformed
signal health_changed(current: int, maximum: int)
signal speech(text: String, duration: float)

const GRAVITY := 1500.0
const SCALE := 1.5
const FRAMES := preload("res://assets/neon_lawyer_frames.tres")
const COSTUME_FRAMES := preload("res://assets/ema_costume_frames.tres")
const PINK_SUIT_TRANSFORM_AUDIO := preload("res://assets/audio/evil_genius_pink_suit.wav")
const BODY := Vector2(84, 196)
const FEET_Y := 110.0
const BODY_OFFSET := Vector2(0, FEET_Y - BODY.y / 2.0)
const PLAYER_HALF := Vector2(21, 36)
const CONTACT_SLOP := 1.0
const CHARGE_WINDUP := 0.8
const BLAST_WINDUP := 0.55
const SUMMON_WINDUP := 0.6
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
var pending_attack: StringName = &""
var attack_windup := 0.0
var charge_dir := 1
var pose_time := 0.0
var pose := &""
var active := false
var dying := false
var costume_form := false
var transforming := false
var flash := 0.0
var sprite: AnimatedSprite2D
var transform_voice: AudioStreamPlayer

func _ready() -> void:
	max_health = GameSettings.scale_health(max_health)
	health = max_health
	add_to_group("enemies")
	var shape := CapsuleShape2D.new()
	shape.radius = BODY.x / 2.0
	shape.height = BODY.y
	var cs := CollisionShape2D.new()
	cs.shape = shape
	cs.position = BODY_OFFSET
	add_child(cs)
	sprite = AnimatedSprite2D.new()
	sprite.sprite_frames = FRAMES
	sprite.scale = Vector2(SCALE, SCALE)
	sprite.centered = false
	sprite.offset = Vector2(-256, -240)
	sprite.position.y = FEET_Y
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(sprite)
	sprite.animation_finished.connect(_on_animation_finished)
	sprite.play(&"idle")

func activate() -> void:
	active = true
	health_changed.emit(health, max_health)

func _say(lines: Array) -> void:
	speech.emit(lines[randi() % lines.size()], 2.0)

func _physics_process(delta: float) -> void:
	if dying:
		return
	flash = maxf(0.0, flash - delta)
	pose_time = maxf(0.0, pose_time - delta)
	if not is_on_floor():
		velocity.y += GRAVITY * delta
	if not active or transforming or not is_instance_valid(target):
		velocity.x = move_toward(velocity.x, 0.0, 1200.0 * delta)
		move_and_slide()
		_update_art()
		return
	var mult := (1.0 + 0.5 * (phase - 1)) * GameSettings.aggro() * (1.1 if costume_form else 1.0)
	if charge_windup > 0.0:
		charge_windup -= delta
		velocity.x = 0.0
		if charge_windup <= 0.0:
			charge_time = 0.8
	elif attack_windup > 0.0:
		velocity.x = 0.0
		attack_windup -= delta
		if attack_windup <= 0.0:
			var attack := pending_attack
			pending_attack = &""
			if attack == &"blast":
				_blast()
			else:
				_summon()
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
	_touch_damage()
	_update_art()

func _touch_damage() -> void:
	if not target.has_method("take_damage"):
		return
	# Match the capsule, allowing only the physics solver's small separation at body contact.
	var distance := (target.global_position - (global_position + BODY_OFFSET)).abs()
	var corner := Vector2(maxf(0.0, distance.x - PLAYER_HALF.x),
			maxf(0.0, distance.y - PLAYER_HALF.y - (BODY.y - BODY.x) / 2.0))
	var radius := BODY.x / 2.0 + CONTACT_SLOP
	if corner.length_squared() < radius * radius:
		target.take_damage(2)

func _update_art() -> void:
	var next := &"idle"
	if dying:
		next = &"dead"
	elif transforming:
		next = &"transform"
	elif charge_windup > 0.0:
		next = &"shield"
	elif attack_windup > 0.0:
		next = pending_attack
	elif pose_time > 0.0 and pose == &"hurt":
		next = &"hurt"
	elif charge_time > 0.0:
		next = &"run"
	elif pose_time > 0.0:
		next = pose
	elif not is_on_floor():
		next = &"jump"
	if not dying and not transforming:
		if charge_time > 0.0 or charge_windup > 0.0:
			sprite.flip_h = charge_dir < 0
		elif is_instance_valid(target):
			sprite.flip_h = target.global_position.x < global_position.x
	if sprite.animation != next:
		sprite.play(next)
	sprite.modulate = Color(1.0, 0.45, 0.45) if flash > 0.0 and not transforming else Color.WHITE
	queue_redraw()

func _draw() -> void:
	if not active or dying or transforming:
		return
	var gold := Color8(255, 224, 145)
	var dark := Color8(8, 13, 18)
	if charge_windup > 0.0:
		var progress := 1.0 - charge_windup / CHARGE_WINDUP
		var start := Vector2(charge_dir * 56.0, FEET_Y - 6.0)
		var tip := start + Vector2(charge_dir * (90.0 + progress * 35.0), 0)
		gold.a = 0.65 + 0.35 * absf(sin(progress * PI * 3.0))
		for width in [9.0, 4.0]:
			var color := dark if width == 9.0 else gold
			draw_line(start, tip, color, width, true)
			draw_line(tip, tip + Vector2(-charge_dir * 22.0, -16), color, width, true)
			draw_line(tip, tip + Vector2(-charge_dir * 22.0, 16), color, width, true)
	elif attack_windup > 0.0:
		var side := -1.0 if sprite.flip_h else 1.0
		var center := Vector2(side * 65.0, -30)
		var duration := BLAST_WINDUP if pending_attack == &"blast" else SUMMON_WINDUP
		var radius := 12.0 + 16.0 * (1.0 - attack_windup / duration)
		draw_arc(center, radius, 0, TAU, 24, dark, 8.0, true)
		draw_arc(center, radius, 0, TAU, 24, gold, 3.0, true)

func _pick_attack() -> void:
	if not active or transforming or dying or not is_instance_valid(target):
		return
	var r := randi() % 3
	velocity.x = 0.0
	if r == 0:
		pending_attack = &"blast"
		attack_windup = BLAST_WINDUP
		_say(LINES_BLAST)
	elif r == 1:
		pending_attack = &"point"
		attack_windup = SUMMON_WINDUP
		_say(LINES_SUMMON)
	else:
		charge_dir = 1 if target.global_position.x > global_position.x else -1
		charge_windup = CHARGE_WINDUP
		_say(LINES_CHARGE)

func _blast() -> void:
	if not active or transforming or dying or not is_instance_valid(target):
		return
	pose = &"blast"
	pose_time = 0.5
	var count := 1 + phase
	var dir := 1.0 if target.global_position.x > global_position.x else -1.0
	for i in range(count):
		var p := Projectile.new()
		p.target_group = "player"
		p.radius = 12.0
		p.position = global_position + Vector2(dir * 70.0, -40.0)
		var aim := (target.global_position - p.position).normalized()
		p.velocity = aim.rotated((i - (count - 1) / 2.0) * 0.25) * 340.0
		if costume_form:
			p.texture = COSTUME_FRAMES.get_frame_texture(&"pink_bolt", 0)
		else:
			p.texture = TruffleAndroid.FRAMES.get_frame_texture(&"money_bolt", 0)
			p.texture_scale = Vector2(0.35, 0.35)
			p.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			p.coin_pop = true
			p.texture_outline_color = Projectile.GOLD_OUTLINE_COLOR
		p.add_to_group("evil_genius_attacks")
		get_parent().add_child(p)

func _summon() -> void:
	if not active or transforming or dying:
		return
	pose = &"point"
	pose_time = 0.6
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
		b.add_to_group("evil_genius_attacks")
		get_parent().add_child(b)

func take_damage(amount: int) -> bool:
	if not active or transforming or dying:
		return false
	GameAudio.play(get_tree(), "squeak")
	var old_phase := phase
	health = maxi(0, health - amount)
	flash = 0.1
	phase = 1 if health > max_health * 2.0 / 3.0 else (2 if health > max_health / 3.0 else 3)
	health_changed.emit(health, max_health)
	if health <= 0:
		if costume_form:
			_die()
		else:
			_transform()
	elif phase != old_phase:
		pose = &"hurt"
		pose_time = 0.5
		attack_cd = maxf(attack_cd, 1.0)
	return true

func _clear_attacks() -> void:
	pending_attack = &""
	attack_windup = 0.0
	for attack in get_tree().get_nodes_in_group("evil_genius_attacks"):
		attack.process_mode = Node.PROCESS_MODE_DISABLED
		attack.remove_from_group("enemies")
		if attack is TruffleAndroid:
			attack.dying = true
			attack.dead = true
			attack.collision_layer = 0
			attack.collision_mask = 0
		attack.queue_free()

func _transform() -> void:
	costume_form = true
	transforming = true
	charge_time = 0.0
	charge_windup = 0.0
	pose_time = 0.0
	velocity = Vector2.ZERO
	flash = 0.0
	remove_from_group("enemies")
	_clear_attacks()
	max_health = GameSettings.scale_health(72)
	health = max_health
	phase = 1
	sprite.sprite_frames = COSTUME_FRAMES
	sprite.play(&"transform")
	transform_voice = AudioStreamPlayer.new()
	transform_voice.stream = PINK_SUIT_TRANSFORM_AUDIO
	transform_voice.bus = "SFX"
	transform_voice.playback_type = AudioServer.PLAYBACK_TYPE_STREAM
	add_child(transform_voice)
	if target is Player:
		(target as Player).died.connect(transform_voice.stop)
	transform_voice.play()
	transformed.emit()
	health_changed.emit(health, max_health)
	speech.emit("Behold my final argument!", 2.0)

# His only weakness: a girl boss lawyer objects, and the Evil Genius collapses.
func _die() -> void:
	if dying or transforming or not costume_form:
		return
	dying = true
	active = false
	if is_instance_valid(transform_voice):
		transform_voice.stop()
	charge_time = 0.0
	charge_windup = 0.0
	remove_from_group("enemies")
	pose_time = 0.0
	_clear_attacks()
	collision_layer = 0
	collision_mask = 0
	velocity = Vector2.ZERO
	speech.emit("Objection! ...Sustained?!", 2.0)
	var lawyer := Sprite2D.new()
	lawyer.texture = SpriteLib.texture("evil_genius_fx", "lawyer")
	lawyer.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	lawyer.scale = Vector2(0.5, 0.5)
	var side := -1.0 if sprite.flip_h else 1.0
	lawyer.position = Vector2(side * 170.0, FEET_Y - lawyer.texture.get_height() * 0.25)
	lawyer.flip_h = side < 0.0
	lawyer.modulate.a = 0.0
	add_child(lawyer)
	create_tween().tween_property(lawyer, "modulate:a", 1.0, 0.3)
	_update_art()

func _on_animation_finished() -> void:
	if transforming and sprite.animation == &"transform":
		transforming = false
		add_to_group("enemies")
		attack_cd = 1.2
		sprite.play(&"idle")
	elif dying and sprite.animation == &"dead":
		set_physics_process(false)
		defeated.emit()
		queue_free()

func _exit_tree() -> void:
	if is_instance_valid(transform_voice):
		transform_voice.stop()
		transform_voice.stream = null
