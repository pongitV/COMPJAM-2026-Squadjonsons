class_name HexFrame
extends RefCounted
## Moldura base do HUD: art/ui/hex_frame.png (borda de hexagonos com pontas
## em chevron), esticada em 9-slice para qualquer largura e altura, com
## variacoes de cor e de espessura.
##
## Fatias (px da imagem original): as pontas (60 px a esquerda, 63 a direita)
## e as faixas de cima/baixo (56 px) ficam intactas; a fileira de hexagonos
## da borda se repete na horizontal (periodo de 21 px) e a coluna do meio da
## ponta se repete na vertical. A cor e trocada mudando o matiz da arte e
## ajustando saturacao/brilho em relacao ao roxo original, entao o desenho
## (contornos claros, chanfros escuros) continua o mesmo em qualquer cor.

const SOURCE := "res://art/ui/hex_frame.png"
## Margens do 9-slice na imagem original: esquerda, cima, direita, baixo.
const MARGINS := [60, 56, 63, 56]
## Cor do miolo na arte original (referencia para recolorir).
const BASE_FILL := Color8(67, 32, 179)
## Espessura da borda de hexagonos e largura das pontas (px da imagem), usadas
## para afastar o conteudo da borda.
const BORDER := 24.0
const CAP := 40.0

## Espessuras prontas (escala da arte).
const THIN := 0.22
const SMALL := 0.3
const MEDIUM := 0.42
const LARGE := 0.6

static var _scaled := {}
static var _textures := {}


## Moldura com o miolo na cor `fill`, na espessura `scale` (1 = arte original).
## `pad` = espaco extra entre a borda e o conteudo.
static func style(fill: Color, scale: float = MEDIUM, pad: float = 6.0) -> StyleBoxTexture:
	var s := StyleBoxTexture.new()
	s.texture = texture(fill, scale)
	s.texture_margin_left = roundf(MARGINS[0] * scale)
	s.texture_margin_top = roundf(MARGINS[1] * scale)
	s.texture_margin_right = roundf(MARGINS[2] * scale)
	s.texture_margin_bottom = roundf(MARGINS[3] * scale)
	s.axis_stretch_horizontal = StyleBoxTexture.AXIS_STRETCH_MODE_TILE_FIT
	s.axis_stretch_vertical = StyleBoxTexture.AXIS_STRETCH_MODE_TILE_FIT
	s.content_margin_left = roundf(CAP * scale + pad)
	s.content_margin_right = roundf(CAP * scale + pad)
	s.content_margin_top = roundf(BORDER * scale + pad * 0.6)
	s.content_margin_bottom = roundf(BORDER * scale + pad * 0.6)
	return s


## Luminancia do miolo das molduras (a do roxo original escurecido um pouco):
## toda variacao de cor fica tao escura quanto ele, e o texto claro e as
## legendas na cor de destaque continuam legiveis.
const FILL_LUMINANCE := 0.16


## Cor do miolo para um conteudo de cor `accent`: mesmo matiz, escurecida ate
## FILL_LUMINANCE.
static func fill_for(accent: Color) -> Color:
	var lum := maxf(accent.get_luminance(), 0.01)
	var c := accent * (FILL_LUMINANCE / lum)
	c.a = 1.0
	# Cores quase sem saturacao (cinza) ficam levemente azuladas, como o resto.
	return c if c.s > 0.15 else Color.from_hsv(0.6, 0.3, c.v)


## Textura recolorida e reescalada (em cache).
static func texture(fill: Color, scale: float) -> Texture2D:
	var key := "%s@%.3f" % [fill.to_html(), scale]
	if not _textures.has(key):
		_textures[key] = ImageTexture.create_from_image(_recolor(_source(scale), fill))
	return _textures[key]


static func _source(scale: float) -> Image:
	if not _scaled.has(scale):
		var img: Image = load(SOURCE).get_image()
		if img.is_compressed():
			img.decompress()
		img.convert(Image.FORMAT_RGBA8)
		if not is_equal_approx(scale, 1.0):
			img.resize(maxi(1, roundi(img.get_width() * scale)), maxi(1, roundi(img.get_height() * scale)),
				Image.INTERPOLATE_LANCZOS)
		_scaled[scale] = img
	return _scaled[scale]


## Troca o matiz pelo de `fill` e escala saturacao/brilho na proporcao entre
## `fill` e o roxo original.
static func _recolor(src: Image, fill: Color) -> Image:
	var img := src.duplicate() as Image
	var s_ratio := fill.s / BASE_FILL.s
	var v_ratio := fill.v / BASE_FILL.v
	for y in img.get_height():
		for x in img.get_width():
			var c := img.get_pixel(x, y)
			if c.a <= 0.0:
				continue
			img.set_pixel(x, y, Color.from_hsv(fill.h, clampf(c.s * s_ratio, 0.0, 1.0),
				clampf(c.v * v_ratio, 0.0, 1.0), c.a))
	return img
