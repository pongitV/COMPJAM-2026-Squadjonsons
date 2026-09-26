class_name UIStyle
extends RefCounted
## Paleta, fontes e estilos compartilhados por toda a interface.
## Cantos chanfrados (corner_detail = 1) ecoam o formato dos hexágonos.

const CYAN := Color(0.3, 0.8, 1.0)
const GOLD := Color(1.0, 0.85, 0.35)
const GREEN := Color(0.35, 1.0, 0.55)
const RED := Color(1.0, 0.32, 0.28)
const TEXT := Color(0.9, 0.97, 1.0)
const TEXT_DIM := Color(0.55, 0.72, 0.85)
const PANEL_BG := Color(0.02, 0.05, 0.1, 0.8)

## Tipos de fonte aceitos por label().
enum { BODY, CAPTION, DISPLAY }

## Hexagon é a fonte do jogo (CC BY-NC-SA 3.0, ver fonts/Hexagon-*.txt).
## Ela só tem letras sem acento: os textos passam por plain() antes de
## aparecer, e números/pontuação saem da Orbitron leve (SIL OFL), a reserva.
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
static var _theme: Theme


## Texto corrido: regras, descrições, teclas.
static func font() -> Font:
	if _body_font == null:
		_body_font = _hexagon(0.0, 0, 400)
	return _body_font


## Títulos, números do HUD, botões e textos flutuantes (traço mais grosso).
static func display_font() -> Font:
	if _display_font == null:
		_display_font = _hexagon(0.9, 1, 700)
	return _display_font


## Legendas, com espaçamento largo.
static func caption_font() -> Font:
	if _caption_font == null:
		_caption_font = _hexagon(0.4, 3, 500)
	return _caption_font


## Texto sem acentos (a Hexagon não tem letras acentuadas).
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


static func panel(accent: Color = CYAN, bg: Color = PANEL_BG, cut: int = 10) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = Color(accent, 0.55)
	s.set_border_width_all(1)
	s.border_width_left = 3
	s.set_corner_radius_all(cut)
	s.corner_detail = 1
	s.content_margin_left = 14
	s.content_margin_right = 18
	s.content_margin_top = 12
	s.content_margin_bottom = 12
	s.shadow_color = Color(accent, 0.15)
	s.shadow_size = 10
	return s


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
	var s := StyleBoxFlat.new()
	s.bg_color = Color(CYAN, 0.12)
	s.border_color = Color(CYAN, 0.7)
	s.set_border_width_all(1)
	s.border_width_bottom = 3
	s.set_corner_radius_all(5)
	s.corner_detail = 1
	s.content_margin_left = 8
	s.content_margin_right = 8
	s.content_margin_top = 4
	s.content_margin_bottom = 5
	chip.add_theme_stylebox_override("panel", s)
	if text in ARROWS:
		chip.add_child(ArrowGlyph.new(ARROWS[text]))
	else:
		var l := label(text, 12, TEXT)
		l.add_theme_font_override("font", display_font())
		chip.add_child(l)
	return chip


const ARROWS := {"UP": -PI / 2, "DOWN": PI / 2, "LEFT": PI, "RIGHT": 0.0}


## Triângulo apontando na direção de uma seta do teclado.
class ArrowGlyph extends Control:
	var _angle := 0.0

	func _init(angle: float) -> void:
		_angle = angle
		custom_minimum_size = Vector2(12, 18)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var c := size * 0.5
		var pts := PackedVector2Array()
		for p in [Vector2(5, 0), Vector2(-4, -5), Vector2(-4, 5)]:
			pts.append(c + p.rotated(_angle))
		draw_colored_polygon(pts, UIStyle.TEXT)


static func button(text: String) -> Button:
	var b := Button.new()
	b.text = plain(text)
	b.custom_minimum_size = Vector2(240, 40)
	b.focus_mode = Control.FOCUS_ALL
	# Hover e foco de teclado ficam sempre no mesmo botão.
	b.mouse_entered.connect(b.grab_focus)
	return b


static func theme() -> Theme:
	if _theme != null:
		return _theme
	var t := Theme.new()
	t.default_font = font()
	t.default_font_size = 17
	t.set_color("font_color", "Label", TEXT)

	var normal := panel(CYAN, Color(0.04, 0.09, 0.16, 0.9), 8)
	normal.border_width_left = 1
	normal.shadow_size = 0
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = Color(CYAN, 0.2)
	hover.border_color = CYAN
	hover.border_width_left = 4
	hover.shadow_color = Color(CYAN, 0.35)
	hover.shadow_size = 14
	var pressed := hover.duplicate() as StyleBoxFlat
	pressed.bg_color = Color(CYAN, 0.4)
	# Foco (teclado) tem o mesmo visual do hover; é desenhado sobre o "normal".
	var focus := hover.duplicate() as StyleBoxFlat
	focus.bg_color = Color(CYAN, 0.15)

	t.set_stylebox("normal", "Button", normal)
	t.set_stylebox("hover", "Button", hover)
	t.set_stylebox("pressed", "Button", pressed)
	t.set_stylebox("hover_pressed", "Button", pressed)
	t.set_stylebox("focus", "Button", focus)
	t.set_font("font", "Button", display_font())
	t.set_font_size("font_size", "Button", 13)
	t.set_color("font_color", "Button", TEXT)
	t.set_color("font_hover_color", "Button", Color.WHITE)
	t.set_color("font_focus_color", "Button", Color.WHITE)
	t.set_color("font_pressed_color", "Button", GOLD)
	t.set_color("font_hover_pressed_color", "Button", GOLD)
	t.set_stylebox("panel", "PanelContainer", panel())
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
