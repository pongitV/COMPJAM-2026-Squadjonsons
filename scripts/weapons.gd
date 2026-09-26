class_name Weapons
extends RefCounted
## Tipos de canhao que uma celula do jogador pode ter, com cores e numeros
## de balanceamento. Celulas sem canhao (NONE) sao casco: nao atiram.

enum { NONE, COMMON, SHOTGUN, LASER, BOMB }

## Cores das artes (celulas e canhoes).
const COLORS := {
	NONE: Color("#cfcfcf"),
	COMMON: Color("#459cff"),
	SHOTGUN: Color("#ffb41f"),
	LASER: Color("#ff2a2a"),
	BOMB: Color("#f72df0"),
}
const NAMES := {
	NONE: "CASCO",
	COMMON: "COMUM",
	SHOTGUN: "SHOTGUN",
	LASER: "LASER",
	BOMB: "BOMBA",
}
## Tempo entre disparos de cada canhao (o do laser inclui os 3 s de raio).
const COOLDOWN := {
	COMMON: 0.2,
	SHOTGUN: 0.7,
	LASER: 6.0,
	BOMB: 2.2,
}

# Comum: um projetil por disparo.
const BULLET_SPEED := 650.0
const BULLET_LIFE := 1.1

# Shotgun: 6 projeteis em leque, alcance curto.
const PELLETS := 6
const PELLET_SPREAD := 0.75  # abertura total do leque, em radianos
const PELLET_SPEED := 560.0
const PELLET_LIFE := 0.38

# Laser: raio para fora da nave com dano continuo.
const LASER_DURATION := 3.0
const LASER_LENGTH := 520.0
const LASER_WIDTH := 6.0
const LASER_DPS := 12.0

# Bomba: missil lento que explode em area.
const MISSILE_SPEED := 200.0
const MISSILE_LIFE := 3.5
const BLAST_RADIUS := 110.0
const BLAST_DAMAGE := 18.0

## Distancia maxima (ate a borda do asteroide) em que cada canhao escolhe
## um alvo. O laser dispara quando um asteroide cruza a linha do raio.
const RANGE := {
	COMMON: BULLET_SPEED * BULLET_LIFE * 0.9,
	SHOTGUN: PELLET_SPEED * PELLET_LIFE,
	LASER: LASER_LENGTH,
	BOMB: 520.0,
}
## Velocidade do projetil, usada para mirar a frente de alvos em movimento.
const PROJECTILE_SPEED := {
	COMMON: BULLET_SPEED,
	SHOTGUN: PELLET_SPEED,
	BOMB: MISSILE_SPEED,
}

## A cada N asteroides destruidos o jogador ganha um canhao comum.
const ASTEROIDS_PER_COMMON := 5
## Peso de cada canhao especial no sorteio do minerio colorido.
const SPECIAL_WEIGHTS := {SHOTGUN: 0.45, BOMB: 0.35, LASER: 0.2}


static func color(weapon: int) -> Color:
	return COLORS[weapon]


## Chance de um asteroide destruido soltar um minerio de canhao especial.
static func special_drop_chance(asteroid_size: int) -> float:
	return clampf(0.06 + asteroid_size * 0.025, 0.0, 0.7)


static func roll_special() -> int:
	var r := randf()
	for w in SPECIAL_WEIGHTS:
		r -= SPECIAL_WEIGHTS[w]
		if r <= 0.0:
			return w
	return SHOTGUN
