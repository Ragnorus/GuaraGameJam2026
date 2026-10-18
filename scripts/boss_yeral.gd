class_name BossYeral
extends CharacterBody2D

signal defeated
signal transformed
signal health_changed(current: int, maximum: int)
signal speech(text: String, duration: float)

const GRAVITY := 1500.0
const HINT_COOLDOWN := 3.0
const ATTACK_TELL_TIME := 0.6
const YERAL_FRAMES := preload("res://assets/yeral_frames.tres")
const GLIZZY_FRAMES := preload("res://assets/glizzy_frames.tres")

# Spoiler Pillar: a gold "?" telegraph on the floor, then a column of toxic-lime spoiler energy
# with rising question marks, drawn in Yeral's palette (forest green, lime glow, gold trim).
class TrapZone extends Node2D:
	const DARK := Color8(8, 13, 10)
	const FOREST := Color8(41, 68, 42)
	const LIME := Color8(112, 237, 24)
	const BRIGHT := Color8(156, 255, 34)
	const GOLD := Color8(217, 154, 40)
	var width := 90.0
	var height := 400.0
	var warn := 1.0
	var live := 0.6
	var t := 0.0
	var target: Node2D

	func _process(delta: float) -> void:
		t += delta
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

	func _glyph(pos: Vector2, size: int, color: Color) -> void:
		var font := ThemeDB.fallback_font
		var w := font.get_string_size("?", HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
		draw_string_outline(font, pos - Vector2(w / 2.0, 0), "?", HORIZONTAL_ALIGNMENT_LEFT, -1, size, 6, DARK)
		draw_string(font, pos - Vector2(w / 2.0, 0), "?", HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)

	func _draw() -> void:
		var hw := width / 2.0
		if warn > 0.0:
			# Telegraph: pulsing gold rune ring on the floor, dashed guide rails and a big "?".
			var pulse := 0.5 + 0.5 * sin(t * 14.0)
			var ring := PackedVector2Array()
			for i in 25:
				var a := TAU * i / 24.0
				ring.append(Vector2(cos(a) * (hw + 8.0), sin(a) * 9.0 - 4.0))
			draw_colored_polygon(ring, Color(GOLD, 0.18 + 0.2 * pulse))
			draw_polyline(ring, Color(GOLD, 0.9), 2.5, true)
			var y := 0.0
			while y > -height * 0.8:
				var a2 := 0.55 * (1.0 + y / height) * (0.4 + 0.6 * pulse)
				draw_line(Vector2(-hw, y), Vector2(-hw, y - 14.0), Color(GOLD, a2), 2.0)
				draw_line(Vector2(hw, y), Vector2(hw, y - 14.0), Color(GOLD, a2), 2.0)
				y -= 26.0
			_glyph(Vector2(0, -24.0 - 6.0 * pulse), 44, Color(GOLD, 0.7 + 0.3 * pulse))
			return
		# Live pillar: layered glow, forest-green shell, lime body, bright core, faded top.
		var k := clampf(live / 0.6, 0.0, 1.0)
		var flicker := 1.0 + 0.08 * sin(t * 60.0)
		var layers := [[hw + 16.0, Color(BRIGHT, 0.18)], [hw, Color(FOREST, 0.9)],
				[hw * 0.72, Color(LIME, 0.85)], [hw * 0.38 * flicker, Color(BRIGHT, 0.95)],
				[hw * 0.12 * flicker, Color(0.95, 1.0, 0.85, 0.95)]]
		for l in layers:
			var lw: float = l[0]
			var c: Color = l[1]
			c.a *= k
			var top := Color(c, 0.0)
			draw_polygon(PackedVector2Array([Vector2(-lw, 0), Vector2(lw, 0), Vector2(lw, -height), Vector2(-lw, -height)]),
					PackedColorArray([c, c, top, top]))
		# Crackling arcs along the column.
		for side in [-1.0, 1.0]:
			var pts := PackedVector2Array()
			var yy := 0.0
			var i := 0
			while yy > -height * 0.9:
				pts.append(Vector2(side * hw * (0.45 + 0.35 * sin(t * 40.0 + i * 1.7 + side)), yy))
				yy -= 22.0
				i += 1
			draw_polyline(pts, Color(0.95, 1.0, 0.8, 0.8 * k), 1.5, true)
		# Rising question marks and a gold splash ring at the base.
		for q in 3:
			var qy := -fmod(t * 420.0 + q * height / 3.0, height * 0.85) - 20.0
			_glyph(Vector2((q - 1) * hw * 0.35, qy), 28 + 6 * q, Color(DARK, 0.75 * k))
		var splash := PackedVector2Array()
		for i2 in 25:
			var a3 := TAU * i2 / 24.0
			splash.append(Vector2(cos(a3) * (hw + 22.0 * (1.0 - k) + 6.0), sin(a3) * 10.0 - 3.0))
		draw_polyline(splash, Color(GOLD, k), 3.0, true)

# Ground-only sauce: the glowing strip is safe until the splash appears.
class SaucePuddle extends Node2D:
	var width := 180.0
	var warn := 0.85
	var live := 1.8
	var target: Node2D
	var splash: AnimatedSprite2D

	func _ready() -> void:
		splash = AnimatedSprite2D.new()
		splash.sprite_frames = GLIZZY_FRAMES
		splash.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		splash.centered = false
		splash.offset = Vector2(-160, -112)
		splash.scale = Vector2(0.6, 0.6)
		splash.visible = false
		add_child(splash)
		splash.play(&"puddle")

	func _process(delta: float) -> void:
		if warn > 0.0:
			warn -= delta
		else:
			splash.visible = true
			live -= delta
			if is_instance_valid(target) and target.has_method("take_damage") \
					and absf(target.global_position.x - global_position.x) < width / 2.0 + 14.0 \
					and target.global_position.y > global_position.y - 55.0 \
					and target.global_position.y < global_position.y + 30.0:
				target.take_damage(2)
			if live <= 0.0:
				queue_free()
		queue_redraw()

	func _draw() -> void:
		if warn > 0.0:
			draw_line(Vector2(-width / 2.0, -3), Vector2(width / 2.0, -3), Color(1, 0.8, 0.05), 5.0)

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
var arena_min := 2100.0
var arena_max := 2850.0
var sprite: AnimatedSprite2D
var pose_time := 0.0
var glizzy := false
var transforming := false
var dying := false
var mustard_next := false

func _ready() -> void:
	max_health = GameSettings.scale_health(max_health)
	health = max_health
	add_to_group("enemies")
	var shape := RectangleShape2D.new()
	shape.size = Vector2(126, 188)
	var cs := CollisionShape2D.new()
	cs.shape = shape
	add_child(cs)
	sprite = AnimatedSprite2D.new()
	sprite.sprite_frames = YERAL_FRAMES
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.scale = Vector2(0.5, 0.5)
	sprite.offset = Vector2(0, -224)
	sprite.position.y = 94.0
	add_child(sprite)
	sprite.animation_finished.connect(_on_animation_finished)
	sprite.play(&"idle")
	hints = YeralHints.all_hints()
	hints.shuffle()

func activate() -> void:
	active = true
	health_changed.emit(health, max_health)

func _process(delta: float) -> void:
	if transforming or dying:
		sprite.modulate = Color.WHITE
		return
	pose_time = maxf(0.0, pose_time - delta)
	var animation := sprite.animation
	var telling := pending != "" and pending_time <= ATTACK_TELL_TIME
	if charge_time > 0.0:
		sprite.flip_h = charge_dir < 0
		animation = &"charge"
	else:
		if is_instance_valid(target):
			sprite.flip_h = target.global_position.x < global_position.x
		if pending != "":
			animation = &"announce"
			if telling:
				match pending:
					"charge":
						animation = &"charge"
					"volley":
						animation = &"spray" if glizzy and mustard_next else &"volley"
					"trap":
						animation = &"trap"
		elif pose_time <= 0.0:
			animation = &"idle"
	if sprite.animation != animation:
		sprite.play(animation)
	if telling and pending != "nothing":
		sprite.pause()
		sprite.frame = 0
	sprite.modulate = Color(3, 3, 3) if flash > 0.0 else Color.WHITE

func _physics_process(delta: float) -> void:
	flash = maxf(0.0, flash - delta)
	hint_cd = maxf(0.0, hint_cd - delta)
	if dying:
		return
	if not is_on_floor():
		velocity.y += GRAVITY * delta
	if not active or transforming or not is_instance_valid(target):
		move_and_slide()
		return
	var mult := (1.0 + 0.4 * (phase - 1)) * GameSettings.aggro()
	if charge_time > 0.0:
		charge_time -= delta
		velocity.x = charge_dir * (520.0 if glizzy else 480.0) * mult
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
			attack_cd = (2.4 if glizzy else 2.8) / mult
	move_and_slide()
	if charge_time > 0.0 and is_on_wall():
		charge_time = 0.0
	if target.has_method("take_damage") \
			and absf(target.global_position.x - global_position.x) < 95.0 \
			and absf(target.global_position.y - global_position.y) < 130.0:
		target.take_damage(2)

# The boast can lie; the final held pose always previews the real attack.
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
	if glizzy:
		lines = {
			"volley": ["Extra mustard! Catch the spread!", "Ketchup with me, Controller King!"],
			"charge": ["Spoiler: this bun is about to run!", "Here comes the Glizzy Gobler!"],
			"trap": ["The floor gets extra sauce!", "Order up! Watch your feet!"],
		}
	var l: Array = lines[real]
	speech.emit(l[randi() % l.size()], 2.0)
	pending = done
	pending_time = 1.0 if done != "nothing" else 1.2

func _execute(a: String) -> void:
	if transforming or dying or not active or not is_instance_valid(target):
		return
	pose_time = 0.65 if glizzy else 0.55
	match a:
		"volley":
			sprite.play(&"spray" if glizzy and mustard_next else &"volley")
			_volley()
		"charge":
			charge_dir = 1 if target.global_position.x > global_position.x else -1
			charge_time = 0.85 if glizzy else 0.7
			sprite.play(&"charge")
		"trap":
			_trap()
			sprite.play(&"trap")
		"nothing":
			sprite.play(&"taunt")
			if randf() < 0.5:
				speech.emit("Hah! Nothing happened. Or did it?", 1.5)

func _volley() -> void:
	var count := (4 if glizzy else 2) + phase
	for i in range(count):
		var p := Projectile.new()
		p.target_group = "player"
		p.color = Color(0.2, 1.0, 0.05)
		p.radius = 9.0
		p.position = global_position + Vector2(0, -20)
		var dir := (target.global_position - p.position).normalized()
		p.velocity = dir.rotated((i - (count - 1) / 2.0) * (0.22 if glizzy else 0.3)) * (340.0 if glizzy else 300.0)
		p.sprite = AnimatedSprite2D.new()
		p.sprite.sprite_frames = GLIZZY_FRAMES if glizzy else YERAL_FRAMES
		p.sprite.scale = Vector2(0.8, 0.8) if glizzy else Vector2(0.4, 0.4)
		p.sprite.flip_h = p.velocity.x < 0.0
		p.add_child(p.sprite)
		p.sprite.play((&"mustard" if mustard_next else &"ketchup") if glizzy else &"projectile")
		p.add_to_group("yeral_attacks")
		get_parent().add_child(p)
	if glizzy:
		mustard_next = not mustard_next

func _trap() -> void:
	if glizzy:
		for i in range(1 + (1 if phase >= 2 else 0)):
			var puddle := SaucePuddle.new()
			puddle.target = target
			var x := target.global_position.x + i * 210.0 * (1 if target.global_position.x < global_position.x else -1)
			puddle.position = Vector2(clampf(x, arena_min, arena_max), floor_y)
			puddle.add_to_group("yeral_attacks")
			get_parent().add_child(puddle)
		return
	var xs := [target.global_position.x]
	if phase >= 2:
		xs.append(target.global_position.x + 160.0 * (1 if randf() < 0.5 else -1))
	if phase >= 3:
		xs.append(target.global_position.x - 220.0)
	for x in xs:
		var z := TrapZone.new()
		z.target = target
		z.position = Vector2(x, floor_y)
		z.add_to_group("yeral_attacks")
		get_parent().add_child(z)

func take_damage(amount: int) -> bool:
	if not active or transforming or dying:
		return false
	health = maxi(0, health - amount)
	flash = 0.1
	phase = 1 if health > max_health * 2.0 / 3.0 else (2 if health > max_health / 3.0 else 3)
	health_changed.emit(health, max_health)
	if health <= 0:
		if not glizzy:
			_transform()
		else:
			_die()
		return true
	if glizzy and pending.is_empty() and charge_time <= 0.0:
		pose_time = 0.2
		sprite.stop()
		sprite.play(&"hurt")
	if hint_cd <= 0.0 and not hints.is_empty():
		hint_cd = HINT_COOLDOWN
		speech.emit(("Glizzy Gobler: " if glizzy else "Yeral: ") + hints[hint_index % hints.size()], 3.5)
		hint_index += 1
	return true

func _clear_attacks() -> void:
	for attack in get_tree().get_nodes_in_group("yeral_attacks"):
		attack.process_mode = Node.PROCESS_MODE_DISABLED
		attack.queue_free()

func _transform() -> void:
	glizzy = true
	transforming = true
	pending = ""
	pending_time = 0.0
	charge_time = 0.0
	pose_time = 0.0
	velocity = Vector2.ZERO
	flash = 0.0
	remove_from_group("enemies")
	_clear_attacks()
	max_health = GameSettings.scale_health(48)
	health = max_health
	phase = 1
	hints = YeralHints.HINTS["glizzy"].duplicate()
	hint_index = 0
	hint_cd = HINT_COOLDOWN
	sprite.sprite_frames = GLIZZY_FRAMES
	sprite.centered = false
	sprite.scale = Vector2(0.8, 0.8)
	sprite.offset = Vector2(-256, -352)
	sprite.play(&"transform")
	transformed.emit()
	health_changed.emit(health, max_health)
	speech.emit("Yeral: Final spoiler... I AM THE GLIZZY GOBLER!", 3.0)

func _die() -> void:
	dying = true
	active = false
	pending = ""
	charge_time = 0.0
	velocity = Vector2.ZERO
	collision_layer = 0
	collision_mask = 0
	remove_from_group("enemies")
	_clear_attacks()
	sprite.play(&"death")
	speech.emit("Glizzy Gobler: ...hold the mustard.", 2.0)

func _on_animation_finished() -> void:
	if transforming and sprite.animation == &"transform":
		transforming = false
		add_to_group("enemies")
		attack_cd = 1.2
		sprite.play(&"idle")
	elif dying and sprite.animation == &"death":
		defeated.emit()
		queue_free()
