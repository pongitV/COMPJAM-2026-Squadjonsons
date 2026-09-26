class_name Boss
extends Asteroid
## MEGATRON, o chefe da bandeira de chegada: um corpo enorme e alto de casco
## branco (como a nave), com o laser gigante saindo pela frente no meio e o
## nucleo logo atras dele. As outras armas (2 bombas no meio, 4 canhoes comuns
## no meio-termo e 2 shotguns nas pontas) sao torretas faceis de destruir.
## A luta tem 3 fases:
## 1. as torretas levam dano; o laser e o nucleo estao com escudo;
## 2. sem torretas, o escudo do laser cai e ele pode ser destruido;
## 3. sem o laser, o nucleo fica exposto; destrui-lo vence o jogo.
## Cada arma (e o nucleo) tem uma vida so para as celulas dela: zerou, ela
## sai inteira. O casco quebra como o da nave: cada celula tem vida propria e
## o que perder a ligacao com o nucleo se solta como um pedaco flutuante (com
## os canhoes que tiver), que a nave pode pegar. Entra pela direita e para
## perto da borda; depois patrulha para cima e para baixo e fica parado
## enquanto o laser gigante (ver EnemyShots) avisa e dispara reto para a
## esquerda, cortando a tela. Nao e empurrado nas batidas.
const NAME := "MEGATRON"
## Nucleo, logo atras do laser (a frente do chefe e a esquerda).
const CORE := Vector2i(0, 0)
## Corpo: oval alto com estes semieixos (em larguras de coluna e alturas de
## celula).
const HALF_WIDTH := 4.2
const HALF_HEIGHT := 10.4
enum Phase { TURRETS, LASER, CORE }
## Tinta das partes ainda protegidas (escudo) e contorno do escudo.
const SHIELDED := Color(0.45, 0.5, 0.62)
const SHIELD_EDGE := Color(0.45, 0.85, 1.0)
const HURT_COLOR := Color(1.0, 0.45, 0.4)
## Piscar ao acertar o casco (as armas piscam forte, 1.0).
const HULL_FLASH := 0.15

var enemy_config: EnemyConfig
## Partes com vida propria: {kind ("turret", "laser", "core"), cells, hp, max_hp}.
## As celulas de casco nao estao em nenhuma: tem vida por celula (cell_hp).
var parts: Array[Dictionary] = []
## Celula de casco -> vida restante.
var cell_hp := {}
## Pedacos que se soltaram desde a ultima leitura ({celula: canhao}); o jogo
## os transforma em pedacos flutuantes.
var detached: Array = []
## Celulas destruidas desde a ultima leitura: [posicao global, era canhao].
var broken: Array = []
## Tiros que bateram num escudo desde a ultima leitura (posicoes).
var pings: PackedVector2Array = []
## Ja chegou ao ponto de parada.
var arrived := false
## Meia largura do chefe inteiro (px), para posiciona-lo na tela.
var extent_x := 0.0
var _part_of := {}
## Vida somada de todas as partes no inicio (barra do HUD).
var _total_hp := 0.0
var _stop_x := 0.0
## Patrulha vertical: centro (y global), amplitude (px) e fase da ida e volta.
## `holding` = laser gigante avisando ou disparando (o jogo atualiza).
var holding := false
var _patrol_y := 0.0
var _patrol_amp := 0.0
var _patrol_t := 0.0
## Meia altura do chefe inteiro (px).
var extent_y := 0.0
var _t := 0.0


## Formato: oval alto, espelhado em cima e embaixo. No meio, o laser (triangulo
## de 10) saindo pela frente com o nucleo atras e uma bomba logo acima e outra
## logo abaixo; no meio-termo, os canhoes comuns (um na frente e outro atras de
## cada lado); nas pontas, os shotguns. Entre armas diferentes sempre ha casco.
static func layout() -> Dictionary:
	var shape := {}
	for q in range(-6, 7):
		for r in range(-16, 17):
			var x := q * 0.866 / HALF_WIDTH
			var y := (r + q * 0.5) / HALF_HEIGHT
			if x * x + y * y <= 1.0:
				shape[Vector2i(q, r)] = Weapons.NONE
	var cannons: Array[Vector2i] = CannonGroups.triangle(Vector2i(-1, 2), 4, true)
	var top: Array[Vector2i] = []
	top.append_array(CannonGroups.triangle(Vector2i(0, -3), 3, true))
	top.append_array(CannonGroups.triangle(Vector2i(0, -9), 2, true))
	top.append_array([Vector2i(-2, -6), Vector2i(2, -8)])
	for h in top:
		cannons.append(h)
		cannons.append(_mirror(h))
	for h in cannons:
		shape[h] = Weapons.COMMON
	return shape


## Espelha de cima para baixo mantendo a grade.
static func _mirror(h: Vector2i) -> Vector2i:
	return Vector2i(h.x, -h.y - h.x)


