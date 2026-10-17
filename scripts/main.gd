extends Node2D

const LEVEL_END := 2400.0
const FLOOR_Y := 600.0

@export var ema_level := false

var player: Player
var dialogue: Label
var dialogue_time := 0.0
var hud_label: Label
var boss_label: Label
var message: Label
var boss_started := false
var finished := false

func _ready() -> void:
	InputSetup.setup()
	_build_world()
	_build_hud()
	if ema_level:
		message.text = "THE INFESTED ZONE"
		await get_tree().create_timer(2.0).timeout
		if not boss_started:
			message.text = ""

func _add_block(rect: Rect2) -> void:
	var body := StaticBody2D.new()
	body.position = rect.position + rect.size / 2.0
	var shape := RectangleShape2D.new()
	shape.size = rect.size
	var cs := CollisionShape2D.new()
	cs.shape = shape
	body.add_child(cs)
	var vis := ColorRect.new()
	vis.size = rect.size
	vis.position = -rect.size / 2.0
	vis.color = Color(0.12, 0.2, 0.1) if ema_level else Color(0.15, 0.2, 0.3)
	body.add_child(vis)
	add_child(body)

func _build_world() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.025, 0.09, 0.055) if ema_level else Color(0.05, 0.03, 0.1)
	bg.position = Vector2(-1000, -600)
	bg.size = Vector2(LEVEL_END + 2000, 1800)
	bg.z_index = -10
	add_child(bg)
	_add_block(Rect2(-100, FLOOR_Y, LEVEL_END + 600, 100))
	_add_block(Rect2(-140, -200, 40, 900))
	_add_block(Rect2(LEVEL_END + 500, -200, 40, 900))
	var platforms: Array = [
		Rect2(350, 480, 140, 20), Rect2(600, 400, 140, 20),
		Rect2(850, 480, 140, 20), Rect2(1100, 380, 160, 20),
		Rect2(1400, 470, 140, 20),
	]
	if ema_level:
		platforms = [
			Rect2(300, 490, 170, 20), Rect2(560, 405, 150, 20),
			Rect2(790, 495, 170, 20), Rect2(1030, 385, 170, 20),
			Rect2(1300, 475, 160, 20), Rect2(1580, 385, 170, 20),
			Rect2(1820, 475, 170, 20),
		]
	for r in platforms:
		_add_block(r)
	player = Player.new()
	player.position = Vector2(100, FLOOR_Y - 40)
	add_child(player)
	player.died.connect(_on_player_died)
	player.stats_changed.connect(_update_hud)
	var cam := Camera2D.new()
	cam.limit_left = -100
	cam.limit_right = int(LEVEL_END + 500)
	cam.limit_bottom = int(FLOOR_Y + 100)
	player.add_child(cam)
	var bug_positions := [500.0, 800.0, 1000.0, 1250.0, 1550.0, 1800.0]
	if ema_level:
		bug_positions = [420.0, 660.0, 900.0, 1120.0, 1350.0, 1590.0, 1810.0, 1980.0]
	for x in bug_positions:
		var b := Bug.new()
		b.position = Vector2(x, FLOOR_Y - 20)
		b.target = player
		add_child(b)
	_update_hud()

func _build_hud() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	hud_label = Label.new()
	hud_label.position = Vector2(16, 12)
	layer.add_child(hud_label)
	boss_label = Label.new()
	boss_label.position = Vector2(440, 12)
	layer.add_child(boss_label)
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
	help.text = "Move A/D  Jump Space  Smash J  Summon K  Recall L  Ultimate U  Restart R"
	help.position = Vector2(16, 690)
	layer.add_child(help)

func _update_hud() -> void:
	if not is_instance_valid(player) or not is_instance_valid(hud_label):
		return
	hud_label.text = "HP %d/%d   Army meter %d%%" % [player.health, player.max_health,
			int(player.meter / player.meter_max * 100.0)]

func _process(delta: float) -> void:
	if dialogue_time > 0.0:
		dialogue_time -= delta
		if dialogue_time <= 0.0:
			dialogue.text = ""
	if Input.is_action_just_pressed("restart"):
		get_tree().reload_current_scene()
	if not boss_started and is_instance_valid(player) and player.position.x > LEVEL_END - 300.0:
		_start_boss()

func _start_boss() -> void:
	boss_started = true
	_add_block(Rect2(LEVEL_END - 340, -200, 30, FLOOR_Y + 200))
	if ema_level:
		var ema := BossEma.new()
		ema.position = Vector2(LEVEL_END + 250, FLOOR_Y - 45)
		ema.target = player
		add_child(ema)
		ema.health_changed.connect(_on_boss_health)
		ema.defeated.connect(_on_boss_defeated)
		ema.activate()
		message.text = "EMA, THE BUG QUEEN"
	else:
		var yeral := BossYeral.new()
		yeral.position = Vector2(LEVEL_END + 250, FLOOR_Y - 45)
		yeral.target = player
		yeral.floor_y = FLOOR_Y
		add_child(yeral)
		yeral.health_changed.connect(_on_boss_health)
		yeral.defeated.connect(_on_boss_defeated)
		yeral.speech.connect(_say)
		yeral.activate()
		message.text = "YERAL, THE SPOILERMAN"
	await get_tree().create_timer(2.0).timeout
	if not finished and is_instance_valid(player) and not player.dead:
		message.text = ""

func _on_boss_health(current: int, maximum: int) -> void:
	boss_label.text = "%s  %d/%d" % ["EMA" if ema_level else "YERAL", current, maximum]

func _say(text: String, duration: float) -> void:
	dialogue.text = text
	dialogue_time = duration

func _on_boss_defeated() -> void:
	finished = true
	boss_label.text = ""
	dialogue.text = ""
	for e in get_tree().get_nodes_in_group("enemies"):
		e.queue_free()
	if ema_level:
		message.text = "Ema defeated! The Infested Zone is clear."
		return
	message.text = "Yeral defeated! Reward: Future Spoiler"
	player.max_minions += 2
	await get_tree().create_timer(3.0).timeout
	message.text = "A mysterious signal reveals the other Guaras..."
	await get_tree().create_timer(3.0).timeout
	for c in get_children():
		if c is CanvasLayer:
			c.queue_free()
	var black := ColorRect.new()
	black.color = Color.BLACK
	black.size = Vector2(5000, 3000)
	black.position = player.global_position - Vector2(2500, 1500)
	black.z_index = 100
	add_child(black)
	var end := Label.new()
	end.text = "The Guara War Has Just Begun"
	end.add_theme_font_size_override("font_size", 40)
	end.position = player.global_position - Vector2(270, 20)
	end.z_index = 101
	add_child(end)

func _on_player_died() -> void:
	message.text = "You died. Press R to restart"
