class_name Asteroid
extends HexBody
## Aglomerado aleatório de n células. É destruído após ceil(n^(3/2)) disparos.

const DAMAGED_COLOR := Color(0.85, 0.35, 0.2)

var size := 1
var max_hp := 1
var hp := 1
var base_color := Color.GRAY


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
		queue_redraw()


## Recebe um disparo. Retorna true se foi destruído.
func hit() -> bool:
	hp -= 1
	flash = 1.0
	queue_redraw()
	return hp <= 0


func cell_color(_h: Vector2i) -> Color:
	var damage := 1.0 - float(hp) / max_hp
	return base_color.lerp(DAMAGED_COLOR, damage * 0.65).lerp(Color.WHITE, flash * 0.6)


func outline_color(_h: Vector2i) -> Color:
	return base_color.lightened(0.35)
