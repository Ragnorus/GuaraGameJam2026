extends Node2D

const LEVEL_END := 2400.0
const FLOOR_Y := 600.0

@export var bichema_level := false

var player: Player
var dialogue: Label
var dialogue_time := 0.0
var hud_label: Label
var boss_label: Label
var message: Label
var message_timer: Timer
var boss_started := false
var glizzy_form := false
var finished := false
var gates: Array = []
var hp_bar: ProgressBar
var meter_bar: ProgressBar
var boss_bar: ProgressBar
var score_label: Label

func _ready() -> void:
	InputSetup.setup()
	GameSettings.begin_level()
	if GameSettings.loaded:
		GameAudio.start_music(get_tree())
	add_child(PauseMenu.new())
	message_timer = Timer.new()
	message_timer.one_shot = true
	message_timer.process_mode = Node.PROCESS_MODE_ALWAYS
	message_timer.timeout.connect(_on_message_timeout)
	add_child(message_timer)
	_build_world()
	_build_hud()
	_update_hud()
	if bichema_level:
		message.text = "BICHEMA'S WORLD"
		message_timer.start(2.0)

# Bichema's World uses the red set in assets/bichema; Yeral's level keeps the green set in assets.
func _asset(file: String) -> String:
	return ("res://assets/bichema/%s" if bichema_level else "res://assets/%s") % file

func _tiled(path: String, pos: Vector2, size: Vector2, px_scale := 1.0) -> TextureRect:
	var tr := TextureRect.new()
	tr.texture = load(path)
	tr.stretch_mode = TextureRect.STRETCH_TILE
	tr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	tr.scale = Vector2(px_scale, px_scale)
	tr.size = size / px_scale
	tr.position = pos
	return tr

# kind: "floor", "platform" or "wall"
func _add_block(rect: Rect2, kind := "wall") -> void:
	var body := StaticBody2D.new()
	body.position = rect.position + rect.size / 2.0
	var shape := RectangleShape2D.new()
	shape.size = rect.size
	var cs := CollisionShape2D.new()
	cs.shape = shape
	body.add_child(cs)
	var origin := -rect.size / 2.0
	match kind:
		"floor":
			body.add_child(_tiled(_asset("tile_floor_mesh.png"), origin, rect.size))
			body.add_child(_tiled(_asset("tile_floor_top.png"), origin, Vector2(rect.size.x, 32), 2.0))
		"platform":
			if bichema_level:
				body.add_child(_tiled(_asset("tile_platform.png"), origin, rect.size))
			else:
				_add_platform_sprite(body, rect)
		_:
			body.add_child(_tiled(_asset("tile_wall.png"), origin, rect.size))
	add_child(body)

func _add_prop(path: String, pos: Vector2, px_scale := 2.0, z := -1) -> void:
	var s := Sprite2D.new()
	s.texture = load(path)
	s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	s.scale = Vector2(px_scale, px_scale)
	s.centered = false
	s.position = pos - Vector2(s.texture.get_width(), s.texture.get_height()) * px_scale * Vector2(0.5, 1.0)
	s.z_index = z
	add_child(s)

# Yeral's night city: the painted skyline from art/sheets/spoiler_gotham_sheet.png, cropped unaltered by
# tools/slice_gotham.js and drawn top-aligned at 2x with nearest filtering (1021x322 -> 2042x644; the floor at
# y=600 covers the rest). A flipped copy sits beside it so the loop is seamless; a plain sky strip is the backstop.
func _build_city_background(pb: ParallaxBackground) -> void:
	var sky: Texture2D = load("res://assets/sprites/city_bg/city_bg_sky.png")
	var sky_layer := ParallaxLayer.new()
	sky_layer.motion_scale = Vector2.ZERO
	var sky_spr := Sprite2D.new()
	sky_spr.texture = sky
	sky_spr.centered = false
	sky_spr.scale = Vector2(1280.0 / sky.get_width(), 720.0 / sky.get_height())
	sky_layer.add_child(sky_spr)
	pb.add_child(sky_layer)

	var tex: Texture2D = load("res://assets/sprites/city_bg/city_bg_panorama.png")
	const PX := 2
	var w := tex.get_width() * PX
	var pl := ParallaxLayer.new()
	pl.motion_scale = Vector2(0.25, 0.0)
	pl.motion_mirroring = Vector2(w * 2, 0)
	for i in 2:
		var spr := Sprite2D.new()
		spr.texture = tex
		spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		spr.centered = false
		spr.flip_h = i == 1
		spr.scale = Vector2(PX, PX)
		spr.position = Vector2(w * i, 0.0)
		pl.add_child(spr)
	pb.add_child(pl)

