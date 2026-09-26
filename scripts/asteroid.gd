class_name Asteroid
extends HexBody
## Aglomerado aleatório de n células. É destruído após ceil(n^(3/2)) disparos.

const DAMAGED_COLOR := Color(0.85, 0.35, 0.2)

var size := 1
var max_hp := 1
var hp := 1
var base_color := Color.GRAY
var _damage_accum := 0.0


func setup(n: int) -> void:
	cells.clear()
	cells[Vector2i.ZERO] = true
	# Cresce a partir de uma célula, colando vizinhos aleatórios.
	while cells.size() < n:
		var keys := cells.keys()
		var h: Vector2i = keys[randi() % keys.size()]
		cells[h + Hex.DIRS[randi() % 6]] = true

	size = cells.size()
	max_hp = ceili(pow(size, 1.5))
	hp = max_hp

	var sum := Vector2.ZERO
	for h in cells:
		sum += Hex.to_pixel(h)
	center_offset = sum / size

	base_color = Color.from_hsv(randf_range(0.05, 0.12), randf_range(0.15, 0.35), randf_range(0.42, 0.58))
	recompute_bounds()


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


## A cor de dano/flash é igual no asteroide inteiro, então vira um
## self_modulate (grátis) em vez de recalcular a cor de cada vértice.
func _update_tint() -> void:
	var damage := 1.0 - float(hp) / max_hp
	var target := base_color.lerp(DAMAGED_COLOR, damage * 0.65).lerp(Color.WHITE, flash * 0.6)
	self_modulate = Color(target.r / base_color.r, target.g / base_color.g, target.b / base_color.b)


func cell_color(_h: Vector2i) -> Color:
	return base_color


func outline_color(_h: Vector2i) -> Color:
	return base_color.lightened(0.35)
