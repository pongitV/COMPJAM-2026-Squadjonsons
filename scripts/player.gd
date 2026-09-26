class_name Player
extends HexBody
## Nave do jogador: um aglomerado de celulas conectadas a celula core.
## Cada celula guarda o tipo de canhao que carrega (Weapons.NONE = casco).

signal core_destroyed

const CORE := Vector2i.ZERO
const ACCEL := 1100.0
const MAX_SPEED := 320.0
## Fracao da velocidade mantida apos 1 segundo (atrito).
const DAMPING := 0.25
## Velocidade de giro (rad/s) de uma nave pequena, segurando "rotate".
const TURN_SPEED := 3.5

const CORE_COLOR := Color(1.0, 0.85, 0.35)
const HURT_COLOR := Color(1.0, 0.25, 0.2)

## Alvos sao recalculados a esta frequencia (nao precisa ser todo frame).
const RETARGET_INTERVAL := 0.1

var alive := true
## Posicao do mouse; a nave gira em direcao a ela segurando "rotate".
var aim := Vector2.RIGHT
## Vector2i (celula com canhao) -> Asteroid mais proximo no alcance.
var _targets := {}
var _retarget_timer := 0.0
## Girando em direcao a mira (tecla segurada).
var turning := false
## Vector2i -> segundos ate o canhao daquela celula poder atirar de novo.
var _cooldowns := {}
## Celulas com canhao e contagem por tipo, atualizadas so quando a nave muda
## (tiro, desenho e HUD rodam todo frame e nao precisam varrer o casco).
var _cannon_cells: Array[Vector2i] = []
var _counts := {}

# Buffer reaproveitado a cada frame para desenhar os canhoes.
var _cannon_sprites := TriBatch.new()


func _init() -> void:
	cells[CORE] = Weapons.COMMON
	recompute_bounds()


## Toda mudanca de celulas ou canhoes termina aqui.
func recompute_bounds() -> void:
	super.recompute_bounds()
	_cannon_cells.clear()
	_counts = {Weapons.COMMON: 0, Weapons.SHOTGUN: 0, Weapons.LASER: 0, Weapons.BOMB: 0}
	for h in cells:
		var w: int = cells[h]
		if w != Weapons.NONE:
			_cannon_cells.append(h)
			_counts[w] += 1


func step(delta: float) -> void:
	var input := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	# Naves maiores aceleram um pouco mais devagar.
	var mass_factor := 1.0 / sqrt(1.0 + cells.size() * 0.02)
	velocity += input * ACCEL * mass_factor * delta
	velocity *= pow(DAMPING, delta)
	velocity = velocity.limit_length(MAX_SPEED)
	position += velocity * delta

	# Segurando "rotate", a nave gira em torno do nucleo ate a frente
	# (eixo +X local) apontar para a mira.
	turning = Input.is_action_pressed("rotate")
	if turning:
		var diff := wrapf((aim - global_position).angle() - rotation, -PI, PI)
		var max_step := TURN_SPEED * mass_factor * delta
		rotation += clampf(diff, -max_step, max_step)

	for h in _cooldowns:
		_cooldowns[h] = maxf(_cooldowns[h] - delta, 0.0)
	if flash > 0.0:
		flash = maxf(flash - delta * 3.0, 0.0)
		refresh_colors()
	# Os canos acompanham a mira, entao redesenha todo frame.
	queue_redraw()


func weapon_at(h: Vector2i) -> int:
	return cells.get(h, Weapons.NONE)


## Celula da camada mais externa (tem ao menos um vizinho vazio).
func is_outer(h: Vector2i) -> bool:
	for d in Hex.DIRS:
		if not cells.has(h + d):
			return true
	return false


## Canhao comum so funciona na camada mais externa.
func is_armed(h: Vector2i) -> bool:
	var w := weapon_at(h)
	return w != Weapons.NONE and (w != Weapons.COMMON or is_outer(h))


