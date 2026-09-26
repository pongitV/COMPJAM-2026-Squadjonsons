class_name CannonCard
extends PanelContainer
## Card do HUD com a quantidade de cada canhao e o progresso ate o
## proximo canhao comum (um hexagono aceso por asteroide destruido).

const TYPES := [Weapons.COMMON, Weapons.SHOTGUN, Weapons.LASER, Weapons.BOMB]
const ICON_SLOTS := {
	Weapons.COMMON: "icon_cannon_common",
	Weapons.SHOTGUN: "icon_cannon_shotgun",
	Weapons.LASER: "icon_cannon_laser",
	Weapons.BOMB: "icon_cannon_bomb",
}

var _counts := {}
var _labels := {}
var _icons := {}
var _pips: HexPips


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	add_theme_stylebox_override("panel", UIStyle.frame(["card_cannons", "card"], Weapons.color(Weapons.COMMON)))

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 4)
	add_child(col)
	col.add_child(UIStyle.label("CANHÕES", 10, Color(Weapons.color(Weapons.COMMON), 0.85), UIStyle.CAPTION))

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	col.add_child(row)
	for w in TYPES:
		var entry := HBoxContainer.new()
		entry.add_theme_constant_override("separation", 4)
		var icon := HexIcon.new(ICON_SLOTS[w], Weapons.color(w), 18)
		icon.spin_speed = 0.0
		var count := UIStyle.label("0", 16, UIStyle.TEXT, UIStyle.DISPLAY)
		entry.add_child(icon)
		entry.add_child(count)
		row.add_child(entry)
		_icons[w] = icon
		_labels[w] = count
		_counts[w] = 0

	var next := HBoxContainer.new()
	next.add_theme_constant_override("separation", 8)
	col.add_child(next)
	next.add_child(UIStyle.label("PRÓXIMO", 10, UIStyle.TEXT_DIM, UIStyle.CAPTION))
	_pips = HexPips.new(Weapons.ASTEROIDS_PER_COMMON, Weapons.color(Weapons.COMMON))
	next.add_child(_pips)


func set_counts(counts: Dictionary) -> void:
	for w in TYPES:
		var n: int = counts.get(w, 0)
		if n == _counts[w]:
			continue
		var label: Label = _labels[w]
		label.text = str(n)
		if n > _counts[w]:
			_icons[w].kick()
			label.modulate = Weapons.color(w).lightened(0.5)
			label.create_tween().tween_property(label, "modulate", Color.WHITE, 0.5)
		_counts[w] = n


func set_progress(filled: int) -> void:
	_pips.set_filled(filled)


## Fileira de hexagonos que acendem conforme o progresso. Cada um usa o
## sprite "pip_full" / "pip_empty" se existir; senao, o hexagono desenhado.
class HexPips extends Control:
	const PIP := 15.0
	var _total := 5
	var _filled := 0
	var _color := Color.WHITE
	var _flash := 0.0

	func _init(total: int, color: Color) -> void:
		_total = total
		_color = color
		custom_minimum_size = Vector2(total * PIP, PIP - 1.0)
		size_flags_vertical = Control.SIZE_SHRINK_CENTER
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func set_filled(n: int) -> void:
		if n == _filled:
			return
		_filled = n
		_flash = 1.0

	func _process(delta: float) -> void:
		if _flash > 0.0:
			_flash = maxf(_flash - delta * 3.0, 0.0)
			queue_redraw()

	func _draw() -> void:
		for i in _total:
			var c := Vector2(7 + i * PIP, size.y * 0.5)
			var lit := i < _filled
			# O ultimo aceso pisca branco ao acender.
			var flash := _flash * 0.6 if i == _filled - 1 else 0.0
			var tex := UISkin.texture("pip_full" if lit else "pip_empty")
			if tex != null:
				var box := Vector2.ONE * (PIP - 1.0)
				draw_texture_rect(tex, Rect2(c - box * 0.5, box), false, Color.WHITE.lerp(Color(2, 2, 2), flash))
				continue
			var pts := PackedVector2Array()
			for k in 6:
				pts.append(c + Vector2.from_angle(PI / 6.0 + k * TAU / 6.0) * 6.0)
			if lit:
				draw_colored_polygon(pts, _color.lerp(Color.WHITE, flash))
			pts.append(pts[0])
			draw_polyline(pts, Color(_color, 0.7), 1.2, true)
