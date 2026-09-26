class_name UISkin
extends RefCounted
## Sprites proprios da interface. Cada peca visual da UI tem um nome (slot);
## se existir res://art/ui/<slot>.png, o sprite e usado no lugar do
## placeholder desenhado em codigo. Sem o arquivo, nada muda.
##
## Paineis e botoes sao esticados em 9-slice: os cantos (SLICE px) ficam
## intactos e o meio estica. Icones e demais sprites sao encaixados no
## tamanho do placeholder, mantendo a proporcao.

const DIR := "res://art/ui/"
## Margem padrao do 9-slice (px da imagem), e excecoes por slot.
const DEFAULT_SLICE := 12
const SLICE := {
	"key": 6,
}

## Todos os slots (nome -> descricao). Serve de documentacao e pega erros de
## digitacao: pedir um slot que nao esta aqui falha em modo debug.
const SLOTS := {
	# Paineis (9-slice)
	"card": "Moldura padrao dos cards e abas (usada se o card nao tiver a sua).",
	"card_record": "Card de recorde (menu principal).",
	"card_cells": "Aba de hexagonos da nave (HUD, topo a esquerda).",
	"card_countdown": "Aba do countdown ate a chegada (HUD, topo a direita).",
	"card_race": "Moldura da linha de chegada no rodape.",
	"card_boss": "Moldura da barra de vida do chefe (no alto da tela).",
	"panel": "Moldura padrao dos paineis grandes (usada se o painel nao tiver a sua).",
	"panel_pause": "Painel do menu de pausa.",
	"panel_manual": "Painel do manual.",
	"panel_game_over": "Painel de game over.",
	"panel_victory": "Painel de vitoria (chefe derrotado).",
	"panel_tutorial": "Caixa de texto do tutorial.",
	"panel_formations": "Janela das formacoes dos canhoes (tutorial).",
	"key": "Chip de tecla do manual.",
	"separator": "Linha separadora horizontal (so estica na largura).",
	# Botoes (9-slice)
	"button_normal": "Botao parado.",
	"button_hover": "Botao com o mouse em cima (sem ele: button_normal).",
	"button_pressed": "Botao apertado / aba ativa (sem ele: hover ou normal).",
	"button_focus": "Destaque de foco do teclado, desenhado por cima do botao (sem ele: button_hover).",
	# Icones (encaixados no tamanho do placeholder)
	"icon_cells": "Icone do card de hexagonos (HUD).",
	"icon_countdown": "Icone do card de countdown (HUD).",
	"icon_record": "Icone do card de recorde.",
	"icon_pause": "Icone do titulo do menu de pausa.",
	"icon_manual": "Icone do titulo do manual.",
	"key_arrow": "Seta das teclas direcionais, apontando para a DIREITA (e girada).",
	"key_mouse_left": "Mouse com o botao esquerdo aceso (manual e tutorial).",
	"key_mouse_right": "Mouse com o botao direito aceso.",
	"key_mouse_wheel": "Mouse com a roda acesa.",
	"reticle": "Mira que segue o mouse durante o jogo (centro = ponta do mouse).",
	"race_marker": "Marcador da nave na linha de chegada do rodape.",
	"race_flag": "Bandeira de chegada no fim da linha do rodape (mastro embaixo a esquerda).",
	# Imagens inteiras
	"title_logo": "Logo do menu principal (substitui o texto HEXCORE).",
	"damage_vignette": "Borda de dano que pisca na tela toda.",
	"backdrop_menu": "Fundo atras do manual no menu principal.",
	"backdrop_pause": "Fundo atras do menu de pausa.",
	"backdrop_game_over": "Fundo atras do painel de game over.",
	"backdrop_victory": "Fundo atras do painel de vitoria.",
}

static var _cache := {}


## Sprite do primeiro slot que tiver arquivo (aceita um nome ou uma lista
## de nomes, em ordem de preferencia). Null se nenhum tiver.
static func texture(slots: Variant) -> Texture2D:
	var slot := _first_with_sprite(slots)
	return _cache[slot] if slot != "" else null


static func has(slots: Variant) -> bool:
	return _first_with_sprite(slots) != ""


## StyleBox 9-slice do sprite, ou o placeholder se nao houver sprite.
## As margens de conteudo (espaco interno) sao as do placeholder.
static func stylebox(slots: Variant, placeholder: StyleBox) -> StyleBox:
	var slot := _first_with_sprite(slots)
	if slot == "":
		return placeholder
	var s := StyleBoxTexture.new()
	s.texture = _cache[slot]
	s.set_texture_margin_all(SLICE.get(slot, DEFAULT_SLICE))
	for side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
		s.set_content_margin(side, placeholder.get_content_margin(side))
	return s


## Troca um Control placeholder por um TextureRect com o sprite (se houver).
## `fill` estica o sprite na area toda (fundos); senao ele mantem o tamanho
## e a proporcao da imagem.
static func replace(slot: String, placeholder: Control, fill: bool = false) -> Control:
	var tex := texture(slot)
	if tex == null:
		return placeholder
	var rect := TextureRect.new()
	rect.texture = tex
	rect.mouse_filter = placeholder.mouse_filter
	if fill:
		rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		rect.stretch_mode = TextureRect.STRETCH_SCALE
	else:
		rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	placeholder.free()
	return rect


static func _first_with_sprite(slots: Variant) -> String:
	for slot: String in (slots if slots is Array else [slots]):
		assert(SLOTS.has(slot), "Slot de UI desconhecido: %s" % slot)
		if not _cache.has(slot):
			var path := DIR + slot + ".png"
			_cache[slot] = load(path) if ResourceLoader.exists(path) else null
		if _cache[slot] != null:
			return slot
	return ""
