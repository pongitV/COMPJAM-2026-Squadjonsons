class_name Player
extends HexBody
## Nave do jogador: um aglomerado de celulas conectadas a celula core.
## Cada celula e casco (Weapons.NONE) ou canhao comum (Weapons.COMMON); canhoes
## comuns em triangulo se fundem em shotgun, bomba ou laser (CannonGroups).
## O nucleo tambem e um canhao comum, mas nunca se funde.

signal core_destroyed

const CORE := Vector2i.ZERO
const ACCEL := 1100.0
const MAX_SPEED := 320.0
## Fracao da velocidade mantida apos 1 segundo (atrito).
const DAMPING := 0.25
## Giro (segurando "rotate") com inercia: velocidade maxima (rad/s) de uma
## nave pequena, aceleracao/frenagem (rad/s^2) e quao rapido a velocidade
## desejada cai perto da mira (1/s; ela desacelera suave ao chegar). Com
## TURN_RESPONSE * TURN_SPEED < TURN_ACCEL a nave nunca passa da mira.
const TURN_SPEED := 3.5
const TURN_ACCEL := 12.0
const TURN_RESPONSE := 3.0

## Azul dos detalhes da arte do nucleo (seta de giro, explosao, titulo).
const CORE_COLOR := Color("#3a7bff")
const HURT_COLOR := Color(1.0, 0.25, 0.2)
## Pisca-pisca do nucleo, para ele ficar sempre evidente: amarelo forte,
## piscadas por segundo e opacidade minima/maxima do preenchimento.
const CORE_BLINK_COLOR := Color(1.0, 0.92, 0.0)
const CORE_BLINK_RATE := 2.0
const CORE_BLINK_MIN := 0.1
const CORE_BLINK_MAX := 0.9

## Alvos sao recalculados a esta frequencia (nao precisa ser todo frame).
const RETARGET_INTERVAL := 0.1

var alive := true
## Posicao do mouse; a nave gira em direcao a ela segurando "rotate".
var aim := Vector2.RIGHT
## Chave do grupo (Vector3i) -> Asteroid mais proximo no alcance.
var _targets := {}
var _retarget_timer := 0.0
## Girando em direcao a mira (tecla segurada).
var turning := false
## Chave do grupo -> segundos ate aquele canhao poder atirar de novo.
var _cooldowns := {}

# Buffer reaproveitado a cada frame para desenhar os canhoes.
var _cannon_sprites := TriBatch.new()


func _init() -> void:
	cells[CORE] = Weapons.COMMON
	recompute_bounds()


func _fixed_cells() -> Dictionary:
	return {CORE: true}


## Toda mudanca de celulas termina aqui: canhoes que deixaram de existir
## perdem a recarga e o alvo.
func refresh_groups() -> void:
	super.refresh_groups()
	var keys := {}
	for g in groups:
		keys[g.key] = true
	for k in _cooldowns.keys():
		if not keys.has(k):
			_cooldowns.erase(k)
	for k in _targets.keys():
		if not keys.has(k):
			_targets.erase(k)


func step(delta: float) -> void:
	var input := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	# Naves maiores aceleram um pouco mais devagar.
	var mass_factor := 1.0 / sqrt(1.0 + cells.size() * 0.02)
	velocity += input * ACCEL * mass_factor * delta
	velocity *= pow(DAMPING, delta)
	velocity = velocity.limit_length(MAX_SPEED)
	position += velocity * delta

	# Segurando "rotate", a nave gira em torno do nucleo ate a frente
	# (eixo +X local) apontar para a mira: acelera, chega devagar e, ao soltar,
	# freia suave em vez de parar seco.
	turning = Input.is_action_pressed("rotate")
	var target_spin := 0.0
	if turning:
		var diff := wrapf((aim - global_position).angle() - rotation, -PI, PI)
		var top := TURN_SPEED * mass_factor
		target_spin = clampf(diff * TURN_RESPONSE, -top, top)
	angular_velocity = move_toward(angular_velocity, target_spin, TURN_ACCEL * mass_factor * delta)
	rotation += angular_velocity * delta

	for k in _cooldowns:
		_cooldowns[k] = maxf(_cooldowns[k] - delta, 0.0)
	if flash > 0.0:
		flash = maxf(flash - delta * 3.0, 0.0)
		refresh_colors()
	# Os canos acompanham a mira, entao redesenha todo frame.
	queue_redraw()


## Direcao global do cano: o laser aponta para fora da nave (do nucleo para
## o canhao, girando junto com ela); os demais apontam para o alvo, ou para
## fora quando sem alvo.
func barrel_dir(g: Dictionary) -> Vector2:
	var d := group_local(g).rotated(rotation)
	var speed := Weapons.config.projectile_speed(g.type)
	if speed > 0.0:
		var target := target_of(g)
		if target != null:
			d = _lead(group_global(g), target, speed) - group_global(g)
	return d.normalized() if d.length_squared() > 0.01 else Vector2.RIGHT.rotated(rotation)


