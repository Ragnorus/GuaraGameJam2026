class_name StoryIntro
extends Control

const NEXT_SCENE := "res://scenes/main.tscn"
const CRAWL_SHADER := preload("res://scripts/story_crawl.gdshader")
const TEXT_WIDTH := 1000
const SCROLL_SPEED := 44.0
const HORIZON_DISTANCE := 2240.0
const STORY := """BANSHEE: THE MOVIE IS OVER

In the wake of political unrest, corruption, and violent riots, La Metrocity was left leaderless. With no true governor to restore order, the city descended into chaos as gangs, opportunists, and corrupt officials fought to claim what remained.

From the shadows emerged a man known as Emanuel Vega, better known throughout the streets as El Bichotema.

Unlike others who sought power through violence alone, Vega discovered something far more dangerous: a rare truffle whose extract could alter the minds of those who consumed it. Refined into a vibrant pink liquid, the substance caused users to perceive themselves and the world not as they truly were, but as they wished it to be. Their deepest fantasies became reality in their minds.

Realizing its potential, Vega secretly introduced the substance into the beer supply distributed throughout La Metrocity. As consumption spread, so did the illusion. The population slowly surrendered itself to a collective fantasy, becoming increasingly detached from reality. Crime was still rampant. Corruption still thrived

People still suffered.

But nobody wanted to see it.

They were living in a movie of their own making.

With the city trapped in a dream, El Bichotema tightened his grip. Supported by powerful allies in the senate and ruthless figures within the criminal underworld, he transformed himself from a political fixer into the undisputed ruler of La Metrocity.

Yet one man remained untouched.

After years away, he returned to find his childhood home devastated by the riots that had paved the way for El Bichotema's rise. Walking through the wreckage of his former life, he discovered remnants of a forgotten past scattered across the floor of his old bedroom. Among them was a battered reggaeton album: "El Señor de la Noche." Staring at the cover, he realized something.

The city did not need another politician. It did not need another revolutionary. It needed someone with the cunning mind of a man but with the ruthlessness of an animal.

Someone who could strike fear into the hearts of those profiting from the illusion. Someone who could remind La Metrocity that reality cannot be hidden forever.

That night, the man disappeared.

.In his place emerged a new figure whispered about across rooftops, alleyways, and underground clubs. A phantom. A warning. A scream in the darkness.

BANSHEE.

Now he wages a one-man war against El Bichotema's criminal empire, determined to shatter the illusion consuming the city and prove a simple truth:

Every movie must eventually end, and when the lights come on, everyone must face reality."""

var scroll_position := -80.0
var crawl_height := 0.0
var finishing := false
var crawl_material: ShaderMaterial
var skip_button: Button
var fade: ColorRect

func _ready() -> void:
	GameSettings.load_settings()
	GameAudio.start_music(get_tree())
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)
	_build_crawl()
	skip_button = MenuKit.button(self, "Skip Intro  [Enter / Space / Esc]", _finish)
	skip_button.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	skip_button.offset_left = -380.0
	skip_button.offset_right = -24.0
	skip_button.offset_top = -66.0
	skip_button.offset_bottom = -16.0
	skip_button.grab_focus()
	fade = ColorRect.new()
	fade.color = Color(0.0, 0.0, 0.0, 0.0)
	fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(fade)

func _build_crawl() -> void:
	var text_viewport := SubViewport.new()
	text_viewport.disable_3d = true
	text_viewport.transparent_bg = true
	text_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	text_viewport.size = Vector2i(TEXT_WIDTH, 720)
	add_child(text_viewport)
	var text := Label.new()
	text_viewport.add_child(text)
	text.text = STORY
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.horizontal_alignment = HORIZONTAL_ALIGNMENT_FILL
	text.add_theme_font_size_override("font_size", 34)
	text.add_theme_constant_override("line_spacing", 10)
	text.add_theme_color_override("font_color", Color8(248, 199, 78))
	text.size.x = TEXT_WIDTH
	var projection := TextureRect.new()
	projection.texture = text_viewport.get_texture()
	projection.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	projection.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	projection.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	projection.offset_left = 100.0
	projection.offset_right = -100.0
	projection.offset_top = 65.0
	projection.offset_bottom = -75.0
	projection.mouse_filter = Control.MOUSE_FILTER_IGNORE
	crawl_material = ShaderMaterial.new()
	crawl_material.shader = CRAWL_SHADER
	crawl_material.set_shader_parameter("text_height", 1.0)
	crawl_material.set_shader_parameter("scroll_position", scroll_position)
	projection.material = crawl_material
	add_child(projection)
	# Wrapped text height is resolved by Control layout on the next frame.
	await get_tree().process_frame
	crawl_height = ceilf(text.get_minimum_size().y) + 24.0
	text_viewport.size = Vector2i(TEXT_WIDTH, int(crawl_height))
	text_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	crawl_material.set_shader_parameter("text_height", crawl_height)

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.005, 0.008, 0.025))
	var rng := RandomNumberGenerator.new()
	rng.seed = 2024
	for i in range(180):
		var point := Vector2(rng.randf(), rng.randf()) * size
		var radius := rng.randf_range(0.6, 1.6)
		draw_circle(point, radius, Color(0.7, 0.8, 1.0, rng.randf_range(0.2, 0.75)))

func _process(delta: float) -> void:
	if finishing or crawl_height <= 0.0:
		return
	scroll_position += SCROLL_SPEED * delta
	crawl_material.set_shader_parameter("scroll_position", scroll_position)
	if scroll_position >= crawl_height + HORIZON_DISTANCE:
		_finish()

func _unhandled_input(event: InputEvent) -> void:
	var skip := event.is_action_pressed("ui_accept") or event.is_action_pressed("ui_cancel")
	if event is InputEventKey:
		skip = skip or (event.pressed and event.keycode == KEY_SPACE)
	if event is InputEventJoypadButton:
		skip = skip or (event.pressed and event.button_index in [JOY_BUTTON_A, JOY_BUTTON_B])
	if skip and not event.is_echo():
		get_viewport().set_input_as_handled()
		_finish()

func _finish() -> void:
	if finishing:
		return
	finishing = true
	skip_button.disabled = true
	var transition := create_tween()
	transition.tween_property(fade, "color:a", 1.0, 0.6)
	transition.tween_callback(MenuKit.go.bind(self, NEXT_SCENE))
