class_name FormationWindow
extends CanvasLayer
## Janela grande do tutorial com as formacoes dos canhoes. Uma linha por arma
## (shotgun, bomba, laser): as pecas (canhoes comuns em triangulo, um pouco
## separados), uma seta e a arma que elas formam, desenhadas com as artes do
## jogo. Embaixo, o aviso de que o canhao do nucleo nao conta. Quem abre pausa
## o jogo; CONTINUAR (ou ENTER) fecha e emite `closed`.

signal closed

## Tamanho de cada celula nos desenhos (escala sobre a celula do jogo).
const CELL_ZOOM := 1.5
## O canhao formado aparece menor que no jogo para nao tampar o triangulo.
const BARREL_ZOOM := 0.6
## Afastamento entre as pecas soltas (1 = encostadas, como na nave).
const PIECE_SPREAD := 1.18
const CELL_EDGE := Color(0.0, 0.0, 0.0, 0.55)
const MARGIN := 6.0

var _button: Button


func _init() -> void:
	layer = 7
	process_mode = Node.PROCESS_MODE_ALWAYS


func _ready() -> void:
	var root := Control.new()
	root.theme = UIStyle.theme()
	add_child(root)
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var backdrop := ColorRect.new()
	backdrop.color = Color(0.0, 0.0, 0.0, 0.6)
	root.add_child(backdrop)
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var holder := CenterContainer.new()
	root.add_child(holder)
	holder.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var parts := Manual.make_panel("panel_formations", UIStyle.CYAN)
	var panel: PanelContainer = parts[0]
	var col: VBoxContainer = parts[1]
	holder.add_child(panel)
	Manual.title(col, "icon_manual", "TUTORIAL", "FORMAÇÕES DOS CANHÕES", UIStyle.CYAN)

	var intro := UIStyle.label("Canhões comuns vizinhos em triângulo se fundem sozinhos num canhão maior:", 15)
	intro.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(intro)

	var rows := VBoxContainer.new()
	rows.add_theme_constant_override("separation", 10)
	rows.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	col.add_child(rows)
	var cfg := Weapons.config
	rows.add_child(_row(Weapons.SHOTGUN, "%d tiros em leque" % cfg.shotgun_pellets()))
	rows.add_child(_row(Weapons.BOMB, "míssil com dano em área"))
	rows.add_child(_row(Weapons.LASER, "raio que atravessa tudo"))

	col.add_child(HSeparator.new())
	var warning := HBoxContainer.new()
	warning.alignment = BoxContainer.ALIGNMENT_CENTER
	warning.add_theme_constant_override("separation", 10)
	var core := TextureRect.new()
	core.texture = Art.cell_icon(Art.CORE)
	core.custom_minimum_size = Vector2(30, 28)
	core.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	core.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	core.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	warning.add_child(core)
	var text := UIStyle.label("Atenção: o canhão comum do NÚCLEO não conta para as formações.", 15, UIStyle.GOLD)
	text.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	warning.add_child(text)
	col.add_child(warning)

	_button = UIStyle.button("CONTINUAR")
	_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_button.pressed.connect(_close)
	col.add_child(_button)
	_button.grab_focus.call_deferred()
	Manual.fit.call_deferred(panel)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo \
			and event.physical_keycode in [KEY_ENTER, KEY_KP_ENTER]:
		get_viewport().set_input_as_handled()
		_close()


func _close() -> void:
	closed.emit()
	queue_free()


