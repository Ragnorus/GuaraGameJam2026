class_name ComicBox
extends PanelContainer

# Comic-book caption box for general game messages (stage titles, boss intros, victory, death).
# Pinned to the top-right of the HUD; setting `text` pops it in, an empty string hides it.

const FILL := Color8(255, 222, 74)
const INK := Color8(8, 13, 10)

var text := "":
	set = set_text
var _label: Label
var _tween: Tween

func _init() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = FILL
	style.set_border_width_all(4)
	style.border_color = INK
	style.set_corner_radius_all(3)
	style.skew = Vector2(-0.12, 0.0)
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.85)
	style.shadow_size = 1
	style.shadow_offset = Vector2(7, 7)
	style.content_margin_left = 22
	style.content_margin_right = 22
	style.content_margin_top = 10
	style.content_margin_bottom = 12
	add_theme_stylebox_override("panel", style)
	_label = Label.new()
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.add_theme_font_size_override("font_size", 22)
	_label.add_theme_color_override("font_color", INK)
	_label.add_theme_color_override("font_outline_color", Color.WHITE)
	_label.add_theme_constant_override("outline_size", 3)
	_label.add_theme_constant_override("line_spacing", 2)
	add_child(_label)
	# Anchored to the top-right corner, growing left/down below the score readout.
	set_anchors_preset(Control.PRESET_TOP_RIGHT)
	grow_horizontal = Control.GROW_DIRECTION_BEGIN
	offset_right = -24.0
	offset_left = -24.0
	offset_top = 72.0
	offset_bottom = 72.0
	rotation_degrees = -2.0
	visible = false

func set_text(value: String) -> void:
	text = value
	if _label == null:
		return
	_label.text = value.to_upper()
	visible = value != ""
	# Collapse to zero size; the minimum size then grows the box leftward from the right edge.
	offset_left = offset_right
	offset_bottom = offset_top
	if visible:
		_pop.call_deferred()

func _pop() -> void:
	pivot_offset = Vector2(size.x, 0.0)
	if _tween:
		_tween.kill()
	scale = Vector2(0.6, 0.6)
	_tween = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_tween.tween_property(self, "scale", Vector2.ONE, 0.22)
