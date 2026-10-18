extends Node2D

const LEVEL_END := 2400.0
const LEVEL_LEFT := -100.0
const FLOOR_Y := 600.0
const PLATFORM_LAYER := 4
const VIEW_WIDTH := 1280.0
const BICHEMA_BACKGROUND_HYSTERESIS := 24.0
const BICHEMA_BACKGROUND_BLEND_WIDTH := 240.0
const BICHEMA_BACKGROUND_BLEND_SHADER := preload("res://scripts/bichema_background_transition.gdshader")
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
var bichema_background_sprites: Array[Sprite2D] = []
var bichema_background_blends: Array[ColorRect] = []
var bichema_background_bleeds: Array[Sprite2D] = []
var bichema_rooms: Array[Dictionary] = []
var bichema_background_index := -1
var bichema_background_area_index := -1
var boss_gate_x := LEVEL_END - 340.0
var boss_trigger_x := LEVEL_END - 300.0
var boss_spawn_x := LEVEL_END + 600.0
var finished := false
var yeral_reward: YeralReward
var ending_transition := false
var gates: Array = []
var hp_bar: ProgressBar
var meter_bar: ProgressBar
var boss_bar: ProgressBar
var score_label: Label
# Right edge of the boss arena; Yeral's lair is wider so the fight has room to move.
var arena_right := LEVEL_END + 500.0
var camera: Camera2D
var yeral_route: YeralRoute
var bichema_route: BichemaRoute
var cam_left := LEVEL_LEFT
var cam_right := LEVEL_END

func _ready() -> void:
	InputSetup.setup()
	GameSettings.begin_level()
	if GameSettings.loaded:
		GameAudio.start_music(get_tree(), false, 2 if bichema_level else 1)
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
			body.z_index = -2
			cs.one_way_collision = true
			if not painted:
				_add_platform_sprite(body, rect)
			_add_platform_edge(body, rect.size)
		_:
			if not painted:
				body.add_child(_tiled("res://assets/tile_wall.png", origin, rect.size))
	add_child(body)

func _add_platform_edge(body: StaticBody2D, size: Vector2) -> void:
	var edge := Node2D.new()
	edge.name = "LandingEdge"
	edge.add_to_group("landing_edges")
	edge.z_index = 1
	var left := Vector2(-size.x / 2.0, -size.y / 2.0)
	var right := left + Vector2(size.x, 0.0)
	var points := PackedVector2Array([
		left + Vector2(0.0, 7.0), left, right, right + Vector2(0.0, 7.0)])
	for width in [7.0, 3.0]:
		var line := Line2D.new()
		line.points = points
		line.width = width
		line.default_color = Color8(8, 13, 18) if width == 7.0 else Color8(255, 224, 145)
		line.joint_mode = Line2D.LINE_JOINT_SHARP
		edge.add_child(line)
	body.add_child(edge)

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

