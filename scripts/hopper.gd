class_name Hopper
extends Robot

const WINDUP := 0.35
const HOP_VELOCITY := -560.0
const HOP_SPEED := 150.0
const REST := 0.5

var windup := 0.0
var rest := REST

func _ready() -> void:
	super._ready()
	health = GameSettings.scale_health(4)

func _physics_process(delta: float) -> void:
	if dying or dead:
		return
	if not is_on_floor():
		velocity.y += GRAVITY * delta
	elif windup <= 0.0:
		velocity.x = 0.0
		rest -= delta
		if rest <= 0.0 and is_instance_valid(target) and not target.get("dead") \
				and absf(target.global_position.x - global_position.x) < 520.0:
			windup = WINDUP
	if windup > 0.0:
		windup -= delta
		sprite.scale = Vector2(0.26, 0.2)
		if windup <= 0.0:
			sprite.scale = Vector2(0.24, 0.24)
			if is_instance_valid(target):
				dir = 1 if target.global_position.x > global_position.x else -1
			if _at_zone_edge(dir):
				dir = -dir
			velocity = Vector2(dir * HOP_SPEED * GameSettings.aggro(), HOP_VELOCITY)
			rest = REST / GameSettings.aggro()
	move_and_slide()
	_clamp_to_zone()
	_touch_damage()
	_update_locomotion()

func _draw() -> void:
	draw_arc(Vector2(0, -72), 12.0, PI, TAU, 16, Color8(255, 190, 70), 3.0, true)
