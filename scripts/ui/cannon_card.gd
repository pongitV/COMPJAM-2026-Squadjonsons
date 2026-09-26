class_name CannonCard
extends PanelContainer
## Card do HUD com a quantidade de cada canhao da nave (comuns soltos e os
## triangulos fundidos em shotgun, laser e bomba).

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


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	add_theme_stylebox_override("panel", UIStyle.frame(["card_cannons", "card"], Weapons.color(Weapons.COMMON)))

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 4)
	add_child(col)
	col.add_child(UIStyle.label("CANHÕES", 10, Weapons.color(Weapons.COMMON).lightened(0.45), UIStyle.CAPTION))

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
