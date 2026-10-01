class_name Tutorial
extends Node
## Tutorial do inicio da partida. Enquanto ele roda, o spawn normal e o
## relogio da corrida ficam parados. Etapas:
## 1. So um meteoro de 4 celulas aparece e o nucleo o destroi sozinho; ele
##    sempre se parte em 2 pedacos de 2.
## 2. Camera lenta: explica a montagem (clicar num pedaco para ele encaixar
##    sozinho, ou segurar e arrastar ate a nave). Ao segurar o primeiro
##    pedaco, aparece a dica da roda do mouse para gira-lo.
## 3. Aparece um inimigo que sempre erra os tiros: uma rocha com uma peca de
##    cada lado, cada peca com 1 canhao. Ao morrer, solta essas 2 pecas.
## 4. Camera lenta: pede para encaixar os 2 canhoes; encaixados, abre a
##    janela das formacoes (FormationWindow), com o jogo pausado.
## 5. Camera lenta: explica o giro da nave (tecla R ou clique direito).
## Os asteroides do tutorial sao inofensivos (Asteroid.harmless). A camera
## lenta volta ao normal quando o jogador faz o que o texto pede (ou depois
## de SLOW_MAX). ENTER pula tudo.

## Escala de tempo da camera lenta e quanto tempo (real) leva para entrar/sair.
const SLOW := 0.15
const SLOW_BLEND := 0.35
## A camera lenta dura no maximo isso (segundos reais).
const SLOW_MAX := 6.0
## Uma etapa que espera o jogador segue sozinha depois disso (segundos reais).
const STEP_TIMEOUT := 35.0
## Segundos girando a nave para concluir a ultima etapa.
const ROTATE_GOAL := 1.0
## Meteoro do tutorial: 4 celulas que se partem sempre em 2 + 2.
const ROCK_SHAPE := {
	Vector2i(0, 0): Weapons.NONE, Vector2i(1, 0): Weapons.NONE,
	Vector2i(0, 1): Weapons.NONE, Vector2i(1, 1): Weapons.NONE,
}
const ROCK_PIECES := [[Vector2i(0, 0), Vector2i(1, 0)], [Vector2i(0, 1), Vector2i(1, 1)]]
## Inimigo do tutorial: rocha central (vira poeira) com uma peca de cada lado,
## cada uma com casco + 1 canhao comum (os canhoes nao se encostam).
const ENEMY_SHAPE := {
	Vector2i(-1, 0): Weapons.NONE, Vector2i(0, 0): Weapons.NONE, Vector2i(1, 0): Weapons.NONE,
	Vector2i(0, -1): Weapons.NONE, Vector2i(1, -1): Weapons.COMMON,
	Vector2i(0, 1): Weapons.NONE, Vector2i(-1, 1): Weapons.COMMON,
}
const ENEMY_PIECES := [[Vector2i(0, -1), Vector2i(1, -1)], [Vector2i(0, 1), Vector2i(-1, 1)]]
## Velocidade e folga ao passar pela nave.
const SPEED := 70.0
const GAP := 40.0
## Lado por onde os asteroides do tutorial passam (acima da nave, longe da
## caixa de texto, que fica embaixo).
const ABOVE := 1.0

enum Step { START, ROCK, ASSEMBLY, BREAK, ENEMY, UPGRADE, FORMATIONS, ROTATION, DONE }

## false depois que o tutorial acaba (ou e pulado).
var running := true

var _game: Node
var _panel: TutorialPanel
var _step := Step.START
## Segundos reais desde o inicio da etapa.
var _timer := 0.0
## Asteroide que a etapa atual espera ser destruido.
var _target: Asteroid
var _slow_target := 1.0
var _slow_left := 0.0
var _scale_before_pause := 1.0
var _rotated := 0.0
## Canhoes na nave (fora o do nucleo) quando o inimigo morreu.
var _turrets_before := 0
var _window: FormationWindow
## A dica da roda do mouse (girar o pedaco segurado) ja apareceu.
var _wheel_tip_shown := false

## O jogador ja pegou o primeiro pedaco e precisa gira-lo.
var _assembly_rotation_required := false

## O jogador ja girou o pedaco pelo menos uma vez.
var _assembly_rotated := false


