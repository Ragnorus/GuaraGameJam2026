class_name BichemaRoute
extends Node2D

const AREAS: Array[Rect2] = [
	Rect2(0, 0, 1280, 720), Rect2(1280, 0, 1280, 720),
	Rect2(2560, 0, 1600, 720), Rect2(4160, 0, 1280, 720),
	Rect2(5440, 0, 1600, 720), Rect2(7040, 0, 1280, 720)]
const TITLES := ["AREA 1 - PLAZA", "AREA 2 - PLAZA EXIT", "AREA 3 - PUB / TACOMA",
	"AREA 4 - CASH FACTORY", "AREA 5 - EAST WING APPROACH", "EMA'S EAST WING ARENA"]
const TACOMA_TRUCK_TEXTURE := preload("res://assets/tacoma_truck.png")
const TACOMA_TRUCK_SCALE := 0.75

var stage: Node2D
var area_index := 0
var transitioning := false
var room_enemies: Array[Array] = []
var curtain: ColorRect
var truck: Sprite2D
var tacoma_arrived := false
var cinematic: Tween
var hint_cooldown := 0.0

func build(parent_stage: Node2D) -> void:
	stage = parent_stage
	stage._build_background()
	stage.arena_right = AREAS[5].end.x
	stage.boss_gate_x = AREAS[5].position.x
	stage.boss_trigger_x = AREAS[5].position.x + 120.0
	stage.boss_spawn_x = AREAS[5].end.x - 280.0
	for i in range(AREAS.size()):
		room_enemies.append([])
	_build_geometry()
	_build_overlay()
	truck = Sprite2D.new()
	truck.texture = TACOMA_TRUCK_TEXTURE
	truck.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	truck.centered = false
	truck.scale = Vector2.ONE * TACOMA_TRUCK_SCALE
	truck.z_index = -1
	truck.position = Vector2(AREAS[2].position.x - truck.texture.get_width() * TACOMA_TRUCK_SCALE,
			600.0 - truck.texture.get_height() * TACOMA_TRUCK_SCALE)
	truck.hide()
	add_child(truck)
	stage.player = Player.new()
	stage.player.collision_mask |= stage.PLATFORM_LAYER
	stage.player.position = Vector2(100.0, 564.0)
	stage.add_child(stage.player)
	stage.player.died.connect(stage._on_player_died)
	stage.player.stats_changed.connect(stage._update_hud)
	stage.camera = Camera2D.new()
	stage.player.add_child(stage.camera)
	_spawn_bug(0, Vector2(500, 562))
	_spawn_bug(0, Vector2(1000, 562))
	_spawn_flyer(0, 700.0, 470.0)
	_spawn_bug(1, Vector2(1600, 562))
	_spawn_bug(1, Vector2(2260, 562))
	_spawn_flyer(1, 1900.0, 470.0)
	var pub_ledge: Rect2 = stage.bichema_rooms[1]["platforms"][4]
	_spawn_tacoma(2, &"capi", Vector2(3100.0, 550.0), true, 3020.0, 3200.0)
	_spawn_tacoma(2, &"ludo", Vector2(pub_ledge.get_center().x, pub_ledge.position.y - 42.0),
			false, pub_ledge.position.x, pub_ledge.end.x)
	_spawn_bug(4, Vector2(5860, 562))
	_spawn_bug(4, Vector2(6500, 562))
	_spawn_flyer(4, 6220.0, 470.0)
	for at in [Vector2(350, 550), Vector2(850, 550), Vector2(1450, 550), Vector2(2110, 550),
			Vector2(2880, 550), Vector2(3600, 550), Vector2(4830, 550), Vector2(7550, 550)]:
		stage._spawn_pickup(Pickup.Kind.COIN, at)
	for at in [Vector2(1080, 550), Vector2(2420, 550), Vector2(6700, 550)]:
		stage._spawn_pickup(Pickup.Kind.MEDALLA, at)
	_set_area(0)

func _build_geometry() -> void:
	stage._add_block(Rect2(0, 600, AREAS[5].end.x, 120), "floor", true)
	for i in range(stage.bichema_rooms.size()):
		var room: Dictionary = stage.bichema_rooms[i]
		for rect: Rect2 in room["platforms"]:
			stage._add_block(rect, "platform", i != 0)
	for rect in [Rect2(-40, -200, 40, 920), Rect2(AREAS[5].end.x, -200, 40, 920)]:
		stage._add_block(rect, "wall", true)

func _build_overlay() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 12
	add_child(layer)
	curtain = ColorRect.new()
	curtain.color = Color(0, 0, 0, 0)
	curtain.mouse_filter = Control.MOUSE_FILTER_IGNORE
	curtain.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.add_child(curtain)


func _spawn_bug(room: int, at: Vector2) -> void:
	var enemy := TruffleAndroid.new()
	enemy.position = at
	enemy.target = stage.player
	enemy.zone_min = AREAS[room].position.x
	enemy.zone_max = AREAS[room].end.x
	enemy.points = clampi(1 + int(5.0 * at.x / AREAS[5].end.x), GameSettings.MOB_POINTS_MIN, GameSettings.MOB_POINTS_MAX)
	stage.add_child(enemy)
	room_enemies[room].append(enemy)

