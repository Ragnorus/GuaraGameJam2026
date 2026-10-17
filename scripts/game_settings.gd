class_name GameSettings
extends RefCounted

# Static game-wide state: difficulty, display/audio settings and the run score.
# Settings are saved to user://settings.cfg (browser storage on web) once load_settings() has run.

const PATH := "user://settings.cfg"
const BOSS_POINTS := 10
const MOB_POINTS_MIN := 1
const MOB_POINTS_MAX := 5

# hp: mob and boss health multiplier. damage: damage dealt to the player. aggro: movement and attack-rate multiplier.
const DIFFICULTIES := [
	{"name": "Baby Guara", "label": "Easy", "hp": 0.6, "damage": 0.5, "aggro": 0.8},
	{"name": "Young Guara", "label": "Medium", "hp": 1.0, "damage": 1.0, "aggro": 1.0},
	{"name": "Guara", "label": "Hard", "hp": 1.5, "damage": 1.5, "aggro": 1.2},
	{"name": "OG Guara", "label": "Very Hard / Impossible", "hp": 2.5, "damage": 2.0, "aggro": 1.5},
]
const RESOLUTIONS := [Vector2i(1280, 720), Vector2i(1600, 900), Vector2i(1920, 1080), Vector2i(2560, 1440)]

static var difficulty := 1
static var music_on := true
static var sfx_on := true
static var music_volume := 0.6
static var sfx_volume := 0.8
static var fullscreen := false
static var resolution_index := 0
static var score := 0
static var level_start_score := 0
static var high_scores: Array[int] = [0, 0, 0, 0]
static var loaded := false

static func current() -> Dictionary:
	return DIFFICULTIES[clampi(difficulty, 0, DIFFICULTIES.size() - 1)]

static func difficulty_title(index: int) -> String:
	var d: Dictionary = DIFFICULTIES[index]
	return "%s (%s)" % [d["name"], d["label"]]

static func scale_health(base: int) -> int:
	return maxi(1, roundi(base * float(current()["hp"])))

static func incoming_damage(amount: int) -> int:
	return maxi(1, roundi(amount * float(current()["damage"])))

static func aggro() -> float:
	return float(current()["aggro"])

# Run score. A run starts from the menu; each level restarts from the score it began with.
static func begin_run() -> void:
	score = 0
	level_start_score = 0

static func begin_level() -> void:
	score = level_start_score

static func complete_level() -> void:
	level_start_score = score

static func add_score(points: int) -> void:
	score += points

static func high_score() -> int:
	return maxi(high_scores[difficulty], score)

# Stores the run score as the high score for this difficulty; returns true on a new record.
static func commit_score() -> bool:
	if score <= high_scores[difficulty]:
		return false
	high_scores[difficulty] = score
	save()
	return true

static func save() -> void:
	if not loaded:
		return
	var cfg := ConfigFile.new()
	cfg.set_value("game", "difficulty", difficulty)
	cfg.set_value("display", "fullscreen", fullscreen)
	cfg.set_value("display", "resolution", resolution_index)
	cfg.set_value("audio", "music_on", music_on)
	cfg.set_value("audio", "sfx_on", sfx_on)
	cfg.set_value("audio", "music_volume", music_volume)
	cfg.set_value("audio", "sfx_volume", sfx_volume)
	for i in range(high_scores.size()):
		cfg.set_value("scores", "difficulty_%d" % i, high_scores[i])
	cfg.save(PATH)

static func load_settings() -> void:
	if loaded:
		return
	loaded = true
	var cfg := ConfigFile.new()
	if cfg.load(PATH) == OK:
		difficulty = clampi(int(cfg.get_value("game", "difficulty", 1)), 0, DIFFICULTIES.size() - 1)
		fullscreen = bool(cfg.get_value("display", "fullscreen", false))
		resolution_index = clampi(int(cfg.get_value("display", "resolution", 0)), 0, RESOLUTIONS.size() - 1)
		music_on = bool(cfg.get_value("audio", "music_on", true))
		sfx_on = bool(cfg.get_value("audio", "sfx_on", true))
		music_volume = clampf(float(cfg.get_value("audio", "music_volume", 0.6)), 0.0, 1.0)
		sfx_volume = clampf(float(cfg.get_value("audio", "sfx_volume", 0.8)), 0.0, 1.0)
		for i in range(high_scores.size()):
			high_scores[i] = int(cfg.get_value("scores", "difficulty_%d" % i, 0))
	GameAudio.apply()
	apply_display(false)

# from_user: browsers only allow fullscreen changes from a click, so the web build skips the startup call.
static func apply_display(from_user := true) -> void:
	if DisplayServer.get_name() == "headless":
		return
	var web := OS.has_feature("web")
	if web and not from_user:
		return
	if fullscreen:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
		return
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	if web:
		return
	var screen := DisplayServer.screen_get_usable_rect()
	var size: Vector2i = RESOLUTIONS[resolution_index]
	size = Vector2i(mini(size.x, screen.size.x), mini(size.y, screen.size.y))
	DisplayServer.window_set_size(size)
	DisplayServer.window_set_position(screen.position + (screen.size - size) / 2)
