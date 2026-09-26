class_name Hex
extends RefCounted
## Matemática de grade hexagonal (pointy-top, coordenadas axiais q/r).
## Referência: https://www.redblobgames.com/grids/hexagons/

## Raio (centro -> vértice) de uma célula, em pixels.
const SIZE := 12.0
const SQRT3 := 1.7320508075688772
const DIRS := [
	Vector2i(1, 0), Vector2i(1, -1), Vector2i(0, -1),
	Vector2i(-1, 0), Vector2i(-1, 1), Vector2i(0, 1),
]

static var _corners := PackedVector2Array()


static func to_pixel(h: Vector2i) -> Vector2:
	return Vector2(SIZE * SQRT3 * (h.x + h.y * 0.5), SIZE * 1.5 * h.y)


static func from_pixel(p: Vector2) -> Vector2i:
	var q := (SQRT3 / 3.0 * p.x - p.y / 3.0) / SIZE
	var r := (2.0 / 3.0 * p.y) / SIZE
	return _cube_round(q, r)


static func distance(a: Vector2i, b: Vector2i) -> int:
	var d := a - b
	return (absi(d.x) + absi(d.y) + absi(d.x + d.y)) >> 1


## Vértices de um hexágono centrado na origem (levemente encolhido para
## deixar a grade visível).
static func corners() -> PackedVector2Array:
	if _corners.is_empty():
		for i in 6:
			_corners.append(Vector2.from_angle(deg_to_rad(60.0 * i - 30.0)) * (SIZE - 1.0))
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
