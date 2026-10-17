extends Node2D

const LEVEL_END := 2400.0
const LEVEL_LEFT := -100.0
const FLOOR_Y := 600.0
const PLATFORM_LAYER := 4
const VIEW_WIDTH := 1280.0
const CAMERA_LIMIT_SPEED := 900.0
const BICHEMA_GROUND := [628.0, 688.0, 533.0]
const BICHEMA_PLATFORMS := [
	[Rect2(260, 500, 150, 16), Rect2(1300, 430, 150, 16), Rect2(1680, 500, 160, 16)],
	[Rect2(122, 379, 429, 16), Rect2(648, 429, 282, 16), Rect2(321, 559, 295, 16),
		Rect2(1016, 559, 239, 16), Rect2(1356, 412, 429, 16)],
	[Rect2(0, 378, 374, 16), Rect2(377, 433, 370, 16)],
]

@export var bichema_level := false

var player: Player
var dialogue: Label
var dialogue_time := 0.0
var hud_label: Label
var boss_label: Label
var message: ComicBox
var message_timer: Timer
var boss_started := false
var glizzy_form := false
var costume_form := false
var bichema_background: Sprite2D
var bichema_rooms: Array[Dictionary] = []
var bichema_background_index := -1
var boss_gate_x := LEVEL_END - 340.0
var boss_trigger_x := LEVEL_END - 300.0
var boss_spawn_x := LEVEL_END + 600.0
var finished := false
var gates: Array = []
var hp_bar: ProgressBar
var meter_bar: ProgressBar
var boss_bar: ProgressBar
var score_label: Label
var gate_hint_cd := 0.0
# Right edge of the boss arena; Yeral's lair is wider so the fight has room to move.
var arena_right := LEVEL_END + 500.0
var camera: Camera2D
# Camera limits ease towards these so the view never shows past the next uncleared gate.
var cam_left := LEVEL_LEFT
var cam_right := LEVEL_END

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

func _tiled(path: String, pos: Vector2, size: Vector2, px_scale := 1.0) -> TextureRect:
	var tr := TextureRect.new()
	tr.texture = load(path)
	tr.stretch_mode = TextureRect.STRETCH_TILE
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	tr.scale = Vector2(px_scale, px_scale)
	tr.size = size / px_scale
	tr.position = pos
	return tr

# kind: "floor", "platform" or "wall"
func _add_block(rect: Rect2, kind := "wall", painted := false) -> void:
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
			if not painted:
				body.add_child(_tiled("res://assets/tile_floor_mesh.png", origin, rect.size))
				body.add_child(_tiled("res://assets/tile_floor_top.png", origin, Vector2(rect.size.x, 32), 2.0))
		"platform":
			# Own physics layer: only the player stands on platforms (bosses and mobs pass behind them),
			# and they are one-way so the player can jump up through them.
			body.collision_layer = PLATFORM_LAYER
			cs.one_way_collision = true
			if not painted:
				_add_platform_sprite(body, rect)
		_:
			if not painted:
				body.add_child(_tiled("res://assets/tile_wall.png", origin, rect.size))
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
# tools/slice_gotham.js and drawn zoomed out at 1.25x with smooth filtering, bottom-aligned to the floor
# (1021x322 -> 1276x402; the sky strip fills above). A flipped copy sits beside it so the loop is seamless.
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
	# Zoomed out (1.25x, smoothed) so the skyline sits far back; its bottom edge tucks under the floor.
	const PX := 1.25
	var w := tex.get_width() * PX
	var top := FLOOR_Y + 24.0 - tex.get_height() * PX
	var pl := ParallaxLayer.new()
	pl.motion_scale = Vector2(0.25, 0.0)
	pl.motion_mirroring = Vector2(w * 2, 0)
	for i in 2:
		var spr := Sprite2D.new()
		spr.texture = tex
		spr.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		spr.centered = false
		spr.flip_h = i == 1
		spr.scale = Vector2(PX, PX)
		spr.position = Vector2(w * i, top)
		pl.add_child(spr)
	# Feather the skyline's top edge into the sky colour so there is no hard seam.
	var fade := Gradient.new()
	fade.set_color(0, Color8(4, 17, 10, 255))
	fade.set_color(1, Color8(4, 17, 10, 0))
	var fade_tex := GradientTexture2D.new()
	fade_tex.gradient = fade
	fade_tex.fill_from = Vector2(0, 0)
	fade_tex.fill_to = Vector2(0, 1)
	fade_tex.width = 8
	fade_tex.height = 64
	var fade_rect := TextureRect.new()
	fade_rect.texture = fade_tex
	fade_rect.stretch_mode = TextureRect.STRETCH_SCALE
	fade_rect.position = Vector2(0, top - 1.0)
	fade_rect.size = Vector2(w * 2, 90.0)
	pl.add_child(fade_rect)
	pb.add_child(pl)

