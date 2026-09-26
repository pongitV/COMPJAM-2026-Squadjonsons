extends Node2D
## Controlador principal: spawn, colisoes, camera e HUD.
## Os asteroides comuns nascem sem canhoes; os inimigos (asteroides armados)
## seguem o cronograma de ondas do EnemyConfig. Na bandeira de chegada os dois
## param e entra o chefe (Boss); destruir o nucleo dele vence o jogo.
## A camera fica parada; so o fundo rola (TravelConfig), dando a impressao de
## que a nave avanca. A nave se move livre, mas presa na area visivel.

## Aproxima a camera para as artes aparecerem maiores (1.0 = escala original).
const ART_ZOOM := 1.2

## Parametros dos asteroides (spawn, tamanho, HP, velocidade, minerio).
## Troque por outro preset .tres no Inspector do no Game.
@export var asteroid_config: AsteroidConfig = preload("res://config/asteroids.tres")
## Parametros dos canhoes (recarga, dano, alcance...).
@export var cannon_config: CannonConfig = preload("res://config/cannons.tres")
## Velocidade do fundo, efeitos de velocidade e duracao ate a chegada.
@export var travel_config: TravelConfig = preload("res://config/travel.tres")
## Asteroides armados: canhoes, forca dos tiros e drop.
@export var enemy_config: EnemyConfig = preload("res://config/enemies.tres")
## Comeca a partida com o tutorial (ENTER pula).
@export var tutorial_enabled := true

## Asteroide destruido pelos canhoes (antes de virar minerio).
signal asteroid_destroyed(a: Asteroid)
## Pedaco encaixado na nave ({celula: canhao}).
signal piece_attached(placement: Dictionary)

var player: Player
var bullets: Bullets
var enemy_shots: EnemyShots
var missiles: Missiles
var lasers: Lasers
var tractor: Tractor
var fx: Fx
var camera: Camera2D
var music: AudioStreamPlayer
var cannon_sfx: AudioStreamPlayer
var laser_sfx: AudioStreamPlayer
var attach_sfx: AudioStreamPlayer
var ship_destroy_sfx: AudioStreamPlayer
var asteroid_destroy_sfx: AudioStreamPlayer
var starfield: Starfield
var speed_fx: SpeedFx
var hud: Hud
var pause_menu: PauseMenu
var tutorial: Tutorial
var asteroids: Array[Asteroid] = []
var ores: Array[Ore] = []

var elapsed := 0.0
var score := 0
var game_over := false
## Estatisticas para a tela de game over.
var collected := 0
var destroyed := 0
var max_cells := 1
var best_score := 0
var _spawn_timer := 0.0
## Segundos ate o proximo inimigo (EnemyConfig.interval).
var _enemy_timer := 0.0
## O chefe, depois que ele aparece (null antes e depois de derrotado).
var boss: Boss
var boss_started := false
var _boss_phase := -1
## Chefe derrotado: fim de jogo com vitoria.
var won := false
var _shake := 0.0
## Atalho para asteroid_config.
var _cfg: AsteroidConfig


