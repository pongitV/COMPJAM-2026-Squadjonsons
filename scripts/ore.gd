class_name Ore
extends HexBody
## Pedaco de minerio: um grupo de celulas soltas, vindo de um asteroide
## destruido ou de uma parte que se soltou da nave. Arrastado pelo raio
## trator e encaixado no grid da nave, vira parte dela.
## cells: Vector2i -> tipo de canhao (Weapons.NONE = minerio verde, vira casco).

## Cor da arte do minerio verde (para feixe, efeitos e textos).
const COLOR := Color("#6ffc12")
const LIFETIME := 25.0
const SPECIAL_LIFETIME := 35.0

## Sendo arrastado pelo raio trator.
var dragged := false
var life := LIFETIME
var _pulse := randf() * TAU


## Cria o pedaco a partir de celulas de outro objeto (asteroide ou nave),
## no mesmo lugar e com a mesma rotacao em que elas estavam.
## weapons: Vector2i -> tipo de canhao (celulas ausentes sao minerio verde).
func setup_from(source: HexBody, keys: Array, weapons: Dictionary = {}) -> void:
	for h in keys:
		cells[h] = weapons.get(h, Weapons.NONE)
	position = source.position
	rotation = source.rotation
	center_offset = source.center_offset
	recenter()
	life = SPECIAL_LIFETIME if has_special() else LIFETIME


func has_special() -> bool:
	for h in cells:
		if cells[h] != Weapons.NONE:
			return true
	return false


## Cor principal do pedaco (a do canhao, se tiver um).
func main_color() -> Color:
	for h in cells:
		if cells[h] != Weapons.NONE:
			return Weapons.color(cells[h])
	return COLOR


func step(delta: float) -> void:
	if dragged:
		# Quem move e gira e o raio trator; e nao expira enquanto esta preso nele.
		visible = true
		return
	rotation += angular_velocity * delta
	velocity *= pow(0.5, delta)
	position += velocity * delta
	life -= delta
	# Pisca nos ultimos segundos antes de sumir.
	visible = life > 5.0 or fmod(life, 0.3) > 0.12
	if has_special():
		_pulse += delta * 5.0
		queue_redraw()


func cell_art(h: Vector2i) -> int:
	return Art.ORE if cells[h] == Weapons.NONE else Art.for_weapon(cells[h])


func _draw() -> void:
	# Brilho pulsante atras das celulas de canhao, para destaca-las.
	for h in cells:
		if cells[h] != Weapons.NONE:
			var glow := Weapons.color(cells[h])
			glow.a = 0.25 + 0.15 * sin(_pulse)
			draw_circle(cell_local(h), Hex.SIZE * (1.5 + 0.15 * sin(_pulse)), glow)
	super._draw()
