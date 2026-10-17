extends Control

const INTRO_SCENE := "res://scenes/story_intro.tscn"
const TITLE_ART := preload("res://assets/ui/title_screen.png")

var menu: Control
var art: TextureRect
var started := false
# Only the first visit shows the bare PRESS START screen; returning from sub-menus opens the menu directly.
static var title_seen := false

func _ready() -> void:
	GameSettings.load_settings()
	GameAudio.start_music(get_tree())
	MenuKit.backdrop(self)
	# Title art: the supplied "The Night Unc" screen, unaltered, scaled to cover the window.
	art = TextureRect.new()
	art.texture = TITLE_ART
	art.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(art)
	menu = Control.new()
	menu.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	menu.mouse_filter = Control.MOUSE_FILTER_IGNORE
	menu.visible = false
	add_child(menu)
	# The title is in the art, so the menu is a slim strip along the bottom bezel.
	var strip := ColorRect.new()
	strip.color = Color(0.02, 0.03, 0.07, 0.82)
	strip.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	strip.offset_top = -78.0
	strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	menu.add_child(strip)
	var row := HBoxContainer.new()
	row.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	row.offset_top = -66.0
	row.offset_bottom = -12.0
	row.offset_left = 24.0
	row.offset_right = -24.0
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 12)
	menu.add_child(row)
	var info := Label.new()
	info.text = "Difficulty: %s   |   High score: %d" % [
		GameSettings.current()["name"], GameSettings.high_scores[GameSettings.difficulty]]
	info.add_theme_font_size_override("font_size", 16)
	info.add_theme_color_override("font_color", Color8(232, 176, 72))
	info.add_theme_color_override("font_outline_color", Color8(8, 10, 20))
	info.add_theme_constant_override("outline_size", 6)
	info.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	info.offset_top = -104.0
	info.offset_bottom = -80.0
	info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	menu.add_child(info)
	var start := _menu_button(row, "Start Game", _start_game)
	_menu_button(row, "Level Select", MenuKit.go.bind(self, "res://scenes/level_select.tscn"))
	_menu_button(row, "Settings", MenuKit.go.bind(self, "res://scenes/settings_menu.tscn"))
	_menu_button(row, "Game Info", MenuKit.go.bind(self, "res://scenes/game_info.tscn"))
	if not OS.has_feature("web"):
		_menu_button(row, "Quit", get_tree().quit)
	menu.set_meta("focus", start)
	if title_seen:
		_open_menu(false)

func _menu_button(row: HBoxContainer, caption: String, callback: Callable) -> Button:
	var b := MenuKit.button(row, caption, callback)
	b.custom_minimum_size = Vector2(200.0, 54.0)
	return b

# The art says PRESS START: any key, button or click opens the menu over it.
func _input(event: InputEvent) -> void:
	if started:
		return
	var pressed := (event is InputEventKey or event is InputEventJoypadButton or event is InputEventMouseButton) \
			and event.is_pressed() and not event.is_echo()
	if not pressed:
		return
	get_viewport().set_input_as_handled()
	_open_menu()

func _open_menu(fade := true) -> void:
	started = true
	title_seen = true
	menu.visible = true
	if fade:
		GameAudio.play(get_tree(), "click")
		menu.modulate.a = 0.0
		create_tween().tween_property(menu, "modulate:a", 1.0, 0.25)
	(menu.get_meta("focus") as Button).grab_focus()

func _start_game() -> void:
	GameSettings.begin_run()
	MenuKit.go(self, INTRO_SCENE)