# Complete paintings are world-sized rooms; the camera never sees beyond the active image.
func _build_bichema_background() -> void:
	var start := 0.0
	var titles := ["GOLDEN TREASURY PLAZA", "LUCKY IRISH ROCK BAR", "NEON CROWN CASH FACTORY"]
	for panel in ["plaza", "pub", "factory"]:
		var index := bichema_rooms.size()
		var tex: Texture2D = load("res://assets/backgrounds/bichema/%s.png" % panel)
		# Two pixels of vertical bleed keep fractional floor alignment inside the painting.
		var k := 722.0 / tex.get_height()
		var rect := Rect2(start, FLOOR_Y - BICHEMA_GROUND[index] * k, floorf(tex.get_width() * k), 722)
		var platforms: Array[Rect2] = []
		for pixels: Rect2 in BICHEMA_PLATFORMS[index]:
			platforms.append(Rect2(rect.position + pixels.position * k, pixels.size * k))
		bichema_rooms.append({"name": titles[index], "texture": tex, "rect": rect,
			"scale": k, "ground": BICHEMA_GROUND[index], "platforms": platforms})
		start = rect.end.x
	arena_right = start
	boss_gate_x = arena_right - VIEW_WIDTH
	boss_trigger_x = boss_gate_x + 120.0
	boss_spawn_x = arena_right - 260.0
	bichema_background = Sprite2D.new()
	bichema_background.centered = false
	bichema_background.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	bichema_background.z_index = -10
	add_child(bichema_background)

func _update_bichema_background() -> void:
	if not is_instance_valid(camera) or not is_instance_valid(player):
		return
	var index := 0
	for i in range(1, bichema_rooms.size()):
		if player.position.x >= (bichema_rooms[i]["rect"] as Rect2).position.x:
			index = i
	if index == bichema_background_index:
		return
	bichema_background_index = index
	var room: Dictionary = bichema_rooms[index]
	var rect: Rect2 = room["rect"]
	bichema_background.texture = room["texture"]
	bichema_background.position = rect.position
	bichema_background.scale = Vector2.ONE * float(room["scale"])
	cam_left = maxf(rect.position.x, boss_gate_x) if boss_started else rect.position.x
	cam_right = _camera_right_target()
	camera.limit_left = int(cam_left)
	camera.limit_right = int(cam_right)
	camera.limit_top = ceili(rect.position.y)
	camera.limit_bottom = camera.limit_top + 720
	camera.reset_smoothing()
	camera.force_update_scroll()
	if is_instance_valid(message) and not finished and not player.dead:
		message.text = room["name"]
		message_timer.start(1.8)

func _build_background() -> void:
	if bichema_level:
		_build_bichema_background()
		return
	var pb := ParallaxBackground.new()
	add_child(pb)
	_build_city_background(pb)

func _build_props() -> void:
	if not bichema_level:
		_build_yeral_props()

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
	_add_prop(_lair("crown_screen"), Vector2(LEVEL_END + 500, 300), 1.5, -2)
	_add_prop(_lair("command_desk"), Vector2(LEVEL_END + 300, FLOOR_Y), 1.0, -1)
	_add_prop(_lair("crown_hologram"), Vector2(LEVEL_END + 760, FLOOR_Y), 1.0, -1)
	_add_prop(_lair("pillar_glow"), Vector2(LEVEL_END + 940, FLOOR_Y), 1.0, -2)
	for x in [LEVEL_END + 150.0, LEVEL_END + 850.0]:
		_add_prop(_lair("banner_a"), Vector2(x, 250), 1.0, -2)
	_add_prop(_lair("lamp_b"), Vector2(LEVEL_END + 620, 160), 1.0, -2)

func _add_platform_sprite(body: Node2D, rect: Rect2) -> void:
	var s := Sprite2D.new()
	if bichema_level:
		var name := "platform_long" if rect.size.x >= 150.0 else "platform_short"
		s.texture = load("res://assets/sprites/capital/%s.png" % name)
	else:
		s.texture = load(_lair("platform_long"))
	s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	s.centered = false
	var k := rect.size.x / s.texture.get_width()
	s.scale = Vector2(k, k)
	s.position = Vector2(-rect.size.x / 2.0, -rect.size.y / 2.0)
	body.add_child(s)

