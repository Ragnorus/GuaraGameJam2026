class_name TitleStorm
extends Control

const RAIN_COUNT := 180
const RAIN_COLOR := Color(0.68, 0.82, 1.0, 0.28)
const STORM_TINT := Color(0.02, 0.04, 0.09, 0.1)

var _rain_positions := PackedVector2Array()
var _rain_speeds := PackedFloat32Array()
var _lightning_points := PackedVector2Array()
var _branch_points := PackedVector2Array()
var _lightning_timer := 0.0
var _lightning_time := 0.0
var _lightning_duration := 0.42

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for i in RAIN_COUNT:
		_rain_positions.append(Vector2(randf_range(0.0, size.x), randf_range(0.0, size.y)))
		_rain_speeds.append(randf_range(420.0, 680.0))
	_lightning_timer = randf_range(1.8, 3.2)

func _process(delta: float) -> void:
	for i in RAIN_COUNT:
		var p := _rain_positions[i]
		p.x -= delta * 58.0
		p.y += delta * _rain_speeds[i]
		if p.y > size.y + 30.0:
			p.y = randf_range(-50.0, -5.0)
			p.x = randf_range(0.0, size.x)
		elif p.x < -30.0:
			p.x = size.x + 20.0
		_rain_positions[i] = p
	if _lightning_time > 0.0:
		_lightning_time = maxf(0.0, _lightning_time - delta)
	else:
		_lightning_timer -= delta
		if _lightning_timer <= 0.0:
			_start_lightning()
	queue_redraw()

func _start_lightning() -> void:
	_lightning_time = _lightning_duration
	_lightning_points.clear()
	_branch_points.clear()
	var side := randf_range(0.0, 1.0)
	var x := randf_range(size.x * 0.08, size.x * 0.3) \
			if side < 0.5 else randf_range(size.x * 0.7, size.x * 0.92)
	var y := -10.0
	_lightning_points.append(Vector2(x, y))
	while y < size.y * 0.43:
		y += randf_range(size.y * 0.035, size.y * 0.065)
		x += randf_range(-size.x * 0.035, size.x * 0.035)
		_lightning_points.append(Vector2(x, y))
	var fork_index := randi_range(2, maxi(2, _lightning_points.size() - 3))
	var fork_start := _lightning_points[fork_index]
	_branch_points.append(fork_start)
	for i in 4:
		fork_start += Vector2(randf_range(-size.x * 0.025, size.x * 0.025), size.y * 0.035)
		_branch_points.append(fork_start)
	_lightning_timer = randf_range(5.0, 9.0)

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), STORM_TINT)
	var rain := RAIN_COLOR
	for i in RAIN_COUNT:
		var p := _rain_positions[i]
		var length := 9.0 + (_rain_speeds[i] - 420.0) * 0.025
		draw_line(p, p + Vector2(-4.0, length), rain, 1.0, true)
	if _lightning_time <= 0.0:
		return
	var elapsed := _lightning_duration - _lightning_time
	var strength := 0.0
	if elapsed < 0.045:
		strength = 0.42
	elif elapsed < 0.11:
		strength = 0.07
	elif elapsed < 0.16:
		strength = 0.23
	elif elapsed < 0.24:
		strength = 0.04
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.72, 0.84, 1.0, strength))
	if _lightning_points.size() > 1:
		draw_polyline(_lightning_points, Color(0.42, 0.68, 1.0, 0.65), 8.0, true)
		draw_polyline(_lightning_points, Color(0.92, 0.97, 1.0, 0.95), 2.0, true)
	if _branch_points.size() > 1:
		draw_polyline(_branch_points, Color(0.65, 0.8, 1.0, 0.85), 1.5, true)
