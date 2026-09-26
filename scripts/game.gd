extends Node2D
## Controlador principal: spawn, colisões, câmera e HUD.

## Asteroides nascem esta distância além da borda da tela.
const SPAWN_MARGIN := 120.0
## São removidos quando ficam mais longe que (raio da tela * fator).
const DESPAWN_FACTOR := 2.5
const MAX_ASTEROIDS := 45
## Quantidade de minério por célula do asteroide destruído.
const ORE_PER_CELL := 1.0
## Se true, asteroides que batem no jogador também soltam minério.
const DROP_ORE_ON_COLLISION := false

var player: Player
var bullets: Bullets
var fx: Fx
var camera: Camera2D
var starfield: Starfield
var asteroids: Array[Asteroid] = []
var ores: Array[Ore] = []

var elapsed := 0.0
var score := 0
var game_over := false
var _spawn_timer := 1.0
var _shake := 0.0

var _hud_label: Label
var _center_label: Label


func _ready() -> void:
	randomize()
	Input.set_default_cursor_shape(Input.CURSOR_CROSS)

	var bg := CanvasLayer.new()
	bg.layer = -1
	add_child(bg)
	starfield = Starfield.new()
	bg.add_child(starfield)

	player = Player.new()
	player.z_index = 2
	player.core_destroyed.connect(_on_core_destroyed)
	add_child(player)

	bullets = Bullets.new()
	bullets.z_index = 3
	add_child(bullets)

	fx = Fx.new()
	fx.z_index = 4
	add_child(fx)

	camera = Camera2D.new()
	add_child(camera)
	camera.make_current()

	_build_hud()


func _physics_process(delta: float) -> void:
	if not game_over:
		elapsed += delta
		player.step(delta)
		if Input.is_action_pressed("fire"):
			for shot in player.fire(get_global_mouse_position()):
				bullets.spawn(shot[0], shot[1], player.velocity)

	for a in asteroids:
		a.step(delta)
	bullets.step(delta, asteroids)
	for a in asteroids.duplicate():
		if a.hp <= 0:
			_destroy_asteroid(a, true)

	if not game_over:
		_check_player_collisions()
	_update_ores(delta)
	fx.step(delta)

	_spawn_asteroids(delta)
	_despawn_far_objects()
	_update_camera(delta)
	_update_hud()


func _unhandled_input(event: InputEvent) -> void:
	if game_over and event.is_action_pressed("restart"):
		get_tree().reload_current_scene()


# --- Asteroides -------------------------------------------------------------

func _spawn_asteroids(delta: float) -> void:
	if game_over:
		return
	_spawn_timer -= delta
	if _spawn_timer > 0.0 or asteroids.size() >= MAX_ASTEROIDS:
		return
	# O intervalo diminui com o tempo de jogo.
	_spawn_timer = maxf(0.55, 2.0 - elapsed * 0.008) * randf_range(0.7, 1.3)

	var n := _roll_asteroid_size()
	var a := Asteroid.new()
	a.setup(n)

	var dist := _view_radius() + a.bound_radius + SPAWN_MARGIN
	a.position = player.global_position + Vector2.from_angle(randf() * TAU) * dist
	# Vai na direção geral do jogador, com um desvio aleatório.
	var heading := (player.global_position - a.position).normalized().rotated(randf_range(-0.6, 0.6))
	var speed := randf_range(30.0, 85.0) * (1.2 - minf(n, 30) / 60.0)
	a.velocity = heading * speed
	a.angular_velocity = randf_range(-0.8, 0.8) / sqrt(n)
	a.rotation = randf() * TAU
	a.z_index = 0
	add_child(a)
	asteroids.append(a)


## Tamanhos pequenos são mais comuns; o máximo cresce com o tempo e com a nave.
func _roll_asteroid_size() -> int:
	var max_n := clampi(3 + int(elapsed / 10.0) + int(player.cells.size() / 3.0), 3, 40)
	return 1 + int(pow(randf(), 1.7) * max_n)


