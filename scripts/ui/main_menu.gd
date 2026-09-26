class_name MainMenu
extends Node2D
## Tela inicial: asteroides e pedaços de minério flutuando, uma nave de
## vitrine girando, título, recorde e botões (jogar, manual, sair).

const SCENE := "res://main.tscn"
const GAME_SCENE := "res://game.tscn"
## Onde fica a nave de vitrine (mundo) e a câmera do fundo.
const SHOWCASE_POS := Vector2(190.0, 10.0)
const CAMERA_ZOOM := 1.6
const DRIFTERS := 14

var _camera: Camera2D
var _starfield: Starfield
var _showcase: Player
## [objeto, velocidade, velocidade angular]
var _drifters: Array = []
var _half_view := Vector2.ZERO
var _root: Control
var _main_panel: Control
var _manual_panel: Control
var _play_button: Button
var _manual_back: Button
var _fade: ColorRect
var _leaving := false
var _music: AudioStreamPlayer


func _ready() -> void:
	InputActions.ensure_defaults()
	
	_music = AudioStreamPlayer.new()
	_music.stream = preload("res://Audio/Music/menu.wav")
	_music.volume_db = -10.0
	add_child(_music)
	_music.play()
	
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	# As artes aparecem menores que o original e giram: mipmaps evitam serrilhado.
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS

	var bg := CanvasLayer.new()
	bg.layer = -1
	add_child(bg)
	_starfield = Starfield.new()
	bg.add_child(_starfield)

	_camera = Camera2D.new()
	_camera.zoom = Vector2.ONE * CAMERA_ZOOM
	add_child(_camera)
	_camera.make_current()
	_half_view = get_viewport_rect().size / CAMERA_ZOOM * 0.5

	for i in DRIFTERS:
		_spawn_drifter(Vector2(randf_range(-1, 1), randf_range(-1, 1)) * _half_view)
	_build_showcase()
	_build_ui()


func _process(delta: float) -> void:
	_starfield.cam_pos += Vector2(22.0, 6.0) * delta
	_starfield.queue_redraw()
	_showcase.rotation += 0.12 * delta
	# Os objetos do fundo atravessam a tela e reaparecem do outro lado.
	var bounds := _half_view + Vector2.ONE * 60.0
	for d in _drifters:
		var body: HexBody = d[0]
		body.position += d[1] * delta
		body.rotation += d[2] * delta
		if absf(body.position.x) > bounds.x:
			body.position.x = -signf(body.position.x) * bounds.x
		if absf(body.position.y) > bounds.y:
			body.position.y = -signf(body.position.y) * bounds.y


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause") and _manual_panel.visible:
		get_viewport().set_input_as_handled()
		_show_main()


# --- Fundo ------------------------------------------------------------------

## Asteroide ou pedaço de minério decorativo, flutuando devagar.
func _spawn_drifter(at: Vector2) -> void:
	var rock := Asteroid.new()
	rock.setup(randi_range(3, 9))
	var body: HexBody = rock
	if randf() < 0.45:
		var piece := Ore.new()
		var keys := rock.cells.keys().slice(0, randi_range(2, 4))
		var weapons := {}
		if randf() < 0.3:
			weapons[keys[0]] = [Weapons.COMMON, Weapons.SHOTGUN, Weapons.LASER, Weapons.BOMB].pick_random()
		piece.setup_from(rock, keys, weapons)
		rock.free()
		body = piece
	body.position = at
	body.rotation = randf() * TAU
	body.modulate.a = 0.35
	add_child(body)
	_drifters.append([body, Vector2.from_angle(randf() * TAU) * randf_range(8.0, 22.0), randf_range(-0.3, 0.3)])


## Nave de exemplo: núcleo, casco e os quatro canhões.
func _build_showcase() -> void:
	_showcase = Player.new()
	_showcase.position = SHOWCASE_POS
	add_child(_showcase)
	for d in Hex.DIRS:
		_showcase.attach_piece({d: Weapons.NONE})
	var outer := [
		[Vector2i(2, -1), Weapons.COMMON], [Vector2i(-2, 1), Weapons.SHOTGUN],
		[Vector2i(0, -2), Weapons.LASER], [Vector2i(0, 2), Weapons.BOMB],
		[Vector2i(2, 0), Weapons.NONE], [Vector2i(-2, 0), Weapons.NONE],
		[Vector2i(1, -2), Weapons.NONE], [Vector2i(-1, 2), Weapons.NONE],
	]
	for o in outer:
		_showcase.attach_piece({o[0]: o[1]})


