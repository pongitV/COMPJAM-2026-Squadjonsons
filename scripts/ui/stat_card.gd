class_name StatCard
extends PanelContainer
## Card do HUD: icone, legenda e um numero que "rola" ate o valor alvo,
## pulsando na cor do card ao subir e em vermelho ao cair.

var icon: HexIcon
var _color: Color
var _value_label: Label
var _sub_label: Label
var _target := 0
var _shown := 0.0


func _init(caption: String, color: Color) -> void:
	_color = color
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	add_theme_stylebox_override("panel", UIStyle.panel(color))

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	add_child(row)
	icon = HexIcon.new(color, 30)
	row.add_child(icon)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 1)
	col.custom_minimum_size.x = 86
	row.add_child(col)
	col.add_child(UIStyle.label(caption, 10, Color(color, 0.85), UIStyle.CAPTION))
	_value_label = UIStyle.label("0", 20, UIStyle.TEXT, UIStyle.DISPLAY)
	col.add_child(_value_label)
	_sub_label = UIStyle.label("", 10, UIStyle.TEXT_DIM, UIStyle.CAPTION)
	_sub_label.visible = false
	col.add_child(_sub_label)


func set_value(v: int) -> void:
	if v == _target:
		return
	var gained := v > _target
	_target = v
	_bump(_color if gained else UIStyle.RED, gained)


## Texto livre (sem animacao de contagem), ex.: o cronometro.
func set_text(text: String) -> void:
	_value_label.text = UIStyle.plain(text)


func set_sub(text: String) -> void:
	_sub_label.visible = text != ""
	_sub_label.text = UIStyle.plain(text)


func _process(delta: float) -> void:
	if _shown == _target:
		return
	_shown = lerpf(_shown, _target, 1.0 - exp(-10.0 * delta))
	if absf(_shown - _target) < 0.5:
		_shown = _target
	_value_label.text = UIStyle.fmt_int(roundi(_shown))


func _bump(flash: Color, gained: bool) -> void:
	icon.kick()
	_value_label.pivot_offset = Vector2(0, _value_label.size.y * 0.5)
	_value_label.scale = Vector2.ONE * (1.12 if gained else 0.9)
	_value_label.modulate = flash.lightened(0.4)
	var tw := create_tween().set_parallel()
	tw.tween_property(_value_label, "scale", Vector2.ONE, 0.3) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(_value_label, "modulate", Color.WHITE, 0.45)
