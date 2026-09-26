class_name HudTab
extends PanelContainer
## Aba do topo do HUD no estilo geometrico (HexTabStyle): um hexagono
## simples, a legenda e um valor grande. set_value() faz o numero rolar ate o
## alvo (pulsando na cor da aba ao subir e em vermelho ao cair); set_text()
## mostra um texto pronto (ex.: o countdown).

var accent: Color
var _hex: HexGlyph
var _caption: Label
var _value: Label
var _target := 0
var _shown := 0.0


## `slot`: sprite proprio da moldura (UISkin), com "tab" como reserva.
func _init(caption: String, color: Color, slot: String, right_aligned: bool = false) -> void:
	accent = color
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	add_theme_stylebox_override("panel", UIStyle.tab([slot, "tab"], color, 16.0))

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	row.alignment = BoxContainer.ALIGNMENT_END if right_aligned else BoxContainer.ALIGNMENT_BEGIN
	add_child(row)
	_hex = HexGlyph.new(color)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 0)
	col.custom_minimum_size.x = 110
	_caption = UIStyle.label(caption, 10, color.lightened(0.35), UIStyle.CAPTION)
	_value = UIStyle.label("0", 26, UIStyle.TEXT, UIStyle.DISPLAY)
	if right_aligned:
		_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		_value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	col.add_child(_caption)
	col.add_child(_value)
	# O hexagono fica do lado de fora (esquerda na aba da esquerda e vice-versa).
	if right_aligned:
		row.add_child(col)
		row.add_child(_hex)
	else:
		row.add_child(_hex)
		row.add_child(col)


func set_value(v: int) -> void:
	if v == _target:
		return
	var gained := v > _target
	_target = v
	bump(accent if gained else UIStyle.RED, gained)


func set_text(text: String, color: Color = UIStyle.TEXT) -> void:
	_value.text = UIStyle.plain(text)
	_value.add_theme_color_override("font_color", color)


func set_caption(text: String) -> void:
	_caption.text = UIStyle.plain(text)


## Pulso no valor (e no hexagono) na cor `flash`.
func bump(flash: Color, grow: bool = true) -> void:
	_hex.pulse = 1.0
	_value.pivot_offset = _value.size * 0.5
	_value.scale = Vector2.ONE * (1.12 if grow else 0.9)
	_value.modulate = flash.lightened(0.4)
	var tw := create_tween().set_parallel()
	tw.tween_property(_value, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(_value, "modulate", Color.WHITE, 0.45)


func _process(delta: float) -> void:
	if _shown == _target:
		return
	_shown = lerpf(_shown, _target, 1.0 - exp(-10.0 * delta))
	if absf(_shown - _target) < 0.5:
		_shown = _target
	_value.text = UIStyle.fmt_int(roundi(_shown))


## Hexagono vazado com um hexagono menor cheio no meio (sem giro: geometrico
## e parado; so cresce um pouco no pulso).
class HexGlyph extends Control:
	var color: Color
	var pulse := 0.0

	func _init(c: Color) -> void:
		color = c
		custom_minimum_size = Vector2(30, 30)
		size_flags_vertical = Control.SIZE_SHRINK_CENTER
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _process(delta: float) -> void:
		if pulse > 0.0:
			pulse = move_toward(pulse, 0.0, delta * 2.5)
			queue_redraw()

	func _draw() -> void:
		var c := size * 0.5
		var r := minf(size.x, size.y) * 0.45 * (1.0 + pulse * 0.2)
		var outer := _hex(c, r)
		draw_colored_polygon(outer, Color(color, 0.12 + pulse * 0.4))
		outer.append(outer[0])
		draw_polyline(outer, color, 2.0, true)
		draw_colored_polygon(_hex(c, r * 0.4), color)

	static func _hex(c: Vector2, r: float) -> PackedVector2Array:
		var pts := PackedVector2Array()
		for i in 6:
			pts.append(c + Vector2.from_angle(i * TAU / 6.0) * r)
		return pts
