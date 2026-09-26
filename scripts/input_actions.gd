class_name InputActions
extends RefCounted
## As ações ficam no project.godot; se alguma sumir (ex.: o editor salvou
## uma versão antiga das configurações), estas teclas padrão são registradas.

const DEFAULTS := {
	"pause": [KEY_ESCAPE, KEY_P],
	"rotate": [KEY_R],
}


static func ensure_defaults() -> void:
	for action in DEFAULTS:
		if InputMap.has_action(action):
			continue
		InputMap.add_action(action)
		for key in DEFAULTS[action]:
			var ev := InputEventKey.new()
			ev.physical_keycode = key
			InputMap.action_add_event(action, ev)