func _ready() -> void:
	Display.setup(get_tree())
	randomize()
	_cfg = asteroid_config
	Asteroid.config = _cfg
	Weapons.config = cannon_config
	Ore.drift = travel_config.ore_drift_velocity()
	_spawn_timer = _cfg.first_spawn_delay
	_enemy_timer = enemy_config.first_enemy_delay
	# As artes aparecem bem menores que o original e giram: mipmaps evitam serrilhado.
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	InputActions.ensure_defaults()
	best_score = SaveData.best_score()
	
	music = AudioStreamPlayer.new()
	music.stream = preload("res://Audio/Music/battle.wav")
	music.volume_db = -30.0
	add_child(music)
	music.play()
	
	cannon_sfx = AudioStreamPlayer.new()
	cannon_sfx.stream = preload("res://Audio/SFX/cannon_shot.wav")
	cannon_sfx.volume_db = -25.0
	add_child(cannon_sfx)
	
	laser_sfx = AudioStreamPlayer.new()
	laser_sfx.stream = preload("res://Audio/SFX/Laserzao.wav")
	laser_sfx.volume_db = -20.0
	add_child(laser_sfx)
	
	attach_sfx = AudioStreamPlayer.new()
	attach_sfx.stream = preload("res://Audio/SFX/attach.wav")
	attach_sfx.volume_db = -20.0
	add_child(attach_sfx)
	
	asteroid_destroy_sfx = AudioStreamPlayer.new()
	asteroid_destroy_sfx.stream = preload("res://Audio/SFX/asteroidExplosion.ogg")
	asteroid_destroy_sfx.volume_db = -20.0
	add_child(asteroid_destroy_sfx)

	ship_destroy_sfx = AudioStreamPlayer.new()
	ship_destroy_sfx.stream = preload("res://Audio/SFX/PlayerExplosion.ogg")
	ship_destroy_sfx.volume_db = -20.0
	add_child(ship_destroy_sfx)

	var bg := CanvasLayer.new()
	bg.layer = -1
	add_child(bg)
	starfield = Starfield.new()
	starfield.configure(travel_config)
	bg.add_child(starfield)

	# Abaixo de tudo no mundo: os riscos saem de tras dos objetos.
	speed_fx = SpeedFx.new()
	speed_fx.config = travel_config
	add_child(speed_fx)

	player = Player.new()
	player.z_index = 2
	player.core_destroyed.connect(_on_core_destroyed)
	add_child(player)

	# Abaixo da nave: o feixe parece sair da borda dela.
	tractor = Tractor.new()
	tractor.z_index = 1
	tractor.attached.connect(_on_ore_attached)
	add_child(tractor)

	lasers = Lasers.new()
	lasers.z_index = 1
	add_child(lasers)
	
	lasers.laser_started.connect(_on_laser_started)
	lasers.laser_stopped.connect(_on_laser_stopped)

	bullets = Bullets.new()
	bullets.z_index = 3
	add_child(bullets)

	missiles = Missiles.new()
	missiles.z_index = 3
	add_child(missiles)

	enemy_shots = EnemyShots.new()
	enemy_shots.config = enemy_config
	enemy_shots.z_index = 3
	add_child(enemy_shots)

	fx = Fx.new()
	fx.z_index = 4
	add_child(fx)

	camera = Camera2D.new()
	add_child(camera)
	camera.make_current()

	hud = Hud.new()
	hud.restart_requested.connect(_restart)
	hud.menu_requested.connect(_go_to_menu)
	add_child(hud)

	pause_menu = PauseMenu.new()
	pause_menu.opened.connect(hud.set_playing.bind(false))
	pause_menu.resumed.connect(hud.set_playing.bind(true))
	pause_menu.menu_requested.connect(_go_to_menu)
	pause_menu.quit_requested.connect(get_tree().quit)
	add_child(pause_menu)
	_update_hud()

	if tutorial_enabled:
		tutorial = Tutorial.new(self)
		add_child(tutorial)


func _on_laser_started() -> void:
	if not laser_sfx.playing:
		laser_sfx.play()


func _on_laser_stopped() -> void:
	if laser_sfx.playing:
		laser_sfx.stop()

func _physics_process(delta: float) -> void:
	var visible_asteroids := _asteroids_on_screen()
	if not game_over:
		# O relogio da corrida (dificuldade, chegada) so anda depois do tutorial.
		if not tutorial_running():
			elapsed += delta
		player.aim = get_global_mouse_position()
		player.step(delta)
		_keep_player_on_screen()
		# Tiro automatico: cada canhao mira no asteroide mais proximo dele.
		player.update_targets(delta, visible_asteroids)
		for shot in player.fire():
			_fire_shot(shot)
		tractor.step(delta, player, ores, get_global_mouse_position(),
			Input.is_action_pressed("drag"), Input.is_action_just_pressed("drag"))
		_enemy_fire(delta, visible_asteroids)

	for a in asteroids:
		a.step(delta)
	_collide_asteroids()
	bullets.step(delta, asteroids)
	lasers.step(delta, player, asteroids, fx)
	if not missiles.step(delta, asteroids, fx).is_empty():
		_shake = maxf(_shake, 7.0)
	for a in asteroids.duplicate():
		if a.hp <= 0:
			_destroy_asteroid(a)

	# Tiros inimigos acertam a nave e os minerios soltos.
	var targets: Array = [player] if player.alive else []
	targets.append_array(ores)
	var shot_hits := enemy_shots.step(delta, targets, fx)
	for body in shot_hits:
		if body is Ore and is_instance_valid(body):
			_chip_ore(body, shot_hits[body].keys())
	if not game_over:
		var player_cells: Array[Vector2i] = []
		player_cells.assign(shot_hits.get(player, {}).keys())
		_hurt_player(player_cells)
		_check_player_collisions()
	_update_ores(delta)
	_scroll_background(delta)
	fx.step(delta)

	_spawn_asteroids(delta)
	_spawn_enemies(delta)
	_update_boss()
	_despawn_far_objects()
	_update_camera(delta)
	_update_hud()


func _unhandled_input(event: InputEvent) -> void:
	# Roda do mouse gira o pedaco que esta sendo arrastado.
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			tractor.turn(-1)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			tractor.turn(1)
	if game_over and event.is_action_pressed("restart"):
		_restart()


func _restart() -> void:
	get_tree().paused = false
	Engine.time_scale = 1.0
	get_tree().reload_current_scene()


func _go_to_menu() -> void:
	get_tree().paused = false
	Engine.time_scale = 1.0
	get_tree().change_scene_to_file(MainMenu.SCENE)


func tutorial_running() -> bool:
	return tutorial != null and tutorial.running


# --- Canhoes ----------------------------------------------------------------

