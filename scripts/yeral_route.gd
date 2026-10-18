class_name YeralRoute
extends Node2D

const AREAS: Array[Rect2] = [
	Rect2(0, 0, 1280, 720), Rect2(1280, 720, 1280, 720),
	Rect2(2560, 720, 1600, 720), Rect2(4160, 720, 1280, 720),
	Rect2(5440, 0, 1600, 720), Rect2(7040, 0, 1280, 720)]
const TITLES := ["AREA 1 - CITY APPROACH", "AREA 2 - SEWER DESCENT",
	"AREA 3 - SERGEANT ROOM", "AREA 4 - SEWER ASCENT", "AREA 5 - CITY WAREHOUSE", "YERAL'S WAREHOUSE"]
const SERGEANT_PLATFORMS: Array[Rect2] = [
	Rect2(2760, 1200, 240, 20), Rect2(3120, 1080, 240, 20), Rect2(3480, 1200, 240, 20)]
const INTRO_TEXT := "I AM YERAL THE SPOILERMAN! Muwahahahahahaha!!!"
const INTRO_AUDIO := preload("res://assets/audio/yeral_intro.wav")

var stage: Node2D
var area_index := 0
var transitioning := false
var intro_complete := false
var backgrounds: Array[Node2D] = []
var room_enemies: Array[Array] = []
var moving_blocks: Array[MovingPlatform] = []
var sergeant: Robot
var boss: BossYeral
var voice: AudioStreamPlayer
var curtain: ColorRect
var speech: PanelContainer
var speech_label: Label
var hint_cooldown := 0.0
var acid_time := 0.0
var cinematic: Tween

func _exit_tree() -> void:
	if is_instance_valid(voice):
		voice.stop()
		voice.stream = null

func build(parent_stage: Node2D) -> void:
	stage = parent_stage
	stage.arena_right = AREAS[5].end.x
	stage.boss_gate_x = AREAS[5].position.x
	stage.boss_trigger_x = AREAS[4].end.x - 100.0
	stage.boss_spawn_x = AREAS[5].end.x - 280.0
	_build_backdrops()
	_build_geometry()
	stage.player = Player.new()
	stage.player.collision_mask |= stage.PLATFORM_LAYER
	stage.player.position = Vector2(100, 540)
	stage.add_child(stage.player)
	stage.player.died.connect(stage._on_player_died)
	stage.player.stats_changed.connect(stage._update_hud)
	stage.camera = Camera2D.new()
	stage.player.add_child(stage.camera)
	for i in range(6):
		room_enemies.append([])
	_spawn_robot(0, Vector2(600, 562))
	_spawn_robot(0, Vector2(1000, 562))
	_spawn_flyer(0, 850.0)
	_spawn_robot(1, Vector2(1610, 1062))
	_spawn_robot(1, Vector2(2260, 1282))
	sergeant = _spawn_robot(2, Vector2(3240, 1042))
	sergeant.health = GameSettings.scale_health(12)
	sergeant.points = 5
	sergeant.scale = Vector2(1.25, 1.25)
	sergeant.position.y = 1035.0
	sergeant.collision_mask |= stage.PLATFORM_LAYER
	sergeant.zone_min = 3150.0
	sergeant.zone_max = 3330.0
	_spawn_robot(4, Vector2(5860, 562))
	_spawn_robot(4, Vector2(6500, 562))
	_spawn_flyer(4, 6220.0)
	for at in [Vector2(400, 550), Vector2(1810, 1150), Vector2(2880, 1160), Vector2(3600, 1160), Vector2(4830, 1040), Vector2(6100, 550)]:
		stage._spawn_pickup(Pickup.Kind.COIN, at)
	for at in [Vector2(2420, 1270), Vector2(6870, 550)]:
		stage._spawn_pickup(Pickup.Kind.MEDALLA, at)
	_build_overlay()
	_set_area(0)

