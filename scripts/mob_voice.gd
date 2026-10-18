class_name MobVoice
extends AudioStreamPlayer2D

const RANGE := 700.0
const GRUNTS: Array[AudioStream] = [
	preload("res://assets/audio/monsters/grunt1.wav"),
	preload("res://assets/audio/monsters/grunt2.wav"),
	preload("res://assets/audio/monsters/piggrunt1.wav"),
	preload("res://assets/audio/monsters/piggrunt2.wav"),
]
const PAIN: Array[AudioStream] = [
	preload("res://assets/audio/monsters/painb.wav"),
	preload("res://assets/audio/monsters/paind.wav"),
	preload("res://assets/audio/monsters/paine.wav"),
	preload("res://assets/audio/monsters/painp.wav"),
	preload("res://assets/audio/monsters/painr.wav"),
	preload("res://assets/audio/monsters/pains.wav"),
]
const DEATH: Array[AudioStream] = [
	preload("res://assets/audio/monsters/deathb.wav"),
	preload("res://assets/audio/monsters/deathd.wav"),
	preload("res://assets/audio/monsters/deathe.wav"),
	preload("res://assets/audio/monsters/deathr.wav"),
	preload("res://assets/audio/monsters/deaths.wav"),
]

var defeated := false
var enabled := true

func _ready() -> void:
	GameAudio.apply()
	bus = "SFX"
	volume_db = -10.0
	max_distance = RANGE
	playback_type = AudioServer.PLAYBACK_TYPE_STREAM

func cue(kind: StringName, target: Node2D) -> void:
	if not enabled or defeated or not is_instance_valid(target) or target.get("dead") \
			or not can_process() or not (get_parent() as CanvasItem).is_visible_in_tree() \
			or global_position.distance_to(target.global_position) > RANGE:
		return
	if kind != &"death" and playing:
		return
	var clips: Array[AudioStream]
	match kind:
		&"attack":
			clips = GRUNTS
		&"hurt":
			clips = PAIN
		&"death":
			clips = DEATH
		_:
			push_error("Unknown mob voice cue: %s" % kind)
			return
	stop()
	if kind == &"death":
		defeated = true
		# Keep the cry alive after the corpse frees, but inside the current level.
		reparent(get_parent().get_parent())
		process_mode = Node.PROCESS_MODE_PAUSABLE
		finished.connect(queue_free)
	stream = clips.pick_random()
	play()

func _exit_tree() -> void:
	stop()
	stream = null