## shot: {type, key, origin, dir, target_pos} vindo de Player.fire().
func _fire_shot(shot: Dictionary) -> void:
	var origin: Vector2 = shot.origin
	var dir: Vector2 = shot.dir
	var color := Weapons.color(shot.type).lightened(0.4)
	
	if shot.type == Weapons.COMMON or shot.type == Weapons.SHOTGUN:
		cannon_sfx.play()
	
	var cfg := Weapons.config
	match shot.type:
		Weapons.COMMON:
			bullets.spawn(origin, dir * cfg.common_speed + player.velocity,
				cfg.projectile_life(Weapons.COMMON), cfg.damage(Weapons.COMMON), color)
		Weapons.SHOTGUN:
			# Um tiro no centro e os outros abrindo em leque para os lados.
			for pellet_dir in cfg.shotgun_dirs(dir):
				bullets.spawn(origin, pellet_dir * cfg.shotgun_speed + player.velocity,
					cfg.projectile_life(Weapons.SHOTGUN), cfg.damage(Weapons.SHOTGUN), color)
		Weapons.LASER:
			lasers.start(shot.key)
			if not laser_sfx.playing:
				laser_sfx.play()
		Weapons.BOMB:
			missiles.launch(origin, shot.target_pos, player.velocity)


## 0..1: quanto da corrida ate a bandeira ja passou (os inimigos ficam mais
## fortes conforme ele sobe).
func _progress() -> float:
	return clampf(elapsed / travel_config.race_duration, 0.0, 1.0)


## Canhoes dos asteroides na tela miram na nave e atiram quando carregados e
## com ela no alcance.
func _enemy_fire(delta: float, visible_asteroids: Array[Asteroid]) -> void:
	var progress := _progress()
	for a in visible_asteroids:
		if a.groups.is_empty():
			continue
		a.aim_at = player.global_position
		# O chefe atira de onde estiver (esta sempre na tela).
		var is_boss := a is Boss
		for g in a.groups:
			var left: float = a.cooldowns.get(g.key, enemy_config.first_shot_delay) - delta
			var reach := INF if is_boss else enemy_config.range_of(g.type) + player.bound_radius
			if left > 0.0 or a.muzzle(g).distance_to(player.global_position) > reach:
				a.cooldowns[g.key] = maxf(left, 0.0)
				continue
			if is_boss and g.type == Weapons.LASER:
				a.cooldowns[g.key] = enemy_config.boss_laser_cooldown
			else:
				a.cooldowns[g.key] = enemy_config.cooldown(g.type, progress) \
					* (enemy_config.boss_cooldown_mult if is_boss else 1.0)
			enemy_shots.fire(a, g, player, progress, a.harmless)
			if g.type == Weapons.COMMON or g.type == Weapons.SHOTGUN:
				cannon_sfx.play()


# --- Asteroides -------------------------------------------------------------

func _spawn_asteroids(delta: float) -> void:
	if game_over or tutorial_running() or boss_started:
		return
	_spawn_timer -= delta
	if _spawn_timer > 0.0 or asteroids.size() >= _cfg.max_asteroids:
		return
	# O intervalo diminui com o tempo de jogo.
	_spawn_timer = _cfg.spawn_interval(elapsed)

	# O tamanho maximo cresce com o tempo e com o poder de fogo (celulas de
	# canhao, ja que o casco nao atira).
	var cannon_cells := 0
	for g in player.groups:
		cannon_cells += g.cells.size()
	var n := _cfg.roll_size(elapsed, cannon_cells)
	var a := Asteroid.new()
	a.setup(n, _cfg.hp_scale(elapsed))
	_launch_from_edge(a)


## Poe um asteroide (ou inimigo) novo fora da tela e o manda na direcao da nave.
func _launch_from_edge(a: Asteroid) -> void:
	var n := a.cells.size()
	# Em volta da tela (a camera e fixa; a nave pode estar perto da borda), de
	# preferencia a frente, no sentido do avanco.
	var dist := _view_radius() + a.bound_radius + _cfg.spawn_margin
	a.position = camera.global_position + Vector2.from_angle(travel_config.roll_spawn_angle()) * dist
	# Vai na direcao geral do jogador, com um desvio aleatorio, e e arrastado
	# devagar para tras (parece que a nave passa por ele).
	var heading := (player.global_position - a.position).normalized() \
		.rotated(randf_range(-_cfg.aim_spread, _cfg.aim_spread))
	a.velocity = heading * _cfg.roll_speed(n) * _cfg.speed_scale(elapsed) + travel_config.drift()
	a.angular_velocity = _cfg.roll_spin(n)
	a.rotation = randf() * TAU
	add_child(a)
	asteroids.append(a)


## Inimigos: um a cada EnemyConfig.interval (conforme o minuto da corrida),
## respeitando o maximo de inimigos vivos daquele minuto. Os canhoes saem de
## EnemyConfig.roll_wave_armament.
func _spawn_enemies(delta: float) -> void:
	if game_over or tutorial_running() or boss_started:
		return
	_enemy_timer -= delta
	if _enemy_timer > 0.0:
		return
	if _enemy_count() >= enemy_config.max_alive(elapsed):
		# No limite: tenta de novo daqui a pouco (quando algum morrer).
		_enemy_timer = 1.0
		return
	_enemy_timer = enemy_config.interval(elapsed)
	var armament := enemy_config.roll_wave_armament(elapsed)
	var a := Asteroid.new()
	a.setup(enemy_config.enemy_size(armament), _cfg.hp_scale(elapsed), armament)
	_launch_from_edge(a)


