class_name Hex
extends RefCounted
## Matematica de grade hexagonal (flat-top: lado plano em cima, como as
## celulas da arte; coordenadas axiais q/r).
## Referencia: https://www.redblobgames.com/grids/hexagons/

## Raio (centro -> vertice) de uma celula, em pixels.
const SIZE := 12.0
const SQRT3 := 1.7320508075688772
const DIRS := [
	Vector2i(1, 0), Vector2i(1, -1), Vector2i(0, -1),
	Vector2i(-1, 0), Vector2i(-1, 1), Vector2i(0, 1),
]
## A propria celula + as 6 vizinhas.
const AROUND := [
	Vector2i(0, 0),
	Vector2i(1, 0), Vector2i(1, -1), Vector2i(0, -1),
	Vector2i(-1, 0), Vector2i(-1, 1), Vector2i(0, 1),
]

static var _corners := PackedVector2Array()


static func to_pixel(h: Vector2i) -> Vector2:
	return Vector2(SIZE * 1.5 * h.x, SIZE * SQRT3 * (h.y + h.x * 0.5))


static func from_pixel(p: Vector2) -> Vector2i:
	var q := (2.0 / 3.0 * p.x) / SIZE
	var r := (-p.x / 3.0 + SQRT3 / 3.0 * p.y) / SIZE
	return _cube_round(q, r)


static func distance(a: Vector2i, b: Vector2i) -> int:
	var d := a - b
	return (absi(d.x) + absi(d.y) + absi(d.x + d.y)) >> 1


## Gira uma coordenada axial em `turns` passos de 60 graus (sentido horario na
## tela), ou seja: to_pixel(rotate(h, 1)) == to_pixel(h).rotated(PI / 3).
static func rotate(h: Vector2i, turns: int) -> Vector2i:
	var q := h.x
	var r := h.y
	for i in posmod(turns, 6):
		var s := -q - r
		q = -r
		r = -s
	return Vector2i(q, r)


## Separa um conjunto de celulas em grupos conectados (listas de Vector2i).
static func components(keys: Array) -> Array:
	var left := {}
	for h in keys:
		left[h] = true
	var groups := []
	while not left.is_empty():
		var start: Vector2i = left.keys()[0]
		left.erase(start)
		var group: Array[Vector2i] = [start]
		var i := 0
		while i < group.size():
			for d in DIRS:
				var n: Vector2i = group[i] + d
				if left.has(n):
					left.erase(n)
					group.append(n)
			i += 1
		groups.append(group)
	return groups


## Vertices de um hexagono centrado na origem, levemente encolhido (usado
## no encaixe fantasma do raio trator).
static func corners() -> PackedVector2Array:
	if _corners.is_empty():
		for i in 6:
			_corners.append(Vector2.from_angle(deg_to_rad(60.0 * i)) * (SIZE - 1.0))
	return _corners


static func _cube_round(q: float, r: float) -> Vector2i:
	var s := -q - r
	var rq := roundf(q)
	var rr := roundf(r)
	var rs := roundf(s)
	var dq := absf(rq - q)
	var dr := absf(rr - r)
	var ds := absf(rs - s)
	if dq > dr and dq > ds:
		rq = -rr - rs
	elif dr > ds:
		rr = -rq - rs
	return Vector2i(int(rq), int(rr))