func _build_world() -> void:
	if not bichema_level:
		arena_right = LEVEL_END + 1000.0
	_build_background()
	_build_props()
	var world_left := 0.0 if bichema_level else LEVEL_LEFT
	_add_block(Rect2(world_left, FLOOR_Y, arena_right - world_left, 100), "floor", bichema_level)
	_add_block(Rect2(world_left - 40, -800, 40, 1500), "wall", bichema_level)
	_add_block(Rect2(arena_right, -800, 40, 1500), "wall", bichema_level)
	var platforms: Array = [
		Rect2(350, 480, 140, 20), Rect2(600, 400, 140, 20),
		Rect2(850, 480, 140, 20), Rect2(1100, 380, 160, 20),
		Rect2(1400, 470, 140, 20),
	]
	if bichema_level:
		platforms = []
		for i in range(bichema_rooms.size()):
			for rect: Rect2 in bichema_rooms[i]["platforms"]:
				_add_block(rect, "platform", i != 0)
		# Complete the plaza's short water crossing with visible stone, not invisible floor.
		var plaza_scale: float = bichema_rooms[0]["scale"]
		var bridge_x := 1950.0 * plaza_scale
		_add_block(Rect2(bridge_x, FLOOR_Y, (bichema_rooms[0]["rect"] as Rect2).end.x - bridge_x, 20), "platform")
	var bug_positions := [500.0, 800.0, 1000.0, 1250.0, 1550.0, 1800.0]
	var flyer_positions := [700.0, 1350.0, 1900.0]
	var gate_xs := [900.0, 1400.0, 2000.0]
	if bichema_level:
		var pub_x: float = (bichema_rooms[1]["rect"] as Rect2).position.x
		var factory_x: float = (bichema_rooms[2]["rect"] as Rect2).position.x
		bug_positions = [420.0, 900.0, 1500.0, 1900.0, pub_x + 350.0, pub_x + 950.0,
			pub_x + 1500.0, factory_x + 250.0, factory_x + 520.0, factory_x + 770.0]
		flyer_positions = [700.0, 1650.0, pub_x + 650.0, pub_x + 1300.0, factory_x + 600.0]
		gate_xs = [1100.0, pub_x - 32.0, pub_x + 900.0, factory_x - 32.0, boss_gate_x]
	else:
		platforms.append_array(_random_platforms(platforms, gate_xs))
		for rect: Rect2 in platforms:
			_add_block(rect, "platform")
	player = Player.new()
	player.collision_mask |= PLATFORM_LAYER
	player.position = Vector2(100, FLOOR_Y - 60)
	add_child(player)
	player.died.connect(_on_player_died)
	player.stats_changed.connect(_update_hud)
	camera = Camera2D.new()
	camera.limit_left = int(world_left)
	camera.limit_bottom = int(FLOOR_Y + 100)
	player.add_child(camera)
	for gx in gate_xs:
		gates.append({"x": gx, "wall": _add_gate(gx), "bugs": []})
	cam_left = world_left
	if bichema_level:
		_update_bichema_background()
	cam_right = _camera_right_target()
	camera.limit_right = int(cam_right)
	var mobs: Array = []
	for x in bug_positions:
		var b: Bug = TruffleAndroid.new() if bichema_level else Robot.new()
		b.position = Vector2(x, FLOOR_Y - (40 if bichema_level else 38))
		mobs.append(b)
	for x in flyer_positions:
		var w := WingedMob.new()
		w.bichema = bichema_level
		w.position = Vector2(x, FLOOR_Y - WingedMob.HOVER_HEIGHT)
		mobs.append(w)
	for b in mobs:
		b.target = player
		b.points = clampi(1 + int(5.0 * b.position.x / (arena_right if bichema_level else LEVEL_END)), GameSettings.MOB_POINTS_MIN, GameSettings.MOB_POINTS_MAX)
		b.zone_min = world_left
		b.zone_max = boss_gate_x
		for gx in gate_xs:
			if b.position.x < gx:
				b.zone_max = gx
				break
			b.zone_min = gx
		add_child(b)
		for g in gates:
			if b.position.x < g["x"]:
				g["bugs"].append(b)
				break
	_update_hud()

# Extra platforms at random spots each run (gaps between the fixed ones, plus a few in the boss arena).
# Heights stay within a double jump of the floor or a neighbouring platform.
func _random_platforms(fixed: Array, gate_xs: Array) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var placed: Array = []
	var taken: Array = fixed.duplicate()
	var x := 260.0
	while x < LEVEL_END - 420.0:
		var w := rng.randf_range(110.0, 170.0)
		var r := Rect2(x, rng.randf_range(300.0, 500.0), w, 20.0)
		if _platform_fits(r, taken, gate_xs):
			placed.append(r)
			taken.append(r)
		x += rng.randf_range(170.0, 300.0)
	var arena_x := LEVEL_END - 260.0
	while arena_x < arena_right - 260.0:
		var r := Rect2(arena_x, rng.randf_range(400.0, 480.0), rng.randf_range(120.0, 170.0), 20.0)
		if _platform_fits(r, taken, gate_xs):
			placed.append(r)
			taken.append(r)
		arena_x += rng.randf_range(300.0, 420.0)
	return placed

