class_name PauseMenu
extends CanvasLayer
## Menu de pausa (ESC): continuar, info (controles e regras), voltar ao menu
## principal e sair.
## Roda com a arvore pausada (PROCESS_MODE_ALWAYS).

signal opened
signal resumed
signal menu_requested
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
	_root = Control.new()
	_root.theme = UIStyle.theme()
	add_child(_root)
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var dim_color := ColorRect.new()
	dim_color.color = Color(0.0, 0.01, 0.04, 0.7)
	var dim := UISkin.replace("backdrop_pause", dim_color, true)
	_root.add_child(dim)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var center := CenterContainer.new()
	_root.add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	_main_panel = _build_main()
	var manual := Manual.build()
	_info_panel = manual[0]
	_info_back_button = manual[1]
	_info_back_button.pressed.connect(_show_main)
	center.add_child(_main_panel)
	center.add_child(_info_panel)


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
	# O manual pode ter reduzido o container que os dois paineis dividem.
	(_main_panel.get_parent() as Control).scale = Vector2.ONE
	_pop_in(_main_panel)
	_resume_button.grab_focus()


func _show_info() -> void:
	_main_panel.visible = false
	_info_panel.visible = true
	Manual.fit(_info_panel)
	_info_back_button.grab_focus()


func _pop_in(panel: Control) -> void:
	panel.pivot_offset = panel.size * 0.5
	panel.scale = Vector2.ONE * 0.94
	create_tween().tween_property(panel, "scale", Vector2.ONE, 0.18) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _build_main() -> Control:
	var parts := Manual.make_panel("panel_pause", UIStyle.CYAN)
	var col: VBoxContainer = parts[1]
	Manual.title(col, "icon_pause", "HEXCORE", "PAUSADO", UIStyle.CYAN)

	_resume_button = UIStyle.button("CONTINUAR")
	_resume_button.pressed.connect(resume)
	var info := UIStyle.button("INFO")
	info.pressed.connect(_show_info)
	var menu := UIStyle.button("MENU PRINCIPAL")
	menu.pressed.connect(menu_requested.emit)
	var quit := UIStyle.button("SAIR DO JOGO")
	quit.pressed.connect(quit_requested.emit)
	for b in [_resume_button, info, menu, quit]:
		col.add_child(b)
	return parts[0]