func _build_background() -> void:
	var pb := ParallaxBackground.new()
	add_child(pb)
	if not bichema_level:
		_build_city_background(pb)
		return
	var layers := [[_asset("bg_far.png"), 0.08], [_asset("bg_mid.png"), 0.25],
			[_asset("bg_near.png"), 0.5]]
	for l in layers:
		var pl := ParallaxLayer.new()
		pl.motion_scale = Vector2(l[1], 0.0)
		pl.motion_mirroring = Vector2(1024, 0)
		var spr := Sprite2D.new()
		spr.texture = load(l[0])
		spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		spr.centered = false
		spr.scale = Vector2(2, 2)
		pl.add_child(spr)
		pb.add_child(pl)

func _build_props() -> void:
	if not bichema_level:
		_build_yeral_props()
		return
	_add_prop(_asset("prop_door.png"), Vector2(60, FLOOR_Y), 2.0)
	_add_prop(_asset("prop_sign_billboard.png"), Vector2(420, 330), 3.0, -2)
	_add_prop(_asset("prop_sign_vertical.png"), Vector2(980, 380), 3.0, -2)
	_add_prop(_asset("prop_neon_lamp.png"), Vector2(1700, 420), 3.0, -2)
	_add_prop(_asset("prop_sign_billboard.png"), Vector2(LEVEL_END + 250, 300), 4.0, -2)
	_add_prop(_asset("prop_neon_lamp.png"), Vector2(LEVEL_END - 80, 400), 3.0, -2)
	for x in [250.0, 700.0, 1180.0, 1480.0, 1900.0, 2150.0]:
		_add_prop(_asset("prop_bollard.png"), Vector2(x, FLOOR_Y), 2.0)
	for x in [560.0, 1320.0, 2000.0]:
		_add_prop(_asset("prop_crate.png"), Vector2(x, FLOOR_Y), 2.0)
	# Red hologram panels cut from the Evil Genius sheet, hanging behind the action.
	var holos := ["chart", "capitol", "sports", "chip", "debate", "globe", "graph", "sports2", "bars", "chip2"]
	for i in range(holos.size()):
		var hy := 250.0 + 50.0 * (i % 3)
		_add_prop("res://assets/sprites/bichema/bichema_holo_%s.png" % holos[i], Vector2(200.0 + 230.0 * i, hy), 1.8, -2)
	_add_prop("res://assets/sprites/bichema/bichema_holo_debate.png", Vector2(LEVEL_END + 100, 330), 3.0, -2)
	_add_prop("res://assets/sprites/bichema/bichema_holo_globe.png", Vector2(LEVEL_END + 420, 330), 3.0, -2)

func _lair(name: String) -> String:
	return "res://assets/sprites/lair/lair_%s.png" % name