func _init(game: Node) -> void:
	_game = game


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	
	_panel = TutorialPanel.new()
	add_child(_panel)
	_game.asteroid_destroyed.connect(_on_asteroid_destroyed)
	_game.piece_attached.connect(_on_piece_attached)
	_panel.show_tip("TUTORIAL", "SEU NÚCLEO",
		"O núcleo é a peça mais importante da nave: se ele for destruído, é fim de jogo. "
		+ "Os canhões atiram sozinhos no asteroide mais próximo.")


func _process(delta: float) -> void:
	if not running:
		return
	var real := delta / maxf(Engine.time_scale, 0.001)
	_timer += real
	_update_slow(real)
	match _step:
		Step.START:
			if _timer > 1.5:
				_spawn_target(false)
				_go(Step.ROCK)
		Step.ROCK, Step.ENEMY:
			_respawn_if_lost()
		Step.ASSEMBLY:
			if not _assembly_rotation_required and _game.tractor.ore != null:
				_start_piece_rotation_tutorial()
		Step.BREAK:
			if _timer > 1.5:
				_spawn_target(true)
				_panel.show_tip("TUTORIAL", "INIMIGO", "Asteroides armados atiram na nave: cada acerto "
					+ "destrói um hexágono. O cano brilha em vermelho antes do tiro.", UIStyle.RED)
				_go(Step.ENEMY)
		Step.UPGRADE:
			if _timer > STEP_TIMEOUT or _nothing_to_grab(true):
				_show_formations()
		Step.ROTATION:
			if _game.player.turning:
				_rotated += real
				_release_slow()
			if _rotated >= ROTATE_GOAL or _timer > STEP_TIMEOUT:
				_panel.show_tip("TUTORIAL", "TUDO PRONTO",
					"Agora é pra valer: os asteroides vão ficar maiores e mais armados. "
					+ "Chegue até a bandeira!", UIStyle.GREEN)
				_go(Step.DONE)
		Step.DONE:
			if _timer > 3.0:
				finish(false)

func _start_piece_rotation_tutorial() -> void:
	_assembly_rotation_required = true
	_assembly_rotated = false

	# Pausa completamente o jogo.
	get_tree().paused = true

	_panel.show_tip(
		"TUTORIAL 1/3",
		"GIRAR DESTROÇO",
		"Para facilitar a formação dos canhões melhores, utilize {WHEEL} "
		+ "para rotacionar a peça na direção necessária.",
		Ore.COLOR
		)

func _unhandled_input(event: InputEvent) -> void:
	if not running:
		return

	# ENTER pula o tutorial inteiro.
	if event is InputEventKey and event.pressed and not event.echo \
			and event.physical_keycode in [KEY_ENTER, KEY_KP_ENTER]:
		get_viewport().set_input_as_handled()
		finish(false)
		return

	# Durante a etapa obrigatória, o jogador precisa usar o scroll.
	if _step == Step.ASSEMBLY \
			and _assembly_rotation_required \
			and not _assembly_rotated \
			and _game.tractor.ore != null:

		if event is InputEventMouseButton \
				and event.pressed:
					if event.button_index == MOUSE_BUTTON_WHEEL_UP:
						_game.tractor.turn(1)
					if event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
						_game.tractor.turn(-1)
					else:
						return
					_assembly_rotated = true

			# Libera o jogo depois da rotação.
					get_tree().paused = false

					_panel.show_tip(
						"TUTORIAL 1/3",
						"MONTAGEM",
						"Muito bem! Agora encaixe o pedaço na nave. "
						+ "Clique nele ou segure e arraste até a posição desejada.",
						Ore.COLOR
					)
					get_viewport().set_input_as_handled()

## Encerra o tutorial (pulado, concluido ou fim de jogo) e devolve a
## velocidade normal. O spawn normal recomeca sozinho.
func finish(_completed: bool) -> void:
	if not running:
		return
	running = false
	if _window != null and is_instance_valid(_window):
		_window.queue_free()
		_end_pause()
	Engine.time_scale = 1.0
	_panel.hide_tip()


func _notification(what: int) -> void:
	# Menu de pausa em tempo normal; a camera lenta volta ao continuar.
	if what == NOTIFICATION_PAUSED:
		_scale_before_pause = Engine.time_scale
		Engine.time_scale = 1.0
	elif what == NOTIFICATION_UNPAUSED and running:
		Engine.time_scale = _scale_before_pause
	elif what == NOTIFICATION_EXIT_TREE:
		Engine.time_scale = 1.0


func _go(step: Step) -> void:
	_step = step
	_timer = 0.0


