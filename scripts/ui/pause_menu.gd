class_name PauseMenu
extends CanvasLayer
## Menu de pausa (ESC): continuar, info (controles e regras) e sair.
## Roda com a árvore pausada (PROCESS_MODE_ALWAYS).

signal opened
signal resumed
signal quit_requested

## Desligado no game over.
var enabled := true

var _root: Control
var _main_panel: Control
var _info_panel: Control
var _resume_button: Button
var _info_back_button: Button


func _init() -> void:
	layer = 10
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false


func _ready() -> void:
	_ensure_pause_action()
	_root = Control.new()
	_root.theme = UIStyle.theme()
	add_child(_root)
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var dim := ColorRect.new()
	dim.color = Color(0.0, 0.01, 0.04, 0.7)
	_root.add_child(dim)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var center := CenterContainer.new()
	_root.add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	_main_panel = _build_main()
	_info_panel = _build_info()
	center.add_child(_main_panel)
	center.add_child(_info_panel)


## A ação "pause" fica no project.godot; se ela sumir (ex.: editor salvou
## uma versão antiga das configurações), registra ESC e P aqui.
func _ensure_pause_action() -> void:
	if InputMap.has_action("pause"):
		return
	InputMap.add_action("pause")
	for key in [KEY_ESCAPE, KEY_P]:
		var ev := InputEventKey.new()
		ev.physical_keycode = key
		InputMap.action_add_event("pause", ev)


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("pause"):
		return
	get_viewport().set_input_as_handled()
	if not visible:
		if enabled:
			open()
	elif _info_panel.visible:
		_show_main()
	else:
		resume()


func _notification(what: int) -> void:
	# Pausa sozinho se a janela perder o foco.
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and enabled and not visible:
		open()


func open() -> void:
	visible = true
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_show_main()
	_root.modulate.a = 0.0
	create_tween().tween_property(_root, "modulate:a", 1.0, 0.15)
	opened.emit()


func resume() -> void:
	visible = false
	get_tree().paused = false
	resumed.emit()


func _show_main() -> void:
	_info_panel.visible = false
	_main_panel.visible = true
	_pop_in(_main_panel)
	_resume_button.grab_focus()


func _show_info() -> void:
	_main_panel.visible = false
	_info_panel.visible = true
	_pop_in(_info_panel)
	_info_back_button.grab_focus()


func _pop_in(panel: Control) -> void:
	panel.pivot_offset = panel.size * 0.5
	panel.scale = Vector2.ONE * 0.94
	create_tween().tween_property(panel, "scale", Vector2.ONE, 0.18) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _make_panel(accent: Color) -> Array:
	var panel := PanelContainer.new()
	var style := UIStyle.panel(accent, UIStyle.PANEL_BG, 16)
	style.set_content_margin_all(24)
	panel.add_theme_stylebox_override("panel", style)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	panel.add_child(col)
	return [panel, col]


func _title(col: VBoxContainer, caption: String, text: String, color: Color) -> void:
	var head := HBoxContainer.new()
	head.alignment = BoxContainer.ALIGNMENT_CENTER
	head.add_theme_constant_override("separation", 12)
	head.add_child(HexIcon.new(color, 28))
	var titles := VBoxContainer.new()
	titles.add_theme_constant_override("separation", 2)
	titles.add_child(UIStyle.label(caption, 10, UIStyle.TEXT_DIM, UIStyle.CAPTION))
	titles.add_child(UIStyle.label(text, 22, color, UIStyle.DISPLAY))
	head.add_child(titles)
	col.add_child(head)
	col.add_child(HSeparator.new())


func _build_main() -> Control:
	var parts := _make_panel(UIStyle.CYAN)
	var col: VBoxContainer = parts[1]
	_title(col, "HEX ASTEROIDS", "PAUSADO", UIStyle.CYAN)

	_resume_button = UIStyle.button("CONTINUAR")
	_resume_button.pressed.connect(resume)
	var info := UIStyle.button("INFO")
	info.pressed.connect(_show_info)
	var quit := UIStyle.button("SAIR DO JOGO")
	quit.pressed.connect(quit_requested.emit)
	for b in [_resume_button, info, quit]:
		col.add_child(b)
	return parts[0]


