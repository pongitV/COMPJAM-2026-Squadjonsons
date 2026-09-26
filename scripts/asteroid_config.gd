class_name AsteroidConfig
extends Resource
## Todos os parametros de balanceamento dos asteroides, num lugar so.
## Edite no Inspector abrindo config/asteroids.tres (ou duplique o arquivo
## para criar presets e arraste o novo no campo "Asteroid Config" do no Game).
## Os valores abaixo sao os padroes usados quando o .tres nao muda nada.

@export_group("Dificuldade com o tempo")
## Multiplicador de dificuldade: comeca em 1 e sobe tanto por minuto de
## partida (0.1 = +10% por minuto; 0 = desligado). Ele multiplica o que
## estiver marcado abaixo, somado as rampas proprias de spawn e tamanho.
@export_range(0.0, 2.0, 0.01, "suffix:/min") var difficulty_per_minute := 0.1
## Teto do multiplicador (2.5 = no maximo 2,5x).
@export_range(1.0, 10.0, 0.1) var difficulty_max := 2.5
## Asteroides nascem com mais HP (e valem mais pontos).
@export var difficulty_scales_hp := true
## Asteroides nascem mais rapidos.
@export var difficulty_scales_speed := true
## Asteroides nascem com mais frequencia (respeitando spawn_interval_min).
@export var difficulty_scales_spawn := true

@export_group("Spawn")
## Segundos ate o primeiro asteroide aparecer.
@export_range(0.0, 10.0, 0.1, "suffix:s") var first_spawn_delay := 1.0
## Intervalo entre spawns no inicio da partida.
@export_range(0.05, 10.0, 0.05, "suffix:s") var spawn_interval_start := 2.0
## Menor intervalo possivel (o spawn nunca fica mais rapido que isso).
@export_range(0.05, 10.0, 0.05, "suffix:s") var spawn_interval_min := 0.55
## Quanto o intervalo diminui por segundo de jogo (0 = ritmo constante).
## Com os padroes, chega ao minimo em (2.0 - 0.55) / 0.008 = ~3 min.
@export_range(0.0, 0.1, 0.001) var spawn_interval_decay := 0.008
## Variacao aleatoria do intervalo (0.3 = entre 70% e 130% do valor).
@export_range(0.0, 1.0, 0.05) var spawn_interval_jitter := 0.3
## Maximo de asteroides vivos ao mesmo tempo (o spawn espera abaixo disso).
@export_range(1, 500, 1) var max_asteroids := 100
## Distancia alem da borda da tela em que os asteroides nascem.
@export_range(0.0, 1000.0, 10.0, "suffix:px") var spawn_margin := 120.0
## Sao removidos quando ficam mais longe que (raio da tela * fator).
@export_range(1.0, 10.0, 0.1) var despawn_factor := 2.5
## Desvio maximo da direcao do asteroide em relacao ao jogador
## (0 = vem reto na nave).
@export_range(0.0, 180.0, 0.5, "radians_as_degrees") var aim_spread := 0.6

@export_group("Tamanho")
## Menor asteroide (em celulas). Pedacos menores que isso viram poeira.
@export_range(1, 20, 1) var min_size := 3
## Maior asteroide possivel, nao importa o tempo de jogo.
@export_range(1, 200, 1) var size_cap := 40
## Tamanho maximo sorteado no inicio da partida.
@export_range(1, 200, 1) var start_max_size := 3
## A cada tantos segundos o tamanho maximo cresce 1 celula (0 = nao cresce).
@export_range(0.0, 120.0, 0.5, "suffix:s") var seconds_per_size := 10.0
## Celulas a mais no tamanho maximo por celula de canhao que a nave tem
## (um laser, feito de 10 comuns, conta 10).
@export_range(0.0, 10.0, 0.1) var size_per_cannon := 1.5
## Controla o tamanho medio: o sorteio vai de min_size ate o maximo atual e
## a media fica em ~ min + (max - min) / (size_bias + 1).
## 1 = uniforme; maior = asteroides pequenos mais comuns; menor que 1 = grandes.
@export_range(0.1, 5.0, 0.05) var size_bias := 1.7

@export_group("Vida e pontos")
## HP = ceil(hp_multiplier * celulas ^ hp_exponent), em "disparos" do
## canhao comum (ex.: 9 celulas, padrao = 27 tiros).
@export_range(0.1, 10.0, 0.05) var hp_multiplier := 1.0
@export_range(0.5, 3.0, 0.05) var hp_exponent := 1.5
## Pontos ao destruir = HP maximo * este fator.
@export_range(0.0, 10.0, 0.05) var score_per_hp := 1.0

