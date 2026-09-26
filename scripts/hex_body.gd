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

# Malha em cache: todas as células viram UMA lista de triângulos e UMA
# chamada de linhas, recalculadas só quando a forma ou as cores mudam.
# Desenhar célula por célula custava milhares de draw calls por frame.
var _geometry_dirty := true
var _colors_dirty := true
var _cell_order: Array = []
var _points := PackedVector2Array()
var _indices := PackedInt32Array()
var _colors := PackedColorArray()
var _outline := PackedVector2Array()
var _outline_colors := PackedColorArray()


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
	_geometry_dirty = true
	queue_redraw()


## Chame quando cell_color()/outline_color() passarem a devolver outra cor.
func refresh_colors() -> void:
	_colors_dirty = true
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
	if _geometry_dirty:
		_rebuild_geometry()
	if _colors_dirty:
		_rebuild_colors()
	if _points.is_empty():
		return
	RenderingServer.canvas_item_add_triangle_array(get_canvas_item(), _indices, _points, _colors)
	draw_multiline_colors(_outline, _outline_colors, 1.5)


## Cada célula: centro + 6 vértices (6 triângulos) e 6 segmentos de contorno.
func _rebuild_geometry() -> void:
	_geometry_dirty = false
	_colors_dirty = true
	_cell_order = cells.keys()
	var n := _cell_order.size()
	_points.resize(n * 7)
	_indices.resize(n * 18)
	_outline.resize(n * 12)
	var corners := Hex.corners()
	for i in n:
		var c := cell_local(_cell_order[i])
		var base := i * 7
		_points[base] = c
		for k in 6:
			_points[base + 1 + k] = c + corners[k]
			var t := i * 18 + k * 3
			_indices[t] = base
			_indices[t + 1] = base + 1 + k
			_indices[t + 2] = base + 1 + (k + 1) % 6
			_outline[i * 12 + k * 2] = c + corners[k]
			_outline[i * 12 + k * 2 + 1] = c + corners[(k + 1) % 6]


func _rebuild_colors() -> void:
	_colors_dirty = false
	var n := _cell_order.size()
	_colors.resize(n * 7)
	_outline_colors.resize(n * 6)
	for i in n:
		var h: Vector2i = _cell_order[i]
		var fill := cell_color(h)
		var line := outline_color(h)
		for k in 7:
			_colors[i * 7 + k] = fill
		for k in 6:
			_outline_colors[i * 6 + k] = line
