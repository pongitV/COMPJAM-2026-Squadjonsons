class_name Hud
extends CanvasLayer
## Interface durante o jogo, no estilo geometrico (HexTabStyle): aba de
## hexagonos da nave a esquerda, countdown ate o fim da corrida a direita,
## linha de chegada no rodape, textos flutuantes, vinheta de dano, mira e a
## tela de fim.

signal restart_requested
signal menu_requested

## Countdown fica dourado no ultimo minuto e vermelho nos ultimos segundos.
const COUNTDOWN_WARN := 60.0
const COUNTDOWN_ALERT := 10.0

var cells_tab: HudTab
var countdown_tab: HudTab
var race_bar: RaceBar
var _last_second := -1

var _root: Control
var _popups: Control
var _vignette: TextureRect
var _vignette_tween: Tween
var _reticle: Reticle
var _hint: Label


func _init() -> void:
	layer = 5


func _ready() -> void:
	_root = Control.new()
	_root.theme = UIStyle.hud_theme()
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	_build_vignette()

	_popups = Control.new()
	_popups.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_popups)
	_popups.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var bar := MarginContainer.new()
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side in ["left", "right", "top"]:
		bar.add_theme_constant_override("margin_" + side, 16)
	_root.add_child(bar)
	bar.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)

	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 10)
	bar.add_child(row)
	cells_tab = HudTab.new("HEXÁGONOS", UIStyle.CYAN, "tab_cells")
	countdown_tab = HudTab.new("CHEGADA EM", UIStyle.PURPLE, "tab_countdown", true)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for c in [cells_tab, spacer, countdown_tab]:
		row.add_child(c)

	# Linha de chegada: 60% da largura, centrada no rodape, numa aba longa.
	var race_panel := PanelContainer.new()
	race_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	race_panel.add_theme_stylebox_override("panel", UIStyle.tab(["tab_race", "tab"], UIStyle.PURPLE, 18.0))
	_root.add_child(race_panel)
	race_panel.anchor_left = 0.2
	race_panel.anchor_right = 0.8
	race_panel.anchor_top = 1.0
	race_panel.anchor_bottom = 1.0
	race_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	race_panel.offset_top = -8.0
	race_panel.offset_bottom = -8.0
	race_bar = RaceBar.new()
	race_bar.custom_minimum_size.y = 36.0
	race_panel.add_child(race_bar)

	_hint = UIStyle.label("ESC  pausar / info", 11, Color(UIStyle.TEXT_DIM, 0.6), UIStyle.CAPTION)
	_root.add_child(_hint)
	_hint.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT, Control.PRESET_MODE_MINSIZE, 16)

	_reticle = Reticle.new()
	_root.add_child(_reticle)
	set_playing(true)


## Countdown ate o fim da corrida (e a linha de chegada do rodape).
func set_countdown(elapsed: float, duration: float) -> void:
	race_bar.set_time(elapsed, duration)
	var left := maxf(duration - elapsed, 0.0)
	if left <= 0.0:
		countdown_tab.set_caption("CHEGADA!")
		countdown_tab.set_text("0:00", UIStyle.GOLD)
		return
	var color := UIStyle.RED if left <= COUNTDOWN_ALERT else UIStyle.GOLD if left <= COUNTDOWN_WARN else UIStyle.TEXT
	# Arredonda para cima: mostra 5:00 no inicio e 0:01 no ultimo segundo.
	var seconds := ceili(left)
	countdown_tab.set_text(UIStyle.fmt_time(seconds), color)
	# Nos ultimos segundos, pulsa a cada segundo.
	if seconds != _last_second and left <= COUNTDOWN_ALERT:
		countdown_tab.bump(UIStyle.RED)
	_last_second = seconds


## Mira customizada durante o jogo; cursor normal em menus.
func set_playing(playing: bool) -> void:
	_reticle.visible = playing
	Input.mouse_mode = Input.MOUSE_MODE_HIDDEN if playing else Input.MOUSE_MODE_VISIBLE