# Keep every unaltered painting in world space so camera edges never expose the canvas clear color.
func _build_bichema_background() -> void:
	var start := 0.0
	var panels := ["plaza", "pub", "factory", "factory"]
	var titles := ["GOLDEN TREASURY PLAZA", "LUCKY IRISH ROCK BAR",
		"NEON CROWN CASH FACTORY", "NEON CROWN CASH FACTORY - EAST WING"]
	var source_indices := [0, 1, 2, 2]
	for panel in panels:
		var index := bichema_rooms.size()
		var source_index: int = source_indices[index]
		var tex: Texture2D = load("res://assets/backgrounds/bichema/%s.png" % panel)
		var k := 722.0 / tex.get_height()
		var rect := Rect2(start, FLOOR_Y - BICHEMA_GROUND[source_index] * k, floorf(tex.get_width() * k), 722)
		var platforms: Array[Rect2] = []
		for pixels: Rect2 in BICHEMA_PLATFORMS[source_index]:
			platforms.append(Rect2(rect.position + pixels.position * k, pixels.size * k))
		bichema_rooms.append({"name": titles[index], "texture": tex, "rect": rect,
			"scale": k, "ground": BICHEMA_GROUND[source_index], "platforms": platforms})
		start = rect.end.x
	arena_right = start
	var backstop := Polygon2D.new()
	backstop.name = "BichemaBackgroundBackstop"
	var route_right: float = bichema_route.AREAS[5].end.x
	backstop.polygon = PackedVector2Array([
		Vector2(0.0, -200.0), Vector2(route_right, -200.0),
		Vector2(route_right, 900.0), Vector2(0.0, 900.0)])
	backstop.color = Color(0.02, 0.035, 0.03)
	backstop.z_index = -11
	add_child(backstop)
	var camera_top_min: float = (bichema_rooms[0]["rect"] as Rect2).position.y
	var camera_bottom_max: float = (bichema_rooms[0]["rect"] as Rect2).end.y
	for room in bichema_rooms:
		var rect: Rect2 = room["rect"]
		var texture: Texture2D = room["texture"]
		var room_scale: float = room["scale"]
		camera_top_min = minf(camera_top_min, rect.position.y)
		camera_bottom_max = maxf(camera_bottom_max, rect.end.y)
		var sprite := Sprite2D.new()
		sprite.centered = false
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		sprite.texture = texture
		sprite.position = rect.position
		sprite.scale = Vector2.ONE * room_scale
		sprite.z_index = -10
		add_child(sprite)
		bichema_background_sprites.append(sprite)
	for room in bichema_rooms:
		var rect: Rect2 = room["rect"]
		var texture: Texture2D = room["texture"]
		var room_scale: float = room["scale"]
		var edge_rows := mini(32, texture.get_height())
		var top_height := rect.position.y - camera_top_min
		if top_height > 0.5:
			var top_bleed := Sprite2D.new()
			top_bleed.name = "BichemaBackgroundTopBleed%d" % bichema_background_bleeds.size()
			top_bleed.centered = false
			top_bleed.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
			top_bleed.texture = texture
			top_bleed.region_enabled = true
			top_bleed.region_rect = Rect2(0.0, 0.0, texture.get_width(), edge_rows)
			top_bleed.position = Vector2(rect.position.x, camera_top_min)
			top_bleed.scale = Vector2(room_scale, top_height / edge_rows)
			top_bleed.z_index = -10
			add_child(top_bleed)
			bichema_background_bleeds.append(top_bleed)
		var bottom_height := camera_bottom_max - rect.end.y
		if bottom_height > 0.5:
			var bottom_bleed := Sprite2D.new()
			bottom_bleed.name = "BichemaBackgroundBottomBleed%d" % bichema_background_bleeds.size()
			bottom_bleed.centered = false
			bottom_bleed.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
			bottom_bleed.texture = texture
			bottom_bleed.region_enabled = true
			bottom_bleed.region_rect = Rect2(0.0, texture.get_height() - edge_rows, texture.get_width(), edge_rows)
			bottom_bleed.position = Vector2(rect.position.x, rect.end.y)
			bottom_bleed.scale = Vector2(room_scale, bottom_height / edge_rows)
			bottom_bleed.z_index = -10
			add_child(bottom_bleed)
			bichema_background_bleeds.append(bottom_bleed)
	for i in range(1, bichema_rooms.size()):
		var left_room: Dictionary = bichema_rooms[i - 1]
		var right_room: Dictionary = bichema_rooms[i]
		var left_rect: Rect2 = left_room["rect"]
		var right_rect: Rect2 = right_room["rect"]
		var left_texture: Texture2D = left_room["texture"]
		var right_texture: Texture2D = right_room["texture"]
		var origin := Vector2(right_rect.position.x - BICHEMA_BACKGROUND_BLEND_WIDTH / 2.0, -200.0)
		var blend := ColorRect.new()
		blend.name = "BichemaBackgroundBlend%d" % i
		blend.position = origin
		blend.size = Vector2(BICHEMA_BACKGROUND_BLEND_WIDTH, 1100.0)
		blend.color = Color.WHITE
		blend.mouse_filter = Control.MOUSE_FILTER_IGNORE
		blend.z_index = -9
		var material := ShaderMaterial.new()
		material.shader = BICHEMA_BACKGROUND_BLEND_SHADER
		material.set_shader_parameter("left_texture", left_texture)
		material.set_shader_parameter("right_texture", right_texture)
		material.set_shader_parameter("transition_origin", origin)
		material.set_shader_parameter("transition_size", blend.size)
		material.set_shader_parameter("left_origin", left_rect.position)
		material.set_shader_parameter("right_origin", right_rect.position)
		material.set_shader_parameter("left_texture_size", Vector2(left_texture.get_size()))
		material.set_shader_parameter("right_texture_size", Vector2(right_texture.get_size()))
		material.set_shader_parameter("left_scale", float(left_room["scale"]))
		material.set_shader_parameter("right_scale", float(right_room["scale"]))
		blend.material = material
		add_child(blend)
		bichema_background_blends.append(blend)

