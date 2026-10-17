extends Control

const YERAL_SCENE := "res://scenes/main.tscn"

func _ready() -> void:
	GameSettings.load_settings()
	GameAudio.start_music(get_tree())
	MenuKit.backdrop(self)
	var stack := MenuKit.column(self)
	MenuKit.label(stack, "GUARA SLAYER", 60)
	MenuKit.label(stack, "Difficulty: %s   |   High score: %d" % [
		GameSettings.current()["name"], GameSettings.high_scores[GameSettings.difficulty]], 18)
	var start := MenuKit.button(stack, "Start Game", _start_game)
	MenuKit.button(stack, "Level Select", MenuKit.go.bind(self, "res://scenes/level_select.tscn"))
	MenuKit.button(stack, "Settings", MenuKit.go.bind(self, "res://scenes/settings_menu.tscn"))
	MenuKit.button(stack, "Game Info", MenuKit.go.bind(self, "res://scenes/game_info.tscn"))
	if not OS.has_feature("web"):
		MenuKit.button(stack, "Quit", get_tree().quit)
	start.grab_focus()

func _start_game() -> void:
	GameSettings.begin_run()
	MenuKit.go(self, YERAL_SCENE)
