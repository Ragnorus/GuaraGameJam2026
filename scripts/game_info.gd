extends Control

# Reviewer-facing rules screen. Difficulty numbers are read from GameSettings so they never drift.

func _ready() -> void:
	GameSettings.load_settings()
	MenuKit.backdrop(self)
	var stack := MenuKit.column(self, 980.0)
	MenuKit.label(stack, "GAME INFO", 44)

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(980.0, 500.0)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	stack.add_child(scroll)
	var text := Label.new()
	text.text = _build_text()
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.custom_minimum_size.x = 950.0
	text.add_theme_font_size_override("font_size", 18)
	scroll.add_child(text)

	var back := MenuKit.button(stack, "Back", MenuKit.go.bind(self, "res://scenes/main_menu.tscn"))
	back.grab_focus()

func _build_text() -> String:
	var lines: Array[String] = []
	lines.append("PREMISE")
	lines.append("You are the Controller King. Fight through two levels and beat their bosses: Yeral the Spoilerman (two forms) and the Evil Genius in Bichema's World.")
	lines.append("")
	lines.append("DIFFICULTY (choose in Settings)")
	lines.append("Difficulty changes three things for every mob and boss: health, the damage they deal to you, and aggression (movement speed and how often they attack).")
	for d in GameSettings.DIFFICULTIES:
		lines.append("  - %s (%s): health x%s, damage x%s, aggression x%s" % [
			d["name"], d["label"], snappedf(d["hp"], 0.01), snappedf(d["damage"], 0.01), snappedf(d["aggro"], 0.01)])
	lines.append("Damage is rounded and never below 1 per hit. Your own health and attacks are the same on every difficulty.")
	lines.append("")
	lines.append("SCORE")
	lines.append("  - Mobs give %d-%d points. The deeper into the level a mob stands, the more it is worth. Minions summoned by a boss give 1." % [GameSettings.MOB_POINTS_MIN, GameSettings.MOB_POINTS_MAX])
	lines.append("  - Defeating a boss gives %d points." % GameSettings.BOSS_POINTS)
	lines.append("  - Coins give 5 points. Medalla cans restore up to 4 HP and remain until the player needs healing.")
	lines.append("  - Score carries from Yeral into Bichema's World during one run. Dying or pressing R restarts the level with the score you had when it began.")
	lines.append("  - Replaying from Level Select starts a fresh score.")
	lines.append("")
	lines.append("HIGH SCORE")
	lines.append("The best run score is saved separately for each difficulty (in the browser's storage on the web build) and shown on the main menu and in the in-game HUD. It is recorded when you die or defeat a boss.")
	lines.append("Current high scores:")
	for i in range(GameSettings.DIFFICULTIES.size()):
		lines.append("  - %s: %d" % [GameSettings.DIFFICULTIES[i]["name"], GameSettings.high_scores[i]])
	lines.append("")
	lines.append("CONTROLS")
	lines.append("Move A/D or arrows / Left Stick or D-pad; Jump Space/W/Up or A; Dash Shift or LB; Controller Smash J/left click or X/Right Trigger.")
	lines.append("Summon minions K or Y; Recall L or RB; GUARA ARMY U or R3 (full meter); SHIELD BURST E or L3 (unlocked by beating the Football Sergeant); Restart R (retries from your last checkpoint in Yeral's level); Pause Esc/B/Start. Menus: D-pad/Left Stick, A to accept, B/Start to go back.")
	lines.append("")
	lines.append("MENU")
	lines.append("Start Game begins at the first level. Level Select replays a specific level. Settings has difficulty, resolution, fullscreen, music and sound.")
	return "\n".join(lines)

func _unhandled_input(event: InputEvent) -> void:
	MenuKit.handle_back(event, self)
