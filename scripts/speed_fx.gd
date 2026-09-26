class_name SpeedFx
extends Node2D
## Efeitos leves de velocidade: riscos de vento que escorrem da traseira da
## nave e dos asteroides (no sentido contrario ao avanco) e um rastro de
## particulas atras da nave. A intensidade acompanha a velocidade do fundo.

## Ciclos por segundo de cada risco (nasce na borda, escorre e some).
const FLOW_RATE := 1.8
const WAKE_COLOR := Color(0.7, 0.9, 1.0, 0.7)
const STREAK_COLOR := Color(0.8, 0.92, 1.0)

var config: TravelConfig
var _t := 0.0
var _intensity := 1.0
var _dir := Vector2.RIGHT
var _wake := 0.0
var _player: Player
var _asteroids: Array[Asteroid] = []
var _batch := TriBatch.new()


## `intensity` = velocidade atual do fundo / velocidade inicial.
func step(delta: float, intensity: float, player: Player, asteroids: Array[Asteroid], fx: Fx) -> void:
	_t += delta * FLOW_RATE * intensity
	_intensity = intensity
	_dir = config.direction()
	_player = player
	_asteroids = asteroids
	if player.alive:
		_emit_wake(delta, fx)
	queue_redraw()


## Particulas saindo da traseira da nave.
func _emit_wake(delta: float, fx: Fx) -> void:
	_wake += config.ship_wake_rate * _intensity * delta
	var back := -_dir
	var r := _player.bound_radius
	while _wake >= 1.0:
		_wake -= 1.0
		var at := _player.global_position + back * r * 0.7 + _dir.orthogonal() * randf_range(-0.6, 0.6) * r
		var vel := back * randf_range(120.0, 220.0) * _intensity + _player.velocity * 0.3
		fx.spark(at, vel, WAKE_COLOR, randf_range(0.25, 0.5))


func _draw() -> void:
	if config == null or config.streak_alpha <= 0.0:
		return
	_batch.clear()
	if _player != null and _player.alive:
		_streaks(_player, config.ship_streaks, config.ship_streak_length)
	for a in _asteroids:
		if is_instance_valid(a):
			_streaks(a, config.asteroid_streaks, config.asteroid_streak_length)
	_batch.draw(get_canvas_item())


## Riscos atras de um corpo. Cada um tem posicao e fase fixas (sorteadas pelo
## id do objeto), escorre para tras e some, em loop.
func _streaks(body: HexBody, count: int, length: float) -> void:
	var back := -_dir
	var across := _dir.orthogonal()
	var r := body.bound_radius
	var id := body.get_instance_id()
	for i in count:
		var h := hash(id * 131 + i)
		var lane := float(h % 1000) / 1000.0
		var phase := float((h >> 10) % 1000) / 1000.0
		var t := fposmod(_t + phase, 1.0)
		var streak_len := length * (0.6 + 0.4 * lane) * _intensity
		var edge := body.global_position + back * r * 0.6 + across * (lane - 0.5) * 1.6 * r
		var head := edge + back * t * streak_len * 0.8
		var tail := head + back * streak_len * (1.0 - t * 0.5)
		# Aparece e some suavemente ao longo do ciclo.
		var alpha := config.streak_alpha * sin(t * PI)
		_batch.add_streak(to_local(head), to_local(tail), 1.5, Color(STREAK_COLOR, alpha), Color(STREAK_COLOR, 0.0))
