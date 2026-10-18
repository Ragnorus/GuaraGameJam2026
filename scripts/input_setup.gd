class_name InputSetup

static func _add_event(action: String, event: InputEvent) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	if not InputMap.action_has_event(action, event):
		InputMap.action_add_event(action, event)

static func _add_key(action: String, keys: Array) -> void:
	for key in keys:
		var event := InputEventKey.new()
		event.physical_keycode = key
		_add_event(action, event)

static func _add_joy_button(action: String, button: int) -> void:
	var event := InputEventJoypadButton.new()
	event.button_index = button
	_add_event(action, event)

static func _add_joy_motion(action: String, axis: int, value: float) -> void:
	var event := InputEventJoypadMotion.new()
	event.axis = axis
	event.axis_value = value
	_add_event(action, event)

static func setup() -> void:
	_add_key("move_left", [KEY_A, KEY_LEFT])
	_add_key("move_right", [KEY_D, KEY_RIGHT])
	_add_key("jump", [KEY_SPACE, KEY_W, KEY_UP])
	_add_key("dash", [KEY_SHIFT])
	_add_key("shoot", [KEY_J])
	_add_key("summon", [KEY_K])
	_add_key("recall", [KEY_L])
	_add_key("ultimate", [KEY_U])
	_add_key("shield", [KEY_Q])
	_add_key("restart", [KEY_R])
	var mouse := InputEventMouseButton.new()
	mouse.button_index = MOUSE_BUTTON_LEFT
	_add_event("shoot", mouse)

	_add_joy_button("move_left", JOY_BUTTON_DPAD_LEFT)
	_add_joy_button("move_right", JOY_BUTTON_DPAD_RIGHT)
	_add_joy_motion("move_left", JOY_AXIS_LEFT_X, -1.0)
	_add_joy_motion("move_right", JOY_AXIS_LEFT_X, 1.0)
	_add_joy_button("jump", JOY_BUTTON_A)
	_add_joy_button("dash", JOY_BUTTON_LEFT_SHOULDER)
	_add_joy_button("shoot", JOY_BUTTON_X)
	_add_joy_motion("shoot", JOY_AXIS_TRIGGER_RIGHT, 1.0)
	_add_joy_button("summon", JOY_BUTTON_Y)
	_add_joy_button("recall", JOY_BUTTON_RIGHT_SHOULDER)
	_add_joy_motion("shield", JOY_AXIS_TRIGGER_LEFT, 1.0)
	_add_joy_button("ultimate", JOY_BUTTON_RIGHT_STICK)

	_add_joy_button("ui_accept", JOY_BUTTON_A)
	_add_joy_button("ui_cancel", JOY_BUTTON_B)
	_add_joy_button("ui_cancel", JOY_BUTTON_START)
	for binding in [
		[&"ui_left", JOY_BUTTON_DPAD_LEFT, JOY_AXIS_LEFT_X, -1.0],
		[&"ui_right", JOY_BUTTON_DPAD_RIGHT, JOY_AXIS_LEFT_X, 1.0],
		[&"ui_up", JOY_BUTTON_DPAD_UP, JOY_AXIS_LEFT_Y, -1.0],
		[&"ui_down", JOY_BUTTON_DPAD_DOWN, JOY_AXIS_LEFT_Y, 1.0],
	]:
		_add_joy_button(binding[0], binding[1])
		_add_joy_motion(binding[0], binding[2], binding[3])