# --- Interface --------------------------------------------------------------

func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	_root = Control.new()
	_root.theme = UIStyle.theme()
	layer.add_child(_root)
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var side := MarginContainer.new()
	side.add_theme_constant_override("margin_left", 80)
	side.add_theme_constant_override("margin_top", 70)
	_root.add_child(side)
	side.set_anchors_and_offsets_preset(Control.PRESET_LEFT_WIDE)
	_main_panel = _build_main()
	side.add_child(_main_panel)

	var credits := UIStyle.label("Fonte Hexagon por twannieboy (CC BY-NC-SA 3.0)", 11, Color(UIStyle.TEXT_DIM, 0.5), UIStyle.CAPTION)
	_root.add_child(credits)
	credits.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT, Control.PRESET_MODE_MINSIZE, 20)

	# Manual por cima de tudo, com o fundo escurecido.
	var manual_layer := Control.new()
	manual_layer.visible = false
	_root.add_child(manual_layer)
	manual_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var dim := ColorRect.new()
	dim.color = Color(0.0, 0.01, 0.04, 0.75)
	manual_layer.add_child(dim)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var center := CenterContainer.new()
	manual_layer.add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var manual := Manual.build()
	center.add_child(manual[0])
	_manual_back = manual[1]
	_manual_back.pressed.connect(_show_main)
	_manual_panel = manual_layer

	# Entra com um fade a partir do preto.
	_fade = ColorRect.new()
	_fade.color = Color(0.0, 0.0, 0.02)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_fade)
	_fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	create_tween().tween_property(_fade, "modulate:a", 0.0, 0.6)
	_play_button.grab_focus()


func _build_main() -> Control:
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 14)

	var title := UIStyle.label("HEX", 96, UIStyle.CYAN, UIStyle.DISPLAY)
	var title2 := UIStyle.label("ASTEROIDS", 52, UIStyle.TEXT, UIStyle.DISPLAY)
	for t in [title, title2]:
		t.add_theme_color_override("font_shadow_color", Color(UIStyle.CYAN, 0.45))
		t.add_theme_constant_override("shadow_offset_x", 0)
		t.add_theme_constant_override("shadow_offset_y", 0)
		t.add_theme_constant_override("shadow_outline_size", 14)
	var titles := VBoxContainer.new()
	titles.add_theme_constant_override("separation", -18)
	titles.add_child(title)
	titles.add_child(title2)
	col.add_child(titles)

	var tagline := HBoxContainer.new()
	tagline.add_theme_constant_override("separation", 10)
	for i in 3:
		if i > 0:
			var dot := HexIcon.new([UIStyle.GREEN, UIStyle.GOLD][i - 1], 12)
			dot.spin_speed = 0.8
			tagline.add_child(dot)
		tagline.add_child(UIStyle.label(["colete", "encaixe", "sobreviva"][i], 16, UIStyle.TEXT_DIM, UIStyle.CAPTION))
	col.add_child(tagline)

	var spacer := Control.new()
	spacer.custom_minimum_size.y = 14
	col.add_child(spacer)

	var record := StatCard.new("RECORDE", UIStyle.GOLD)
	record.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	record.set_value(SaveData.best_score())
	col.add_child(record)

	_play_button = UIStyle.button("JOGAR")
	_play_button.custom_minimum_size = Vector2(280, 52)
	_play_button.add_theme_font_size_override("font_size", 20)
	_play_button.pressed.connect(_play)
	var manual := UIStyle.button("MANUAL")
	manual.pressed.connect(_show_manual)
	var quit := UIStyle.button("SAIR")
	quit.pressed.connect(get_tree().quit)
	for b in [_play_button, manual, quit]:
		b.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		col.add_child(b)
	return col


func _show_manual() -> void:
	_manual_panel.visible = true
	Manual.fit(_manual_back.get_parent().get_parent())
	_manual_back.grab_focus()


func _show_main() -> void:
	_manual_panel.visible = false
	_play_button.grab_focus()


func _play() -> void:
	if _leaving:
		return
	_leaving = true
	var tw := create_tween()
	tw.tween_property(_fade, "modulate:a", 1.0, 0.35)
	tw.tween_callback(get_tree().change_scene_to_file.bind(GAME_SCENE))
