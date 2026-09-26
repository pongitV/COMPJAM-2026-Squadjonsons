class_name HexTabStyle
extends StyleBox
## Moldura da UI de jogo: versao geometrica e simples da moldura de hexagonos.
## Um retangulo com as pontas em chevron ("<" e ">", como as pontas da arte
## original), miolo chapado, contorno fino e um segundo contorno interno na
## cor de destaque. Desenhada em vetor: estica em qualquer tamanho e escala
## sem perder nitidez.

## Cor do miolo, do contorno e do contorno interno de destaque.
@export var fill := Color(0.07, 0.05, 0.16, 0.92)
@export var border := Color(0.46, 0.3, 1.0)
@export var accent := Color(0.3, 0.8, 1.0, 0.35)
## Profundidade das pontas em chevron (px; limitada a meia altura).
@export var point := 14.0
@export var border_width := 2.0
## Distancia do contorno interno ate a borda (0 = sem contorno interno).
@export var inset := 4.0


static func make(fill_color: Color, border_color: Color, accent_color: Color, point_depth: float = 14.0) -> HexTabStyle:
	var s := HexTabStyle.new()
	s.fill = fill_color
	s.border = border_color
	s.accent = accent_color
	s.point = point_depth
	s.content_margin_left = point_depth + 8.0
	s.content_margin_right = point_depth + 8.0
	s.content_margin_top = 8.0
	s.content_margin_bottom = 8.0
	return s


func _draw(to_canvas_item: RID, rect: Rect2) -> void:
	var outer := _shape(rect, point)
	RenderingServer.canvas_item_add_polygon(to_canvas_item, outer, PackedColorArray([fill]))
	if inset > 0.0 and accent.a > 0.0:
		var inner_rect := rect.grow(-inset)
		if inner_rect.size.x > 0.0 and inner_rect.size.y > 0.0:
			var inner := _shape(inner_rect, maxf(point - inset * 0.6, 0.0))
			inner.append(inner[0])
			RenderingServer.canvas_item_add_polyline(to_canvas_item, inner, PackedColorArray([accent]), 1.0, true)
	outer.append(outer[0])
	RenderingServer.canvas_item_add_polyline(to_canvas_item, outer, PackedColorArray([border]), border_width, true)


## Hexagono alongado: lados de cima e de baixo retos, pontas em chevron.
static func _shape(rect: Rect2, depth: float) -> PackedVector2Array:
	var p := minf(depth, rect.size.y * 0.5)
	var mid := rect.position.y + rect.size.y * 0.5
	return PackedVector2Array([
		Vector2(rect.position.x + p, rect.position.y),
		Vector2(rect.end.x - p, rect.position.y),
		Vector2(rect.end.x, mid),
		Vector2(rect.end.x - p, rect.end.y),
		Vector2(rect.position.x + p, rect.end.y),
		Vector2(rect.position.x, mid),
	])
