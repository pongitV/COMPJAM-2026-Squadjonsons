class_name Art
extends RefCounted
## Artes das celulas (flores de 19 hexagonos) e dos canhoes. Sao juntadas em
## dois atlas na primeira vez que forem usadas, para cada objeto continuar
## sendo desenhado numa chamada so.

enum { CORE, HULL, COMMON, SHOTGUN, LASER, BOMB, ORE, ASTEROID }

const CELL_FILES := {
	CORE: "cell_core",
	HULL: "cell_hull",
	COMMON: "cell_common",
	SHOTGUN: "cell_shotgun",
	LASER: "cell_laser",
	BOMB: "cell_bomb",
	ORE: "cell_ore",
	ASTEROID: "cell_asteroid",
}
const CANNON_FILES := {
	Weapons.COMMON: "cannon_common",
	Weapons.SHOTGUN: "cannon_shotgun",
	Weapons.LASER: "cannon_laser",
	Weapons.BOMB: "cannon_bomb",
}
## O canhao gira em torno deste ponto da imagem (fracao da altura, a partir
## do topo). Na arte o cano aponta para cima (-Y).
const CANNON_PIVOT := 0.5
## Aumento do canhao em relacao a celula dele: na escala da arte ele tem o
## tamanho da celula e some em cima dela (mesma cor).
const CANNON_ZOOM := 1.6
## Espaco vazio entre as imagens do atlas (evita "vazamento" nos mipmaps).
const PAD := 16

static var _cell_atlas: Texture2D
static var _cell_uv := {}
static var _cell_size := {}
static var _cannon_atlas: Texture2D
static var _cannon_uv := {}
static var _cannon_size := {}


## Pixels do jogo por pixel da arte: cada flor ocupa a largura (ponta a
## ponta) de uma celula, independente do tamanho da imagem.
static func cell_scale(kind: int) -> float:
	cell_atlas()
	return 2.0 * Hex.SIZE / _cell_size[kind].x


## Tipo de arte de uma celula a partir do canhao que ela carrega.
static func for_weapon(weapon: int) -> int:
	match weapon:
		Weapons.COMMON: return COMMON
		Weapons.SHOTGUN: return SHOTGUN
		Weapons.LASER: return LASER
		Weapons.BOMB: return BOMB
	return HULL


static func cell_atlas() -> Texture2D:
	if _cell_atlas == null:
		_cell_atlas = _build_atlas(CELL_FILES, _cell_uv, _cell_size)
	return _cell_atlas


## Regiao da celula no atlas (UV de 0 a 1).
static func cell_uv(kind: int) -> Rect2:
	cell_atlas()
	return _cell_uv[kind]


## Recorte do atlas com a flor de um tipo de celula (icones da interface).
static func cell_icon(kind: int) -> AtlasTexture:
	var atlas := cell_atlas()
	var uv := cell_uv(kind)
	var icon := AtlasTexture.new()
	icon.atlas = atlas
	icon.region = Rect2(uv.position * atlas.get_size(), uv.size * atlas.get_size())
	return icon


## Tamanho da flor no jogo (px).
static func cell_size(kind: int) -> Vector2:
	return _cell_size[kind] * cell_scale(kind)


static func cannon_atlas() -> Texture2D:
	if _cannon_atlas == null:
		_cannon_atlas = _build_atlas(CANNON_FILES, _cannon_uv, _cannon_size)
	return _cannon_atlas


static func cannon_uv(weapon: int) -> Rect2:
	cannon_atlas()
	return _cannon_uv[weapon]


## Tamanho do canhao no jogo (px): a escala da celula do canhao vezes
## CANNON_ZOOM.
static func cannon_size(weapon: int) -> Vector2:
	cannon_atlas()
	return _cannon_size[weapon] * cell_scale(for_weapon(weapon)) * CANNON_ZOOM


## Ponto de giro do canhao, em pixels do jogo a partir do canto superior esquerdo.
static func cannon_pivot(weapon: int) -> Vector2:
	var size := cannon_size(weapon)
	return Vector2(size.x * 0.5, size.y * CANNON_PIVOT)


## Distancia do centro da celula ate a ponta do cano (de onde sai o tiro).
static func muzzle_length(weapon: int) -> float:
	return cannon_pivot(weapon).y


static func _build_atlas(files: Dictionary, uv_out: Dictionary, size_out: Dictionary) -> Texture2D:
	var images := {}
	var width := 0
	var height := 0
	for key in files:
		var img: Image = load("res://art/%s.png" % files[key]).get_image()
		if img.is_compressed():
			img.decompress()
		img.convert(Image.FORMAT_RGBA8)
		images[key] = img
		width += img.get_width() + PAD
		height = maxi(height, img.get_height())
	height += PAD
	var atlas := Image.create_empty(width, height, false, Image.FORMAT_RGBA8)
	var x := 0
	for key in images:
		var img: Image = images[key]
		atlas.blit_rect(img, Rect2i(Vector2i.ZERO, img.get_size()), Vector2i(x, 0))
		uv_out[key] = Rect2(
			float(x) / width, 0.0,
			float(img.get_width()) / width, float(img.get_height()) / height)
		size_out[key] = Vector2(img.get_size())
		x += img.get_width() + PAD
	# Mipmaps: as artes aparecem bem menores que o original e giram.
	atlas.generate_mipmaps()
	return ImageTexture.create_from_image(atlas)
