class_name Ore
extends HexBody
## Pedaco de minerio: um grupo de celulas soltas, vindo de um asteroide
## destruido ou de uma parte que se soltou da nave. Arrastado pelo raio
## trator e encaixado no grid da nave, vira parte dela.
## cells: Vector2i -> Weapons.NONE (minerio verde, vira casco) ou
## Weapons.COMMON (canhao; em triangulo ja aparece como o canhao grande).

## Cor da arte do minerio verde (para feixe, efeitos e textos).
const COLOR := Color("#4df0b0")
const LIFETIME := 25.0
const CANNON_LIFETIME := 35.0

## Sendo arrastado pelo raio trator.
var dragged := false
var life := LIFETIME
var _pulse := randf() * TAU


## Cria o pedaco a partir de celulas de outro objeto (asteroide ou nave),
## no mesmo lugar e com a mesma rotacao em que elas estavam.
## weapons: Vector2i -> tipo (celulas ausentes sao minerio verde).
func setup_from(source: HexBody, keys: Array, weapons: Dictionary = {}) -> void:
	for h in keys:
		cells[h] = weapons.get(h, Weapons.NONE)
	position = source.position
	rotation = source.rotation
	center_offset = source.center_offset
	recenter()
	life = CANNON_LIFETIME if has_cannon() else LIFETIME


func has_cannon() -> bool:
	return not groups.is_empty()


## Cor principal do pedaco (a do maior canhao, se tiver um).
func main_color() -> Color:
	var best := -1
	for g in groups:
		if best < 0 or CannonGroups.cell_count(g.type) > CannonGroups.cell_count(best):
			best = g.type
	return Weapons.color(best) if best >= 0 else COLOR


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
	if has_cannon():
		_pulse += delta * 5.0
		queue_redraw()


func cell_art(h: Vector2i) -> int:
	return cannon_art(h, Art.ORE)


func _draw() -> void:
	# Brilho pulsante atras das celulas de canhao, na cor do canhao que formam.
	for g in groups:
		var glow := Weapons.color(g.type)
		glow.a = 0.25 + 0.15 * sin(_pulse)
		for h in g.cells:
			draw_circle(cell_local(h), Hex.SIZE * (1.5 + 0.15 * sin(_pulse)), glow)
	super._draw()
