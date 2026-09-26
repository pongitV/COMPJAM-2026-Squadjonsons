class_name RaceBar
extends Control
## Linha de progresso no rodape: o marcador da nave anda da largada ate a
## bandeira de chegada conforme o tempo passa (chega nela em
## TravelConfig.race_duration). Marcador e bandeira aceitam sprites proprios
## (slots "race_marker" e "race_flag").

const TRACK_Y := 0.7
const FLAG_SIZE := Vector2(26, 30)
const MARKER_SIZE := 22.0

var progress := 0.0
var _duration := 300.0
var _marker: HexIcon
var _flag: FlagIcon
var _left: Label


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_marker = HexIcon.new("race_marker", UIStyle.CYAN, MARKER_SIZE)
	_marker.spin_speed = 0.0
	add_child(_marker)
	_flag = FlagIcon.new()
	add_child(_flag)
	_left = UIStyle.label("", 11, UIStyle.TEXT_DIM, UIStyle.CAPTION)
	add_child(_left)


## `elapsed` e `duration` em segundos.
func set_time(elapsed: float, duration: float) -> void:
	_duration = duration
	var p := clampf(elapsed / duration, 0.0, 1.0)
	var finished := p >= 1.0
	if finished and progress < 1.0:
		_marker.kick()
	progress = p
	# O tempo restante fica no countdown do topo; aqui so o aviso de chegada.
	if finished:
		_left.text = UIStyle.plain("CHEGADA!")
		_left.add_theme_color_override("font_color", UIStyle.GOLD)
	else:
		_left.text = ""
	_layout()
	queue_redraw()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_layout()


## Inicio e fim da pista (a bandeira fica depois do fim).
func _track() -> Array:
	var y := size.y * TRACK_Y
	return [Vector2(MARKER_SIZE * 0.5, y), Vector2(size.x - FLAG_SIZE.x * 0.6, y)]


func _layout() -> void:
	var t := _track()
	var start: Vector2 = t[0]
	var end: Vector2 = t[1]
	_marker.size = _marker.custom_minimum_size
	_marker.position = start.lerp(end, progress) - _marker.size * 0.5
	_flag.size = FLAG_SIZE
	_flag.position = Vector2(end.x - 3.0, end.y - FLAG_SIZE.y)
	_left.size = _left.get_combined_minimum_size()
	_left.position = Vector2(end.x - _left.size.x - 8.0, end.y - _left.size.y - 12.0)


func _draw() -> void:
	var t := _track()
	var start: Vector2 = t[0]
	var end: Vector2 = t[1]
	var now := start.lerp(end, progress)
	draw_line(start, end, Color(UIStyle.TEXT_DIM, 0.3), 3.0, true)
	draw_line(start, now, Color(UIStyle.CYAN, 0.85), 3.0, true)
	# Um tique por minuto de corrida.
	var minutes := int(_duration / 60.0)
	for m in range(1, minutes + 1):
		var x := lerpf(start.x, end.x, m * 60.0 / _duration)
		var passed := x <= now.x
		draw_line(Vector2(x, start.y - 4.0), Vector2(x, start.y + 4.0),
			Color(UIStyle.CYAN if passed else UIStyle.TEXT_DIM, 0.7 if passed else 0.35), 1.5)


## Bandeira quadriculada num mastro (slot "race_flag", base do mastro
## embaixo a esquerda). O pano tremula de leve.
class FlagIcon extends UISprite:
	const COLS := 4
	const ROWS := 3
	var _t := 0.0

	func _init() -> void:
		super("race_flag", RaceBar.FLAG_SIZE)
		color = UIStyle.TEXT

	func _process(delta: float) -> void:
		_t += delta
		if not has_sprite():
			queue_redraw()

	func _draw_placeholder() -> void:
		draw_line(Vector2(1.5, 0.0), Vector2(1.5, size.y), color, 2.0)
		var cloth := Vector2(size.x - 3.0, size.y * 0.55)
		var cell := cloth / Vector2(COLS, ROWS)
		for i in COLS:
			var wave := sin(_t * 6.0 - i * 0.9) * 1.2 * (i + 1) / COLS
			for j in ROWS:
				var dark := (i + j) % 2 == 1
				var rect := Rect2(Vector2(3.0 + i * cell.x, j * cell.y + wave), cell)
				draw_rect(rect, Color(0.1, 0.12, 0.15) if dark else color)
