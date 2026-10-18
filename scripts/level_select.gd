extends Control

const YERAL_SCENE := "res://scenes/main.tscn"
const BICHEMA_SCENE := "res://scenes/bichema_level.tscn"

func _ready() -> void:
	GameSettings.load_settings()
	MenuKit.backdrop(self)
	var stack := MenuKit.column(self)
	MenuKit.label(stack, "LEVEL SELECT", 44)
	MenuKit.label(stack, "Difficulty: %s" % GameSettings.current()["name"], 18)
	var yeral_button := MenuKit.button(stack, "Yeral — The Spoilerman", _open_level.bind(YERAL_SCENE))
	MenuKit.button(stack, "Bichema's World — The Evil Genius", _open_level.bind(BICHEMA_SCENE))
	MenuKit.button(stack, "End Credits", MenuKit.go.bind(self, "res://scenes/end_credits.tscn"))
	MenuKit.button(stack, "Back", MenuKit.go.bind(self, "res://scenes/main_menu.tscn"))
	yeral_button.grab_focus()

# Replaying a level starts a fresh score.
func _open_level(scene_path: String) -> void:
	GameSettings.begin_run()
	MenuKit.go(self, scene_path)

func _unhandled_input(event: InputEvent) -> void:
	MenuKit.handle_back(event, self)