func _on_asteroid_destroyed(a: Asteroid) -> void:
	if not running or a != _target:
		return
	_target = null
	if _step == Step.ROCK:
		_slow(true)
		_panel.show_tip(
			"TUTORIAL  1/3", "MONTAGEM",
			"Asteroides destruidos viram pedaços de casco"
			+ "Clique em um pedaço para segurá-lo.",
			Ore.COLOR
			)
		_go(Step.ASSEMBLY)
	elif _step == Step.ENEMY:
		_slow(true)
		_turrets_before = _turret_count()
		_panel.show_tip("TUTORIAL  2/3", "CANHÕES",
			"Inimigos derrubam canhões. Encaixe as duas peças com canhão na nave como os pedaços "
			+ "de casco: clique {LMB} nelas ou segure e arraste.", Weapons.color(Weapons.COMMON))
		_go(Step.UPGRADE)


func _on_piece_attached(_placement: Dictionary) -> void:
	if not running:
		return
	if _step == Step.ASSEMBLY:
		# O tutorial so permite continuar depois que o jogador
		# tiver girado a peca pelo menos uma vez.
		if _assembly_rotated:
			_to_break()
		return
	elif _step == Step.UPGRADE and _turret_count() >= _turrets_before + 2:
		_show_formations()


func _to_break() -> void:
	_release_slow()
	_panel.hide_tip()
	_go(Step.BREAK)


func _to_rotation() -> void:
	_slow(true)
	_rotated = 0.0
	_panel.show_tip("TUTORIAL  3/3", "GIRAR A NAVE",
		"Segure {R} ou {RMB} para girar a nave na direção do mouse. "
		+ "Use para apontar os canhões e virar o casco para os asteroides.", Player.CORE_COLOR)
	_go(Step.ROTATION)


## Os dois canhoes do inimigo encaixados (ou perdidos): janela grande com as
## formacoes, com o jogo pausado. Ao fechar, segue para o giro da nave.
func _show_formations() -> void:
	_release_slow()
	_panel.hide_tip()
	_go(Step.FORMATIONS)
	_window = FormationWindow.new()
	_window.closed.connect(_on_formations_closed)
	add_child(_window)
	get_tree().paused = true
	_game.pause_menu.enabled = false
	_game.hud.set_playing(false)


func _on_formations_closed() -> void:
	_window = null
	_end_pause()
	_to_rotation()


func _end_pause() -> void:
	get_tree().paused = false
	_game.pause_menu.enabled = true
	_game.hud.set_playing(true)


## Canhoes comuns montados na nave, fora o do nucleo.
func _turret_count() -> int:
	var n := 0
	for h in _game.player.cells:
		if h != Player.CORE and _game.player.cells[h] != Weapons.NONE:
			n += 1
	return n


## Manda o meteoro (ou o inimigo) do tutorial.
func _spawn_target(enemy: bool) -> void:
	_target = _game.spawn_scripted_asteroid(ENEMY_SHAPE if enemy else ROCK_SHAPE,
		ENEMY_PIECES if enemy else ROCK_PIECES, ABOVE, GAP, SPEED)


## O asteroide esperado saiu da tela sem ser destruido: manda outro igual.
func _respawn_if_lost() -> void:
	if _target != null and is_instance_valid(_target) and _game.asteroids.has(_target):
		return
	_spawn_target(_step == Step.ENEMY)


## Nao sobrou nada para o jogador pegar (os pedacos sumiram ou foram
## destruidos): a etapa segue sem esperar. `cannons` = so pedacos com canhao.
func _nothing_to_grab(cannons: bool) -> bool:
	if _game.tractor.ore != null:
		return false
	for ore: Ore in _game.ores:
		if not cannons or ore.has_cannon():
			return false
	return true


# --- Camera lenta ------------------------------------------------------------

func _slow(on: bool) -> void:
	_slow_target = SLOW if on else 1.0
	_slow_left = SLOW_MAX if on else 0.0


## Volta a velocidade normal (o jogador ja esta fazendo o que o texto pede).
func _release_slow() -> void:
	_slow(false)


func _update_slow(real: float) -> void:
	if _slow_target < 1.0:
		_slow_left -= real
		if _slow_left <= 0.0 or (_game.tractor.ore != null and _step in [Step.ASSEMBLY, Step.UPGRADE]):
			_release_slow()
	var speed := (1.0 - SLOW) / SLOW_BLEND
	Engine.time_scale = move_toward(Engine.time_scale, _slow_target, real * speed)
