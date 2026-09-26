class_name EnemyShots
extends Node2D
## Tiros dos canhoes dos asteroides contra a nave. Acertam a nave e os
## pedacos de minerio (nao os asteroides). Cada acerto destroi uma celula:
## projeteis (comum e shotgun) destroem a que tocam, a bomba destroi as
## celulas no raio da explosao e o laser destroi as que ficarem sob o raio por
## EnemyConfig.laser_cell_time. step() devolve as celulas atingidas de cada
## corpo; quem aplica o dano e o jogo.

const COLOR := Color(1.0, 0.35, 0.3)
const BULLET_RADIUS := 3.0
const HIT_DIST := Hex.SIZE * 0.87 + BULLET_RADIUS
const MISSILE_HIT_DIST := Hex.SIZE * 0.87 + 4.0
## Tiro que erra de proposito: passa esta distancia alem da borda da nave.
const MISS_DISTANCE := 70.0

var config: EnemyConfig
## Projeteis: {pos, vel, life, harmless}
var _bullets: Array[Dictionary] = []
## Misseis: {pos, vel, target, life, harmless}
var _missiles: Array[Dictionary] = []
## Lasers: {source (Asteroid), key, dir, left, exposure: {corpo: {celula: s}}, harmless}
## e, no laser grande do chefe, tambem {warn, width, length, cell_time}: ele
## so dispara depois de `warn` segundos mostrando a linha por onde vai passar.
## (harmless = tiro de mentira do tutorial: passa ao lado e nao acerta nada)
var _beams: Array[Dictionary] = []
var _t := 0.0


## Dispara o canhao `g` do asteroide `a` na nave. `progress` = 0..1 da corrida.
## `miss`: mira ao lado da nave e o tiro nao acerta nada (inimigo do tutorial).
func fire(a: Asteroid, g: Dictionary, player: Player, progress: float, miss: bool = false) -> void:
	var origin := a.muzzle(g)
	var type: int = g.type
	var err := 0.0 if miss else config.aim_error(progress)
	var aim := player.global_position
	if miss:
		var side := (aim - origin).normalized().orthogonal() * (1.0 if randf() < 0.5 else -1.0)
		aim += side * (player.bound_radius + MISS_DISTANCE)
	if type == Weapons.LASER:
		var beam_dir := (aim - origin).normalized().rotated(randf_range(-err, err))
		var beam := {"source": a, "key": g.key, "dir": beam_dir, "left": Weapons.config.laser_duration,
			"exposure": {}, "harmless": miss}
		if a is Boss:
			# Laser grande do chefe: reto para a esquerda (corta a tela no
			# meio), com aviso antes, mais longo e bem mais grosso.
			beam.dir = a.barrel_dir(g)
			beam.left = config.boss_laser_duration
			beam.duration = config.boss_laser_duration
			beam.warn = config.boss_laser_warning
			beam.width = Weapons.LASER_WIDTH * config.boss_laser_width
			beam.length = config.boss_laser_length
			beam.cell_time = config.boss_laser_cell_time
		_beams.append(beam)
		return
	var speed := config.projectile_speed(type, progress)
	# Mira a frente da nave (onde ela vai estar quando o tiro chegar).
	var target := aim + player.velocity * origin.distance_to(aim) / speed
	var dir := (target - origin).normalized().rotated(randf_range(-err, err))
	var shot_range := config.boss_shot_range if a is Boss else config.range_of(type)
	var life := shot_range / speed * CannonConfig.PROJECTILE_OVERSHOOT
	match type:
		Weapons.COMMON:
			_bullets.append({"pos": origin, "vel": dir * speed, "life": life, "harmless": miss})
		Weapons.SHOTGUN:
			var pellets := config.shotgun_pellets
			for i in pellets:
				var t := float(i) / (pellets - 1) - 0.5 if pellets > 1 else 0.0
				var pellet_dir := dir.rotated(t * Weapons.config.shotgun_spread)
				_bullets.append({"pos": origin, "vel": pellet_dir * speed * randf_range(0.9, 1.1), "life": life,
					"harmless": miss})
		Weapons.BOMB:
			_missiles.append({"pos": origin, "vel": dir * speed, "target": origin + dir * origin.distance_to(target),
				"life": life + CannonConfig.MISSILE_EXTRA_LIFE, "harmless": miss})


## Move os tiros contra os `targets` (a nave, se viva, e os minerios).
## Retorna {corpo: {celula: true}} com as celulas atingidas neste frame.
func step(delta: float, targets: Array, fx: Fx) -> Dictionary:
	_t += delta
	var hits := {}
	_step_bullets(delta, targets, hits)
	_step_missiles(delta, targets, fx, hits)
	_step_beams(delta, targets, hits)
	queue_redraw()
	return hits


## O laser gigante do chefe `boss` esta avisando ou disparando?
func boss_laser_active(boss: Asteroid) -> bool:
	for beam in _beams:
		if beam.source == boss and beam.has("warn"):
			return true
	return false


func clear() -> void:
	_bullets.clear()
	_missiles.clear()
	_beams.clear()


