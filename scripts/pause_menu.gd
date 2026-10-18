class_name PauseMenu
extends CanvasLayer

# Esc/Start opens this over a level; menu cancel also resumes when paused.

var panel: Control

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 20
	panel = Control.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.visible = false
	add_child(panel)
	var dim := ColorRect.new()
	dim.color = Color(0.0, 0.0, 0.05, 0.75)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.add_child(dim)
	var stack := MenuKit.column(panel, 400.0)
	MenuKit.label(stack, "PAUSED", 44)
	MenuKit.button(stack, "Resume", _set_paused.bind(false))
	MenuKit.button(stack, "Restart Level", _restart)
	MenuKit.button(stack, "Main Menu", _main_menu)

func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("ui_cancel"):
		return
	if not get_tree().paused:
		var pause_key: bool = event is InputEventKey and (event.keycode == KEY_ESCAPE or event.physical_keycode == KEY_ESCAPE)
		var pause_button: bool = event is InputEventJoypadButton and event.button_index == JOY_BUTTON_START
		if not pause_key and not pause_button:
			return
	var level := get_parent()
	if level != null and level.get("finished") and level.get("yeral_reward") == null:
		return
	_set_paused(not get_tree().paused)
	get_viewport().set_input_as_handled()

func _set_paused(on: bool) -> void:
	get_tree().paused = on
	panel.visible = on
	if on:
		for b in panel.find_children("*", "Button", true, false):
			(b as Button).grab_focus()
			break

func _restart() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()

func _main_menu() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
