class_name HexBody
extends Node2D
## Base de todo objeto composto por celulas hexagonais
## (jogador, asteroides e minerios).

## Distancia entre centros a partir da qual duas celulas se tocam.
const CONTACT_DIST := Hex.SQRT3 * Hex.SIZE * 0.92
## "Nenhuma celula" (retorno de find_cell_near).
const NO_CELL := Vector2i(1 << 30, 1 << 30)
## Tamanho dos canos desenhados em relacao a arte do canhao.
const BARREL_SCALE := 0.5
## Contorno dos canhoes: a propria arte em preto, deslocada para os lados.
const OUTLINE_COLOR := Color(0.0, 0.0, 0.0, 0.85)
const OUTLINE_OFFSETS := [Vector2(1.2, 0), Vector2(-1.2, 0), Vector2(0, 1.2), Vector2(0, -1.2)]

## Vector2i (coordenada axial) -> tipo da celula (Weapons.NONE ou COMMON)
var cells: Dictionary = {}
## Canhoes formados pelas celulas de canhao comum (ver CannonGroups).
var groups: Array = []
## Vector2i -> indice em `groups`.
var _group_of := {}
## Deslocamento do centro de rotacao em relacao a celula (0, 0).
var center_offset := Vector2.ZERO
var velocity := Vector2.ZERO
var angular_velocity := 0.0
## Raio de um circulo que envolve o objeto inteiro (broad-phase).
var bound_radius := Hex.SIZE
## 0..1, usado para piscar ao receber dano.
var flash := 0.0

# Malha em cache: cada celula e um quadrado com a arte da flor (do atlas
# Art), e todas viram UMA lista de triangulos, recalculada so quando a forma
# ou as cores mudam.
var _geometry_dirty := true
var _colors_dirty := true
var _cell_order: Array = []
var _points := PackedVector2Array()
var _indices := PackedInt32Array()
var _uvs := PackedVector2Array()
var _colors := PackedColorArray()


func cell_local(h: Vector2i) -> Vector2:
	return Hex.to_pixel(h) - center_offset


func cell_global(h: Vector2i) -> Vector2:
	return global_transform * cell_local(h)


## Converte uma posicao global para o espaco da grade deste objeto.
func global_to_grid(p: Vector2) -> Vector2:
	return global_transform.affine_inverse() * p + center_offset


func recompute_bounds() -> void:
	bound_radius = 0.0
	for h in cells:
		bound_radius = maxf(bound_radius, cell_local(h).length())
	bound_radius += Hex.SIZE
	refresh_groups()
	_geometry_dirty = true
	queue_redraw()


## Recalcula os canhoes a partir das celulas (chamado a cada mudanca de forma).
func refresh_groups() -> void:
	groups = CannonGroups.find(cells, _fixed_cells())
	_group_of.clear()
	for i in groups.size():
		for h in groups[i].cells:
			_group_of[h] = i
	_geometry_dirty = true


## Celulas de canhao que nao se fundem em triangulos.
func _fixed_cells() -> Dictionary:
	return {}


## Grupo que contem a celula ({} se ela nao for canhao).
func group_at(h: Vector2i) -> Dictionary:
	var i: int = _group_of.get(h, -1)
	return groups[i] if i >= 0 else {}


func group_by_key(key: Vector3i) -> Dictionary:
	for g in groups:
		if g.key == key:
			return g
	return {}


func group_local(g: Dictionary) -> Vector2:
	return g.center - center_offset


func group_global(g: Dictionary) -> Vector2:
	return global_transform * group_local(g)


## Distancia do centro do canhao ate a ponta do cano.
func muzzle_length(g: Dictionary) -> float:
	return Art.muzzle_length(g.type) * BARREL_SCALE * CannonGroups.art_scale(g.side)


## Arte da celula conforme o canhao a que ela pertence (ou `fallback`).
func cannon_art(h: Vector2i, fallback: int) -> int:
	var i: int = _group_of.get(h, -1)
	return Art.for_weapon(groups[i].type) if i >= 0 else fallback


## Quantidade de canhoes de cada tipo.
func weapon_counts() -> Dictionary:
	var counts := {Weapons.COMMON: 0, Weapons.SHOTGUN: 0, Weapons.LASER: 0, Weapons.BOMB: 0}
	for g in groups:
		counts[g.type] += 1
	return counts


