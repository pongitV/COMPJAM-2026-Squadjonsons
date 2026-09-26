class_name TutorialPanel
extends CanvasLayer
## Caixa de texto do tutorial, pequena e embaixo (logo acima da linha de
## chegada), para nao tampar o inimigo nem os pedacos: etapa, titulo,
## explicacao e o aviso de como pular. Aparece e some com um fade que usa o
## tempo real (continua suave durante a camera lenta). No texto, as marcas de
## KEYS viram chips de tecla/mouse (UIStyle.key_chip) no meio das palavras.

const WIDTH := 420.0
## Distancia da borda de baixo da tela (acima da linha de chegada).
const BOTTOM := 76.0
const FADE := 0.25
const FONT_SIZE := 12
## Chips no meio do texto: tamanho da letra e espessura da moldura.
const CHIP_FONT := 10
const CHIP_FRAME := 0.17
## Marca no texto -> tecla do chip.
const KEYS := {
	"{R}": "R", "{ENTER}": "ENTER",
	"{LMB}": "MOUSE_LEFT", "{RMB}": "MOUSE_RIGHT", "{WHEEL}": "MOUSE_WHEEL",
}

var _panel: PanelContainer
var _step: Label
var _title: Label
var _body: HFlowContainer
var _target_alpha := 0.0


func _init() -> void:
	layer = 6
	# O fade continua com o jogo pausado (ex.: janela das formacoes).
	process_mode = Node.PROCESS_MODE_ALWAYS


func _ready() -> void:
	var root := Control.new()
	root.theme = UIStyle.theme()
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	# Centralizada e crescendo para cima a partir de BOTTOM.
	var holder := CenterContainer.new()
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(holder)
	holder.anchor_left = 0.0
	holder.anchor_right = 1.0
	holder.anchor_top = 1.0
	holder.anchor_bottom = 1.0
	holder.grow_vertical = Control.GROW_DIRECTION_BEGIN
	holder.offset_top = -BOTTOM
	holder.offset_bottom = -BOTTOM

	_panel = PanelContainer.new()
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_theme_stylebox_override("panel",
		UIStyle.frame(["panel_tutorial", "panel"], UIStyle.CYAN, HexFrame.SMALL, 8.0))
	holder.add_child(_panel)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 3)
	_panel.add_child(col)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 10)
	_title = UIStyle.label("", 14, UIStyle.CYAN, UIStyle.DISPLAY)
	_step = UIStyle.label("", 9, UIStyle.TEXT_DIM, UIStyle.CAPTION)
	_step.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_step.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var skip := HBoxContainer.new()
	skip.add_theme_constant_override("separation", 5)
	skip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	skip.add_child(UIStyle.key_chip("ENTER", 8, 0.15, UIStyle.PURPLE))
	var skip_text := UIStyle.label("pular", 9, Color(UIStyle.TEXT_DIM, 0.7), UIStyle.CAPTION)
	skip_text.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	skip.add_child(skip_text)
	for c in [_title, _step, skip]:
		head.add_child(c)
	col.add_child(head)

	_body = HFlowContainer.new()
	_body.custom_minimum_size.x = WIDTH
	_body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var space := UIStyle.font().get_string_size(" ", HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE).x
	_body.add_theme_constant_override("h_separation", ceili(space))
	_body.add_theme_constant_override("v_separation", 2)
	col.add_child(_body)
	_panel.modulate.a = 0.0


## Mostra (ou troca) o texto. `step` e o rotulo pequeno ao lado do titulo.
func show_tip(step: String, title: String, body: String, color: Color = UIStyle.CYAN) -> void:
	_step.text = UIStyle.plain(step)
	_title.text = UIStyle.plain(title)
	_title.add_theme_color_override("font_color", color)
	_set_body(UIStyle.plain(body))
	_target_alpha = 1.0
	# Um pulinho a cada texto novo, para chamar atencao.
	_panel.modulate.a = minf(_panel.modulate.a, 0.35)


func hide_tip() -> void:
	_target_alpha = 0.0


func is_showing() -> bool:
	return _target_alpha > 0.0


## Texto corrido na Hexagon, uma palavra por Label (a quebra de linha fica
## com o HFlowContainer); cada marca de KEYS sai como um chip de tecla.
func _set_body(text: String) -> void:
	for c in _body.get_children():
		_body.remove_child(c)
		c.queue_free()
	for word in text.split(" ", false):
		if KEYS.has(word):
			var chip := UIStyle.key_chip(KEYS[word], CHIP_FONT, CHIP_FRAME, UIStyle.PURPLE)
			chip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			_body.add_child(chip)
			continue
		var l := UIStyle.label(word, FONT_SIZE)
		l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		_body.add_child(l)


func _process(delta: float) -> void:
	var real := delta / maxf(Engine.time_scale, 0.001)
	_panel.modulate.a = move_toward(_panel.modulate.a, _target_alpha, real / FADE)