func _update_bichema_background() -> void:
	if not is_instance_valid(camera) or not is_instance_valid(player) or bichema_rooms.is_empty():
		return
	var index := maxi(0, bichema_background_index)
	if bichema_background_index < 0:
		for i in range(1, bichema_rooms.size()):
			if player.position.x >= (bichema_rooms[i]["rect"] as Rect2).position.x:
				index = i
	else:
		while index < bichema_rooms.size() - 1 \
				and player.position.x >= (bichema_rooms[index + 1]["rect"] as Rect2).position.x \
				+ BICHEMA_BACKGROUND_HYSTERESIS:
			index += 1
		while index > 0 and player.position.x < (bichema_rooms[index]["rect"] as Rect2).position.x \
				- BICHEMA_BACKGROUND_HYSTERESIS:
			index -= 1
	var camera_top: float = (bichema_rooms[0]["rect"] as Rect2).position.y
	for i in range(1, bichema_rooms.size()):
		var rect: Rect2 = bichema_rooms[i]["rect"]
		var amount := clampf((player.position.x - rect.position.x
				+ BICHEMA_BACKGROUND_BLEND_WIDTH / 2.0) / BICHEMA_BACKGROUND_BLEND_WIDTH, 0.0, 1.0)
		amount = amount * amount * (3.0 - 2.0 * amount)
		camera_top = lerpf(camera_top, rect.position.y, amount)
	camera.limit_top = roundi(camera_top)
	camera.limit_bottom = camera.limit_top + 720
	var area := bichema_route.area_index if bichema_route != null else -1
	var room_changed := index != bichema_background_index
	if not room_changed and area == bichema_background_area_index:
		return
	_apply_bichema_background(index, area, room_changed)

func _apply_bichema_background(index: int, area: int, announce: bool) -> void:
	bichema_background_index = index
	bichema_background_area_index = area
	bichema_background = bichema_background_sprites[index]
	if announce and is_instance_valid(message) and not finished and not player.dead:
		message.text = bichema_rooms[index]["name"]
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
		yeral_route = YeralRoute.new()
		add_child(yeral_route)
		yeral_route.build(self)
		return
	bichema_route = BichemaRoute.new()
	add_child(bichema_route)
	bichema_route.build(self)

func _spawn_pickup(kind: int, at: Vector2, dropped := false) -> Pickup:
	var pickup := Pickup.new()
	pickup.kind = kind
	pickup.position = at
	if dropped:
		pickup.lifetime = Pickup.DROP_LIFETIME
	add_child(pickup)
	return pickup

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
	help.text = "Move A/D/LS/D-pad  Jump Space/A(Cross)  Smash J/X(Square)/RT(R2)  Dash Shift/B(Circle)\nSummon K/Y(Triangle)  Recall L/RB(R1)  Army U/R3  Shield Q/LB(L1)  Pause Esc/Start(Options)  Restart R"
	help.position = Vector2(16, 668)
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
	hud_label.text = "HP %d/%d%s" % [player.health, player.max_health,
			("   SHIELD " + ("READY (Q/LB/L1)" if player.shield_cd <= 0.0 else "%.0fs" % ceilf(player.shield_cd))) if GameSettings.shield_unlocked else ""]
	if player.mecha_time > 0.0:
		hud_label.text += "   MECHA %ds" % ceili(player.mecha_time)
	hud_label.position = Vector2(24, 74)
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
	if yeral_route != null:
		yeral_route.update(delta)
		return
	if bichema_route != null:
		bichema_route.update(delta)
		if not finished and not boss_started and is_instance_valid(player) and not player.dead \
				and player.position.x > boss_trigger_x:
			_start_boss()

