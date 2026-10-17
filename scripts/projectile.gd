class_name Projectile
extends Area2D

const CHARACTER_FRAMES := preload("res://assets/character_frames.tres")
const OUTLINE_SHADER := preload("res://scripts/player_outline.gdshader")
const GOLD_OUTLINE_COLOR := Color(1.0, 0.92, 0.2, 1.0)


var velocity := Vector2.ZERO
var damage := 1
var target_group := "enemies"
var color := Color(0.4, 0.9, 1.0)
var radius := 8.0
var life := 3.0
var texture: Texture2D
var texture_scale := Vector2.ONE
var texture_outline_color := Color.TRANSPARENT
var coin_pop := false
var character_art := false
var sprite: AnimatedSprite2D

func _ready() -> void:
	collision_layer = 0
	collision_mask = 0xFFFFFFFF & ~4  # pass through floating platforms (main.gd PLATFORM_LAYER)
	var shape := CircleShape2D.new()
	shape.radius = radius
	var cs := CollisionShape2D.new()
	cs.shape = shape
	add_child(cs)
	body_entered.connect(_on_body_entered)
	if texture_outline_color.a > 0.0 and texture is AtlasTexture:
		var atlas_texture := texture as AtlasTexture
		var atlas_size := atlas_texture.atlas.get_size()
		var start := (atlas_texture.region.position + Vector2(0.5, 0.5)) / atlas_size
		var end := (atlas_texture.region.end - Vector2(0.5, 0.5)) / atlas_size
		var outline := ShaderMaterial.new()
		outline.shader = OUTLINE_SHADER
		outline.set_shader_parameter("frame_uv", Vector4(start.x, start.y, end.x, end.y))
		outline.set_shader_parameter("outline_color", texture_outline_color)
		material = outline

	if character_art and target_group != "player":
		sprite = AnimatedSprite2D.new()
		sprite.sprite_frames = CHARACTER_FRAMES
		sprite.scale = Vector2(0.5, 0.5)
		sprite.flip_h = velocity.x < 0.0
		add_child(sprite)
		sprite.play(&"projectile")

func _physics_process(delta: float) -> void:
	if sprite != null and velocity.x != 0.0:
		sprite.flip_h = velocity.x < 0.0
	position += velocity * delta
	life -= delta
	if life <= 0.0:
		queue_free()

func _draw() -> void:
	if texture != null:
		draw_set_transform(Vector2.ZERO, velocity.angle(), texture_scale)
		draw_texture(texture, -texture.get_size() / 2.0)
		return
	if sprite == null:
		draw_circle(Vector2.ZERO, radius, color)

func _on_body_entered(body: Node) -> void:
	if body.is_in_group(target_group) and body.has_method("take_damage"):
		body.take_damage(damage)
		_spawn_coin_pop()
		queue_free()
	elif body is StaticBody2D and not body.is_in_group("gates"):
		_spawn_coin_pop()
		queue_free()

func _spawn_coin_pop() -> void:
	if not coin_pop:
		return
	var pop := Label.new()
	pop.text = "$"
	pop.add_theme_font_size_override("font_size", 16)
	pop.add_theme_color_override("font_color", Color(1.0, 0.82, 0.25))
	pop.add_theme_color_override("font_outline_color", Color(0.08, 0.05, 0.02))
	pop.add_theme_constant_override("outline_size", 2)
	pop.z_index = 50
	get_parent().add_child(pop)
	pop.global_position = global_position + Vector2(-5.0, -12.0)
	var tween := pop.create_tween()
	tween.tween_property(pop, "position:y", pop.position.y - 8.0, 0.18)
	tween.parallel().tween_property(pop, "modulate:a", 0.0, 0.18)
	tween.tween_callback(pop.queue_free)
