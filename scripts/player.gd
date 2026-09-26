class_name Player
extends HexBody
## Nave do jogador: um aglomerado de células conectadas à célula core.

signal core_destroyed

const CORE := Vector2i.ZERO
const ACCEL := 1100.0
const MAX_SPEED := 320.0
## Fração da velocidade mantida após 1 segundo (atrito).
const DAMPING := 0.25
## Intervalo entre rajadas enquanto o botão está pressionado.
const FIRE_INTERVAL := 0.18

const CORE_COLOR := Color(1.0, 0.85, 0.35)
const CELL_COLOR := Color(0.3, 0.8, 1.0)
const HURT_COLOR := Color(1.0, 0.25, 0.2)

var alive := true
var _fire_timer := 0.0


func _init() -> void:
	cells[CORE] = true
	recompute_bounds()


func step(delta: float) -> void:
	var input := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	# Naves maiores aceleram um pouco mais devagar.
	var mass_factor := 1.0 / sqrt(1.0 + cells.size() * 0.02)
	velocity += input * ACCEL * mass_factor * delta
	velocity *= pow(DAMPING, delta)
	velocity = velocity.limit_length(MAX_SPEED)
	position += velocity * delta

	_fire_timer = maxf(_fire_timer - delta, 0.0)
	if flash > 0.0:
		flash = maxf(flash - delta * 3.0, 0.0)
		queue_redraw()


## Cada célula dispara um projétil em direção ao alvo.
## Retorna uma lista de [origem, direção].
func fire(target: Vector2) -> Array:
	if not alive or _fire_timer > 0.0:
		return []
	_fire_timer = FIRE_INTERVAL
	var shots := []
	for h in cells:
		var origin := cell_global(h)
		var dir := (target - origin).normalized()
		if dir == Vector2.ZERO:
			dir = Vector2.RIGHT
		shots.append([origin, dir])
	return shots


## Transforma um minério que tocou a nave em uma nova célula, no espaço
## livre adjacente mais próximo do ponto de contato.
func absorb_at(global_p: Vector2) -> void:
	var grid_p := global_to_grid(global_p)
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
	cells[best] = true
	recompute_bounds()


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
		alive = false
		recompute_bounds()
		core_destroyed.emit()
		return lost

	var ranked := others.map(func(h): return [Hex.distance(h, CORE) + randf() * 0.9, h])
	ranked.sort_custom(func(a, b): return a[0] > b[0])
	for i in amount:
		var h: Vector2i = ranked[i][1]
		lost.append(cell_global(h))
		cells.erase(h)
	lost.append_array(_prune_disconnected())
	flash = 1.0
	recompute_bounds()
	return lost


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
			cells.erase(h)
	return lost


func cell_color(h: Vector2i) -> Color:
	var base := CORE_COLOR if h == CORE else CELL_COLOR
	return base.lerp(HURT_COLOR, flash * 0.7)


func outline_color(h: Vector2i) -> Color:
	return Color(1, 1, 1, 0.9) if h == CORE else Color(0.75, 0.95, 1.0, 0.7)


func _draw() -> void:
	super._draw()
	if cells.has(CORE):
		draw_circle(cell_local(CORE), Hex.SIZE * 0.35, Color(1, 1, 1, 0.9))