## Inimigos vivos (asteroides com canhao; o chefe e os do tutorial nao contam).
func _enemy_count() -> int:
	var n := 0
	for a in asteroids:
		if not a.groups.is_empty() and not a.harmless and not a is Boss:
			n += 1
	return n


# --- Chefe ------------------------------------------------------------------

## Na bandeira de chegada o chefe entra pela direita (o spawn ja parou).
func _update_boss() -> void:
	if not boss_started:
		if not game_over and not tutorial_running() and elapsed >= travel_config.race_duration:
			_start_boss()
		return
	if boss == null or not is_instance_valid(boss):
		return
	boss.set_stop_x(_boss_stop_x())
	_set_boss_patrol()
	boss.holding = enemy_shots.boss_laser_active(boss)
	for b in boss.broken:
		fx.burst(b[0], Weapons.color(Weapons.COMMON) if b[1] else Color.WHITE, 14 if b[1] else 6, 160.0)
	boss.broken.clear()
	# Partes que se soltaram do chefe viram pedacos flutuantes (como os da nave).
	for piece: Dictionary in boss.detached:
		var ore := Ore.new()
		ore.setup_from(boss, piece.keys(), piece)
		var outward := (ore.global_position - boss.global_position).normalized()
		ore.velocity = boss.velocity + outward * randf_range(40.0, 80.0)
		ore.angular_velocity = randf_range(-1.0, 1.0)
		_add_ore(ore)
	if not boss.detached.is_empty():
		_trim_ores()
	boss.detached.clear()
	# Tiros no escudo: so faisca cinza.
	for p in boss.pings:
		if randf() < 0.3:
			fx.burst(p, Color(0.75, 0.8, 0.9), 2, 90.0)
	boss.pings.clear()
	var phase := boss.phase()
	if phase != _boss_phase:
		if _boss_phase != -1:
			var msg: String = ["", "ESCUDO DO LASER CAIU!", "NÚCLEO EXPOSTO!"][phase]
			hud.popup(msg, UIStyle.GOLD, get_viewport_rect().size * Vector2(0.5, 0.3), 26)
			_shake = maxf(_shake, 12.0)
		_boss_phase = phase
	hud.set_boss_status(Boss.NAME, boss.health_ratio())


func _start_boss() -> void:
	boss_started = true
	boss = Boss.new()
	boss.setup_boss(enemy_config)
	var half := get_viewport_rect().size / camera.zoom * 0.5
	var center := camera.global_position
	# Centralizado na altura da tela: o laser corta a tela no meio.
	boss.position = Vector2(center.x + half.x + boss.extent_x + 30.0, center.y)
	boss.set_stop_x(_boss_stop_x())
	_set_boss_patrol()
	boss.z_index = 1
	add_child(boss)
	asteroids.append(boss)
	hud.show_boss_bar()
	hud.popup(Boss.NAME + "!", UIStyle.RED, get_viewport_rect().size * Vector2(0.5, 0.35), 34)
	_shake = maxf(_shake, 10.0)


## Onde o chefe fica: inteiro na tela, perto da borda direita.
func _boss_stop_x() -> float:
	var half := get_viewport_rect().size / camera.zoom * 0.5
	return camera.global_position.x + half.x - boss.extent_x - enemy_config.boss_edge_margin


## Faixa em que o chefe sobe e desce: centrada na tela, sem sair dela.
func _set_boss_patrol() -> void:
	var half := get_viewport_rect().size / camera.zoom * 0.5
	var room := maxf(half.y - boss.extent_y - Hex.SIZE, 0.0)
	boss.set_patrol(camera.global_position.y, room * enemy_config.boss_patrol_range)


## Nucleo do chefe destruido: explosao grande e a tela de vitoria.
func _on_boss_defeated(b: Boss) -> void:
	won = true
	game_over = true
	boss = null
	pause_menu.enabled = false
	tractor.drop()
	enemy_shots.clear()
	score += enemy_config.boss_score
	destroyed += 1
	for h in b.cells:
		fx.burst(b.cell_global(h), Weapons.color(Weapons.COMMON) if b.cells[h] != Weapons.NONE else b.base_color, 8, 220.0)
	fx.burst(b.cell_global(Boss.CORE), Player.CORE_COLOR, 80, 320.0)
	fx.ring(b.cell_global(Boss.CORE), 260.0, UIStyle.GOLD)
	_shake = 30.0
	hud.hide_boss_bar()
	b.queue_free()
	var new_record := score > best_score
	if new_record:
		best_score = score
		SaveData.save_best_score(best_score)
	hud.show_victory({
		"score": score, "best": best_score, "new_record": new_record,
		"time": elapsed, "max_cells": max_cells,
		"collected": collected, "destroyed": destroyed,
	})


