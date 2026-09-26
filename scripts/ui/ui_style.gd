class_name UIStyle
extends RefCounted
## Paleta, fontes e estilos compartilhados por toda a interface.
## Paineis, botoes e chips usam a moldura de hexagonos (HexFrame), na cor do
## conteudo; um sprite de slot proprio (UISkin) tem prioridade sobre ela.

const CYAN := Color(0.3, 0.8, 1.0)
const GOLD := Color(1.0, 0.85, 0.35)
const GREEN := Color(0.35, 1.0, 0.55)
const RED := Color(1.0, 0.32, 0.28)
const TEXT := Color(0.9, 0.97, 1.0)
const TEXT_DIM := Color(0.55, 0.72, 0.85)
const PANEL_BG := Color(0.02, 0.05, 0.1, 0.8)
## Roxo da moldura de hexagonos original (paineis e botoes neutros).
const PURPLE := Color(0.46, 0.3, 1.0)

## Tipos de fonte aceitos por label().
enum { BODY, CAPTION, DISPLAY }

## Hexagon e a fonte do jogo (CC BY-NC-SA 3.0, ver fonts/Hexagon-*.txt).
## Ela so tem letras sem acento: os textos passam por plain() antes de
## aparecer, e numeros/pontuacao saem da Orbitron leve (SIL OFL), a reserva.
const HEXAGON := preload("res://fonts/Hexagon.otf")
const ORBITRON := preload("res://fonts/Orbitron.ttf")
const _ACCENTS := {
	"á": "a", "à": "a", "â": "a", "ã": "a", "ä": "a",
	"é": "e", "è": "e", "ê": "e", "ë": "e",
	"í": "i", "ì": "i", "î": "i", "ï": "i",
	"ó": "o", "ò": "o", "ô": "o", "õ": "o", "ö": "o",
	"ú": "u", "ù": "u", "û": "u", "ü": "u", "ç": "c",
	"Á": "A", "À": "A", "Â": "A", "Ã": "A", "Ä": "A",
	"É": "E", "È": "E", "Ê": "E", "Ë": "E",
	"Í": "I", "Ì": "I", "Î": "I", "Ï": "I",
	"Ó": "O", "Ò": "O", "Ô": "O", "Õ": "O", "Ö": "O",
	"Ú": "U", "Ù": "U", "Û": "U", "Ü": "U", "Ç": "C",
}

static var _body_font: Font
static var _display_font: Font
static var _caption_font: Font
static var _upper_font: Font
static var _theme: Theme


## Texto corrido: regras, descricoes, teclas.
static func font() -> Font:
	if _body_font == null:
		_body_font = _hexagon(0.0, 0, 400)
	return _body_font


## Titulos, numeros do HUD, botoes e textos flutuantes (traco mais grosso).
static func display_font() -> Font:
	if _display_font == null:
		_display_font = _hexagon(0.9, 1, 700)
	return _display_font


## Legendas, com espacamento largo.
static func caption_font() -> Font:
	if _caption_font == null:
		_caption_font = _hexagon(0.4, 3, 500)
	return _caption_font


## Letras que precisam aparecer em maiusculo (a Hexagon desenha maiusculas
## e minusculas iguais, com cara de minuscula): saem na Orbitron. Ex.: a
## tecla R de girar a nave.
static func upper_font() -> Font:
	if _upper_font == null:
		var f := FontVariation.new()
		f.base_font = ORBITRON
		var wght := TextServerManager.get_primary_interface().name_to_tag("wght")
		f.variation_opentype = {wght: 700}
		_upper_font = f
	return _upper_font


## Teclas mostradas sempre em maiusculo (na Orbitron, ver upper_font).
const UPPERCASE_KEYS := ["R"]


## Texto sem acentos (a Hexagon nao tem letras acentuadas).
static func plain(text: String) -> String:
	var out := ""
	for c in text:
		out += _ACCENTS.get(c, c)
	return out


static func _hexagon(embolden: float, spacing: int, fallback_weight: int) -> Font:
	var reserve := FontVariation.new()
	reserve.base_font = ORBITRON
	var wght := TextServerManager.get_primary_interface().name_to_tag("wght")
	reserve.variation_opentype = {wght: fallback_weight}
	var f := FontVariation.new()
	f.base_font = HEXAGON
	f.variation_embolden = embolden
	f.spacing_glyph = spacing
	f.fallbacks = [reserve]
	return f


## Moldura de painel: sprite do slot (ou do primeiro de uma lista de slots)
## ou, sem sprite, a moldura de hexagonos (HexFrame) na cor do conteudo e na
## espessura `scale`.
static func frame(slots: Variant, accent: Color = PURPLE, scale: float = HexFrame.MEDIUM, pad: float = 6.0) -> StyleBox:
	return UISkin.stylebox(slots, HexFrame.style(HexFrame.fill_for(accent), scale, pad))


