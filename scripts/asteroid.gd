class_name Asteroid
extends HexBody
## Aglomerado aleatorio de n celulas (n >= config.min_size), com HP dado por
## config.max_hp_for(n). Ao bater na nave, quica e destroi as celulas dela que
## tocou, tomando config.contact_damage de dano por celula destruida (sem
## perder celulas). Asteroides batem entre si e com os minerios. Os numeros
## de balanceamento ficam em AsteroidConfig.
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
## Segundos ate poder causar dano de contato na nave de novo.
var contact_cooldown := 0.0
## Para onde os canhoes miram (a nave), atualizado pelo jogo.
var aim_at := Vector2.ZERO
## Chave do grupo -> segundos ate aquele canhao atirar (controlado pelo jogo).
var cooldowns := {}
var _damage_accum := 0.0
var _barrels := TriBatch.new()


## `armament`: tipos de canhao (maiores primeiro, ver EnemyConfig.roll_armament).
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

	size = cells.size()
	max_hp = config.max_hp_for(size, hp_scale)
	hp = max_hp
	base_color = ART_COLOR
	recenter()


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
	contact_cooldown = maxf(contact_cooldown - delta, 0.0)
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


## Empurrao aplicado no ponto global `at` (massa = numero de celulas): muda a
## velocidade e, se o ponto estiver fora do centro, o giro.
func apply_impulse(at: Vector2, impulse: Vector2) -> void:
	velocity += impulse / cells.size()
	var spin := config.spin_limit
	angular_velocity = clampf(angular_velocity + (at - global_position).cross(impulse) / inertia(), -spin, spin)


## Batida com outro asteroide (massa = numero de celulas).
func collide_with(other: Asteroid) -> void:
	HexBody.bounce_apart(self, other, cells.size(), other.cells.size(), config.bounce, config.spin_limit)


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