func _build_backdrops() -> void:
	for i in range(AREAS.size()):
		var root := Node2D.new()
		root.position = AREAS[i].position
		root.z_index = -20
		add_child(root)
		backgrounds.append(root)
		if i in [0, 4]:
			var sky := Sprite2D.new()
			sky.texture = load("res://assets/sprites/city_bg/city_bg_sky.png")
			sky.centered = false
			sky.scale = AREAS[i].size / sky.texture.get_size()
			root.add_child(sky)
			for x in [0.0, 1276.25]:
				var city := Sprite2D.new()
				city.texture = load("res://assets/sprites/city_bg/city_bg_panorama.png")
				city.centered = false
				city.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
				city.scale = Vector2(1.25, 1.25)
				city.position = Vector2(x, 624.0 - city.texture.get_height() * 1.25)
				root.add_child(city)
			var gradient := Gradient.new()
			gradient.set_color(0, Color8(4, 17, 10))
			gradient.set_color(1, Color8(4, 17, 10, 0))
			var feather := GradientTexture2D.new()
			feather.gradient = gradient
			feather.fill_from = Vector2.ZERO
			feather.fill_to = Vector2(0, 1)
			var skyline_edge := Sprite2D.new()
			skyline_edge.texture = feather
			skyline_edge.centered = false
			skyline_edge.scale = Vector2(AREAS[i].size.x, 90.0) / feather.get_size()
			skyline_edge.position.y = 624.0 - 322.0 * 1.25 - 1.0
			root.add_child(skyline_edge)
		else:
			for x in range(0, int(AREAS[i].size.x), 1280):
				var painting := Sprite2D.new()
				painting.texture = load("res://assets/backgrounds/yeral/%s.png" % ("warehouse" if i == 5 else "sewer"))
				painting.centered = false
				painting.position.x = x
				root.add_child(painting)
		var caption := Label.new()
		caption.text = TITLES[i]
		caption.position = Vector2(60, 105)
		caption.add_theme_font_size_override("font_size", 24)
		caption.add_theme_color_override("font_color", Color8(255, 224, 145))
		caption.add_theme_color_override("font_outline_color", Color.BLACK)
		caption.add_theme_constant_override("outline_size", 6)
		root.add_child(caption)

func _block(rect: Rect2, platform := false) -> void:
	stage._add_block(rect, "platform" if platform else "floor")

func _sign(at: Vector2, text: String) -> void:
	var label := Label.new()
	label.position = at
	label.text = text
	label.add_theme_font_size_override("font_size", 22)
	label.add_theme_color_override("font_color", Color8(255, 224, 145))
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 6)
	add_child(label)

func _build_geometry() -> void:
	_block(Rect2(0, 600, 1280, 120))
	for rect in [Rect2(350, 480, 160, 20), Rect2(750, 430, 180, 20)]:
		_block(rect, true)
	# The descent has solid steps; the sergeant room deliberately has no floor over its acid.
	_block(Rect2(1280, 1100, 450, 340))
	_block(Rect2(1730, 1210, 340, 230))
	_block(Rect2(2070, 1320, 490, 120))
	_block(Rect2(2560, 1320, 190, 120))
	for rect in SERGEANT_PLATFORMS:
		_block(rect, true)
	_block(Rect2(3880, 1200, 280, 240))
	_block(Rect2(4160, 1320, 240, 120))
	_block(Rect2(4710, 1080, 230, 20), true)
	_block(Rect2(5180, 850, 260, 20), true)
	_moving(Rect2(4380, 1200, 170, 20), Vector2(190, 0), 4.0)
	_moving(Rect2(4960, 1150, 170, 20), Vector2(0, -220), 5.0)
	_block(Rect2(5440, 600, 1600, 120))
	_block(Rect2(7040, 600, 1280, 120))
	_block(Rect2(5900, 450, 180, 20), true)
	_block(Rect2(6380, 480, 180, 20), true)
	for rect in [Rect2(-40, -200, 40, 920), Rect2(1280, 720, 20, 380),
			Rect2(AREAS[5].end.x, -200, 40, 920)]:
		stage._add_block(rect, "wall", true)
	_sign(Vector2(980, 480), "SEWER ACCESS\nDOWN >")
	_sign(Vector2(2660, 960), "SERGEANT AHEAD\nFIXED PLATFORMS / LETHAL ACID")
	_sign(Vector2(4220, 925), "RIDE THE MOVING BLOCKS\nTO THE UPPER EXIT >")
	_sign(Vector2(5190, 930), "CITY EXIT\nUP >")
	_sign(Vector2(6540, 365), "WAREHOUSE\nENTER >")
	# A new warehouse exterior uses the generated warehouse painting, not city scenery.
	var door := Sprite2D.new()
	door.texture = load("res://assets/backgrounds/yeral/warehouse_entrance.png")
	door.centered = false
	door.position = Vector2(6780, 240)
	add_child(door)

func _moving(rect: Rect2, travel: Vector2, period: float) -> void:
	var body := MovingPlatform.new()
	body.start = rect.get_center()
	body.position = body.start
	body.travel = travel
	body.period = period
	body.collision_layer = stage.PLATFORM_LAYER
	var collider := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = rect.size
	collider.shape = shape
	collider.one_way_collision = true
	body.add_child(collider)
	stage._add_platform_sprite(body, rect)
	stage._add_platform_edge(body, rect.size)
	stage.add_child(body)
	moving_blocks.append(body)