## Texto que salta e sobe a partir de um ponto da tela.
func popup(text: String, color: Color, screen_pos: Vector2, font_size: int = 18) -> void:
	var l := UIStyle.label(text, font_size, color)
	# Mesma fonte da UI; contorno fino na cor dos paineis para ler sobre o jogo.
	l.add_theme_font_override("font", UIStyle.display_font())
	l.add_theme_constant_override("outline_size", 3)
	l.add_theme_color_override("font_outline_color", Color(UIStyle.PANEL_BG, 0.9))
	_popups.add_child(l)
	l.size = l.get_combined_minimum_size()
	l.position = screen_pos - l.size * 0.5
	l.pivot_offset = l.size * 0.5
	l.scale = Vector2.ONE * 0.75
	var tw := l.create_tween().set_parallel()
	tw.tween_property(l, "scale", Vector2.ONE, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(l, "position:y", l.position.y - 40.0, 0.9).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(l, "modulate:a", 0.0, 0.35).set_delay(0.55)
	tw.chain().tween_callback(l.queue_free)


## Borda vermelha na tela ao levar dano (0..1).
func damage_flash(strength: float) -> void:
	if _vignette_tween != null and _vignette_tween.is_valid():
		_vignette_tween.kill()
	_vignette.modulate.a = clampf(0.45 + strength, 0.45, 1.0)
	_vignette_tween = create_tween()
	_vignette_tween.tween_property(_vignette, "modulate:a", 0.0, 0.7)


## Tela de fim. stats: score, best, new_record, time, duration, max_cells,
## collected, destroyed.
func show_game_over(stats: Dictionary) -> void:
	set_playing(false)
	_hint.visible = false
	race_bar.get_parent().visible = false
	var dim := ColorRect.new()
	dim.color = Color(0.0, 0.0, 0.02, 0.65)
	var overlay := UISkin.replace("backdrop_game_over", dim, true)
	_root.add_child(overlay)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var center := CenterContainer.new()
	overlay.add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	# Painel grande em chevron, com as pontas bem marcadas.
	var panel := PanelContainer.new()
	var style := UIStyle.tab(["panel_game_over", "tab"], UIStyle.RED, 44.0)
	style.content_margin_left = 64.0
	style.content_margin_right = 64.0
	style.content_margin_top = 24.0
	style.content_margin_bottom = 24.0
	panel.add_theme_stylebox_override("panel", style)
	center.add_child(panel)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 12)
	col.custom_minimum_size.x = 420
	panel.add_child(col)

	col.add_child(_centered(UIStyle.label("GAME OVER", 11, UIStyle.TEXT_DIM, UIStyle.CAPTION)))
	col.add_child(_centered(UIStyle.label("NÚCLEO DESTRUÍDO", 26, UIStyle.RED, UIStyle.DISPLAY)))
	if stats.new_record:
		var rec := _centered(UIStyle.label("NOVO RECORDE!", 13, UIStyle.GOLD, UIStyle.CAPTION))
		col.add_child(rec)
		var tw := rec.create_tween().set_loops()
		tw.tween_property(rec, "modulate:a", 0.35, 0.5)
		tw.tween_property(rec, "modulate:a", 1.0, 0.5)

	# Destaque: quanto faltava para a chegada (ou se ela foi alcancada).
	var left: float = maxf(stats.duration - stats.time, 0.0)
	var race := HBoxContainer.new()
	race.alignment = BoxContainer.ALIGNMENT_CENTER
	race.add_theme_constant_override("separation", 10)
	if left > 0.0:
		race.add_child(UIStyle.label("FALTAVAM", 11, UIStyle.TEXT_DIM, UIStyle.CAPTION))
		race.add_child(UIStyle.label(UIStyle.fmt_time(ceili(left)), 20, UIStyle.GOLD, UIStyle.DISPLAY))
		race.add_child(UIStyle.label("PARA A CHEGADA", 11, UIStyle.TEXT_DIM, UIStyle.CAPTION))
	else:
		race.add_child(UIStyle.label("CHEGADA ALCANÇADA", 14, UIStyle.GOLD, UIStyle.DISPLAY))
	for l in race.get_children():
		l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	col.add_child(race)

	col.add_child(_rule())
	var rows := [
		["PONTOS", UIStyle.fmt_int(stats.score), UIStyle.GOLD],
		["RECORDE", UIStyle.fmt_int(stats.best), UIStyle.GOLD],
		["TEMPO", UIStyle.fmt_time(stats.time), UIStyle.TEXT],
		["MAIOR NAVE", "%d %s" % [stats.max_cells, "hexágono" if stats.max_cells == 1 else "hexágonos"], UIStyle.CYAN],
		["HEXÁGONOS COLETADOS", UIStyle.fmt_int(stats.collected), UIStyle.GREEN],
		["ASTEROIDES DESTRUÍDOS", UIStyle.fmt_int(stats.destroyed), UIStyle.TEXT],
	]
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 32)
	grid.add_theme_constant_override("v_separation", 6)
	col.add_child(grid)
	for r in rows:
		grid.add_child(UIStyle.label(r[0], 11, UIStyle.TEXT_DIM, UIStyle.CAPTION))
		var v := UIStyle.label(r[1], 15, r[2], UIStyle.DISPLAY)
		v.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grid.add_child(v)
	col.add_child(_rule())

	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", 14)
	col.add_child(buttons)
	var restart := UIStyle.button("JOGAR NOVAMENTE   [R]")
	restart.custom_minimum_size.x = 220
	restart.pressed.connect(restart_requested.emit)
	var menu := UIStyle.button("MENU PRINCIPAL")
	menu.custom_minimum_size.x = 180
	menu.pressed.connect(menu_requested.emit)
	buttons.add_child(restart)
	buttons.add_child(menu)

	overlay.modulate.a = 0.0
	var fade := overlay.create_tween()
	fade.tween_interval(0.6)  # deixa a explosao aparecer antes
	fade.tween_property(overlay, "modulate:a", 1.0, 0.4)
	fade.tween_callback(restart.grab_focus)