static func label(text: String, size: int, color: Color = TEXT, kind: int = BODY) -> Label:
	var l := Label.new()
	l.text = plain(text)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	match kind:
		CAPTION:
			l.add_theme_font_override("font", caption_font())
		DISPLAY:
			l.add_theme_font_override("font", display_font())
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


## "Tecla" desenhada como um pequeno chip (usada na tela de info).
## "UP", "DOWN", "LEFT" e "RIGHT" viram setas desenhadas.
static func key_chip(text: String) -> PanelContainer:
	var chip := PanelContainer.new()
	chip.add_theme_stylebox_override("panel", frame("key", CYAN, HexFrame.THIN, 2.0))
	if text in ARROWS:
		chip.add_child(ArrowGlyph.new(ARROWS[text]))
	else:
		var l := label(text, 12, TEXT)
		l.add_theme_font_override("font", upper_font() if text in UPPERCASE_KEYS else display_font())
		chip.add_child(l)
	return chip


const ARROWS := {"UP": -PI / 2, "DOWN": PI / 2, "LEFT": PI, "RIGHT": 0.0}


## Seta do teclado (slot "key_arrow", desenhado apontando para a direita e
## girado); o placeholder e um triangulo.
class ArrowGlyph extends UISprite:
	func _init(angle: float) -> void:
		super("key_arrow", Vector2(12, 18))
		color = UIStyle.TEXT
		sprite_angle = angle

	func _draw_placeholder() -> void:
		var c := size * 0.5
		var pts := PackedVector2Array()
		for p in [Vector2(5, 0), Vector2(-4, -5), Vector2(-4, 5)]:
			pts.append(c + p.rotated(sprite_angle))
		draw_colored_polygon(pts, color)


static func button(text: String) -> Button:
	var b := Button.new()
	b.text = plain(text)
	b.custom_minimum_size = Vector2(240, 40)
	b.focus_mode = Control.FOCUS_ALL
	# Hover e foco de teclado ficam sempre no mesmo botao.
	b.mouse_entered.connect(b.grab_focus)
	return b


static func theme() -> Theme:
	if _theme != null:
		return _theme
	var t := Theme.new()
	t.default_font = font()
	t.default_font_size = 17
	t.set_color("font_color", "Label", TEXT)

	# Botoes: a moldura de hexagonos fina; roxo parado, ciano com o mouse/foco
	# (o foco e desenhado por cima do "normal") e dourado apertado.
	var normal := HexFrame.style(HexFrame.fill_for(PURPLE).darkened(0.15), HexFrame.SMALL, 8.0)
	var hover := HexFrame.style(HexFrame.fill_for(CYAN), HexFrame.SMALL, 8.0)
	var pressed := HexFrame.style(HexFrame.fill_for(GOLD), HexFrame.SMALL, 8.0)
	var focus := hover

	# Estados sem sprite proprio usam o do estado mais proximo.
	t.set_stylebox("normal", "Button", UISkin.stylebox("button_normal", normal))
	t.set_stylebox("hover", "Button", UISkin.stylebox(["button_hover", "button_normal"], hover))
	var pressed_box := UISkin.stylebox(["button_pressed", "button_hover", "button_normal"], pressed)
	t.set_stylebox("pressed", "Button", pressed_box)
	t.set_stylebox("hover_pressed", "Button", pressed_box)
	t.set_stylebox("focus", "Button", UISkin.stylebox(["button_focus", "button_hover"], focus))
	t.set_font("font", "Button", display_font())
	t.set_font_size("font_size", "Button", 13)
	t.set_color("font_color", "Button", TEXT)
	t.set_color("font_hover_color", "Button", Color.WHITE)
	t.set_color("font_focus_color", "Button", Color.WHITE)
	t.set_color("font_pressed_color", "Button", Color.WHITE)
	t.set_color("font_hover_pressed_color", "Button", Color.WHITE)
	t.set_stylebox("panel", "PanelContainer", frame("panel"))
	var separator := UISkin.texture("separator")
	if separator != null:
		# Estica so na largura: a altura do sprite fica inteira.
		var line := StyleBoxTexture.new()
		line.texture = separator
		line.texture_margin_top = floorf(separator.get_height() * 0.5)
		line.texture_margin_bottom = separator.get_height() - line.texture_margin_top
		t.set_stylebox("separator", "HSeparator", line)
		t.set_constant("separation", "HSeparator", int(separator.get_height()))
	_theme = t
	return t


## 12345 -> "12.345"
static func fmt_int(n: int) -> String:
	var s := str(absi(n))
	var out := ""
	while s.length() > 3:
		out = "." + s.substr(s.length() - 3) + out
		s = s.substr(0, s.length() - 3)
	return ("-" if n < 0 else "") + s + out


static func fmt_time(t: float) -> String:
	return "%d:%02d" % [int(t / 60.0), int(t) % 60]
