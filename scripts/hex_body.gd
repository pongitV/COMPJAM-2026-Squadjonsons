class_name HexBody
extends Node2D
## Base de todo objeto composto por células hexagonais
## (jogador, asteroides e minérios).

## Distância entre centros a partir da qual duas células se tocam.
const CONTACT_DIST := Hex.SQRT3 * Hex.SIZE * 0.92

## Vector2i (coordenada axial) -> true
var cells: Dictionary = {}
## Deslocamento do centro de rotação em relação à célula (0, 0).
var center_offset := Vector2.ZERO
var velocity := Vector2.ZERO
var angular_velocity := 0.0
## Raio de um círculo que envolve o objeto inteiro (broad-phase).
var bound_radius := Hex.SIZE
## 0..1, usado para piscar ao receber dano.
var flash := 0.0


func cell_local(h: Vector2i) -> Vector2:
	return Hex.to_pixel(h) - center_offset


func cell_global(h: Vector2i) -> Vector2:
	return global_transform * cell_local(h)


## Converte uma posição global para o espaço da grade deste objeto.
func global_to_grid(p: Vector2) -> Vector2:
	return global_transform.affine_inverse() * p + center_offset


func recompute_bounds() -> void:
	bound_radius = 0.0
	for h in cells:
		bound_radius = maxf(bound_radius, cell_local(h).length())
	bound_radius += Hex.SIZE
	queue_redraw()


## Existe alguma célula deste objeto a menos de `radius` do ponto global?
func has_cell_near(global_p: Vector2, radius: float) -> bool:
	var grid_p := global_to_grid(global_p)
	var center := Hex.from_pixel(grid_p)
	if _cell_within(center, grid_p, radius):
		return true
	for d in Hex.DIRS:
		if _cell_within(center + d, grid_p, radius):
			return true
	return false


func touches(other: HexBody) -> bool:
	var reach := bound_radius + other.bound_radius
	if global_position.distance_squared_to(other.global_position) > reach * reach:
		return false
	# Itera sobre o menor objeto e consulta a grade do maior.
	var small: HexBody = self if cells.size() <= other.cells.size() else other
	var big: HexBody = other if small == self else self
	for h in small.cells:
		if big.has_cell_near(small.cell_global(h), CONTACT_DIST):
			return true
	return false


func cell_color(_h: Vector2i) -> Color:
	return Color.WHITE


func outline_color(_h: Vector2i) -> Color:
	return Color(1, 1, 1, 0.5)


func _cell_within(h: Vector2i, grid_p: Vector2, radius: float) -> bool:
	return cells.has(h) and Hex.to_pixel(h).distance_to(grid_p) < radius


func _draw() -> void:
	var corners := Hex.corners()
	for h in cells:
		var c := cell_local(h)
		var poly := PackedVector2Array()
		for p in corners:
			poly.append(c + p)
		draw_colored_polygon(poly, cell_color(h))
		poly.append(poly[0])
		draw_polyline(poly, outline_color(h), 1.5, true)
