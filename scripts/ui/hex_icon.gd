class_name HexIcon
extends UISprite
## Icone animado: da um "pulso" quando chutado. O placeholder e um hexagono
## que gira devagar; um sprite proprio so pulsa (nao gira).

var spin_speed := 0.4
var pulse := 0.0
var _angle := randf() * TAU


func _init(slot_name: String = "", c: Color = UIStyle.CYAN, icon_size: float = 38.0) -> void:
	super(slot_name, Vector2(icon_size, icon_size))
	color = c
	size_flags_vertical = Control.SIZE_SHRINK_CENTER


func kick() -> void:
	pulse = 1.0


func _process(delta: float) -> void:
	_angle += delta * (spin_speed + pulse * 7.0)
	pulse = move_toward(pulse, 0.0, delta * 2.5)
	sprite_scale = 1.0 + pulse * 0.25
	queue_redraw()


func _draw_placeholder() -> void:
	var c := size * 0.5
	var r := minf(size.x, size.y) * 0.42 * sprite_scale
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
