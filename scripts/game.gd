extends Node2D
## Controlador principal: spawn, colisoes, camera e HUD.

## Asteroides nascem esta distancia alem da borda da tela.
const SPAWN_MARGIN := 120.0
## Sao removidos quando ficam mais longe que (raio da tela * fator).
const DESPAWN_FACTOR := 2.5
const MAX_ASTEROIDS := 100
## Maximo de minerios soltos na tela ao mesmo tempo.
const MAX_ORES := 150
## Fracao das celulas do asteroide que se perde quando ele se parte em minerio.
const ORE_LOSS := 0.2
## Tamanho (em celulas) dos pedacos em que o asteroide se parte.
const PIECE_MIN := 2
const PIECE_MAX := 4
## Aproxima a camera para as artes aparecerem maiores (1.0 = escala original).
const ART_ZOOM := 1.2

var player: Player
var bullets: Bullets
var missiles: Missiles
var lasers: Lasers
var tractor: Tractor
var fx: Fx
var camera: Camera2D
var music: AudioStreamPlayer
var cannon_sfx: AudioStreamPlayer
var laser_sfx: AudioStreamPlayer
var starfield: Starfield
var hud: Hud
var pause_menu: PauseMenu
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
var _spawn_timer := 1.0
var _shake := 0.0


func _ready() -> void:
	randomize()
	# As artes aparecem bem menores que o original e giram: mipmaps evitam serrilhado.
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	InputActions.ensure_defaults()
	best_score = SaveData.best_score()
	
	music = AudioStreamPlayer.new()
	music.stream = preload("res://Audio/Music/battle.wav")
	music.volume_db = -20.0
	add_child(music)
	music.play()
	
	cannon_sfx = AudioStreamPlayer.new()
	cannon_sfx.stream = preload("res://Audio/SFX/cannon_shot.wav")
	cannon_sfx.volume_db = -25.0
	add_child(cannon_sfx)
	
	laser_sfx = AudioStreamPlayer.new()
	laser_sfx.stream = preload("res://Audio/SFX/laser_shot_final.wav")
	laser_sfx.volume_db = -20.0
	add_child(laser_sfx)

	var bg := CanvasLayer.new()
	bg.layer = -1
	add_child(bg)
	starfield = Starfield.new()
	bg.add_child(starfield)

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


func _on_laser_started() -> void:
	if not laser_sfx.playing:
		laser_sfx.play()


func _on_laser_stopped() -> void:
	if laser_sfx.playing:
		laser_sfx.stop()

func _physics_process(delta: float) -> void:
	if not game_over:
		elapsed += delta
		player.aim = get_global_mouse_position()
		player.step(delta)
		# Tiro automatico: cada canhao mira no asteroide mais proximo dele.
		player.update_targets(delta, _asteroids_on_screen())
		for shot in player.fire():
			_fire_shot(shot)
		tractor.step(delta, player, ores, get_global_mouse_position(),
			Input.is_action_pressed("drag"), Input.is_action_just_pressed("drag"))

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

	if not game_over:
		_check_player_collisions()
	_update_ores(delta)
	fx.step(delta)

	_spawn_asteroids(delta)
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
	get_tree().reload_current_scene()


func _go_to_menu() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file(MainMenu.SCENE)


# --- Canhoes ----------------------------------------------------------------

## shot: {type, cell, origin, dir, target_pos} vindo de Player.fire().
func _fire_shot(shot: Dictionary) -> void:
	var origin: Vector2 = shot.origin
	var dir: Vector2 = shot.dir
	var color := Weapons.color(shot.type).lightened(0.4)
	
	if shot.type == Weapons.COMMON or shot.type == Weapons.SHOTGUN:
		cannon_sfx.play()
	
	match shot.type:
		Weapons.COMMON:
			bullets.spawn(origin, dir * Weapons.BULLET_SPEED + player.velocity, Weapons.BULLET_LIFE, color)
		Weapons.SHOTGUN:
			for i in Weapons.PELLETS:
				var t := float(i) / (Weapons.PELLETS - 1) - 0.5
				var pellet_dir := dir.rotated(t * Weapons.PELLET_SPREAD + randf_range(-0.05, 0.05))
				var speed := Weapons.PELLET_SPEED * randf_range(0.9, 1.1)
				bullets.spawn(origin, pellet_dir * speed + player.velocity, Weapons.PELLET_LIFE, color)
		Weapons.LASER:
			lasers.start(shot.cell)
			if not laser_sfx.playing:
				laser_sfx.play()
		Weapons.BOMB:
			missiles.launch(origin, shot.target_pos, player.velocity)


func _grant_common_cannon() -> void:
	var h := player.add_common_cannon()
	var at := player.cell_global(h)
	fx.burst(at, Weapons.color(Weapons.COMMON), 14, 120.0)
	hud.popup("+CANHÃO", Weapons.color(Weapons.COMMON), _to_screen(at + Vector2(0, -20)), 14)


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
	# Vai na direcao geral do jogador, com um desvio aleatorio.
	var heading := (player.global_position - a.position).normalized().rotated(randf_range(-0.6, 0.6))
	var speed := randf_range(30.0, 85.0) * (1.2 - minf(n, 30) / 60.0)
	a.velocity = heading * speed
	a.angular_velocity = randf_range(-0.8, 0.8) / sqrt(n)
	a.rotation = randf() * TAU
	add_child(a)
	asteroids.append(a)