@export_group("Movimento")
## Faixa de velocidade sorteada no spawn (antes do ajuste por tamanho).
@export_range(0.0, 1000.0, 1.0, "suffix:px/s") var speed_min := 30.0
@export_range(0.0, 1000.0, 1.0, "suffix:px/s") var speed_max := 85.0
## Multiplicador da velocidade dos asteroides minusculos e dos grandes
## (a partir de large_size celulas); entre os dois e linear.
@export_range(0.0, 5.0, 0.05) var speed_mult_small := 1.2
@export_range(0.0, 5.0, 0.05) var speed_mult_large := 0.7
@export_range(1, 200, 1) var large_size := 30
## Giro inicial maximo (dividido pela raiz do tamanho: grandes giram menos).
@export_range(0.0, 10.0, 0.05, "suffix:rad/s") var spin_max := 0.8
## Limite de giro depois de batidas.
@export_range(0.0, 20.0, 0.1, "suffix:rad/s") var spin_limit := 3.0
## Elasticidade da batida entre asteroides (0 = gruda, 1 = quique perfeito).
@export_range(0.0, 1.0, 0.05) var bounce := 0.6
## Velocidade extra dos pedacos quando um asteroide se parte na nave.
@export_range(0.0, 200.0, 1.0, "suffix:px/s") var split_speed := 15.0

@export_group("Dano na nave")
## Quantas celulas da nave cada celula do asteroide destroi antes de sumir.
@export_range(1, 10, 1) var cell_charges := 2

@export_group("Minerio")
## Fracao das celulas que se perde quando o asteroide vira minerio (canhoes
## incluidos: sao celulas como as outras). So somem celulas cuja perda nao
## parte o que sobra.
@export_range(0.0, 1.0, 0.05) var ore_loss := 0.2
## Em quantos pedacos o asteroide se parte: 1 ate `no_split_size` celulas e
## mais um a cada `cells_per_extra_piece` celulas acima disso. Com os padroes:
## 4 celulas = 1 pedaco, 10 = 2, 16 = 3, 40 = 7.
@export_range(1, 50, 1) var no_split_size := 4
@export_range(1.0, 30.0, 0.5) var cells_per_extra_piece := 6.0
## Variacao aleatoria no numero de pedacos (0.5 = ate meio pedaco para mais
## ou para menos, arredondado no sorteio).
@export_range(0.0, 3.0, 0.1) var piece_count_jitter := 0.5
## Velocidade com que os pedacos se afastam do asteroide destruido.
@export_range(0.0, 300.0, 1.0, "suffix:px/s") var ore_speed_min := 20.0
@export_range(0.0, 300.0, 1.0, "suffix:px/s") var ore_speed_max := 55.0
## Maximo de pedacos soltos na tela (os mais antigos somem).
@export_range(1, 500, 1) var max_ores := 150


## Multiplicador de dificuldade depois de `elapsed` segundos de partida.
func difficulty(elapsed: float) -> float:
	return minf(1.0 + elapsed / 60.0 * difficulty_per_minute, maxf(difficulty_max, 1.0))


func hp_scale(elapsed: float) -> float:
	return difficulty(elapsed) if difficulty_scales_hp else 1.0


func speed_scale(elapsed: float) -> float:
	return difficulty(elapsed) if difficulty_scales_speed else 1.0


## Tempo ate o proximo spawn.
func spawn_interval(elapsed: float) -> float:
	var base := spawn_interval_start - elapsed * spawn_interval_decay
	if difficulty_scales_spawn:
		base /= difficulty(elapsed)
	base = maxf(spawn_interval_min, base)
	return base * randf_range(1.0 - spawn_interval_jitter, 1.0 + spawn_interval_jitter)


## Maior tamanho que pode ser sorteado agora.
func max_size(elapsed: float, cannons: int) -> int:
	var growth := int(elapsed / seconds_per_size) if seconds_per_size > 0.0 else 0
	return clampi(start_max_size + growth + int(cannons * size_per_cannon), min_size, maxi(size_cap, min_size))


## Tamanho de um novo asteroide (pequenos sao mais comuns, ver size_bias).
func roll_size(elapsed: float, cannons: int) -> int:
	var top := max_size(elapsed, cannons)
	return min_size + int(pow(randf(), size_bias) * (top - min_size + 1))


## `scale` = hp_scale() da hora em que o asteroide nasceu.
func max_hp_for(cells: int, scale: float = 1.0) -> int:
	return maxi(1, ceili(hp_multiplier * scale * pow(cells, hp_exponent)))


func score_for(max_hp: int) -> int:
	return roundi(max_hp * score_per_hp)


## Velocidade de spawn: sorteada e reduzida conforme o tamanho.
func roll_speed(cells: int) -> float:
	var t := minf(float(cells) / large_size, 1.0)
	return randf_range(speed_min, speed_max) * lerpf(speed_mult_small, speed_mult_large, t)


func roll_spin(cells: int) -> float:
	return randf_range(-spin_max, spin_max) / sqrt(cells)


## Quantos pedacos de minerio um asteroide de `cells` celulas vira (sorteado:
## a media sobe com o tamanho; o arredondamento e aleatorio na proporcao).
func roll_piece_count(cells: int) -> int:
	var expected := 1.0 + maxf(0.0, cells - no_split_size) / cells_per_extra_piece
	expected = maxf(1.0, expected + randf_range(-piece_count_jitter, piece_count_jitter))
	var whole := int(expected)
	return whole + (1 if randf() < expected - whole else 0)
