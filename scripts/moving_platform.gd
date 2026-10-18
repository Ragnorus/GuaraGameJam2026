class_name MovingPlatform
extends AnimatableBody2D

var start := Vector2.ZERO
var travel := Vector2.ZERO
var period := 4.0
var elapsed := 0.0

func _ready() -> void:
	sync_to_physics = true
	add_to_group("moving_platforms")

func _physics_process(delta: float) -> void:
	elapsed += delta
	position = start + travel * (0.5 - 0.5 * cos(TAU * elapsed / period))
