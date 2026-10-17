extends SceneTree

func _initialize() -> void:
	InputSetup.setup()
	_check_button(&"move_left", JOY_BUTTON_DPAD_LEFT)
	_check_button(&"move_right", JOY_BUTTON_DPAD_RIGHT)
	_check_motion(&"move_left", JOY_AXIS_LEFT_X, -1.0)
	_check_motion(&"move_right", JOY_AXIS_LEFT_X, 1.0)
	_check_button(&"jump", JOY_BUTTON_A)
	_check_button(&"dash", JOY_BUTTON_LEFT_SHOULDER)
	_check_button(&"shoot", JOY_BUTTON_X)
	_check_button(&"summon", JOY_BUTTON_Y)
	_check_button(&"recall", JOY_BUTTON_RIGHT_SHOULDER)
	_check_button(&"ultimate", JOY_BUTTON_RIGHT_STICK)
	_check_button(&"ui_accept", JOY_BUTTON_A)
	_check_button(&"ui_cancel", JOY_BUTTON_B)
	_check_button(&"ui_cancel", JOY_BUTTON_START)
	_check_button(&"ui_left", JOY_BUTTON_DPAD_LEFT)
	_check_button(&"ui_right", JOY_BUTTON_DPAD_RIGHT)
	_check_button(&"ui_up", JOY_BUTTON_DPAD_UP)
	_check_button(&"ui_down", JOY_BUTTON_DPAD_DOWN)
	_check_motion(&"ui_left", JOY_AXIS_LEFT_X, -1.0)
	_check_motion(&"ui_right", JOY_AXIS_LEFT_X, 1.0)
	_check_motion(&"ui_up", JOY_AXIS_LEFT_Y, -1.0)
	_check_motion(&"ui_down", JOY_AXIS_LEFT_Y, 1.0)
	var count := InputMap.action_get_events(&"jump").size()
	InputSetup.setup()
	assert(InputMap.action_get_events(&"jump").size() == count, "Repeated setup must not duplicate bindings")
	_check_synthetic_input.call_deferred()

func _check_synthetic_input() -> void:
	await process_frame
	var jump_event := InputEventJoypadButton.new()
	jump_event.button_index = JOY_BUTTON_A
	jump_event.pressed = true
	Input.parse_input_event(jump_event)
	Input.flush_buffered_events()
	assert(Input.is_action_pressed(&"jump"), "A must activate gameplay jump")
	assert(Input.is_action_pressed(&"ui_accept"), "A must activate menu confirm")
	var jump_release := InputEventJoypadButton.new()
	jump_release.button_index = JOY_BUTTON_A
	Input.parse_input_event(jump_release)
	var stick_event := InputEventJoypadMotion.new()
	stick_event.axis = JOY_AXIS_LEFT_X
	stick_event.axis_value = -1.0
	Input.parse_input_event(stick_event)
	Input.flush_buffered_events()
	assert(Input.is_action_pressed(&"move_left"), "Left stick must move the player")
	assert(Input.is_action_pressed(&"ui_left"), "Left stick must navigate menus")
	var neutral_stick := InputEventJoypadMotion.new()
	neutral_stick.axis = JOY_AXIS_LEFT_X
	neutral_stick.axis_value = 0.0
	Input.parse_input_event(neutral_stick)
	await process_frame

	assert(change_scene_to_file("res://scenes/main_menu.tscn") == OK)
	await process_frame
	var title := current_scene
	var title_stick := InputEventJoypadMotion.new()
	title_stick.axis = JOY_AXIS_LEFT_X
	title_stick.axis_value = 1.0
	Input.parse_input_event(title_stick)
	Input.flush_buffered_events()
	await process_frame
	assert(title.get("started") and (title.get("menu") as Control).visible, "Left-stick motion must open the title menu")

	var right := InputEventJoypadButton.new()
	right.button_index = JOY_BUTTON_DPAD_RIGHT
	right.pressed = true
	Input.parse_input_event(right)
	Input.flush_buffered_events()
	await process_frame
	var focus := get_root().gui_get_focus_owner()
	assert(focus is Button and (focus as Button).text == "Level Select", "D-pad must move focus between menu buttons")

	var accept := InputEventJoypadButton.new()
	accept.button_index = JOY_BUTTON_A
	accept.pressed = true
	Input.parse_input_event(accept)
	Input.flush_buffered_events()
	await process_frame
	var accept_release := InputEventJoypadButton.new()
	accept_release.button_index = JOY_BUTTON_A
	Input.parse_input_event(accept_release)
	Input.flush_buffered_events()
	await process_frame
	assert(current_scene.scene_file_path == "res://scenes/level_select.tscn", "A must activate the focused menu button")

	var cancel := InputEventJoypadButton.new()
	cancel.button_index = JOY_BUTTON_B
	cancel.pressed = true
	Input.parse_input_event(cancel)
	Input.flush_buffered_events()
	await process_frame
	assert(current_scene.scene_file_path == "res://scenes/main_menu.tscn", "B must return from submenus")
	print("PASS: controller gameplay, title/menu navigation, confirm/cancel, and repeated setup")
	quit()

func _check_button(action: StringName, button: int) -> void:
	var event := InputEventJoypadButton.new()
	event.button_index = button
	assert(InputMap.action_has_event(action, event), "Missing joypad button for %s" % action)

func _check_motion(action: StringName, axis: int, value: float) -> void:
	var event := InputEventJoypadMotion.new()
	event.axis = axis
	event.axis_value = value
	assert(InputMap.action_has_event(action, event), "Missing joypad axis for %s" % action)
