class_name EndCredits
extends Control

const MUSIC := preload("res://assets/audio/lord_of_the_night.mp3")
const MENU := "res://scenes/main_menu.tscn"
const INTRO_DURATION := 6.0
const ROLL_DURATION := 30.0
const TITLE_DURATION := 6.0
const FADE_DURATION := 1.5
const TOTAL_DURATION := INTRO_DURATION + ROLL_DURATION + TITLE_DURATION + FADE_DURATION
const MEMBERS := ["Shaggy......Ese es ponce?!", "Zinnaxef", "Ragn0rus", "Ludo", "Kpi", "Samurai Porcupine"]
const CAST: Array[SpriteFrames] = [
	preload("res://assets/character_frames.tres"),
	preload("res://assets/robot_frames.tres"),
	preload("res://assets/yeral_frames.tres"),
	preload("res://assets/glizzy_frames.tres"),
	preload("res://assets/sergeant_frames.tres"),
	preload("res://assets/money_minion_frames.tres"),
	preload("res://assets/neon_lawyer_frames.tres"),
	preload("res://assets/ema_costume_frames.tres"),
]

var elapsed := 0.0
var finishing := false
var song: AudioStreamPlayer
var opening: Label
var roll: VBoxContainer
var closing: Label
var fade: ColorRect
var cameos: Node2D
var retry: Button
var rng := RandomNumberGenerator.new()
var cameo_timer := 0.0

func _ready() -> void:
	GameSettings.load_settings()
	GameAudio.stop_music()
	GameAudio.apply()
	rng.randomize()
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var black := ColorRect.new()
	black.color = Color.BLACK
	black.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(black)
	cameos = Node2D.new()
	add_child(cameos)
	opening = _label("To Be Continued.....", 56)
	add_child(opening)
	roll = VBoxContainer.new()
	roll.add_theme_constant_override("separation", 46)
	add_child(roll)
	roll.add_child(_label("Team members:", 42))
	for member in MEMBERS:
		roll.add_child(_label(member, 32))
	closing = _label("Guaras Game Jam 2026", 52)
	add_child(closing)
	fade = ColorRect.new()
	fade.color = Color.BLACK
	fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(fade)
	retry = MenuKit.button(self, "Return to Main Menu", _finish)
	retry.hide()
	song = AudioStreamPlayer.new()
	song.stream = MUSIC
	song.bus = "Music"
	song.playback_type = AudioServer.PLAYBACK_TYPE_STREAM
	add_child(song)
	song.play()
	resized.connect(_layout)
	_layout()
	_update_cards()

func _label(text: String, font_size: int) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", Color8(248, 221, 160))
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label

func _layout() -> void:
	if not is_instance_valid(roll):
		return
	var font_scale := minf(1.0, size.x / 1280.0)
	opening.add_theme_font_size_override("font_size", maxi(16, roundi(56.0 * font_scale)))
	closing.add_theme_font_size_override("font_size", maxi(16, roundi(52.0 * font_scale)))
	for i in range(roll.get_child_count()):
		var label := roll.get_child(i) as Label
		label.add_theme_font_size_override("font_size", maxi(14, roundi((42.0 if i == 0 else 32.0) * font_scale)))
	for label in [opening, closing]:
		label.position = Vector2(size.x * 0.22, size.y * 0.3)
		label.size = Vector2(size.x * 0.56, size.y * 0.4)
	roll.size.x = size.x * 0.56
	roll.position.x = size.x * 0.22
	retry.position = Vector2(size.x * 0.5 - 160.0, size.y - 80.0)
	retry.size.x = 320.0

func _process(delta: float) -> void:
	if finishing:
		return
	elapsed += delta
	cameo_timer -= delta
	if elapsed < INTRO_DURATION + ROLL_DURATION and cameo_timer <= 0.0:
		_spawn_cameo()
		cameo_timer = rng.randf_range(2.8, 4.2)
	for child in cameos.get_children():
		var sprite := child as AnimatedSprite2D
		var age: float = float(sprite.get_meta("age")) + delta
		sprite.set_meta("age", age)
		if age >= 7.0 or elapsed >= INTRO_DURATION + ROLL_DURATION:
			sprite.queue_free()
			continue
		var point: Vector2 = sprite.get_meta("point")
		sprite.position = point * size + Vector2(0, -age * 5.0)
		sprite.modulate.a = minf(clampf(age, 0.0, 1.0), clampf(7.0 - age, 0.0, 1.0))
		sprite.modulate.a *= clampf(INTRO_DURATION + ROLL_DURATION - elapsed, 0.0, 1.0)
		var texture := sprite.sprite_frames.get_frame_texture(&"idle", 0)
		var extent := minf(size.x * 0.18, size.y * 0.3)
		sprite.scale = Vector2.ONE * extent / maxf(texture.get_width(), texture.get_height())
	_update_cards()
	if elapsed >= TOTAL_DURATION:
		_finish()

func _update_cards() -> void:
	opening.visible = elapsed < INTRO_DURATION
	opening.modulate.a = minf(clampf(elapsed / FADE_DURATION, 0.0, 1.0),
			clampf((INTRO_DURATION - elapsed) / FADE_DURATION, 0.0, 1.0))
	roll.visible = elapsed >= INTRO_DURATION and elapsed < INTRO_DURATION + ROLL_DURATION
	var progress := clampf((elapsed - INTRO_DURATION) / ROLL_DURATION, 0.0, 1.0)
	roll.position.y = lerpf(size.y + 30.0, -roll.size.y - 30.0, progress)
	var title_start := INTRO_DURATION + ROLL_DURATION
	closing.visible = elapsed >= title_start
	closing.modulate.a = clampf((elapsed - title_start) / FADE_DURATION, 0.0, 1.0)
	var fade_out := clampf((elapsed - (TOTAL_DURATION - FADE_DURATION)) / FADE_DURATION, 0.0, 1.0)
	fade.color.a = maxf(1.0 - clampf(elapsed / FADE_DURATION, 0.0, 1.0), fade_out)
	song.volume_db = linear_to_db(maxf(0.0001, (1.0 - fade_out) * clampf(elapsed / FADE_DURATION, 0.0, 1.0)))

func _spawn_cameo() -> void:
	var sprite := AnimatedSprite2D.new()
	sprite.sprite_frames = CAST[rng.randi_range(0, CAST.size() - 1)]
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	sprite.set_meta("age", 0.0)
	var side := 0.11 if rng.randi_range(0, 1) == 0 else 0.89
	sprite.set_meta("point", Vector2(side, rng.randf_range(0.25, 0.8)))
	sprite.modulate.a = 0.0
	cameos.add_child(sprite)
	sprite.play(&"idle")

func _finish() -> void:
	if finishing:
		return
	finishing = true
	var error := get_tree().change_scene_to_file(MENU)
	if error != OK:
		push_error("Could not open credits main menu: %s" % error_string(error))
		closing.text = "Could not open the main menu."
		closing.show()
		closing.modulate.a = 1.0
		fade.color.a = 0.0
		retry.show()
		retry.grab_focus()
		finishing = false
		set_process(false)

func _exit_tree() -> void:
	if is_instance_valid(song):
		song.stop()
		song.stream = null
