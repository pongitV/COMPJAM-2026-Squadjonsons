class_name TriBatch
extends RefCounted
## Acumula formas simples (discos, retângulos, quadrados com textura) numa
## única lista de triângulos, desenhada com uma só chamada em vez de uma por
## forma. Num mesmo lote, use só formas com textura (add_quad) ou só sem.

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


func add_disc(center: Vector2, radius: float, color: Color, sides: int = 8) -> void:
	var base := points.size()
	points.append(center)
	colors.append(color)
	for k in sides:
		points.append(center + Vector2.from_angle(k * TAU / sides) * radius)
		colors.append(color)
		indices.append(base)
		indices.append(base + 1 + k)
		indices.append(base + 1 + (k + 1) % sides)


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


## Quadrilátero com textura: `corners` em sentido horário a partir do canto
## superior esquerdo da região `uv` do atlas.
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