static func _centered(l: Label) -> Label:
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return l


## Filete geometrico: linha fina com um losango no meio.
static func _rule() -> Control:
	var rule := RuleLine.new()
	rule.custom_minimum_size.y = 10
	return rule


class RuleLine extends Control:
	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var y := size.y * 0.5
		var c := Vector2(size.x * 0.5, y)
		draw_line(Vector2(0, y), c - Vector2(8, 0), Color(UIStyle.RED, 0.45), 1.0, true)
		draw_line(c + Vector2(8, 0), Vector2(size.x, y), Color(UIStyle.RED, 0.45), 1.0, true)
		draw_colored_polygon(PackedVector2Array([c + Vector2(-5, 0), c + Vector2(0, -4), c + Vector2(5, 0), c + Vector2(0, 4)]),
			Color(UIStyle.RED, 0.8))


## Sprite "damage_vignette" esticado na tela; placeholder: gradiente radial.
func _build_vignette() -> void:
	var tex := UISkin.texture("damage_vignette")
	if tex == null:
		var grad := Gradient.new()
		grad.set_color(0, Color(UIStyle.RED, 0.0))
		grad.set_color(1, Color(UIStyle.RED, 0.55))
		grad.add_point(0.6, Color(UIStyle.RED, 0.0))
		var gradient_tex := GradientTexture2D.new()
		gradient_tex.gradient = grad
		gradient_tex.fill = GradientTexture2D.FILL_RADIAL
		gradient_tex.fill_from = Vector2(0.5, 0.5)
		gradient_tex.fill_to = Vector2(1.0, 1.0)
		tex = gradient_tex
	_vignette = TextureRect.new()
	_vignette.texture = tex
	_vignette.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_vignette.stretch_mode = TextureRect.STRETCH_SCALE
	_vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_vignette.modulate.a = 0.0
	_root.add_child(_vignette)
	_vignette.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


## Mira que segue o mouse (slot "reticle", centrado na ponta do mouse).
## Placeholder: hexagono girando com tres tracos.
class Reticle extends UISprite:
	const SIZE := 42.0
	var _t := 0.0

	func _init() -> void:
		super("reticle", Vector2.ONE * SIZE)
		size = custom_minimum_size

	func _process(delta: float) -> void:
		_t += delta
		position = get_parent_control().get_local_mouse_position() - size * 0.5
		queue_redraw()

	func _draw_placeholder() -> void:
		var m := size * 0.5
		var r := 11.0
		var pts := PackedVector2Array()
		for i in 7:
			pts.append(m + Vector2.from_angle(_t * 1.2 + i * TAU / 6.0) * r)
		draw_polyline(pts, Color(color, 0.9), 1.5, true)
		for i in 3:
			var d := Vector2.from_angle(-_t * 0.8 + i * TAU / 3.0)
			draw_line(m + d * (r + 4.0), m + d * (r + 9.0), Color(color, 0.6), 1.5, true)
		draw_circle(m, 2.0, UIStyle.GOLD)