## Batidas entre asteroides (cada par uma vez por frame).
func _collide_asteroids() -> void:
	for i in asteroids.size():
		for j in range(i + 1, asteroids.size()):
			asteroids[i].collide_with(asteroids[j])


## Asteroide destruido pelos canhoes: pontos e minerio.
func _destroy_asteroid(a: Asteroid) -> void:
	asteroids.erase(a)
	asteroid_destroy_sfx.play()
	if a is Boss:
		# So e vitoria se a nave ainda estiver inteira (nucleo vivo).
		if game_over:
			boss = null
			a.queue_free()
		else:
			_on_boss_defeated(a)
		return
	if not game_over:
		# A pontuacao conta por tras (game over e recorde), sem aparecer no HUD.
		score += _cfg.score_for(a.max_hp)
		destroyed += 1
	asteroid_destroyed.emit(a)
	_break_into_ore(a)
	a.queue_free()


## O asteroide se parte em roll_piece_count() pedacos conectados (poucos nos
## pequenos, mais nos grandes), no mesmo lugar em que estavam. Os canhoes sao
## celulas como as outras: vao no pedaco em que cairem, entao um triangulo
## pode cair inteiro, dividido entre pedacos ou sem algumas celulas (quando
## encaixados, os que ainda formarem triangulo voltam a se fundir).
func _break_into_ore(a: Asteroid) -> void:
	if not a.drop_pieces.is_empty():
		_drop_fixed_pieces(a)
		return
	var kept := _lose_cells(a)
	var weapons := {}
	for h in kept:
		if a.cells[h] == Weapons.COMMON:
			weapons[h] = Weapons.COMMON
	for piece in _split_into_pieces(kept, _cfg.roll_piece_count(a.size)):
		_launch_ore(a, piece, weapons)
	for h in kept:
		fx.burst(a.cell_global(h), a.base_color.lightened(0.2), 2, 70.0)
	_trim_ores()


## Asteroide com pedacos fixos (tutorial): cada pedaco cai inteiro, com os
## canhoes que tiver; o que nao estiver em nenhum pedaco vira poeira.
func _drop_fixed_pieces(a: Asteroid) -> void:
	var used := {}
	for piece: Array in a.drop_pieces:
		var weapons := {}
		for h in piece:
			used[h] = true
			if a.cells.get(h, Weapons.NONE) == Weapons.COMMON:
				weapons[h] = Weapons.COMMON
				fx.burst(a.cell_global(h), Weapons.color(Weapons.COMMON), 10, 110.0)
		_launch_ore(a, piece, weapons)
	for h in a.cells:
		if not used.has(h):
			fx.burst(a.cell_global(h), a.base_color.darkened(0.2), 8, 100.0)


## Asteroide que so o tutorial cria (inofensivo, formato fixo, ver
## Asteroid.setup_shape): nasce fora da borda da frente (direita) e cruza a
## tela no sentido contrario, passando ao lado da nave (`side` = 1 de um lado,
## -1 do outro) com `gap` px de folga.
func spawn_scripted_asteroid(shape: Dictionary, pieces: Array, side: float, gap: float, speed: float) -> Asteroid:
	var a := Asteroid.new()
	a.setup_shape(shape)
	a.drop_pieces = pieces
	a.harmless = true
	var forward := travel_config.direction()
	var half := get_viewport_rect().size / camera.zoom * 0.5
	var ahead := absf(forward.x) * half.x + absf(forward.y) * half.y
	a.position = camera.global_position + forward * (ahead + a.bound_radius + 20.0) \
		+ forward.orthogonal() * (player.global_position - camera.global_position).dot(forward.orthogonal()) \
		+ forward.orthogonal() * side * (player.bound_radius + a.bound_radius + gap)
	a.velocity = -forward * speed
	a.angular_velocity = randf_range(-0.15, 0.15)
	add_child(a)
	asteroids.append(a)
	return a


## ore_loss das celulas vira poeira (arredondamento sorteado: em media perde
## exatamente ore_loss). So somem celulas cuja perda nao parte o que sobra:
## quem decide em quantos pedacos o asteroide se divide e roll_piece_count().
## Retorna as celulas que ficam.
func _lose_cells(a: Asteroid) -> Array:
	var keys := a.cells.keys()
	keys.shuffle()
	var exact := keys.size() * _cfg.ore_loss
	var to_lose := int(exact) + (1 if randf() < exact - int(exact) else 0)
	var left := {}
	for h in keys:
		left[h] = true
	var parts := Hex.components(keys).size()
	for h in keys:
		if to_lose <= 0:
			break
		left.erase(h)
		if left.is_empty() or Hex.components(left.keys()).size() > parts:
			left[h] = true
			continue
		to_lose -= 1
		fx.burst(a.cell_global(h), a.base_color.darkened(0.2), 6, 90.0)
	return left.keys()


