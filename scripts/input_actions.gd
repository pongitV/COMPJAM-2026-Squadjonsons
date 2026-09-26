class_name InputActions
extends RefCounted
## As ações ficam no project.godot; se alguma sumir (ex.: o editor salvou
## uma versão antiga das configurações), estas entradas padrão são registradas.


static func ensure_defaults() -> void:
	var defaults := {
		"pause": [_key(KEY_ESCAPE), _key(KEY_P)],
		"rotate": [_mouse(MOUSE_BUTTON_RIGHT)],
		"drag": [_mouse(MOUSE_BUTTON_LEFT)]
	}
	for action in defaults:
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
