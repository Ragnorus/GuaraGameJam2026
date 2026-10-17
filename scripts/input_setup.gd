class_name InputSetup

static func _add_key(action: String, keys: Array) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	for k in keys:
		var ev := InputEventKey.new()
		ev.physical_keycode = k
		InputMap.action_add_event(action, ev)

static func setup() -> void:
	_add_key("move_left", [KEY_A, KEY_LEFT])
	_add_key("move_right", [KEY_D, KEY_RIGHT])
	_add_key("jump", [KEY_SPACE, KEY_W, KEY_UP])
	_add_key("shoot", [KEY_J])
	_add_key("summon", [KEY_K])
	_add_key("recall", [KEY_L])
	_add_key("ultimate", [KEY_U])
	_add_key("restart", [KEY_R])
	var mb := InputEventMouseButton.new()
	mb.button_index = MOUSE_BUTTON_LEFT
	InputMap.action_add_event("shoot", mb)