## Pedaco de minerio com celulas do asteroide, afastando-se do centro dele.
func _launch_ore(a: Asteroid, keys: Array, weapons: Dictionary = {}) -> void:
	var ore := Ore.new()
	ore.setup_from(a, keys, weapons)
	var outward := (ore.global_position - a.global_position).normalized()
	if outward == Vector2.ZERO:
		outward = Vector2.from_angle(randf() * TAU)
	ore.velocity = a.velocity + outward.rotated(randf_range(-0.4, 0.4)) \
		* randf_range(_cfg.ore_speed_min, _cfg.ore_speed_max)
	ore.angular_velocity = randf_range(-1.0, 1.0)
	_add_ore(ore)


## Divide as celulas em ~`count` pedacos conectados de tamanhos parecidos
## (cada parte desconectada recebe sua parcela, no minimo 1).
func _split_into_pieces(keys: Array, count: int) -> Array:
	var pieces := []
	for part in Hex.components(keys):
		var k := clampi(roundi(float(count) * part.size() / keys.size()), 1, part.size())
		pieces.append_array(_grow_pieces(part, k))
	return pieces


## Sementes espalhadas (cada uma o mais longe possivel das anteriores) crescem
## juntas, uma celula por vez em rodizio, ate cobrir a parte toda.
func _grow_pieces(part: Array, count: int) -> Array:
	if count <= 1:
		return [part]
	var inside := {}
	for h in part:
		inside[h] = true
	var seeds: Array[Vector2i] = [part.pick_random()]
	while seeds.size() < count:
		var best: Vector2i = part[0]
		var best_dist := -1.0
		for h in part:
			var dist := INF
			for s in seeds:
				dist = minf(dist, Hex.distance(h, s))
			dist += randf() * 0.5  # desempate aleatorio
			if dist > best_dist:
				best_dist = dist
				best = h
		seeds.append(best)
	var taken := {}
	var pieces := []
	for s in seeds:
		taken[s] = true
		pieces.append([s])
	var growing := true
	while growing and taken.size() < part.size():
		growing = false
		for piece in pieces:
			var options := []
			for h in piece:
				for d in Hex.DIRS:
					var n: Vector2i = h + d
					if inside.has(n) and not taken.has(n):
						options.append(n)
			if options.is_empty():
				continue
			var pick: Vector2i = options.pick_random()
			taken[pick] = true
			piece.append(pick)
			growing = true
	return pieces


func _add_ore(ore: Ore) -> void:
	ore.z_index = 1
	add_child(ore)
	ores.append(ore)


## Limita os minerios soltos: remove os mais antigos, preferindo os sem
## canhao. O pedaco que esta sendo arrastado nunca sai.
func _trim_ores() -> void:
	while ores.size() > _cfg.max_ores:
		var loose := ores.filter(func(o): return not o.dragged)
		var plain := loose.filter(func(o): return not o.has_cannon())
		_remove_ore(plain[0] if not plain.is_empty() else loose[0])


## Batida celula a celula: o asteroide entra na nave destruindo as celulas
## que toca (cada uma quebra a celula dele que bateu) ate gastar a
## penetracao do tamanho dele (Asteroid.impact_budget); entao recua. Partes da
## nave que se soltarem do nucleo viram pedacos soltos.
func _check_player_collisions() -> void:
	var hits := PackedVector2Array()
	var core_hit := false
	for a: Asteroid in asteroids.duplicate():
		var reach := a.bound_radius + player.bound_radius
		if a.global_position.distance_squared_to(player.global_position) > reach * reach:
			a.recharge_impact()
			continue
		# Pares [celula do asteroide, celula da nave] encostados, ponto de
		# contato, normal (da nave para o asteroide) e sobreposicao.
		var touching := []
		var contact := Vector2.ZERO
		var normal := Vector2.ZERO
		var depth := 0.0
		for h in a.cells:
			var p := a.cell_global(h)
			var target := player.find_cell_near(p, HexBody.CONTACT_DIST)
			if target == HexBody.NO_CELL:
				continue
			var q := player.cell_global(target)
			touching.append([h, target])
			contact += (p + q) * 0.5
			normal += p - q
			depth = maxf(depth, HexBody.CONTACT_DIST - p.distance_to(q))
		if touching.is_empty():
			continue
		contact /= touching.size()
		normal = normal.normalized()
		if normal == Vector2.ZERO:
			normal = (a.global_position - player.global_position).normalized()

		# Entra destruindo enquanto tiver penetracao.
		var spent: Array[Vector2i] = []
		for pair in touching:
			if a.impact_budget <= 0:
				break
			var target: Vector2i = pair[1]
			if not player.cells.has(target):
				continue
			hits.append(player.cell_global(target))
			spent.append(pair[0])
			a.impact_budget -= 1
			if player.destroy_cell(target):
				core_hit = true
				break
		if core_hit:
			break
		# Sem penetracao: bate e recua (antes de quebrar, para os pedacos
		# herdarem o recuo).
		if a.impact_budget <= 0:
			a.bounce_off(player, normal, contact, depth)
			_shake = maxf(_shake, minf(2.0 + a.cells.size() * 0.3, 10.0))
		if not spent.is_empty() and not a is Boss:
			for h in spent:
				fx.burst(a.cell_global(h), a.base_color, 5, 110.0)
			for piece in a.remove_cells(spent):
				if piece.size < _cfg.min_size:
					_crumble(piece)
					piece.free()
				else:
					add_child(piece)
					asteroids.append(piece)
			if a.cells.size() < _cfg.min_size:
				_crumble(a)
				asteroids.erase(a)
				a.queue_free()
		if core_hit:
			break
	_after_player_damage(hits, core_hit)


