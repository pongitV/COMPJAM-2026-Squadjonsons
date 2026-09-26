class_name Manual
extends RefCounted
## Pecas de interface compartilhadas pelo menu principal e pelo de pausa:
## painel chanfrado, titulo com icone e o manual (controles, regras, canhoes).


## Painel com uma coluna dentro. Retorna [painel, coluna].
static func make_panel(accent: Color) -> Array:
	var panel := PanelContainer.new()
	var style := UIStyle.panel(accent, UIStyle.PANEL_BG, 16)
	style.set_content_margin_all(24)
	panel.add_theme_stylebox_override("panel", style)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	panel.add_child(col)
	return [panel, col]


static func title(col: VBoxContainer, caption: String, text: String, color: Color) -> void:
	var head := HBoxContainer.new()
	head.alignment = BoxContainer.ALIGNMENT_CENTER
	head.add_theme_constant_override("separation", 12)
	head.add_child(HexIcon.new(color, 28))
	var titles := VBoxContainer.new()
	titles.add_theme_constant_override("separation", 2)
	titles.add_child(UIStyle.label(caption, 10, UIStyle.TEXT_DIM, UIStyle.CAPTION))
	titles.add_child(UIStyle.label(text, 22, color, UIStyle.DISPLAY))
	head.add_child(titles)
	col.add_child(head)
	col.add_child(HSeparator.new())


## Reduz o painel se ele nao couber na altura da tela. A escala vai no
## CenterContainer que o envolve (containers zeram a escala dos filhos a
## cada layout), a partir do centro dele.
static func fit(panel: Control) -> void:
	var holder := panel.get_parent() as Control
	var available := panel.get_viewport_rect().size.y - 24.0
	holder.pivot_offset = holder.size * 0.5
	holder.scale = Vector2.ONE * minf(1.0, available / panel.get_combined_minimum_size().y)


## O manual, em tres abas (controles, como jogar, canhoes) para caber na
## tela. Retorna [painel, botao VOLTAR] (quem usa conecta o botao).
static func build() -> Array:
	var parts := make_panel(UIStyle.GREEN)
	var col: VBoxContainer = parts[1]
	title(col, "INFO", "MANUAL", UIStyle.GREEN)

	var tabs := HBoxContainer.new()
	tabs.alignment = BoxContainer.ALIGNMENT_CENTER
	tabs.add_theme_constant_override("separation", 8)
	col.add_child(tabs)
	# Altura fixa: o painel nao muda de tamanho ao trocar de aba.
	var pages := MarginContainer.new()
	pages.custom_minimum_size = Vector2(740, 250)
	pages.add_theme_constant_override("margin_top", 8)
	col.add_child(pages)

	var group := ButtonGroup.new()
	var sections := [["CONTROLES", _controls()], ["COMO JOGAR", _how_to_play()], ["CANHÕES", _cannons()]]
	for i in sections.size():
		var page: Control = sections[i][1]
		page.visible = i == 0
		pages.add_child(page)
		var tab := UIStyle.button(sections[i][0])
		tab.custom_minimum_size = Vector2(180, 34)
		tab.toggle_mode = true
		tab.button_group = group
		tab.button_pressed = i == 0
		tab.toggled.connect(func(on: bool) -> void: page.visible = on)
		tabs.add_child(tab)

	var back := UIStyle.button("VOLTAR")
	back.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	col.add_child(HSeparator.new())
	col.add_child(back)
	return [parts[0], back]


static func _controls() -> Control:
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 20)
	grid.add_theme_constant_override("v_separation", 10)
	var rows := [
		[["W", "A", "S", "D"], "mover (setas também)"],
		[["Clique esquerdo"], "arrastar pedaço até a nave"],
		[["Roda do mouse"], "girar o pedaço"],
		[["Clique direito"], "girar a nave"],
		[["ESC"], "pausar"],
		[["R"], "recomeçar após o fim de jogo"],
	]
	for r in rows:
		var keys := HBoxContainer.new()
		keys.add_theme_constant_override("separation", 6)
		for k in r[0]:
			keys.add_child(UIStyle.key_chip(k))
		grid.add_child(keys)
		var action := UIStyle.label(r[1], 16)
		action.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		grid.add_child(action)
	return grid


static func _how_to_play() -> Control:
	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 10)
	_line(list, Art.CORE, "Proteja o núcleo: se ele cair, fim de jogo.")
	_line(list, Art.COMMON, "Os canhões atiram sozinhos no asteroide mais próximo.")
	_line(list, Art.ASTEROID, "Cada hexágono de asteroide que toca a nave destrói 2 dos seus.")
	_line(list, Art.ORE, "Asteroides destruídos viram pedaços de minério (20% se perde).")
	_line(list, Art.ORE, "Arraste o pedaço até a nave e solte no encaixe.")
	_line(list, Art.HULL, "Partes soltas da nave podem ser encaixadas de novo.")
	return list


static func _cannons() -> Control:
	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 10)
	_line(list, Art.COMMON, "Tiro único. Ganhe 1 a cada %d asteroides." % Weapons.ASTEROIDS_PER_COMMON,
		"COMUM", Weapons.color(Weapons.COMMON))
	_line(list, Art.SHOTGUN, "6 tiros em leque, alcance curto.", "SHOTGUN", Weapons.color(Weapons.SHOTGUN))
	_line(list, Art.LASER, "Raio para fora da nave por 3 s.", "LASER", Weapons.color(Weapons.LASER))
	_line(list, Art.BOMB, "Míssil lento com dano em área.", "BOMBA", Weapons.color(Weapons.BOMB))
	_line(list, Art.HULL, "Não atira, mas protege o núcleo.", "CASCO", Weapons.color(Weapons.NONE))
	var note := UIStyle.label("Minério colorido vira o canhão da mesma cor.", 13, UIStyle.TEXT_DIM)
	list.add_child(note)
	return list


## Linha do manual: flor da celula + nome opcional + frase curta.
static func _line(parent: VBoxContainer, art: int, text: String, heading: String = "", color: Color = UIStyle.TEXT) -> void:
	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", 12)
	var icon := TextureRect.new()
	icon.texture = Art.cell_icon(art)
	icon.custom_minimum_size = Vector2(30, 28)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	line.add_child(icon)
	if heading != "":
		var name_label := UIStyle.label(heading, 14, color, UIStyle.DISPLAY)
		name_label.custom_minimum_size.x = 110
		name_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		line.add_child(name_label)
	var desc := UIStyle.label(text, 16)
	desc.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	line.add_child(desc)
	parent.add_child(line)