## Desenha o cano de cada canhao, girado em torno do centro do grupo para
## `dirs[key]` (direcao global), com contorno escuro e o tom de `shades[key]`.
## Todos numa chamada so (atlas).
func draw_barrels(batch: TriBatch, dirs: Dictionary, shades: Dictionary) -> void:
	batch.clear()
	for g in groups:
		var w: int = g.type
		var k := BARREL_SCALE * CannonGroups.art_scale(g.side)
		var size := Art.cannon_size(w) * k
		var pivot := Art.cannon_pivot(w) * k
		# _draw usa o espaco local, entao desfaz a rotacao da direcao global.
		# Na arte o cano aponta para cima (-Y).
		var dir: Vector2 = dirs.get(g.key, Vector2.RIGHT.rotated(rotation))
		var angle := dir.rotated(-rotation).angle() + PI / 2.0
		var c := group_local(g)
		var corners := [
			c + (-pivot).rotated(angle),
			c + (Vector2(size.x, 0.0) - pivot).rotated(angle),
			c + (size - pivot).rotated(angle),
			c + (Vector2(0.0, size.y) - pivot).rotated(angle),
		]
		var uv := Art.cannon_uv(w)
		for offset in OUTLINE_OFFSETS:
			batch.add_quad(corners.map(func(p): return p + offset), uv, OUTLINE_COLOR)
		var shade: float = shades.get(g.key, 1.0)
		batch.add_quad(corners, uv, Color(shade, shade, shade))
	batch.draw(get_canvas_item(), Art.cannon_atlas())


## Chame quando cell_color() passar a devolver outra cor.
func refresh_colors() -> void:
	_colors_dirty = true
	queue_redraw()


## Existe alguma celula deste objeto a menos de `radius` do ponto global?
func has_cell_near(global_p: Vector2, radius: float) -> bool:
	return find_cell_near(global_p, radius) != NO_CELL


## Celula mais proxima do ponto global, se estiver a menos de `radius`
## (senao NO_CELL). So olha a celula sob o ponto e as 6 vizinhas.
func find_cell_near(global_p: Vector2, radius: float) -> Vector2i:
	var grid_p := global_to_grid(global_p)
	var center := Hex.from_pixel(grid_p)
	var best := NO_CELL
	var best_dist := radius
	for d in Hex.AROUND:
		var h: Vector2i = center + d
		if not cells.has(h):
			continue
		var dist := Hex.to_pixel(h).distance_to(grid_p)
		if dist < best_dist:
			best_dist = dist
			best = h
	return best


## Momento de inercia com massa 1 por celula (multiplique pela massa da celula).
func inertia() -> float:
	var sum := 0.0
	for h in cells:
		sum += cell_local(h).length_squared() + Hex.SIZE * Hex.SIZE * 0.5
	return sum


