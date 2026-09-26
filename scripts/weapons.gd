class_name Weapons
extends RefCounted
## Tipos de canhão que uma célula do jogador pode ter, com cores e números
## de balanceamento. Células sem canhão (NONE) são casco: não atiram.

enum { NONE, COMMON, SHOTGUN, LASER, BOMB }

const COLORS := {
	NONE: Color(0.36, 0.5, 0.64),
	COMMON: Color(0.3, 0.8, 1.0),
	SHOTGUN: Color(1.0, 0.58, 0.2),
	LASER: Color(1.0, 0.25, 0.45),
	BOMB: Color(0.72, 0.42, 1.0),
}
const NAMES := {
	NONE: "CASCO",
	COMMON: "COMUM",
	SHOTGUN: "SHOTGUN",
	LASER: "LASER",
	BOMB: "BOMBA",
}
## Tempo entre disparos de cada canhão (o do laser inclui os 3 s de raio).
const COOLDOWN := {
	COMMON: 0.2,
	SHOTGUN: 0.7,
	LASER: 6.0,
	BOMB: 2.2,
}

# Comum: um projétil por disparo.
const BULLET_SPEED := 650.0
const BULLET_LIFE := 1.1

# Shotgun: 6 projéteis em leque, alcance curto.
const PELLETS := 6
const PELLET_SPREAD := 0.75  # abertura total do leque, em radianos
const PELLET_SPEED := 560.0
const PELLET_LIFE := 0.38

# Laser: raio para fora da nave com dano contínuo.
const LASER_DURATION := 3.0
const LASER_LENGTH := 520.0
const LASER_WIDTH := 6.0
const LASER_DPS := 12.0

# Bomba: míssil lento que explode em área.
const MISSILE_SPEED := 200.0
const MISSILE_LIFE := 3.5
const BLAST_RADIUS := 110.0
const BLAST_DAMAGE := 18.0

## A cada N asteroides destruídos o jogador ganha um canhão comum.
const ASTEROIDS_PER_COMMON := 5
## Peso de cada canhão especial no sorteio do minério colorido.
const SPECIAL_WEIGHTS := {SHOTGUN: 0.45, BOMB: 0.35, LASER: 0.2}


static func color(weapon: int) -> Color:
	return COLORS[weapon]


## Chance de um asteroide destruído soltar um minério de canhão especial.
static func special_drop_chance(asteroid_size: int) -> float:
	return clampf(0.06 + asteroid_size * 0.025, 0.0, 0.7)


static func roll_special() -> int:
	var r := randf()
	for w in SPECIAL_WEIGHTS:
		r -= SPECIAL_WEIGHTS[w]
		if r <= 0.0:
			return w
	return SHOTGUN
