class_name EnemyConfig
extends Resource
## Inimigos (asteroides armados): as ondas de cada minuto da corrida (quantos
## ao mesmo tempo, de quanto em quanto tempo e com que canhoes), quao forte
## atiram na nave e o chefe que aparece na bandeira de chegada. A forca vai de
## um valor "inicio" a um valor "fim" conforme o progresso da barra de chegada
## (0 na largada, 1 na bandeira). Edite em config/enemies.tres.
##
## Os canhoes inimigos sao os mesmos da nave (triangulos de canhoes comuns,
## ver CannonGroups) e usam os numeros do CannonConfig, com os ajustes daqui.
## Cada tiro que acerta destroi uma celula da nave.

@export_group("Ondas")
## Os inimigos tem cronograma proprio (os asteroides comuns nao nascem mais
## armados). Nas listas por minuto, a posicao e o minuto da corrida (0 = o
## primeiro); depois do ultimo item vale o ultimo.
## Maximo de inimigos vivos ao mesmo tempo.
@export var max_alive_by_minute := PackedInt32Array([2, 2, 3, 3, 4])
## Segundos entre um inimigo e o proximo (spawn baixo e controlado).
@export var interval_by_minute := PackedFloat32Array([14.0, 8.0, 7.0, 6.0, 5.0])
## Primeiro inimigo depois de tantos segundos de corrida.
@export_range(0.0, 60.0, 0.5, "suffix:s") var first_enemy_delay := 8.0
## Tipos de inimigo: comum (1 a 3 canhoes comuns) desde o inicio; shotgun
## (1 a 2 shotguns), bomba (1 bomba) e misto (canhoes misturados, podendo
## ter 1 laser) a partir destes minutos.
@export_range(0, 10, 1) var shotgun_minute := 2
@export_range(0, 10, 1) var bomb_minute := 3
@export_range(0, 10, 1) var mixed_minute := 4
## Maximo de canhoes de um inimigo misto.
@export_range(1, 6, 1) var mixed_max_cannons := 3
## Celulas de rocha alem das de canhao (sorteado entre os dois).
@export_range(0, 30, 1) var extra_cells_min := 3
@export_range(0, 30, 1) var extra_cells_max := 7

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

@export_group("Empurrao nos asteroides")
## Tiros inimigos que acertam outros asteroides nao causam dano: empurram o
## asteroide no sentido do tiro. O valor e dividido pelo numero de celulas
## (ex.: 90 empurra um asteroide de 3 celulas a 30 px/s e um de 18 a 5 px/s).
@export_range(0.0, 2000.0, 5.0) var push_per_hit := 90.0
## Explosao da bomba: empurra para longe do centro (mais fraco na borda).
@export_range(0.0, 5000.0, 10.0) var push_blast := 400.0
## Laser: empurrao continuo por segundo enquanto o raio cruza o asteroide.
@export_range(0.0, 5000.0, 10.0) var push_laser := 240.0

@export_group("Chefe")
## Chega na bandeira (TravelConfig.race_duration): os asteroides e inimigos
## param de vir, o chefe (enorme, casco blindado) entra pela direita, para
## perto da borda e fica atirando. Fases: destruir as torretas, depois o laser
## gigante (sem escudo) e por fim o nucleo (vitoria). Cada arma tem uma vida
## so; o casco quebra celula a celula, como o da nave.
## Vida de cada celula de casco.
@export_range(1.0, 500.0, 1.0) var boss_hull_hp := 20.0
## Vida de cada torreta por celula de canhao (comum 1x, shotgun 3x, bomba 6x).
@export_range(1.0, 500.0, 1.0) var boss_turret_hp := 12.0
## Vida do laser gigante (inteiro) e do nucleo.
@export_range(1.0, 5000.0, 5.0) var boss_laser_hp := 250.0
@export_range(1.0, 5000.0, 5.0) var boss_core_hp := 200.0
## Velocidade de entrada e distancia da borda direita onde ele para.
@export_range(10.0, 500.0, 5.0, "suffix:px/s") var boss_speed := 70.0
@export_range(0.0, 400.0, 5.0, "suffix:px") var boss_edge_margin := 40.0
## Depois de chegar, patrulha para cima e para baixo (para enquanto o laser
## gigante avisa e dispara). Fracao do espaco livre na altura da tela que ele
## usa e velocidade da ida e volta (rad/s; 0.6 = uma volta a cada ~10 s).
@export_range(0.0, 1.0, 0.05) var boss_patrol_range := 0.85
@export_range(0.0, 3.0, 0.05, "suffix:rad/s") var boss_patrol_speed := 0.6
## Recarga dos canhoes do chefe = recarga do inimigo no fim da corrida * isto.
@export_range(0.2, 5.0, 0.05) var boss_cooldown_mult := 1.5
## Distancia que os tiros do chefe voam (ele atira de longe, da borda).
@export_range(200.0, 4000.0, 50.0, "suffix:px") var boss_shot_range := 1500.0
## Laser grande: sai reto para a esquerda e corta a tela no meio. Segundos
## entre um disparo e o proximo (contando o aviso e o raio), aviso (faixa
## piscando) antes do disparo, quanto tempo o raio fica ligado, espessura
## (vezes a do laser normal), comprimento e tempo para destruir uma celula.
@export_range(2.0, 60.0, 0.5, "suffix:s") var boss_laser_cooldown := 12.0
@export_range(0.2, 10.0, 0.1, "suffix:s") var boss_laser_warning := 3.0
@export_range(0.5, 20.0, 0.1, "suffix:s") var boss_laser_duration := 5.0
@export_range(1.0, 12.0, 0.1) var boss_laser_width := 6.0
@export_range(200.0, 4000.0, 50.0, "suffix:px") var boss_laser_length := 1800.0
@export_range(0.02, 2.0, 0.01, "suffix:s") var boss_laser_cell_time := 0.12
## Celulas da nave destruidas se ela bater no chefe (ele nao perde nada).
@export_range(0, 20, 1) var boss_contact_cells := 2
## Pontos por derrotar o chefe.
@export_range(0, 100000, 100) var boss_score := 5000