# Yeral's lair dressing (sprites sliced from art/sheets/level_sheet.png).
func _build_yeral_props() -> void:
	_add_prop("res://assets/prop_door.png", Vector2(60, FLOOR_Y), 2.0)
	for x in [300.0, 760.0, 1250.0, 1700.0, 2150.0]:
		_add_prop(_lair("banner_a"), Vector2(x, 250), 1.0, -2)
	for x in [520.0, 1020.0, 1500.0, 1950.0]:
		_add_prop(_lair("lamp_b"), Vector2(x, 160), 1.0, -2)
	_add_prop(_lair("desk_banner"), Vector2(620, FLOOR_Y), 1.0)
	_add_prop(_lair("plant"), Vector2(250, FLOOR_Y), 1.0)
	_add_prop(_lair("crate_crown"), Vector2(1320, FLOOR_Y), 1.0)
	_add_prop(_lair("crate_dark"), Vector2(1360, FLOOR_Y), 1.0)
	_add_prop(_lair("terminal"), Vector2(1800, FLOOR_Y), 1.0)
	_add_prop(_lair("vat"), Vector2(2100, FLOOR_Y), 1.0)
	_add_prop(_lair("pillar_glow"), Vector2(LEVEL_END - 80, FLOOR_Y), 1.0, -2)
	_add_prop(_lair("crown_screen"), Vector2(LEVEL_END + 250, 300), 1.5, -2)
	_add_prop(_lair("command_desk"), Vector2(LEVEL_END + 120, FLOOR_Y), 1.0, -1)
	_add_prop(_lair("crown_hologram"), Vector2(LEVEL_END + 400, FLOOR_Y), 1.0, -1)

func _add_platform_sprite(body: Node2D, rect: Rect2) -> void:
	var s := Sprite2D.new()
	s.texture = load(_lair("platform_long"))
	s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	s.centered = false
	var k := rect.size.x / s.texture.get_width()
	s.scale = Vector2(k, k)
	s.position = Vector2(-rect.size.x / 2.0, -rect.size.y / 2.0)
	body.add_child(s)

func _build_world() -> void:
	_build_background()
	_build_props()
	if bichema_level:
		var tint := CanvasModulate.new()
		tint.color = Color(1.0, 0.88, 0.88)
		add_child(tint)
	_add_block(Rect2(-100, FLOOR_Y, LEVEL_END + 600, 100), "floor")
	_add_block(Rect2(-140, -200, 40, 900))
	_add_block(Rect2(LEVEL_END + 500, -200, 40, 900))
	var platforms: Array = [
		Rect2(350, 480, 140, 20), Rect2(600, 400, 140, 20),
		Rect2(850, 480, 140, 20), Rect2(1100, 380, 160, 20),
		Rect2(1400, 470, 140, 20),
	]
	if bichema_level:
		platforms = [
			Rect2(300, 490, 170, 20), Rect2(560, 405, 150, 20),
			Rect2(790, 495, 170, 20), Rect2(1030, 385, 170, 20),
			Rect2(1300, 475, 160, 20), Rect2(1580, 385, 170, 20),
			Rect2(1820, 475, 170, 20),
		]
	for r in platforms:
		_add_block(r, "platform")
	player = Player.new()
	player.position = Vector2(100, FLOOR_Y - 60)
	add_child(player)
	player.died.connect(_on_player_died)
	player.stats_changed.connect(_update_hud)
	var cam := Camera2D.new()
	cam.limit_left = -100
	cam.limit_right = int(LEVEL_END + 500)
	cam.limit_bottom = int(FLOOR_Y + 100)
	player.add_child(cam)
	var bug_positions := [500.0, 800.0, 1000.0, 1250.0, 1550.0, 1800.0]
	var gate_xs := [900.0, 1400.0, 2000.0]
	if bichema_level:
		bug_positions = [420.0, 660.0, 900.0, 1120.0, 1350.0, 1590.0, 1810.0, 1980.0]
		gate_xs = [800.0, 1250.0, 1700.0, 2100.0]
	for gx in gate_xs:
		gates.append({"x": gx, "wall": _add_gate(gx), "bugs": []})
	for x in bug_positions:
		var b: Bug = TruffleAndroid.new() if bichema_level else Robot.new()
		b.position = Vector2(x, FLOOR_Y - (40 if bichema_level else 38))
		b.target = player
		b.points = clampi(1 + int(5.0 * x / LEVEL_END), GameSettings.MOB_POINTS_MIN, GameSettings.MOB_POINTS_MAX)
		add_child(b)
		for g in gates:
			if x < g["x"]:
				g["bugs"].append(b)
				break
	_update_hud()

