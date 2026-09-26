class_name Lasers
extends Node2D
## Raios dos canhões laser: saem da célula para fora da nave por
## LASER_DURATION segundos, acompanhando a nave, com dano contínuo.

## Célula do jogador (Vector2i) -> segundos restantes de raio.
var _beams := {}
var _player: Player
var _t := 0.0


func start(cell: Vector2i) -> void:
	_beams[cell] = Weapons.LASER_DURATION


func step(delta: float, player: Player, asteroids: Array[Asteroid], fx: Fx) -> void:
	_player = player
	_t += delta
	for cell in _beams.keys():
		_beams[cell] -= delta
		if _beams[cell] <= 0.0 or not player.alive or player.weapon_at(cell) != Weapons.LASER:
			_beams.erase(cell)
			continue
		var p0 := player.cell_global(cell)
		var p1 := p0 + player.barrel_dir(cell) * Weapons.LASER_LENGTH
		for a in asteroids:
			if a.hp > 0 and _beam_hits(a, p0, p1):
				a.apply_damage(Weapons.LASER_DPS * delta)
				if randf() < 0.25:
					fx.burst(Geometry2D.get_closest_point_to_segment(a.global_position, p0, p1),
						Weapons.color(Weapons.LASER).lightened(0.4), 1, 90.0)
	queue_redraw()


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
	var color := Weapons.color(Weapons.LASER)
	for cell in _beams:
		var left: float = _beams[cell]
		# Liga rápido, desliga suave e tremula um pouco.
		var fade := clampf((Weapons.LASER_DURATION - left) / 0.08, 0.0, 1.0) * clampf(left / 0.25, 0.0, 1.0)
		var w := Weapons.LASER_WIDTH * fade * (1.0 + 0.15 * sin(_t * 45.0))
		var p0 := _player.cell_global(cell)
		var p1 := p0 + _player.barrel_dir(cell) * Weapons.LASER_LENGTH
		draw_line(p0, p1, Color(color, 0.18 * fade), w * 3.5, true)
		draw_line(p0, p1, Color(color, 0.9 * fade), w, true)
		draw_line(p0, p1, Color(1, 0.9, 0.95, fade), w * 0.35, true)
		draw_circle(p0, w * 1.2, Color(1, 0.9, 0.95, fade))
