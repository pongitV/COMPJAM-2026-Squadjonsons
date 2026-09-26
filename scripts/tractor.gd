class_name Tractor
extends Node2D
## Raio trator: clique e arraste um pedaco de minerio (dentro do alcance da
## nave) e solte perto da nave para encaixa-lo no grid. O pedaco se alinha
## ao grid da nave em passos de 60 graus; a roda do mouse gira o pedaco.
## Um clique rapido (sem segurar) puxa o pedaco sozinho ate a nave, e ele
## encaixa no primeiro lugar em que couber.

## placement: {celula da nave: canhao}, pronto para Player.attach_piece().
signal attached(ore: Ore, placement: Dictionary)

## Alcance alem da borda da nave.
const RANGE := 200.0
## Distancia do mouse a uma celula do pedaco para conseguir pega-lo.
const PICK_RADIUS := Hex.SIZE * 1.6
## Distancia do pedaco ao encaixe para ele grudar ao soltar.
const SNAP_DIST := Hex.SIZE * 2.4
## Quao rapido o pedaco segue o mouse e gira ate o alinhamento.
const FOLLOW := 16.0
const ALIGN := 14.0
## Soltar antes deste tempo conta como clique rapido (puxa sozinho).
const QUICK_CLICK := 0.25
## Velocidade do pedaco puxado e tempo maximo tentando encaixar.
const PULL_SPEED := 420.0
const PULL_TIMEOUT := 4.0

## Pedaco sendo arrastado (ou null).
var ore: Ore = null
## Pedacos sendo puxados sozinhos: [{ore, turns, time}].
var _pulled: Array[Dictionary] = []
var _held := 0.0
## Pedaco sob o mouse, quando nada esta sendo arrastado.
var hover: Ore = null
## Onde o pedaco vai encaixar se for solto agora ({} = em lugar nenhum).
var placement := {}
var _turns := 0
var _grab_offset := Vector2.ZERO
var _player: Player
var _t := 0.0


func reach(player: Player) -> float:
	return player.bound_radius + RANGE


func step(delta: float, player: Player, ores: Array[Ore], mouse: Vector2, pressed: bool, just_pressed: bool) -> void:
	_player = player
	_t += delta
	if ore != null and not is_instance_valid(ore):
		ore = null
	hover = null
	if ore == null and player.alive:
		hover = _piece_under(mouse, ores)
		if just_pressed and hover != null and _in_reach(hover):
			_grab(hover, mouse)

	if ore != null:
		_held += delta
		if not pressed or not player.alive:
			_release()
		else:
			_drag(delta, mouse)
	_step_pulled(delta)
	queue_redraw()


## Pedacos puxados: vao ate a nave, alinhados ao grid, e encaixam assim que
## houver lugar. Desistem se demorarem demais (ex.: sem espaco livre).
func _step_pulled(delta: float) -> void:
	for p in _pulled.duplicate():
		var piece: Ore = p.ore if is_instance_valid(p.ore) else null
		p.time += delta
		if piece == null or not _player.alive or p.time > PULL_TIMEOUT:
			if piece != null:
				piece.dragged = false
			_pulled.erase(p)
			continue
		var to_ship := _player.global_position - piece.global_position
		var move := to_ship.limit_length(PULL_SPEED * delta)
		piece.velocity = move / maxf(delta, 0.0001)
		piece.global_position += move
		var turns: int = p.turns
		var aligned := _player.rotation + turns * PI / 3.0
		piece.rotation = lerp_angle(piece.rotation, aligned, 1.0 - exp(-ALIGN * delta))
		var fit := _player.find_placement(piece, p.turns, SNAP_DIST)
		if not fit.is_empty():
			piece.dragged = false
			_pulled.erase(p)
			attached.emit(piece, fit)


## Um pedaco esta sendo segurado (arrastado) ha mais tempo que um clique rapido.
func holding() -> bool:
	return ore != null and _held >= QUICK_CLICK


## Gira o pedaco segurado em passos de 60 graus (+1 horario, -1 anti-horario).
func turn(steps: int) -> void:
	if ore != null:
		_turns += steps


## Solta o pedaco sem encaixar (ex.: game over).
func drop() -> void:
	if ore != null and is_instance_valid(ore):
		ore.dragged = false
		ore.z_index = 1
	ore = null
	placement = {}


## Solta tambem os pedacos que estavam sendo puxados (fim de jogo).
func drop_all() -> void:
	drop()
	for p in _pulled:
		if is_instance_valid(p.ore):
			p.ore.dragged = false
	_pulled.clear()


