class_name Weapons
extends RefCounted
## Tipos de canhao que uma celula do jogador pode ter, com cores e nomes.
## Celulas sem canhao (NONE) sao casco: nao atiram. Os numeros de
## balanceamento (recarga, dano, alcance...) ficam em CannonConfig.

enum { NONE, COMMON, SHOTGUN, LASER, BOMB }

## Cores das artes (celulas e canhoes).
const COLORS := {
	NONE: Color("#e8ecf2"),
	COMMON: Color("#2f8cff"),
	SHOTGUN: Color("#ff9a1a"),
	LASER: Color("#ff2a2a"),
	BOMB: Color("#b44dff"),
}
const NAMES := {
	NONE: "CASCO",
	COMMON: "COMUM",
	SHOTGUN: "SHOTGUN",
	LASER: "LASER",
	BOMB: "BOMBA",
}
## Espessura do raio laser (visual e area de acerto).
const LASER_WIDTH := 6.0

## Parametros em uso (o jogo troca pelo preset escolhido no no Game).
## Carregado no primeiro uso: CannonConfig usa as constantes daqui, entao um
## preload na inicializacao desta classe seria circular.
static var config: CannonConfig:
	get:
		if config == null:
			config = load("res://config/cannons.tres")
		return config


static func color(weapon: int) -> Color:
	return COLORS[weapon]