func _spawn_flyer(room: int, x: float, y: float) -> void:
	var enemy := WingedMob.new()
	enemy.bichema = true
	enemy.position = Vector2(x, y)
	enemy.target = stage.player
	enemy.zone_min = AREAS[room].position.x
	enemy.zone_max = AREAS[room].end.x
	enemy.points = clampi(1 + int(5.0 * x / AREAS[5].end.x), GameSettings.MOB_POINTS_MIN, GameSettings.MOB_POINTS_MAX)
	stage.add_child(enemy)
	room_enemies[room].append(enemy)

func _spawn_tacoma(room: int, bro: StringName, at: Vector2, is_sergeant: bool, min_x: float, max_x: float) -> void:
	var enemy := TacomaBro.new()
	enemy.bro_name = bro
	enemy.sergeant = is_sergeant
	enemy.position = at
	enemy.target = stage.player
	enemy.zone_min = min_x
	enemy.zone_max = max_x
	enemy.points = 5
	enemy.collision_mask |= stage.PLATFORM_LAYER
	stage.add_child(enemy)
	room_enemies[room].append(enemy)


func _set_area(index: int) -> void:
	area_index = index
	for i in range(room_enemies.size()):
		for enemy in room_enemies[i]:
			if is_instance_valid(enemy) and not enemy.dead:
				var active := i == index and (not (enemy is TacomaBro) or tacoma_arrived)
				enemy.process_mode = Node.PROCESS_MODE_INHERIT if active else Node.PROCESS_MODE_DISABLED
				enemy.visible = active
	stage.cam_left = AREAS[index].position.x
	stage.cam_right = AREAS[index].end.x
	stage._update_bichema_background()
	# Keep camera movement tied to playable area bounds, not the painted background
	# image bounds. The background panels do not necessarily match the route widths.
	stage.camera.limit_left = int(stage.cam_left)
	stage.camera.limit_right = int(stage.cam_right)
	stage.camera.reset_smoothing()
	stage.camera.force_update_scroll()

func _room_clear() -> bool:
	for enemy in room_enemies[area_index]:
		if is_instance_valid(enemy) and not enemy.dead:
			return false
	return true

func update(delta: float) -> void:
	if stage.player.dead:
		return
	if transitioning:
		return
	stage._update_bichema_background()
	hint_cooldown = maxf(0.0, hint_cooldown - delta)
	var player: Player = stage.player
	var rect := AREAS[area_index]
	player.position.x = clampf(player.position.x, rect.position.x + 24.0, rect.end.x - 24.0)
	if player.position.y > rect.end.y + 100.0:
		player.die()
		return
	if area_index == 5:
		return
	var at_exit := player.position.x > rect.end.x - 95.0
	if area_index == 4:
		at_exit = player.position.x > rect.end.x - 160.0
	if at_exit:
		if not _room_clear():
			if hint_cooldown <= 0.0:
				stage._say("Defeat the Tacoma Brothers before leaving!" if area_index == 2 else "Defeat the guards to open the route!", 2.0)
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
	stage.player.player_sprite.play(&"run")
	cinematic = create_tween()
	var exit: Vector2 = stage.player.position + Vector2(55, 0)
	cinematic.tween_property(stage.player, "position", exit, 0.55)
	cinematic.parallel().tween_property(curtain, "color:a", 1.0, 0.55)
	if next == 5:
		cinematic.parallel().tween_property(stage.player, "modulate:a", 0.0, 0.55)
	cinematic.tween_callback(func() -> void:
		_set_area(next)
		stage.player.position = Vector2(AREAS[next].position.x + 90.0, 564.0)
		stage.player.velocity = Vector2.ZERO
		stage.player.modulate.a = 1.0
		stage.camera.reset_smoothing()
		stage.camera.force_update_scroll()
		stage.message.text = TITLES[next]
		stage.message_timer.start(2.0)
		if next == 2:
			truck.position = Vector2(stage.cam_left - truck.texture.get_width() * TACOMA_TRUCK_SCALE,
					600.0 - truck.texture.get_height() * TACOMA_TRUCK_SCALE)
			truck.modulate.a = 1.0
			truck.show()
	)
	cinematic.tween_property(curtain, "color:a", 0.0, 0.55)
	if next == 2:
		var drive := cinematic.tween_property(truck, "position:x", AREAS[2].position.x + 250.0, 1.3)
		drive.set_trans(Tween.TRANS_CUBIC)
		drive.set_ease(Tween.EASE_OUT)
		cinematic.tween_interval(0.15)
		cinematic.tween_property(truck, "modulate:a", 0.0, 0.2)
		cinematic.tween_callback(_start_tacoma_disembark)
	else:
		cinematic.tween_callback(_finish_transition)

func _start_tacoma_disembark() -> void:
	truck.hide()
	var disembark := create_tween().set_parallel()
	for enemy in room_enemies[2]:
		if enemy is TacomaBro:
			enemy.process_mode = Node.PROCESS_MODE_INHERIT
			enemy.set_physics_process(false)
			enemy.visible = true
			enemy.modulate.a = 0.0
			enemy.position.x -= 24.0
			enemy.sprite.play(&"run")
			disembark.tween_property(enemy, "position:x", enemy.position.x + 24.0, 0.25)
			disembark.tween_property(enemy, "modulate:a", 1.0, 0.25)
	disembark.finished.connect(_finish_tacoma_entry)

func _finish_tacoma_entry() -> void:
	tacoma_arrived = true
	for enemy in room_enemies[2]:
		if enemy is TacomaBro:
			enemy.set_physics_process(true)
	_set_area(2)
	_finish_transition()

func _finish_transition() -> void:
	stage.player.controls_locked = false
	transitioning = false