## Ponta do cano (de onde saem tiros e o laser).
func muzzle(g: Dictionary) -> Vector2:
	return group_global(g) + barrel_dir(g) * muzzle_length(g)


## Alvo atual do canhao (null se nao houver).
func target_of(g: Dictionary) -> Asteroid:
	var a = _targets.get(g.key)
	if a == null or not is_instance_valid(a) or a.hp <= 0:
		return null
	return a


## Cada canhao escolhe o asteroide mais proximo DELE dentro do alcance.
## O laser so "tem alvo" quando algum asteroide cruza a linha do raio.
func update_targets(delta: float, asteroids: Array[Asteroid]) -> void:
	_retarget_timer -= delta
	if _retarget_timer > 0.0:
		return
	_retarget_timer = RETARGET_INTERVAL
	_targets.clear()
	for g in groups:
		var origin := group_global(g)
		var best: Asteroid = null
		var best_dist := Weapons.config.range_of(g.type)
		if g.type == Weapons.LASER:
			var tip := origin + barrel_dir(g) * best_dist
			for a in asteroids:
				if a.hp <= 0:
					continue
				var closest := Geometry2D.get_closest_point_to_segment(a.global_position, origin, tip)
				if closest.distance_to(a.global_position) < a.bound_radius:
					best = a
					break
		else:
			for a in asteroids:
				if a.hp <= 0:
					continue
				var dist := a.target_distance(origin)
				if dist < best_dist:
					best_dist = dist
					best = a
		if best != null:
			_targets[g.key] = best


## Dispara os canhoes prontos que tem alvo.
## Retorna uma lista de {type, key, origin, dir, target_pos}.
func fire() -> Array:
	if not alive:
		return []
	var shots := []
	for g in groups:
		if _cooldowns.get(g.key, 0.0) > 0.0:
			continue
		var target := target_of(g)
		if target == null:
			continue
		var w: int = g.type
		var origin := muzzle(g)
		_cooldowns[g.key] = Weapons.config.cooldown(w)
		var target_pos := target.aim_point(origin)
		if w != Weapons.LASER:
			target_pos = _lead(origin, target, Weapons.config.projectile_speed(w))
		shots.append({"type": w, "key": g.key, "origin": origin, "dir": barrel_dir(g), "target_pos": target_pos})
	return shots


## Onde o alvo vai estar quando o projetil chegar (mira a frente). Usa a
## velocidade relativa porque os projeteis herdam a velocidade da nave.
func _lead(origin: Vector2, target: Asteroid, speed: float) -> Vector2:
	var point := target.aim_point(origin)
	var t := origin.distance_to(point) / speed
	return point + (target.velocity - velocity) * t


## Onde um pedaco de minerio encaixaria no grid da nave, girado `turns`
## passos de 60 graus em relacao a ela. Procura perto da posicao atual do pedaco
## um lugar em que todas as celulas caibam e ao menos uma encoste na nave.
## Retorna {celula da nave: tipo}, ou {} se nao houver encaixe a menos de
## `snap_dist`.
func find_placement(piece: Ore, turns: int, snap_dist: float) -> Dictionary:
	if not alive or piece.cells.is_empty():
		return {}
	var keys := piece.cells.keys()
	var ref: Vector2i = keys[0]
	var ref_grid := global_to_grid(piece.cell_global(ref))
	var ref_rot := Hex.rotate(ref, turns)
	var base := Hex.from_pixel(ref_grid) - ref_rot
	var best := {}
	var best_dist := snap_dist
	for dq in range(-2, 3):
		for dr in range(maxi(-2, -dq - 2), mini(2, -dq + 2) + 1):
			var offset := base + Vector2i(dq, dr)
			var dist := Hex.to_pixel(ref_rot + offset).distance_to(ref_grid)
			if dist >= best_dist:
				continue
			var fits := true
			var touches := false
			for c in keys:
				var slot := Hex.rotate(c, turns) + offset
				if cells.has(slot):
					fits = false
					break
				touches = touches or _touches_ship(slot)
			if fits and touches:
				best_dist = dist
				best = {}
				for c in keys:
					best[Hex.rotate(c, turns) + offset] = piece.cells[c]
	return best


## Gruda um pedaco ja posicionado ({celula: tipo}, de find_placement).
## Os canhoes comuns se fundem sozinhos se formarem triangulos.
func attach_piece(placement: Dictionary) -> bool:
	if not alive or placement.is_empty():
		return false
	var touches := false
	for slot in placement:
		if cells.has(slot):
			return false
		touches = touches or _touches_ship(slot)
	if not touches:
		return false
	for slot in placement:
		cells[slot] = placement[slot]
	recompute_bounds()
	return true


