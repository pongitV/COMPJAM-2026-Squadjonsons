class_name TriBatch
extends RefCounted
## Acumula formas simples (discos, retângulos) numa única lista de
## triângulos, desenhada com uma só chamada em vez de uma por forma.

var points := PackedVector2Array()
var colors := PackedColorArray()
var indices := PackedInt32Array()


func clear() -> void:
	points.resize(0)
	colors.resize(0)
	indices.resize(0)


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


func draw(canvas_item: RID) -> void:
	if not points.is_empty():
		RenderingServer.canvas_item_add_triangle_array(canvas_item, indices, points, colors)