func _destroy_asteroid(a: Asteroid, drop_ore: bool) -> void:
	asteroids.erase(a)
	for h in a.cells:
		fx.burst(a.cell_global(h), a.base_color.lightened(0.2), 3, 110.0)
	if drop_ore:
		score += a.max_hp
		var keys := a.cells.keys()
		var count := maxi(1, roundi(a.size * ORE_PER_CELL))
		for i in count:
			var origin := a.cell_global(keys[i % keys.size()])
			var ore := Ore.new()
			ore.position = origin + Vector2(randf_range(-4, 4), randf_range(-4, 4))
			var outward := (origin - a.global_position).normalized()
			if outward == Vector2.ZERO:
				outward = Vector2.from_angle(randf() * TAU)
			ore.velocity = a.velocity + outward.rotated(randf_range(-0.5, 0.5)) * randf_range(20.0, 70.0)
			ore.angular_velocity = randf_range(-2.0, 2.0)
			ore.z_index = 1
			add_child(ore)
			ores.append(ore)
	a.queue_free()


func _check_player_collisions() -> void:
	for a in asteroids.duplicate():
		if not player.touches(a):
			continue
		var lost := player.take_damage(a.size)
		for p in lost:
			fx.burst(p, Player.CELL_COLOR, 5, 160.0)
		_shake = minf(6.0 + a.size, 22.0)
		_destroy_asteroid(a, DROP_ORE_ON_COLLISION)
		if not player.alive:
			return


# --- Minérios ---------------------------------------------------------------

func _update_ores(delta: float) -> void:
	for ore in ores.duplicate():
		ore.step(delta, null if game_over else player)
		if ore.life <= 0.0:
			_remove_ore(ore)
		elif not game_over and player.touches(ore):
			player.absorb_at(ore.global_position)
			fx.burst(ore.global_position, Ore.COLOR, 4, 60.0)
			_remove_ore(ore)


func _remove_ore(ore: Ore) -> void:
	ores.erase(ore)
	ore.queue_free()


func _despawn_far_objects() -> void:
	var limit := _view_radius() * DESPAWN_FACTOR
	for a in asteroids.duplicate():
		if a.global_position.distance_to(camera.global_position) > limit + a.bound_radius:
			asteroids.erase(a)
			a.queue_free()
	for ore in ores.duplicate():
		if ore.global_position.distance_to(camera.global_position) > limit:
			_remove_ore(ore)


# --- Câmera / HUD -----------------------------------------------------------

func _view_radius() -> float:
	return (get_viewport_rect().size / camera.zoom).length() * 0.5


func _update_camera(delta: float) -> void:
	# Afasta a câmera conforme a nave cresce.
	var target_zoom := clampf(260.0 / (player.bound_radius + 210.0), 0.3, 1.2)
	camera.zoom = camera.zoom.lerp(Vector2.ONE * target_zoom, 1.0 - exp(-2.0 * delta))
	camera.global_position = camera.global_position.lerp(player.global_position, 1.0 - exp(-8.0 * delta))
	camera.offset = Vector2(randf_range(-1, 1), randf_range(-1, 1)) * _shake
	_shake = move_toward(_shake, 0.0, 40.0 * delta)
	starfield.cam_pos = camera.global_position
	starfield.queue_redraw()


func _build_hud() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)

	_hud_label = Label.new()
	_hud_label.position = Vector2(16, 12)
	_hud_label.add_theme_font_size_override("font_size", 20)
	layer.add_child(_hud_label)

	var help := Label.new()
	help.text = "WASD / setas: mover    Clique esquerdo: atirar"
	help.add_theme_font_size_override("font_size", 14)
	help.modulate = Color(1, 1, 1, 0.5)
	layer.add_child(help)
	help.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT, Control.PRESET_MODE_MINSIZE, 16)

	_center_label = Label.new()
	_center_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_center_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_center_label.add_theme_font_size_override("font_size", 36)
	_center_label.visible = false
	layer.add_child(_center_label)
	_center_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func _update_hud() -> void:
	_hud_label.text = "Células: %d    Pontos: %d    Tempo: %s" % [
		player.cells.size(), score, _format_time(elapsed)]


func _format_time(t: float) -> String:
	return "%d:%02d" % [int(t / 60.0), int(t) % 60]


func _on_core_destroyed() -> void:
	game_over = true
	fx.burst(player.global_position, Player.CORE_COLOR, 60, 260.0)
	_shake = 25.0
	_center_label.text = "GAME OVER\n\nPontos: %d    Tempo: %s\n\n[R] reiniciar" % [score, _format_time(elapsed)]
	_center_label.visible = true
