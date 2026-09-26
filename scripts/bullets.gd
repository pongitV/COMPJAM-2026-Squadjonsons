class_name Bullets
extends Node2D
## Projeteis simples (canhao comum e shotgun). Ficam em arrays compactos e
## sao desenhados numa unica chamada: naves grandes disparam muitos por vez.

const RADIUS := 2.5
const MAX_BULLETS := 4000
const HIT_DIST := Hex.SIZE * 0.87 + RADIUS

var _pos := PackedVector2Array()
var _vel := PackedVector2Array()
var _life := PackedFloat32Array()
var _damage := PackedFloat32Array()
var _color := PackedColorArray()


func spawn(origin: Vector2, velocity: Vector2, life: float, damage: float, color: Color) -> void:
	if _pos.size() >= MAX_BULLETS:
		return
	_pos.append(origin)
	_vel.append(velocity)
	_life.append(life)
	_damage.append(damage)
	_color.append(color)


## Move os projeteis e aplica acertos nos asteroides.
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
					a.damage_at(p, _damage[i])
					dead = true
					break
		if dead:
			var last := _pos.size() - 1
			_pos[i] = _pos[last]
			_vel[i] = _vel[last]
			_life[i] = _life[last]
			_damage[i] = _damage[last]
			_color[i] = _color[last]
			_pos.resize(last)
			_vel.resize(last)
			_life.resize(last)
			_damage.resize(last)
			_color.resize(last)
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
	draw_multiline_colors(segments, _color, 2.5)