## Direcao global do cano: o laser aponta para fora da nave (gira junto
## com ela); os demais apontam para o alvo, ou para fora quando sem alvo.
func barrel_dir(h: Vector2i) -> Vector2:
	var d := cell_local(h).rotated(rotation)
	var w := weapon_at(h)
	if Weapons.PROJECTILE_SPEED.has(w):
		var target := target_of(h)
		if target != null:
			d = _lead(cell_global(h), target, Weapons.PROJECTILE_SPEED[w]) - cell_global(h)
	return d.normalized() if d.length_squared() > 0.01 else Vector2.RIGHT.rotated(rotation)


## Ponta do cano do canhao da celula (de onde saem tiros e o laser).
func muzzle(h: Vector2i) -> Vector2:
	return cell_global(h) + barrel_dir(h) * Art.muzzle_length(weapon_at(h))


## Alvo atual do canhao daquela celula (null se nao houver).
func target_of(h: Vector2i) -> Asteroid:
	var a = _targets.get(h)
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
	for h in _cannon_cells:
		var w: int = cells[h]
		var origin := cell_global(h)
		var best: Asteroid = null
		var best_dist: float = Weapons.RANGE[w]
		if w == Weapons.LASER:
			var tip := origin + barrel_dir(h) * Weapons.LASER_LENGTH
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
				var dist := origin.distance_to(a.global_position) - a.bound_radius
				if dist < best_dist:
					best_dist = dist
					best = a
		if best != null:
			_targets[h] = best


## Dispara os canhoes prontos que tem alvo.
## Retorna uma lista de {type, cell, origin, dir, target_pos}.
func fire() -> Array:
	if not alive:
		return []
	var shots := []
	for h in _cannon_cells:
		if not is_armed(h) or _cooldowns.get(h, 0.0) > 0.0:
			continue
		var target := target_of(h)
		if target == null:
			continue
		var w: int = cells[h]
		var origin := muzzle(h)
		_cooldowns[h] = Weapons.COOLDOWN[w]
		var target_pos := target.global_position
		if w != Weapons.LASER:
			target_pos = _lead(origin, target, Weapons.PROJECTILE_SPEED[w])
		shots.append({"type": w, "cell": h, "origin": origin, "dir": barrel_dir(h), "target_pos": target_pos})
	return shots


## Onde o alvo vai estar quando o projetil chegar (mira a frente). Usa a
## velocidade relativa porque os projeteis herdam a velocidade da nave.
func _lead(origin: Vector2, target: Asteroid, speed: float) -> Vector2:
	var t := origin.distance_to(target.global_position) / speed
	return target.global_position + (target.velocity - velocity) * t


## Onde um pedaco de minerio encaixaria no grid da nave, girado `turns`
## passos de 60 graus em relacao a ela. Procura perto da posicao atual do pedaco
## um lugar em que todas as celulas caibam e ao menos uma encoste na nave.
## Retorna {celula da nave: canhao}, ou {} se nao houver encaixe a menos de
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


## Gruda um pedaco ja posicionado ({celula: canhao}, de find_placement).
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
	_relocate_commons()
	recompute_bounds()
	return true


## Coloca um canhao comum numa celula de casco da borda, do lado da mira.
## Sem casco livre na borda, a nave ganha uma celula nova com o canhao.
func add_common_cannon() -> Vector2i:
	# Direcao da mira no espaco local da nave (que pode estar girada).
	var aim_dir := (aim - global_position).normalized().rotated(-rotation)
	var best := CORE
	var best_score := -INF
	for h in cells:
		if cells[h] != Weapons.NONE or not is_outer(h):
			continue
		var score := cell_local(h).normalized().dot(aim_dir)
		if score > best_score:
			best_score = score
			best = h
	if best_score == -INF:
		best = _nearest_free_slot(Hex.to_pixel(CORE) + aim_dir * bound_radius)
	cells[best] = Weapons.COMMON
	_cooldowns.erase(best)
	recompute_bounds()
	return best


## Quantidade de canhoes de cada tipo.
func weapon_counts() -> Dictionary:
	return _counts.duplicate()


## Destroi uma celula atingida por um asteroide. Retorna true se era o
## nucleo (fim de jogo). Chame settle_damage() depois da rodada de dano.
func destroy_cell(h: Vector2i) -> bool:
	_remove_cell(h)
	if h == CORE:
		alive = false
		return true
	return false


