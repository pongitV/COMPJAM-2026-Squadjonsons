class_name TriBatch
extends RefCounted
## Acumula formas simples (retangulos, quadrados com textura) numa
## unica lista de triangulos, desenhada com uma so chamada em vez de uma por
## forma. Num mesmo lote, use so formas com textura (add_quad) ou so sem.

var points := PackedVector2Array()
var colors := PackedColorArray()
var indices := PackedInt32Array()
var uvs := PackedVector2Array()


func clear() -> void:
	points.resize(0)
	colors.resize(0)
	indices.resize(0)
	uvs.resize(0)


func is_empty() -> bool:
	return points.is_empty()


func add_rect(rect: Rect2, color: Color) -> void:
	var base := points.size()
	points.append(rect.position)
	points.append(Vector2(rect.end.x, rect.position.y))
	points.append(rect.end)
	points.append(Vector2(rect.position.x, rect.end.y))
	for k in 4:
		colors.append(color)
	for i in [0, 1, 2, 0, 2, 3]:
		indices.append(base + i)


## Risco de `from` ate `to` com a espessura dada; a cor vai de `from_color`
## a `to_color` (ex.: cauda transparente). Sem textura.
func add_streak(from: Vector2, to: Vector2, width: float, from_color: Color, to_color: Color) -> void:
	var side := (to - from).orthogonal().normalized() * width * 0.5
	var base := points.size()
	points.append(from - side)
	points.append(to - side)
	points.append(to + side)
	points.append(from + side)
	colors.append(from_color)
	colors.append(to_color)
	colors.append(to_color)
	colors.append(from_color)
	for i in [0, 1, 2, 0, 2, 3]:
		indices.append(base + i)


## Quadrilatero com textura: `corners` em sentido horario a partir do canto
## superior esquerdo da regiao `uv` do atlas.
func add_quad(corners: Array, uv: Rect2, color: Color) -> void:
	var base := points.size()
	for p in corners:
		points.append(p)
		colors.append(color)
	uvs.append(uv.position)
	uvs.append(Vector2(uv.end.x, uv.position.y))
	uvs.append(uv.end)
	uvs.append(Vector2(uv.position.x, uv.end.y))
	for i in [0, 1, 2, 0, 2, 3]:
		indices.append(base + i)


func draw(canvas_item: RID, texture: Texture2D = null) -> void:
	if points.is_empty():
		return
	if texture == null:
		RenderingServer.canvas_item_add_triangle_array(canvas_item, indices, points, colors)
	else:
		RenderingServer.canvas_item_add_triangle_array(canvas_item, indices, points, colors, uvs,
			PackedInt32Array(), PackedFloat32Array(), texture.get_rid())