func _grab(piece: Ore, mouse: Vector2) -> void:
	ore = piece
	ore.dragged = true
	ore.z_index = 3
	# Comeca no alinhamento de 60 graus mais proximo do angulo atual do pedaco.
	_turns = roundi(wrapf(ore.rotation - _player.rotation, -PI, PI) / (PI / 3.0))
	_grab_offset = ore.global_position - mouse
	_held = 0.0
	hover = null


func _drag(delta: float, mouse: Vector2) -> void:
	# O pedaco segue o mouse (mantendo o ponto onde foi pego), preso ao alcance.
	var center := _player.global_position
	var target := center + (mouse + _grab_offset - center).limit_length(reach(_player))
	var new_pos := ore.global_position.lerp(target, 1.0 - exp(-FOLLOW * delta))
	ore.velocity = (new_pos - ore.global_position) / maxf(delta, 0.0001)
	ore.global_position = new_pos
	# E gira ate ficar alinhado com o grid da nave.
	var aligned := _player.rotation + _turns * PI / 3.0
	ore.rotation = lerp_angle(ore.rotation, aligned, 1.0 - exp(-ALIGN * delta))
	placement = _player.find_placement(ore, _turns, SNAP_DIST)


func _release() -> void:
	var released := ore
	var fit := placement
	var quick := _held < QUICK_CLICK
	drop()
	if not fit.is_empty():
		attached.emit(released, fit)
	elif quick and _player.alive:
		# Clique rapido: o pedaco segue sozinho ate a nave.
		released.dragged = true
		_pulled.append({"ore": released, "turns": _turns, "time": 0.0})
	else:
		released.velocity *= 0.6  # arremesso suave
		released.angular_velocity = randf_range(-0.6, 0.6)


func _in_reach(piece: Ore) -> bool:
	return piece.global_position.distance_to(_player.global_position) - piece.bound_radius <= reach(_player)


func _piece_under(mouse: Vector2, ores: Array[Ore]) -> Ore:
	var best: Ore = null
	var best_dist := INF
	for o in ores:
		# Pedacos ja presos no raio (arrastado ou sendo puxado) ficam de fora.
		if o.dragged or o.global_position.distance_to(mouse) > o.bound_radius + PICK_RADIUS:
			continue
		var h := o.find_cell_near(mouse, PICK_RADIUS)
		if h == HexBody.NO_CELL:
			continue
		var d := o.cell_global(h).distance_to(mouse)
		if d < best_dist:
			best_dist = d
			best = o
	return best


func _draw() -> void:
	if _player == null or not _player.alive:
		return
	var center := _player.global_position
	# Feixes finos puxando os pedacos do clique rapido.
	for p in _pulled:
		if is_instance_valid(p.ore):
			var c: Color = p.ore.main_color()
			draw_line(center, p.ore.global_position, Color(c, 0.5), 1.5, true)
	if ore != null:
		var color := ore.main_color()
		# Alcance do raio.
		draw_arc(center, reach(_player), 0.0, TAU, 96, Color(color, 0.12), 2.0, true)
		# Feixe da nave ate o pedaco, com pulsos correndo por ele.
		var p := ore.global_position
		draw_line(center, p, Color(color, 0.18), 9.0, true)
		draw_line(center, p, Color(color, 0.7), 2.0, true)
		for i in 4:
			var k := fmod(_t * 1.5 + i * 0.25, 1.0)
			draw_circle(p.lerp(center, k), 3.0, Color(color.lightened(0.5), 1.0 - k * 0.6))
		if not placement.is_empty():
			_draw_ghost()
	elif hover != null:
		var ok := _in_reach(hover)
		var ring := UIStyle.CYAN if ok else UIStyle.RED
		var pulse := 1.0 + 0.08 * sin(_t * 8.0)
		draw_arc(hover.global_position, (hover.bound_radius + 4.0) * pulse, 0.0, TAU, 40, Color(ring, 0.9), 2.0, true)
		if not ok:
			draw_arc(center, reach(_player), 0.0, TAU, 96, Color(UIStyle.RED, 0.15), 2.0, true)


## Hexagonos fantasmas nos encaixes onde o pedaco vai grudar.
func _draw_ghost() -> void:
	var pulse := 0.5 + 0.5 * sin(_t * 10.0)
	var corners := Hex.corners()
	for slot in placement:
		var w: int = placement[slot]
		var color := Ore.COLOR if w == Weapons.NONE else Weapons.color(w)
		var c := _player.cell_global(slot)
		var pts := PackedVector2Array()
		for corner in corners:
			pts.append(c + corner.rotated(_player.rotation))
		draw_colored_polygon(pts, Color(color, 0.25 + 0.2 * pulse))
		pts.append(pts[0])
		draw_polyline(pts, Color(1, 1, 1, 0.6 + 0.4 * pulse), 2.0, true)
