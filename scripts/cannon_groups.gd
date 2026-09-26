class_name CannonGroups
extends RefCounted
## O canhao comum e o "bloco de montar" dos demais: celulas de canhao comum
## adjacentes em formato de triangulo se fundem num unico canhao maior que
## ocupa o triangulo todo. 3 celulas (lado 2) = shotgun, 6 (lado 3) = bomba,
## 10 (lado 4) = laser. As celulas continuam sendo canhoes comuns; o canhao
## grande e derivado delas, entao perder uma celula desfaz a fusao e o que
## sobrar volta a se fundir no maior triangulo possivel.
##
## Grupo: {type, cells: Array[Vector2i], side, key: Vector3i, center: Vector2}
## (center em pixels da grade; key identifica o grupo entre recalculos).

const SIDES := {Weapons.SHOTGUN: 2, Weapons.BOMB: 3, Weapons.LASER: 4}
## Os maiores sao procurados primeiro.
const MERGE_ORDER := [Weapons.LASER, Weapons.BOMB, Weapons.SHOTGUN]


## Numero de celulas de um canhao (1 para o comum).
static func cell_count(type: int) -> int:
	var side: int = SIDES.get(type, 1)
	return (side * (side + 1)) >> 1


## Celulas de um triangulo de lado `side` com vertice em `anchor`. Na grade
## hexagonal ha duas orientacoes (`flip`); as demais rotacoes repetem essas.
static func triangle(anchor: Vector2i, side: int, flip: bool) -> Array[Vector2i]:
	var s := -1 if flip else 1
	var out: Array[Vector2i] = []
	for q in side:
		for r in side - q:
			out.append(anchor + Vector2i(q, r) * s)
	return out


## Grupos formados pelas celulas de canhao comum (cells: Vector2i -> tipo).
## Celulas em `fixed` nao se fundem (ex.: o nucleo) e ficam como comuns.
static func find(cells: Dictionary, fixed: Dictionary = {}) -> Array:
	var free := {}
	for h in cells:
		if cells[h] == Weapons.COMMON and not fixed.has(h):
			free[h] = true
	# Ordem fixa: a mesma forma sempre gera os mesmos grupos (sem piscar).
	var keys := free.keys()
	keys.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return a.x < b.x or (a.x == b.x and a.y < b.y))
	var groups := []
	for type in MERGE_ORDER:
		var side: int = SIDES[type]
		for h in keys:
			if not free.has(h):
				continue
			for flip in [false, true]:
				var tri := triangle(h, side, flip)
				if tri.all(func(c: Vector2i) -> bool: return free.has(c)):
					for c in tri:
						free.erase(c)
					groups.append(_group(type, tri, side))
					break
	for h in keys:
		if free.has(h):
			groups.append(_group(Weapons.COMMON, [h], 1))
	for h in fixed:
		if cells.get(h, Weapons.NONE) == Weapons.COMMON:
			groups.append(_group(Weapons.COMMON, [h], 1))
	return groups


## Escala da arte do canhao para um triangulo de lado `side`.
static func art_scale(side: int) -> float:
	return 1.0 + (side - 1) * 0.7


static func _group(type: int, group_cells: Array, side: int) -> Dictionary:
	var sum := Vector2.ZERO
	for c in group_cells:
		sum += Hex.to_pixel(c)
	var first: Vector2i = group_cells[0]
	return {
		"type": type,
		"cells": group_cells,
		"side": side,
		"key": Vector3i(first.x, first.y, type),
		"center": sum / group_cells.size(),
	}
