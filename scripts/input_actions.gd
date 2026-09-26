class_name InputActions
extends RefCounted
## Entradas das acoes definidas por codigo (substituem as do project.godot).
## Chamado ao abrir o menu e o jogo.


static func ensure_defaults() -> void:
	var defaults := {
		"pause": [_key(KEY_ESCAPE), _key(KEY_P)],
		"rotate": [_mouse(MOUSE_BUTTON_RIGHT), _key(KEY_R)],
		"drag": [_mouse(MOUSE_BUTTON_LEFT)]
	}
	for action in defaults:
		if InputMap.has_action(action):
			InputMap.erase_action(action)
		InputMap.add_action(action)
		for ev in defaults[action]:
			InputMap.action_add_event(action, ev)


static func _key(keycode: Key) -> InputEvent:
	var ev := InputEventKey.new()
	ev.physical_keycode = keycode
	return ev


static func _mouse(button: MouseButton) -> InputEvent:
	var ev := InputEventMouseButton.new()
	ev.button_index = button
	return ev
