class_name Tractor
extends Node2D
## Raio trator: clique e arraste um pedaço de minério (dentro do alcance da
## nave) e solte perto da nave para encaixá-lo no grid. O pedaço se alinha
## ao grid da nave em passos de 60°; a roda do mouse gira o pedaço.

## placement: {célula da nave: canhão}, pronto para Player.attach_piece().
signal attached(ore: Ore, placement: Dictionary)

## Alcance além da borda da nave.
const RANGE := 200.0
## Distância do mouse a uma célula do pedaço para conseguir pegá-lo.
const PICK_RADIUS := Hex.SIZE * 1.6
## Distância do pedaço ao encaixe para ele grudar ao soltar.
const SNAP_DIST := Hex.SIZE * 2.4
## Quão rápido o pedaço segue o mouse e gira até o alinhamento.
const FOLLOW := 16.0
const ALIGN := 14.0

## Pedaço sendo arrastado (ou null).
var ore: Ore = null
## Pedaço sob o mouse, quando nada está sendo arrastado.
var hover: Ore = null
## Onde o pedaço vai encaixar se for solto agora ({} = em lugar nenhum).
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
		if not pressed or not player.alive:
			_release()
		else:
			_drag(delta, mouse)
	queue_redraw()


## Gira o pedaço segurado em passos de 60° (+1 horário, -1 anti-horário).
func turn(steps: int) -> void:
	if ore != null:
		_turns += steps


## Solta o pedaço sem encaixar (ex.: game over).
func drop() -> void:
	if ore != null and is_instance_valid(ore):
		ore.dragged = false
		ore.z_index = 1
	ore = null
	placement = {}


func _grab(piece: Ore, mouse: Vector2) -> void:
	ore = piece
	ore.dragged = true
	ore.z_index = 3
	# Começa no alinhamento de 60° mais próximo do ângulo atual do pedaço.
	_turns = roundi(wrapf(ore.rotation - _player.rotation, -PI, PI) / (PI / 3.0))
	_grab_offset = ore.global_position - mouse
	hover = null


func _drag(delta: float, mouse: Vector2) -> void:
	# O pedaço segue o mouse (mantendo o ponto onde foi pego), preso ao alcance.
	var center := _player.global_position
	var target := center + (mouse + _grab_offset - center).limit_length(reach(_player))
	var new_pos := ore.global_position.lerp(target, 1.0 - exp(-FOLLOW * delta))
	ore.velocity = (new_pos - ore.global_position) / maxf(delta, 0.0001)
	ore.global_position = new_pos
	# E gira até ficar alinhado com o grid da nave.
	var aligned := _player.rotation + _turns * PI / 3.0
	ore.rotation = lerp_angle(ore.rotation, aligned, 1.0 - exp(-ALIGN * delta))
	placement = _player.find_placement(ore, _turns, SNAP_DIST)


func _release() -> void:
	var released := ore
	var fit := placement
	drop()
	if not fit.is_empty():
		attached.emit(released, fit)
	else:
		released.velocity *= 0.6  # arremesso suave
		released.angular_velocity = randf_range(-0.6, 0.6)


func _in_reach(piece: Ore) -> bool:
	return piece.global_position.distance_to(_player.global_position) - piece.bound_radius <= reach(_player)


func _piece_under(mouse: Vector2, ores: Array[Ore]) -> Ore:
	var best: Ore = null
	var best_dist := INF
	for o in ores:
		if o.global_position.distance_to(mouse) > o.bound_radius + PICK_RADIUS:
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
	if ore != null:
		var color := ore.main_color()
		# Alcance do raio.
		draw_arc(center, reach(_player), 0.0, TAU, 96, Color(color, 0.12), 2.0, true)
		# Feixe da nave até o pedaço, com pulsos correndo por ele.
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


## Hexágonos fantasmas nos encaixes onde o pedaço vai grudar.
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
