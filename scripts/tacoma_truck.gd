class_name TacomaTruck
extends Bug

const TRUCK_FRAMES := preload("res://assets/tacoma_truck_frames.tres")
const MUSIC := preload("res://assets/audio/ronca.mp3")
const TRUCK_SCALE := 0.75
const TRUCK_SOURCE_WIDTH := 400.0
const HALF_WIDTH := TRUCK_SOURCE_WIDTH * TRUCK_SCALE / 2.0
const WINDUP_TIME := 0.65
const FIRST_WINDUP_TIME := 1.2
const CHARGE_TIME := 1.2
const CHARGE_SPEED := 480.0
const JUMP_SPEED := 520.0
const RECOVER_TIME := 1.0

enum DriveState { INTRO, WINDUP, CHARGE, RECOVER }

var drive_state := DriveState.INTRO
var state_time := FIRST_WINDUP_TIME
var charge_direction := 1
var hit_this_charge := false
var max_health := 0
var truck_sprite: AnimatedSprite2D
var music: AudioStreamPlayer

func _ready() -> void:
	robot = false
	super._ready()
	voice.enabled = false
	(cs.shape as RectangleShape2D).size = Vector2(252.0, 72.0)
	cs.position = Vector2(0.0, -36.0)
	health = GameSettings.scale_health(19)
	max_health = health
	points = 10
	collision_layer = 0
	collision_mask = 0
	truck_sprite = AnimatedSprite2D.new()
	truck_sprite.sprite_frames = TRUCK_FRAMES
	truck_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	truck_sprite.scale = Vector2.ONE * TRUCK_SCALE
	truck_sprite.centered = false
	truck_sprite.offset = Vector2(-320.0, -240.0)
	truck_sprite.z_index = -1
	add_child(truck_sprite)
	truck_sprite.play(&"drive")
	music = AudioStreamPlayer.new()
	var recording := MUSIC.duplicate() as AudioStreamMP3
	recording.loop = true
	music.stream = recording
	music.bus = "Music"
	music.playback_type = AudioServer.PLAYBACK_TYPE_STREAM
	add_child(music)
	if target is Player:
		(target as Player).died.connect(_stop_music)
	set_physics_process(false)
	queue_redraw()

func activate() -> void:
	if dead or not is_instance_valid(target) or (target is Player and (target as Player).dead):
		return
	collision_layer = 1
	collision_mask = 1
	velocity = Vector2.ZERO
	drive_state = DriveState.WINDUP
	state_time = FIRST_WINDUP_TIME
	truck_sprite.play(&"idle")
	set_physics_process(true)
	GameAudio.stop_music()
	music.play()

func _physics_process(delta: float) -> void:
	if dead or drive_state == DriveState.INTRO or not is_instance_valid(target) \
			or (target is Player and ((target as Player).dead or (target as Player).controls_locked)):
		return
	if not is_on_floor():
		velocity.y += GRAVITY * delta
	match drive_state:
		DriveState.WINDUP:
			velocity.x = 0.0
			dir = 1 if target.global_position.x >= global_position.x else -1
			state_time -= delta
			if state_time <= WINDUP_TIME:
				truck_sprite.play(&"drift")
			if state_time <= 0.0:
				if is_on_floor():
					velocity.y = -JUMP_SPEED
				drive_state = DriveState.CHARGE
				charge_direction = dir
				hit_this_charge = false
				state_time = CHARGE_TIME
				truck_sprite.play(&"charge")
		DriveState.CHARGE:
			dir = charge_direction
			velocity.x = dir * CHARGE_SPEED * GameSettings.aggro()
			state_time -= delta
			if is_on_floor():
				truck_sprite.play(&"drive")
		DriveState.RECOVER:
			velocity.x = 0.0
			state_time -= delta
			if state_time <= 0.0:
				drive_state = DriveState.WINDUP
				state_time = WINDUP_TIME
				truck_sprite.play(&"idle")
	truck_sprite.flip_h = (dir < 0) != (drive_state == DriveState.RECOVER and state_time < RECOVER_TIME / 2.0)
	truck_sprite.rotation = clampf(velocity.y / JUMP_SPEED, -1.0, 1.0) * 0.12 * dir if not is_on_floor() else 0.0
	move_and_slide()
	if drive_state == DriveState.CHARGE:
		_ram_player()
		if is_on_floor() and (state_time <= 0.0 or is_on_wall() or _at_zone_edge(charge_direction)):
			drive_state = DriveState.RECOVER
			state_time = RECOVER_TIME
			velocity.x = 0.0
			truck_sprite.rotation = 0.0
			truck_sprite.play(&"spin")
	_clamp_to_zone()

func _ram_player() -> void:
	if dead or drive_state != DriveState.CHARGE or hit_this_charge or not target is Player:
		return
	var player := target as Player
	var half := (cs.shape as RectangleShape2D).size / 2.0
	var distance := (player.global_position - (global_position + cs.position)).abs()
	if distance.x < half.x + PLAYER_HALF.x + TOUCH_MARGIN \
			and distance.y < half.y + PLAYER_HALF.y + TOUCH_MARGIN:
		hit_this_charge = player.hit_by(GameSettings.incoming_damage(2),
				Vector2(charge_direction * 650.0, -340.0))

func take_damage(amount: int) -> bool:
	if dead or drive_state == DriveState.INTRO:
		return false
	health -= amount
	queue_redraw()
	if health <= 0:
		_die()
	return true

func _die() -> void:
	dead = true
	remove_from_group("enemies")
	collision_layer = 0
	collision_mask = 0
	cs.set_deferred("disabled", true)
	_stop_music()
	_award_points()
	queue_free()

func _stop_music() -> void:
	music.stop()
	GameAudio.start_music(get_tree())

func _exit_tree() -> void:
	music.stop()
	music.stream = null

func _draw() -> void:
	if dead:
		return
	var width := 180.0
	var top := Vector2(-width / 2.0, -111.0)
	draw_rect(Rect2(top - Vector2(2.0, 2.0), Vector2(width + 4.0, 10.0)), Color(0.03, 0.05, 0.04))
	draw_rect(Rect2(top, Vector2(width * health / float(max_health), 6.0)), Color(0.44, 0.93, 0.09))