## Batida entre dois corpos de celulas: se alguma celula de um encosta numa
## do outro, aplica um impulso no ponto de contato e afasta os dois para nao
## ficarem sobrepostos. `mass_a`/`mass_b` sao as massas totais (INF = corpo
## que nao se mexe, ex.: a nave); `bounce` = elasticidade (0 = gruda,
## 1 = quique perfeito). Retorna true se estavam encostados.
static func bounce_apart(a: HexBody, b: HexBody, mass_a: float, mass_b: float, bounce: float, spin_limit: float) -> bool:
	var reach := a.bound_radius + b.bound_radius
	if a.global_position.distance_squared_to(b.global_position) > reach * reach:
		return false
	# Contato: media dos pontos e das normais entre celulas encostadas
	# (procura com as celulas do menor no grid do maior).
	var swap := a.cells.size() > b.cells.size()
	var small: HexBody = b if swap else a
	var big: HexBody = a if swap else b
	var contact := Vector2.ZERO
	var normal := Vector2.ZERO
	var depth := 0.0
	var touching := 0
	for h in small.cells:
		var p := small.cell_global(h)
		var touched := big.find_cell_near(p, CONTACT_DIST)
		if touched == NO_CELL:
			continue
		var q := big.cell_global(touched)
		contact += (p + q) * 0.5
		normal += p - q
		depth = maxf(depth, CONTACT_DIST - p.distance_to(q))
		touching += 1
	if touching == 0:
		return false
	contact /= touching
	normal = normal.normalized()
	if normal == Vector2.ZERO:
		normal = (small.global_position - big.global_position).normalized()
	# A normal aponta de `big` para `small`.
	var m_small := mass_b if swap else mass_a
	var m_big := mass_a if swap else mass_b
	var inv_small := 1.0 / m_small
	var inv_big := 1.0 / m_big
	var inv_i_small := inv_small * small.cells.size() / small.inertia()
	var inv_i_big := inv_big * big.cells.size() / big.inertia()
	var r_small := contact - small.global_position
	var r_big := contact - big.global_position
	var v_small := small.velocity + Vector2(-small.angular_velocity * r_small.y, small.angular_velocity * r_small.x)
	var v_big := big.velocity + Vector2(-big.angular_velocity * r_big.y, big.angular_velocity * r_big.x)
	var approach := (v_small - v_big).dot(normal)
	if approach < 0.0:
		var rn_small := r_small.cross(normal)
		var rn_big := r_big.cross(normal)
		var j := -(1.0 + bounce) * approach / (inv_small + inv_big
			+ rn_small * rn_small * inv_i_small + rn_big * rn_big * inv_i_big)
		small.velocity += normal * j * inv_small
		big.velocity -= normal * j * inv_big
		if inv_small > 0.0:
			small.angular_velocity = clampf(small.angular_velocity + rn_small * j * inv_i_small, -spin_limit, spin_limit)
		if inv_big > 0.0:
			big.angular_velocity = clampf(big.angular_velocity - rn_big * j * inv_i_big, -spin_limit, spin_limit)
	# Separa proporcionalmente a massa (o mais leve anda mais).
	var push := normal * depth * 0.8 / (inv_small + inv_big)
	small.position += push * inv_small
	big.position -= push * inv_big
	return true


## Move o pivo para o centro das celulas sem tira-las do lugar (usado quando
## um objeto ganha ou perde celulas, ou nasce de pedacos de outro).
func recenter() -> void:
	if cells.is_empty():
		return
	var sum := Vector2.ZERO
	for h in cells:
		sum += Hex.to_pixel(h)
	var new_offset := sum / cells.size()
	position += (new_offset - center_offset).rotated(rotation)
	center_offset = new_offset
	recompute_bounds()


## Tinta multiplicada sobre a arte da celula (branco = arte original).
func cell_color(_h: Vector2i) -> Color:
	return Color.WHITE


## Qual arte (Art.CORE, Art.HULL, ...) a celula usa.
func cell_art(_h: Vector2i) -> int:
	return Art.HULL


func _draw() -> void:
	if _geometry_dirty:
		_rebuild_geometry()
	if _colors_dirty:
		_rebuild_colors()
	if _points.is_empty():
		return
	RenderingServer.canvas_item_add_triangle_array(get_canvas_item(), _indices, _points, _colors,
		_uvs, PackedInt32Array(), PackedFloat32Array(), Art.cell_atlas().get_rid())


## Cada celula: um quadrado do tamanho da flor, centrado na celula.
func _rebuild_geometry() -> void:
	_geometry_dirty = false
	_colors_dirty = true
	_cell_order = cells.keys()
	var n := _cell_order.size()
	_points.resize(n * 4)
	_uvs.resize(n * 4)
	_indices.resize(n * 6)
	for i in n:
		var h: Vector2i = _cell_order[i]
		var kind := cell_art(h)
		var half := Art.cell_size(kind) * 0.5
		var uv := Art.cell_uv(kind)
		var c := cell_local(h)
		var base := i * 4
		_points[base] = c - half
		_points[base + 1] = c + Vector2(half.x, -half.y)
		_points[base + 2] = c + half
		_points[base + 3] = c + Vector2(-half.x, half.y)
		_uvs[base] = uv.position
		_uvs[base + 1] = Vector2(uv.end.x, uv.position.y)
		_uvs[base + 2] = uv.end
		_uvs[base + 3] = Vector2(uv.position.x, uv.end.y)
		var t := i * 6
		_indices[t] = base
		_indices[t + 1] = base + 1
		_indices[t + 2] = base + 2
		_indices[t + 3] = base
		_indices[t + 4] = base + 2
		_indices[t + 5] = base + 3


func _rebuild_colors() -> void:
	_colors_dirty = false
	var n := _cell_order.size()
	_colors.resize(n * 4)
	for i in n:
		var tint := cell_color(_cell_order[i])
		for k in 4:
			_colors[i * 4 + k] = tint