func _build_info() -> Control:
	var parts := _make_panel(UIStyle.GREEN)
	var col: VBoxContainer = parts[1]
	_title(col, "INFO", "MANUAL", UIStyle.GREEN)

	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 24)
	col.add_child(columns)
	var left := VBoxContainer.new()
	left.add_theme_constant_override("separation", 10)
	var right := VBoxContainer.new()
	right.add_theme_constant_override("separation", 10)
	columns.add_child(left)
	columns.add_child(VSeparator.new())
	columns.add_child(right)

	# Coluna esquerda: controles e regras gerais.
	left.add_child(UIStyle.label("CONTROLES", 10, UIStyle.TEXT_DIM, UIStyle.CAPTION))
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 16)
	grid.add_theme_constant_override("v_separation", 8)
	left.add_child(grid)
	var controls := [
		[["W", "A", "S", "D"], "Mover"],
		[["UP", "LEFT", "DOWN", "RIGHT"], "Mover (alternativo)"],
		[["Clique esquerdo"], "Atirar (segure)"],
		[["ESC"], "Pausar / voltar"],
		[["R"], "Reiniciar após o game over"],
	]
	for c in controls:
		var keys := HBoxContainer.new()
		keys.add_theme_constant_override("separation", 6)
		for k in c[0]:
			keys.add_child(UIStyle.key_chip(k))
		grid.add_child(keys)
		var action := UIStyle.label(c[1], 17)
		action.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		grid.add_child(action)

	left.add_child(HSeparator.new())
	left.add_child(UIStyle.label("COMO JOGAR", 10, UIStyle.TEXT_DIM, UIStyle.CAPTION))
	_rule(left, UIStyle.GOLD, "", "O hexágono dourado é o seu núcleo. Se ele for destruído, é fim de jogo.")
	_rule(left, Color(0.7, 0.6, 0.5), "", "Um asteroide de N hexágonos aguenta N^1,5 de dano. Se bater na nave, destrói N hexágonos seus.")
	_rule(left, UIStyle.GREEN, "", "Asteroides destruídos soltam minério. O verde vira casco; o colorido vira um canhão daquela cor.")

	# Coluna direita: canhões.
	right.add_child(UIStyle.label("CANHÕES", 10, UIStyle.TEXT_DIM, UIStyle.CAPTION))
	_rule(right, Weapons.color(Weapons.COMMON), "COMUM",
		"Tiro único na mira. Você ganha 1 a cada %d asteroides destruídos. Fica sempre na borda da nave." % Weapons.ASTEROIDS_PER_COMMON)
	_rule(right, Weapons.color(Weapons.SHOTGUN), "SHOTGUN", "6 tiros em leque, de alcance curto.")
	_rule(right, Weapons.color(Weapons.LASER), "LASER", "Raio para fora da nave, com dano contínuo por 3 segundos.")
	_rule(right, Weapons.color(Weapons.BOMB), "BOMBA", "Míssil lento que explode na mira ou ao tocar um asteroide, com dano em área.")
	_rule(right, Weapons.color(Weapons.NONE), "CASCO", "Hexágono sem canhão. Não atira, mas protege o núcleo.")

	_info_back_button = UIStyle.button("VOLTAR")
	_info_back_button.pressed.connect(_show_main)
	_info_back_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	col.add_child(HSeparator.new())
	col.add_child(_info_back_button)
	return parts[0]


## Linha do manual: hexágono colorido + título opcional + descrição.
func _rule(parent: VBoxContainer, color: Color, title: String, text: String) -> void:
	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", 10)
	var icon := HexIcon.new(color, 16)
	icon.spin_speed = 0.0
	icon.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	line.add_child(icon)
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 0)
	if title != "":
		body.add_child(UIStyle.label(title, 12, color, UIStyle.DISPLAY))
	var desc := UIStyle.label(text, 16, UIStyle.TEXT)
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.custom_minimum_size.x = 340
	body.add_child(desc)
	line.add_child(body)
	parent.add_child(line)
