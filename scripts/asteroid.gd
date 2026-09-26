class_name Asteroid
extends HexBody
## Aglomerado aleatório de n células. É destruído após ceil(n^(3/2)) disparos.
## Ao encostar na nave, cada célula dele destrói CELL_CHARGES células da nave
## (as que tocar) e depois some; se o asteroide se partir, os pedaços viram
## asteroides separados.

const DAMAGED_COLOR := Color(0.85, 0.35, 0.2)
## Cor média da arte do asteroide (base do tingimento de dano e dos efeitos).
const ART_COLOR := Color("#756348")
## Quantas células da nave cada célula do asteroide destrói antes de sumir.
const CELL_CHARGES := 2

var size := 1
var max_hp := 1
var hp := 1
var base_color := Color.GRAY
## Vector2i -> cargas restantes daquela célula contra a nave.
var charges := {}
var _damage_accum := 0.0


func setup(n: int) -> void:
	cells.clear()
	cells[Vector2i.ZERO] = true
	# Cresce a partir de uma célula, colando vizinhos aleatórios.
	while cells.size() < n:
		var keys := cells.keys()
		var h: Vector2i = keys[randi() % keys.size()]
		cells[h + Hex.DIRS[randi() % 6]] = true
	for h in cells:
		charges[h] = CELL_CHARGES

	size = cells.size()
	max_hp = ceili(pow(size, 1.5))
	hp = max_hp
	base_color = ART_COLOR
	recenter()


func step(delta: float) -> void:
	position += velocity * delta
	rotation += angular_velocity * delta
	if flash > 0.0:
		flash = maxf(flash - delta * 8.0, 0.0)
		_update_tint()


## Recebe um disparo. Retorna true se foi destruído.
func hit() -> bool:
	apply_damage(1.0)
	return hp <= 0


## Dano em unidades de "disparo". Aceita frações (dano contínuo do laser).
func apply_damage(amount: float) -> void:
	_damage_accum += amount
	var whole := int(_damage_accum)
	if whole <= 0:
		return
	_damage_accum -= whole
	hp -= whole
	flash = 1.0
	_update_tint()


## Gasta uma carga da célula ao destruir uma célula da nave.
## Retorna true quando a célula esgotou e deve sumir.
func spend_charge(h: Vector2i) -> bool:
	charges[h] -= 1
	return charges[h] <= 0


## Remove células esgotadas. Partes que ficarem desconectadas viram novos
## asteroides (retornados, para o jogo adicionar à cena). O HP acompanha o
## tamanho, mantendo a proporção de dano já sofrido.
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
	velocity = source.velocity + Vector2.from_angle(randf() * TAU) * 15.0
	_resize(hp_ratio)
	recenter()


func _resize(hp_ratio: float) -> void:
	size = cells.size()
	max_hp = ceili(pow(size, 1.5))
	hp = maxi(1, ceili(hp_ratio * max_hp))
	_update_tint()


## A cor de dano/flash é igual no asteroide inteiro, então vira um
## self_modulate (grátis) em vez de recalcular a cor de cada vértice.
func _update_tint() -> void:
	var damage := 1.0 - float(hp) / max_hp
	var target := base_color.lerp(DAMAGED_COLOR, damage * 0.65).lerp(Color.WHITE, flash * 0.6)
	self_modulate = Color(target.r / base_color.r, target.g / base_color.g, target.b / base_color.b)


func cell_art(_h: Vector2i) -> int:
	return Art.ASTEROID
