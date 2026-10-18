class_name SergeantVoice
extends AudioStreamPlayer2D

const RANGE := 1000.0
const GRUNTS: Array[AudioStream] = [
	preload("res://assets/audio/sergeant/3grunt3.wav"),
	preload("res://assets/audio/sergeant/3grunt4.wav"),
	preload("res://assets/audio/sergeant/3grunt5.wav"),
]
const SCREAM := preload("res://assets/audio/sergeant/3yell1.wav")
const RAGE := preload("res://assets/audio/sergeant/3yell13.wav")
const DEATH := preload("res://assets/audio/sergeant/3yell10.wav")

var defeated := false

func _ready() -> void:
	GameAudio.apply()
	bus = "SFX"
	volume_db = -6.0
	pitch_scale = 0.9
	max_distance = RANGE
	playback_type = AudioServer.PLAYBACK_TYPE_STREAM

func cue(kind: StringName) -> void:
	var actor := get_parent() as Sergeant
	if defeated or not actor.can_process() or not actor.is_visible_in_tree() \
			or not actor._target_alive() or (actor.dead and kind != &"death") \
			or actor.global_position.distance_to(actor.target.global_position) > RANGE:
		return
	if playing and kind in [&"attack", &"hurt"]:
		return
	var clip: AudioStream
	match kind:
		&"attack", &"hurt":
			clip = GRUNTS.pick_random()
		&"scream":
			clip = SCREAM
		&"rage":
			clip = RAGE
		&"death":
			clip = DEATH
		_:
			push_error("Unknown Sergeant voice cue: %s" % kind)
			return
	stop()
	stream = clip
	defeated = kind == &"death"
	play()

func _process(_delta: float) -> void:
	var actor := get_parent() as Sergeant
	if playing and not actor._target_alive():
		stop()

func _exit_tree() -> void:
	stop()
	stream = null