func setup_boss(cfg: EnemyConfig) -> void:
	enemy_config = cfg
	setup_shape(layout())
	immovable = true
	rotation = 0.0
	angular_velocity = 0.0
	base_color = Color.WHITE
	for g in groups:
		if g.type == Weapons.LASER:
			_add_part("laser", g.cells, cfg.boss_laser_hp)
		else:
			_add_part("turret", g.cells, cfg.boss_turret_hp * g.cells.size())
	var core: Array[Vector2i] = [CORE]
	_add_part("core", core, cfg.boss_core_hp)
	for h in cells:
		if not _part_of.has(h):
			cell_hp[h] = cfg.boss_hull_hp
		extent_x = maxf(extent_x, absf(cell_local(h).x))
		extent_y = maxf(extent_y, absf(cell_local(h).y))
	extent_x += Hex.SIZE
	extent_y += Hex.SIZE
	max_hp = ceili(cfg.boss_core_hp)
	hp = max_hp
	_update_tint()
	refresh_colors()
	recharge_impact()


func _add_part(kind: String, part_cells: Array, part_hp: float) -> void:
	var part := {"kind": kind, "cells": part_cells.duplicate(), "hp": part_hp, "max_hp": part_hp}
	_total_hp += part_hp
	parts.append(part)
	for h in part_cells:
		_part_of[h] = part


## Fase atual da luta (quem ainda esta de pe decide).
func phase() -> Phase:
	for part in parts:
		if part.kind == "turret":
			return Phase.TURRETS
	for part in parts:
		if part.kind == "laser":
			return Phase.LASER
	return Phase.CORE


func vulnerable(part: Dictionary) -> bool:
	match part.kind:
		"turret":
			return true
		"laser":
			return phase() == Phase.LASER
	return phase() == Phase.CORE


## Vida que falta do chefe inteiro (torretas, laser e nucleo), 0..1.
func health_ratio() -> float:
	var left := 0.0
	for part in parts:
		left += maxf(part.hp, 0.0)
	return clampf(left / maxf(_total_hp, 0.001), 0.0, 1.0)


## Posicao x (global) onde ele fica. O jogo atualiza todo frame (o zoom da
## camera muda com o tamanho da nave), e ele desliza ate la.
func set_stop_x(x: float) -> void:
	_stop_x = x


## Faixa da patrulha: centro (y global) e amplitude (px).
func set_patrol(center_y: float, amplitude: float) -> void:
	_patrol_y = center_y
	_patrol_amp = amplitude


func recharge_impact() -> void:
	impact_budget = enemy_config.boss_contact_cells if enemy_config != null else 0


func step(delta: float) -> void:
	_t += delta
	var old := position
	position.x = move_toward(position.x, _stop_x, enemy_config.boss_speed * delta)
	arrived = arrived or is_equal_approx(position.x, _stop_x)
	# Sobe e desce so depois de chegar e fora do laser gigante.
	if arrived and not holding:
		_patrol_t += delta * enemy_config.boss_patrol_speed
	position.y = _patrol_y + sin(_patrol_t) * _patrol_amp
	velocity = (position - old) / maxf(delta, 0.0001)
	if flash > 0.0:
		flash = maxf(flash - delta * 8.0, 0.0)
		_update_tint()
	queue_redraw()


## Os canhoes da nave miram na celula vulneravel mais perto deles.
func aim_point(from: Vector2) -> Vector2:
	var best := global_position
	var best_dist := INF
	for part in parts:
		if not vulnerable(part):
			continue
		for h in part.cells:
			var p := cell_global(h)
			var d := p.distance_squared_to(from)
			if d < best_dist:
				best_dist = d
				best = p
	return best


## Contra o chefe, o alcance conta ate a torreta mirada (nao ate a borda).
func target_distance(from: Vector2) -> float:
	return from.distance_to(aim_point(from)) - Hex.SIZE


## Casco branco e nucleo iguais aos da nave; canhoes com a arte de cada tipo.
func cell_art(h: Vector2i) -> int:
	return Art.CORE if h == CORE else cannon_art(h, Art.HULL)


## Partes protegidas ficam apagadas (escudo).
func cell_color(h: Vector2i) -> Color:
	var part = _part_of.get(h)
	if part != null and not vulnerable(part):
		return SHIELDED
	return Color.WHITE


## So pisca avermelhado ao levar dano (a arte ja tem as cores).
func _update_tint() -> void:
	self_modulate = Color.WHITE.lerp(HURT_COLOR, flash * 0.6)


## O laser aponta sempre reto para a esquerda; os outros, para a nave.
func barrel_dir(g: Dictionary) -> Vector2:
	if g.type == Weapons.LASER:
		return Vector2.LEFT
	return super.barrel_dir(g)


