class_name Asteroid
extends HexBody
## Aglomerado aleatorio de n celulas (n >= config.min_size), com HP dado por
## config.max_hp_for(n). Anda em linha reta ate bater em algo. Ao bater na
## nave, entra destruindo ate config.penetration_for(n) celulas dela (cada
## uma quebra a celula do asteroide que bateu) e depois recua; se ele se
## partir, os pedacos viram asteroides separados. Asteroides batem entre si.
## Os numeros de balanceamento ficam em AsteroidConfig.
## Alguns nascem armados (EnemyConfig): celulas de canhao comum, que em
## triangulo formam shotgun/bomba/laser, e atiram na nave (EnemyShots).

const DAMAGED_COLOR := Color(0.85, 0.35, 0.2)
## Cor media da arte do asteroide (base do tingimento de dano e dos efeitos).
const ART_COLOR := Color("#8a3b2c")
## O cano brilha em vermelho nestes ultimos segundos antes de atirar.
const TELEGRAPH := 0.4
const TELEGRAPH_COLOR := Color(1.0, 0.25, 0.2)

## Parametros em uso (o jogo troca pelo preset escolhido no no Game).
static var config: AsteroidConfig = preload("res://config/asteroids.tres")

var size := 1
var max_hp := 1
var hp := 1
## Multiplicador de HP da dificuldade na hora em que nasceu (pedacos herdam).
var hp_scale := 1.0
var base_color := Color.GRAY
## Celulas da nave que ainda pode destruir na batida atual. Zera quando ele
## recua e so recarrega depois que ele se afasta da nave (ver recharge_impact).
var impact_budget := 0
## Para onde os canhoes miram (a nave), atualizado pelo jogo.
var aim_at := Vector2.ZERO
## Chave do grupo -> segundos ate aquele canhao atirar (controlado pelo jogo).
var cooldowns := {}
## Tutorial: os tiros dele sempre erram e encostar nele nao machuca a nave.
var harmless := false
## Nao e empurrado nas batidas (o chefe): quem bate nele e que quica.
var immovable := false
## Tutorial: pedacos fixos (listas de celulas) em que ele se parte ao ser
## destruido, sem perder nada; celulas fora deles viram poeira.
var drop_pieces: Array = []
var _damage_accum := 0.0
var _barrels := TriBatch.new()


## `armament`: tipos de canhao (maiores primeiro, ver EnemyConfig.roll_wave_armament).
func setup(n: int, hp_multiplier: float = 1.0, armament: Array[int] = []) -> void:
	hp_scale = hp_multiplier
	cells.clear()
	# O maior canhao e a semente do formato, entao sempre cabe.
	if armament.is_empty():
		cells[Vector2i.ZERO] = Weapons.NONE
	else:
		var side: int = CannonGroups.SIDES.get(armament[0], 1)
		for c in CannonGroups.triangle(Vector2i.ZERO, side, randf() < 0.5):
			cells[c] = Weapons.COMMON
	# Cresce colando vizinhos aleatorios.
	while cells.size() < n:
		var keys := cells.keys()
		var h: Vector2i = keys[randi() % keys.size()] + Hex.DIRS[randi() % 6]
		if not cells.has(h):
			cells[h] = Weapons.NONE
	for i in range(1, armament.size()):
		_place_cannon(armament[i])
	_finish_setup()


## Asteroide de formato fixo (tutorial): `shape` = {celula: Weapons.NONE ou
## Weapons.COMMON}.
func setup_shape(shape: Dictionary, hp_multiplier: float = 1.0) -> void:
	hp_scale = hp_multiplier
	cells = shape.duplicate()
	_finish_setup()


func _finish_setup() -> void:
	size = cells.size()
	max_hp = config.max_hp_for(size, hp_scale)
	hp = max_hp
	base_color = ART_COLOR
	recenter()
	recharge_impact()


## Poe um canhao onde o triangulo dele cabe em celulas de rocha, de
## preferencia longe dos outros canhoes (para nao se fundirem sem querer).
func _place_cannon(type: int) -> void:
	var side: int = CannonGroups.SIDES.get(type, 1)
	var apart := []
	var touching := []
	for h in cells:
		for flip in [false, true]:
			var tri := CannonGroups.triangle(h, side, flip)
			if not tri.all(func(c: Vector2i) -> bool: return cells.get(c, Weapons.COMMON) == Weapons.NONE):
				continue
			var near_cannon := false
			for c in tri:
				for d in Hex.DIRS:
					if cells.get(c + d, Weapons.NONE) == Weapons.COMMON:
						near_cannon = true
			(touching if near_cannon else apart).append(tri)
	var options := apart if not apart.is_empty() else touching
	if options.is_empty():
		return
	for c in options.pick_random():
		cells[c] = Weapons.COMMON