func _start_boss() -> void:
	boss_started = true
	_add_block(Rect2(boss_gate_x, -200, 30, FLOOR_Y + 200), "wall", true)
	cam_left = arena_right - VIEW_WIDTH
	if is_instance_valid(camera):
		cam_right = arena_right
		camera.limit_left = int(cam_left)
		camera.limit_right = int(cam_right)
		camera.force_update_scroll()
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
	player.controls_locked = true
	player.clear_attacks()
	process_mode = Node.PROCESS_MODE_DISABLED
	boss_label.text = ""
	boss_bar.visible = false
	for e in get_tree().get_nodes_in_group("enemies"):
		e.queue_free()
	GameSettings.add_score(GameSettings.BOSS_POINTS)
	var new_high := GameSettings.commit_score()
	GameSettings.complete_level()
	if not bichema_level:
		YeralRoute.checkpoint = 0
	GameAudio.play(get_tree(), "boss")
	var score_text := "\nBoss +%d  |  Score: %d%s" % [GameSettings.BOSS_POINTS, GameSettings.score,
			"  NEW HIGH SCORE!" if new_high else ""]
	if bichema_level:
		message.text = "The Evil Genius is defeated! All levels clear." + score_text
	else:
		message.text = "Yeral and Glizzy Gobler defeated!" + score_text + "\nNext: Bichema's World"
	if bichema_level:
		message_timer.start(3.0)
	else:
		message_timer.stop()
		yeral_reward = YeralReward.new()
		yeral_reward.completed.connect(_on_yeral_reward_completed)
		add_child(yeral_reward)

func _on_yeral_reward_completed() -> void:
	if player.dead:
		return
	GameSettings.dash_unlocked = true
	GameSettings.save()
	_on_message_timeout()

func _on_message_timeout() -> void:
	if not finished:
		if not player.dead:
			message.text = ""
		return
	if ending_transition:
		return
	ending_transition = true
	if bichema_level:
		var layer := CanvasLayer.new()
		layer.layer = 100
		layer.process_mode = Node.PROCESS_MODE_ALWAYS
		add_child(layer)
		var fade := ColorRect.new()
		fade.color = Color(0, 0, 0, 0)
		fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		layer.add_child(fade)
		var tween := layer.create_tween()
		tween.tween_property(fade, "color:a", 1.0, 1.2)
		tween.tween_callback(_open_next_scene.bind("res://scenes/end_credits.tscn"))
	else:
		_open_next_scene("res://scenes/bichema_level.tscn")

func _open_next_scene(next_scene: String) -> void:
	var error := get_tree().change_scene_to_file(next_scene)
	if error != OK:
		process_mode = Node.PROCESS_MODE_INHERIT
		ending_transition = false
		if is_instance_valid(yeral_reward):
			yeral_reward.cancel()
		message.text = "Could not load the next level.\nPress R to restart."
		push_error("Could not open level %s: %s" % [next_scene, error_string(error)])

func _on_player_died() -> void:
	if is_instance_valid(yeral_reward) and not yeral_reward.cancelled:
		yeral_reward.cancel()
		finished = false
		process_mode = Node.PROCESS_MODE_INHERIT
	if finished:
		return
	message_timer.stop()
	player.clear_attacks()
	if yeral_route != null:
		yeral_route.cancel_intro()
	var new_high := GameSettings.commit_score()
	var retry := "Press R to retry from the checkpoint" if yeral_route != null and YeralRoute.checkpoint > 0 else "Press R to restart"
	message.text = "You died. Score: %d%s\n%s" % [GameSettings.score, "  NEW HIGH SCORE!" if new_high else "", retry]
