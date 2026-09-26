class_name Lasers
extends Node2D
## Raios dos canhoes laser da nave: saem da ponta do cano para fora da nave
## por config.laser_duration segundos, acompanhando a nave, com dano continuo.

signal laser_started
signal laser_stopped

## Chave do grupo do canhao (Vector3i) -> segundos restantes de raio.
var _beams := {}
var _player: Player
var _t := 0.0


func start(key: Vector3i) -> void:
	var was_empty := _beams.is_empty()
	_beams[key] = Weapons.config.laser_duration
	if was_empty:
		laser_started.emit()


func step(delta: float, player: Player, asteroids: Array[Asteroid], fx: Fx) -> void:
	_player = player
	_t += delta
	var length := Weapons.config.range_of(Weapons.LASER)
	var dps := Weapons.config.damage(Weapons.LASER)
	for key in _beams.keys():
		_beams[key] -= delta
		# O laser some se o triangulo for desfeito (celula destruida).
		var g := player.group_by_key(key)
		if _beams[key] <= 0.0 or not player.alive or g.is_empty():
			_beams.erase(key)
			continue
		var p0 := player.muzzle(g)
		var p1 := p0 + player.barrel_dir(g) * length
		for a in asteroids:
			if a.hp > 0 and _beam_hits(a, p0, p1):
				a.apply_damage(dps * delta)
				if randf() < 0.25:
					fx.burst(Geometry2D.get_closest_point_to_segment(a.global_position, p0, p1),
						Weapons.color(Weapons.LASER).lightened(0.4), 1, 90.0)
	queue_redraw()

	if _beams.is_empty():
		laser_stopped.emit()


func _beam_hits(a: Asteroid, p0: Vector2, p1: Vector2) -> bool:
	var reach := a.bound_radius + Weapons.LASER_WIDTH
	if Geometry2D.get_closest_point_to_segment(a.global_position, p0, p1).distance_to(a.global_position) > reach:
		return false
	var hit_dist := Hex.SIZE * 0.87 + Weapons.LASER_WIDTH * 0.5
	for h in a.cells:
		var c := a.cell_global(h)
		if Geometry2D.get_closest_point_to_segment(c, p0, p1).distance_to(c) < hit_dist:
			return true
	return false


func _draw() -> void:
	if _player == null or _beams.is_empty():
		return
	for key in _beams:
		# O canhao pode ter sido desfeito depois do step deste frame.
		var g := _player.group_by_key(key)
		if g.is_empty():
			continue
		var p0 := _player.muzzle(g)
		var p1 := p0 + _player.barrel_dir(g) * Weapons.config.range_of(Weapons.LASER)
		draw_beam(self, p0, p1, Weapons.color(Weapons.LASER), _beams[key], Weapons.config.laser_duration, _t)


## Desenha um raio que liga rapido, desliga suave e tremula um pouco
## (usado tambem pelos lasers dos asteroides).
static func draw_beam(ci: CanvasItem, p0: Vector2, p1: Vector2, color: Color, left: float, duration: float, t: float) -> void:
	var fade := clampf((duration - left) / 0.08, 0.0, 1.0) * clampf(left / 0.25, 0.0, 1.0)
	var w := Weapons.LASER_WIDTH * fade * (1.0 + 0.15 * sin(t * 45.0))
	ci.draw_line(p0, p1, Color(color, 0.18 * fade), w * 3.5, true)
	ci.draw_line(p0, p1, Color(color, 0.9 * fade), w, true)
	ci.draw_line(p0, p1, Color(1, 0.9, 0.95, fade), w * 0.35, true)
	ci.draw_circle(p0, w * 1.2, Color(1, 0.9, 0.95, fade))