func _step_bullets(delta: float, targets: Array, hits: Dictionary) -> void:
	for b in _bullets.duplicate():
		b.pos += b.vel * delta
		b.life -= delta
		var dead: bool = b.life <= 0.0
		if not dead and not b.harmless:
			for body: HexBody in targets:
				if not _near(body, b.pos):
					continue
				var cell := body.find_cell_near(b.pos, HIT_DIST)
				if cell != HexBody.NO_CELL:
					_hit(hits, body, cell)
					dead = true
					break
		if dead:
			_bullets.erase(b)


func _step_missiles(delta: float, targets: Array, fx: Fx, hits: Dictionary) -> void:
	for m in _missiles.duplicate():
		m.pos += m.vel * delta
		m.life -= delta
		fx.spark(m.pos, -m.vel * 0.2, Color(COLOR, 0.6), 0.3)
		var touched := false
		var hit_targets: Array = [] if m.harmless else targets
		for body: HexBody in hit_targets:
			if _near(body, m.pos) and body.find_cell_near(m.pos, MISSILE_HIT_DIST) != HexBody.NO_CELL:
				touched = true
				break
		if m.life <= 0.0 or m.pos.distance_to(m.target) < 10.0 or touched:
			_explode(m.pos, hit_targets, fx, hits)
			_missiles.erase(m)


func _explode(at: Vector2, targets: Array, fx: Fx, hits: Dictionary) -> void:
	var radius := config.bomb_radius
	for body: HexBody in targets:
		if at.distance_to(body.global_position) > radius + body.bound_radius:
			continue
		for h in body.cells:
			if body.cell_global(h).distance_to(at) < radius:
				_hit(hits, body, h)
	fx.burst(at, COLOR, 24, 220.0)
	fx.ring(at, radius, COLOR)


func _step_beams(delta: float, targets: Array, hits: Dictionary) -> void:
	for beam in _beams.duplicate():
		var ends := _beam_ends(beam)
		if ends.is_empty():
			_beams.erase(beam)
			continue
		# Aviso do laser do chefe: so a linha, ainda sem dano.
		if beam.get("warn", 0.0) > 0.0:
			beam.warn -= delta
			continue
		beam.left -= delta
		if beam.left <= 0.0:
			_beams.erase(beam)
			continue
		if beam.harmless:
			continue
		var hit_dist: float = Hex.SIZE * 0.87 + beam.get("width", Weapons.LASER_WIDTH) * 0.5
		var cell_time: float = beam.get("cell_time", config.laser_cell_time)
		var exposure: Dictionary = beam.exposure
		for body: HexBody in targets:
			var closest := Geometry2D.get_closest_point_to_segment(body.global_position, ends[0], ends[1])
			if closest.distance_to(body.global_position) > body.bound_radius + hit_dist:
				continue
			var times: Dictionary = exposure.get_or_add(body, {})
			for h in body.cells:
				var c := body.cell_global(h)
				if Geometry2D.get_closest_point_to_segment(c, ends[0], ends[1]).distance_to(c) < hit_dist:
					times[h] = times.get(h, 0.0) + delta
					if times[h] >= cell_time:
						_hit(hits, body, h)
						times.erase(h)


static func _hit(hits: Dictionary, body: HexBody, cell: Vector2i) -> void:
	var cells: Dictionary = hits.get_or_add(body, {})
	cells[cell] = true


## [inicio, fim] do laser, ou [] se o canhao que o dispara sumiu.
func _beam_ends(beam: Dictionary) -> Array:
	var a = beam.source
	if not is_instance_valid(a) or a.hp <= 0:
		return []
	var g: Dictionary = a.group_by_key(beam.key)
	if g.is_empty():
		return []
	var p0: Vector2 = a.muzzle(g)
	return [p0, p0 + beam.dir * beam.get("length", config.range_of(Weapons.LASER))]


func _near(body: HexBody, p: Vector2) -> bool:
	var reach := body.bound_radius + Hex.SIZE
	return p.distance_squared_to(body.global_position) < reach * reach


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
		if ends.is_empty():
			continue
		var warn: float = beam.get("warn", 0.0)
		if warn > 0.0:
			_draw_warning(ends[0], ends[1], warn, beam.get("width", Weapons.LASER_WIDTH))
		else:
			Lasers.draw_beam(self, ends[0], ends[1], COLOR, beam.left,
				beam.get("duration", Weapons.config.laser_duration), _t, beam.get("width", Weapons.LASER_WIDTH))


## Aviso do laser grande: linha fina piscando cada vez mais rapido no caminho
## do raio e um brilho crescendo na ponta do cano.
func _draw_warning(p0: Vector2, p1: Vector2, left: float, width: float) -> void:
	var k := 1.0 - clampf(left / config.boss_laser_warning, 0.0, 1.0)
	var blink := 0.5 + 0.5 * sin(_t * (10.0 + 30.0 * k))
	draw_line(p0, p1, Color(COLOR, 0.08 + 0.1 * k), width * (0.6 + k), true)
	draw_line(p0, p1, Color(1.0, 0.8, 0.75, 0.25 + 0.55 * blink), 1.5, true)
	draw_circle(p0, 4.0 + width * 0.6 * k, Color(1.0, 0.85, 0.8, 0.4 + 0.5 * k))