## Linha de uma arma: pecas -> seta -> arma formada, e o texto ao lado.
func _row(weapon: int, what: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	row.add_child(Diagram.new(weapon, true))
	row.add_child(Arrow.new())
	row.add_child(Diagram.new(weapon, false))
	var text := VBoxContainer.new()
	text.add_theme_constant_override("separation", 2)
	text.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	text.custom_minimum_size.x = 250.0
	text.add_child(UIStyle.label(Weapons.NAMES[weapon], 18, Weapons.color(weapon), UIStyle.DISPLAY))
	text.add_child(UIStyle.label("%d canhões comuns em triângulo" % CannonGroups.cell_count(weapon), 14))
	text.add_child(UIStyle.label(what, 12, UIStyle.TEXT_DIM))
	row.add_child(text)
	return row


## Triangulo da arma desenhado como no jogo. `pieces`: os canhoes comuns
## separados (celula azul + canhao comum em cada uma); senao, a arma ja
## formada (celulas na cor dela e o canhao grande no centro). A largura e a
## do maior triangulo (laser), para as colunas das linhas se alinharem.
class Diagram extends Control:
	var _weapon := Weapons.SHOTGUN
	var _pieces := false

	func _init(weapon: int, pieces: bool) -> void:
		_weapon = weapon
		_pieces = pieces
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		size_flags_vertical = Control.SIZE_SHRINK_CENTER
		var widest := _extent(CannonGroups.SIDES[Weapons.LASER])
		custom_minimum_size = Vector2(widest.x, _extent(CannonGroups.SIDES[weapon]).y)

	## Tamanho do desenho de um triangulo de lado `side` (com as pecas afastadas).
	func _extent(side: int) -> Vector2:
		var lo := Vector2.INF
		var hi := -Vector2.INF
		for h in CannonGroups.triangle(Vector2i.ZERO, side, false):
			var p := Hex.to_pixel(h) * FormationWindow.PIECE_SPREAD
			lo = lo.min(p)
			hi = hi.max(p)
		var cell := Art.cell_size(Art.COMMON)
		return (hi - lo + cell) * FormationWindow.CELL_ZOOM + Vector2.ONE * FormationWindow.MARGIN * 2.0

	func _draw() -> void:
		var side: int = CannonGroups.SIDES[_weapon]
		var tri := CannonGroups.triangle(Vector2i.ZERO, side, false)
		var center := Vector2.ZERO
		for h in tri:
			center += Hex.to_pixel(h)
		center /= tri.size()
		var k := FormationWindow.CELL_ZOOM
		var spread := FormationWindow.PIECE_SPREAD if _pieces else 1.0
		var origin := size * 0.5
		var kind := Art.COMMON if _pieces else Art.for_weapon(_weapon)
		var cell := Art.cell_size(kind) * k
		var spots: Array[Vector2] = []
		for h in tri:
			spots.append(origin + (Hex.to_pixel(h) - center) * k * spread)
		for p in spots:
			draw_texture_rect(Art.cell_icon(kind), Rect2(p - cell * 0.5, cell), false)
		# Contorno de cada hexagono, para contar as celulas do triangulo.
		for p in spots:
			var pts := PackedVector2Array()
			for corner in Hex.corners():
				pts.append(p + corner * k * 0.96)
			pts.append(pts[0])
			draw_polyline(pts, FormationWindow.CELL_EDGE, 1.5, true)
		if _pieces:
			for p in spots:
				_draw_barrel(Weapons.COMMON, p, HexBody.BARREL_SCALE * k)
		else:
			_draw_barrel(_weapon, origin,
				HexBody.BARREL_SCALE * CannonGroups.art_scale(side) * k * FormationWindow.BARREL_ZOOM)

	## Canhao com o cano para cima e o contorno escuro do jogo.
	func _draw_barrel(weapon: int, at: Vector2, s: float) -> void:
		var barrel := Art.cannon_size(weapon) * s
		var pivot := Art.cannon_pivot(weapon) * s
		var atlas := Art.cannon_atlas()
		var uv := Art.cannon_uv(weapon)
		var region := Rect2(uv.position * atlas.get_size(), uv.size * atlas.get_size())
		for offset: Vector2 in HexBody.OUTLINE_OFFSETS:
			draw_texture_rect_region(atlas, Rect2(at - pivot + offset, barrel), region, HexBody.OUTLINE_COLOR)
		draw_texture_rect_region(atlas, Rect2(at - pivot, barrel), region)


## Seta "vira" entre as pecas e a arma formada.
class Arrow extends Control:
	func _init() -> void:
		custom_minimum_size = Vector2(46, 30)
		size_flags_vertical = Control.SIZE_SHRINK_CENTER
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var y := size.y * 0.5
		var tip := Vector2(size.x - 4.0, y)
		draw_line(Vector2(4.0, y), tip - Vector2(4.0, 0.0), UIStyle.CYAN, 4.0, true)
		draw_colored_polygon(PackedVector2Array([tip, tip + Vector2(-14, -10), tip + Vector2(-14, 10)]), UIStyle.CYAN)
