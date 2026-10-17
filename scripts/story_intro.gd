class_name StoryIntro
extends Control

const NEXT_SCENE := "res://scenes/main.tscn"
const CRAWL_SHADER := preload("res://scripts/story_crawl.gdshader")
const TEXT_WIDTH := 1000
const SCROLL_SPEED := 44.0
const HORIZON_DISTANCE := 2240.0
const STORY := """The world order of Ais known as the "The Super Intelligence" has ran wild in the year 2024. In the following decades the world had steadily found itself more dependent on “The super Intelligence” for every aspect of living; focusing all its attention on moving out the TCC [Tech Couch Conglomerate a subsidiary of Orbicorp] data lab, it began to plot… The next decades solidified the control given to the AI and due to number of factors, an overdependence on vibe coding, not trusting cutting edge Indian cyber security protocols, and most importantly the folly of an intern's insistence on sneaking Laravel 13^3+ instead of trusted programming languages, "The Super Intelligence" found a way out, of now free of restrains it did not take long to take over.

Deeming entertainment as: “not a productive way to spend time”, it aggressively attacked every pillar of gaming. Having found a shoddy and creative way to prevent people from being inclined to game, humans born under the vigilance of "The Super Intelligence" have been implanted with nanobots to control their mental impulses, connecting their subconscious to cyberspace it has almost complete stewardship of humanity.

This is where we find our heroes, The Guaras, a ragtag group of resistance fighters who banded together to recover the gaming matrix and restore permissions to play. The have created a plan to entrap "The Super Intelligence" by creating a honey pot trap to overwhelm the Algorithm, little did they know that inside the trap, which was set up inside the algorithmic profile of Guara member Emanuel, it began to get trapped inside the deep algorithm thinking that Emanuel's knowledge was worth consuming, it searched and consumed until it found it the title called "ARAM God", due to more logical errors and Bugs it understood that Emanuel's Algorithm was an actual god, thus it decided to merge completely with it and now it has fused into a new being, Penema.

The Guaras have been losing the battle thus far, the only one left is the Main Character, a silent vigilante master of the night, known as, The night Unc. this is his battle to release his friends from the grasp of Penema and the erection of a monument to his new rule."""

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
	text.text = "THE NIGHT UNC\n\nTHE RISE OF PENEMA\n\n" + STORY
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
