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

const CORE_COLOR := Color(1.0, 0.85, 0.35)
const HURT_COLOR := Color(1.0, 0.25, 0.2)
const SOCKET_COLOR := Color(0.02, 0.04, 0.08)

var alive := true
## Ponto global para onde os canhões miram (atualizado pelo jogo).
var aim := Vector2.RIGHT
## Vector2i -> segundos até o canhão daquela célula poder atirar de novo.
var _cooldowns := {}


func _init() -> void:
	cells[CORE] = Weapons.COMMON
	recompute_bounds()


func step(delta: float) -> void:
	var input := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	# Naves maiores aceleram um pouco mais devagar.
	var mass_factor := 1.0 / sqrt(1.0 + cells.size() * 0.02)
	velocity += input * ACCEL * mass_factor * delta
	velocity *= pow(DAMPING, delta)
	velocity = velocity.limit_length(MAX_SPEED)
	position += velocity * delta

	for h in _cooldowns:
		_cooldowns[h] = maxf(_cooldowns[h] - delta, 0.0)
	flash = maxf(flash - delta * 3.0, 0.0)
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


## Direção do cano: o laser aponta para fora da nave, os demais para a mira.
func barrel_dir(h: Vector2i) -> Vector2:
	var d := cell_local(h) if weapon_at(h) == Weapons.LASER else aim - cell_global(h)
	return d.normalized() if d.length_squared() > 0.01 else Vector2.RIGHT


## Dispara todos os canhões prontos.
## Retorna uma lista de {type, cell, origin, dir}; o jogo cria os projéteis.
func fire() -> Array:
	if not alive:
		return []
	var shots := []
	for h in cells:
		if not is_armed(h) or _cooldowns.get(h, 0.0) > 0.0:
			continue
		var w: int = cells[h]
		_cooldowns[h] = Weapons.COOLDOWN[w]
		shots.append({"type": w, "cell": h, "origin": cell_global(h), "dir": barrel_dir(h)})
	return shots


## Transforma um minério que tocou a nave em uma nova célula (com o canhão
## do minério, se houver), no espaço livre mais próximo do ponto de contato.
func absorb_at(global_p: Vector2, weapon: int = Weapons.NONE) -> Vector2i:
	var h := _nearest_free_slot(global_to_grid(global_p))
	cells[h] = weapon
	_relocate_commons()
	recompute_bounds()
	return h


## Coloca um canhão comum numa célula de casco da borda, do lado da mira.
## Sem casco livre na borda, a nave ganha uma célula nova com o canhão.
func add_common_cannon() -> Vector2i:
	var aim_dir := (aim - global_position).normalized()
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
	var counts := {Weapons.COMMON: 0, Weapons.SHOTGUN: 0, Weapons.LASER: 0, Weapons.BOMB: 0}
	for h in cells:
		var w: int = cells[h]
		if w != Weapons.NONE:
			counts[w] += 1
	return counts


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
	for h in cells:
		var w: int = cells[h]
		if w == Weapons.NONE:
			if h == CORE:
				draw_circle(cell_local(h), Hex.SIZE * 0.35, Color(1, 1, 1, 0.9))
			continue
		_draw_cannon(h, w)


## Soquete escuro + cano apontando + luz que acende quando está carregado.
func _draw_cannon(h: Vector2i, w: int) -> void:
	var c := cell_local(h)
	var dir := barrel_dir(h)
	var col := Weapons.color(w).lightened(0.55)
	var armed := is_armed(h)
	var ready: float = 1.0 - _cooldowns.get(h, 0.0) / Weapons.COOLDOWN[w]
	var barrel_width := 5.0 if w == Weapons.SHOTGUN or w == Weapons.BOMB else 3.5

	draw_circle(c, Hex.SIZE * 0.45, SOCKET_COLOR)
	draw_line(c, c + dir * Hex.SIZE * 0.95, SOCKET_COLOR, barrel_width + 2.0, true)
	draw_line(c, c + dir * Hex.SIZE * 0.85, Color(col, 0.8 if armed else 0.25), barrel_width - 1.5, true)
	var glow := (0.3 + 0.7 * ready) if armed else 0.15
	draw_circle(c, Hex.SIZE * (0.18 + 0.1 * ready), Color(col, glow))
