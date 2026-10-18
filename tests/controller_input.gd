extends SceneTree

func _initialize() -> void:
	InputSetup.setup()
	_check_button(&"move_left", JOY_BUTTON_DPAD_LEFT)
	_check_button(&"move_right", JOY_BUTTON_DPAD_RIGHT)
	_check_motion(&"move_left", JOY_AXIS_LEFT_X, -1.0)
	_check_motion(&"move_right", JOY_AXIS_LEFT_X, 1.0)
	_check_button(&"jump", JOY_BUTTON_A)
	_check_button(&"dash", JOY_BUTTON_B)
	_check_button(&"shoot", JOY_BUTTON_X)
	_check_motion(&"shoot", JOY_AXIS_TRIGGER_RIGHT, 1.0)
	_check_button(&"summon", JOY_BUTTON_Y)
	_check_button(&"recall", JOY_BUTTON_RIGHT_SHOULDER)
	_check_button(&"ultimate", JOY_BUTTON_RIGHT_STICK)
	_check_button(&"shield", JOY_BUTTON_LEFT_SHOULDER)
	var shield_stick := InputEventJoypadButton.new()
	shield_stick.button_index = JOY_BUTTON_LEFT_STICK
	assert(not InputMap.action_has_event(&"shield", shield_stick), "L3 must no longer activate Shield Burst")
	var shield_back := InputEventJoypadButton.new()
	shield_back.button_index = JOY_BUTTON_B
	assert(not InputMap.action_has_event(&"shield", shield_back), "B must remain available for menu cancel")
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
	_button(JOY_BUTTON_LEFT_SHOULDER, true)
	assert(Input.is_action_pressed(&"shield"), "LB must activate Shield Burst")
	assert(not Input.is_action_pressed(&"dash"), "LB must not activate Dash")
	_button(JOY_BUTTON_LEFT_SHOULDER, false)
	var jump_event := InputEventJoypadButton.new()
	jump_event.button_index = JOY_BUTTON_A
	jump_event.pressed = true
	Input.parse_input_event(jump_event)
	Input.flush_buffered_events()
	assert(Input.is_action_pressed(&"jump"), "A must activate gameplay jump")
	assert(Input.is_action_pressed(&"ui_accept"), "A must activate menu confirm")
	var shoot_trigger := InputEventJoypadMotion.new()
	shoot_trigger.axis = JOY_AXIS_TRIGGER_RIGHT
	shoot_trigger.axis_value = 1.0
	Input.parse_input_event(shoot_trigger)
	Input.flush_buffered_events()
	assert(Input.is_action_pressed(&"shoot"), "Right trigger must fire")
	assert(Input.is_action_pressed(&"jump"), "Jump must remain active while firing")
	var neutral_trigger := InputEventJoypadMotion.new()
	neutral_trigger.axis = JOY_AXIS_TRIGGER_RIGHT
	neutral_trigger.axis_value = 0.0
	Input.parse_input_event(neutral_trigger)
	Input.flush_buffered_events()
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
	await _check_level_input()

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
	assert(not Input.is_action_pressed(&"shield"), "B must cancel without activating Shield Burst")
	print("PASS: controller stage dash/shield/pause, keyboard controls, title/menu navigation, confirm/cancel, and repeated setup")
	quit()

func _frames(count: int) -> void:
	for i in range(count):
		await physics_frame
		await process_frame

func _button(button: int, pressed: bool) -> void:
	var event := InputEventJoypadButton.new()
	event.button_index = button
	event.pressed = pressed
	Input.parse_input_event(event)
	Input.flush_buffered_events()

