class_name CannonConfig
extends Resource
## Parametros dos canhoes, num lugar so. Edite no Inspector abrindo
## config/cannons.tres (ou duplique para criar presets e arraste o novo no
## campo "Cannon Config" do no Game). Dano e medido em "tiros do canhao
## comum": um asteroide de n celulas aguenta ~n^1.5 disso (ver AsteroidConfig).

## Os projeteis voam um pouco alem do alcance de mira (para acertar alvos em
## movimento); o missil tem folga extra antes de explodir sozinho.
const PROJECTILE_OVERSHOOT := 1.1
const MISSILE_EXTRA_LIFE := 1.0

@export_group("Geral")
## Multiplica o dano de todos os canhoes.
@export_range(0.1, 10.0, 0.05) var damage_multiplier := 1.0
## Multiplica a cadencia de todos os canhoes (2 = atiram 2x mais rapido).
@export_range(0.1, 10.0, 0.05) var fire_rate_multiplier := 1.0

@export_group("Comum")
## Segundos entre tiros.
@export_range(0.02, 10.0, 0.01, "suffix:s") var common_cooldown := 0.2
## Dano por tiro.
@export_range(0.0, 100.0, 0.1) var common_damage := 1.0
## Distancia maxima para escolher um alvo.
@export_range(50.0, 2000.0, 10.0, "suffix:px") var common_range := 640.0
@export_range(50.0, 3000.0, 10.0, "suffix:px/s") var common_speed := 650.0

@export_group("Shotgun")
@export_range(0.02, 10.0, 0.01, "suffix:s") var shotgun_cooldown := 0.7
## Projeteis por disparo (em leque).
@export_range(1, 30, 1) var shotgun_pellets := 6
## Dano de cada projetil.
@export_range(0.0, 100.0, 0.1) var shotgun_damage := 1.0
@export_range(50.0, 2000.0, 10.0, "suffix:px") var shotgun_range := 210.0
## Abertura total do leque.
@export_range(0.0, 180.0, 1.0, "radians_as_degrees") var shotgun_spread := 0.75
@export_range(50.0, 3000.0, 10.0, "suffix:px/s") var shotgun_speed := 560.0

@export_group("Laser")
## Segundos entre um raio e o proximo (contando a duracao do raio).
@export_range(0.1, 30.0, 0.1, "suffix:s") var laser_cooldown := 6.0
## Quanto tempo o raio fica ligado.
@export_range(0.1, 30.0, 0.1, "suffix:s") var laser_duration := 3.0
## Dano por segundo em cada asteroide que o raio cruza.
@export_range(0.0, 500.0, 0.5, "suffix:/s") var laser_dps := 12.0
## Comprimento do raio.
@export_range(50.0, 2000.0, 10.0, "suffix:px") var laser_range := 520.0

@export_group("Bomba")
@export_range(0.1, 30.0, 0.1, "suffix:s") var bomb_cooldown := 2.2
## Dano da explosao em cada asteroide dentro do raio.
@export_range(0.0, 500.0, 0.5) var bomb_damage := 18.0
@export_range(10.0, 1000.0, 5.0, "suffix:px") var bomb_radius := 110.0
@export_range(50.0, 2000.0, 10.0, "suffix:px") var bomb_range := 520.0
@export_range(20.0, 2000.0, 10.0, "suffix:px/s") var bomb_speed := 200.0

@export_group("Ganho de canhoes")
## A cada tantos asteroides destruidos o jogador ganha um canhao comum.
@export_range(1, 100, 1) var asteroids_per_common := 5
## Chance relativa de cada canhao especial no minerio colorido (a chance de
## vir um minerio colorido fica em AsteroidConfig).
@export_range(0.0, 10.0, 0.05) var shotgun_weight := 0.45
@export_range(0.0, 10.0, 0.05) var bomb_weight := 0.35
@export_range(0.0, 10.0, 0.05) var laser_weight := 0.2


## Segundos ate o canhao poder atirar de novo.
func cooldown(weapon: int) -> float:
	var base: float = {
		Weapons.COMMON: common_cooldown,
		Weapons.SHOTGUN: shotgun_cooldown,
		Weapons.LASER: laser_cooldown,
		Weapons.BOMB: bomb_cooldown,
	}[weapon]
	return base / fire_rate_multiplier


## Distancia maxima (ate a borda do asteroide) para escolher um alvo.
## No laser e o comprimento do raio.
func range_of(weapon: int) -> float:
	return {
		Weapons.COMMON: common_range,
		Weapons.SHOTGUN: shotgun_range,
		Weapons.LASER: laser_range,
		Weapons.BOMB: bomb_range,
	}[weapon]


## Velocidade do projetil (usada para mirar a frente). 0 = sem projetil (laser).
func projectile_speed(weapon: int) -> float:
	return {
		Weapons.COMMON: common_speed,
		Weapons.SHOTGUN: shotgun_speed,
		Weapons.BOMB: bomb_speed,
	}.get(weapon, 0.0)


## Segundos de voo de um projetil ate sumir.
func projectile_life(weapon: int) -> float:
	var flight := range_of(weapon) / projectile_speed(weapon)
	if weapon == Weapons.BOMB:
		return flight + MISSILE_EXTRA_LIFE
	return flight * PROJECTILE_OVERSHOOT


## Dano por projetil (comum, shotgun), por segundo (laser) ou da explosao (bomba).
func damage(weapon: int) -> float:
	var base: float = {
		Weapons.COMMON: common_damage,
		Weapons.SHOTGUN: shotgun_damage,
		Weapons.LASER: laser_dps,
		Weapons.BOMB: bomb_damage,
	}[weapon]
	return base * damage_multiplier


## Qual canhao especial vem no minerio colorido.
func roll_special() -> int:
	var weights := {Weapons.SHOTGUN: shotgun_weight, Weapons.BOMB: bomb_weight, Weapons.LASER: laser_weight}
	var total := 0.0
	for w in weights:
		total += weights[w]
	var r := randf() * total
	for w in weights:
		r -= weights[w]
		if r <= 0.0 and weights[w] > 0.0:
			return w
	return Weapons.SHOTGUN
