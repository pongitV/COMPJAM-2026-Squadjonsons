class_name Asteroid
extends HexBody
## Aglomerado aleatorio de n celulas (n >= config.min_size), com HP dado por
## config.max_hp_for(n). Ao encostar na nave, cada celula dele destroi
## config.cell_charges celulas da nave (as que tocar) e depois some; se o
## asteroide se partir, os pedacos viram asteroides separados. Asteroides
## batem entre si. Os numeros de balanceamento ficam em AsteroidConfig.

const DAMAGED_COLOR := Color(0.85, 0.35, 0.2)
## Cor media da arte do asteroide (base do tingimento de dano e dos efeitos).
const ART_COLOR := Color("#8a3b2c")

## Parametros em uso (o jogo troca pelo preset escolhido no no Game).
static var config: AsteroidConfig = preload("res://config/asteroids.tres")

var size := 1
var max_hp := 1
var hp := 1
var base_color := Color.GRAY
## Vector2i -> cargas restantes daquela celula contra a nave.
var charges := {}
var _damage_accum := 0.0


func setup(n: int) -> void:
	cells.clear()
	cells[Vector2i.ZERO] = true
	# Cresce a partir de uma celula, colando vizinhos aleatorios.
	while cells.size() < n:
		var keys := cells.keys()
		var h: Vector2i = keys[randi() % keys.size()]
		cells[h + Hex.DIRS[randi() % 6]] = true
	for h in cells:
		charges[h] = config.cell_charges

	size = cells.size()
	max_hp = config.max_hp_for(size)
	hp = max_hp
	base_color = ART_COLOR
	recenter()


func step(delta: float) -> void:
	position += velocity * delta
	rotation += angular_velocity * delta
	if flash > 0.0:
		flash = maxf(flash - delta * 8.0, 0.0)
		_update_tint()


## Recebe um disparo. Retorna true se foi destruido.
func hit() -> bool:
	apply_damage(1.0)
	return hp <= 0


## Dano em unidades de "disparo". Aceita fracoes (dano continuo do laser).
func apply_damage(amount: float) -> void:
	_damage_accum += amount
	var whole := int(_damage_accum)
	if whole <= 0:
		return
	_damage_accum -= whole
	hp -= whole
	flash = 1.0
	_update_tint()


## Gasta uma carga da celula ao destruir uma celula da nave.
## Retorna true quando a celula esgotou e deve sumir.
func spend_charge(h: Vector2i) -> bool:
	charges[h] -= 1
	return charges[h] <= 0


## Remove celulas esgotadas. Partes que ficarem desconectadas viram novos
## asteroides (retornados, para o jogo adicionar a cena). O HP acompanha o
## tamanho, mantendo a proporcao de dano ja sofrido.
func remove_cells(keys: Array) -> Array[Asteroid]:
	for h in keys:
		cells.erase(h)
		charges.erase(h)
	var pieces: Array[Asteroid] = []
	if cells.is_empty():
		return pieces
	var groups := Hex.components(cells.keys())
	groups.sort_custom(func(a, b): return a.size() > b.size())
	var hp_ratio := float(hp) / max_hp
	for i in range(1, groups.size()):
		var piece := Asteroid.new()
		piece._split_from(self, groups[i], hp_ratio)
		pieces.append(piece)
		for h in groups[i]:
			cells.erase(h)
			charges.erase(h)
	_resize(hp_ratio)
	recenter()
	return pieces


func _split_from(source: Asteroid, keys: Array, hp_ratio: float) -> void:
	for h in keys:
		cells[h] = true
		charges[h] = source.charges[h]
	base_color = source.base_color
	rotation = source.rotation
	position = source.position
	center_offset = source.center_offset
	angular_velocity = source.angular_velocity
	velocity = source.velocity + Vector2.from_angle(randf() * TAU) * config.split_speed
	_resize(hp_ratio)
	recenter()


func _resize(hp_ratio: float) -> void:
	size = cells.size()
	max_hp = config.max_hp_for(size)
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
	# A normal aponta de `big` para `small`.
	var inv_small := 1.0 / small.cells.size()
	var inv_big := 1.0 / big.cells.size()
	var r_small := contact - small.global_position
	var r_big := contact - big.global_position
	var inv_i_small := 1.0 / small._inertia()
	var inv_i_big := 1.0 / big._inertia()
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


func cell_art(_h: Vector2i) -> int:
	return Art.ASTEROID
