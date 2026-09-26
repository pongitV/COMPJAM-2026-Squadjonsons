class_name Display
extends Node
## Tela cheia e escala, aplicadas por codigo (nao dependem do project.godot,
## que o editor pode sobrescrever): tudo (UI, sprites, mundo) escala a partir
## da resolucao base; telas mais largas ou mais altas mostram mais area, sem
## distorcer. F11 ou Alt+Enter alternam entre tela cheia e janela.
## Chame Display.setup(get_tree()) no _ready das cenas principais.

const BASE_SIZE := Vector2i(1280, 720)

static var _started := false


static func setup(tree: SceneTree) -> void:
	var root := tree.root
	root.content_scale_size = BASE_SIZE
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_EXPAND
	if not _started:
		_started = true
		# So na primeira cena: depois respeita o que o jogador escolheu (F11).
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
		var toggle := Display.new()
		toggle.name = "Display"
		root.add_child.call_deferred(toggle)


func _init() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func _unhandled_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	if key.physical_keycode == KEY_F11 or (key.physical_keycode == KEY_ENTER and key.alt_pressed):
		get_viewport().set_input_as_handled()
		var full := DisplayServer.window_get_mode() in [DisplayServer.WINDOW_MODE_FULLSCREEN,
			DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN]
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED if full else DisplayServer.WINDOW_MODE_FULLSCREEN)
