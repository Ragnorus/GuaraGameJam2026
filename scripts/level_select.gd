extends Control

const YERAL_SCENE := "res://scenes/main.tscn"
const EMA_SCENE := "res://scenes/ema_level.tscn"

func _ready() -> void:
	var backdrop := ColorRect.new()
	backdrop.color = Color(0.025, 0.035, 0.08)
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(backdrop)

	var stack := VBoxContainer.new()
	stack.anchor_left = 0.5
	stack.anchor_top = 0.5
	stack.anchor_right = 0.5
	stack.anchor_bottom = 0.5
	stack.offset_left = -280.0
	stack.offset_top = -170.0
	stack.offset_right = 280.0
	stack.offset_bottom = 170.0
	stack.alignment = BoxContainer.ALIGNMENT_CENTER
	stack.add_theme_constant_override("separation", 18)
	add_child(stack)

	var title := Label.new()
	title.text = "GUARA SLAYER"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 44)
	stack.add_child(title)

	var prompt := Label.new()
	prompt.text = "CHOOSE A LEVEL"
	prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt.add_theme_font_size_override("font_size", 22)
	stack.add_child(prompt)

	var yeral_button := _add_level_button(stack, "Yeral — The Spoilerman", YERAL_SCENE)
	_add_level_button(stack, "The Infested Zone — Ema, the Bug Queen", EMA_SCENE)
	yeral_button.grab_focus()

func _add_level_button(stack: VBoxContainer, caption: String, scene_path: String) -> Button:
	var button := Button.new()
	button.text = caption
	button.custom_minimum_size = Vector2(560.0, 58.0)
	button.add_theme_font_size_override("font_size", 20)
	button.pressed.connect(_open_level.bind(scene_path))
	stack.add_child(button)
	return button

func _open_level(scene_path: String) -> void:
	var error := get_tree().change_scene_to_file(scene_path)
	if error != OK:
		push_error("Could not open level %s: %s" % [scene_path, error_string(error)])