## Minuto da corrida (indice das listas por minuto).
static func minute_of(elapsed: float) -> int:
	return int(elapsed / 60.0)


func max_alive(elapsed: float) -> int:
	return _by_minute(max_alive_by_minute, elapsed, 2)


func interval(elapsed: float) -> float:
	return _by_minute(interval_by_minute, elapsed, 10.0)


func cooldown(type: int, progress: float) -> float:
	return Weapons.config.base_cooldown(type) * lerpf(cooldown_mult_start, cooldown_mult_end, progress)


func projectile_speed(type: int, progress: float) -> float:
	return Weapons.config.projectile_speed(type) * lerpf(projectile_speed_start, projectile_speed_end, progress)


func aim_error(progress: float) -> float:
	return lerpf(aim_error_start, aim_error_end, progress)


func range_of(type: int) -> float:
	return Weapons.config.range_of(type) * range_mult


## Canhoes de um novo inimigo neste momento da corrida (maiores primeiro).
## Sorteia entre os tipos ja liberados: comum (1 a 3 comuns), shotgun (1 a 2),
## bomba (1) e misto (2 a mixed_max_cannons de qualquer tipo, no maximo 1 laser).
func roll_wave_armament(elapsed: float) -> Array[int]:
	var minute := minute_of(elapsed)
	var kinds := ["common"]
	if minute >= shotgun_minute:
		kinds.append("shotgun")
	if minute >= bomb_minute:
		kinds.append("bomb")
	if minute >= mixed_minute:
		kinds.append("mixed")
	var out: Array[int] = []
	match kinds.pick_random():
		"common":
			for i in randi_range(1, 3):
				out.append(Weapons.COMMON)
		"shotgun":
			for i in randi_range(1, 2):
				out.append(Weapons.SHOTGUN)
		"bomb":
			out.append(Weapons.BOMB)
		"mixed":
			var types := [Weapons.COMMON, Weapons.SHOTGUN, Weapons.BOMB, Weapons.LASER]
			for i in randi_range(2, maxi(mixed_max_cannons, 2)):
				var type: int = types.pick_random()
				out.append(type)
				if type == Weapons.LASER:
					types.erase(Weapons.LASER)
	out.sort_custom(func(a: int, b: int) -> bool: return CannonGroups.cell_count(a) > CannonGroups.cell_count(b))
	return out


## Celulas de um inimigo com esses canhoes (os canhoes mais a rocha).
func enemy_size(armament: Array[int]) -> int:
	var n := 0
	for type in armament:
		n += CannonGroups.cell_count(type)
	return n + randi_range(extra_cells_min, maxi(extra_cells_min, extra_cells_max))


static func _by_minute(values: Variant, elapsed: float, fallback: Variant) -> Variant:
	# Preset sem a lista (ou salvo vazio pelo editor): usa o padrao.
	if values == null or values.is_empty():
		return fallback
	return values[mini(minute_of(elapsed), values.size() - 1)]
