class_name Hud
extends CanvasLayer
## Interface durante o jogo: cards de status, linha de chegada no rodape,
## textos flutuantes, vinheta de dano, mira hexagonal e tela de game over.

signal restart_requested
signal menu_requested

var cells_card: StatCard
var time_card: StatCard
var cannon_card: CannonCard
var race_bar: RaceBar

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
	_root.theme = UIStyle.theme()
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
	cells_card = StatCard.new("HEXÁGONOS", UIStyle.CYAN, "cells")
	cannon_card = CannonCard.new()
	time_card = StatCard.new("TEMPO", UIStyle.TEXT_DIM, "time")
	time_card.icon.spin_speed = 1.2
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for c in [cells_card, cannon_card, spacer, time_card]:
		row.add_child(c)

	# Linha de chegada: 60% da largura, centrada no rodape.
	race_bar = RaceBar.new()
	_root.add_child(race_bar)
	race_bar.anchor_left = 0.2
	race_bar.anchor_right = 0.8
	race_bar.anchor_top = 1.0
	race_bar.anchor_bottom = 1.0
	race_bar.offset_top = -50.0
	race_bar.offset_bottom = -12.0

	_hint = UIStyle.label("ESC  pausar / info", 11, Color(UIStyle.TEXT_DIM, 0.6), UIStyle.CAPTION)
	_root.add_child(_hint)
	_hint.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT, Control.PRESET_MODE_MINSIZE, 16)

	_reticle = Reticle.new()
	_root.add_child(_reticle)
	set_playing(true)


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


## stats: score, best, new_record, time, max_cells, collected, destroyed
func show_game_over(stats: Dictionary) -> void:
	set_playing(false)
	_hint.visible = false
	race_bar.visible = false
	var dim := ColorRect.new()
	dim.color = Color(0.0, 0.0, 0.02, 0.6)
	var overlay := UISkin.replace("backdrop_game_over", dim, true)
	_root.add_child(overlay)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var center := CenterContainer.new()
	overlay.add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var panel := PanelContainer.new()
	var style := UIStyle.frame(["panel_game_over", "panel"], UIStyle.RED, UIStyle.PANEL_BG, 16)
	style.set_content_margin_all(24)
	panel.add_theme_stylebox_override("panel", style)
	center.add_child(panel)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	panel.add_child(col)

	var sub := UIStyle.label("GAME OVER", 11, UIStyle.TEXT_DIM, UIStyle.CAPTION)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(sub)
	var title := UIStyle.label("NÚCLEO DESTRUÍDO", 24, UIStyle.RED, UIStyle.DISPLAY)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(title)

	if stats.new_record:
		var rec := UIStyle.label("NOVO RECORDE!", 13, UIStyle.GOLD, UIStyle.CAPTION)
		rec.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		col.add_child(rec)
		var tw := rec.create_tween().set_loops()
		tw.tween_property(rec, "modulate:a", 0.35, 0.5)
		tw.tween_property(rec, "modulate:a", 1.0, 0.5)

	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 32)
	grid.add_theme_constant_override("v_separation", 5)
	col.add_child(grid)
	var rows := [
		["PONTOS", UIStyle.fmt_int(stats.score), UIStyle.GOLD],
		["RECORDE", UIStyle.fmt_int(stats.best), UIStyle.GOLD],
		["TEMPO", UIStyle.fmt_time(stats.time), UIStyle.TEXT],
		["MAIOR NAVE", "%d %s" % [stats.max_cells, "hexágono" if stats.max_cells == 1 else "hexágonos"], UIStyle.CYAN],
		["HEXÁGONOS COLETADOS", UIStyle.fmt_int(stats.collected), UIStyle.GREEN],
		["ASTEROIDES DESTRUÍDOS", UIStyle.fmt_int(stats.destroyed), UIStyle.TEXT],
	]
	for r in rows:
		grid.add_child(UIStyle.label(r[0], 11, UIStyle.TEXT_DIM, UIStyle.CAPTION))
		var v := UIStyle.label(r[1], 14, r[2], UIStyle.DISPLAY)
		v.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grid.add_child(v)

	var restart := UIStyle.button("JOGAR NOVAMENTE   [R]")
	restart.pressed.connect(restart_requested.emit)
	var menu := UIStyle.button("MENU PRINCIPAL")
	menu.pressed.connect(menu_requested.emit)
	col.add_child(HSeparator.new())
	col.add_child(restart)
	col.add_child(menu)
	restart.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	menu.size_flags_horizontal = Control.SIZE_SHRINK_CENTER

	overlay.modulate.a = 0.0
	var fade := overlay.create_tween()
	fade.tween_interval(0.6)  # deixa a explosao aparecer antes
	fade.tween_property(overlay, "modulate:a", 1.0, 0.4)
	fade.tween_callback(restart.grab_focus)


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
