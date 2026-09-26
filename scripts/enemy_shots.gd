class_name EnemyShots
extends Node2D
## Tiros dos canhoes dos asteroides contra a nave. Cada acerto destroi uma
## celula: projeteis (comum e shotgun) destroem a que tocam, a bomba destroi
## as celulas no raio da explosao e o laser destroi as que ficarem sob o raio
## por EnemyConfig.laser_cell_time. step() devolve as celulas atingidas; quem
## aplica o dano e o jogo. Os tiros inimigos tem cor propria e nao acertam
## asteroides.

const COLOR := Color(1.0, 0.35, 0.3)
const BULLET_RADIUS := 3.0
const HIT_DIST := Hex.SIZE * 0.87 + BULLET_RADIUS
const MISSILE_HIT_DIST := Hex.SIZE * 0.87 + 4.0

var config: EnemyConfig
## Projeteis: {pos, vel, life}
var _bullets: Array[Dictionary] = []
## Misseis: {pos, vel, target, life}
var _missiles: Array[Dictionary] = []
## Lasers: {source (Asteroid), key, dir, left, exposure: {celula: s}}
var _beams: Array[Dictionary] = []
var _t := 0.0


## Dispara o canhao `g` do asteroide `a` na nave. `progress` = 0..1 da corrida.
func fire(a: Asteroid, g: Dictionary, player: Player, progress: float) -> void:
	var origin := a.muzzle(g)
	var type: int = g.type
	var err := config.aim_error(progress)
	if type == Weapons.LASER:
		var beam_dir := (player.global_position - origin).normalized().rotated(randf_range(-err, err))
		_beams.append({"source": a, "key": g.key, "dir": beam_dir, "left": Weapons.config.laser_duration, "exposure": {}})
		return
	var speed := config.projectile_speed(type, progress)
	# Mira a frente da nave (onde ela vai estar quando o tiro chegar).
	var target := player.global_position + player.velocity * origin.distance_to(player.global_position) / speed
	var dir := (target - origin).normalized().rotated(randf_range(-err, err))
	var life := config.range_of(type) / speed * CannonConfig.PROJECTILE_OVERSHOOT
	match type:
		Weapons.COMMON:
			_bullets.append({"pos": origin, "vel": dir * speed, "life": life})
		Weapons.SHOTGUN:
			var pellets := config.shotgun_pellets
			for i in pellets:
				var t := float(i) / (pellets - 1) - 0.5 if pellets > 1 else 0.0
				var pellet_dir := dir.rotated(t * Weapons.config.shotgun_spread)
				_bullets.append({"pos": origin, "vel": pellet_dir * speed * randf_range(0.9, 1.1), "life": life})
		Weapons.BOMB:
			_missiles.append({"pos": origin, "vel": dir * speed, "target": origin + dir * origin.distance_to(target),
				"life": life + CannonConfig.MISSILE_EXTRA_LIFE})


## Move os tiros. Retorna as celulas da nave atingidas neste frame.
func step(delta: float, player: Player, fx: Fx) -> Array[Vector2i]:
	_t += delta
	var hits := {}
	_step_bullets(delta, player, hits)
	_step_missiles(delta, player, fx, hits)
	_step_beams(delta, player, hits)
	queue_redraw()
	var out: Array[Vector2i] = []
	out.assign(hits.keys())
	return out


func clear() -> void:
	_bullets.clear()
	_missiles.clear()
	_beams.clear()


func _step_bullets(delta: float, player: Player, hits: Dictionary) -> void:
	for b in _bullets.duplicate():
		b.pos += b.vel * delta
		b.life -= delta
		var dead: bool = b.life <= 0.0
		if not dead and player.alive and _near(player, b.pos):
			var cell := player.find_cell_near(b.pos, HIT_DIST)
			if cell != HexBody.NO_CELL:
				hits[cell] = true
				dead = true
		if dead:
			_bullets.erase(b)


func _step_missiles(delta: float, player: Player, fx: Fx, hits: Dictionary) -> void:
	for m in _missiles.duplicate():
		m.pos += m.vel * delta
		m.life -= delta
		fx.spark(m.pos, -m.vel * 0.2, Color(COLOR, 0.6), 0.3)
		var touched := player.alive and _near(player, m.pos) \
			and player.find_cell_near(m.pos, MISSILE_HIT_DIST) != HexBody.NO_CELL
		if m.life <= 0.0 or m.pos.distance_to(m.target) < 10.0 or touched:
			_explode(m.pos, player, fx, hits)
			_missiles.erase(m)


func _explode(at: Vector2, player: Player, fx: Fx, hits: Dictionary) -> void:
	var radius := config.bomb_radius
	if player.alive:
		for h in player.cells:
			if player.cell_global(h).distance_to(at) < radius:
				hits[h] = true
	fx.burst(at, COLOR, 24, 220.0)
	fx.ring(at, radius, COLOR)


func _step_beams(delta: float, player: Player, hits: Dictionary) -> void:
	var hit_dist := Hex.SIZE * 0.87 + Weapons.LASER_WIDTH * 0.5
	for beam in _beams.duplicate():
		beam.left -= delta
		var ends := _beam_ends(beam)
		if beam.left <= 0.0 or ends.is_empty():
			_beams.erase(beam)
			continue
		if not player.alive:
			continue
		var exposure: Dictionary = beam.exposure
		for h in player.cells:
			var c := player.cell_global(h)
			if Geometry2D.get_closest_point_to_segment(c, ends[0], ends[1]).distance_to(c) < hit_dist:
				exposure[h] = exposure.get(h, 0.0) + delta
				if exposure[h] >= config.laser_cell_time:
					hits[h] = true
					exposure.erase(h)


## [inicio, fim] do laser, ou [] se o canhao que o dispara sumiu.
func _beam_ends(beam: Dictionary) -> Array:
	var a = beam.source
	if not is_instance_valid(a) or a.hp <= 0:
		return []
	var g: Dictionary = a.group_by_key(beam.key)
	if g.is_empty():
		return []
	var p0: Vector2 = a.muzzle(g)
	return [p0, p0 + beam.dir * config.range_of(Weapons.LASER)]


func _near(player: Player, p: Vector2) -> bool:
	var reach := player.bound_radius + Hex.SIZE
	return p.distance_squared_to(player.global_position) < reach * reach


func _draw() -> void:
	for b in _bullets:
		var tail: Vector2 = b.pos - b.vel.normalized() * 8.0
		draw_line(tail, b.pos, COLOR, 3.0, true)
		draw_circle(b.pos, 2.0, Color(1, 0.85, 0.8))
	for m in _missiles:
		var p: Vector2 = m.pos
		var dir: Vector2 = m.vel.normalized()
		draw_circle(p, 8.0, Color(COLOR, 0.25))
		var body := PackedVector2Array([
			p + dir * 8.0,
			p + dir.rotated(2.4) * 6.0,
			p - dir * 3.0,
			p + dir.rotated(-2.4) * 6.0,
		])
		draw_colored_polygon(body, COLOR)
		draw_circle(p, 2.0, Color.WHITE)
	for beam in _beams:
		var ends := _beam_ends(beam)
		if not ends.is_empty():
			Lasers.draw_beam(self, ends[0], ends[1], COLOR, beam.left, Weapons.config.laser_duration, _t)
