class_name Player
extends HexBody
## Nave do jogador: um aglomerado de células conectadas à célula core.
## Cada célula guarda o tipo de canhão que carrega (Weapons.NONE = casco).

signal core_destroyed

const CORE := Vector2i.ZERO
const ACCEL := 1100.0
const MAX_SPEED := 320.0
## Fração da velocidade mantida após 1 segundo (atrito).
const DAMPING := 0.25
## Velocidade de giro (rad/s) de uma nave pequena, segurando "rotate".
const TURN_SPEED := 3.5

const CORE_COLOR := Color(1.0, 0.85, 0.35)
const HURT_COLOR := Color(1.0, 0.25, 0.2)
const SOCKET_COLOR := Color(0.02, 0.04, 0.08)

var alive := true
## Ponto global para onde os canhões miram (atualizado pelo jogo).
var aim := Vector2.RIGHT
## Girando em direção à mira (tecla segurada).
var turning := false
## Vector2i -> segundos até o canhão daquela célula poder atirar de novo.
var _cooldowns := {}
## Células com canhão e contagem por tipo, atualizadas só quando a nave muda
## (tiro, desenho e HUD rodam todo frame e não precisam varrer o casco).
var _cannon_cells: Array[Vector2i] = []
var _counts := {}

# Buffers reaproveitados a cada frame para desenhar os canhões.
var _sockets := TriBatch.new()
var _glows := TriBatch.new()
var _barrels_dark := PackedVector2Array()
var _barrels_lit := PackedVector2Array()
var _barrel_colors := PackedColorArray()


func _init() -> void:
	cells[CORE] = Weapons.COMMON
	recompute_bounds()


## Toda mudança de células ou canhões termina aqui.
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

	# Segurando "rotate", a nave gira em torno do núcleo até a frente
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
	# Os canos acompanham a mira, então redesenha todo frame.
	queue_redraw()


func weapon_at(h: Vector2i) -> int:
	return cells.get(h, Weapons.NONE)


## Célula da camada mais externa (tem ao menos um vizinho vazio).
func is_outer(h: Vector2i) -> bool:
	for d in Hex.DIRS:
		if not cells.has(h + d):
			return true
	return false


## Canhão comum só funciona na camada mais externa.
func is_armed(h: Vector2i) -> bool:
	var w := weapon_at(h)
	return w != Weapons.NONE and (w != Weapons.COMMON or is_outer(h))


## Direção global do cano: o laser aponta para fora da nave (gira junto
## com ela), os demais para a mira.
func barrel_dir(h: Vector2i) -> Vector2:
	var d: Vector2
	if weapon_at(h) == Weapons.LASER:
		d = cell_local(h).rotated(rotation)
	else:
		d = aim - cell_global(h)
	return d.normalized() if d.length_squared() > 0.01 else Vector2.RIGHT.rotated(rotation)


## Dispara todos os canhões prontos.
## Retorna uma lista de {type, cell, origin, dir}; o jogo cria os projéteis.
func fire() -> Array:
	if not alive:
		return []
	var shots := []
	for h in _cannon_cells:
		if not is_armed(h) or _cooldowns.get(h, 0.0) > 0.0:
			continue
		var w: int = cells[h]
		_cooldowns[h] = Weapons.COOLDOWN[w]
		shots.append({"type": w, "cell": h, "origin": cell_global(h), "dir": barrel_dir(h)})
	return shots


## Transforma um minério que tocou a nave em uma nova célula (com o canhão
## do minério, se houver), no espaço livre mais próximo do ponto de contato.
func absorb_at(global_p: Vector2, weapon: int = Weapons.NONE) -> Vector2i:
	return absorb_many([[global_p, weapon]])[0]


## Absorve vários minérios de uma vez: [[posição global, canhão], ...].
## Reorganiza os canhões e recalcula o raio uma vez só no final, para uma
## chuva de minérios não varrer a nave inteira para cada um.
func absorb_many(items: Array) -> Array[Vector2i]:
	var added: Array[Vector2i] = []
	for item in items:
		var h := _free_slot_near(global_to_grid(item[0]))
		cells[h] = item[1]
		added.append(h)
	_relocate_commons()
	recompute_bounds()
	return added


## Coloca um canhão comum numa célula de casco da borda, do lado da mira.
## Sem casco livre na borda, a nave ganha uma célula nova com o canhão.
func add_common_cannon() -> Vector2i:
	# Direção da mira no espaço local da nave (que pode estar girada).
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


## Quantidade de canhões de cada tipo.
func weapon_counts() -> Dictionary:
	return _counts.duplicate()


