class_name TravelConfig
extends Resource
## Parametros da "viagem": a camera fica parada e so o fundo rola, dando a
## impressao de que a nave avanca. Aqui ficam a velocidade do fundo, os
## efeitos de velocidade e a duracao da corrida ate a bandeira de chegada.
## Edite no Inspector abrindo config/travel.tres (ou troque o preset no campo
## "Travel Config" do no Game).

@export_group("Fundo")
## Velocidade de rolagem no inicio da partida (camada mais proxima de estrelas).
@export_range(0.0, 3000.0, 5.0, "suffix:px/s") var scroll_speed := 260.0
## Quanto a velocidade aumenta por minuto de partida (0 = constante).
@export_range(0.0, 1000.0, 5.0, "suffix:px/s") var scroll_speed_per_minute := 25.0
## Velocidade maxima de rolagem.
@export_range(0.0, 5000.0, 5.0, "suffix:px/s") var scroll_speed_max := 400.0
## Direcao em que a nave "avanca" (0 = direita; o fundo rola ao contrario).
@export_range(-180.0, 180.0, 1.0, "radians_as_degrees") var travel_angle := 0.0
## Velocidade relativa das estrelas mais distantes e das mais proximas
## (parallax: 1 = rola na velocidade cheia).
@export_range(0.0, 2.0, 0.01) var parallax_far := 0.12
@export_range(0.0, 3.0, 0.01) var parallax_near := 1.0
## Quantidade de estrelas.
@export_range(0, 2000, 10) var star_count := 260
## Rastro das estrelas: quantos segundos de movimento cada uma "borra"
## (0 = pontos; maior = riscos mais longos).
@export_range(0.0, 0.3, 0.005, "suffix:s") var star_streak := 0.035
## Linhas de velocidade: riscos longos e rapidos passando pelo fundo.
@export_range(0, 100, 1) var speed_lines := 10
@export_range(0.0, 1.0, 0.01) var speed_line_alpha := 0.1
## Velocidade das linhas em relacao a rolagem.
@export_range(0.5, 5.0, 0.1) var speed_line_factor := 2.2

@export_group("Efeitos de velocidade")
## Riscos de vento saindo de tras da nave.
@export_range(0, 30, 1) var ship_streaks := 6
@export_range(0.0, 400.0, 5.0, "suffix:px") var ship_streak_length := 70.0
## Particulas de rastro soltas pela traseira da nave, por segundo.
@export_range(0.0, 200.0, 1.0, "suffix:/s") var ship_wake_rate := 30.0
## Riscos de vento atras de cada asteroide.
@export_range(0, 20, 1) var asteroid_streaks := 3
@export_range(0.0, 400.0, 5.0, "suffix:px") var asteroid_streak_length := 45.0
## Opacidade dos riscos (0 = desliga).
@export_range(0.0, 1.0, 0.01) var streak_alpha := 0.16

@export_group("Fluxo")
## Arrasto lento dos asteroides no sentido contrario ao avanco: somado a
## velocidade de cada um que nasce, faz eles "passarem" pela nave.
@export_range(0.0, 500.0, 1.0, "suffix:px/s") var asteroid_drift := 45.0
## Arrasto dos pedacos de minerio soltos (a velocidade deles tende a esta):
## ficam para tras e saem da tela pela esquerda se ninguem pegar.
@export_range(0.0, 500.0, 1.0, "suffix:px/s") var ore_drift := 45.0
## Chance de um asteroide nascer a frente (no sentido do avanco); o resto
## nasce em qualquer ponto em volta da tela.
@export_range(0.0, 1.0, 0.05) var spawn_ahead_chance := 0.7
## Abertura do arco "a frente" onde eles nascem (centrado no avanco).
@export_range(0.0, 360.0, 1.0, "radians_as_degrees") var spawn_ahead_arc := 2.1

@export_group("Chegada")
## Tempo ate a bandeira de chegada (a barra no rodape enche nesse tempo).
@export_range(10.0, 3600.0, 5.0, "suffix:s") var race_duration := 300.0


## Velocidade de rolagem depois de `elapsed` segundos.
func speed_at(elapsed: float) -> float:
	return minf(scroll_speed + elapsed / 60.0 * scroll_speed_per_minute, maxf(scroll_speed_max, scroll_speed))


## Direcao do avanco da nave (o fundo anda no sentido oposto).
func direction() -> Vector2:
	return Vector2.from_angle(travel_angle)


## Velocidade de arrasto somada aos asteroides.
func drift() -> Vector2:
	return -direction() * asteroid_drift


## Velocidade para a qual os minerios soltos tendem.
func ore_drift_velocity() -> Vector2:
	return -direction() * ore_drift


## Angulo (a partir do centro da tela) onde um asteroide nasce.
func roll_spawn_angle() -> float:
	if randf() < spawn_ahead_chance:
		return travel_angle + randf_range(-0.5, 0.5) * spawn_ahead_arc
	return randf() * TAU
