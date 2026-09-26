class_name Starfield
extends Node2D
## Fundo de estrelas com parallax, desenhado em espaco de tela.

const TILE := 1024.0
const COUNT := 220

var cam_pos := Vector2.ZERO
## [posicao no tile, fator de parallax, tamanho, alpha]
var _stars := []
## Todas as estrelas vao numa so chamada de desenho.
var _batch := TriBatch.new()


func _ready() -> void:
	for i in COUNT:
		var depth := randf()
		_stars.append([
			Vector2(randf() * TILE, randf() * TILE),
			lerpf(0.05, 0.4, depth),
			lerpf(1.0, 2.5, depth),
			lerpf(0.25, 0.9, depth),
		])


func _draw() -> void:
	var screen := get_viewport_rect().size
	_batch.clear()
	for s in _stars:
		var p: Vector2 = (s[0] - cam_pos * s[1]).posmod(TILE)
		var size := Vector2(s[2], s[2])
		var color := Color(1, 1, 1, s[3])
		var x := p.x
		while x < screen.x:
			var y := p.y
			while y < screen.y:
				_batch.add_rect(Rect2(Vector2(x, y), size), color)
				y += TILE
			x += TILE
	_batch.draw(get_canvas_item())
