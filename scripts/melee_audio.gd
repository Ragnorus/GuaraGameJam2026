class_name MeleeAudio
extends AudioStreamPlayer2D

const STRIKE := preload("res://assets/audio/melee/melee sound.wav")
const ANIMAL := preload("res://assets/audio/melee/animal melee sound.wav")
const RANGE := 700.0

static func strike(source: Node2D, target: Node2D, animal := false) -> void:
	if not is_instance_valid(target) or (target is Player and (target.dead or target.controls_locked)):
		return
	_play(source, animal)

static func contact(source: Node2D, target: Node2D, damage: int, animal := false) -> void:
	# Preserve take_damage's default recoil; hit_by with zero knockback would remove it.
	var before := (target as Player).health if target is Player else 0
	target.take_damage(damage)
	if target is Player and target.health < before:
		_play(source, animal)

static func _play(source: Node2D, animal: bool) -> void:
	if not source.can_process() or not source.is_visible_in_tree():
		return
	var audio := source.get_node_or_null("MeleeAudio") as MeleeAudio
	if audio == null:
		audio = MeleeAudio.new()
		audio.name = "MeleeAudio"
		source.add_child(audio)
	if audio.playing:
		return
	audio.stream = ANIMAL if animal else STRIKE
	audio.play()

func _ready() -> void:
	GameAudio.apply()
	bus = "SFX"
	volume_db = -8.0
	max_distance = RANGE
	playback_type = AudioServer.PLAYBACK_TYPE_STREAM

func _exit_tree() -> void:
	stop()
	stream = null
