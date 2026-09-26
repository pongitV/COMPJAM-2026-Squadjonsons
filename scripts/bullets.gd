class_name Bullets
extends Node2D
## Todos os projéteis ficam em arrays compactos e são desenhados numa
## única chamada — naves grandes disparam centenas por rajada.

const SPEED := 650.0
const LIFE := 1.1
const RADIUS := 2.5
const MAX_BULLETS := 4000
const HIT_DIST := Hex.SIZE * 0.87 + RADIUS
const COLOR := Color(1.0, 0.95, 0.6)

var _pos := PackedVector2Array()
var _vel := PackedVector2Array()
var _life := PackedFloat32Array()


func spawn(origin: Vector2, dir: Vector2, inherited_velocity: Vector2) -> void:
	if _pos.size() >= MAX_BULLETS:
		return
	_pos.append(origin)
	_vel.append(dir * SPEED + inherited_velocity)
	_life.append(LIFE)


## Move os projéteis e aplica acertos nos asteroides.
func step(delta: float, asteroids: Array[Asteroid]) -> void:
	var i := 0
	while i < _pos.size():
		var p := _pos[i] + _vel[i] * delta
		_pos[i] = p
		_life[i] -= delta
		var dead := _life[i] <= 0.0
		if not dead:
			for a in asteroids:
				if a.hp <= 0:
					continue
				var reach := a.bound_radius + RADIUS
				if p.distance_squared_to(a.global_position) < reach * reach and a.has_cell_near(p, HIT_DIST):
					a.hit()
					dead = true
					break
		if dead:
			var last := _pos.size() - 1
			_pos[i] = _pos[last]
			_vel[i] = _vel[last]
			_life[i] = _life[last]
			_pos.resize(last)
			_vel.resize(last)
			_life.resize(last)
		else:
			i += 1
	queue_redraw()


func _draw() -> void:
	if _pos.is_empty():
		return
	var segments := PackedVector2Array()
	for i in _pos.size():
		segments.append(_pos[i] - _vel[i].normalized() * 7.0)
		segments.append(_pos[i])
	draw_multiline(segments, COLOR, 2.5)