func _key(key: Key, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = key
	event.physical_keycode = key
	event.pressed = pressed
	Input.parse_input_event(event)
	Input.flush_buffered_events()

func _check_level_input() -> void:
	GameSettings.loaded = true
	GameSettings.music_on = false
	GameSettings.sfx_on = false
	GameSettings.dash_unlocked = true
	GameSettings.shield_unlocked = true
	YeralRoute.checkpoint = 0
	assert(change_scene_to_file("res://scenes/main.tscn") == OK)
	await _frames(3)
	var stage := current_scene
	var player := stage.get("player") as Player
	# Keep the input fixture in normal form and away from unrelated combat.
	for child in stage.get_children():
		if child is Pickup and child.kind == Pickup.Kind.MECHA:
			child.queue_free()
	for enemy in get_nodes_in_group("enemies"):
		enemy.set_physics_process(false)
	player.invuln = 100.0
	await _frames(3)

	var start_x := player.position.x
	_button(JOY_BUTTON_B, true)
	await _frames(2)
	assert(not paused and player.dash_time > 0.0 and player.position.x > start_x, "B must dash in the real stage without opening pause")
	_button(JOY_BUTTON_B, false)
	await _frames(20)
	player.dash_cooldown = 0.0
	_button(JOY_BUTTON_LEFT_SHOULDER, true)
	await _frames(2)
	assert(player.shield_cd > 0.0 and player.dash_time == 0.0 and player.dash_cooldown == 0.0, "LB must shield without starting a dash")
	_button(JOY_BUTTON_LEFT_SHOULDER, false)
	player.shield_cd = 0.0
	_button(JOY_BUTTON_LEFT_STICK, true)
	await _frames(2)
	assert(player.shield_cd == 0.0, "L3 must not activate Shield Burst")
	_button(JOY_BUTTON_LEFT_STICK, false)
	var trigger := InputEventJoypadMotion.new()
	trigger.axis = JOY_AXIS_TRIGGER_LEFT
	trigger.axis_value = 1.0
	Input.parse_input_event(trigger)
	Input.flush_buffered_events()
	await _frames(2)
	assert(player.shield_cd == 0.0, "LT must not activate Shield Burst")
	trigger = InputEventJoypadMotion.new()
	trigger.axis = JOY_AXIS_TRIGGER_LEFT
	trigger.axis_value = 0.0
	Input.parse_input_event(trigger)
	Input.flush_buffered_events()

	_button(JOY_BUTTON_START, true)
	await _frames(2)
	assert(paused, "Start must pause active gameplay")
	_button(JOY_BUTTON_START, false)
	_button(JOY_BUTTON_B, true)
	await _frames(2)
	assert(not paused, "B must still resume a paused game")
	_button(JOY_BUTTON_B, false)
	await _frames(20)
	_key(KEY_ESCAPE, true)
	await _frames(2)
	assert(paused, "Esc must pause active gameplay")
	_key(KEY_ESCAPE, false)
	_key(KEY_ESCAPE, true)
	await _frames(2)
	assert(not paused, "Esc must resume paused gameplay")
	_key(KEY_ESCAPE, false)

	player.dash_cooldown = 0.0
	_key(KEY_SHIFT, true)
	await _frames(2)
	assert(player.dash_time > 0.0 and not paused, "Keyboard Shift must still dash")
	_key(KEY_SHIFT, false)
	await _frames(20)
	_key(KEY_Q, true)
	await _frames(2)
	assert(player.shield_cd > 0.0, "Keyboard Q must still shield")
	_key(KEY_Q, false)
	start_x = player.position.x
	_key(KEY_D, true)
	await _frames(3)
	_key(KEY_D, false)
	assert(player.position.x > start_x, "Keyboard D must still move the player")
	_key(KEY_SPACE, true)
	await _frames(2)
	_key(KEY_SPACE, false)
	assert(player.velocity.y < 0.0, "Keyboard Space must still jump")
	_key(KEY_J, true)
	await _frames(2)
	_key(KEY_J, false)
	assert(not get_nodes_in_group("player_shots").is_empty(), "Keyboard J must still fire")
	await _frames(1)

func _check_button(action: StringName, button: int) -> void:
	var event := InputEventJoypadButton.new()
	event.button_index = button
	assert(InputMap.action_has_event(action, event), "Missing joypad button for %s" % action)

func _check_motion(action: StringName, axis: int, value: float) -> void:
	var event := InputEventJoypadMotion.new()
	event.axis = axis
	event.axis_value = value
	assert(InputMap.action_has_event(action, event), "Missing joypad axis for %s" % action)
