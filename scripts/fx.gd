class_name Fx
extends Node2D
## Partículas simples de explosão / detritos.

const MAX_PARTICLES := 3000
const RING_TIME := 0.45

## {pos, radius, color, t (0..1)}
var _rings: Array[Dictionary] = []

var _pos := PackedVector2Array()
var _vel := PackedVector2Array()
var _life := PackedFloat32Array()
var _max_life := PackedFloat32Array()
var _color := PackedColorArray()


func burst(at: Vector2, color: Color, count: int, speed: float) -> void:
	for i in count:
		if _pos.size() >= MAX_PARTICLES:
			return
		var l := randf_range(0.3, 0.8)
		_pos.append(at)
		_vel.append(Vector2.from_angle(randf() * TAU) * randf_range(0.3, 1.0) * speed)
		_life.append(l)
		_max_life.append(l)
		_color.append(color)


## Anel de choque que se expande até `radius` (explosões).
func ring(at: Vector2, radius: float, color: Color) -> void:
	_rings.append({"pos": at, "radius": radius, "color": color, "t": 0.0})


func step(delta: float) -> void:
	for r in _rings.duplicate():
		r.t += delta / RING_TIME
		if r.t >= 1.0:
			_rings.erase(r)
	var i := 0
	while i < _pos.size():
		_life[i] -= delta
		if _life[i] <= 0.0:
			var last := _pos.size() - 1
			_pos[i] = _pos[last]
			_vel[i] = _vel[last]
			_life[i] = _life[last]
			_max_life[i] = _max_life[last]
			_color[i] = _color[last]
			_pos.resize(last)
			_vel.resize(last)
			_life.resize(last)
			_max_life.resize(last)
			_color.resize(last)
			continue
		_pos[i] += _vel[i] * delta
		_vel[i] *= pow(0.1, delta)
		i += 1
	queue_redraw()


func _draw() -> void:
	for r in _rings:
		var t: float = r.t
		var c: Color = r.color
		var radius: float = r.radius * (1.0 - pow(1.0 - t, 3.0))
		draw_circle(r.pos, radius, Color(c, 0.12 * (1.0 - t)))
		draw_arc(r.pos, radius, 0.0, TAU, 48, Color(c.lightened(0.4), 1.0 - t), 3.0 * (1.0 - t) + 1.0, true)
	for i in _pos.size():
		var t := _life[i] / _max_life[i]
		var c := _color[i]
		c.a = t
		var s := 2.0 + 3.0 * t
		draw_rect(Rect2(_pos[i] - Vector2(s, s) * 0.5, Vector2(s, s)), c)