## Tamanhos pequenos sao mais comuns (minimo Asteroid.MIN_SIZE); o maximo
## cresce com o tempo e com o poder de fogo (numero de canhoes, ja que o
## casco nao atira).
func _roll_asteroid_size() -> int:
	var cannons := 0
	for n in player.weapon_counts().values():
		cannons += n
	var max_n := clampi(3 + int(elapsed / 10.0) + int(cannons * 1.5), Asteroid.MIN_SIZE, 40)
	return Asteroid.MIN_SIZE + int(pow(randf(), 1.7) * (max_n - Asteroid.MIN_SIZE + 1))


## Batidas entre asteroides (cada par uma vez por frame).
func _collide_asteroids() -> void:
	for i in asteroids.size():
		for j in range(i + 1, asteroids.size()):
			asteroids[i].collide_with(asteroids[j])


## Asteroide destruido pelos canhoes: pontos, progresso de canhao e minerio.
func _destroy_asteroid(a: Asteroid) -> void:
	asteroids.erase(a)
	if not game_over:
		score += a.max_hp
		destroyed += 1
		hud.popup("+%s" % UIStyle.fmt_int(a.max_hp), UIStyle.GOLD, _to_screen(a.global_position),
			clampi(14 + (a.size >> 1), 14, 24))
		if destroyed % Weapons.ASTEROIDS_PER_COMMON == 0:
			_grant_common_cannon()
	_break_into_ore(a)
	a.queue_free()


## O asteroide se parte em pedacos de PIECE_MIN..PIECE_MAX celulas conectadas,
## no mesmo lugar em que estavam; ORE_LOSS das celulas some (vira poeira).
func _break_into_ore(a: Asteroid) -> void:
	var keys := a.cells.keys()
	keys.shuffle()
	# Arredondamento sorteado: em media perde exatamente ORE_LOSS.
	var exact := keys.size() * (1.0 - ORE_LOSS)
	var count := int(exact) + (1 if randf() < exact - int(exact) else 0)
	for i in range(count, keys.size()):
		fx.burst(a.cell_global(keys[i]), a.base_color.darkened(0.2), 6, 90.0)
	var kept := keys.slice(0, count)
	if kept.is_empty():
		return

	# As vezes uma das celulas e de canhao especial (mais chance em asteroides maiores).
	var weapons := {}
	if randf() < Weapons.special_drop_chance(a.size):
		weapons[kept[randi() % kept.size()]] = Weapons.roll_special()

	for group in _split_into_pieces(kept):
		var ore := Ore.new()
		ore.setup_from(a, group, weapons)
		var outward := (ore.global_position - a.global_position).normalized()
		if outward == Vector2.ZERO:
			outward = Vector2.from_angle(randf() * TAU)
		ore.velocity = a.velocity + outward.rotated(randf_range(-0.4, 0.4)) * randf_range(20.0, 55.0)
		ore.angular_velocity = randf_range(-1.0, 1.0)
		_add_ore(ore)
	for h in kept:
		fx.burst(a.cell_global(h), a.base_color.lightened(0.2), 2, 70.0)
	_trim_ores()


## Divide celulas em grupos conectados de PIECE_MIN..PIECE_MAX celulas.
## Comeca e cresce pelas celulas com menos vizinhos livres (as que ficariam
## isoladas) e, no fim, cola as sobras de 1 celula num pedaco vizinho.
func _split_into_pieces(keys: Array) -> Array:
	var left := {}
	for h in keys:
		left[h] = true
	var piece_of := {}
	var pieces := []
	while not left.is_empty():
		var start := _most_isolated(left.keys(), left)
		left.erase(start)
		var piece: Array[Vector2i] = [start]
		var target := randi_range(PIECE_MIN, PIECE_MAX)
		while piece.size() < target:
			var options: Array[Vector2i] = []
			for h in piece:
				for d in Hex.DIRS:
					if left.has(h + d) and not options.has(h + d):
						options.append(h + d)
			if options.is_empty():
				break
			var pick := _most_isolated(options, left)
			left.erase(pick)
			piece.append(pick)
		for h in piece:
			piece_of[h] = pieces.size()
		pieces.append(piece)

	# Sobras de 1 celula entram num pedaco vizinho (ele pode passar de PIECE_MAX).
	for i in pieces.size():
		if pieces[i].size() != 1:
			continue
		var h: Vector2i = pieces[i][0]
		for d in Hex.DIRS:
			var j: int = piece_of.get(h + d, -1)
			if j != -1 and j != i and not pieces[j].is_empty():
				pieces[j].append(h)
				piece_of[h] = j
				pieces[i] = []
				break
	return pieces.filter(func(piece): return not piece.is_empty())


