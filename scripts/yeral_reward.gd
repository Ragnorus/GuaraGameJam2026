class_name YeralReward
extends CanvasLayer

signal completed

const VOICE := preload("res://assets/audio/night_unc_dime_a_vel.wav")
const ABSORB_TIME := 3.2
const LINE := "Dime a vel!"

var elapsed := 0.0
var cancelled := false
var speaking := false
var voice: AudioStreamPlayer
var screen: Control
var hero: AnimatedSprite2D
var bubble: PanelContainer
var title: Label
var power: Label
var fade: ColorRect

func duration() -> float:
	return ABSORB_TIME + maxf(2.5, VOICE.get_length()) + 1.0

func _ready() -> void:
	layer = 15
	process_mode = Node.PROCESS_MODE_PAUSABLE
	screen = Control.new()
	screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(screen)
	screen.draw.connect(_draw_energy)
	screen.resized.connect(_layout)
	title = _label("YERAL'S POWER", 38)
	screen.add_child(title)
	power = _label("DASH ACQUIRED!\nShift / B (Circle)   |   Jump during a dash to rise", 26)
	screen.add_child(power)
	hero = AnimatedSprite2D.new()
	hero.sprite_frames = Player.CHARACTER_FRAMES
	hero.scale = Vector2.ONE * 1.5
	hero.offset = Vector2(0, -72)
	hero.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	screen.add_child(hero)
	hero.play(&"summon")
	bubble = PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(1.0, 0.97, 0.83)
	style.border_color = Color8(8, 13, 10)
	style.set_border_width_all(4)
	style.set_corner_radius_all(18)
	style.content_margin_left = 24
	style.content_margin_right = 24
	style.content_margin_top = 12
	style.content_margin_bottom = 12
	bubble.add_theme_stylebox_override("panel", style)
	var line := _label(LINE, 34)
	line.add_theme_color_override("font_color", Color8(8, 13, 10))
	bubble.add_child(line)
	screen.add_child(bubble)
	for inner in [false, true]:
		var tail := Polygon2D.new()
		tail.color = style.bg_color if inner else style.border_color
		tail.polygon = PackedVector2Array([Vector2(25, 0), Vector2(65, 0), Vector2(10, 45)]) if not inner \
				else PackedVector2Array([Vector2(31, -3), Vector2(58, -3), Vector2(17, 32)])
		tail.position.y = 65
		bubble.add_child(tail)
	bubble.hide()
	fade = ColorRect.new()
	fade.color = Color.BLACK
	fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	screen.add_child(fade)
	voice = AudioStreamPlayer.new()
	voice.stream = VOICE
	voice.bus = "SFX"
	voice.playback_type = AudioServer.PLAYBACK_TYPE_STREAM
	add_child(voice)
	GameAudio.apply()
	_layout()
	_update_visuals()

func _label(text: String, font_size: int) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", Color8(248, 221, 160))
	return label

func _layout() -> void:
	if not is_instance_valid(hero):
		return
	title.position = Vector2(0, screen.size.y * 0.12)
	title.size.x = screen.size.x
	power.position = Vector2(0, screen.size.y * 0.79)
	power.size.x = screen.size.x
	bubble.position = screen.size * Vector2(0.55, 0.28)
	bubble.size = Vector2(290, 70)

func _process(delta: float) -> void:
	if cancelled:
		return
	elapsed += delta
	if elapsed >= ABSORB_TIME and not speaking:
		speaking = true
		bubble.show()
		hero.play(&"recall")
		voice.play()
	_update_visuals()
	if elapsed >= duration():
		set_process(false)
		voice.stop()
		completed.emit()

func _update_visuals() -> void:
	hero.position = screen.size * Vector2(0.5, 0.64) + Vector2(0, sin(elapsed * 3.0) * 8.0)
	power.modulate.a = clampf((elapsed - ABSORB_TIME + 0.3) * 2.0, 0.0, 1.0)
	fade.color.a = maxf(1.0 - clampf(elapsed / 0.6, 0.0, 1.0),
			clampf((elapsed - duration() + 0.7) / 0.7, 0.0, 1.0))
	screen.queue_redraw()

func _draw_energy() -> void:
	var size := screen.size
	screen.draw_rect(Rect2(Vector2.ZERO, size), Color8(4, 12, 15))
	var center := size * Vector2(0.5, 0.5)
	var absorb := clampf(elapsed / ABSORB_TIME, 0.0, 1.0)
	var glow := Color8(112, 237, 24)
	var radius := 150.0 + sin(elapsed * 5.0) * 12.0
	screen.draw_circle(center, radius, Color(0.3, 0.8, 0.2, 0.08))
	for i in range(3):
		screen.draw_arc(center, radius + i * 16.0, elapsed + i, elapsed + i + PI * 1.5, 64,
				Color(glow, 0.5), 2.0, true)
	if elapsed < ABSORB_TIME:
		for i in range(20):
			var angle := TAU * i / 20.0 + elapsed * 0.6
			var distance := lerpf(450.0, 40.0, fmod(absorb * 2.0 + i * 0.137, 1.0))
			var point := center + Vector2.from_angle(angle) * distance
			screen.draw_line(point, point + Vector2.from_angle(angle) * 30.0, glow, 3.0, true)
	else:
		for i in range(12):
			var angle := TAU * i / 12.0 - elapsed * 0.4
			var point := center + Vector2.from_angle(angle) * (190.0 + sin(elapsed * 4.0 + i) * 12.0)
			screen.draw_circle(point, 3.0, Color8(248, 221, 160))

func cancel() -> void:
	cancelled = true
	set_process(false)
	voice.stop()
	hide()

func _exit_tree() -> void:
	if is_instance_valid(voice):
		voice.stop()
		voice.stream = null
