class_name Starfield
extends Node2D
## Fundo de estrelas com parallax, desenhado em espaco de tela. Quem usa move
## `cam_pos` (a "camera" do fundo); com `cam_velocity` as estrelas viram
## riscos e aparecem linhas de velocidade. Os valores padrao sao os do menu;
## o jogo aplica os do TravelConfig com configure().

const TILE := 1024.0

var cam_pos := Vector2.ZERO
## Velocidade da "camera" do fundo (px/s), usada so para os efeitos.
var cam_velocity := Vector2.ZERO

## Mudancas nestes valores valem no proximo _ready (quantidade) ou desenho.
var star_count := 220
var parallax_far := 0.05
var parallax_near := 0.4
## Segundos de movimento que cada estrela "borra" (0 = pontos).
var streak := 0.0
var speed_lines := 0
var speed_line_alpha := 0.1
var speed_line_factor := 2.0

## [posicao no tile, profundidade 0..1 (1 = perto)]
var _stars := []
## [posicao transversal 0..1, comprimento, fase]
var _lines := []
## Todas as estrelas vao numa so chamada de desenho.
var _batch := TriBatch.new()


func configure(cfg: TravelConfig) -> void:
	star_count = cfg.star_count
	parallax_far = cfg.parallax_far
	parallax_near = cfg.parallax_near
	streak = cfg.star_streak
	speed_lines = cfg.speed_lines
	speed_line_alpha = cfg.speed_line_alpha
	speed_line_factor = cfg.speed_line_factor


func _ready() -> void:
	# O background continua funcionando mesmo com o jogo pausado.
	process_mode = Node.PROCESS_MODE_ALWAYS

	for i in star_count:
		_stars.append([Vector2(randf() * TILE, randf() * TILE), randf()])
	for i in speed_lines:
		_lines.append([randf(), randf_range(80.0, 260.0), randf()])

func _process(_delta: float) -> void:
	# Mantém o movimento do fundo mesmo quando o jogo está pausado.
	if get_tree().paused:
		var speed := 0.0
		# O Game normalmente atualiza cam_velocity.
		# Durante a pausa usamos a última velocidade conhecida.
		cam_pos += cam_velocity * _delta
	queue_redraw()

func _draw() -> void:
	var screen := get_viewport_rect().size
	_batch.clear()
	for s in _stars:
		var depth: float = s[1]
		var factor := lerpf(parallax_far, parallax_near, depth)
		var p: Vector2 = (s[0] - cam_pos * factor).posmod(TILE)
		var size := lerpf(1.0, 2.5, depth)
		var color := Color(1, 1, 1, lerpf(0.25, 0.9, depth))
		# A cauda aponta para onde a estrela estava (a camera avanca, ela recua).
		var tail := cam_velocity * factor * streak
		var streaked := tail.length_squared() > 1.0
		var x := p.x
		while x < screen.x:
			var y := p.y
			while y < screen.y:
				var at := Vector2(x, y)
				if streaked:
					_batch.add_streak(at, at + tail, size, color, Color(color, 0.0))
				else:
					_batch.add_rect(Rect2(at, Vector2(size, size)), color)
				y += TILE
			x += TILE
	_draw_speed_lines(screen)
	_batch.draw(get_canvas_item())


## Riscos longos atravessando a tela no sentido contrario ao avanco.
func _draw_speed_lines(screen: Vector2) -> void:
	if _lines.is_empty() or cam_velocity.length_squared() < 1.0:
		return
	var dir := cam_velocity.normalized()
	var across := dir.orthogonal()
	var center := screen * 0.5
	var reach := screen.length() * 0.5
	for l in _lines:
		var lane: float = l[0]
		var length: float = l[1]
		var phase: float = l[2]
		var span := reach * 2.0 + length
		# Posicao ao longo do avanco: recua conforme a camera anda.
		var along := fposmod(phase * span - cam_pos.dot(dir) * speed_line_factor, span) - span * 0.5
		var head := center + dir * along + across * (lane - 0.5) * screen.length()
		var color := Color(0.75, 0.9, 1.0, speed_line_alpha)
		_batch.add_streak(head, head + dir * length, 1.5, color, Color(color, 0.0))