## Destroi uma celula atingida. Retorna true se era o nucleo (fim de jogo).
## Chame settle_damage() depois da rodada de dano.
func destroy_cell(h: Vector2i) -> bool:
	cells.erase(h)
	if h == CORE:
		alive = false
		return true
	return false


## Fecha uma rodada de dano: partes que perderam a ligacao com o nucleo se
## soltam inteiras (com seus canhoes). Retorna [{celula: tipo}, ...] para
## o jogo transformar em pedacos flutuantes. Canhoes grandes que perderam
## celulas se desfazem (as que sobraram voltam a se fundir no que der).
func settle_damage() -> Array:
	var reached := {CORE: true}
	var queue: Array[Vector2i] = [CORE]
	while not queue.is_empty():
		var h: Vector2i = queue.pop_back()
		for d in Hex.DIRS:
			var n: Vector2i = h + d
			if cells.has(n) and not reached.has(n):
				reached[n] = true
				queue.append(n)
	var loose := cells.keys().filter(func(h): return not reached.has(h))
	var detached := []
	for group in Hex.components(loose):
		var piece := {}
		for h in group:
			piece[h] = cells[h]
		detached.append(piece)
	for h in loose:
		cells.erase(h)
	flash = 1.0
	recompute_bounds()
	return detached


## Nucleo destruido: a nave inteira explode. Retorna onde estavam as celulas.
func explode() -> PackedVector2Array:
	var lost := PackedVector2Array()
	for h in cells:
		lost.append(cell_global(h))
	cells.clear()
	_cooldowns.clear()
	alive = false
	recompute_bounds()
	core_destroyed.emit()
	return lost


## O espaco vazio `h` encosta em alguma celula da nave?
func _touches_ship(h: Vector2i) -> bool:
	for d in Hex.DIRS:
		if cells.has(h + d):
			return true
	return false


## Tinta das celulas: so o vermelho de dano (a arte ja tem as cores).
func cell_color(_h: Vector2i) -> Color:
	return Color.WHITE.lerp(HURT_COLOR, flash * 0.7)


func cell_art(h: Vector2i) -> int:
	return Art.CORE if h == CORE else cannon_art(h, Art.HULL)


func _draw() -> void:
	super._draw()
	_draw_cannons()
	if alive and cells.has(CORE):
		_draw_core_blink()
	if turning and alive:
		_draw_heading()


## Nucleo piscando em amarelo forte, por cima de tudo (arte e cano): no pico
## ele fica quase todo amarelo; no vale a arte aparece, com o contorno sempre
## aceso. Um anel de brilho se expande a cada piscada.
func _draw_core_blink() -> void:
	var t := Time.get_ticks_msec() / 1000.0 * CORE_BLINK_RATE
	# 0..1, com a subida rapida e a descida mais lenta (cara de alerta).
	var k := pow(0.5 + 0.5 * cos(TAU * t), 2.0)
	var c := cell_local(CORE)
	var hex := PackedVector2Array()
	for corner in Hex.corners():
		hex.append(c + corner)
	draw_colored_polygon(hex, Color(CORE_BLINK_COLOR, lerpf(CORE_BLINK_MIN, CORE_BLINK_MAX, k)))
	var outline := hex.duplicate()
	outline.append(hex[0])
	draw_polyline(outline, CORE_BLINK_COLOR.lerp(Color.WHITE, 0.4 * k), 3.0, true)
	# Anel: nasce no contorno no pico e se afasta sumindo.
	var ring := PackedVector2Array()
	for p in outline:
		ring.append(c + (p - c) * (1.1 + 0.6 * (1.0 - k)))
	draw_polyline(ring, Color(CORE_BLINK_COLOR, 0.9 * k), 2.5, true)


## Seta na frente da nave (eixo +X local) enquanto ela gira.
func _draw_heading() -> void:
	var tip := Vector2(bound_radius + 24.0, 0.0)
	var arrow := PackedVector2Array([tip, tip + Vector2(-18, -11), tip + Vector2(-12, 0), tip + Vector2(-18, 11)])
	draw_colored_polygon(arrow, Color(CORE_COLOR, 0.95))
	arrow.append(arrow[0])
	draw_polyline(arrow, Color.WHITE, 1.5, true)
	draw_dashed_line(Vector2(Hex.SIZE, 0), tip - Vector2(14, 0), Color(CORE_COLOR, 0.45), 2.0, 6.0)


## Canos apontando para o alvo; recarregando o canhao fica mais escuro.
func _draw_cannons() -> void:
	var dirs := {}
	var shades := {}
	for g in groups:
		dirs[g.key] = barrel_dir(g)
		var charged: float = 1.0 - _cooldowns.get(g.key, 0.0) / Weapons.config.cooldown(g.type)
		shades[g.key] = 0.6 + 0.4 * charged
	draw_barrels(_cannon_sprites, dirs, shades)
