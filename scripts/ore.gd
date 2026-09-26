class_name Ore
extends HexBody
## Célula solta de minério. Ao tocar o jogador vira uma célula do jogador.

const COLOR := Color(0.35, 1.0, 0.55)
const LIFETIME := 25.0
const MAGNET_RANGE := 70.0
const MAGNET_ACCEL := 500.0

var life := LIFETIME


func _init() -> void:
	cells[Vector2i.ZERO] = true
	recompute_bounds()


func step(delta: float, player: Player) -> void:
	if player != null and player.alive:
		var to_player := player.global_position - global_position
		var dist := to_player.length()
		if dist > 0.0 and dist < player.bound_radius + MAGNET_RANGE:
			velocity += to_player / dist * MAGNET_ACCEL * delta
	velocity *= pow(0.5, delta)
	position += velocity * delta
	rotation += angular_velocity * delta
	life -= delta
	# Pisca nos últimos segundos antes de sumir.
	visible = life > 5.0 or fmod(life, 0.3) > 0.12


func cell_color(_h: Vector2i) -> Color:
	return COLOR


func outline_color(_h: Vector2i) -> Color:
	return Color(0.85, 1.0, 0.9, 0.9)
