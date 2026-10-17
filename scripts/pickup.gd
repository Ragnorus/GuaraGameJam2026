class_name Pickup
extends Area2D

enum Kind { MEDALLA, COIN }

const MEDALLA_TEXTURE := preload("res://assets/medalla_can.png")
const COIN_TEXTURE := preload("res://assets/coin.png")
const HEAL_AMOUNT := 4
const COIN_POINTS := 5
const PICKUP_RADIUS := 24.0

var kind: int = Kind.COIN

func _ready() -> void:
	collision_layer = 0
	collision_mask = 1
	body_entered.connect(_on_body_entered)
	var shape := CircleShape2D.new()
	shape.radius = PICKUP_RADIUS
	var collision := CollisionShape2D.new()
	collision.shape = shape
	add_child(collision)
	var sprite := Sprite2D.new()
	sprite.texture = MEDALLA_TEXTURE if kind == Kind.MEDALLA else COIN_TEXTURE
	sprite.scale = Vector2(0.65, 0.65)
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(sprite)

func _on_body_entered(body: Node2D) -> void:
	if not body is Player:
		return
	var player := body as Player
	if player.dead:
		return
	if kind == Kind.MEDALLA:
		var healed := player.heal(HEAL_AMOUNT)
		if healed == 0:
			return
		_show_popup("+%d HP" % healed, Color8(120, 255, 120))
	elif kind == Kind.COIN:
		GameSettings.add_score(COIN_POINTS)
		_show_popup("+%d" % COIN_POINTS, Color8(255, 220, 80))
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