## Dano sem ponto definido: vai na parte vulneravel mais a frente.
func apply_damage(amount: float) -> void:
	var p := aim_point(global_position + Vector2.LEFT * 1000.0)
	damage_at(p, amount)


func damage_at(p: Vector2, amount: float) -> void:
	var h := find_cell_near(p, Hex.SIZE * 2.0)
	if h != NO_CELL:
		_damage_cell(h, amount, p)


## O raio acerta a primeira celula no caminho dele.
func damage_beam(p0: Vector2, p1: Vector2, amount: float) -> void:
	var dir := (p1 - p0).normalized()
	var reach := Hex.SIZE * 0.87 + Weapons.LASER_WIDTH * 0.5
	var best := NO_CELL
	var best_t := INF
	for h in cells:
		var c := cell_global(h)
		if Geometry2D.get_closest_point_to_segment(c, p0, p1).distance_to(c) >= reach:
			continue
		var t := (c - p0).dot(dir)
		if t < best_t:
			best_t = t
			best = h
	if best != NO_CELL:
		_damage_cell(best, amount, cell_global(best))


## A explosao danifica cada celula de casco dentro do raio e cada parte
## vulneravel uma vez.
func damage_area(center: Vector2, radius: float, amount: float) -> void:
	var hit := {}
	var hull: Array[Vector2i] = []
	for h in cells:
		if cell_global(h).distance_to(center) < radius:
			var part = _part_of.get(h)
			if part == null:
				hull.append(h)
			elif vulnerable(part):
				hit[part] = h
	if hit.is_empty() and hull.is_empty():
		pings.append(center)
	for part in hit:
		_damage_cell(hit[part], amount, center)
	for h in hull:
		_damage_cell(h, amount, center)


func _damage_cell(h: Vector2i, amount: float, at: Vector2) -> void:
	if not cells.has(h) or hp <= 0:
		return
	var part = _part_of.get(h)
	if part == null:
		# Casco: cada celula tem a sua vida e quebra sozinha.
		cell_hp[h] = cell_hp.get(h, enemy_config.boss_hull_hp) - amount
		# Piscar leve: sob fogo continuo o casco continua branco.
		flash = maxf(flash, HULL_FLASH)
		_update_tint()
		if cell_hp[h] <= 0.0:
			_remove([h])
		return
	if not vulnerable(part):
		# Escudo: o tiro so faz faisca.
		pings.append(at)
		return
	part.hp -= amount
	flash = 1.0
	_update_tint()
	if part.kind == "core":
		# A vida do nucleo e a vida do chefe: em 0 o jogo o destroi.
		hp = maxi(ceili(part.hp), 0)
		return
	if part.hp <= 0.0:
		parts.erase(part)
		_remove(part.cells)


## Tira celulas (destruidas); o que perder a ligacao com o nucleo se solta em
## pedacos (em `detached`). Uma arma que se solta, mesmo em parte, deixa de
## contar como parte do chefe. Quando a fase muda, o escudo da proxima parte
## cai (as cores mudam).
func _remove(keys: Array) -> void:
	for h in keys:
		if cells.has(h):
			broken.append([cell_global(h), cells[h] != Weapons.NONE])
			cells.erase(h)
		cell_hp.erase(h)
		_part_of.erase(h)
	var reached := {CORE: true}
	var queue: Array[Vector2i] = [CORE]
	while not queue.is_empty():
		var c: Vector2i = queue.pop_back()
		for d in Hex.DIRS:
			var n: Vector2i = c + d
			if cells.has(n) and not reached.has(n):
				reached[n] = true
				queue.append(n)
	var loose := cells.keys().filter(func(c: Vector2i) -> bool: return not reached.has(c))
	for group in Hex.components(loose):
		var piece := {}
		for c in group:
			piece[c] = cells[c]
			var part = _part_of.get(c)
			if part != null:
				_drop_part(part)
		detached.append(piece)
	for c in loose:
		cells.erase(c)
		cell_hp.erase(c)
	recompute_bounds()
	refresh_colors()


## A parte deixa de existir; celulas dela que ficaram presas viram casco.
func _drop_part(part: Dictionary) -> void:
	parts.erase(part)
	for c in part.cells:
		_part_of.erase(c)
		if cells.has(c):
			cell_hp[c] = enemy_config.boss_hull_hp


func _draw() -> void:
	super._draw()
	# Contorno pulsante nas partes protegidas por escudo.
	var pulse := 0.45 + 0.35 * sin(_t * 4.0)
	for part in parts:
		if vulnerable(part):
			continue
		for h in part.cells:
			var pts := PackedVector2Array()
			for corner in Hex.corners():
				pts.append(cell_local(h) + corner * 0.95)
			pts.append(pts[0])
			draw_polyline(pts, Color(SHIELD_EDGE, pulse), 1.5, true)