# Energy barrier that blocks the player until its zone's mobs are dead.
func _add_gate(x: float) -> StaticBody2D:
	var body := StaticBody2D.new()
	body.position = Vector2(x, FLOOR_Y - 300)
	var shape := RectangleShape2D.new()
	shape.size = Vector2(16, 600)
	var cs := CollisionShape2D.new()
	cs.shape = shape
	body.add_child(cs)
	var vis := ColorRect.new()
	vis.size = Vector2(16, 600)
	vis.position = Vector2(-8, -300)
	vis.color = Color(1.0, 0.2, 0.15, 0.35) if bichema_level else Color(0.4, 1.0, 0.1, 0.35)
	body.add_child(vis)
	add_child(body)
	return body

func _update_gates() -> void:
	for g in gates.duplicate():
		var alive := false
		for b in g["bugs"]:
			if is_instance_valid(b) and not b.dead:
				alive = true
				break
		if not alive:
			g["wall"].queue_free()
			gates.erase(g)
			_say("Path cleared!", 1.5)

func _make_bar(pos: Vector2, size: Vector2, fill: Color) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.position = pos
	bar.custom_minimum_size = size
	bar.size = size
	bar.show_percentage = false
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.05, 0.08, 0.06, 0.85)
	bg.set_border_width_all(2)
	bg.border_color = Color(0.85, 0.6, 0.15)
	var fg := StyleBoxFlat.new()
	fg.bg_color = fill
	bar.add_theme_stylebox_override("background", bg)
	bar.add_theme_stylebox_override("fill", fg)
	return bar

func _build_hud() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	hud_label = Label.new()
	hud_label.position = Vector2(16, 12)
	layer.add_child(hud_label)
	hp_bar = _make_bar(Vector2(16, 14), Vector2(260, 22), Color(0.4, 0.95, 0.15))
	layer.add_child(hp_bar)
	meter_bar = _make_bar(Vector2(16, 40), Vector2(260, 12), Color(0.85, 0.6, 0.15))
	layer.add_child(meter_bar)
	boss_label = Label.new()
	boss_label.position = Vector2(440, 8)
	boss_label.size = Vector2(400, 24)
	boss_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	layer.add_child(boss_label)
	boss_bar = _make_bar(Vector2(440, 34), Vector2(400, 20), Color(0.8, 0.15, 0.2))
	boss_bar.visible = false
	layer.add_child(boss_bar)
	message = Label.new()
	message.position = Vector2(300, 300)
	message.add_theme_font_size_override("font_size", 36)
	layer.add_child(message)
	dialogue = Label.new()
	dialogue.position = Vector2(100, 630)
	dialogue.size = Vector2(1080, 50)
	dialogue.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	dialogue.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	dialogue.add_theme_font_size_override("font_size", 22)
	layer.add_child(dialogue)
	var help := Label.new()
	help.text = "Move A/D  Jump Space  Smash J  Summon K  Recall L  Ultimate U  Restart R  Pause Esc"
	help.position = Vector2(16, 690)
	layer.add_child(help)
	score_label = Label.new()
	score_label.position = Vector2(880, 12)
	score_label.size = Vector2(384, 50)
	score_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	score_label.add_theme_font_size_override("font_size", 18)
	layer.add_child(score_label)

func _update_hud() -> void:
	if not is_instance_valid(player) or not is_instance_valid(hud_label):
		return
	hp_bar.max_value = player.max_health
	hp_bar.value = player.health
	meter_bar.max_value = player.meter_max
	meter_bar.value = player.meter
	hud_label.text = "HP %d/%d" % [player.health, player.max_health]
	hud_label.position = Vector2(24, 12)
	hud_label.add_theme_font_size_override("font_size", 14)