func step(delta: float) -> void:
	position += velocity * delta
	rotation += angular_velocity * delta
	if flash > 0.0:
		flash = maxf(flash - delta * 8.0, 0.0)
		_update_tint()
	if not groups.is_empty():
		queue_redraw()  # os canos seguem a nave


## Direcao global do cano (para a nave).
func barrel_dir(g: Dictionary) -> Vector2:
	var d := aim_at - group_global(g)
	return d.normalized() if d.length_squared() > 0.01 else Vector2.RIGHT


func muzzle(g: Dictionary) -> Vector2:
	return group_global(g) + barrel_dir(g) * muzzle_length(g)


## Dano em unidades de "disparo do canhao comum". Aceita fracoes (dano
## continuo do laser).
func apply_damage(amount: float) -> void:
	_damage_accum += amount
	var whole := int(_damage_accum)
	if whole <= 0:
		return
	_damage_accum -= whole
	hp -= whole
	flash = 1.0
	_update_tint()


## Onde os canhoes da nave miram (visto de `from`). O chefe devolve a parte
## vulneravel mais perto.
func aim_point(_from: Vector2) -> Vector2:
	return global_position


## Distancia de `from` ate o que os canhoes da nave acertariam (para o alcance).
func target_distance(from: Vector2) -> float:
	return from.distance_to(global_position) - bound_radius


## Tiro que acertou no ponto `p` (global). Asteroides comuns so tem a vida
## do corpo inteiro; o chefe (Boss) danifica a celula atingida.
func damage_at(_p: Vector2, amount: float) -> void:
	apply_damage(amount)


## Raio de p0 a p1 passando por ele.
func damage_beam(_p0: Vector2, _p1: Vector2, amount: float) -> void:
	apply_damage(amount)


## Explosao em `center` (so chamado se ele estiver dentro do raio).
func damage_area(_center: Vector2, _radius: float, amount: float) -> void:
	apply_damage(amount)


## Longe da nave: a proxima batida volta a entrar com toda a forca.
## Asteroide inofensivo (tutorial) so quica.
func recharge_impact() -> void:
	impact_budget = 0 if harmless else config.penetration_for(cells.size())


## Remove celulas esgotadas. Partes que ficarem desconectadas viram novos
## asteroides (retornados, para o jogo adicionar a cena). O HP acompanha o
## tamanho, mantendo a proporcao de dano ja sofrido.
func remove_cells(keys: Array) -> Array[Asteroid]:
	for h in keys:
		cells.erase(h)
	var pieces: Array[Asteroid] = []
	if cells.is_empty():
		return pieces
	var parts := Hex.components(cells.keys())
	parts.sort_custom(func(a, b): return a.size() > b.size())
	var hp_ratio := float(hp) / max_hp
	for i in range(1, parts.size()):
		var piece := Asteroid.new()
		piece._split_from(self, parts[i], hp_ratio)
		pieces.append(piece)
		for h in parts[i]:
			cells.erase(h)
	_resize(hp_ratio)
	recenter()
	return pieces


func _split_from(source: Asteroid, keys: Array, hp_ratio: float) -> void:
	for h in keys:
		cells[h] = source.cells[h]
	# Pedaco que se soltou na batida so machuca depois de se afastar.
	impact_budget = 0
	base_color = source.base_color
	hp_scale = source.hp_scale
	cooldowns = source.cooldowns.duplicate()
	harmless = source.harmless
	aim_at = source.aim_at
	rotation = source.rotation
	position = source.position
	center_offset = source.center_offset
	angular_velocity = source.angular_velocity
	velocity = source.velocity + Vector2.from_angle(randf() * TAU) * config.split_speed
	_resize(hp_ratio)
	recenter()


func _resize(hp_ratio: float) -> void:
	size = cells.size()
	max_hp = config.max_hp_for(size, hp_scale)
	hp = maxi(1, ceili(hp_ratio * max_hp))
	_update_tint()


