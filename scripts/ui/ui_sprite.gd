class_name UISprite
extends Control
## Objeto de UI com espaco reservado para um sprite proprio.
## Se o slot tiver arquivo em art/ui/ (ver UISkin), desenha o sprite
## encaixado no tamanho do controle, mantendo a proporcao; senao desenha o
## placeholder de _draw_placeholder(). Subclasses so implementam o
## placeholder e, se quiserem, animam sprite_angle / sprite_scale.

## Nome do slot em UISkin.SLOTS ("" = sempre placeholder).
var slot := "":
	set(value):
		slot = value
		texture = UISkin.texture(slot) if slot != "" else null
		queue_redraw()
## Cor do placeholder (o sprite e desenhado com as cores dele).
var color := UIStyle.CYAN
## Giro e escala do sprite, em volta do centro do controle.
var sprite_angle := 0.0
var sprite_scale := 1.0
var texture: Texture2D


func _init(slot_name: String = "", min_size: Vector2 = Vector2(32, 32)) -> void:
	custom_minimum_size = min_size
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	slot = slot_name


func has_sprite() -> bool:
	return texture != null


func _draw() -> void:
	if texture == null:
		_draw_placeholder()
		return
	var tex_size := texture.get_size()
	var fit := minf(size.x / tex_size.x, size.y / tex_size.y)
	draw_set_transform(size * 0.5, sprite_angle, Vector2.ONE * sprite_scale)
	draw_texture_rect(texture, Rect2(-tex_size * fit * 0.5, tex_size * fit), false)
	draw_set_transform(Vector2.ZERO)


## Desenho provisorio. O padrao e uma caixa com um X, para o slot aparecer
## na tela mesmo sem placeholder proprio.
func _draw_placeholder() -> void:
	var r := Rect2(Vector2.ONE, size - Vector2.ONE * 2.0)
	draw_rect(r, Color(color, 0.8), false, 1.0)
	draw_line(r.position, r.end, Color(color, 0.4), 1.0)
	draw_line(Vector2(r.end.x, r.position.y), Vector2(r.position.x, r.end.y), Color(color, 0.4), 1.0)