## Tiros inimigos: cada celula atingida e destruida.
func _hurt_player(cells: Array[Vector2i]) -> void:
	var hits := PackedVector2Array()
	var core_hit := false
	for h in cells:
		if not player.cells.has(h):
			continue
		hits.append(player.cell_global(h))
		if player.destroy_cell(h):
			core_hit = true
			break
	_after_player_damage(hits, core_hit)


## Efeitos do dano na nave (`hits` = onde as celulas estavam) e, se o nucleo
## caiu, a explosao; senao, as partes soltas viram pedacos.
func _after_player_damage(hits: PackedVector2Array, core_hit: bool) -> void:
	if hits.is_empty():
		return
	for p in hits:
		fx.burst(p, Weapons.color(Weapons.NONE).lightened(0.3), 6, 160.0)
	hud.popup("-%d" % hits.size(), UIStyle.RED,
		_to_screen(player.global_position + Vector2(0, -player.bound_radius - 8.0)), 22)
	hud.damage_flash(minf(hits.size() / 6.0, 1.0))
	_shake = maxf(_shake, minf(4.0 + hits.size() * 2.0, 22.0))
	if core_hit:
		for p in player.explode():
			fx.burst(p, Weapons.color(Weapons.NONE).lightened(0.3), 5, 160.0)
		return
	for piece in player.settle_damage():
		_detach_from_ship(piece)


## Asteroide pequeno demais (menos de min_size celulas) vira poeira.
func _crumble(a: Asteroid) -> void:
	for h in a.cells:
		fx.burst(a.cell_global(h), a.base_color.darkened(0.2), 6, 90.0)


## Parte da nave que perdeu a ligacao com o nucleo: vira um pedaco solto,
## com os canhoes que tinha, que pode ser encaixado de novo.
func _detach_from_ship(piece: Dictionary) -> void:
	var ore := Ore.new()
	ore.setup_from(player, piece.keys(), piece)
	var outward := (ore.global_position - player.global_position).normalized()
	ore.velocity = player.velocity + outward * randf_range(30.0, 60.0)
	ore.angular_velocity = randf_range(-0.8, 0.8)
	_add_ore(ore)
	_trim_ores()


# --- Minerios ---------------------------------------------------------------

## Minerios so flutuam; viram parte da nave quando o raio trator os encaixa.
func _update_ores(delta: float) -> void:
	for ore in ores.duplicate():
		ore.step(delta)
		if ore.life <= 0.0:
			_remove_ore(ore)


func _on_ore_attached(ore: Ore, placement: Dictionary) -> void:
	if not is_instance_valid(ore):
		return
	
	var before := {}
	for g in player.groups:
		before[g.key] = true
	if not player.attach_piece(placement):
		return
	attach_sfx.play()
	collected += placement.size()
	max_cells = maxi(max_cells, player.cells.size())
	var center := Vector2.ZERO
	for slot in placement:
		var at := player.cell_global(slot)
		center += at
		var w: int = placement[slot]
		fx.burst(at, Ore.COLOR if w == Weapons.NONE else Weapons.color(w), 6, 80.0)
	hud.popup("+%d" % placement.size(), UIStyle.GREEN, _to_screen(center / placement.size()), 14)
	piece_attached.emit(placement)
	# Canhoes que surgiram com o encaixe (inclusive triangulos que se fundiram).
	for g in player.groups:
		if before.has(g.key):
			continue
		var at := player.group_global(g)
		fx.burst(at, Weapons.color(g.type), 10 + 6 * g.cells.size(), 140.0)
		if g.type != Weapons.COMMON:
			hud.popup("+%s" % Weapons.NAMES[g.type], Weapons.color(g.type), _to_screen(at + Vector2(0, -20)), 16)
	_remove_ore(ore)


