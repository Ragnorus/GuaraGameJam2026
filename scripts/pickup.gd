class_name Pickup
extends Area2D

enum Kind { MEDALLA, COIN, SMALL_HEAL, MECHA }

const MEDALLA_TEXTURE := preload("res://assets/medalla_can.png")
const COIN_TEXTURE := preload("res://assets/coin.png")
const MECHA_TEXTURE := preload("res://assets/mecha_chest.png")
const HEAL_AMOUNT := 4
const SMALL_HEAL_AMOUNT := 2
const COIN_POINTS := 5
const PICKUP_RADIUS := 24.0
const DROP_LIFETIME := 8.0
const COIN_DROP_CHANCE := 0.5
const HEAL_DROP_CHANCE := 0.22

var kind: int = Kind.COIN
# Dropped pickups vanish (blinking first) like Mega Man's energy capsules; 0 means permanent.
var lifetime := 0.0
var sprite: Sprite2D

# Enemy loot table: hurt players may get a small health drop, everyone may get a coin. Returns -1 for no drop.
static func roll_drop(roll: float, player_hurt: bool) -> int:
	if player_hurt and roll < HEAL_DROP_CHANCE:
		return Kind.SMALL_HEAL
	if roll < COIN_DROP_CHANCE:
		return Kind.COIN
	return -1

static func drop_loot(from: Node2D, player: Node) -> void:
	var stage := from.get_parent()
	if stage == null or not stage.has_method("_spawn_pickup"):
		return
	var hurt: bool = player != null and is_instance_valid(player) and player.get("health") != null \
			and int(player.get("health")) < int(player.get("max_health"))
	var drop := roll_drop(randf(), hurt)
	if drop >= 0:
		stage._spawn_pickup(drop, from.global_position + Vector2(0.0, -12.0), true)

func _ready() -> void:
	collision_layer = 0
	collision_mask = 1
	body_entered.connect(_on_body_entered)
	var shape := CircleShape2D.new()
	shape.radius = PICKUP_RADIUS
	var collision := CollisionShape2D.new()
	collision.shape = shape
	add_child(collision)
	sprite = Sprite2D.new()
	sprite.texture = COIN_TEXTURE if kind == Kind.COIN else MEDALLA_TEXTURE
	sprite.scale = Vector2(0.4, 0.4) if kind == Kind.SMALL_HEAL else Vector2(0.65, 0.65)
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	if kind == Kind.MECHA:
		sprite.texture = MECHA_TEXTURE
		sprite.scale = Vector2.ONE * 0.8
		var outline := ShaderMaterial.new()
		outline.shader = Player.OUTLINE_SHADER
		outline.set_shader_parameter("frame_uv", Vector4(0.0, 0.0, 1.0, 1.0))
		outline.set_shader_parameter("outline_color", Player.MECHA_OUTLINE_COLOR)
		sprite.material = outline
	add_child(sprite)

func _process(delta: float) -> void:
	if lifetime <= 0.0:
		return
	lifetime -= delta
	sprite.visible = lifetime > 2.0 or int(lifetime * 10.0) % 2 == 0
	if lifetime <= 0.0:
		queue_free()

func _on_body_entered(body: Node2D) -> void:
	if not body is Player:
		return
	var player := body as Player
	if player.dead:
		return
	if kind == Kind.MEDALLA or kind == Kind.SMALL_HEAL:
		var healed := player.heal(HEAL_AMOUNT if kind == Kind.MEDALLA else SMALL_HEAL_AMOUNT)
		if healed == 0:
			return
		_show_popup("+%d HP" % healed, Color8(120, 255, 120))
	elif kind == Kind.COIN:
		GameSettings.add_score(COIN_POINTS)
		_show_popup("+%d" % COIN_POINTS, Color8(255, 220, 80))
	elif kind == Kind.MECHA:
		if not player.activate_mecha():
			return
		_show_popup("MECHA: 20s", Player.MECHA_OUTLINE_COLOR)
	else:
		return
	queue_free()

func _show_popup(text: String, color: Color) -> void:
	var popup := Label.new()
	popup.text = text
	popup.position = global_position + Vector2(-18.0, -54.0)
	popup.add_theme_font_size_override("font_size", 20)
	popup.add_theme_color_override("font_color", color)
	popup.add_theme_color_override("font_outline_color", Color.BLACK)
	popup.add_theme_constant_override("outline_size", 4)
	popup.z_index = 50
	get_parent().add_child(popup)
	var tween := popup.create_tween()
	tween.tween_property(popup, "position:y", popup.position.y - 32.0, 0.65)
	tween.parallel().tween_property(popup, "modulate:a", 0.0, 0.65)
	tween.tween_callback(popup.queue_free)