func _platform_fits(r: Rect2, taken: Array, gate_xs: Array) -> bool:
	for gx in gate_xs:
		if gx > r.position.x - 40.0 and gx < r.end.x + 40.0:
			return false
	for t in taken:
		if r.grow_individual(50.0, 70.0, 50.0, 70.0).intersects(t):
			return false
	# Platforms floating too high need a lower step nearby, otherwise they are unreachable.
	if r.position.y < 380.0:
		for t in taken:
			if t.position.y >= 380.0 and absf(t.get_center().x - r.get_center().x) < 300.0:
				return true
		return false
	return true

# Invisible energy barrier that blocks the player until its zone's mobs are dead.
func _add_gate(x: float) -> StaticBody2D:
	var body := StaticBody2D.new()
	body.add_to_group("gates")
	body.position = Vector2(x, FLOOR_Y - 700)
	var shape := RectangleShape2D.new()
	shape.size = Vector2(16, 1400)
	var cs := CollisionShape2D.new()
	cs.shape = shape
	body.add_child(cs)
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
	gate_hint_cd = maxf(0.0, gate_hint_cd - get_process_delta_time())
	if not gates.is_empty() and gate_hint_cd <= 0.0 and is_instance_valid(player) \
			and player.position.x > gates[0]["x"] - 50.0:
		gate_hint_cd = 4.0
		_say("Defeat the mobs nearby to keep moving!", 2.0)

func _camera_right_target() -> float:
	var right: float = gates[0]["x"] if not gates.is_empty() else arena_right
	if bichema_level:
		var room: Rect2 = bichema_rooms[bichema_background_index]["rect"]
		return clampf(right, cam_left + VIEW_WIDTH, room.end.x)
	return clampf(right, cam_left + VIEW_WIDTH, arena_right)

func _update_camera_limits(delta: float) -> void:
	if not is_instance_valid(camera):
		return
	var step := CAMERA_LIMIT_SPEED * delta
	cam_right = move_toward(cam_right, _camera_right_target(), step)
	camera.limit_right = int(cam_right)
	camera.limit_left = int(cam_left) if bichema_level else int(move_toward(camera.limit_left, cam_left, step))

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
	message = ComicBox.new()
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
	if bichema_level:
		for label: Label in [hud_label, boss_label, dialogue, help, score_label]:
			label.add_theme_color_override("font_outline_color", Color.BLACK)
			label.add_theme_constant_override("outline_size", 4)

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
	if bichema_level:
		_update_bichema_background()
	_update_camera_limits(delta)
	if not finished and not boss_started and is_instance_valid(player) and not player.dead and player.position.x > boss_trigger_x:
		_start_boss()

func _start_boss() -> void:
	boss_started = true
	_add_block(Rect2(boss_gate_x, -200, 30, FLOOR_Y + 200), "wall", bichema_level)
	cam_left = arena_right - VIEW_WIDTH if bichema_level else minf(LEVEL_END - 340.0, arena_right - VIEW_WIDTH)
	if is_instance_valid(camera):
		if bichema_level:
			cam_right = arena_right
			camera.limit_left = int(cam_left)
			camera.limit_right = int(cam_right)
			camera.force_update_scroll()
		else:
			camera.limit_left = int(minf(cam_left, camera.get_screen_center_position().x - VIEW_WIDTH / 2.0))
	if bichema_level:
		var genius := BossEvilGenius.new()
		genius.position = Vector2(boss_spawn_x, FLOOR_Y - 112)
		genius.target = player
		add_child(genius)
		genius.health_changed.connect(_on_boss_health)
		genius.defeated.connect(_on_boss_defeated)
		genius.transformed.connect(_on_ema_transformed)
		genius.speech.connect(_say)
		genius.activate()
		message.text = "THE EVIL GENIUS"
	else:
		var yeral := BossYeral.new()
		yeral.position = Vector2(boss_spawn_x, FLOOR_Y - 96)
		yeral.target = player
		yeral.floor_y = FLOOR_Y
		yeral.arena_min = LEVEL_END - 280.0
		yeral.arena_max = arena_right - 60.0
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

func _on_ema_transformed() -> void:
	costume_form = true
	boss_label.text = "EMA — SECOND FORM"
	message.text = "EMA'S TRUE FORM\nTHE PINK SUIT"
	message_timer.start(3.0)

func _on_boss_health(current: int, maximum: int) -> void:
	boss_label.text = ("EMA — SECOND FORM" if costume_form else "EVIL GENIUS") if bichema_level else ("GLIZZY GOBLER" if glizzy_form else "YERAL")
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