## Remove `amount` células (as mais distantes do core primeiro).
## Se não houver células suficientes, o core é destruído.
## Retorna as posições globais das células perdidas (para efeitos).
func take_damage(amount: int) -> PackedVector2Array:
	var lost := PackedVector2Array()
	var others := cells.keys().filter(func(h): return h != CORE)
	if amount >= others.size():
		for h in cells:
			lost.append(cell_global(h))
		cells.clear()
		_cooldowns.clear()
		alive = false
		recompute_bounds()
		core_destroyed.emit()
		return lost

	var ranked := others.map(func(h): return [Hex.distance(h, CORE) + randf() * 0.9, h])
	ranked.sort_custom(func(a, b): return a[0] > b[0])
	for i in amount:
		var h: Vector2i = ranked[i][1]
		lost.append(cell_global(h))
		_remove_cell(h)
	lost.append_array(_prune_disconnected())
	_relocate_commons()
	flash = 1.0
	recompute_bounds()
	return lost


## Espaço vazio adjacente à nave mais próximo de um ponto (espaço da grade).
## O minério encosta na borda, então basta olhar os hexágonos em volta do
## ponto de contato; a busca na nave inteira fica só de reserva.
func _free_slot_near(grid_p: Vector2) -> Vector2i:
	const SEARCH_RADIUS := 3
	var start := Hex.from_pixel(grid_p)
	var best := start
	var best_dist := INF
	for dq in range(-SEARCH_RADIUS, SEARCH_RADIUS + 1):
		for dr in range(maxi(-SEARCH_RADIUS, -dq - SEARCH_RADIUS), mini(SEARCH_RADIUS, -dq + SEARCH_RADIUS) + 1):
			var n := start + Vector2i(dq, dr)
			if cells.has(n) or not _touches_ship(n):
				continue
			var dist := Hex.to_pixel(n).distance_squared_to(grid_p)
			if dist < best_dist:
				best_dist = dist
				best = n
	if best_dist < INF:
		return best
	return _nearest_free_slot(grid_p)


func _touches_ship(h: Vector2i) -> bool:
	for d in Hex.DIRS:
		if cells.has(h + d):
			return true
	return false


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


## Canhões comuns que ficaram no meio da nave vão para o casco livre mais
## próximo da borda. Sem casco livre na borda, ficam inativos até abrir espaço.
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


## Células que perderam a ligação com o core se soltam e são destruídas.
func _prune_disconnected() -> PackedVector2Array:
	var reached := {CORE: true}
	var queue: Array[Vector2i] = [CORE]
	while not queue.is_empty():
		var h: Vector2i = queue.pop_back()
		for d in Hex.DIRS:
			var n: Vector2i = h + d
			if cells.has(n) and not reached.has(n):
				reached[n] = true
				queue.append(n)
	var lost := PackedVector2Array()
	for h in cells.keys():
		if not reached.has(h):
			lost.append(cell_global(h))
			_remove_cell(h)
	return lost


func cell_color(h: Vector2i) -> Color:
	var base := CORE_COLOR if h == CORE else Weapons.color(cells[h])
	return base.lerp(HURT_COLOR, flash * 0.7)


func outline_color(h: Vector2i) -> Color:
	if h == CORE:
		return Color(1, 1, 1, 0.9)
	return Weapons.color(cells[h]).lightened(0.5)


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


## Canhões: soquete escuro + cano apontando + luz que acende quando está
## carregado. Tudo em lote (4 chamadas no total, não 4 por canhão), porque
## isso é redesenhado todo frame para os canos acompanharem a mira.
func _draw_cannons() -> void:
	_sockets.clear()
	_glows.clear()
	_barrels_dark.resize(0)
	_barrels_lit.resize(0)
	_barrel_colors.resize(0)
	if weapon_at(CORE) == Weapons.NONE and cells.has(CORE):
		_glows.add_disc(cell_local(CORE), Hex.SIZE * 0.35, Color(1, 1, 1, 0.9))
	for h in _cannon_cells:
		var w: int = cells[h]
		var c := cell_local(h)
		# _draw usa o espaço local da nave, então desfaz a rotação da direção global.
		var dir := barrel_dir(h).rotated(-rotation)
		var col := Weapons.color(w).lightened(0.55)
		var armed := is_armed(h)
		var ready: float = 1.0 - _cooldowns.get(h, 0.0) / Weapons.COOLDOWN[w]
		_sockets.add_disc(c, Hex.SIZE * 0.45, SOCKET_COLOR)
		_barrels_dark.append(c)
		_barrels_dark.append(c + dir * Hex.SIZE * 0.95)
		_barrels_lit.append(c)
		_barrels_lit.append(c + dir * Hex.SIZE * 0.85)
		_barrel_colors.append(Color(col, 0.8 if armed else 0.25))
		var glow := (0.3 + 0.7 * ready) if armed else 0.15
		_glows.add_disc(c, Hex.SIZE * (0.18 + 0.1 * ready), Color(col, glow))
	_sockets.draw(get_canvas_item())
	if not _barrels_dark.is_empty():
		draw_multiline(_barrels_dark, SOCKET_COLOR, 6.0)
		draw_multiline_colors(_barrels_lit, _barrel_colors, 2.5)
	_glows.draw(get_canvas_item())
