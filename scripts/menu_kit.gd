class_name MenuKit
extends RefCounted

# Shared builders so every menu screen looks and behaves the same.

static func backdrop(parent: Control) -> void:
	var rect := ColorRect.new()
	rect.color = Color(0.025, 0.035, 0.08)
	rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(rect)

static func column(parent: Control, width := 560.0) -> VBoxContainer:
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	parent.add_child(center)
	var stack := VBoxContainer.new()
	stack.custom_minimum_size.x = width
	stack.add_theme_constant_override("separation", 14)
	center.add_child(stack)
	return stack

static func label(parent: Control, text: String, size := 20) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", size)
	parent.add_child(l)
	return l

static func button(parent: Control, caption: String, callback: Callable) -> Button:
	var b := Button.new()
	b.text = caption
	b.custom_minimum_size = Vector2(0.0, 54.0)
	b.add_theme_font_size_override("font_size", 20)
	b.pressed.connect(func() -> void: GameAudio.play(b.get_tree(), "click"))
	b.pressed.connect(callback)
	parent.add_child(b)
	return b

static func go(from: Node, scene_path: String) -> void:
	var error := from.get_tree().change_scene_to_file(scene_path)
	if error != OK:
		push_error("Could not open %s: %s" % [scene_path, error_string(error)])

static func handle_back(event: InputEvent, from: Node) -> void:
	if event.is_action_pressed("ui_cancel"):
		from.get_viewport().set_input_as_handled()
		go(from, "res://scenes/main_menu.tscn")