func _spawn_robot(room: int, at: Vector2) -> Robot:
	var enemy := Robot.new()
	enemy.position = at
	enemy.target = stage.player
	enemy.zone_min = AREAS[room].position.x
	enemy.zone_max = AREAS[room].end.x
	enemy.points = room + 1
	stage.add_child(enemy)
	room_enemies[room].append(enemy)
	return enemy

func _spawn_flyer(room: int, x: float) -> void:
	var enemy := WingedMob.new()
	enemy.position = Vector2(x, 600.0 - WingedMob.HOVER_HEIGHT)
	enemy.target = stage.player
	enemy.zone_min = AREAS[room].position.x
	enemy.zone_max = AREAS[room].end.x
	enemy.points = room + 1
	stage.add_child(enemy)
	room_enemies[room].append(enemy)

func _build_overlay() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 12
	add_child(layer)
	speech = PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(1.0, 0.97, 0.83)
	style.border_color = Color8(8, 13, 10)
	style.set_border_width_all(5)
	style.set_corner_radius_all(18)
	style.content_margin_left = 22
	style.content_margin_right = 22
	style.content_margin_top = 14
	style.content_margin_bottom = 14
	speech.add_theme_stylebox_override("panel", style)
	speech.position = Vector2(530, 160)
	speech.size = Vector2(600, 140)
	speech_label = Label.new()
	speech_label.text = INTRO_TEXT
	speech_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	speech_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	speech_label.add_theme_font_size_override("font_size", 28)
	speech_label.add_theme_color_override("font_color", Color8(8, 13, 10))
	speech.add_child(speech_label)
	# A comic speech tail points at Yeral rather than reading as a stage caption.
	var tail := Polygon2D.new()
	tail.polygon = PackedVector2Array([Vector2(370, 132), Vector2(430, 132), Vector2(460, 210)])
	tail.color = style.border_color
	speech.add_child(tail)
	var inner := Polygon2D.new()
	inner.polygon = PackedVector2Array([Vector2(380, 130), Vector2(423, 130), Vector2(451, 194)])
	inner.color = style.bg_color
	speech.add_child(inner)
	layer.add_child(speech)
	speech.hide()
	curtain = ColorRect.new()
	curtain.color = Color(0, 0, 0, 0)
	curtain.mouse_filter = Control.MOUSE_FILTER_IGNORE
	curtain.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.add_child(curtain)
	voice = AudioStreamPlayer.new()
	voice.stream = INTRO_AUDIO
	voice.bus = "SFX"
	voice.playback_type = AudioServer.PLAYBACK_TYPE_STREAM
	add_child(voice)

func _set_area(index: int) -> void:
	area_index = index
	var rect := AREAS[index]
	for i in range(backgrounds.size()):
		backgrounds[i].visible = i == index
		for enemy in room_enemies[i]:
			if is_instance_valid(enemy) and not enemy.dead:
				enemy.process_mode = Node.PROCESS_MODE_INHERIT if i == index else Node.PROCESS_MODE_DISABLED
				enemy.visible = i == index
	stage.cam_left = rect.position.x
	stage.cam_right = rect.end.x
	stage.camera.limit_left = int(rect.position.x)
	stage.camera.limit_right = int(rect.end.x)
	stage.camera.limit_top = int(rect.position.y)
	stage.camera.limit_bottom = int(rect.end.y)
	stage.camera.reset_smoothing()
	stage.camera.force_update_scroll()
	queue_redraw()

func _room_clear() -> bool:
	for enemy in room_enemies[area_index]:
		if is_instance_valid(enemy) and not enemy.dead:
			return false
	return true

func update(delta: float) -> void:
	if stage.player.dead:
		return
	acid_time += delta
	queue_redraw()
	if transitioning:
		return
	hint_cooldown = maxf(0.0, hint_cooldown - delta)
	var player: Player = stage.player
	var rect := AREAS[area_index]
	# Keep the player inside the active room; transitions are the only room crossings.
	player.position.x = clampf(player.position.x, rect.position.x + 24.0, rect.end.x - 24.0)
	if area_index in [2, 3] and player.position.y + 36.0 >= 1380.0:
		player.die()
		return
	if player.position.y > rect.end.y + 100.0:
		player.die()
		return
	if area_index == 5:
		return
	var at_exit := player.position.x > rect.end.x - 95.0
	if area_index == 4:
		at_exit = player.position.x > rect.end.x - 160.0
	if area_index == 3:
		at_exit = at_exit and player.position.y + 36.0 <= 865.0
	if at_exit:
		if not _room_clear():
			if hint_cooldown <= 0.0:
				stage._say("Defeat the sergeant before leaving!" if area_index == 2 else "Defeat the guards to open the route!", 2.0)
				hint_cooldown = 3.0
			return
		_transition(area_index + 1)