func _process(delta: float) -> void:
	score_label.text = "SCORE %d   HI %d\n%s" % [GameSettings.score, GameSettings.high_score(), GameSettings.current()["name"]]
	if dialogue_time > 0.0:
		dialogue_time -= delta
		if dialogue_time <= 0.0:
			dialogue.text = ""
	if Input.is_action_just_pressed("restart"):
		var error := get_tree().reload_current_scene()
		if error != OK:
			push_error("Could not restart level: %s" % error_string(error))
		return
	_update_gates()
	if not finished and not boss_started and is_instance_valid(player) and not player.dead and player.position.x > LEVEL_END - 300.0:
		_start_boss()

func _start_boss() -> void:
	boss_started = true
	_add_block(Rect2(LEVEL_END - 340, -200, 30, FLOOR_Y + 200))
	if bichema_level:
		var genius := BossEvilGenius.new()
		genius.position = Vector2(LEVEL_END + 250, FLOOR_Y - 112)
		genius.target = player
		add_child(genius)
		genius.health_changed.connect(_on_boss_health)
		genius.defeated.connect(_on_boss_defeated)
		genius.speech.connect(_say)
		genius.activate()
		message.text = "THE EVIL GENIUS"
	else:
		var yeral := BossYeral.new()
		yeral.position = Vector2(LEVEL_END + 250, FLOOR_Y - 96)
		yeral.target = player
		yeral.floor_y = FLOOR_Y
		add_child(yeral)
		yeral.health_changed.connect(_on_boss_health)
		yeral.defeated.connect(_on_boss_defeated)
		yeral.transformed.connect(_on_yeral_transformed)
		yeral.speech.connect(_say)
		yeral.activate()
		message.text = "YERAL, THE SPOILERMAN"
	message_timer.start(2.0)

func _on_yeral_transformed() -> void:
	glizzy_form = true
	boss_label.text = "GLIZZY GOBLER"
	message.text = "YERAL'S TRUE FORM\nGLIZZY GOBLER"
	message_timer.start(3.0)

func _on_boss_health(current: int, maximum: int) -> void:
	boss_label.text = "EVIL GENIUS" if bichema_level else ("GLIZZY GOBLER" if glizzy_form else "YERAL")
	boss_bar.visible = true
	boss_bar.max_value = maximum
	boss_bar.value = current

func _say(text: String, duration: float) -> void:
	dialogue.text = text
	dialogue_time = duration

func _on_boss_defeated() -> void:
	if finished or player.dead:
		return
	finished = true
	process_mode = Node.PROCESS_MODE_DISABLED
	boss_label.text = ""
	boss_bar.visible = false
	for e in get_tree().get_nodes_in_group("enemies"):
		e.queue_free()
	GameSettings.add_score(GameSettings.BOSS_POINTS)
	var new_high := GameSettings.commit_score()
	GameSettings.complete_level()
	GameAudio.play(get_tree(), "boss")
	var score_text := "\nBoss +%d  |  Score: %d%s" % [GameSettings.BOSS_POINTS, GameSettings.score,
			"  NEW HIGH SCORE!" if new_high else ""]
	if bichema_level:
		message.text = "The Evil Genius is defeated! All levels clear." + score_text + "\nReturning to level selection..."
	else:
		message.text = "Yeral and Glizzy Gobler defeated!" + score_text + "\nNext: Bichema's World"
	message_timer.start(3.0)

func _on_message_timeout() -> void:
	if not finished:
		if not player.dead:
			message.text = ""
		return
	var next_scene := "res://scenes/level_select.tscn" if bichema_level else "res://scenes/bichema_level.tscn"
	var error := get_tree().change_scene_to_file(next_scene)
	if error != OK:
		process_mode = Node.PROCESS_MODE_INHERIT
		message.text = "Could not load the next level.\nPress R to restart."
		push_error("Could not open level %s: %s" % [next_scene, error_string(error)])

func _on_player_died() -> void:
	if finished:
		return
	message_timer.stop()
	var new_high := GameSettings.commit_score()
	message.text = "You died. Score: %d%s\nPress R to restart" % [GameSettings.score, "  NEW HIGH SCORE!" if new_high else ""]
