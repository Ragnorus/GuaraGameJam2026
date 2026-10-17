extends Control

var difficulty_note: Label
var music_slider: HSlider
var sfx_slider: HSlider

func _ready() -> void:
	GameSettings.load_settings()
	MenuKit.backdrop(self)
	var stack := MenuKit.column(self, 720.0)
	MenuKit.label(stack, "SETTINGS", 44)

	var difficulty := OptionButton.new()
	for i in range(GameSettings.DIFFICULTIES.size()):
		difficulty.add_item(GameSettings.difficulty_title(i), i)
	difficulty.select(GameSettings.difficulty)
	difficulty.item_selected.connect(_on_difficulty)
	_row(stack, "Difficulty", difficulty)
	difficulty_note = Label.new()
	difficulty_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	difficulty_note.modulate = Color(1.0, 0.85, 0.4)
	stack.add_child(difficulty_note)
	_refresh_note()

	if OS.has_feature("web"):
		MenuKit.label(stack, "Resolution scales automatically in the browser; use Fullscreen.", 15)
	else:
		var resolution := OptionButton.new()
		for r in GameSettings.RESOLUTIONS:
			resolution.add_item("%d x %d" % [r.x, r.y])
		resolution.select(GameSettings.resolution_index)
		resolution.item_selected.connect(_on_resolution)
		_row(stack, "Resolution", resolution)

	var fullscreen := CheckButton.new()
	fullscreen.button_pressed = GameSettings.fullscreen
	fullscreen.toggled.connect(_on_fullscreen)
	_row(stack, "Fullscreen", fullscreen)

	var music := CheckButton.new()
	music.button_pressed = GameSettings.music_on
	music.toggled.connect(_on_music)
	_row(stack, "Music", music)
	music_slider = _slider(GameSettings.music_volume, _on_music_volume)
	_row(stack, "Music volume", music_slider)

	var sfx := CheckButton.new()
	sfx.button_pressed = GameSettings.sfx_on
	sfx.toggled.connect(_on_sfx)
	_row(stack, "Sound effects", sfx)
	sfx_slider = _slider(GameSettings.sfx_volume, _on_sfx_volume)
	_row(stack, "Sound volume", sfx_slider)

	var back := MenuKit.button(stack, "Back", MenuKit.go.bind(self, "res://scenes/main_menu.tscn"))
	back.grab_focus()

func _row(stack: VBoxContainer, caption: String, control: Control) -> void:
	var row := HBoxContainer.new()
	var l := Label.new()
	l.text = caption
	l.custom_minimum_size.x = 240.0
	l.add_theme_font_size_override("font_size", 20)
	row.add_child(l)
	control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(control)
	stack.add_child(row)

func _slider(value: float, callback: Callable) -> HSlider:
	var s := HSlider.new()
	s.min_value = 0.0
	s.max_value = 1.0
	s.step = 0.05
	s.value = value
	s.custom_minimum_size.y = 28.0
	s.value_changed.connect(callback)
	return s

func _refresh_note() -> void:
	var d := GameSettings.current()
	difficulty_note.text = "Mob & boss health x%s  |  Damage to you x%s  |  Aggression x%s" % [
		snappedf(d["hp"], 0.01), snappedf(d["damage"], 0.01), snappedf(d["aggro"], 0.01)]

func _on_difficulty(index: int) -> void:
	GameSettings.difficulty = index
	GameSettings.save()
	_refresh_note()

func _on_resolution(index: int) -> void:
	GameSettings.resolution_index = index
	GameSettings.save()
	GameSettings.apply_display()

func _on_fullscreen(on: bool) -> void:
	GameSettings.fullscreen = on
	GameSettings.save()
	GameSettings.apply_display()

func _on_music(on: bool) -> void:
	GameSettings.music_on = on
	GameSettings.save()
	GameAudio.apply()

func _on_music_volume(value: float) -> void:
	GameSettings.music_volume = value
	GameSettings.save()
	GameAudio.apply()

func _on_sfx(on: bool) -> void:
	GameSettings.sfx_on = on
	GameSettings.save()
	GameAudio.apply()
	GameAudio.play(get_tree(), "kill")

func _on_sfx_volume(value: float) -> void:
	GameSettings.sfx_volume = value
	GameSettings.save()
	GameAudio.apply()

func _unhandled_input(event: InputEvent) -> void:
	MenuKit.handle_back(event, self)