## Minerio atingido por tiro inimigo: as celulas atingidas somem; se o pedaco
## ficar partido, cada parte vira um pedaco separado.
func _chip_ore(ore: Ore, hit: Array) -> void:
	for h in hit:
		if ore.cells.has(h):
			var color := Ore.COLOR if ore.cells[h] == Weapons.NONE else Weapons.color(ore.cells[h])
			fx.burst(ore.cell_global(h), color, 6, 110.0)
			ore.cells.erase(h)
	if ore.cells.is_empty():
		_remove_ore(ore)
		return
	var parts := Hex.components(ore.cells.keys())
	parts.sort_custom(func(a, b): return a.size() > b.size())
	for i in range(1, parts.size()):
		var weapons := {}
		for h in parts[i]:
			weapons[h] = ore.cells[h]
		var piece := Ore.new()
		piece.setup_from(ore, parts[i], weapons)
		for h in parts[i]:
			ore.cells.erase(h)
		piece.velocity = ore.velocity + Vector2.from_angle(randf() * TAU) * 20.0
		piece.angular_velocity = ore.angular_velocity + randf_range(-0.5, 0.5)
		_add_ore(piece)
	ore.recenter()


func _remove_ore(ore: Ore) -> void:
	if ore == tractor.ore:
		tractor.drop()
	ores.erase(ore)
	ore.queue_free()


func _despawn_far_objects() -> void:
	var limit := _view_radius() * _cfg.despawn_factor
	for a in asteroids.duplicate():
		if a is Boss:
			continue
		if a.global_position.distance_to(camera.global_position) > limit + a.bound_radius:
			asteroids.erase(a)
			a.queue_free()
	for ore in ores.duplicate():
		if not ore.dragged and ore.global_position.distance_to(camera.global_position) > limit:
			_remove_ore(ore)


# --- Camera / HUD -----------------------------------------------------------

## Os canhoes so miram no que aparece na tela: o alcance deles e maior que
## a area visivel, e o jogador precisa ver o asteroide antes dele ser destruido.
func _asteroids_on_screen() -> Array[Asteroid]:
	var half := get_viewport_rect().size / camera.zoom * 0.5
	var view := Rect2(camera.get_screen_center_position() - half, half * 2.0)
	var result: Array[Asteroid] = []
	for a in asteroids:
		if view.grow(-a.bound_radius * 0.5).has_point(a.global_position):
			result.append(a)
	return result


func _view_radius() -> float:
	return (get_viewport_rect().size / camera.zoom).length() * 0.5


## A camera nao segue a nave: so afasta o zoom conforme ela cresce e treme.
func _update_camera(delta: float) -> void:
	var target_zoom := clampf(260.0 / (player.bound_radius + 210.0), 0.3, 1.2) * ART_ZOOM
	camera.zoom = camera.zoom.lerp(Vector2.ONE * target_zoom, 1.0 - exp(-2.0 * delta))
	camera.offset = Vector2(randf_range(-1, 1), randf_range(-1, 1)) * _shake
	_shake = move_toward(_shake, 0.0, 40.0 * delta)


## O fundo rola no sentido contrario ao avanco; os efeitos acompanham a
## velocidade (que cresce com o tempo, ver TravelConfig).
func _scroll_background(delta: float) -> void:
	var speed := travel_config.speed_at(elapsed)
	starfield.cam_velocity = travel_config.direction() * speed
	starfield.cam_pos += starfield.cam_velocity * delta
	starfield.queue_redraw()
	var intensity := speed / maxf(travel_config.scroll_speed, 1.0)
	speed_fx.step(delta, intensity, player, asteroids, fx)


## Mantem a nave dentro da area visivel (com folga do tamanho dela).
func _keep_player_on_screen() -> void:
	var half := get_viewport_rect().size / camera.zoom * 0.5
	var margin := minf(player.bound_radius * 0.5 + 12.0, minf(half.x, half.y) * 0.8)
	var lo := camera.global_position - half + Vector2.ONE * margin
	var hi := camera.global_position + half - Vector2.ONE * margin
	var p := player.global_position
	var clamped := p.clamp(lo, hi)
	# Batendo na borda, perde a velocidade naquele eixo.
	if clamped.x != p.x:
		player.velocity.x = 0.0
	if clamped.y != p.y:
		player.velocity.y = 0.0
	player.global_position = clamped


func _to_screen(world_pos: Vector2) -> Vector2:
	return get_viewport().get_canvas_transform() * world_pos


func _update_hud() -> void:
	hud.race_bar.set_time(elapsed, travel_config.race_duration)
	hud.cells_card.set_value(player.cells.size())
	hud.cells_card.set_sub("COLETADOS %s" % UIStyle.fmt_int(collected))
	hud.time_card.set_text(UIStyle.fmt_time(elapsed))
	hud.cannon_card.set_counts(player.weapon_counts())


func _on_core_destroyed() -> void:
	if won:
		return
	game_over = true
	if tutorial != null:
		tutorial.finish(false)
	pause_menu.enabled = false
	tractor.drop()
	tractor.queue_redraw()
	ship_destroy_sfx.play()
	fx.burst(player.global_position, Player.CORE_COLOR, 60, 260.0)
	_shake = 25.0
	hud.damage_flash(1.0)
	var new_record := score > best_score
	if new_record:
		best_score = score
		SaveData.save_best_score(best_score)
	hud.show_game_over({
		"score": score, "best": best_score, "new_record": new_record,
		"time": elapsed, "max_cells": max_cells,
		"collected": collected, "destroyed": destroyed,
	})