## Batida com outro asteroide: se alguma celula de um encosta numa do outro,
## aplica um impulso no ponto de contato (massa = numero de celulas) e afasta
## os dois para nao ficarem sobrepostos.
func collide_with(other: Asteroid) -> void:
	var reach := bound_radius + other.bound_radius
	if global_position.distance_squared_to(other.global_position) > reach * reach:
		return
	# Contato: media dos pontos e das normais entre celulas encostadas.
	var small: Asteroid = self if cells.size() <= other.cells.size() else other
	var big: Asteroid = other if small == self else self
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
		return
	contact /= touching
	normal = normal.normalized()
	if normal == Vector2.ZERO:
		normal = (small.global_position - big.global_position).normalized()
	# A normal aponta de `big` para `small`. Corpo imovel = massa infinita.
	var inv_small := 0.0 if small.immovable else 1.0 / small.cells.size()
	var inv_big := 0.0 if big.immovable else 1.0 / big.cells.size()
	if inv_small + inv_big <= 0.0:
		return
	var r_small := contact - small.global_position
	var r_big := contact - big.global_position
	var inv_i_small := 0.0 if small.immovable else 1.0 / small._inertia()
	var inv_i_big := 0.0 if big.immovable else 1.0 / big._inertia()
	var v_small := small.velocity + Vector2(-small.angular_velocity * r_small.y, small.angular_velocity * r_small.x)
	var v_big := big.velocity + Vector2(-big.angular_velocity * r_big.y, big.angular_velocity * r_big.x)
	var approach := (v_small - v_big).dot(normal)
	if approach < 0.0:
		var rn_small := r_small.cross(normal)
		var rn_big := r_big.cross(normal)
		var j := -(1.0 + config.bounce) * approach / (inv_small + inv_big
			+ rn_small * rn_small * inv_i_small + rn_big * rn_big * inv_i_big)
		small.velocity += normal * j * inv_small
		big.velocity -= normal * j * inv_big
		var spin := config.spin_limit
		small.angular_velocity = clampf(small.angular_velocity + rn_small * j * inv_i_small, -spin, spin)
		big.angular_velocity = clampf(big.angular_velocity - rn_big * j * inv_i_big, -spin, spin)
	# Separa proporcionalmente a massa (o mais leve anda mais).
	var push := normal * depth * 0.8 / (inv_small + inv_big)
	small.position += push * inv_small
	big.position -= push * inv_big


## Recuo depois de gastar a penetracao numa batida na nave: impulso no ponto
## de contato (massa = celulas; cada celula da nave pesa
## config.ship_mass_per_cell), com elasticidade config.ship_bounce e um recuo
## minimo que diminui com o tamanho. Tambem separa os dois.
## `normal` aponta da nave para o asteroide.
func bounce_off(ship: Player, normal: Vector2, contact: Vector2, depth: float) -> void:
	var inv_a := 0.0 if immovable else 1.0 / cells.size()
	var inv_s := 1.0 / maxf(ship.cells.size() * config.ship_mass_per_cell, 0.1)
	var r := contact - global_position
	var inv_i := 0.0 if immovable else 1.0 / _inertia()
	var rel := velocity + Vector2(-angular_velocity * r.y, angular_velocity * r.x) - ship.velocity
	var approach := rel.dot(normal)
	if approach < 0.0:
		var rn := r.cross(normal)
		var j := -(1.0 + config.ship_bounce) * approach / (inv_a + inv_s + rn * rn * inv_i)
		velocity += normal * j * inv_a
		ship.velocity -= normal * j * inv_s
		angular_velocity = clampf(angular_velocity + rn * j * inv_i, -config.spin_limit, config.spin_limit)
	# Recuo minimo em relacao a nave e ao espaco (a nave freia sozinha logo
	# depois, entao so o relativo deixaria o asteroide grande voltar a encostar).
	var min_speed := config.recoil_speed / sqrt(cells.size())
	var need := maxf(min_speed - velocity.dot(normal), min_speed - (velocity - ship.velocity).dot(normal))
	if need > 0.0 and not immovable:
		velocity += normal * need
	# Separa proporcionalmente a massa (o mais leve anda mais).
	var push := normal * depth / (inv_a + inv_s)
	position += push * inv_a
	ship.position -= push * inv_s


## Momento de inercia (celulas de massa 1 distribuidas em volta do centro).
func _inertia() -> float:
	var sum := 0.0
	for h in cells:
		sum += cell_local(h).length_squared() + Hex.SIZE * Hex.SIZE * 0.5
	return sum


## A cor de dano/flash e igual no asteroide inteiro, entao vira um
## self_modulate (gratis) em vez de recalcular a cor de cada vertice.
func _update_tint() -> void:
	var damage := 1.0 - float(hp) / max_hp
	var target := base_color.lerp(DAMAGED_COLOR, damage * 0.65).lerp(Color.WHITE, flash * 0.6)
	self_modulate = Color(target.r / base_color.r, target.g / base_color.g, target.b / base_color.b)


func cell_art(h: Vector2i) -> int:
	return cannon_art(h, Art.ASTEROID)


func _draw() -> void:
	super._draw()
	if groups.is_empty():
		return
	var dirs := {}
	for g in groups:
		dirs[g.key] = barrel_dir(g)
	draw_barrels(_barrels, dirs, {})
	# Aviso antes do tiro: brilho vermelho crescendo na ponta do cano.
	for g in groups:
		var left: float = cooldowns.get(g.key, INF)
		if left < TELEGRAPH:
			var k := 1.0 - left / TELEGRAPH
			draw_circle(to_local(muzzle(g)), 2.0 + 4.0 * k * CannonGroups.art_scale(g.side),
				Color(TELEGRAPH_COLOR, 0.35 + 0.55 * k))
