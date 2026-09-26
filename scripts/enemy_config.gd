class_name EnemyConfig
extends Resource
## Asteroides armados: com que canhoes nascem e quao forte atiram na nave (ao
## serem destruidos, os canhoes se partem junto com as outras celulas; ver
## AsteroidConfig, grupo Minerio). Quase tudo vai de um valor "inicio" a um
## valor "fim" conforme o progresso da barra de chegada (0 na largada, 1 na
## bandeira; depois fica no "fim"). Edite em config/enemies.tres.
##
## Os canhoes inimigos sao os mesmos da nave (triangulos de canhoes comuns,
## ver CannonGroups) e usam os numeros do CannonConfig, com os ajustes daqui.
## Cada tiro que acerta destroi uma celula da nave.

@export_group("Armamento")
## Chance de um asteroide nascer armado.
@export_range(0.0, 1.0, 0.05) var armed_chance_start := 0.25
@export_range(0.0, 1.0, 0.05) var armed_chance_end := 0.8
## Maximo de canhoes num asteroide.
@export_range(1, 10, 1) var max_cannons_start := 1
@export_range(1, 10, 1) var max_cannons_end := 3
## Tamanho: o asteroide precisa ter pelo menos (celulas do canhao + esta
## folga) celulas. Ex.: com 2, shotgun (3) so em asteroides de 5+, bomba (6)
## em 8+, laser (10) em 12+.
@export_range(0, 20, 1) var size_margin := 2
## Fracao maxima das celulas do asteroide que podem ser canhao (com 0.7, o
## laser de 10 celulas so aparece em asteroides de 15+).
@export_range(0.1, 1.0, 0.05) var max_cannon_fraction := 0.7
## Chance relativa de cada canhao (0 = nunca aparece nessa fase).
@export_range(0.0, 10.0, 0.05) var common_weight_start := 1.0
@export_range(0.0, 10.0, 0.05) var common_weight_end := 0.3
@export_range(0.0, 10.0, 0.05) var shotgun_weight_start := 0.15
@export_range(0.0, 10.0, 0.05) var shotgun_weight_end := 0.6
@export_range(0.0, 10.0, 0.05) var bomb_weight_start := 0.0
@export_range(0.0, 10.0, 0.05) var bomb_weight_end := 0.45
@export_range(0.0, 10.0, 0.05) var laser_weight_start := 0.0
@export_range(0.0, 10.0, 0.05) var laser_weight_end := 0.35

@export_group("Forca")
## Recarga dos canhoes inimigos = recarga do CannonConfig * este fator.
@export_range(0.5, 20.0, 0.1) var cooldown_mult_start := 5.0
@export_range(0.5, 20.0, 0.1) var cooldown_mult_end := 2.0
## Velocidade dos projeteis inimigos em relacao aos da nave (mais lentos =
## da para desviar).
@export_range(0.1, 2.0, 0.05) var projectile_speed_start := 0.4
@export_range(0.1, 2.0, 0.05) var projectile_speed_end := 0.65
## Erro maximo de mira.
@export_range(0.0, 45.0, 0.5, "radians_as_degrees") var aim_error_start := 0.2
@export_range(0.0, 45.0, 0.5, "radians_as_degrees") var aim_error_end := 0.05
## Alcance em relacao ao do canhao da nave.
@export_range(0.1, 3.0, 0.05) var range_mult := 0.8
## Espera antes do primeiro tiro de um canhao que acabou de aparecer.
@export_range(0.0, 10.0, 0.1, "suffix:s") var first_shot_delay := 1.5
## Projeteis por disparo da shotgun inimiga.
@export_range(1, 20, 1) var shotgun_pellets := 4
## Raio da explosao da bomba inimiga (destroi as celulas dentro dele).
@export_range(5.0, 300.0, 1.0, "suffix:px") var bomb_radius := 32.0
## Tempo que o laser inimigo precisa ficar sobre uma celula para destrui-la.
@export_range(0.05, 5.0, 0.05, "suffix:s") var laser_cell_time := 0.45


func armed_chance(progress: float) -> float:
	return lerpf(armed_chance_start, armed_chance_end, progress)


func max_cannons(progress: float) -> int:
	return roundi(lerpf(max_cannons_start, max_cannons_end, progress))


func cooldown(type: int, progress: float) -> float:
	return Weapons.config.base_cooldown(type) * lerpf(cooldown_mult_start, cooldown_mult_end, progress)


func projectile_speed(type: int, progress: float) -> float:
	return Weapons.config.projectile_speed(type) * lerpf(projectile_speed_start, projectile_speed_end, progress)


func aim_error(progress: float) -> float:
	return lerpf(aim_error_start, aim_error_end, progress)


func range_of(type: int) -> float:
	return Weapons.config.range_of(type) * range_mult


## Canhoes de um novo asteroide de `size` celulas (maiores primeiro; vazio =
## desarmado). Cada um so entra se couber (size_margin e max_cannon_fraction).
func roll_armament(size: int, progress: float) -> Array[int]:
	var out: Array[int] = []
	if randf() >= armed_chance(progress):
		return out
	var weights := {
		Weapons.COMMON: lerpf(common_weight_start, common_weight_end, progress),
		Weapons.SHOTGUN: lerpf(shotgun_weight_start, shotgun_weight_end, progress),
		Weapons.BOMB: lerpf(bomb_weight_start, bomb_weight_end, progress),
		Weapons.LASER: lerpf(laser_weight_start, laser_weight_end, progress),
	}
	var budget := int(size * max_cannon_fraction)
	for i in max_cannons(progress):
		var options := {}
		for type in weights:
			var n := CannonGroups.cell_count(type)
			if weights[type] > 0.0 and n <= budget and n + size_margin <= size:
				options[type] = weights[type]
		if options.is_empty():
			break
		var type := _pick(options)
		out.append(type)
		budget -= CannonGroups.cell_count(type)
	out.sort_custom(func(a: int, b: int) -> bool: return CannonGroups.cell_count(a) > CannonGroups.cell_count(b))
	return out


static func _pick(weights: Dictionary) -> int:
	var total := 0.0
	for w in weights:
		total += weights[w]
	var r := randf() * total
	for w in weights:
		r -= weights[w]
		if r <= 0.0:
			return w
	return weights.keys()[0]