func _transition(next: int) -> void:
	transitioning = true
	stage.player.controls_locked = true
	stage.player.clear_attacks()
	stage.player.dash_time = 0.0
	stage.player.action_time = 0.0
	stage.player.player_sprite.show()
	stage.player.player_sprite.play(&"run" if next == 5 else &"jump")
	cinematic = create_tween()
	var exit: Vector2 = stage.player.position + Vector2(55, -95 if next in [1, 4] else 0)
	cinematic.tween_property(stage.player, "position", exit, 0.55)
	cinematic.parallel().tween_property(curtain, "color:a", 1.0, 0.55)
	if next == 5:
		cinematic.parallel().tween_property(stage.player, "modulate:a", 0.0, 0.55)
	cinematic.tween_callback(func() -> void:
		_set_area(next)
		var floor_y := 1100.0 if next == 1 else (1320.0 if next in [2, 3] else 600.0)
		stage.player.position = Vector2(AREAS[next].position.x + 90.0, floor_y - 36.0)
		stage.player.velocity = Vector2.ZERO
		stage.player.modulate.a = 1.0
		stage.camera.reset_smoothing()
		stage.camera.force_update_scroll()
		stage.message.text = TITLES[next]
		stage.message_timer.start(2.0)
	)
	cinematic.tween_property(curtain, "color:a", 0.0, 0.55)
	cinematic.tween_callback(func() -> void:
		if next == 5:
			start_boss_intro()
		else:
			stage.player.controls_locked = false
			transitioning = false
	)

func start_boss_intro() -> void:
	if stage.player.dead or is_instance_valid(boss):
		return
	stage.boss_started = true
	transitioning = true
	stage.player.controls_locked = true
	stage.player.clear_attacks()
	stage.player.player_sprite.show()
	stage.player.player_sprite.play(&"idle")
	boss = BossYeral.new()
	boss.position = Vector2(stage.boss_spawn_x, 504)
	boss.target = stage.player
	boss.floor_y = 600.0
	boss.arena_min = AREAS[5].position.x + 80.0
	boss.arena_max = AREAS[5].end.x - 70.0
	stage.add_child(boss)
	boss.remove_from_group("enemies")
	boss.health_changed.connect(stage._on_boss_health)
	boss.defeated.connect(stage._on_boss_defeated)
	boss.transformed.connect(stage._on_yeral_transformed)
	boss.speech.connect(stage._say)
	boss.sprite.play(&"announce")
	boss.pose_time = INTRO_AUDIO.get_length() + 1.0
	speech.show()
	speech.scale = Vector2(0.85, 0.85)
	create_tween().tween_property(speech, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK)
	GameAudio.apply()
	voice.play()
	# Muting SFX must not change cinematic timing or let gameplay start during the line.
	cinematic = create_tween()
	cinematic.tween_interval(maxf(3.0, INTRO_AUDIO.get_length()) + 0.3)
	cinematic.tween_callback(func() -> void:
		speech.hide()
		voice.stop()
		if stage.player.dead:
			return
		boss.add_to_group("enemies")
		boss.activate()
		stage.player.controls_locked = false
		intro_complete = true
		transitioning = false
	)

func cancel_intro() -> void:
	if cinematic != null and cinematic.is_valid():
		cinematic.kill()
	voice.stop()
	speech.hide()
	curtain.color.a = 0.0
	stage.player.modulate.a = 1.0

func _draw() -> void:
	if area_index not in [2, 3]:
		return
	var left := AREAS[area_index].position.x
	var width := AREAS[area_index].size.x
	draw_rect(Rect2(left, 1380, width, 60), Color8(28, 76, 12))
	var surface := PackedVector2Array()
	for i in range(int(width / 12) + 1):
		surface.append(Vector2(left + i * 12, 1380 + sin(acid_time * 3.0 + i * 0.6) * 4.0))
	draw_polyline(surface, Color8(156, 255, 34), 5.0, true)
	for i in range(24):
		var x := left + fmod(i * 71.0 + acid_time * 12.0, width)
		var y := 1398 + sin(acid_time * 2.0 + i) * 12.0
		draw_circle(Vector2(x, y), 3.0 + i % 3, Color8(112, 237, 24))
