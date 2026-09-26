class_name Missiles
extends Node2D
## Mísseis do canhão bomba: voam devagar até o ponto mirado e explodem lá
## (ou antes, ao tocar um asteroide), causando dano em área.

const HIT_DIST := Hex.SIZE * 0.87 + 4.0

## {pos, vel, target, life}
var _items: Array[Dictionary] = []


func launch(origin: Vector2, target: Vector2, inherited_velocity: Vector2) -> void:
	var dir := (target - origin).normalized()
	if dir == Vector2.ZERO:
		dir = Vector2.RIGHT
	_items.append({
		"pos": origin,
		"vel": dir * Weapons.MISSILE_SPEED + inherited_velocity * 0.5,
		"target": target,
		"life": Weapons.MISSILE_LIFE,
	})


## Move os mísseis e aplica as explosões. Retorna onde houve explosão.
func step(delta: float, asteroids: Array[Asteroid], fx: Fx) -> PackedVector2Array:
	var blasts := PackedVector2Array()
	var color := Weapons.color(Weapons.BOMB)
	for m in _items.duplicate():
		m.pos += m.vel * delta
		m.life -= delta
		fx.burst(m.pos, color.lightened(0.3), 1, 25.0)
		if m.life <= 0.0 or m.pos.distance_to(m.target) < 10.0 or _touches_asteroid(m.pos, asteroids):
			_explode(m.pos, asteroids, fx)
			blasts.append(m.pos)
			_items.erase(m)
	queue_redraw()
	return blasts


func _touches_asteroid(p: Vector2, asteroids: Array[Asteroid]) -> bool:
	for a in asteroids:
		if a.hp > 0 and p.distance_to(a.global_position) < a.bound_radius + 4.0 and a.has_cell_near(p, HIT_DIST):
			return true
	return false


func _explode(at: Vector2, asteroids: Array[Asteroid], fx: Fx) -> void:
	for a in asteroids:
		if a.hp > 0 and _in_blast(a, at):
			a.apply_damage(Weapons.BLAST_DAMAGE)
	var color := Weapons.color(Weapons.BOMB)
	fx.burst(at, color, 40, 320.0)
	fx.burst(at, Color.WHITE, 12, 160.0)
	fx.ring(at, Weapons.BLAST_RADIUS, color)


func _in_blast(a: Asteroid, at: Vector2) -> bool:
	if at.distance_to(a.global_position) > Weapons.BLAST_RADIUS + a.bound_radius:
		return false
	for h in a.cells:
		if a.cell_global(h).distance_to(at) < Weapons.BLAST_RADIUS:
			return true
	return false


func _draw() -> void:
	var color := Weapons.color(Weapons.BOMB)
	for m in _items:
		var p: Vector2 = m.pos
		var dir: Vector2 = m.vel.normalized()
		draw_circle(p, 9.0, Color(color, 0.25))
		var body := PackedVector2Array([
			p + dir * 8.0,
			p + dir.rotated(2.4) * 6.0,
			p - dir * 3.0,
			p + dir.rotated(-2.4) * 6.0,
		])
		draw_colored_polygon(body, color.lightened(0.3))
		draw_circle(p, 2.0, Color.WHITE)