## Fecha uma rodada de dano: partes que perderam a ligacao com o nucleo se
## soltam inteiras (com seus canhoes). Retorna [{celula: canhao}, ...] para
## o jogo transformar em pedacos flutuantes.
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
		_remove_cell(h)
	_relocate_commons()
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


## Espaco vazio adjacente a nave mais proximo de um ponto (espaco da grade).
func _nearest_free_slot(grid_p: Vector2) -> Vector2i:
	var best := CORE
	var best_dist := INF
	for h in cells:
		for d in Hex.DIRS:
			var n: Vector2i = h + d
			if cells.has(n):
				continue
			var dist := Hex.to_pixel(n).distance_squared_to(grid_p)
			if dist < best_dist:
				best_dist = dist
				best = n
	return best


## Canhoes comuns que ficaram no meio da nave vao para o casco livre mais
## proximo da borda. Sem casco livre na borda, ficam inativos ate abrir espaco.
func _relocate_commons() -> void:
	for h in cells.keys():
		if cells[h] != Weapons.COMMON or is_outer(h):
			continue
		var target: Vector2i = h
		var best_dist := 1 << 30
		for c in cells:
			if cells[c] != Weapons.NONE or not is_outer(c):
				continue
			var dist := Hex.distance(h, c)
			if dist < best_dist:
				best_dist = dist
				target = c
		if target != h:
			cells[target] = Weapons.COMMON
			cells[h] = Weapons.NONE
			_cooldowns[target] = _cooldowns.get(h, 0.0)
			_cooldowns.erase(h)


func _remove_cell(h: Vector2i) -> void:
	cells.erase(h)
	_cooldowns.erase(h)


## O nucleo usa a arte cinza com centro preto, tingida de dourado.
func cell_color(h: Vector2i) -> Color:
	var base := CORE_COLOR.lightened(0.3) if h == CORE else Color.WHITE
	return base.lerp(HURT_COLOR, flash * 0.7)


func cell_art(h: Vector2i) -> int:
	return Art.CORE if h == CORE else Art.for_weapon(cells[h])


func _draw() -> void:
	super._draw()
	_draw_cannons()
	if turning and alive:
		_draw_heading()


## Seta na frente da nave (eixo +X local) enquanto ela gira.
func _draw_heading() -> void:
	var tip := Vector2(bound_radius + 24.0, 0.0)
	var arrow := PackedVector2Array([tip, tip + Vector2(-18, -11), tip + Vector2(-12, 0), tip + Vector2(-18, 11)])
	draw_colored_polygon(arrow, Color(CORE_COLOR, 0.95))
	arrow.append(arrow[0])
	draw_polyline(arrow, Color.WHITE, 1.5, true)
	draw_dashed_line(Vector2(Hex.SIZE, 0), tip - Vector2(14, 0), Color(CORE_COLOR, 0.45), 2.0, 6.0)


## Canhoes: a arte de cada um, girada em torno da base (no centro da celula)
## para o cano apontar para o alvo. Todos numa chamada so (atlas). Recarregando
## o canhao fica mais escuro; comum preso no meio da nave fica bem apagado.
func _draw_cannons() -> void:
	_cannon_sprites.clear()
	var s := Art.scale()
	for h in _cannon_cells:
		var w: int = cells[h]
		var size := Art.cannon_size(w)
		var pivot := Vector2(size.x * 0.5, Art.CANNON_PIVOT_Y * s)
		# _draw usa o espaco local da nave, entao desfaz a rotacao da direcao global.
		# Na arte o cano aponta para baixo (+Y).
		var angle := barrel_dir(h).rotated(-rotation).angle() - PI / 2.0
		var c := cell_local(h)
		var corners := [
			c + (-pivot).rotated(angle),
			c + (Vector2(size.x, 0.0) - pivot).rotated(angle),
			c + (size - pivot).rotated(angle),
			c + (Vector2(0.0, size.y) - pivot).rotated(angle),
		]
		var charged: float = 1.0 - _cooldowns.get(h, 0.0) / Weapons.COOLDOWN[w]
		var shade := (0.6 + 0.4 * charged) if is_armed(h) else 0.35
		_cannon_sprites.add_quad(corners, Art.cannon_uv(w), Color(shade, shade, shade))
	_cannon_sprites.draw(get_canvas_item(), Art.cannon_atlas())
