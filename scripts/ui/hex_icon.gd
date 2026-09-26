class_name HexIcon
extends Control
## Ícone hexagonal animado: gira devagar e dá um "pulso" quando chutado.

var color := UIStyle.CYAN
var spin_speed := 0.4
var pulse := 0.0
var _angle := randf() * TAU


func _init(c: Color = UIStyle.CYAN, icon_size: float = 38.0) -> void:
	color = c
	custom_minimum_size = Vector2(icon_size, icon_size)
	size_flags_vertical = Control.SIZE_SHRINK_CENTER
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func kick() -> void:
	pulse = 1.0


func _process(delta: float) -> void:
	_angle += delta * (spin_speed + pulse * 7.0)
	pulse = move_toward(pulse, 0.0, delta * 2.5)
	queue_redraw()


func _draw() -> void:
	var c := size * 0.5
	var r := minf(size.x, size.y) * 0.42 * (1.0 + pulse * 0.25)
	var outer := _hex(c, r, _angle)
	draw_colored_polygon(outer, Color(color, 0.15 + pulse * 0.45))
	outer.append(outer[0])
	draw_polyline(outer, color, 2.0, true)
	draw_colored_polygon(_hex(c, r * 0.42, -_angle * 1.5), color)


static func _hex(c: Vector2, r: float, angle: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in 6:
		pts.append(c + Vector2.from_angle(angle + i * TAU / 6.0) * r)
	return pts