## A celula com menos vizinhos ainda livres (desempate aleatorio).
func _most_isolated(candidates: Array, left: Dictionary) -> Vector2i:
	var best: Vector2i = candidates[0]
	var best_rank := INF
	for h in candidates:
		var free := 0
		for d in Hex.DIRS:
			if left.has(h + d):
				free += 1
		var rank := free + randf() * 0.5
		if rank < best_rank:
			best_rank = rank
			best = h
	return best


func _add_ore(ore: Ore) -> void:
	ore.z_index = 1
	add_child(ore)
	ores.append(ore)


## Limita os minerios soltos: remove os mais antigos, preferindo os sem
## canhao. O pedaco que esta sendo arrastado nunca sai.
func _trim_ores() -> void:
	while ores.size() > MAX_ORES:
		var loose := ores.filter(func(o): return not o.dragged)
		var plain := loose.filter(func(o): return not o.has_special())
		_remove_ore(plain[0] if not plain.is_empty() else loose[0])


## Contato celula a celula: cada celula de asteroide que encosta na nave
## destroi a celula da nave que ela tocou; depois de CELL_CHARGES destruicoes
## ela some. Partes da nave que se soltarem do nucleo viram pedacos soltos.
func _check_player_collisions() -> void:
	var hits := PackedVector2Array()
	var core_hit := false
	for a: Asteroid in asteroids.duplicate():
		var reach := a.bound_radius + player.bound_radius
		if a.global_position.distance_squared_to(player.global_position) > reach * reach:
			continue
		var spent: Array[Vector2i] = []
		for h in a.cells:
			var target := player.find_cell_near(a.cell_global(h), HexBody.CONTACT_DIST)
			if target == HexBody.NO_CELL:
				continue
			hits.append(player.cell_global(target))
			if a.spend_charge(h):
				spent.append(h)
			if player.destroy_cell(target):
				core_hit = true
				break
		if not spent.is_empty():
			for h in spent:
				fx.burst(a.cell_global(h), a.base_color, 5, 110.0)
			for piece in a.remove_cells(spent):
				if piece.size < Asteroid.MIN_SIZE:
					_crumble(piece)
					piece.free()
				else:
					add_child(piece)
					asteroids.append(piece)
			if a.cells.size() < Asteroid.MIN_SIZE:
				_crumble(a)
				asteroids.erase(a)
				a.queue_free()
		if core_hit:
			break
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


## Asteroide pequeno demais (menos de MIN_SIZE celulas) vira poeira.
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
	if not is_instance_valid(ore) or not player.attach_piece(placement):
		return
	collected += placement.size()
	max_cells = maxi(max_cells, player.cells.size())
	var center := Vector2.ZERO
	for slot in placement:
		var at := player.cell_global(slot)
		center += at
		var w: int = placement[slot]
		if w == Weapons.NONE:
			fx.burst(at, Ore.COLOR, 6, 80.0)
		else:
			fx.burst(at, Weapons.color(w), 16, 140.0)
			hud.popup("+%s" % Weapons.NAMES[w], Weapons.color(w), _to_screen(at), 15)
	hud.popup("+%d" % placement.size(), UIStyle.GREEN, _to_screen(center / placement.size()), 14)
	_remove_ore(ore)


func _remove_ore(ore: Ore) -> void:
	if ore == tractor.ore:
		tractor.drop()
	ores.erase(ore)
	ore.queue_free()


func _despawn_far_objects() -> void:
	var limit := _view_radius() * DESPAWN_FACTOR
	for a in asteroids.duplicate():
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


func _update_camera(delta: float) -> void:
	# Afasta a camera conforme a nave cresce.
	var target_zoom := clampf(260.0 / (player.bound_radius + 210.0), 0.3, 1.2) * ART_ZOOM
	camera.zoom = camera.zoom.lerp(Vector2.ONE * target_zoom, 1.0 - exp(-2.0 * delta))
	camera.global_position = camera.global_position.lerp(player.global_position, 1.0 - exp(-8.0 * delta))
	camera.offset = Vector2(randf_range(-1, 1), randf_range(-1, 1)) * _shake
	_shake = move_toward(_shake, 0.0, 40.0 * delta)
	starfield.cam_pos = camera.global_position
	starfield.queue_redraw()


func _to_screen(world_pos: Vector2) -> Vector2:
	return get_viewport().get_canvas_transform() * world_pos


func _update_hud() -> void:
	hud.score_card.set_value(score)
	hud.score_card.set_sub("RECORDE %s" % UIStyle.fmt_int(maxi(best_score, score)))
	hud.cells_card.set_value(player.cells.size())
	hud.cells_card.set_sub("COLETADOS %s" % UIStyle.fmt_int(collected))
	hud.time_card.set_text(UIStyle.fmt_time(elapsed))
	hud.cannon_card.set_counts(player.weapon_counts())
	hud.cannon_card.set_progress(destroyed % Weapons.ASTEROIDS_PER_COMMON)


func _on_core_destroyed() -> void:
	game_over = true
	pause_menu.enabled = false
	tractor.drop()
	tractor.queue_redraw()
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
